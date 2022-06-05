

-- mem_writer:start(code_addr,0x2000)
-- 	:op(op_push_table)
-- 	:op_push_str("r2")
-- 	:op_push_num(42)
-- 	:op_set_table(index_global)
-- 	:op(op_debug)

-- print("hello world!")
code_addr = 0
str_addr = 0x100
jump = 0x0
function test(name,code,expected_values,init_values)
	local checkval = {}
	for k,v in pairs(expected_values) do
		_ENV[k] = checkval
	end
	if init_values then
		for k,v in pairs(init_values) do _ENV[k] = v end
	end
	name = name or code
	local suc, err = picode_compile(code,mem_writer:start(code_addr,str_addr))
	if not suc and err then 
		printh(err)
		stop(err)
	end
	
	local f = load(code_addr)
	local co = cocreate(f)
	local suc,err = coresume(co)
	if not suc and err then
		printh("execution error: "..err)
		printh(trace(co,err))
	end
	local err
	for k,v in pairs(expected_values) do
		if _ENV[k] ~= v then
			err = true
			printh(name..": "..tostr(k).. " is "..(_ENV[k] == checkval and "not set" or tostr(_ENV[k])).." but should be "..tostr(v))
			err = true
		end
		_ENV[k] = nil
	end
	if err then
		dump(code_addr)
		print("error - "..name.." see logs")
		stop()
	end
	code_addr += jump
	str_addr += jump
	return test
end

print "running tests"
test
("assign number", "r = 55.5", {r = 55.5})
("assign numbers", "r = 55.5 r2 = 123", {r = 55.5, r2 = 123})
("assign string", 'a_str = "hi"', {a_str = "hi"})
("assign bools", 'a_bool = true b_bool = false', {a_bool = true, b_bool = false})
("assign nil", 'a_str = nil', {a_str = nil})
("adding numbers", "r = 1 + 2", {r = 3})
("sub numbers", "r = 1 - 2", {r = -1})
("multiplying numbers", "r = 2 * 3", {r = 6})
("div numbers", "r = 3 / 2", {r = 1.5})
("div numbers 2", "r = -3 / 2", {r = -1.5})
("mod numbers", "r = 3 % 2", {r = 1})
("adding 3 numbers", "r = 1 + 2 + 3", {r = 6})
(nil, "r = 2 ^ 2 + 3", {r = 2 ^ 2 + 3})
(nil, "r = 2 * 2 + 3", {r = 2 * 2 + 3})
(nil, "r = 2 + 2 * 3", {r = 2 + 2 * 3})
(nil, "r = 2 / 2 * 3", {r = 2 / 2 * 3})
(nil, "r = 2 * 2 / 3", {r = 2 * 2 / 3})
(nil, "r = (2 * 2) / 4", {r = (2 * 2) / 4})
(nil, "r = 2 * (2 / 4)", {r = 2 * (2 / 4)})
(nil, "r = 2 * 2 / (4 - 12)", {r = 2 * 2 / (4 - 12)})
(nil, "r = 2 * x", {r = 6},{x=3})
(nil, "r = x * x", {r = 9},{x=3})
(nil, "r = x * x + 2", {r = 11},{x=3})
(nil, "r = x * (x + 2)", {r = 15},{x=3})
(nil, "r = x()", {r = 5},{x=function() return 5 end})
(nil, "r = x(1)", {r = 2},{x=function(a) return a*2 end})
(nil, "r = x(1,2)", {r = 3},{x=function(a,b) return a+b end})
(nil, "r = x(1+2,2*2)", {r = 7},{x=function(a,b) return a+b end})
(nil, "r = x(x(1,2)*2,2)", {r = 8},{x=function(a,b) return a+b end})
(nil, "r = x(y(2))", {r = 4},{y=function(a) return a,a end, x=function(a,b) return a+b end})
(nil, "r = x(y(2),1)", {r = 3},{y=function(a) return a,a end, x=function(a,b) return a+b end})
(nil, "r = x((y(2)))", {r = 2},{y=function(a) return a,a end, x=function(a,b) return a+(b or 0) end})
(nil, "a,b = 2,1", {a = 2,b=1})
(nil, "a,b = x()", {a = 2,b=1},{x=function() return 2,1 end})
(nil, "a,b = x(),3", {a = 2,b=3},{x=function() return 2,1 end})
(nil, "a,b,c = 3,x()", {a = 3,b=2,c=1},{x=function() return 2,1 end})
(nil, "a,b,c = b,c,a", {a = 2,b=3,c=1},{a = 1, b = 2, c = 3})
(nil, "a = true and true", {a = true})
(nil, "a = 1 and 2", {a = 1 and 2})
(nil, "a = 1 and false", {a = 1 and false})
(nil, "a = 1 and 2 and 3", {a = 3})
(nil, "a = false or 3", {a = 3})
(nil, "a = true and 1 or 2", {a = 1})
(nil, "a = false and 1 or 2", {a = 2})
(nil, "a = false and 1 or true and 2 or 3", {a = 2})
(nil, "a = f() and 2", {a = 2}, {f=function() return 1 end})
(nil, "a = 2 and f()", {a = 1}, {f=function() return 1 end})




cls()
sspr(0,0,128,128,0,0)
print("all tests successfull",0,100)
flip()

-- print(r2)
--for k,v in pairs(_ENV) do printh(tostr(k).." : "..tostr(v)) end

