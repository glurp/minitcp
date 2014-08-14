# LGPL,  Author: Regis d'Aubarede <regis.aubarede@gmail.com>
#
##############################################################
# minitcp.rb
##############################################################

require 'thread'
require 'socket'
require 'gserver'
require 'timeout'


module SocketReactive
	TICK=50
	def make_socket_reactive(socket)
	  def socket.received_timeout(sizemax,timeout)
		timeout(timeout/1000.0) {
		   buff=""
		   data=(self.recv(sizemax) rescue return nil)
		   if data && data.size>0
			  buff+=data
			  sizemax-=data.size
			  if sizemax<=0
				if  block_given?
				  return yield(buff) 
				else
				  return buff
				end
			  end
		   end
		} rescue return nil
	  end
	  def socket.on_any_receive()
	    Thread.new() do
		   loop {
			   data=(self.recv(64*1024) rescue nil)
			   if data && data.size>0
				  yield(data)
			   else
			      break
			   end
		   }
		end
	  end
	  def socket.after(duration)
	    Thread.new() do
			sleep(duration/1000)
			yield unless self.closed?
		end
	  end
	  def socket.on_n_receive(sizemax=1)
	    Thread.new() do
		   s=sizemax
		   buff=""
		   loop {
			   data=(self.recv(s) rescue nil)
			   if data && data.size>0
			      buff+=data
				  s-=data.size
				  if s<=0
					yield(buff)
					buff=""
					s=sizemax
				  end
			   else
			      break
			   end
		   }
		end
	  end
	  def socket.on_receive_sep(separator,sizemax=1024)
	    Thread.new() do
		   buff=""
		   loop do
			   data=(self.recv(sizemax) rescue nil)
			   if data && data.size>0 
			    buff+=data
				a=(buff).split(separator,2)
				if a.size==2
				    buff=data.last
					yield(a.first) 
				end
			   else
			     break
			   end
		   end
		end
	  end
	  def socket.on_timer(value=1000)
	    Thread.new() {
		   nbtick=(value/TICK)+1
		   loop do
		       i=0
		       (i+=1;sleep(TICK/1000.0)) while (! self.closed?()) && i<nbtick
			   unless self.closed?
					yield() 
			   else
			     break;
			   end
		   end
		}
	  end
	  def socket.wait_end()
	      loop do
			  begin
				sleep(TICK/1000.0) while recv_nonblock(0) 
			  rescue Errno::EAGAIN
			  rescue Errno::EWOULDBLOCK
			  rescue Exception  => e
				break
			  end
		  end
	  end
    end # end make... 
end

class MClient
	extend SocketReactive
	def self.run_continous(host,port,timer_interconnection,&b)
	  Thread.new do
		  loop { run_one_shot(host,port,&b).join ; sleep timer_interconnection }
	  end
    end	
	
	def self.run_one_shot(host="localhost",port=80) 
		begin
		  socket = TCPSocket.new(host,port)
		rescue
		  puts "not connected to #{host}:#{port}: " + $!.to_s
		  return (Thread.new {})
		end
		make_socket_reactive(socket)
		Thread.new do
			begin
			  yield(socket)
			rescue Exception => e
				puts "#{e}\n  #{e.backtrace.join("\n  ")}"
			ensure
			  socket.close() rescue nil
			end
		end
	end
end

#Mserver( "8080" , "0.0.0.0" ,1) { |socket| loop { p socket.gets} }
class MServer < GServer
  include SocketReactive
  def self.service(port,host,max,&b)
     p [port,host,max]
     srv=new(port,host,max,&b)
	 srv.audit = true 
	 srv.start
	 srv
  end
  def initialize(port,host,max=1,&b)
     super(port,host,max)
	 @bloc=b
  end
  def serve( io )
	make_socket_reactive(io)
    begin
		@bloc.call(io)
    rescue Exception => e
		puts  "Error Mserver bloc: #{e} :\n  #{e.backtrace.join("\n  ")}"
    end
  end
end

if $0==__FILE__
    BasicSocket.do_not_reverse_lookup = true
    Thread.abort_on_exception = true
	if ARGV.size==0 || ARGV[0]=="1"
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
	   MClient.run_one_shot("localhost",2200) do |socket|
		   socket.on_any_receive { |data| p "client recieved #{data.inspect}"}
		   p "connected in client"
		   3.times { |j| socket.puts "Hello  #{j}..." ; sleep(1) }
		   p "end client"
	   end.join
	   puts "server connection should be stoped !!!"
	   
	   
	   sleep 5
	   puts "\n"*5
	   puts "\n\n*************** 10 times in // ****************\n\n"
	   (0..10).map do|i|
		 MClient.run_one_shot("localhost",2200) do |socket|
		   socket.on_any_receive { |data| p "Client #{i} recieved #{data.inspect}" }
		   3.times { |j| socket.puts "Hello from #{i} @ #{j}..." ; sleep(0.1) }
		 end
	   end.each {|th| th.join}
	   puts "\n"*5
	   sleep(5)
	   srv.stop
	   sleep(5)
	   p Thread.current
	   p Thread.list
   end
   if  ARGV.size==0 || ARGV[0]=="2" 
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
   sleep 3
   srv.stop
   sleep 3
   p Thread.list if Thread.list .size>1
   puts "End."
end
