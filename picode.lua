

-- mem_writer:start(code_addr,0x2000)
-- 	:op(op_push_table)
-- 	:op_push_str("r2")
-- 	:op_push_num(42)
-- 	:op_set_table(index_global)
-- 	:op(op_debug)

-- print("hello world!")
function equals(a,b)
	if a == b then return true end
	if type(a)~=type(b) then return false end
	if type(a) ~= "table" then return false end
	for k,v in pairs(a) do
		if not equals(v,b[k]) then return false end
	end
	for k,v in pairs(b) do
		if not equals(v,a[k]) then return false end
	end
	return true
end

function serialize(v)
	if type(v) ~= "table" then return tostr(v) end
	local s = "{"
	for i,v in pairs(v) do
		s = s.."["..serialize(i).."]="..serialize(v)..","
	end
	s = s.."}"
	return s
end

code_addr = 0
str_addr = 0x100
jump = 0x0
function test(code,expected_values,init_values)
	printh(code)
	local checkval = {}
	for k,v in pairs(expected_values) do
		_ENV[k] = checkval
	end
	if init_values then
		for k,v in pairs(init_values) do _ENV[k] = v end
	end
	local name = code
	local suc, err = picode_compile(code,mem_writer:start(code_addr,str_addr))
	if not suc and err then 
		printh(err)
		print("code parsing error:")
		print(" "..code)
		color(8)
		stop(err)
	end
	
	local f = load(code_addr)
	local co = cocreate(f)
	local suc,err = coresume(co)
	if not suc and err then
		-- printh("execution error: "..err)
		printh(trace(co,err))
		dump(code_addr)

	end
	local err
	for k,v in pairs(expected_values) do
		if not equals(_ENV[k], v) then
			printh(name..": "..tostr(k).. " is "..(_ENV[k] == checkval and "not set" or serialize(_ENV[k])).." but should be "..serialize(v))
			
			err = true
		end
		_ENV[k] = nil
	end
	if err then
		dump(code_addr)
		color(8)
		print("error:\n"..name.."\nsee logs")
		stop()
	end
	code_addr += jump
	str_addr += jump
	color(11)
	print(code)
	color(6)

	return test
end
cls()
print "running tests"
test
-- ("r = 55.5", {r = 55.5})
-- ("r = 55.5 r2 = 123", {r = 55.5, r2 = 123})
-- ('a_str = "hi"', {a_str = "hi"})
-- ('a_bool = true b_bool = false', {a_bool = true, b_bool = false})
-- ('a_str = nil', {a_str = nil})
-- ("r = 1 + 2", {r = 3})
-- ("r = 1 - 2", {r = -1})
-- ("r = 2 * 3", {r = 6})
-- ("r = 3 / 2", {r = 1.5})
-- ("r = -3 / 2", {r = -1.5})
-- ("r = 3 % 2", {r = 1})
-- ("r = 1 + 2 + 3", {r = 6})
-- ("r = 2 ^ 2 + 3", {r = 2 ^ 2 + 3})
-- ("r = 2 * 2 + 3", {r = 2 * 2 + 3})
-- ("r = 2 + 2 * 3", {r = 2 + 2 * 3})
-- ("r = 2 / 2 * 3", {r = 2 / 2 * 3})
-- ("r = 2 * 2 / 3", {r = 2 * 2 / 3})
-- ("r = (2 * 2) / 4", {r = (2 * 2) / 4})
-- ("r = 2 * (2 / 4)", {r = 2 * (2 / 4)})
-- ("r = 2 * 2 / (4 - 12)", {r = 2 * 2 / (4 - 12)})
-- ("r = 2 * x", {r = 6},{x=3})
-- ("r = x * x", {r = 9},{x=3})
-- ("r = x * x + 2", {r = 11},{x=3})
-- ("r = x * (x + 2)", {r = 15},{x=3})
-- ("r = x()", {r = 5},{x=function() return 5 end})
-- ("r = x(1)", {r = 2},{x=function(a) return a*2 end})
-- ("r = x(1,2)", {r = 3},{x=function(a,b) return a+b end})
-- ("r = x(1+2,2*2)", {r = 7},{x=function(a,b) return a+b end})
-- ("r = x(x(1,2)*2,2)", {r = 8},{x=function(a,b) return a+b end})
-- ("r = x(y(2))", {r = 4},{y=function(a) return a,a end, x=function(a,b) return a+b end})
-- ("r = x(y(2),1)", {r = 3},{y=function(a) return a,a end, x=function(a,b) return a+b end})
-- ("r = x((y(2)))", {r = 2},{y=function(a) return a,a end, x=function(a,b) return a+(b or 0) end})
-- ("a,b = 2,1", {a = 2,b=1})
-- ("a,b = x()", {a = 2,b=1},{x=function() return 2,1 end})
-- ("a,b = x(),3", {a = 2,b=3},{x=function() return 2,1 end})
-- ("a,b,c = 3,x()", {a = 3,b=2,c=1},{x=function() return 2,1 end})
-- ("a,b,c = b,c,a", {a = 2,b=3,c=1},{a = 1, b = 2, c = 3})
-- ("a = true and true", {a = true})
-- ("a = 1 and 2", {a = 1 and 2})
-- ("a = 1 and false", {a = 1 and false})
-- ("a = 1 and 2 and 3", {a = 3})
-- ("a = false or 3", {a = 3})
-- ("a = true and 1 or 2", {a = 1})
-- ("a = false and 1 or 2", {a = 2})
-- ("a = false and 1 or true and 2 or 3", {a = 2})
-- ("a = f() and 2", {a = 2}, {f=function() return 1 end})
-- ("a = 2 and f()", {a = 1}, {f=function() return 1 end})
-- ("a = 1 and (false or 2)", {a = 2})
-- ("a = (false or 2) and 1", {a = 1})
-- ("if true then a = 1 end", {a = 1})
-- ("a=2 if false then a = 1 end x = 3", {a = 2,x = 3})
-- ("if cnd() then a = 1 end x = 3",{a=1,x=3}, {cnd=function()return 1 end})
-- ("x = 1 < 2",{x=true})
-- ("x = 2 <= 2",{x=true})
-- ("x = 2 <= 1",{x=false})
-- ("if 1+3 < 3 then a = 1 end x = 3",{x=3,a=0},{a=0})
-- ("if 1+3 <= 4 then a = 1 end x = 3",{x=3,a=1})
-- ("if true then a = 1 else a = 3 end",{a=1})
-- ("if false then a = 1 else a = 3 end",{a=3})
-- ("if true then a = 1 elseif true then a = 3 end",{a=1})
-- for i=1,4 do
-- 	test("if c==1 then a = 1 elseif c==2 then a = 2 elseif c==3 then a = 3 else a = 4 end",
-- 		{a=i},{c=i})
-- end
-- test("x = {}",{x={}})
-- ("x = {1,2,3}",{x={1,2,3}})
-- ("x = {1,2,{3,4}}",{x={1,2,{3,4}}})
-- ('x = {1,"hi",f()}',{x={1,"hi",2}},{f=function()return 2 end})
-- ('x = {k=true,k2 = false}',{x={k=true,k2 = false}})
-- ('x = {1,k=true,k2 = false,2}',{x={1,k=true,k2 = false,2}})
('local x = 0 a = x x = 1 b = x', {a = 0, b = 1, x = false}, {x=false})
('local x,y = 0,1 a,b = x,y', {a = 0, b = 1, x = false}, {x=false})
('local x,y = c,d x,y = y,x a,b = y,x', {a = 0, b = 1, x = false}, {c=0,d=1,x=false})
('a = t.b.c', {a = 0}, {t={b={c=0}}})
('t.b.c = 0', {t = {b={c=0}}}, {t={b={}}})
('t.b.c,t.b.d = 0,1', {t = {b={c=0,d=1}}}, {t={b={}}})
('t.b.c,t.b.d,t.x = 0,1,t.y', {t = {b={c=0,d=1},x="f",y="f"}}, {t={b={},y="f"}})
("if x.b then a = 1 else a = 3 end",{a=1},{x={b=true}})
('function fun() a = 0 end y = fun()', {a = 0})

--[[ 
missing features
- function declaration
- table access (this will be fun)
  [x] access with .
  [ ] access with []
  [ ] access with :
- function calling as statement
- for loop
- for .. in loop
- while loop
]]


-- cls()
-- sspr(0,0,128,128,0,0)
print("all tests successfull")
-- flip()

-- print(r2)
--for k,v in pairs(_ENV) do printh(tostr(k).." : "..tostr(v)) end

