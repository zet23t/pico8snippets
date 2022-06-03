local late_commands = {}
function late_command(f,...)
	add(late_commands,{f=f,...})
end
function exec_late_commands()
	for i=1,#late_commands do
		local cmd = late_commands[i]
		cmd.f(unpack(cmd))
	end
	late_commands = {}
end

function debug_rect(x1,y1,x2,y2,c)
	late_command(rect,x1,y1,x2,y2,c)
end

function flat_copy(t)
	local cp = {}
	for i,v in pairs(t) do cp[i] = v end
	return cp
end

function tab_compare_i(a,b)
	if type(a) ~= "table" or type(b) ~= "table" or a==b then 
		return a==b 
	end

	if #a==#b then 
		for i=1,#b do
			if not tab_compare_i(a[i],b[i]) then
				return
			end
		end
		return true
	end
end

function tab_contains(t,...)
	for i=1,select('#',...) do
		local q = select(i,...)
		for v in all(t) do
			if v == q then return true end
		end
	end
end

function concat(m, s,...)
	s = tostr(s)
	return s and ... and (s..m..concat(m,...)) or s
end

function printc(...)
	printh(concat(", ",...))
end

function lines(col, close, ...)
	local x,y = ...
	local px,py = ...
	for i=3,select('#',...),2 do
		local nx,ny = select(i,...)
		line(nx,ny,px,py,col)
		px,py = nx,ny
	end
	if close then
		line(px,py,x,y,col)
	end
end

-- faking sprite access on RAM area that gets copied from other cartridges
function dsset(x,y,v)
	local addr = 64 * y + (x>>1) + 0x4300
	local byte = peek(addr,1)
	if x % 2 == 0 then
		byte = (byte & 0xf0) | (v&0xf)
	else
		byte = (byte & 0xf) | ((v&0xf)<<4)
	end
	poke(addr,byte)
end

function dsget(x,y)
	local addr = 64 * y + (x>>1) + 0x4300
	local byte = peek(addr,1)
	return x%2 == 0 and (byte & 0xf) or flr(byte >> 4)
end

function load_cartsprites(cartfile)
	reload(0x4300,0x0000,0x1000,cartfile)
	reload(0x5300,0x3000,0x100,cartfile)
end

function save_cartsprites(cartfile)
	cstore(0x0000,0x4300,0x1000,cartfile)
	cstore(0x3000,0x5300,0x100,cartfile)
end

function text_width(s)
	local w = 0
	for i=1,#s do
		local c = sub(s,i,i)
		if ord(c) >= 128 then
			w = w + 8
		else
			w = w + 4
		end
	end
	return w - 1
end

function wrap_and_repeat(fn)
	local function f(...) fn(...) return f end
	return f
end