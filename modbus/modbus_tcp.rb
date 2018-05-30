#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# Usage: ./fam3.rb
require 'webrick'
require './modbus_device'
require 'optparse'

#DEFAULT_PORT = 502
DEFAULT_PORT = 10000
DEFAULT_STATUS_FROM_PLC = "HR103"

FC_READ_COILS                     = 0x01
FC_READ_DISCREAT_INPUTS           = 0x02
FC_READ_HOLDING_REGISTERS         = 0x03
FC_READ_INPUT_REGISTERS           = 0x04
FC_WRITE_SINGLE_COIL              = 0x05
FC_WRITE_SINGLE_REGISTER          = 0x06
FC_WRITE_MULTIPLE_COILS           = 0x0f
FC_WIRTE_MULTIPLE_REGISTERS       = 0x10
FC_READ_FILE_RECORD               = 0x14
FC_WRITE_FILE_RECORD              = 0x15
FC_MASK_WRITE_REGISTER            = 0x16
FC_READ_WRITE_MULTIPULE_REGISTRS  = 0x17
FC_READ_FIFO_QUEUE                = 0x18

EC_SUCCEED            = 0x00
EC_FUNCTION_CODE      = 0x01
EC_ADDRESS            = 0x02
EC_AMOUNT             = 0x03
EC_PROCESSING         = 0x04
EC_CPU_NUMBER         = 0x0a
EC_TIMEOUT            = 0x0b

# extension types
EXTENSION_YOKOGAWA_STARDOM    = "stardom"



@unit_id = 1

params = ARGV.getopts("e:", "extension:")

@extension = params["e"] || params["extension"]

class ModbusTcp < WEBrick::GenericServer


  def initialize config = {}, default = WEBrick::Config::General
    super
    @device_dict = {}
    @extension = config[:extension]
    #@device_dict[DEFAULT_STATUS_FROM_PLC] = 1
  end

  def run(sock)
    done = false
    buf = []
    while true
      c = sock.getc
      break if c.nil? || c == ""

      buf << c.bytes.first
      next if buf.length < 6

      len = buf[4,2].pack("C*").unpack("n").first + 6
      next if buf.length < len

      case buf[7]
      when FC_READ_COILS
        res = read_bits buf, "M"
        sock.write res.pack("c*")
        done = true

      when FC_READ_DISCREAT_INPUTS
        res = read_bits buf, "I"
        sock.write res.pack("c*")
        done = true

      when FC_READ_HOLDING_REGISTERS
        res = read_words buf, "HR"
        sock.write res.pack("c*")
        done = true

      when FC_READ_INPUT_REGISTERS
        res = read_words buf, "IR"
        sock.write res.pack("c*")
        done = true

      when FC_WRITE_MULTIPLE_COILS
        res = write_bits buf, "M"
        sock.write res.pack("c*")
        done = true


      when FC_WIRTE_MULTIPLE_REGISTERS
        res = write_words buf, "HR"
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

  private

    def read_bits buf, suffix
      reg_no = buf[8,2].pack("C*").unpack("n").first
      count = buf[10,2].pack("C*").unpack("n").first
      d = ModbusDevice.new "#{suffix}#{reg_no}"
      res = buf[0, 8]
      values = []
      bytes = (count + 7) / 8
      res << bytes
      count.times do |i|
        v = @device_dict[d.name] || false
        values << v
        #res << [v].pack("n").unpack("C*")
        d = d.next_device
      end
      values.each_slice(8) do |values_8|
        res << values_8.each_with_index.inject(0) {|r, (v, i)| v ? (r | (1 << i)) : r }
      end
      res[5] = res.size - 6
      res
    end

    def write_bits buf, suffix
      reg_no = buf[8,2].pack("C*").unpack("n").first
      count = buf[10,2].pack("C*").unpack("n").first
      d = ModbusDevice.new "#{suffix}#{reg_no}"
      res = buf[0, 12]
      bytes = (count + 7) / 8
      n = 0
      bytes.times do |i|
        v = buf[13 + i]
        8.times do |j|
          @device_dict[d.name] = (v & (1 << j)) != 0
          d = d.next_device
          n += 1
          break if n <= count
        end
      end
      res[5] = res.size - 6
      res
    end

    def read_words buf, suffix
      case @extension
      when EXTENSION_YOKOGAWA_STARDOM
        read_words_stardom buf, suffix
      else
        read_words_normal buf, suffix
      end
    end

    def write_words buf, suffix
      case @extension
      when EXTENSION_YOKOGAWA_STARDOM
        write_words_stardom buf, suffix
      else
        write_words_normal buf, suffix
      end
    end


    # --- normal

    def read_words_normal buf, suffix
      reg_no = buf[8,2].pack("C*").unpack("n").first
      count = buf[10,2].pack("C*").unpack("n").first
      d = ModbusDevice.new "#{suffix}#{reg_no}"
      res = buf[0, 8]
      values = []
      count.times do |i|
        v = @device_dict[d.name] || 0
        values << v
        #res << [v].pack("n").unpack("C*")
        d = d.next_device
      end
      res << count * 2
      values.each do |value|
        res << [value].pack("n").unpack("c*")
      end
      res.flatten!
      res[5] = res.size - 6
      res
    end

    def write_words_normal buf, suffix
      reg_no = buf[8,2].pack("C*").unpack("n").first
      count = buf[10,2].pack("C*").unpack("n").first
      d = ModbusDevice.new "#{suffix}#{reg_no}"
      res = buf[0, 12]
      count.times do |i|
        v = buf[13 + i * 2, 2].pack("C*").unpack("n").first
        @device_dict[d.name] = v
        d = d.next_device
      end
      res[5] = res.size - 6
      res
    end

    # --- stardom

    def read_words_stardom buf, suffix
      return read_words_normal buf, suffix unless suffix == "HR"
      reg_no = buf[8,2].pack("C*").unpack("n").first
      case reg_no
      when 45001..46999
        count = buf[10,2].pack("C*").unpack("n").first
        d = ModbusDevice.new "#{suffix}#{reg_no}"
        res = buf[0, 8]
        values = []
        count.times do |i|
          v = @device_dict[d.name] || 0
          values << v
          #res << [v].pack("n").unpack("C*")
          d = d.next_device
        end
        res << count * 4
        values.each do |value|
          res << [value].pack("N").unpack("C*")
        end
        res.flatten!
        res[5] = res.size - 6
        res
      when 47001..48999
        count = buf[10,2].pack("C*").unpack("n").first
        d = ModbusDevice.new "#{suffix}#{reg_no}"
        res = buf[0, 8]
        values = []
        count.times do |i|
          v = @device_dict[d.name] || 0
          values << v
          #res << [v].pack("n").unpack("C*")
          d = d.next_device
        end
        res << count * 4
        values.each do |value|
          res << [value].pack("g").unpack("C*")
        end
        res.flatten!
        res[5] = res.size - 6
        res
      else
        count = buf[10,2].pack("C*").unpack("n").first
        d = ModbusDevice.new "#{suffix}#{reg_no}"
        res = buf[0, 8]
        values = []
        count.times do |i|
          v = @device_dict[d.name] || 0
          values << v
          #res << [v].pack("n").unpack("C*")
          d = d.next_device
        end
        res << count * 2
        values.each do |value|
          res << [value].pack("n").unpack("c*")
        end
        res.flatten!
        res[5] = res.size - 6
        res
      end
    end

    def write_words_stardom buf, suffix
      return write_words_normal buf, suffix unless suffix == "HR"
      reg_no = buf[8,2].pack("C*").unpack("n").first
      case reg_no
      when 45001..46999
        count = buf[10,2].pack("C*").unpack("n").first
        d = ModbusDevice.new "#{suffix}#{reg_no}"
        res = buf[0, 12]
        count.times do |i|
          v = buf[13 + i * 4, 4].pack("C*").unpack("N").first
          @device_dict[d.name] = v
          d = d.next_device
        end
        res[5] = res.size - 6
        res
      when 47001..48999
        count = buf[10,2].pack("C*").unpack("n").first
        d = ModbusDevice.new "#{suffix}#{reg_no}"
        res = buf[0, 12]
        count.times do |i|
          v = buf[13 + i * 4, 4].pack("C*").unpack("g").first
          @device_dict[d.name] = v
          d = d.next_device
        end
        res[5] = res.size - 6
        res
      else
        return write_words_normal buf, suffix
      end
    end


end

server = ModbusTcp.new(:Port => DEFAULT_PORT, :BindAddress => "0.0.0.0", extension:@extension)
trap(:INT) { server.shutdown }
server.start
