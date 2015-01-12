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

require 'minitcp'
#require_relative 'minitcp/lib/minitcp.rb'

if ARGV.size<1
  puts"Usage>"
  puts"  #{$0} type       hostname       port"
  puts"  #{$0} proxyhttp  proxy-hostname proxy-port"
  puts"  #{$0} relai      proxy-saia-ip  proxy-port  plugin"
  exit(1)
end

$opt,$host,$port=ARGV[0]||"proxyhttp",ARGV[1]||"localhost",ARGV[2]||80

NBDIGITHEAD=8
QUEUE_SIZE=10

def sformat(socket,mess) 
  puts "sformat message len=#{mess.size} #{mess.inspect[0..30]}..."
  data=("%-#{NBDIGITHEAD}d%s" % [mess.size,mess])
  socket.send(data,0)
end

def sformat0(socket,mess) 
  data=("%-#{NBDIGITHEAD}d%s" % [mess.size,mess])
  l=socket.send(data,0)
end
def receive(socket) 
  log "r1 len=#{NBDIGITHEAD} #{socket}"
  resp_length= socket.receive_n_bytes(NBDIGITHEAD)
  return nil unless resp_length
  len   =resp_length.strip.to_i
  log "header: #{resp_length} => #{len}"
  (len>0) ? socket.receive_n_bytes(len) : ""
end
def receive_to(socket,to=1000) 
  begin
    timeout(to/1000.0) {
      #log "r1 len=#{NBDIGITHEAD} #{socket}"
      resp_length= socket.receive_n_bytes(NBDIGITHEAD)
      return nil unless resp_length
      len   =resp_length.strip.to_i
      #log "header: #{resp_length} => #{len}"
      (len>0) ? socket.receive_n_bytes(len) : ""
    } 
  rescue Exception => e
    return(nil)
  end
end
def log(t) puts "%10s | %s" % [Time.now.to_s,t] end

if $opt=="proxyhttp"
##################################################################################
##                              P R O X Y : extranet side
##################################################################################

$client_sockets ={} 
$queue=Queue.new
############# Proxy serveur http saia >>> machine distante #######################
def relai_command(mess)
  relai=nil
  begin
    loop  {
      begin relai=$queue.pop end until $client_sockets[relai]
      sformat(relai,"SDV")
      break if receive_to(relai,1000)!=nil
    }
    log("getted relai #{relai}")
    sformat(relai,mess) 
    log("wait response...")
    receive_to(relai,9000)
  ensure
    $queue.push(relai) if relai
  end
end

MServer.service($port.to_i,"0.0.0.0",22) do |s_cli|
  log("telecommande")
  timeout(10) {
    begin
      header=s_cli.receive_sep("\r\n\r\n")
      #log("request header=#{header.inspect}")
      if header.match(/^Content-Length: (\d+)/i) || "0"=~/(.)/
        length=$1.strip.to_i
        #log("length body==#{length}")
        body= length>0 ? s_cli.receive_n_bytes(length) : ""
        #log("request body=#{body.inspect}")
        mess="#{header}\r\n\r\n#{body}"
        log("transmit request...")
        response=relai_command(mess)
        log(response!=nil ? "response ok" : "timeout") unless response
        s_cli.write(response ? response : "HTTP/1.0 500 NOK\r\n\r\n")
      else
        s_cli.write( "HTTP/1.0 501 NOK\r\n\r\n")
      end
    rescue Exception => e
     puts "global error: #{e} #{}"
    end
  }
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

#-- signe de vie sur chaque socket du pool

Thread.new { loop {
  begin relai=$queue.pop end until $client_sockets[relai]
  #puts "testing #{relai}..."
  sformat0(relai,"SDV")
  receive_to(relai,1000)
  sleep(0.1)
  if $client_sockets[relai]
    $queue.push(relai)
    sleep 5
  else
    puts "testing socket pool:  nok"
  end
} }
else

##################################################################################
##                              R E L A Y : intranet side
##################################################################################
CONF="relai_config.data"
$plugin=ARGV.last||"ocpp"
$config=nil
$configtime=nil
=begin
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Header>
    <chargeBoxIdentity xmlns="urn://Ocpp/Cp/2012/06/">TEST1</chargeBoxIdentity>
    <Action xmlns="http://www.w3.org/2005/08/addressing">/ChangeAvailability</Action>
    <MessageID xmlns="http://www.w3.org/2005/08/addressing">urn:uuid:4efc4b17-6fc0-4a91-bf0b-153ecbc03cd0</MessageID>
    <To xmlns="http://www.w3.org/2005/08/addressing">http://localhost:7700/</To>
    <ReplyTo xmlns="http://www.w3.org/2005/08/addressing">
       <Address>http://www.w3.org/2005/08/addressing/anonymous</Address>
    </ReplyTo>
  </soap:Header>
  <soap:Body><changeAvailabilityRequest xmlns="urn://Ocpp/Cp/2012/06/">
    <connectorId>1</connectorId>
    <type>Operative</type>
    </changeAvailabilityRequest>
  </soap:Body>
</soap:Envelope>
=end
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
def verify_request_ocpp(request)
  (log("request does not contain ChargeBoxId0");return false) unless request =~/chargeBoxIdentity/i
  return(true)
end
def transform_ocpp(request)
  load_config
  (log("request does not contain valid ChargeBoxId");return nil) unless request =~ /chargeBoxIdentity.*?>(.*?)<\/.*?chargeBoxIdentity/
  chargeboxIdentity=$1.strip
  ip=$config[chargeboxIdentity] # [ip,port,path]
  unless ip
    p request
    log("unknown CS #{chargeboxIdentity} in config")
    nil
  else
    #request.gsub!(
    #   %r{(<To[^>]*>http://)([^<]*)(</To>)},
    #   "\\1#{ip[0]}:#{ip[1]}#{ip[2]}\\3"
    #)
    #puts request
    ip+[request] # return [ip, port, path, request]
  end
end

def transmit(ip,port=nil,path=nil,request=nil) 
  return "HTTP/1.0 404 NOK\r\n\r\n"  unless request
  
  #log("send data <#{request.inspect[0..70]}...\n    > to #{ip}:#{port}#{path} len=#{request.size}")
  response=nil
  begin
    timeout(5) do
      MClient.run_one_shot(ip,port) { |client| 
        client.send(request,0)
        header=client.receive_sep("\r\n\r\n")
        if header=~/Content-Length: (\d+)/i  && $1.to_i>0
          log( "receive data with content-length #{$1}")
          begin
            data_response=client.received_timeout($1.to_i,3000) 
          rescue
            log($!.to_s)
            data_response="ERROR_TIMEOUT"
          end
        else
          puts "until close"
          rep=""
          rep+=(a=client.receive_any(1000_000)) until a==nil
          data_response=rep
        end
        #log( "data_response="+data_response)
        response=header+"\r\n\r\n" + data_response
      }.join
      response
    end
  rescue Exception => e
    p e
    nil
  end
end

QUEUE_SIZE.times do
  MClient.run_continious($host,$port.to_i+1,1000) do |socket|
    nbr=0
    puts "connected..."
    socket.on_n_receive(NBDIGITHEAD) do |header|
      #p header
      nbr+=1
      len=header.strip.to_i
      #p len
      request=socket.receive_n_bytes(len)
      #p request
      if request!="SDV" && send("verify_request_#{$plugin}",request)
        ip,port,path,request=send("transform_#{$plugin}",request)
        response= transmit(ip,port,path,request)
        puts "\n\nreplay with len=#{(response||"").size} <<<\n#{(response.inspect||"")[0..150]}..#{(response.inspect||"")[-40..-1]}\n>>"
        sformat( socket, response ? response : "NOK #{Time.now}\r\n")
      else 
        sformat(socket,"OK")
        print "."
      end
    end
    socket.wait_end
    puts "deconnected."
  end
end

end
sleep
