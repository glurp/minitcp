Minitcp
===

Presentation
==

A little tool for doing some TCP/UDP sockets communications.

This tool have no pretention : it is not EventMachine ! : 

* no mainloop, 
* many threads are created/deleted.
* it is useful for send some data one-shot, test a ascii communication in few minutes...
* should be equivalent to netcat+bash ...


A  TCP client :

```ruby
MClient.run_one_shot("localhost",2200) do |socket|
   socket.on_any_receive { |data| p "client recieved #{data.inspect}"}
   3.times { |j| socket.puts "Hello  #{j}..." ; sleep(1) }
end.join
```

An echo server :

```ruby
srv=MServer.service(2200,"0.0.0.0",22) do |socket|
  socket.on_any_receive { |data|  socket.print(data) }
  socket.on_timer(2000) do
    socket.close
  end
  socket.wait_end
end
```

A UDP server

```ruby
	UDPAgent.on_datagramme("127.0.0.2",SRV_PORT ) { |data,from,p| 
	  puts "Agent: received #{data} from #{from}:#{p}" 
	  data && data.size>3 ? "OK-#{data}." : nil
	}
```

A UDP sender

```ruby
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
```


Docs: http://rubydoc.info/gems/minitcp


TCP
===

Client
---

```
MClient.run_one_shot(host,port) do |socket| ... end
MClient.run_continious(host,port,time_inter_connection) do |socket| ... end
```

Client socket is extended with all specifiques commandes (```SocketReactive```, see Sockets).

Server
---

```ruby
srv=MServer.service(port,"0.0.0.0",max_client) do |socket| ... end
```
Mserver run a GServer. 
Connected sockets are extended with same module as in client.

Sockets
---

Handlers are disponibles for any sockets : client or server. 
All handler's bloc run in distinct thread : so any handler-bloc can wait anything.
if socket is closed, handler/thread are cleanly (?) stoped.

* socket.**on_any_receive() {|data| ...}**          : on receive some data, any size
* socket.**on_n_receive(sizemax=1) {|data| ...}**   : receives n byte(s) only
* socket.**on_receive_sep(";") {|field | ... }**    : reveive data until string separator
* socket.**on_timer(value_ms) { ... }**             : each time do something, if socket is open
* socket.**after(duration) { ... }**    : do something after n millisecondes, if socket is open

Some primitives are here for help (no thread):

* **received_timeout(sizemax,timeout)** : wait for n bytes, with timeout, (blocking caller),
* **wait_end()**                        : wait, (blocking caller) until socket is close. this
  work only if something has closed the socket.this is possible unicly by receiving 0 bte on a
* **receive_n_bytes** / **on_receive_sep** : bocking version of handler,
* **connected?** : test if a close have been done,  
* **data_readed()** : some receives (receive_sep...) can read more data form sockets,
 this data are used by ```n_revieve/any_receive/receive_sep```, but they can be read/reseted 
 whith data_readed getseter.

This primitives are declared in SocketReactive module.

UDP
===

2 type of agents : 

* **Server** : receive data from anywhere, can reply to sender
* **Timer**  : emit to everybody, can receive response from them

3 primiitves :

* **send_datagram(host,port,message)** : create a socket, send mesage and close socket (ca'nt receive a reply)
* **send_datagram_on_socket(socket,host,port,message)** : use existant socket for send a message to ip:port


TODO
==

* Serial line
* more socket primitive


Tests case
==
A TCP proxy, debug tool (see samples/proxy.rb) :

```ruby
MServer.service(2200,"0.0.0.0",22) do |scli|
  px 2, "======== client Connected ========"
  srv=MClient.run_one_shot("ip",2200) do |ssrv|
     px 1, "======== server Connected ========"
     ssrv.on_any_receive { |data| px 1,data; scli.print data }
     scli.on_any_receive { |data| px 2,data; ssrv.print data}
     ssrv.wait_end
     scli.close rescue nil
  end
  scli.wait_end
  srv.stop rescue nil
end   
def px(sens,data)
  data.each_line {|line| puts "#{(sens==1 ? "> " : "< ")}#{line.chomp}"
end

```




Test serial **protocole-like** : header/body => ack/timeout:

* client send <length><data> , wait one char acquit or timeout
* serveur receive heade( size: 4 chars) , then data with size, send ack


```ruby
   
srv=MServer.service(2200,"0.0.0.0",22) do |socket|
  socket.on_n_receive(4) { |data| 
     size=data.to_i
     data=socket.recv(size)
     puts "  Server recieved buffer : #{data.inspect}"
     if rand(100)>50
        socket.print("o") 
     else 
        puts "  !!!non-ack by serv"
     end
  }
  socket.on_timer(40*1000) { puts " serv close after 40 seconds"; socket.close }
  socket.wait_end
end   

MClient.run_one_shot("localhost",2200) do |socket|
   10.times { |j| 
	   size=rand(1..10)
	   puts "Sending #{size} data..."
	   data='*'*size
	   socket.print "%04d" % size
	   socket.print data 
	   p socket.received_timeout(1,100)  ? "ack ok" : "!!! timeout ack"
   }
   p "end client"
end.join


```

