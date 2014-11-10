# LGPL,  Author: Regis d'Aubarede <regis.aubarede@gmail.com>
#################################################################
#  pingpongplot.rb : measure pingpong time on google, plot it
#
# Usage :
#   > ruby pingpongplot.rb  | ruby plot.rb 0 0 300 pingpong auto
#################################################################
require_relative '../lib/minitcp.rb'


$stdout.sync=true
l=ARGV.size>0 ? ARGV : ["google.com"]
$data=(1..l.size).map {|| "0"}
l.each_with_index do |url,index|
  MClient.run_continious(url,80,1000-100) do |socket|
    s=Time.now.to_f
    socket.on_receive_sep("\r\n") do |data| 
      $data[index]="#{((Time.now.to_f-s)*1000).round}"
      socket.close rescue nil
    end
    s=Time.now.to_f
    socket.print "GET /blabla HTTP/1.0\r\nHost: ici\r\n\r\n"
    socket.wait_end
  end
end
Thread.new {|| loop {
  data=$data.clone
  $stdout.puts data.join(" ")
  $stdout.flush
  sleep 1
}}
sleep
