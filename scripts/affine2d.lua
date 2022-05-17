local m33 = {}
local m33_mt = {__index = m33}

local function m33new(t)
	return setmetatable(t,m33_mt)
end

function m33:mulxy(x,y,...)
	if not x then return end
	return
		x * self[1] + y * self[2] + self[5],
		x * self[3] + y * self[4] + self[6],
		self:mulxy(...)
end

function m33_ident()
	return m33new{1,0,0,1,0,0}
end

function m33_ang(a,tx,ty,sx,sy)
	sx = sx or 1
	sy = sy or sx or 1
	local c,s = cos(a) * sx,sin(a) * sy
	return m33new{c,s,-s,c,tx or 0,ty or 0}
end
