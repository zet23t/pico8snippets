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

function concat(m, s,...)
	s = tostr(s)
	return s and ... and (s..m..concat(m,...)) or s or ""
end

function printc(...)
	printh(concat(", ",...))
end

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