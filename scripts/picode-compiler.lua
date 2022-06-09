function poke_str(addr,str)
	for i=1,#str do
		poke(addr + i - 1, ord(str, i))
	end
	poke(addr + #str, 0)
end

mem_writer = {}
function mem_writer:start(pos,str_start)
	memset(pos,0,str_start-pos)
	self = setmetatable({}, {__index = self})
	self.strings = {}
	self.string_addr = str_start
	self.pos = pos
	return self
end
function mem_writer:op(n)
	-- printh(" -> "..self.pos.." < "..n)
	poke(self.pos, n)
	self.pos += 1
	return self
end
function mem_writer:num(n)
	poke4(self.pos, n)
	self.pos += 4
	return self
end
function mem_writer:num1(n)
	poke(self.pos,n)
	self.pos += 1
	return self
end
function mem_writer:num2(n)
	poke2(self.pos, n)
	self.pos += 2
	return self
end
function mem_writer:str(str)
	local addr = self.strings[str]
	if not addr then
		addr = self.string_addr
		self.strings[str] = addr
		poke_str(addr, str)
		self.string_addr += #str + 1
	end
	poke2(self.pos,addr)
	self.pos += 2
	return self
end
function mem_writer:op_push_str(str)
	return self:op(op_push_str):str(str)
end
function mem_writer:op_push_local(scope,index)
	return self:op(op_push_local):num1(scope):num1(index)
end
function mem_writer:op_push_num(n)
	return self:op(op_push_num):num(n)
end
function mem_writer:op_get_table(n)
	return self:op(op_get_table):num2(n)
end
function mem_writer:op_get_global()
	return self:op(op_get_global)
end
function mem_writer:op_set_vars(n)
	return self:op(op_set_vars):num1(n)
end
function mem_writer:op_val(n)
	return self:op(op_val):num1(n)
end
function mem_writer:op_var(n)
	return self:op(op_var):num1(n)
end
function mem_writer:num2symbol(s,rel)
	if s then
		poke2(s, self.pos + (rel or 0))
		return self
	end
	
	local pos = self.pos
	self:num2(0)
	return pos
end

------------------

local tokens = {[","] = ","}
local keywords = {}
local op_mapping = {
	["+"] = op_add,
	["-"] = op_sub,
	["*"] = op_mul,
	["/"] = op_div,
	["%"] = op_mod,
	["^"] = op_pow,
	["<"] = op_lt,
	[">"] = op_gt,
	[">="] = op_gte,
	["<="] = op_lte,
	["=="] = op_eq,
	["~="] = op_neq,
}
local op_prio = {
	["+"] = 1,
	["-"] = 1,
	["*"] = 2,
	["/"] = 2,
	["%"] = 2,
	["^"] = 2,
	[">"] = 0,
	["<"] = 0,
	["<="] = 0,
	[">="] = 0,
	["=="] = -1,
	["~="] = -1,
}
for c in all(split ".,:,(,),\",\\,[,],{,},+,-,*,/,%,=,==,~=,<,>,<=,>=") do
	tokens[c] = c
end
for keyword in all(split("and,or,not,true,false,if,then,else,elseif,end,do,while,for,in,local")) do
	--tokens[keyword] = keyword
	keywords[keyword] = keyword
end

function picode_compile(code, mem_writer)
	local function character(str, n) return chr(ord(str,n)) end
	local pos = 1
	local current_token
	local function is_alpha(alpha,numeric, str,n)
		if not str then return false end
		local c = character(str,n)
		return (alpha and c >= 'a' and c <='z') or 
			(alpha and c >='A' and c <= 'Z') or 
			(alpha and c == '_') or 
			(numeric and c >= '0' and c <= '9')
	end
	local function skip_whitespaces()
		while pos <= #code and ord(code, pos) <= 32 do pos+=1 end
	end
	local function next_token()
		current_token = nil
		skip_whitespaces()
		if pos > #code then return end
		local start = pos
		local c = character(code,pos)
		
		repeat
			--local c = chr(ord(code,pos))
			pos += 1
			-- color(5) print(sub(code,start,pos)) color(7)
		until pos > #code or ord(code, pos) <= 32 
			or (tokens[character(code,pos)] and not tokens[sub(code,start,pos)]) 
			or (tokens[sub(code,start,pos-1)] and not tokens[sub(code,start,pos)])
		current_token = sub(code,start,pos - 1)

		-- print("t: "..current_token.." @ "..pos)
		return current_token
	end
	local function peek_token(n)
		local p,t = pos
		for i=1,n or 1 do
			t = next_token()
		end
		pos = p
		return t
	end
	local err_msg 
	local function error(err)
		err_msg = err
		yield()
	end
	local function is_valid_number(str)
		for i=1,#str do 
			if not is_alpha(false,true,str,i) then
				return false
			end
		end
		return true
	end
	local function is_valid_name(str)
		if keywords[str] then
			return false
		end
		for i=1,#str do
			if not is_alpha(true, i > 1,str,i) then
				return false
			end
		end
		return true
	end
	local local_var_scope = {{}}
	local function push_scope()
		add(local_var_scope,{})
	end
	local function pop_scope()
		deli(local_var_scope,#local_var_scope)
	end
	local function add_var(name)
		local scope = local_var_scope[#local_var_scope]
		add(scope, name)
	end
	local function get_var_info(name)
		for i=#local_var_scope,1,-1 do
			local scope = local_var_scope[i]
			for j=#scope,1,-1 do
				if scope[j] == name then
					return #local_var_scope - i,j
				end
			end
		end
	end

	local parse_expression
	function parse_expression(bcnt, prio, call,is_args,is_table)
		skip_whitespaces()
		local pstart = pos
		local t = next_token()
		if t == "{" then
			mem_writer:op(op_push_table)
			local n = 1
			while peek_token() ~= "}" do
				--print("T! "..current_token)
				local key,assign = peek_token(), peek_token(2)
				if assign == "=" then
					if not is_valid_name(key) then
						error("invalid table key: "..key)
					end
					mem_writer:op(op_next_table_value):num2(0)
					mem_writer:op_push_str(next_token())
					next_token()
				else
					mem_writer:op(op_next_table_value):num2(n)
					n = n + 1
				end

				parse_expression(bcnt, prio, call, false, true)
				mem_writer:op(op_table_assign)

				if peek_token() == "," then
					next_token()
				end
			end
			next_token()
			--printh(">>> "..trace())
			return
		end
		if t == "}" and is_table then 
			return 
		end
		if t == ")" and bcnt == 0 then
			pos = pstart
			return
		end

		local unary = false
		if t == "not" or t == "-" or t == "+" then
			unary = t
			t = next_token()
		end
		if t == "(" then
			return parse_expression(bcnt + 1, 0, call, false)
		end
		
		if t == "true" then
			mem_writer:op(op_push_true)
		elseif t == "false" then
			mem_writer:op(op_push_false)
		elseif t == "nil" then
			mem_writer:op(op_push_nil)
		elseif t == '"' then			
			while next_token() ~= '"' do 
				if current_token == "\\" then
					next_token()
				end
			end
			local str = sub(code,pstart+1,pos-2)
			-- printh("-> "..str.." - "..t.." - "..trace())
			mem_writer:op_push_str(str)
		elseif is_valid_number(t) then
			if peek_token() == "." and is_valid_number(peek_token(2)) then
				t ..= next_token()..next_token()
				if unary == "-" then t = "-"..t end
				mem_writer:op_push_num(tonum(t))
			else
				if unary == "-" then t = "-"..t end
				mem_writer:op_push_num(tonum(t))
			end
		elseif is_valid_name(t) then
			local scope,index = get_var_info(t)
			if scope then
				mem_writer:op_push_local(scope, index)
			else
				mem_writer:op_push_str(t)
				mem_writer:op_get_global()
			end
			if unary == "not" then
				mem_writer:op(op_not)
			elseif unary == "-" then
				mem_writer:op_push_num(-1)
				mem_writer:op(op_mul)
			end
			if peek_token() == "(" then
				mem_writer:op(op_call_start)
				::next_arg::
				next_token()
				parse_expression(0,0,nil,true)
				if peek_token() == "," then
					goto next_arg
				end
				if peek_token() ~= ")" then
					error("unexpected: "..tostr(peek_token()))
				end
				next_token()
				mem_writer:op((peek_token() == ',' or bcnt > 0) and op_call_r1 or op_call)
			end
		end

		local next = peek_token()
		-- printh("::"..tostr(next).."::")
		while next == ")" and bcnt > 0 do
			bcnt -= 1
			if call then
				call()
				call = nil
			end
			next_token()
			next = peek_token()
		end
		if next == ',' and bcnt == 0 then
			if is_table then
				return
			end
			if not is_args then
				printh(trace())
				error("unexpected ,")
			end
			if call then call() end
			return 
		elseif op_mapping[next] then
			next_token()
			if call and prio >= op_prio[next] then
				call()
				call = nil
			end
			parse_expression(bcnt, op_prio[next],
				function()
					mem_writer:op(op_mapping[next])
				end,is_args)
		elseif next == "and" or next == "or" then
			next_token()
			if call then
				call()
				call = nil
			end
			local symbol = mem_writer:op(next == "and" and op_and or op_or):num2symbol()
			parse_expression(bcnt, 0,
				function()
					mem_writer:num2symbol(symbol)
				end)
		end
		
		if call then
			call()
		end
	end
	local function expected(expected, found)
		if expected ~= found then
			error("expected "..expected..", found "..found)
		end
	end
	local function parse_statement(parse_until)
		local start = pos
		local t = next_token()
		if not t then return true end
		if parse_until[t] then
			return
		end
		if t == "if" then
			local finals = {}
			::check_expression::
			local symbol = mem_writer:op(op_jmp_cnd):num2symbol()
			parse_expression(0, 0, nil, false)
			mem_writer:op(op_cnd_check)
			expected("then", next_token())
			::rep::
			if parse_statement{["end"]=true,["else"]=true,["elseif"] = true} then
				error "expected end, found eof"
			end
			if current_token == "else" or current_token == "elseif" then
				add(finals, mem_writer:op(op_jmp):num2symbol())
				mem_writer:num2symbol(symbol)
				-- printh("==> "..current_token.." - "..tostr(symbol).." "..mem_writer.pos.."\n"..trace())
				symbol = nil
				if current_token == "elseif" then
					goto check_expression
				else
					goto rep
				end
			elseif symbol then
				mem_writer:num2symbol(symbol)
			end
			for s in all(finals) do mem_writer:num2symbol(s) end
		elseif t == "local" then
			local vars = {}
			while 1 do
				local name = next_token()
				if not is_valid_name(name) then
					error("invalid local name: "..name)
				end
				add(vars, name)
				local next = peek_token()
				if next == "=" then
					mem_writer:op(op_local)
					next_token()
					parse_expression(0,0,nil,true)
					for name in all(vars) do
						add_var(name)
					end
					mem_writer:op(op_assign_locals):num1(#vars)
					break
				end
				if next ~= ',' then
					break
				end
				next_token()
			end
		elseif tokens[t] or keywords[t] then
			-- printh(tostr(parse_until).." -- "..trace())
			error("unexpected token: "..t)
		else
			if not is_valid_name(t) then
				error("not a valid name: "..t)
			end
			local op = next_token()
			if op == '(' then
				-- mem_writer:op_push_str(t):op(op_get_global):op(op_call_start)
			elseif op == '=' or op == "," then
				local var_count = 0
				local function push_var(t)
					var_count += 1
					local scope, index = get_var_info(t)
					if scope then
						-- print(scope.." - "..index)
						mem_writer:op_push_local(scope,index)
					else
						-- print(t)
						mem_writer:op_push_str(t)
					end
					mem_writer:op_var(var_count)
				end
				push_var(t)

				while op == "," do
					t = next_token()
					if not is_valid_name(t) then
						error("valid name expected: "..t)
					end
					push_var(t)
					op = next_token()
				end
				if op ~= '=' then
					error("expected =, found "..op)
				end
				local has_next = true
				local arg = 1
				while 1 do
					mem_writer:op_val(arg)
					arg += 1
					parse_expression(0,0,nil,true)
					if peek_token() == "," then
						next_token()
					else
						break
					end
				end
				mem_writer:op_set_vars(var_count)
				-- mem_writer:op_push_str(t):op(op_)
			else
				error("unexpected op: "..op)
			end
		end
		return parse_statement(parse_until)
	end
	local parser = cocreate(parse_statement)
	local suc, err = coresume(parser,{})
	if err and not suc then
		printh(trace(parser,err))
		stop(trace(parser,err))
	elseif err_msg then
		printh(trace(parser,err_msg))
		return false, "error: "..err_msg
	else
		return "parsed successfully"
	end
end