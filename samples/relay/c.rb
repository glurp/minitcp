require 'minitcp'
require 'open-uri'

Thread.abort_on_exception=true

lfile=Dir.glob("*.*").reject {|f| File.extname(f)==".pdf" || f=~/\s/}.select {|f| !File.directory?(f) && f.size<20000}[0..3000]
p lfile

(ARGV[0]||"1").to_i.times do
  Thread.new { loop {
    fn=lfile[rand(lfile.size)-1]
    s=Time.now
    timeout(10) {
      data=(open("http://localhost:2200/ruby/local/#{fn}?ChargeBoxId=%3ETOTO%3C").read rescue nil)
      data||=""
      puts "Received size=%-5d/%-5d/miss %10d for %-30s duree=%d  ms" % [data.size,File.size(fn),File.size(fn)-data.size,fn,((Time.now.to_f-s.to_f)*1000).to_i]
      #sleep 0.4
    } rescue p $! 
  }}
end
sleep