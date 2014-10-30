# LGPL,  Author: Regis d'Aubarede <regis.aubarede@gmail.com>
#################################################################
#  pingpongplot.rb : measure pingpong time on google, plot it
#
# Usage :
#   > ruby pingpongplot.rb  | ruby plot.rb 0 0 300 pingpong auto
#################################################################
require_relative '../lib/minitcp.rb'


$stdout.sync=true

MClient.run_continious("google.com",80,50) do |socket|
  s=Time.now.to_f
  socket.on_receive_sep("\r\n") do |data| 
  	$stdout.puts("#{(Time.now.to_f-s)*1000}") 
  	$stdout.flush 
  	socket.close rescue nil
  end
  s=Time.now.to_f
  socket.print "GET /blabla HTTP/1.0\r\nHost: ici\r\n\r\n"
  socket.wait_end
end


sleep
