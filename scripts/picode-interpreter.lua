op_exit = 0

op_push_table = 1
op_push_str = 2
op_push_num = 3
op_push_true = 4
op_push_false = 5
op_push_nil = 6
op_push_value = 7

op_get_table = 11
op_set_table = 12
op_get_global = 13
op_set_global = 14

op_add = 20
op_sub = 21
op_mul = 22
op_div = 23
op_pow = 24
op_mod = 25

op_and = 30
op_or = 31
op_not = 32

op_call_start = 40
op_call = 41

op_debug = 255

index_global = -9999

ops = {}
for i,op in ipairs(split [[op_exit,op_push_table,op_push_str,op_push_num,op_push_true,op_push_false,op_push_nil,op_push_value,op_get_table,op_set_table,op_get_global,op_set_global,op_add,op_sub,op_mul,op_div,op_pow,op_mod,op_and,op_or,op_not,op_call_start,op_call,op_debug]]) 
do 
	ops[op] = _ENV[op] 
	ops[_ENV[op]] = op
end

op_args = {
	[op_push_str] = 2,
	[op_push_num] = 4,
	
}

function peek_str(addr)
	local str = ""
	::next::
	local byte = peek(addr)
	if byte == 0 then return str end
	addr += 1
	str..=chr(byte)
	goto next
end

function dump(addr)
	printh("Dumping "..addr)
	::cont::
	local op = peek(addr)
	printh("  "..addr..": "..tostr(ops[op]).." ("..op..")")
	if op == op_exit then
		return
	end
	if op_args[op] then
		for i=1,op_args[op] do
			printh("    "..addr..": "..peek(addr))
			addr += 1
		end
	end
	addr += 1
	goto cont
end

function load(addr)
	local vm = {
		vars = {},
		stack = {},
		code = addr,
		pos = addr
	}

	local function stack_get(i)
		assert(#vm.stack > 0, "stack underflow")
		local v = i < 0 and vm.stack[#vm.stack + i + 1] or vm.stack[i]
		return v[1]
	end
	local function stack_pop(n)
		if n > 0 then
			return deli(vm.stack,#vm.stack - n + 1)[1], stack_pop(n - 1)
		end
	end

	local function stack_push(...)
		for i=1,select('#',...) do
			add(vm.stack, {select(i,...)})
		end
	end

	local function push_fcall(f,n)
		n = n or 1
		return function()
			add(vm.stack, {f()})
			addr += n
		end
	end

	local function push_literal(v)
		return function()
			add(vm.stack, {v})
			addr+=1
		end
	end
	local call_starter = {}

	local op_act = {
		[op_push_table] = push_fcall(function()return{}end),
		[op_push_false] = push_literal(false),
		[op_push_true] = push_literal(true),
		[op_push_nil] = push_literal(nil),
		[op_push_str] = push_fcall(function()return peek_str(peek2(addr+1))end,3),
		[op_push_num] = push_fcall(function()return peek4(addr+1)end,5),
		[op_call_start] = function() 
			stack_push(call_starter)
			addr +=1
		end,
		[op_call] = function() 
			local p = #vm.stack
			local n = 0
			while p > 0 and vm.stack[p][1] ~= call_starter do
				n += 1
				p -= 1
			end
			deli(vm.stack, p)
			local f = deli(vm.stack, p - 1)[1]
			stack_push(f(stack_pop(n)))
			addr +=1 end,
		[op_get_global] = function()
			stack_push(_ENV[stack_pop(1)])
			addr += 1
		end,
		[op_set_table] = function()
			local dst = peek2(addr + 1)
			addr += 3
			local k,v = stack_pop(2)
			if dst == index_global then
				_ENV[k] = v
			else
				stack_get(dst)[k] = v
			end
		end,
		[op_set_global] = function()
			local k, v = stack_pop(2)
			_ENV[k] = v
			addr += 1
		end,
		[op_add] = function()
			local k, v = stack_pop(2)
			stack_push(k+v)
			addr += 1
		end,
		[op_mul] = function()
			local k, v = stack_pop(2)

			-- print("> "..tostr(k).." "..tostr(v))
			stack_push(k*v)
			addr += 1
		end,
		[op_sub] = function()
			local k, v = stack_pop(2)
			stack_push(k-v)
			addr += 1
		end,
		[op_div] = function()
			local k, v = stack_pop(2)
			stack_push(k/v)
			addr += 1
		end,
		[op_mod] = function()
			local k, v = stack_pop(2)
			stack_push(k%v)
			addr += 1
		end,
		[op_pow] = function()
			local k, v = stack_pop(2)
			stack_push(k^v)
			addr += 1
		end,
		[op_debug] = function()
			printh("DEBUG:")
			for i=1,#vm.stack do
				printh("  @"..i..": "..tostr(vm.stack[i]))
			end
			addr += 1
		end
	}

	return function(...)
		for i=1,select('#',...) do
			stack_push(select(i),...)
		end
		::cont::
		local op = peek(addr)
		if op == op_exit then
			return stack_pop(#vm.stack)
		end
		if op_act[op] then
			op_act[op]()
			goto cont
		end

		printh("unkown op: "..op.." @ "..tostr(addr,true))
	end
end