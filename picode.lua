

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
	if init_values then
		for k,v in pairs(init_values) do _ENV[k] = v end
	end
	name = name or code
	local checkval = {}
	for k,v in pairs(expected_values) do
		_ENV[k] = checkval
	end
	local suc, err = picode_compile(code,mem_writer:start(code_addr,str_addr))
	if not suc and err then 
		printh(err)
		stop(err)
	end
	
	local f = load(code_addr)
	local co = cocreate(f)
	local suc,err = coresume(co, addr)
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
end

print "running tests"
test("assign number", "r = 55.5", {r = 55.5})
test("assign numbers", "r = 55.5 r2 = 123", {r = 55.5, r2 = 123})
test("assign string", 'a_str = "hi"', {a_str = "hi"})
test("assign bools", 'a_bool = true b_bool = false', {a_bool = true, b_bool = false})
test("assign nil", 'a_str = nil', {a_str = nil})
test("adding numbers", "r = 1 + 2", {r = 3})
test("sub numbers", "r = 1 - 2", {r = -1})
test("multiplying numbers", "r = 2 * 3", {r = 6})
test("div numbers", "r = 3 / 2", {r = 1.5})
test("div numbers 2", "r = -3 / 2", {r = -1.5})
test("mod numbers", "r = 3 % 2", {r = 1})
test("adding 3 numbers", "r = 1 + 2 + 3", {r = 6})
test(nil, "r = 2 ^ 2 + 3", {r = 2 ^ 2 + 3})
test(nil, "r = 2 * 2 + 3", {r = 2 * 2 + 3})
test(nil, "r = 2 + 2 * 3", {r = 2 + 2 * 3})
test(nil, "r = 2 / 2 * 3", {r = 2 / 2 * 3})
test(nil, "r = 2 * 2 / 3", {r = 2 * 2 / 3})
test(nil, "r = (2 * 2) / 4", {r = (2 * 2) / 4})
test(nil, "r = 2 * (2 / 4)", {r = 2 * (2 / 4)})
test(nil, "r = 2 * 2 / (4 - 12)", {r = 2 * 2 / (4 - 12)})
test(nil, "r = 2 * x", {r = 6},{x=3})
test(nil, "r = x * x", {r = 9},{x=3})
test(nil, "r = x * x + 2", {r = 11},{x=3})
test(nil, "r = x * (x + 2)", {r = 15},{x=3})
test(nil, "r = x()", {r = 5},{x=function() return 5 end})
test(nil, "r = x(1)", {r = 2},{x=function(a) return a*2 end})
test(nil, "r = x(1,2)", {r = 3},{x=function(a,b) return a+b end})
test(nil, "r = x(1+2,2*2)", {r = 7},{x=function(a,b) return a+b end})
test(nil, "r = x(x(1,2)*2,2)", {r = 8},{x=function(a,b) return a+b end})
test(nil, "r = x(y(2))", {r = 4},{y=function(a) return a,a end, x=function(a,b) return a+b end})



cls()
sspr(0,0,128,128,0,0)
print("all tests successfull",0,100)
flip()

-- print(r2)
--for k,v in pairs(_ENV) do printh(tostr(k).." : "..tostr(v)) end

