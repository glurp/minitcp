# LGPL,  Author: Regis d'Aubarede <regis.aubarede@gmail.com>
#################################################################
#  relay.rb : estabish connexion between 2 agents
#  One agent open a (http like) connection as 'server', with his name
#  A 'client' ask a connection to a 'server', with the name of server
#     if sever connection is alive
#        server receive an 'CONNECTED' message,with the name of client
#        socket server is IO.copy with client socket
#        server should establish a new 'server' connection for other client
#
#
#################################################################
require_relative '../lib/minitcp.rb'

BasicSocket.do_not_reverse_lookup = true
Thread.abort_on_exception = true

$SIZE=30
$dico_name={}
$dico_ip={}

def run_net_relay()
  MServer.service(4410,"0.0.0.0",1000) do |socket| 
    socket.on_n_receive($SIZE) do |data|
      ip=socket.remote_address.ip_address
      cmd,url,http=data.split(' ')  
      name,method,*args=url.split('/').last
      next if cmd!="GET"  
      case method
      when "server"
        old=ActiveConnection.search(name)
        if old && old.state==:free
           old.deconnect
           old=nil
        end
        if !old || old.state==:connected
          ActiveConnection.add(socket)
        end
      when "client"
        if srv=ActiveConnection.search(args.first)
          srv.connect_to(name)
        else
          smess("NOTCONNECT")
        end
      end
      rep=""
    end
  end
end

def smess(socket,*args)
    data=  args.join(";")+";"
    socket.send(data+" "*($SIZE-data.length),0) rescue p $!
end

def run_server_name()
  MServer.service(4400,"0.0.0.0",100) do |socket| 
    socket.on_n_receive($SIZE) do |data|
      ip=socket.remote_address.ip_address
      cmd,*args=data.split(";")  
      name=args.first
      rep=""
      case cmd
        when "update"
          $dico_name[name]=ip
          $dico_ip[ip]=name
          rep="OK"
        when "forget"
          oldip=$dico_ip[ip]
          if oldip && $dico_ip[ip]==name && $dico_name[name]==ip
            $dico_name.delete(name)
            $dico_ip.delete(ip)
            rep="OK"
          end
        when "get"
          rep=$dico_name[name].to_s
        when "geti"
          rep=$dico_ip[name].to_s
      end
      rep.size>0  ? smess(socket,"ACK",name,rep) : smess(socket,"NACK","NOK","NOK")
    end
    socket.after(10*1000) { socket.close rescue nil}
    socket.wait_end
  end
end

################# Client api ########################

if $0==__FILE__
  run_server_name
  
  Thread.new { 4.times { update_server_name("glurp") ; sleep 1 } }
  Thread.new { 4.times { update_server_name("glurp22") ; sleep 1 } }

  sleep 2
  puts "\n\n***************** get name *******************\n\n"

  p fetch_name("glurp")
  p fetch_ip("127.0.0.1")
  forget_me("glurp22")
  sleep
end
