# LGPL
###############################################################
# plot.rb plot data(s) of stdin to Gui display
# Usage:
#  > vmstat 1 | ruby  plot.rb -2 -0.01 1 cpu 10  0.0001 0 io
#                             column         column ...
#      y=ax+b / y in 0..1.0  =>   a     b label ...
###############################################################

require 'Ruiby'
HHEAD=20
$bgcolor=::Gdk::Color.parse("#023")
$fgcolor=[
	::Gdk::Color.parse("#FFAAFF"),
	::Gdk::Color.parse("#FFAA00"),
	::Gdk::Color.parse("#00FF00"),
	::Gdk::Color.parse("#0000FF"),
	::Gdk::Color.parse("#FFFF00"),
	::Gdk::Color.parse("#00FFFF"),
	::Gdk::Color.parse("#FF00FF"),
	::Gdk::Color.parse("#AAAAAA"),
]
PAS=2
H=100
W=400
$o,$curve,$coef=[],[],[]
while ARGV.size>=4 
  $curve << []
  $coef << {noc: ARGV.shift.to_i,div: ARGV.shift.to_f , off: ARGV.shift.to_f, name: ARGV.shift}
end
puts "Coefs: #{$coef.inspect}"

def run(app)
	$str=$stdin.gets
	if $str
		p $str if $DEBUG
		nums=$str.scan(/\d+/)
		$curve.each_with_index do |c,i|
			svalue=nums[$coef[i][:noc]]
			next if svalue !~ /[\d.]+/
			value=svalue.to_f
			v=value * $coef[i][:div] + $coef[i][:off]
			pos=[0,H-HHEAD,(H-HHEAD)*(1-v)].sort[1]+HHEAD
			c << [W+PAS,pos]
			c.select! {|pt| pt[0]-=PAS; pt[0]>=0}
		    p [i,value,v,pos,$coef[i]] if $DEBUG
		end
		gui_invoke { @cv.redraw }
	else
		exit!(0)
	end
end


Ruiby.app width: W, height: H, title: "Curve" do
	stack do
		@cv=canvas(W,H) { on_canvas_draw { |w,ctx| expose(w,ctx) } }
	end

	rposition(1,1)
	after(4*1000) { chrome(false); move(-1,-20) }
	Thread.new(self) { |app| sleep(1) ; loop { run(app) } }
    @ow,@oh=size
	def expose(cv,ctx)
		ctx.set_source_rgba($bgcolor.red/65000.0, $bgcolor.green/65000.0, $bgcolor.blue/65000.0, 1)
		ctx.rectangle(0,0,W,H)
		ctx.fill()
		ctx.set_source_rgba($bgcolor.red/65000.0, $bgcolor.green/65000.0, 05+$bgcolor.blue/65000.0, 0.3)
		ctx.rectangle(0,0,W,HHEAD)
		ctx.fill()
		return if $curve[0].size < 3
		$curve.each_with_index do |curve,noc|
			a,*l=curve
			ctx.set_line_width(2)
			color=$fgcolor[noc % $fgcolor.size]
			ctx.set_source_rgba(color.red/65000.0,color.green/65000.0,color.blue/65000.0, 1)
			ctx.move_to(*a)
			l.each {|(x,y)| ctx.line_to(x,y) }
			ctx.stroke   
		end
		$coef.each_with_index do |c,noc|
			color=$fgcolor[noc % $fgcolor.size]
			ctx.set_source_rgba(color.red/65000.0,color.green/65000.0,color.blue/65000.0, 1)
			ctx.move_to(10,(HHEAD-5)*(noc+2));ctx.show_text(c[:name])
		end
		ctx.move_to(10,HHEAD-5);ctx.show_text($str.chomp)
	end
end
