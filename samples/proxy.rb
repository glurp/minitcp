####################################################
# proxy.rb : pure tcp proxy, for dev/admin/fun :)
####################################################
require_relative '../minitcp.rb'

def spy(sens,data)
  return if $opt=="none"
  prefix=(sens==1 ? "< " : "> ")
  if $opt=="ascii"
    data.each_line {|line| puts "#{prefix}#{line.chomp}"  }
  else
    data.chars.each_slice(16) do |aline|
      a=(aline.map { |char| "%02X " % char.ord }).join.ljust(16*3)+pref+
         aline.map { |char| (char.ord>30 ? char : "~") }.join()
      puts "#{prefix}#{a}"
    end
  end
end

MServer.service(2200,"0.0.0.0",22) do |s_cli|
  puts "> ======== client Connected ========"
  srv=MClient.run_one_shot($host,$port) do |s_srv|
     puts "< ======== server Concected ========"
     s_srv.on_any_receive { |data| spy 1,data; s_cli.print data }
     s_cli.on_any_receive { |data| spy 2,data; s_srv.print data}
     s_srv.wait_end
     s_cli.close rescue nil
  end
  s_cli.wait_end
  p "end cli, stop proxy"
  srv.kill
end


if $0==__FILE__

  $host,$port,$opt=ARGV[0]||"localhost",ARGV[1]||80,ARGV[2]||"ascii"
  puts "Server on port 2200, proxy to #{$host}:#{$port}..."
  sleep
end  

