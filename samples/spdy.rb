#!/usr/bin/ruby
# LGPL
####################################################
# spdy.rb : pure spdy relay : recieve SPDY cnnexion,
#           send http request to a http server, 
#   > ruby spdy.rb target-hostname target-port 
####################################################
require_relative '../lib/minitcp.rb'

$host,$port,$opt=ARGV[0]||"localhost",ARGV[1]||80
puts "Server SPDY:// on port 2200, proxy to #{$host}:#{$port}..."

class SPDY
	HEADER_SIZE=8 # 8 bytes, [2 version,2 type,1 flags,3 length(24)],data[length]
	class << self
		def  control_frame_decode(data)
			cbit=(data[0].ord&0x80)!=0
			if cbit && data.size==8
				version=(data[0].ord&0x7F)*256+data[1].ord
				type= data[2].ord*256+data[3].ord
				iflag= data[4].ord
				length=(data[5].ord*256+data[6].ord)*256+data[7].ord
			end
		end
	end
end


MServer.service(2200,"0.0.0.0",22) do |s_cli|
  puts "> ======== client Connected ========"
  on_n_receive(SPDY::HEADER_SIZE) do |header|
	version,type,flags,length=SPDY.control_frame_decode(header)
	data= length>0 ? receive_n_bytes(length) : ""
    srv=MClient.run_one_shot($host,$port) do |s_srv|
  end
  s_cli.wait_end
  p "end cli, stop proxy"
  srv.kill
end

sleep


