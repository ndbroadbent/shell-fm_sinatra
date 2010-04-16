require "socket"
 
host = "192.168.1.37"
port = 54311

info = nil

4.times do
  t = TCPSocket.new(host, port)
  t.print "info %a - %t\n"
  info = t.gets(nil)
  t.close
  break
end

puts info
