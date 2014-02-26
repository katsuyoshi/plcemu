#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# Usage: ./qbin.rb
require 'webrick'
require './qdevice'

DEFAULT_PORT = 5010
DEFAULT_STATUS_FROM_PLC = "D7989"


class Q < WEBrick::GenericServer
  
  HEADER_LENGTH = 11
  
  def initialize config = {}, default = WEBrick::Config::General
    super
    @device_dict = {}
    @device_dict[DEFAULT_STATUS_FROM_PLC] = 1
  end
  
  def run(sock)
    done = false
    buf = []
    while true
      c = sock.getc
      break if c.nil? || c == ""
      buf << c
      next if buf.length < 15

      case buf[HEADER_LENGTH, 4]
      
      # read bit device
      when [0x01, 0x04, 0x01, 0x00]
        next if buf.length < HEADER_LENGTH + 10
        count = short_value buf[HEADER_LENGTH + 8, 2]
        d = QDevice.new buf[HEADER_LENGTH + 4, 4]
        res = [[0xd0, 0x00,  0x00,  0xff,  0xff, 0x03,  0x00],  [0x02, 0x00],  [0x00, 0x00]].flatten
        res[7] = 2 + (count + 1) / 2
        count.times do |i|
          v = @device_dict[d.name] || 0
          if i % 2 == 0
            res << (v == 0 ? 0 : 0x10)
          else
            res[-1] |= (v == 0 ? 0 : 1)
          end
          d = d.next_device
        end
        sock.write res.pack("c*")
        done = true
      
      # write bit device
      when [0x01, 0x14, 0x01, 0x00]
        next if buf.length < HEADER_LENGTH + 10
        count = short_value buf[HEADER_LENGTH + 8, 2]
        next if buf.length < HEADER_LENGTH + 10 + (count + 1) / 2
        d = QDevice.new buf[HEADER_LENGTH + 4, 4]
        count.times do |i|
          index = HEADER_LENGTH + 10 + i / 2
          if i % 2 == 0
            @device_dict[d.name] = buf[index] & 0x10 == 0 ? 0 : 1
          else
            @device_dict[d.name] = buf[index] & 0x1 == 0 ? 0 : 1
          end
        end
        res = [[0xd0, 0x00,  0x00,  0xff,  0xff, 0x03,  0x00],  [0x02, 0x00],  [0x00, 0x00]].flatten
        sock.write res.pack("c*")
        done = true
      
      # read word device
      when [0x01, 0x04, 0x00, 0x00]
        next if buf.length < HEADER_LENGTH + 10
        count = short_value buf[HEADER_LENGTH + 8, 2]
        d = QDevice.new buf[HEADER_LENGTH + 4, 4]
        res = [[0xd0, 0x00,  0x00,  0xff,  0xff, 0x03,  0x00],  [0x02, 0x00],  [0x00, 0x00]].flatten
        res[7] = 2 + count * 2
        count.times do |i|
          v = 0
          if d.bit_device?
            16.times do |i|
              v |= (((@device_dict[d.name] || 0) == 0 ? 0 : 1) << i)
              d = d.next_device
            end
          else
            v = @device_dict[d.name] || 0
            d = d.next_device
          end
          res << (v & 0xff); v >>= 8
          res << (v & 0xff)
        end
        sock.write res.pack("c*")
        done = true
      
      # write word device
      when [0x01, 0x14, 0x00, 0x00]
        next if buf.length < HEADER_LENGTH + 10
        count = short_value buf[HEADER_LENGTH + 8, 2]
        next if buf.length < HEADER_LENGTH + 10 + count * 2
        d = QDevice.new buf[HEADER_LENGTH + 4, 4]
        count.times do |i|
          index = HEADER_LENGTH + 10 + i * 2
          v = short_value(buf[index, 2])
          if d.bit_device?
            16.times do |i|
              @device_dict[d.name] = v & (1 << i) ? 1 : 0
              d = d.next_device
            end
          else
            @device_dict[d.name] = v
            d = d.next_device
          end
        end
        res = [[0xd0, 0x00,  0x00,  0xff,  0xff, 0x03,  0x00],  [0x02, 0x00],  [0x00, 0x00]].flatten
        sock.write res.pack("c*")
        done = true

      # remote run
      when 0x13
        @device_dict["M8000"] = 1
        res = [buf[0] | 0x80, 0]
        sock.write res.pack("c*")
        done = true
      
      # remote stop
      when 0x14
        @device_dict["M8000"] = 0
        res = [buf[0] | 0x80, 0]
        sock.write res.pack("c*")
        done = true
      
      end
      
      if done
        puts ">> #{buf.map{|c| ("0" + c.to_s(16).upcase)[-2, 2]}}"
        puts "<< #{res.map{|c| ("0" + c.to_s(16).upcase)[-2, 2]}}"
p @device_dict
        buf = []
        done = false
      end
      
    end
    puts "Close"
  end
  
  def short_value a
    a[1] << 8 | a[0]
  end
  
end

server = Q.new(:Port => DEFAULT_PORT)
trap(:INT) { server.shutdown }
server.start

