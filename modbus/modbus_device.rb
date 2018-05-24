# -*- coding: utf-8 -*-
class ModbusDevice
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

  def bit_device?
    case @suffix
    when "M", "I"
      true
    else
      false
    end
  end

end

if $0 == __FILE__
  p ModbusDevice.new("M0").name
  p ModbusDevice.new("I0").name
  p ModbusDevice.new("HR0").name
  p ModbusDevice.new("IR0").name
end


__END__
HR IR
