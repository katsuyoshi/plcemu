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
    buf = ""
    while true
      c = sock.getc
      break if c.nil? || c == ""
      buf << c
      next if buf.length < 8
      case buf[0,2].to_i(16)
      
      when 0
        next if buf.length < 24
        count = buf[20,2].to_i(16)
        d = AnSDevice.new buf[8, 12]
        res = "8000"
        count.times do |i|
          v = @device_dict[d.name] || 0
          res << v.to_s
          d = d.next_device
        end
p res
        sock.write res
        done = true
        
      when 2
        next if buf.length < 24
        count = buf[20,2].to_i(16)
        next if buf.length < 24 + count + (count % 2)
        d = AnSDevice.new buf[8, 12]
        count.times do |i|
          @device_dict[d.name] = buf[24 + i, 1] == "0"  ? 0 : 1
          d = d.next_device
        end
        sock.write "8200"
        done = true
      
      when 1
        next if buf.length < 24
        count = buf[20,2].to_i(16)
        d = AnSDevice.new buf[8, 12]
        res = "8100"
        count.times do |i|
          v = @device_dict[d.name] || 0
          res << ("0000" + v.to_s(16))[-4, 4]
          d = d.next_device
        end
        sock.write res
        done = true
        
      when 3
        next if buf.length < 24
        count = buf[20,2].to_i(16)
        next if buf.length < 24 + count * 4
        d = AnSDevice.new buf[8, 12]
        count.times do |i|
          v = buf[24 + i * 4, 4].to_i(16)
          @device_dict[d.name] = v
          d = d.next_device
        end
        sock.write "8300"
        done = true

      when 0x13
        @device_dict["D9015"] = 0x0000
        sock.write "9300"
        done = true
      
      when 0x14
        @device_dict["D9015"] = 0x1000
        sock.write "9400"
        done = true
      
      end
      
      if done
p buf
p @device_dict
        buf = ""
        done = false
      end
      
    end
    puts "Close"
  end
  
end

server = AnS.new(:Port => DEFAULT_PORT)
trap(:INT) { server.shutdown }
server.start
