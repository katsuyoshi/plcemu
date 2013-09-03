require 'socket'


def fins_header
  icf = 0x80# | (@require_response ? 0 : 1);
  rsv = 0
  gct = 2
  dna = 0
  da1 = 96
  da2 = 0
  sna = 0
  sa1 = 5
  sa2 = 0
  sid = 0
  [icf, rsv, gct, dna, da1, da2, sna, sa1, sa2, sid].pack "C*"
end

def command
#return %w(80 00 02 00 60 00 00 05 00 01 01 02 82 00 14 00 00 0A 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00).collect{|c| c.to_i(16)}.pack "C*"
  s = fins_header
  body = [1, 1, 0x82, 0, 0xa, 0, 0, 0x1].pack "C*"
#  body = [1, 2, 0x82, 0, 0xa, 0, 0, 0x1, 0, 1].pack "C*"
  s + body
end

def to_hex s
  s.split(//).inject(""){|r,c| r + sprintf("%02X ",c[0])}.strip
end

def dump_hex s
  puts to_hex(s)
end


c = command
socket = UDPSocket.new
socket.connect("192.168.2.96", 9600)

@response = nil
@received = false
thread = Thread.start {
  until @received
    @response = socket.recv(65536, 0)
    @received = true
  end
}

socket.send c, 0

until @received
end

socket.close
dump_hex c
dump_hex @response
