# -*- coding: utf-8 -*-
class FinsDevice
  attr_reader :suffix, :number, :bit, :bit_access
  
  def initialize a, b = nil
    case a
    when Array
      case a.size
      when 2
        @suffix = a[0]
        @number = a[1]
        @bit = 0
        @bit_access = fasle
      when 3
        @suffix = a[0]
        @number = a[1]
        @bit = a[2]
        @bit_access = true
      when 4
        @suffix = to_suffix a[0]
        @number = to_int a[1, 2]
        @bit = to_int a[3, 1]
      end
      
    when String
      if b
        @suffix = a
        @number = b
      else
        /([A-Za-z]+)?(.+)/ =~ a
        @suffix = $1 ? $1 : ""
        @number = $2.to_i(p_adic_number)
      end
    end
  end
  
  def p_adic_number
    10
  end
  
  def name
    n = @suffix + @number.to_s(p_adic_number).upcase
    if self.bit_access
      n += ".#{bit}"
    end
    n
  end
  
  def channel_device
    self.class.new @suffix + @number.to_s(p_adic_number).upcase
  end
  
  def next_device
    if self.bit_access
      bit = @bit += 1
      if bit >= 16
        bit -= 16
        number = @number + 1
      end
      return self.class.new [@suffix, number, bit]
    else
      self.class.new @suffix, @number + 1
    end
  end
  
  def to_suffix code
    s = { 0x30 => "", 0x31 => "W", 0x32 => "H", 0x33 => "A", 0x09 => "T", 0x2 => "D", 0x0a => "E", 0x06 => "TK"}[code]
    if s
      @bit_access = true
      return s
    end
    @bit_access = false
    { 0xB0 => "", 0xB1 => "W", 0xB2 => "H", 0xB3 => "A", 0x89 => "T", 0x82 => "D", 0x98 => "E", 0xbc => "DR"}[code]
  end
  
  def to_int a
    v = 0
    a.each do |e|
      v <<= 8
      v += e
    end
    v
  end
  
  def bit_device?
    case @suffix
    when "X", "Y", "I", "E", "L", "M", "TU", "CU"
      true
    else
      false
    end
  end

end
