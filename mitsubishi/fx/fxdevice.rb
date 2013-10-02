# -*- coding: utf-8 -*-
class FxDevice
  attr_reader :suffix, :number
  def initialize a, b = nil
    case a
    when Array
      case a.size
      when 6
        @suffix = ""
        @suffix << a[5]
        @suffix << a[4]
        @suffix.strip!
    
        @number = (((a[3] << 8 | a[2]) << 8 | a[1]) << 8) | a[0]
      when 12
        s = a[0, 4].pack "c*"
        @suffix = [s[0,2].to_i(16), s[2,2].to_i(16)].pack "c*"
        @suffix.strip!
        @number = a[4,8].pack("c*").to_i(16)
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
    when "X", "Y"
      8
    when "B", "W"
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
    when "X", "Y", "M", "S", "T", "C"
      true
    else
      false
    end
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
