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