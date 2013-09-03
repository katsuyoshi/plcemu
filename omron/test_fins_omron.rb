require 'socket'
require 'timeout'


@require_response = true

def fins_header
  icf = 0x80 | (@require_response ? 0 : 1);
  rsv = 0
  gct = 2
  dna = 1
  da1 = 96
  da2 = 0
  sna = 1
  sa1 = 5
  sa2 = 0
  sid = 0
  [icf, rsv, gct, dna, da1, da2, sna, sa1, sa2, sid].pack "C*"
end


@socket = nil
@host = "192.168.2.96"
@port = 9600

def open
  @socket = TCPSocket.open(@host, @port) unless @socket
end
  
def close
  @socket.close if @socket
end
  

def command
return %w(80 00 02 00 60 00 00 05 00 00 01 01 82 00 0A 00 00 01).collect{|c| c.to_i(16)}.pack "C*"
return %w(80 00 02 00 60 00 00 05 00 01 01 02 82 00 14 00 00 0A 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00).collect{|c| c.to_i(16)}.pack "C*"
  s = fins_header
  body = ""#[1, 0, 0x82, 0, 0xa, 0, 0, 0x1].pack "C*"
#  body = [1, 2, 0x82, 0, 0xa, 0, 0, 0x1, 0, 1].pack "C*"
  s + body
end

def to_hex s
  s.split(//).inject(""){|r,c| r + sprintf("%02X ",c[0])}.strip
end

def dump_hex s
  puts to_hex(s)
end

def tcp_command c
  l = c.size + 2 * 4
  "FINS" + [l, 2, 0].pack("N*") + c# + [0,0].pack("C*")
end

def tcp_header_0
    "FINS" + [0xc, 0, 0, 5].pack("N*")
end

  def receive
    res = ""
    len = 0
    begin
      timeout(0.5) do
        while true
          r = @socket.read(1)
          res << r if r
          l = res.size
          if l >= 8
            sa = res[4, 4]
            len = sa.unpack("N")[0]
            break if l >= len + 8
          end
        end
      end
    rescue Timeout::Error
    end
#@logger.debug("< #{res}")
    res
  end


open

c = tcp_header_0
dump_hex c
@socket.send(c, 0)
@socket.flush
r = receive
dump_hex r

c = tcp_command(command)
dump_hex c
@socket.send(c, 0)
@socket.flush
r = receive
dump_hex r

close

