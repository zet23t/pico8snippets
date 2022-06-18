op_exit = 0

op_push_table = 1
op_push_str = 2
op_push_num = 3
op_push_true = 4
op_push_false = 5
op_push_nil = 6
op_push_value = 7
op_push_local = 7
op_push_function = 8

op_get_table = 11
op_set_table = 12
op_get_global = 13
op_set_vars = 14
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
op_return = 44

op_jmp_cnd = 50
op_jmp = 51
op_cnd_check = 52

op_lt = 60
op_gt = 61
op_gte = 62
op_lte = 63
op_eq = 64
op_neq = 65

op_local = 70
op_assign_locals = 71
op_get_local = 72
op_set_locals = 72

op_debug = 255

index_global = -9999

ops = {}
for i,op in ipairs(split (
	"op_exit,op_push_table,op_push_str,op_push_num,op_push_true,op_push_false,op_push_function,"..
	"op_push_nil,op_push_value,op_get_table,op_get_global,op_set_table,"..
	"op_set_vars,op_add,op_sub,op_mul,op_div,op_pow,op_mod,op_and,op_or,"..
	"op_not,op_call_start,op_call,op_call_r1,op_val,op_debug,op_var,op_jmp_cnd,op_return,"..
	"op_jmp,op_cnd_check,op_next_table_value,op_table_assign,op_local,op_assign_locals,op_push_local")) 
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
	[op_set_vars] = 1,
	[op_and] = 2,
	[op_jmp_cnd] = 2,
	[op_jmp] = 2,
	[op_next_table_value] = 2,
	[op_assign_locals] = 1,
	[op_push_local] = 2,
	[op_push_function] = 2,
	[op_return] = 1,
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
		vars = {{n=0}},
		stack = {},
		assignmentvars = {},
		table_assign = {},
		cnd_check = {},
		code = addr,
		pos = addr
	}
	local function local_set(scope, index, val)
		vm.vars[#vm.vars - scope][index] = val
	end
	local function local_get(scope,index)
		return vm.vars[#vm.vars - scope][index]
	end
	local function stack_get(i)
		assert(#vm.stack > 0, "stack underflow")
		local v = i < 0 and vm.stack[#vm.stack + i + 1] or vm.stack[i]
		assert(v)
		local k = v.k
		
		if v.scope then
			--print(v.scope.." ")
			v = vm.vars[#vm.vars - v.scope][v.index]
		else
			v = v[1]
		end
		if k then
			v = v[k[1]]
		end
		return v
	end
	local function stack_pop_raw(n)
		if n > 0 then
			return deli(vm.stack,#vm.stack - n + 1), stack_pop_raw(n - 1)
		end
	end
	local function stack_pop(n)
		if n > 0 then
			local v = deli(vm.stack,#vm.stack - n + 1)
			local k = v.k
			if v.scope then
				v = vm.vars[#vm.vars - v.scope][v.index]
			else
				v = v[1]
			end
			if k then
				--print(tostr(v))
				v = v[k[1]]
			end
			
			return v, stack_pop(n - 1)
		end
	end

	local function stack_push_local(scope,index)
		add(vm.stack, {scope=scope, index=index})
	end

	local function stack_push(...)
		for i=1,select('#',...) do
			-- printh("PUSH "..i..": "..tostr(select(i,...))..trace())
			add(vm.stack, {select(i,...)})
		end
	end

	local function stack_push_key(k)
		vm.stack[#vm.stack].k = {k}
	end

	local function push_fcall(f,n)
		n = n or 1
		return function(addr)
			add(vm.stack, {f(addr)})
			addr += n
			return addr
		end
	end

	local function push_literal(v)
		return function(addr)
			add(vm.stack, {v})
			addr+=1
			return addr
		end
	end
	local call_starter = {}

	local function op_call_handle(truncate)
		return function(addr) 
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
				-- print("1->"..#vm.stack)
			else
				stack_push(f(stack_pop(n)))
				-- print("2->"..#vm.stack)
			end
			addr +=1 
			return addr
		end
	end
	local function log(addr,str)
		print(addr..": "..tostr(str))
	end
	
	local op_act
	local function prog(start)
		return function(...)
			for i=1,select('#',...) do
				stack_push(select(i,...))
			end
			local addr = start
			local assignmentvars = vm.assignmentvars
			vm.assignmentvars = {}
			::cont::
			local op = peek(addr)
			-- print(addr..": "..op)
			if op == op_exit or op == op_return then
				-- print("<<-"..#vm.stack)
				vm.assignmentvars = assignmentvars
				return stack_pop(#vm.stack)
			end
			if op_act[op] then
				addr = op_act[op](addr)
				goto cont
			end

			printh("unkown op: "..op.." @ "..tostr(addr))
			-- assert()
		end
	end

	op_act = {
		[op_push_table] = push_fcall(function()return{}end),
		[op_push_false] = push_literal(false),
		[op_push_true] = push_literal(true),
		[op_push_nil] = push_literal(nil),
		[op_push_str] = push_fcall(function(addr)return peek_str(peek2(addr+1))end,3),
		[op_push_num] = push_fcall(function(addr)
					-- printh(" "..#vm.stack.." = "..peek4(addr+1))
			return peek4(addr+1)end,5),
		[op_push_local] = function(addr)
			-- log("op_push_local "..peek(addr+1).." "..peek(addr+2))
			stack_push_local(peek(addr+1),peek(addr+2))
			return addr + 3
		end,
		[op_push_function] = function(addr)
			stack_push(prog(peek2(addr + 1)))
			return addr + 3
		end,
		[op_local] = function(addr)
			add(vm.assignmentvars, #vm.stack + 1)
			return addr + 1
		end,
		[op_assign_locals] = function(addr)
			local n = peek(addr+1)
			local stack_start = deli(vm.assignmentvars, #vm.assignmentvars)
			local stack_pos = stack_start
			-- log(addr,tostr(stack_pos))
			local scope_vars = vm.vars[#vm.vars]
			for i=1,n do
				scope_vars.n += 1
				local index = scope_vars.n
				-- print(stack_pos.." - "..#vm.stack)
				scope_vars[index] = stack_get(stack_pos)
				-- print(index..": "..scope_vars[index])
				stack_pos += 1
			end
			stack_pop_raw(#vm.stack - stack_pos)
			return addr + 2
		end,
		[op_next_table_value] = function(addr)
			add(vm.table_assign,{peek2(addr+1), #vm.stack, stack_get(-1)})
			return addr + 3
		end,
		[op_table_assign] = function(addr)
			local index, stack_pos, tab = unpack(deli(vm.table_assign, #vm.table_assign))
			
			if index == 0 then
				local k,v = stack_pop(#vm.stack - stack_pos)
				tab[k] = v
			else
				tab[index] = stack_pop(#vm.stack - stack_pos)
			end
			return addr + 1
		end,
		[op_get_table] = function(addr)
			local t,k = stack_pop(2)
			stack_push(t)
			stack_push_key(k)
			return addr + 1
		end,
		[op_call_start] = function(addr) 
			stack_push(call_starter)
			return addr + 1
		end,
		[op_call_r1] = op_call_handle(true),
		[op_call] = op_call_handle(),
		[op_jmp] = function(addr)
			return peek2(addr+1)
		end,
		[op_jmp_cnd] = function(addr)
			local jmp = peek2(addr+1)
			add(vm.cnd_check, {#vm.stack, jmp})
			return addr + 3
		end,
		[op_cnd_check] = function(addr)
			local stack_pos,jmp = unpack(deli(vm.cnd_check, #vm.cnd_check))
			if not stack_pop(#vm.stack - stack_pos) then
				return jmp
			end
			return addr + 1
		end,
		[op_get_global] = function(addr)
			-- local v = stack_get(-1)
			-- printh("_ENV["..tostr(v).."] = "..
			-- 	tostr(_ENV[v]))
			stack_push(_ENV[stack_pop(1)])
			return addr + 1
		end,
		[op_val] = function(addr)
			local vnum = peek(addr + 1)
			-- log("op_val "..vnum)
			vm.assignmentvars[vnum].from = #vm.stack + 1
			return addr + 2
		end,
		[op_var] = function(addr)
			local vnum = peek(addr + 1)
			-- log("op_var "..vnum)
			vm.assignmentvars[vnum] = {target = stack_pop_raw(1)}
			return addr + 2
		end,
		[op_set_vars] = function(addr)
			-- log(addr,"set_vars "..#vm.stack)
			local var_count = peek(addr + 1)
			local first = #vm.assignmentvars - var_count + 1
			--print(first.." - "..#vm.assignmentvars)	
			local from = vm.assignmentvars[first].from
			local last = from
			-- print "assign"
			if from then
				for i=first,#vm.assignmentvars do
					local info = vm.assignmentvars[i]
					-- log(addr,"info.scope = "..tostr(serialize(info.target)))
					if info.from then
						last = info.from
						info.v = last <= #vm.stack and stack_get(last)
					else
						last += 1
						info.v = last <= #vm.stack and stack_get(last)
					end
				end
			end
			for i=first, #vm.assignmentvars do
				local info = vm.assignmentvars[i]
				vm.assignmentvars[i] = nil
				local k = info.target.k
				if k then
					if info.target.scope then
						-- print("set "..info.target.index.." = "..v)
						local_get(info.target.scope,info.target.index)[k[1]] = info.v
					else
						-- print("set "..tostr(info.target).." = "..v)
						info.target[1][k[1]] = info.v
					end
				else
					if info.target.scope then
						-- print("set "..info.target.index.." = "..v)
						local_set(info.target.scope,info.target.index,info.v)
					else
						-- print("set "..tostr(info.target).." = "..v)
						_ENV[info.target[1]] = info.v
					end
				end
			end
			stack_pop(#vm.stack - from + 1)
			-- print("< set_vars "..#vm.stack.." - "..from)
			-- printh(i..": "..tostr(info.target).." "..info.from)
			return addr + 2
		end,
		[op_and] = function(addr)
			if stack_get(-1) then
				stack_pop(1)
				return addr + 3
			end
			return peek2(addr + 1)
		end,
		[op_or] = function(addr)
			if stack_get(-1) then
				return peek2(addr + 1)
			end
			stack_pop(1)
			return addr + 3
		end,
		[op_lt] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k < v)
			return addr + 1
		end,
		[op_gt] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k > v)
			return addr + 1
		end,
		[op_lte] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k <= v)
			return addr + 1
		end,
		[op_gte] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k >= v)
			return addr + 1
		end,
		[op_eq] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k == v)
			return addr + 1
		end,
		[op_neq] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k ~= v)
			return addr + 1
		end,
		[op_add] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k+v)
			return addr + 1
		end,
		[op_mul] = function(addr)
			local k, v = stack_pop(2)

			-- print("> "..tostr(k).." "..tostr(v))
			stack_push(k*v)
			return addr + 1
		end,
		[op_sub] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k-v)
			return addr + 1
		end,
		[op_div] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k/v)
			return addr + 1
		end,
		[op_mod] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k%v)
			return addr + 1
		end,
		[op_pow] = function(addr)
			local k, v = stack_pop(2)
			stack_push(k^v)
			return addr + 1
		end,
		[op_debug] = function(addr)
			printh("DEBUG:")
			for i=1,#vm.stack do
				printh("  @"..i..": "..tostr(vm.stack[i]))
			end
			return addr + 1
		end
	}
	return prog(addr)
end