# LGPL
# ruby b.rb  0.2  3 | ruby plot.rb --pos 300,0  0 -0.01 1 cpu

if File.exists?("c:/windows")
	require 'ruby-wmi'

	puts "Not implemented for Windows !!!"
	exit(0)
else

def get_nbcpu()
	stat = Hash[*(IO.read("/proc/stat").split("\n").map {|line| line.chomp.split(/\s+/,2)}.flatten)]
	stat.keys.grep(/^cpu(\d+)/).size
end
def get_stat()
	stat = Hash[*(IO.read("/proc/stat").split("\n").map {|line| line.chomp.split(/\s+/,2)}.flatten)]
	p stat if $DEBUG
	stat=stat["cpu"].split(/\s+/).map(&:to_i)
end


$stdout.sync=true
periode= ARGV.shift.to_f
lno=ARGV.map(&:to_i)
p periode
p lno
nbcpu=get_nbcpu()
p nbcpu
ref=get_stat()
loop {
		ref=get_stat().tap {|t|
			x=t.zip(ref).map {|a,b| ((a-b)*10)/(nbcpu*periode*1000)} 
		    puts lno.map {|i| (100*x[i]).to_i}.join(" ")
	    }
		sleep periode
}
end