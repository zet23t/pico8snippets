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
op_set_globals = 14
op_var = 15

op_next_table_value = 16
op_table_assign = 17

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
op_call_r1 = 42
op_val = 43

op_jmp_cnd = 50
op_jmp = 51
op_cnd_check = 52

op_lt = 60
op_gt = 61
op_gte = 62
op_lte = 63
op_eq = 64
op_neq = 65

op_debug = 255

index_global = -9999

ops = {}
for i,op in ipairs(split (
	"op_exit,op_push_table,op_push_str,op_push_num,op_push_true,op_push_false,"..
	"op_push_nil,op_push_value,op_get_table,op_set_table,op_get_global,"..
	"op_set_globals,op_add,op_sub,op_mul,op_div,op_pow,op_mod,op_and,op_or,"..
	"op_not,op_call_start,op_call,op_call_r1,op_val,op_debug,op_var,op_jmp_cnd,"..
	"op_jmp,op_cnd_check,op_next_table_value,op_table_assign")) 
do 
	ops[op] = _ENV[op] 
	ops[_ENV[op]] = op
end

op_vals = {
	[op_push_str] = function(addr)
		local str = peek_str(peek2(addr + 1))
		printh("   "..(addr+1)..": "..str)
		return addr + 2
	end,
	[op_push_num] = 4,
	[op_val] = 1,
	[op_var] = 1,
	[op_set_globals] = 1,
	[op_and] = 2,
	[op_jmp_cnd] = 2,
	[op_jmp] = 2,
	[op_next_table_value] = 2,
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
function print_stack(stack)
	printh "==== STACK ===="
	for i=1,#stack do
		printh(i..": "..tostr(stack[i][1]))
	end
end
function dump(addr)
	printh("Dumping "..addr)
	::cont::
	local op = peek(addr)
	printh("  "..addr..": "..tostr(ops[op]).." ("..op..")")
	if op == op_exit then
		return
	end
	local n = op_vals[op]
	if n then
		if type(n) == "function" then
			addr = n(addr)
		else
			for i=1,n do
				addr += 1
				printh("    "..addr..": "..peek(addr))
			end
		end
	end
	addr += 1
	goto cont
end

function load(addr)
	local vm = {
		vars = {},
		stack = {},
		assignmentvars = {},
		table_assign = {},
		cnd_check = {},
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
			-- printh("PUSH "..i..": "..tostr(select(i,...))..trace())
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

	local function op_call_handle(truncate)
		return function() 
			local p = #vm.stack
			local n = 0
			while p > 0 and vm.stack[p][1] ~= call_starter do
				n += 1
				p -= 1
			end
			deli(vm.stack, p)
			local f = deli(vm.stack, p - 1)[1]
			if truncate then
				stack_push((f(stack_pop(n))))
			else
				stack_push(f(stack_pop(n)))
			end
			addr +=1 
		end
	end
	local op_act = {
		[op_push_table] = push_fcall(function()return{}end),
		[op_push_false] = push_literal(false),
		[op_push_true] = push_literal(true),
		[op_push_nil] = push_literal(nil),
		[op_push_str] = push_fcall(function()return peek_str(peek2(addr+1))end,3),
		[op_push_num] = push_fcall(function()
					-- printh(" "..#vm.stack.." = "..peek4(addr+1))
			return peek4(addr+1)end,5),
		[op_next_table_value] = function()
			add(vm.table_assign,{peek2(addr+1), #vm.stack, stack_get(-1)})
			addr += 3
		end,
		[op_table_assign] = function()
			local index, stack_pos, tab = unpack(deli(vm.table_assign, #vm.table_assign))
			
			if index == 0 then
				local k,v = stack_pop(#vm.stack - stack_pos)
				tab[k] = v
			else
				tab[index] = stack_pop(#vm.stack - stack_pos)
			end
			addr += 1
		end,
		[op_call_start] = function() 
			stack_push(call_starter)
			addr +=1
		end,
		[op_call_r1] = op_call_handle(true),
		[op_call] = op_call_handle(),
		[op_jmp] = function()
			addr = peek2(addr+1)
		end,
		[op_jmp_cnd] = function()
			local jmp = peek2(addr+1)
			add(vm.cnd_check, {#vm.stack, jmp})
			addr += 3
		end,
		[op_cnd_check] = function()
			local stack_pos,jmp = unpack(deli(vm.cnd_check, #vm.cnd_check))
			if not stack_pop(#vm.stack - stack_pos) then
				addr = jmp
			else
				addr += 1
			end
		end,
		[op_get_global] = function()
			-- local v = stack_get(-1)
			-- printh("_ENV["..tostr(v).."] = "..
			-- 	tostr(_ENV[v]))
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
		[op_val] = function()
			local vnum = peek(addr + 1)
			vm.assignmentvars[vnum].from = #vm.stack + 1
			addr += 2
		end,
		[op_var] = function()
			local vnum = peek(addr + 1)
			vm.assignmentvars[vnum] = {target = stack_pop(1)}
			addr +=2
		end,
		[op_set_globals] = function()
			-- print_stack(vm.stack)
			local globals = peek(addr + 1)
			addr += 2
			local last = vm.assignmentvars[1].from
			for i=1,#vm.assignmentvars do
				local info = vm.assignmentvars[i]
				if not last then
					_ENV[info.target] = nil
				elseif info.from then
					last = info.from
					_ENV[info.target] = last <= #vm.stack and stack_get(last)
					-- printh(" "..info.target.." = "..last.." - "..tostr(stack_get(1)))
				else
					last += 1
					_ENV[info.target] = last <= #vm.stack and stack_get(last)
				end
			end
			vm.assignmentvars = {}
			-- printh(i..": "..tostr(info.target).." "..info.from)
		end,
		[op_and] = function()
			if stack_get(-1) then
				stack_pop(1)
				addr += 3
			else
				addr = peek2(addr + 1)
			end
		end,
		[op_or] = function()
			if stack_get(-1) then
				addr = peek2(addr + 1)
			else
				stack_pop(1)
				addr += 3
			end
		end,
		[op_lt] = function()
			local k, v = stack_pop(2)
			stack_push(k < v)
			addr += 1
		end,
		[op_gt] = function()
			local k, v = stack_pop(2)
			stack_push(k > v)
			addr += 1
		end,
		[op_lte] = function()
			local k, v = stack_pop(2)
			stack_push(k <= v)
			addr += 1
		end,
		[op_gte] = function()
			local k, v = stack_pop(2)
			stack_push(k >= v)
			addr += 1
		end,
		[op_eq] = function()
			local k, v = stack_pop(2)
			stack_push(k == v)
			addr += 1
		end,
		[op_neq] = function()
			local k, v = stack_pop(2)
			stack_push(k ~= v)
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
			stack_push(select(i,...))
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