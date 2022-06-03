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
function mem_writer:op_push_num(n)
	return self:op(op_push_num):num(n)
end
function mem_writer:op_set_table(n)
	return self:op(op_set_table):num2(n)
end
function mem_writer:op_get_table(n)
	return self:op(op_get_table):num2(n)
end
function mem_writer:op_get_global()
	return self:op(op_get_global)
end
function mem_writer:op_set_global(n)
	return self:op(op_set_global)
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
}
local op_prio = {
	["+"] = 1,
	["-"] = 1,
	["*"] = 2,
	["/"] = 2,
	["%"] = 2,
	["^"] = 2,
}
for c in all(split ".,:,(,),\",\\,[,],{,},+,-,*,/,%,=,~=") do
	tokens[c] = c
end
for keywoord in all(split "and,or,not,true,false,if,then,else,elseif,end,do,while,for,in") do
	tokens[keywoord] = keywoord
	keywords[keywoord] = keywoord
end

function picode_compile(code, mem_writer)
	local function character(str, n) return chr(ord(str,n)) end
	local pos = 1
	local current_token
	local function next_token()
		current_token = nil
		while pos <= #code and ord(code, pos) <= 32 do pos+=1 end
		if pos > #code then return end
		local start = pos
		local c = chr(ord(code,pos))
		
		repeat
			--local c = chr(ord(code,pos))
			pos += 1
			--color(5) print(sub(code,start,pos)) color(7)
		until pos > #code or ord(code, pos) <= 32 
			or tokens[character(code,pos)]
			or tokens[sub(code,start,pos-1)]
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
	local function is_alpha(alpha,numeric, str,n)
		if not str then return false end
		local c = character(str,n)
		return (alpha and c >= 'a' and c <='z') or 
			(alpha and c >='A' and c <= 'Z') or 
			(alpha and c == '_') or 
			(numeric and c >= '0' and c <= '9')
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
	local function parse_expression(bcnt, prio, call)
		local pstart = pos
		local t = next_token()
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
			return parse_expression(bcnt + 1, 0, call)
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
			local str = sub(code,pstart+2,pos-2)
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
			mem_writer:op_push_str(t)
			mem_writer:op_get_global()
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
				parse_expression(0)
				if peek_token() == "," then
					goto next_arg
				end
				if peek_token() ~= ")" then
					error("unexpected: "..tostr(peek_token()))
				end
				next_token()
				mem_writer:op(op_call)
			end
		end

		local next = peek_token()
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
				end)
		end
		
		if call then
			call()
		end
	end
	local function parse_statement()
		local start = pos
		local t = next_token()
		if not t then return true end
		if tokens[t] then
			error("unexpected token: "..t)
		else
			if not is_valid_name(t) then
				error("not a valid name: "..t)
			end
			local op = next_token()
			if op == '(' then
				-- mem_writer:op_push_str(t):op(op_get_global):op(op_call_start)
			elseif op == '=' then
				mem_writer:op_push_str(t)
				parse_expression(0)
				mem_writer:op_set_global(-2)
				-- mem_writer:op_push_str(t):op(op_)
			else
				error("unexpected op: "..t)
			end
		end
		return parse_statement()
	end
	local parser = cocreate(parse_statement)
	local suc, err = coresume(parser)
	if err and not suc then
		stop(trace(parser,err))
	elseif err_msg then
		printh(trace(parser,err_msg))
		return false, "error: "..err_msg
	else
		return "parsed successfully"
	end
end