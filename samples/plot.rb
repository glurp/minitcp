# LGPL
###############################################################
# plot.rb plot data(s) of stdin to Gui display
# Usage:
#  > vmstat 1 | ruby  plot.rb -2 0-value 100%-value cpu --  10  0 5000 io auto
#                             ^input-column         ^label  ^in-column .. ^auto-scale
#      
###############################################################

require 'Ruiby'
$bgcolor=::Gdk::Color.parse("#023")
$fgcolor=[
	::Gdk::Color.parse("#FFAA00"),
	::Gdk::Color.parse("#99DDFF"),
	::Gdk::Color.parse("#00FF00"),
	::Gdk::Color.parse("#0000FF"),
	::Gdk::Color.parse("#FFFF00"),
	::Gdk::Color.parse("#00FFFF"),
	::Gdk::Color.parse("#FF00FF"),
	::Gdk::Color.parse("#999"),
]
class Measure
	class << self
		def create(argv)
			@lcurve||=[]
			@lcurve << Measure.new(argv)
		end
		def scan_line(line)
			nums=line.scan(/[\d+.]+/)
			@lcurve.each { |m| m.register_value(nums) }
		end
		def draw_measures(ctx)
			@lcurve.each_with_index { |m,index| m.plot_curve(index,ctx) }
			@lcurve.each_with_index { |m,index| m.plot_label(index,ctx) }
		end
	end
	def initialize(argv)
		a=argv.clone
	  @noc=argv.shift.to_i
	  y0=(argv.shift||"0.0").to_f
	  y1=(argv.shift||"100.0").to_f
	  @div,@offset=calc_coef(y0,0.0,y1,1.0)
	  @name=argv.shift||"?"
	  @value= 0
	  @curve=[]
	  @label=@name
	  @autoscale=argv.size>0
	  p [a,self]
	end
	def register_value(lfields)
		svalue=lfields[@noc]
		return if !svalue || svalue !~ /[\d.]+/

		@value=svalue.to_f
		@label = "%s %5.2f" % [@name,@value]
		v= @value * @div + @offset
		py=[0.0,(H-HHEAD)*1.0,(H-HHEAD)*(1.0-v)].sort[1]+HHEAD
		@curve << [W+PAS,py,v,@value]
		@curve.select! {|pt| pt[0]-=PAS; pt[0]>=0}
	    p [i,@value,v,py] if $DEBUG
	    auto_scale if @curve.size>5
	end
	def auto_scale()
		min,max=@curve.minmax_by {|pt| pt[2]}
		if min!=max && (min[2]<-0.1 || max[2]>1.01)
		   p "correction1 #{@name} #{min} // #{max}"
		   @div,@offset=calc_coef(min[3],0.0,max[3],1.0)
		   @curve.each {|a| a[2]=a[3]*@div+@offset ; a[1] = (H-HHEAD)*(1-a[2])}
		elsif (d=(max[2]-min[2]))< 0.1 && (@curve.size-1) >= W/PAS && min!=max
		   p "correction2 #{@name} #{min} // #{max}"
		   @div,@offset=calc_coef(min[3],min[2]-3*d,max[3],max[2]+3*d)
		   @curve.each {|a| a[2]=a[3]*@div+@offset ; a[1] = (H-HHEAD)*(1.0-a[2])}			
		end
	end
	def calc_coef(x0,y0,x1,y1)
		y0=[0.0,1.0,y0].sort[1]
		y1=[0.0,1.0,y1].sort[1]
		a=1.0*(y0-y1)/(x0-x1)
        b= (y0+y1-(x0+x1)*a)/2
        [a,b]
	end
	def plot_curve(index,ctx)
		return if @curve.size<2
		a,*l=@curve
		style(ctx,3,$fgcolor.last)   ; draw(ctx,a,l)
		style(ctx,1,$fgcolor[index]) ; draw(ctx,a,l)
	end
	def style(ctx,width,color)
		ctx.set_line_width(width)
		ctx.set_source_rgba(color.red/65000.0,color.green/65000.0,color.blue/65000.0, 1.0)
	end
	def draw(ctx,h,t)
		ctx.move_to(h.first,h[1])
		t.each {|x,y,*q| ctx.line_to(x,y) }
		ctx.stroke   
	end		
	def plot_label(index,ctx)
		style(ctx,3,$fgcolor[index]) 
		ctx.move_to(5+60*index,HHEAD-5)
		ctx.show_text(@label)
	end
end


def run(app)
	$str=$stdin.gets
	if $str
		p $str if $DEBUG
		Measure.scan_line($str)
		gui_invoke { @cv.redraw }
	else 
		exit!(0)
	end
end

############################### Main #################################

trap("TERM") { exit!(0) }

PAS=2
HHEAD=20
$posxy=[0,0]

if  ARGV.size>=2 && ARGV[0]=="--pos"
  _,posxy=ARGV.shift,ARGV.shift
  $posxy=posxy.split(/[x,:]/).map(&:to_i)
end  
if  ARGV.size>=2 && ARGV[0]=="--dim"
  _,geom=ARGV.shift,ARGV.shift
  W,H=geom.split(/[x,:]/).map(&:to_i)
else
	W,H=200,100
end  

while ARGV.size>0
  argv=[]
  argv << ARGV.shift  while ARGV.size>0 && ARGV.first!="--"
  Measure.create(argv)
  ARGV.shift if ARGV.size>0 && ARGV.first=="--"
end

Ruiby.app width: W, height: H, title: "Curve" do
	stack do
		@cv=canvas(W,H) do
			on_canvas_draw { |w,ctx| expose(w,ctx) } 
			on_canvas_button_press do |w,e| 
				case e.button 
					when 1 then system("lxterminal", "-e", "htop") 
					when 3 then Process.spawn("gnome-system-monitor") 
					when 2 then ask("Exit ?") && exit(0) 
				end
			end

        end		
	end
	chrome(false)
	move($posxy[0],$posxy[1])
    @ow,@oh=size
	def expose(cv,ctx)
		ctx.set_source_rgba($bgcolor.red/65000.0, $bgcolor.green/65000.0, $bgcolor.blue/65000.0, 1)
		ctx.rectangle(0,0,W,H)
		ctx.fill()
		ctx.set_source_rgba($bgcolor.red/65000.0, $bgcolor.green/65000.0, 05+$bgcolor.blue/65000.0, 0.3)
		ctx.rectangle(0,0,W,HHEAD)
		ctx.fill()		
		Measure.draw_measures(ctx)
		(puts "source modified!!!";exit!(0)) if File.mtime(__FILE__)!=$mtime 
	end
	$mtime=File.mtime(__FILE__)

	Thread.new(self) { |app|  loop { run(app) } }
end
