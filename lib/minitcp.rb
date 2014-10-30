# LGPL,  Author: Regis d'Aubarede <regis.aubarede@gmail.com>
#
##############################################################
# minitcp.rb
##############################################################

require 'thread'
require 'timeout'
require 'socket'
require 'gserver'


module SocketReactive

  def data_readed=(v) @data_readed=v end
  def data_readed()   @data_readed||="" end

  # read n byte, block the caller, return nil if socket if close
  # if block is defined, it is yield with data, method return whith the value of yield
  # if looping is true, the method loop until socket close, (or current thread is killed)
  def receive_n_bytes(sizemax,looping=false,&b)
    s=sizemax
    if self.data_readed.size>=sizemax
      buff,self.data_readed=self.data_readed[0..sizemax-1],self.data_readed[sizemax..-1]
      buff=b.call(buff) if block_given?
      return buff unless looping
    end
    s=sizemax-self.data_readed.size
    loop do
      #p ["waiting ",s,data_readed]
      sd=s>1024 ? 1024 : s
      data=(self.recv(sd) rescue nil)
      #p "nrec: w#{sizemax}/ rec:#{(data||'').size} / #{sd} old=#{data_readed.size} /// #{(data||'').size<70 ? data : "."}"
      if data && data.size>0
        self.data_readed=self.data_readed+data
        s=sizemax-self.data_readed.size
        if s<=0
          buff,self.data_readed=self.data_readed,""
          s=sizemax
          buff=b.call(buff) if block_given?
          return buff unless looping
        end
      else
        close rescue nil
        break # socket close
      end
    end #loop
  end
  # wait n byte or timeout. if block is defined, it is yielded with data
  # return nil if timeout/socket closed, or data if no bloc, or yield value
  def received_n_timeout(sizemax,timeout_ms,&b)
    timeout(timeout_ms/1000.0) {
      ret=receive_n_bytes(sizemax,false,&b)
      return ret
    }
  rescue Timeout::Error
    return nil
  rescue Exception => e
    $stdout.puts  "#{e} :\n  #{e.backtrace.join("\n  ")}"
  end
  
  def received_any_timeout(sizemax,timeout_ms)
    timeout(timeout_ms/1000.0) {
      return recv(sizemax)
    }
  rescue Timeout::Error
    return nil
  rescue Exception => e
    $stdout.puts  "#{e} :\n  #{e.backtrace.join("\n  ")}"
  end

  # async wait and read data on socket, yield values readed,
  # return thread spawned, which can be kill
  def on_any_receive()
    Thread.new() do
      begin
        if self.data_readed.size>0
          buff,self.data_readed=self.data_readed,""
          yield(buff)
        end
        loop do
          data=(self.recv(64*1024) rescue nil)
          data && data.size>0 ? yield(data) : break
        end
      rescue Exception => e
        $stdout.puts  "#{e} :\n  #{e.backtrace.join("\n  ")}"
      end
      close rescue nil
    end
  end


  # async yield on received n bytes
  # return thread spawned, which can be kill
  def on_n_receive(sizemax=1,&b)
    Thread.new() do
      begin
        receive_n_bytes(sizemax,true,&b)
      rescue Exception => e
        $stdout.puts  "#{e} :\n  #{e.backtrace.join("\n  ")}"
      end
    end
  end

  # read until separator reached, block the caller, return nil if socket is close
  # if block is defined, it is yield with data, method return whith the value of yield
  # if looping is true, the method loop until socket close, (or current thread is killed)
  # this read some extra data. they can be retrieve with in socket.data_readed.
  # data_readed is use for next calls to receives_n_byte/receive_sep
  def receive_sep(separator,sizemax=1024,looping=false,&b)
    if self.data_readed.size>0
      a=self.data_readed.split(separator,2)
      while a.size>1
        buff= a.size>2 ? a[0..-2] : a.first
        self.data_readed=a.last
        buff=b.call(buff) if block_given?
        return buff unless looping
        a=self.data_readed.split(separator,2)
      end
    end
    loop do
      data=(self.recv(sizemax-self.data_readed.size) rescue nil)
      if data && data.size>0
        self.data_readed=self.data_readed+data
        a=(self.data_readed).split(separator,2)
        while a.size>1
          buff= a.size>2 ? a[0..-2] : a.first
          self.data_readed=a.last
          buff=b.call(buff) if block_given?
          return buff unless looping
          a=(self.data_readed).split(separator,2)
        end
      else
        close rescue nil
        break
      end
    end
  end

  # async yield on received data until end-buffer string
  # end-buffer can be string or regexp (args of data.split(,2))
  # return thread spawned, which can be kill
  # this read some extra data. they can be retrieve with in socket.data_readed.
  # data_readed is use for next calls to receives_n_byte/receive_sep
  def on_receive_sep(separator,sizemax=1024,&b)
    Thread.new() do
      begin
        receive_sep(separator,sizemax,looping=true,&b)
      rescue Exception => e
        $stdout.puts  "#{e} :\n  #{e.backtrace.join("\n  ")}"
      end
    end
  end

  # async yield after a duration, if socket is open
  # return thread spawned, which can be kill
  def after(duration_ms)
    Thread.new() do
      begin
        sleep(duration_ms/1000.0)
        yield unless self.connected?()
      rescue Exception => e
        $stdout.puts  "#{e} :\n  #{e.backtrace.join("\n  ")}"
      end
    end
  end

  # async yield periodicaly, if socket is open
  # return thread spawned, which can be kill
  def on_timer(value=1000)
    Thread.new() {
      begin
        nbtick=(value/TICK)+1
        loop do
          i=0
          sleep(TICK/1000.0) while self.connected?() && (i+=1)<nbtick
          self.connected?() ? yield() : break
        end
      rescue Exception => e
        $stdout.puts  "#{e} :\n  #{e.backtrace.join("\n  ")}"
      end
    }
  end

  # wait until curent socket is close.
  def wait_end()
    begin
      loop do
        sleep(TICK/1000.0) while (self.connected?() rescue nil)
        break
      end
    rescue Exception => e
    end
  end

  # Test if a socket is open. (use socket.remote_address() !)
  def connected?()
    (self.remote_address rescue nil) ? true : false
  end
  # duration of sleep when active wait (wait_end,on_timer...)
  TICK=600

  def self.make_socket_reactive(socket)
    socket.extend(SocketReactive)
    socket.data_readed=""
  end
end

# Assure connection to server, extend socket connection by SocketReactive module.
#
#	MClient.run_one_shot("localhost",2200)       do |socket| .. end.join
#
#	MClient.run_continous("localhost",2200,6000) do |socket| .. end.join
#
class MClient
  # maintain a conntection to a TCP serveur, sleep timer_interconnection_ms millisecondes
  # beetwen each reconnections 
  def self.run_continious(host,port,timer_interconnection_ms,&b)
    Thread.new do
      loop { run_one_shot(host,port,&b).join ; sleep timer_interconnection_ms/1000.0 }
    end
  end

  def self.run_continous(host,port,timer_interconnection,&b)
    self.run_continious(host,port,timer_interconnection,&b)
  end

  # Connecte to a TCP server, call block with client socket if connection sucess.
  # enssure close connection after end of block
  def self.run_one_shot(host="localhost",port=80)
    begin
      sleep(0.03) # give some time for server ready (for test...)
      socket = TCPSocket.new(host,port)
    rescue
      puts "not connected to #{host}:#{port}: " + $!.to_s
      return (Thread.new {})
    end
    SocketReactive::make_socket_reactive(socket)
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


# Assure connection to server, extend socket connection by SocketReactive module.
#
#	MClient.run_one_shot("localhost",2200)       do |socket| .. end.join
#
#	MClient.run_continous("localhost",2200,6000) do |socket| .. end.join
#
class UDPAgent
  # maintain a conntection to a TCP serveur, sleep timer_interconnection_ms millisecondes
  # beetwen each reconnections 
  def self.send_datagram(host,port,mess)
        sock = UDPSocket.new
        #p ["sock.send",mess, 0, host, port]
        sock.send(mess, 0, host, port)
        sock.close
  end
  def self.send_datagram_on_socket(socket,host,port,mess)
        socket.send(mess, 0, host, port)
  end

  Thread.abort_on_exception=true

  # send datagram on timer
  def self.on_timer(periode,options)
    Thread.new do 
      sleep periode/1000.0
      sock = UDPSocket.new
      if options[:port]
        sock.bind("0.0.0.0", options[:port])
      end
      loop do
        rep=IO.select([sock],nil,nil,periode/1000.0)
        #puts  "IO.SELECT => #{rep}"
        if rep
          Thread.new {
               data,peer=sock.recvfrom(1024)
               options[:on_receive].call(data,peer,sock)
          } if options[:on_receive]
        elsif options[:on_timer]
          h=options[:on_timer].call()
          self.send_datagram_on_socket(sock,h[:host], h[:port],h[:mess]) if h && h[:mess] && h[:host] && h[:port]
        end
      end
    end
  end
  # recieved UDP datagramme, bloc can ellaborate a reply, which will be sending to client
  def self.on_datagramme(host,port)
    serv = UDPSocket.new
    serv.bind(host, port)
    Thread.new do
      loop do
        begin
        Thread.new(*serv.recvfrom(1024)) do |data,peer|  # peer=["AF_INET", 59340, "127.0.0.1", "127.0.0.1"]
            proto,cli_port,srv_addr,cli_addr=*peer
            response=yield(data,cli_addr,cli_port)
            self.send_datagram_on_socket(serv,cli_addr,cli_port,response) if response
        end
        rescue Exception => e
          puts "#{e}\n  #{e.backtrace.join("\n  ")}"
        ensure
        end
      end
    end
  end
end

# Run a TCP serveur, with a max connection simultaneous,
# When connection succes, call the bloc given with socket (extended by SocketReactive).
#
# MServer.new( "8080" , "0.0.0.0" ,1) { |socket| loop { p socket.gets} }
class MServer < GServer
  def self.service(port,host,max,&b)
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
    SocketReactive::make_socket_reactive(io)
    begin
      @bloc.call(io)
    rescue Exception => e
      puts  "Error in Mserver block: #{e} :\n  #{e.backtrace.join("\n  ")}"
    end
  end
end

##########################################################
# messages stream
##########################################################

module SocketMessage
	def on_message(timeout=nil,&b)
		on_n_receive(6) do |head| 
			len=head.to_i
			received_n_timeout(len,10_000) do |data|
				response=b.call(eval(data))
				send(response) if response
			end
	  end
  end
	def send_message(message)
		data=message.inspect
		send(("%6d" % data.size)+data,0)		
	end
end

class MClientAgent
  def self.run(host,port,&b) 
    me=MClientAgent.new
	  MClient.run_continious(host,port,10_000) do |so|
      so.extend(SocketMessage)
      me.instance_eval { b.call(so) }
	  end
  end
end

class MServerAgent
 def self.run(port,host,n,&b)
   me=MClientAgent.new
   MServer.service( port , host ,n) do |so|
		so.extend(SocketMessage)
		me.instance_eval { b.call(so) }		
   end
 end
end

