import mymodule

#to demo scope
def foo():
	def bar():
		q=False
		r="stringify"
		def baz():
			print(p,"function")
		
	


foo()

#this is a comment

#demo dead code elim
x=True
z="this is a string" 

#demo strength reduction
c=3*4  

#demo constant prop
s=18
t=s+s

#demo const folding
u=100+15



a=5
b=10

if (a==5) and (b>8):
	a=9
	b=20
	print("inside if")
elif a<4:
	print("inside elif")
else:
	pass


for item1 in range(0,2):
	for item2 in range(0,4):
		for item3 in range(0,6):
			e=9
			for item4 in range(0,8):
				f=40
				for item5 in range(0,5):
					print("nested loop")
				
			
		
	

