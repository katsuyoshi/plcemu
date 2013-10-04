# -*- coding: utf-8 -*-
class Fam3Device
  attr_reader :suffix, :number
  
  def initialize a, b = nil
    case a
    when String
      if b
        @suffix = a
        @number = b
      else
        /([A-Za-z]+)(.+)/ =~ a
        @suffix = $1
        @number = $2.to_i(p_adic_number)
      end
    end
  end
  
  def p_adic_number
    10
  end
  
  def name
    @suffix + @number.to_s(p_adic_number).upcase
  end
  
  def next_device
    d = self.class.new @suffix, @number + 1
    d
  end
  
end
