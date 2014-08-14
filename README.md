Minitcp
===

Presentation
==

A little tool for doing some socket communication.

A simple TCP client :
```ruby
MClient.run_one_shot("localhost",2200) do |socket|
   socket.on_any_receive { |data| p "client recieved #{data.inspect}"}
   3.times { |j| socket.puts "Hello  #{j}..." ; sleep(1) }
end.join
```

A simple echo server
```ruby
srv=MServer.service(2200,"0.0.0.0",22) do |socket|
  socket.on_any_receive do |data| 
    puts "  Server recieved: #{data.inspect}" 
	socket.print(data)
  end
  socket.on_timer(2000) { socket.puts "CouCou say server @ #{Time.now}" rescue nil }
  socket.wait_end
  puts "  end server connection!"
end   
```

Client
==

```
MClient.run_one_shot(host,port) do |socket| ... end
MClient.run_continous(host,port,time_inter_connection) do |socket| ... end
```

Server
==

```ruby
srv=MServer.service(port,"0.0.0.0",max_client) do |socket| ... end
```

Sockets
==

Handlers are disponibles for any sockets : client or server. 
All handler bloc run in distinct thead : so any handler-bloc can wait anything
* **socket.on_any_receive() {|data| ...}**          : on receive some data, any size
* **socket.on_n_receive(sizemax=1) {|data| ...}**   : receives n byte only
* **socket.on_receive_sep(";") {|field | ... }**    : reveive data until string separator
* **socket.on_timer(value_ms) { ... }**             : each time do something, if socket is open

some primitives are here for help (no thread):
* **received_timeout(sizemax,timeout)** : wait for n bytes, with timeout, (blocking caller)
* **socket.after(duration) { ... }**    : d somethinf after n millisecondes, if socket is open
* **wait_end()**                        : wait, (blocking caller) until socket is close


Tests case
==

A tcp serveur which send some data to any client,
```ruby
		BasicSocket.do_not_reverse_lookup = true
		Thread.abort_on_exception = true
		puts "**********************************************************"
		puts "** Test basic, one client, multi client"
		puts "**********************************************************"
	   srv=MServer.service(2200,"0.0.0.0",22) do |socket|
		  socket.after(100) { socket.puts "Hello client" }
		  socket.on_any_receive { |data| puts "  Server recieved: #{data.inspect}" }
		  socket.on_timer(2000) { socket.puts "CouCou say server @ #{Time.now}" rescue nil }
		  puts "  srv waiting..."
		  socket.wait_end
		  puts "  end server connection!"
	   end   
```

Some clients which connect to a server, print any data received :

```ruby
	   
	   
	   (0..10).map do|i|
		 MClient.run_one_shot("localhost",2200) do |socket|
		   socket.on_any_receive { |data| p "Client #{i} recieved #{data.inspect}" }
		   3.times { |j| socket.puts "Hello from #{i} @ #{j}..." ; sleep(0.1) }
		 end
	   end.each {|th| th.join}
```

Test serial **protocole-like** : header/body => ack/timeout:
* client send <length><data> , wait one char ackit or timeout
* serveur receive heade( size: 4 chars) , then data with maxsize, send ack


```ruby
   
		puts "**********************************************************"
		puts "** Test serial protocole-like : header/body => ack/timeout"
		puts "**********************************************************"
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
   end
```


Traces :
```
**********************************************************
** Test serial protocole-like : header/body => ack/timeout
**********************************************************
[2200, "0.0.0.0", 22]
[Thu Aug 14 22:40:17 2014] MServer 0.0.0.0:2200 start
Sending 6 data...
[Thu Aug 14 22:40:17 2014] MServer 0.0.0.0:2200 client:44276 127.0.0.1<127.0.0.1> connect
  Server recieved buffer : "******"
  !!!non-ack by serv
"!!! timeout ack"
Sending 1 data...
  Server recieved buffer : "*"
  !!!non-ack by serv
"!!! timeout ack"
Sending 6 data...
  Server recieved buffer : "******"
"ack ok"
Sending 4 data...
  Server recieved buffer : "****"
  !!!non-ack by serv
"!!! timeout ack"
Sending 3 data...
  Server recieved buffer : "***"
  !!!non-ack by serv
"!!! timeout ack"
Sending 1 data...
  Server recieved buffer : "*"
  !!!non-ack by serv
"!!! timeout ack"
Sending 1 data...
  Server recieved buffer : "*"
"ack ok"
Sending 4 data...
  Server recieved buffer : "****"
"ack ok"
Sending 9 data...
  Server recieved buffer : "*********"
  !!!non-ack by serv
"!!! timeout ack"
Sending 3 data...
  Server recieved buffer : "***"
"ack ok"
"end client"
```
