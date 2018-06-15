#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# Usage: ./qbin.rb
require 'webrick'
require './finsdevice'

DEFAULT_PORT = 9600
DEFAULT_STATUS_FROM_PLC = "D32761"


class Fins < WEBrick::GenericServer

  attr_accessor :server_node, :client_node, :running

  def initialize config = {}, default = WEBrick::Config::General
    super
    @device_dict = {}
    @device_dict[DEFAULT_STATUS_FROM_PLC] = 1
    @server_node = 1
  end

  def running
    @running  | true
  end

  def run(sock)
    done = false
    buf = []
    while true
      c = sock.getc
      break if c.nil? || c == ""

      buf << c.bytes.first
      next if buf.length < 8

      len = to_int(buf[4, 4])
      next if buf.length < 6 + len + 2

      fins_frame_command = to_int(buf[8, 4])
      case fins_frame_command
      when 0
        self.client_node = buf[19] == 0 ? 239 : buf[19]
        self.server_node += 1 if self.client_node == self.server_node
        res = ["FINS".bytes.to_a, [0, 0, 0, 0x10], [0, 0, 0, 1], [0, 0, 0, 0], [0, 0, 0, self.client_node], [0, 0, 0, server_node]].flatten
        sock.write res.pack("c*")

      when 2
        res = ["FINS".bytes.to_a, [0, 0, 0, 0x10], [0, 0, 0, 2], [0, 0, 0, 0]].flatten
        # 2:number of gateways
        # 3:destination network no
        # 4:destination node
        res += [0x80, 0x00, 0x02, 0x00, self.client_node, 0x00, 0x00, self.server_node, 0x00, 0x00]
        body = buf[26..-1]
        cmd = body[0, 2]

        res += cmd
        res += [0, 0]

        case cmd
        # read device
        when [1, 1]
          d = FinsDevice.new body[2, 4]
          count = to_int body[6, 2]
          if d.bit_access
            res[7] = 8 + 4 + count
            count.times do |i|
              v = @device_dict[d.channel_device.name] || 0
              res << (v & (1 << d.bit) == 0 ? 0 : 1)
              d = d.next_device
            end
          else
            count.times do |i|
              v = @device_dict[d.channel_device.name] || 0
              res << ((v >> 8) & 0xff)
              res << (v & 0xff)
              d = d.next_device
            end
          end
          res[7] = res.size - 8
          sock.write res.pack("c*")

        # write device
        when [1, 2]
          d = FinsDevice.new body[2, 4]
          count = to_int body[6, 2]
          if d.bit_access
            cd = d.channel_device
            v = @device_dict[cd.name] || 0
            count.times do |i|
              index = 8 + i
              if body[index] == 0
                v &= ~(1 << d.bit)
              else
                v |= (1 << d.bit)
              end
              d = d.next_device
            end
            @device_dict[cd.name] = v
          else
            count.times do |i|
              index = 8 + i * 2
              v = body[index] << 8 | body[index + 1]
              @device_dict[d.name] = v
              d = d.next_device
            end
          end
          res[7] = res.size - 8
          sock.write res.pack("c*")

        when [01, 04]
          count = (body.length - 2) / 4
          count.times do |i|
            kind = body[2 + i * 4]
            d = FinsDevice.new body[2 + i * 4, 4]
            if d.bit_access
              res << kind
              v = @device_dict[d.channel_device.name] || 0
              res << (v & (1 << d.bit) == 0 ? 0 : 1)
              d = d.next_device
            else
              v = @device_dict[d.name] || 0
              res << kind
              res << ((v >> 8) & 0xff)
              res << (v & 0xff)
            end
          end
          res[7] = res.size - 8
          sock.write res.flatten.pack("c*")

        when [06, 01]
          res << (running ? 1 : 0)
          res << 4
          res += [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]].flatten
          res[7] = res.size - 8
          sock.write res.pack("c*")

        end

      end

      puts ">> #{buf.map{|c| ("0" + c.to_s(16).upcase)[-2, 2]}}"
      puts "<< #{res.map{|c| ("0" + c.to_s(16).upcase)[-2, 2]}}"
p @device_dict

      buf = []
    end
    puts "Close"
  end

  def to_int a
    v = 0
    a.each do |e|
      v <<= 8
      v += e
    end
    v
  end

end


server = Fins.new(:Port => DEFAULT_PORT)
trap(:INT) { server.shutdown }
server.start
