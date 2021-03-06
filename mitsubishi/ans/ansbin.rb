#!/usr/bin/ruby
# -*- coding: utf8 -*-
require 'webrick'
require 'ansdevice'

DEFAULT_PORT = 5010
DEFAULT_STATUS_FROM_PLC = "D1021"


class AnS < WEBrick::GenericServer
  
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
      next if buf.length < 4

      case buf[0]
      
      when 0
        next if buf.length < 12
        count = short_value buf[10,2]
        d = AnSDevice.new buf[4, 6]
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
        
      when 2
        next if buf.length < 12
        count = short_value buf[10,2]
        next if buf.length < 12 + (count + 1) / 2
        d = AnSDevice.new buf[4, 6]
        count.times do |i|
          index = i / 2
          if i % 2 == 0
            @device_dict[d.name] = buf[12 + index] & 0x10 == 0 ? 0 : 1
          else
            @device_dict[d.name] = buf[12 + index] & 0x1 == 0 ? 0 : 1
          end
          d = d.next_device
        end
        sock.write [buf[0] | 0x80, 0].pack("c*")
        done = true
      
      when 1
        next if buf.length < 12
        count = short_value buf[10,2]
        d = AnSDevice.new buf[4, 6]
        res = [buf[0] | 0x80, 0]
        count.times do |i|
          v = @device_dict[d.name] || 0
          res << (v & 0xff)
          res << (v >> 8)
          d = d.next_device
        end
        sock.write res.pack("c*")
        done = true
        
      when 3
        next if buf.length < 12
        count = short_value buf[10,2]
        next if buf.length < 12 + count * 2
        d = AnSDevice.new buf[4, 6]
        count.times do |i|
          v = short_value buf[12 + i * 2, 2]
          @device_dict[d.name] = v
          d = d.next_device
        end
        sock.write [buf[0] | 0x80, 0].pack("c*")
        done = true

      when 0x13
        @device_dict["D9015"] = 0x0000
        sock.write [buf[0] | 0x80, 0].pack("c*")
        done = true
      
      when 0x14
        @device_dict["D9015"] = 0x1000
        sock.write [buf[0] | 0x80, 0].pack("c*")
        done = true
      
      end
      
      if done
p buf
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

server = AnS.new(:Port => DEFAULT_PORT)
trap(:INT) { server.shutdown }
server.start

