#!/usr/bin/ruby
# LGPL
#################################################################################
# relaiproxy.rb : An extranet server want to send command (http/soap)
#                 to a intranet client_socket clients are many, variables, 
#                 so NAT is not a solution.
#
#           relai.rb : in intranet, maintain the socket open with the proxy (initiated by a http request) 
#           relaiproxy : receive soap request and send them to relai via open socket
# so
#   a pool of sockets beetwen intranet/extranet is maintain, client is inside intranet, 
#   serveur is outside.
#   server can send http request to intranet host via proxy-relai 
#   'plugin' in relai can determine host adresse with the request contant (header SOAP...)
#
#################################################################################
=begin
                                                                        h[XX]=[ip,80,/]
request--------http://proxy_hostname:prox-port/XX-------------------------------->>>> http://ip:80/
      <--------------------------------------------------------------------------response
                        =================      firewal     =========
Server ---------------> |  proxy-relai  | <------//--------| relai | ------------>>>> hosts
                        =================                  =========
         proxy-hostname                 proxy-ip                            ( config h[borne]= [ip,port,path] )
             proxy-port                 proxy-port
\___________________________________________/          \_______________/           .............
           internet server                              server-in-intranet         intranet hosts
=end

#require 'minitcp'
require_relative 'minitcp/lib/minitcp.rb'

if ARGV.size<1
  puts"Usage>"
  puts"  #{$0} type hostname port"
  puts"  #{$0} proxyhttp  proxy-hostname proxy-port"
  puts"  #{$0} relai      proxy-saia-ip  proxy-saia-port  plugin"
  exit(1)
end

$opt,$host,$port=ARGV[0]||"proxyhttp",ARGV[1]||"localhost",ARGV[2]||80

NBDIGITHEAD=8
QUEUE_SIZE=100

def sformat(socket,mess) 
  socket.send("%-#{NBDIGITHEAD}d%s" % [mess.size,mess],0)
end
def receive(socket) 
        resp_length= socket.receive_n_bytes(NBDIGITHEAD)
        len   =resp_length.strip.to_i
        #log "header: #{resp_length} => #{len}"
        (len>0) ? socket.receive_n_bytes(len) : ""
end
def log(t) puts "%10s | %s" % [Time.now.to_s,t] end

if $opt=="proxyhttp"
##################################################################################
##                              P R O X Y
##################################################################################

$client_sockets ={} 
$queue=Queue.new
############# Proxy serveur http saia >>> machine distante #######################

MServer.service($port.to_i,"0.0.0.0",22) do |s_cli|
  
  begin relai=$queue.pop end until $client_sockets[relai]
  begin
    header=s_cli.receive_sep("\r\n\r\n")
    log("request...#{header.inspect}")
    if header.match(/^Content-length: (\d+)/i) || "0"=~/(.)/
      length=$1.strip.to_i
      log("length body==#{length}")
      body= length>0 ? s_cli.receive_n_bytes(length) : ""
      mess="#{header}\r\n\r\n#{body}"
      log("transmit request...")
        sformat(relai,mess) 
        log("wait response...")
        response= (timeout(5) { receive(relai) } rescue nil)
      log(response!=nil ? "response ok" : "timeout") unless response
      s_cli.write(response ? response : "HTTP/1.0 500 NOK\r\n\r\n")
    else
      s_cli.write( "HTTP/1.0 501 NOK\r\n\r\n")
    end
  ensure
    $queue.push(relai)
  end
end

############# serveur http  machine distante #######################

MServer.service($port.to_i+1,"0.0.0.0",22) do |s_cli|
  puts "> ======== relai is Connected ========"
  $client_sockets[s_cli]=true
  $queue.push s_cli
  s_cli.wait_end
  puts "> ======== relai deConnected "
  $client_sockets.delete(s_cli)
end

else

##################################################################################
##                              R E L A Y
##################################################################################
CONF="relai_config.data"
plugin=ARGV.last||"ocpp"
p plugin
$config=nil
$configtime=nil

def load_config()
  return if  $configtime!=nil && $configtime.to_f == File.mtime(CONF).to_f
  begin
    log("load config...")
    File.open(CONF) { |f| $config=eval( f.read.strip ) }
    log("load config ok, nb-host=#{$config.size} ...")
    $configtime=File.mtime(CONF)
  rescue
    log("Error loading configration : #{$!}")
  end
end

def transform_ocpp(request)
  load_config
  pos=0
  puts "recieved request #{request}"
  (log("request does not contain ChargeBoxId");return nil) unless pos=(request =~/ChargeBoxId/i) 
  (log("request does not contain ChargeBoxId");return nil) unless request[pos,pos+50] =~ /%3E(.*?)%3C/m 
  id=$1.strip
  ip=$config[id]
  (log("unknown CS #{id} in config"); return nil) unless ip
  request.sub!(/\?[^\s]*/,"")
  request.sub!(/GET [^\s]*/,"GET #{ip.last}") if ip.last!=""
  [*ip,request]
end

def transmit(ip,port=nil,path=nil,request=nil) 
  return "HTTP/1.0 404 NOK\r\n\r\n" unless request
  log("send data <#{request.inspect[0..70]}...\n    > to #{ip}:#{port}#{path} len=#{request.size}")
  response=nil
  MClient.run_one_shot(ip,port) { |socket| 
    socket.send(request,0)
    header=socket.receive_sep("\r\n\r\n")
    puts header
    response=header+"\r\n\r\n"+if header=~/Content-length: (\d+)/i && $1 && $1.to_i>0
      puts "with content-length #{$1}"
      socket.received_n_timeout($1.to_i,10) rescue "ERROR"
    else
      puts "until close"
      rep=""
      rep+=(a=socket.receive_any(1000_000)) until a==nil
      rep
    end
  }.join
  response
end

QUEUE_SIZE.times do
  MClient.run_continious($host,$port.to_i+1,1000) do |socket|
    nbr=0
    socket.on_n_receive(NBDIGITHEAD) do |header|
      p header
      nbr+=1
      len=header.strip.to_i
      #p len
      request=socket.receive_n_bytes(len)
      #p request
      response= transmit(*send("transform_#{plugin}",request))
      puts "replay with len=#{(response||"").size} <<<\n#{(response.inspect||"")[0..40]}..#{(response.inspect||"")[-40..-1]}\n>>"
      sformat( socket, response ? response : "NOK #{Time.now}")  
      (socket.close rescue nil) if nbr>100
    end
    socket.wait_end
  end
end

end
sleep
