function rect_contains(x1,y1,x2,y2,px,py,...)
	local is_inside = px >= x1 and py >= y1 and px < x2 and py < y2
	if ... then
		return is_inside, rect_contains(x1,y1,x2,y2,...)
	end
	return is_inside
end
function clamp(min,max,v,...)
	v = (v > max and max) or (v < min and min) or v
	if ... then
		return v, clamp(min,max,...)
	end
	return v
end
function lerp(t,a,b,...)
	local x = t * b + a * (1 - t)
	if ... then return x,lerp(t,...) end
	return x
end

function xys_add(addx,addy,x,y,...)
	if x then
		return addx+x,addy+y,xys_add(addx,addy,...)
	end
end

function min_all(a,...)
	return ... and min(a,min_all(...)) or a
end

function line_distance(px,py,x1,y1,x2,y2,...)
	if not x1 then return end
	if x1 == x2 and y1 == y2 then
		return length(x1-px,y1-py), line_distance(px,py,...)
	end
	local dx,dy,d = normalize(x2-x1,y2-y1)
	local posOnLine = dx*(px-x1) + dy*(py-y1)
	local pd = posOnLine < 0 and length(px-x1,py-y1) or posOnLine > d and length(px-x2,py-y2)
	return pd or abs( dy*(px-x1) - dx*(py-y1)), line_distance(px,py,...)
end

function multiply_all(m, x,...)
	if x then
		return x * m, multiply_all(m,...)
	end
end

function ceil_all(x,...)
	if not x then return end
	return ceil(x),ceil_all(...)
end
function flr_all(x,...)
	if not x then return end
	return flr(x),flr_all(...)
end
function round(x,...)
	if not x then return end
	return flr(x+.5),round(...)
end

function nabs(x,...)
	if x then return abs(x),nabs(...) end
end

function dot(x1,y1,x2,y2)
	return x1*x2 + y1*y2
end

function normalize(x,y)
	local m = max(nabs(x, y))
	if m == 0 then return x,y,0 end
	x,y = x / m, y / m
	local d = (x*x+y*y)^.5
	return x / d, y / d, d * m
end

function length(dx,dy)
	local d = max(nabs(dx,dy))
	local n = min(nabs(dx,dy)) / d
	return sqrt(n*n + 1) * d
end

function distance(x1,y1,x2,y2)
	return length(x1-x2,y1-y2)
end