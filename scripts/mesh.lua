local function sides(x,...)
	if x then 
		return x < 0 and -1 or x >= 128 and 1 or 0, sides(...)
	end
end

local function is_outside(x1,x2,x3)
	local sx1,sx2,sx3 = sides(x1,x2,x3)
	if sx1 == sx2 and sx2 == sx3 and sx1~=0 then
		return
	end
end


function p3sort(x1,y1,x2,y2,x3,y3)
	if y2 < y1 and y2 < y3 then
		x1,y1,x2,y2 = x2,y2,x1,y1
	elseif y3 < y1 then
		x1,y1,x3,y3 = x3,y3,x1,y1
	end
	if y2 > y3 then
		x3,y3,x2,y2 = x2,y2,x3,y3
	end
	return x1,y1,x2,y2,x3,y3
end


function tcontains(line_margin,px,py,x1,y1,x2,y2,x3,y3)
	if line_margin and line_margin > 0 and 
		min_all(line_distance(px,py,x1,y1,x2,y2,x1,y1,x3,y3,x2,y2,x3,y3)) <= line_margin 
	then
		return true
	end
	
	x1,y1,x2,y2,x3,y3 = p3sort(round(x1,y1,x2,y2,x3,y3))
	if py <= y1 or py >= y3 or px <= x1 and px <= x2 and px <= x3 or px >= x1 and px >= x2 and px >= x3 then
		return false
	end
	
	if py > y2 then
		-- lower triangle part, just swap
		x1,y1,x3,y3 = x3,y3,x1,y1
	end

	local ax,bx,cx = (x2 - x1) / (y2 - y1) * (py - y1), (x3 - x1) / (y3 - y1) * (py - y1), px - x1
	if ax > bx then
		ax,bx = bx, ax
	end
	return cx >= ax and cx <= bx
end

function tfill(col,linecol,m,x1,y1,x2,y2,x3,y3)
	if m then
		x1,y1,x2,y2,x3,y3 = m:mulxy(x1,y1,x2,y2,x3,y3)	
	end
	x1,y1,x2,y2,x3,y3=round(x1,y1,x2,y2,x3,y3)
	if is_outside(x1,x2,x3) or is_outside(y1,y2,y3) then
		return
	end
	 
	if col >= 0 then
		x1,y1,x2,y2,x3,y3 = p3sort(x1,y1,x2,y2,x3,y3)
		local dx2,dy2 = x2-x1,y2-y1
		local dx3,dy3 = x3-x1,y3-y1
		
		local x3x1,x2x1 = x3 - x1, x2 - x1
		local y3y1,y2y1 = y3 - y1, y2 - y1
		local x4 = x3x1 / y3y1 * y2y1 + x1
		local va,vb = x3x1 / y3y1, x2x1 / y2y1
		for y=y1,y2 do
			local ax,bx = round(va * (y-y1) + x1, vb * (y-y1) + x1)
			rectfill(ax,y,bx,y,col)
		end
		local x3x4,x3x2 = x3 - x4,x3-x2
		local y3y2 = y3 - y2
		va,vb = x3x4 / y3y2, x3x2 / y3y2
		for y=y2,y3 do
			local ax,bx = round(va * (y-y2) + x4,vb * (y-y2) + x2)
			rectfill(ax,y,bx,y,col)
		end
	end
 
 	if linecol and linecol >= 0 then
	 	lines(linecol, true, x1,y1,x2,y2,x3,y3)
	end
end

dsget = dsget or sget

function sgets(x,y,...)
	if (x) return dsget(x,y),sgets(...)
end

local function lerp(a,...)
	local b = 1 - a
	local function l(x1,x2,...)
		if not x1 then return end
		return a * x2 + b * x1,l(...)
	end
	return l(...)
end

function draw_smesh(m33,sx,sy,
			ox,oy,n,sx2,sy2,blend,
			override_col,override_line)
	ox = ox or 0
	oy = oy or 0
	for y=sy,sy+n-1 do
		local x1,y1 = sgets(sx+0,y,sx+1,y)
		local x2,y2 = sgets(sx+2,y,sx+3,y)
		local x3,y3 = sgets(sx+4,y,sx+5,y)
		if x1+y1+x2+y2+x3+y3 ~= 0 then
			local co,lc = sgets(sx+6,y,sx+7,y)
			co,lc = override_col or co, override_line or lc
		
			if blend then	 
				local x1b,y1b = sgets(sx2+0,y,sx2+1,y)
				local x2b,y2b = sgets(sx2+2,y,sx2+3,y)
				local x3b,y3b = sgets(sx2+4,y,sx2+5,y)
				x1,y1,x2,y2,x3,y3 = lerp(blend,x1,x1b,y1,y1b,x2,x2b,y2,y2b,x3,x3b,y3,y3b)
			end
		
			tfill(co,lc,m33,xys_add(ox,oy,x1,y1, x2,y2, x3,y3))
		end
	end
end