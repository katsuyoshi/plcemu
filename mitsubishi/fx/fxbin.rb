#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# Usage: ./fxbin.rb
require 'webrick'
require './fxdevice'

DEFAULT_PORT = 5010
DEFAULT_STATUS_FROM_PLC = "D7989"


class Fx < WEBrick::GenericServer
  
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
      
      buf << c.bytes.first
      next if buf.length < 4

      case buf[0]
      
      # read bit device
      when 0
        next if buf.length < 12
        count = short_value buf[10,2]
        d = FxDevice.new buf[4, 6]
        res = [buf[0] | 0x80, 0]
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
      when 2
        next if buf.length < 12
        count = short_value buf[10,2]
        next if buf.length < 12 + (count + 1) / 2
        d = FxDevice.new buf[4, 6]
        count.times do |i|
          index = i / 2
          if i % 2 == 0
            @device_dict[d.name] = buf[12 + index] & 0x10 == 0 ? 0 : 1
          else
            @device_dict[d.name] = buf[12 + index] & 0x1 == 0 ? 0 : 1
          end
        end
        sock.write [buf[0] | 0x80, 0].pack("c*")
        done = true
      
      # read word device
      when 1
        next if buf.length < 12
        count = short_value buf[10,2]
        d = FxDevice.new buf[4, 6]
        res = [buf[0] | 0x80, 0]
        count.times do |i|
          v = 0
          if d.bit_device?
            16.times do |i|
              v |= (((@device_dict[d.name] || 0) == 0 ? 0 : 1) << i)
              d = d.next_device
              break if d.nil?
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
      when 3
        next if buf.length < 12
        count = short_value buf[10,2]
        next if buf.length < 12 + count * 2
        d = FxDevice.new buf[4, 6]
        count.times do |i|
          v = short_value buf[12 + i * 2, 2]
          if d.bit_device?
            16.times do |i|
              @device_dict[d.name] = v & (1 << i) ? 1 : 0
              d = d.next_device
              break if d.nil?
            end
          else
            @device_dict[d.name] = v
            d = d.next_device
          end
        end
        res = [buf[0] | 0x80, 0]
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

server = Fx.new(:Port => DEFAULT_PORT)
trap(:INT) { server.shutdown }
server.start

