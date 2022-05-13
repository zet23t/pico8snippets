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



local function sides(x,...)
	if not x then return end
	if x < 0 then return -1,sides(...)
	elseif x >= 128 then return 1,sides(...)
	end
	return 0,sides(...)
end

local function is_outside(x1,x2,x3)
	local sx1,sx2,sx3 = sides(x1,x2,x3)
	local sy1,sy2,sy3 = sides(y1,y2,y3)
	if sx1 == sx2 and sx2 == sx3 and sx1~=0 then
		return
	end
end

local function round(x,...)
	if not x then return end
	return flr(x+.5),round(...)
end

function tfill(x1,y1,x2,y2,x3,y3,col,linecol,m)
	if m then
		x1,y1,x2,y2,x3,y3 = m:mulxy(x1,y1,x2,y2,x3,y3)	
	end
	x1,y1,x2,y2,x3,y3=round(x1,y1,x2,y2,x3,y3)
	if is_outside(x1,x2,x3) or is_outside(y1,y2,y3) then
		return
	end
	 
	if col >= 0 then
	 if y2 < y1 and y2 < y3 then
	 	x1,y1,x2,y2 = x2,y2,x1,y1
	 elseif y3 < y1 then
	  x1,y1,x3,y3 = x3,y3,x1,y1
	 end
	 if y2 > y3 then
	  x3,y3,x2,y2 = x2,y2,x3,y3
	 end
	 local dx2,dy2 = x2-x1,y2-y1
	 local dx3,dy3 = x3-x1,y3-y1
	 
	 local x3x1,x2x1 = x3 - x1, x2 - x1
	 local y3y1,y2y1 = y3 - y1, y2 - y1
	 local x4 = x3x1 / y3y1 * y2y1 + x1
	 local va,vb = x3x1 / y3y1, x2x1 / y2y1
	 for y=y1,y2 do
		 local ax = va * (y-y1) + x1
	 	local bx = vb * (y-y1) + x1
			rectfill(round(ax),y,round(bx),y,col)
	 end
	 local x3x4,x3x2 = x3 - x4,x3-x2
	 local y3y2 = y3 - y2
	 va,vb = x3x4 / y3y2, x3x2 / y3y2
	 for y=y2,y3 do
		 local ax = va * (y-y2) + x4
	 	local bx = vb * (y-y2) + x2
			rectfill(round(ax),y,round(bx),y,col)
	 end
	end
 
 if linecol then
		line(x1,y1,x2,y2,linecol)
		line(x1,y1,x3,y3,linecol)
		line(x2,y2,x3,y3,linecol)
	end
end
