# LGPL
require_relative 'lib/minitcp.rb'

BasicSocket.do_not_reverse_lookup = true
Thread.abort_on_exception = true


if ARGV.size==0 || ARGV[0]=="1"
  puts "**********************************************************"
  puts "** Test basic, one client, multi client, any receive"
  puts "**********************************************************"
  srv=MServer.service(2200,"0.0.0.0",22) do |socket|
    socket.after(100) { socket.puts "Hello client" }
    socket.on_any_receive { |data| puts "  Server recieved: #{data.inspect}" }
    socket.on_timer(2000) { socket.puts "CouCou say server @ #{Time.now}" rescue nil }
    puts "  srv waiting..."
    socket.wait_end
    puts "  end server connection!"
  end   
  MClient.run_one_shot("localhost",2200) do |socket|
   socket.on_any_receive { |data| p "client recieved #{data.inspect}"}
   p "connected in client"
   3.times { |j| socket.puts "Hello  #{j}..." ; sleep(1) }
   p "end client"
  end.join
  puts "server connection should be stoped !!!"
  sleep(1) 
  puts "\n"*5
  sleep(1)
  srv.stop rescue nil
  sleep(3)
  puts "Tread list : #{Thread.list} / current= #{Thread.current.inspect}"
end

if  ARGV.size==0 || ARGV[0]=="2" 
  puts "**********************************************************"
  puts "** Test serial protocole-like : header/body => ack/timeout"
  puts "**********************************************************"
  srv=MServer.service(2200,"0.0.0.0",22) do |socket|
    socket.on_n_receive(11) do |data| 
      s,data=data[0,1],data[1..-1]
      (socket.close; next) if s!="e"
      size=data.to_i
      puts "     Server waiting for #{size} Bytes of data"
      socket.received_timeout(size,100_000) do |data|
       puts "     Server recieved buffer : #{data.size} Bytes"
       puts "     emit ack..."
       socket.send("o",0) 
      end
    end
    #socket.on_timer(120*1000) { puts " serv close after 40 seconds"; socket.close }
    socket.wait_end
  end   
  MClient.run_one_shot("localhost",2200) do |socket|
   30.times { |j| 
     size=rand((j+1)*100..(j+1)*100000)
     puts "Sending #{size} data..."
     data='%'*size
     socket.print "e%010d" % size
     while data && data.size>0
       s,data=data[0..(1024-1)],data[1024..-1]
       socket.send s,0
     end 
     p socket.received_timeout(1,[size/1000,1000].max)  ? "ack ok" : "!!! timeout ack"
     #puts "\n"*7
   }
   p "end client"
  end.join
  sleep 1
  puts "\n"*3
  sleep 3
  puts "srv stop..."
  srv.stop rescue nil
  sleep 1
  puts "Tread list : #{Thread.list} / current= #{Thread.current.inspect}"
end

if ARGV.size==0 || ARGV[0]=="3"
  puts "**********************************************************"
  puts "** Test tcp proxy : one echo server, one proxy, on client"
  puts "**********************************************************"

  srv1=MServer.service(2201,"0.0.0.0",22) do |socket|
    socket.on_any_receive { |data| socket.puts "ECHO:#{data}" }
    socket.on_timer(2000) { socket.puts "Hello say server @ #{Time.now}" rescue nil }
    socket.on_timer(4000) { socket.puts "byebye" rescue nil; socket.close rescue nil }
    socket.wait_end
  end   

  srv2=MServer.service(2200,"0.0.0.0",22) do |s_cli|
    puts "> ======== client Connected ========"
    srv=MClient.run_one_shot("127.0.0.1",2201) do |s_srv|
       puts "< ======== server Concected ========"
       s_srv.on_any_receive { |data| puts "< "+data; s_cli.print data }
       s_cli.on_any_receive { |data| puts "> "+data; s_srv.print data}
       s_srv.wait_end
       s_cli.close rescue nil
    end
    s_cli.wait_end
    p "end cli, stop proxy"
    srv.kill
  end
  sleep 1
   MClient.run_one_shot("localhost",2200) do |socket|
     socket.on_any_receive { |data| p "client recieved #{data}"}
     p "connected in client"
     10.times { |j| socket.print "C#{j} #{"+"*j*3}" ; sleep(0.1) }
     p "end client"
   end.join

  sleep 1
  puts "\n"*3
  sleep 3
  puts "srv stop..."
  srv1.stop rescue nil
  srv2.stop rescue nil
  sleep 1
  puts "Tread list : #{Thread.list} / current= #{Thread.current.inspect}"
end

if ARGV.size==0 || ARGV[0]=="4"
  puts "**********************************************************"
  puts "** Test sending with separator"
  puts "**********************************************************"
  $tm=Time.now
  srv=MServer.service(2200,"0.0.0.0",22) do |socket|
    l,ll=[],[]
    socket.on_receive_sep(/([\.;$!])/) { |(data,sep)| 
      case sep
        when ";" then l << data
        when "." 
            ll << l ; l=[] 
        when "$" 
            p ll ; ll=[]   
            puts "Latency: #{(Time.now.to_f - $tm.to_f)*1000} ms"
            socket.receive_n_bytes(10) { |data| p data }
        when "!"
            socket.close 
      end
    }
    socket.wait_end
  end   
   MClient.run_one_shot("localhost",2200) do |socket|
     p "connected in client"
     $tm=Time.now
     p 1; 4.times { |j| 3.times { |p| socket.print "#{j}/#{p};" } ; socket.print(".") } 
     socket.print '$1234567890'
     $tm=Time.now
     p 2; 4.times { |j| 3.times { |p| socket.print "#{j}/#{p};" } ; socket.print(".") } 
     socket.print '$1234567890!'
     p "end client"
   end.join

  sleep 1
  puts "\n"*3
  sleep 3
  puts "srv stop..."
  srv.stop rescue p $!
  sleep 1
  puts "Tread list : #{Thread.list} / current= #{Thread.current.inspect}"
end


if ARGV.size==0 || ARGV[0]=="5"
  SRV_PORT=2234
  ## ############################# Client UDP : send datagram to anybody, serv response from them
  
  UDPAgent.on_timer(1000, 
    port: 2232,
    on_timer: proc do
      data=Time.now.to_i.to_s
      puts "\n\n\non timer send <#{data}>"
      {mess: data,host: "127.0.0.2",port: SRV_PORT}
    end,
    on_receive: proc { |data,from,sock| 
      puts "Client: received #{data} from #{from}"  
      UDPAgent.send_datagram_on_socket(sock,from.last,from[1],'ack')
    }
  )
  
  ## ############################# Server UDP : receive datagrram from anybody, response to sender
  
  UDPAgent.on_datagramme("127.0.0.2",SRV_PORT ) { |data,from,p| 
    puts "Agent: received #{data} from #{from}:#{p}" 
    data && data.size>3 ? "OK-#{data}." : nil
  }
  sleep 1
  UDPAgent.send_datagram("127.0.0.2",SRV_PORT,"Hello")
  sleep 10
end

puts "Test End !"
