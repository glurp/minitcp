
class A
end

module B
  def v=(a)
    @v=a
  end
  
def v()
    @v||="no init value"
  end
end

a=A.new
p a.v rescue p "a not know v()"
a.extend(B)
p a.v
a.v=1
p a.v

A.extend B
p A.v
b=A.new
p b.v
