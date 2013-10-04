#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# Usage: ./fam3.rb
require 'webrick'
require './fam3device'

DEFAULT_PORT = 12289
DEFAULT_STATUS_FROM_PLC = "D16382"


class Fam3 < WEBrick::GenericServer
  
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
      next if buf.index("\n").nil?

      puts "s> " + buf.chomp

      /^\d(\d)(\w{3})((.+?)\s+(\d+)(\s+(\w+))?)?/ =~ buf.chomp
      cpu_no = $1.to_i
      cmd = $2
      d = $4 ? Fam3Device.new($4) : nil
      count = $5 ? $5.to_i : 0
      value = $7
      res = nil
      
      case cmd
      when "WWR"
        count.times do |i|
          v = value[i * 4, 4].to_i(16)
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
        res = "1#{cpu_no}OK\r\n"
        sock.write res
      
      when "BWR"
        count.times do |i|
          @device_dict[d.name] = value[i, 1].to_i
          d = d.next_device
        end
        res = "1#{cpu_no}OK\r\n"
        sock.write res
      
      when "WRD"
        res = "1#{cpu_no}OK"
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
          res << ("000" + v.to_s(16))[-4, 4]
        end
        res << "\r\n"
        sock.write res
        
      when "BRD"
        res = "1#{cpu_no}OK"
        count.times do |i|
          v = @device_dict[d.name] || 0
          res << (v == 0 ? "0" : "1")
          d = d.next_device
        end
        res << "\r\n"
        sock.write res
      
      when "STA", "STP"
        res = "1#{cpu_no}OK\r\n"
        sock.write res
      
      end

      puts "r< " + res.chomp if res
p @device_dict
      buf = ""
    end
    puts "Close"
  end
  
end

server = Fam3.new(:Port => DEFAULT_PORT)
trap(:INT) { server.shutdown }
server.start

