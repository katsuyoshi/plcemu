# -*- coding: utf-8 -*-
class QDevice
  attr_reader :suffix, :number
  def initialize a, b = nil
    case a
    when Array
      case a.size
      when 4
        @suffix = suffix_for_code(a[3])
        @number = ((a[2] << 8 | a[1]) << 8) | a[0]
      end
    when String
      if b
        @suffix = a
        @number = b
      else
        if a.length == 12
          @suffix = [a[0,2].to_i(16), a[2,2].to_i(16)].pack "c*"
          @suffix.strip!
          @number = a[4,8].to_i(16)
        elsif /(X|Y)(.+)/ =~ a
          @suffix = $1
          @number = $2.to_i(p_adic_number)
        else
          /(M|L|S|B|F|T|C|D|W|R)(.+)/ =~ a
          @suffix = $1
          @number = $2.to_i(p_adic_number)
        end
      end
    end
  end
  
  def p_adic_number
    case @suffix
    when "X", "Y", "B", "W", "SB", "SW", "DX", "DY", "ZR"
      16
    else
      10
    end
  end
  
  def name
    @suffix + @number.to_s(p_adic_number).upcase
  end
  
  def next_device
    d = self.class.new @suffix, @number + 1
    d
  end
  
  def bit_device?
    case @suffix
    when "SM", "X", "Y", "M", "L", "F", "V", "B",
         "TS", "TC", "SS", "SC","CS", "CC", "SB", "S", "DX", "DY"
      true
    else
      false
    end
  end
  
  def suffix_for_code code
    @@suffixes ||= %w(SM SD X Y M L F V B D W TS TC TN SS SC SN CS CC CN SB SW S DX DY Z R ZR)
    @@suffix_codes ||= [0x91, 0xa9, 0x9c, 0x9d, 0x90, 0x92, 0x93, 0x94, 0xa0, 0xa8, 0xb4, 0xc1, 0xc0, 0xc2, 0xc7, 0xc6, 0xc8, 0xc4, 0xc3, 0xc5, 0xa1, 0xb5, 0x98, 0xa2, 0xa3, 0xcc ,0xaf, 0xb0]
      
      index = @@suffix_codes.index code
      index ? @@suffixes[index] : nil
  end
  
end

=begin
d = FxDevice.new [0, 0, 0, 0, 32, 68]
p d.name
p d.next_device.name

p FxDevice.new "D", 0
p FxDevice.new "D0"
p FxDevice.new "X10"
p FxDevice.new("X10").name
p FxDevice.new "4D2000000064".unpack("c*")
p FxDevice.new "4D2000000064"
p FxDevice.new "582000000011"
p FxDevice.new("582000000011").name
=end
