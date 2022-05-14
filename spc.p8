pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
unit_t = 0.0002

local star_dep = {1,5,6,7}
function draw_starfield(x,y,scale)
	local s = 63
	local offsetx,offsety = flr(x / s), flr(y / s)
	for rx=x%s-s,128,s do
	 local seedx = flr(rx / s) - offsetx
--	 print(seedx.." - "..flr(rx/s).." - "..rx.." - "..offsetx,0,8 + rx,8)
		for ry=y%s-s,128,s do
			local seedy = flr(ry / s) - offsety
			srand(seedx + seedy + seedx * seedy)
			for i=1,32 do 
			 local px,py,pz = rnd(s) + rx, rnd(s) + ry, rnd(1)
			 local dx, dy = px - 128, py - 128
			 pset(px + dx * pz, py + dy * pz, star_dep[flr(pz * #star_dep)+1])
			end
		end
--		break
	end
end

function draw_room(x,y,w,h)
	rectfill(x,y,w,h)
end

bodies = {
	{x=330,y=900,r=100,col=12,g=50},
 {x=50,y=50,parent=1,r=10,g=2,
 	draw = function(b,t,x,y,scale)
 		local m33 = m33_ang(t*10,x,y,scale*8)
 		draw_smesh(m33,16,0,-7.5,-7.5,8)
 	end},
	{x=350,y=386,parent=1,r=10,col=12,g=2},
}

function bodies_calc_pos(t,i)
	local b = bodies[i]
	if not b.parent then
		return b.x,b.y
	end
	local px,py = bodies_calc_pos(t,b.parent)
	local ang = atan2(b.y-py,b.x-px)
	local r = distance(b.x,b.y,px,py)
	local vorb = (bodies[b.parent].g/r)^.5
--	local circumference = r*2*3.141593
	local vang = vorb / r / 6.28
--print(vorb.."  "..vang)
--assert(false)
	local mod = 1/vang
	local a = ang+(t/(unit_t/vang))
--	printh(t.." "..mod.." "..a.." "..(unit_t/vang))
	return px + sin(a)*r, py + cos(a)*r
end

function bodies_draw(t,x,y,scale)
	for i=1,#bodies do
		local b = bodies[i]
		local bx,by = bodies_calc_pos(t,i)
		bx,by = (-bx+x)*scale,(-by+y)*scale
		if b.draw then
			b:draw(t,bx,by,scale)
		else
			circfill(bx,by,b.r*scale,b.col)
		end
	end
end

function bodies_calc_gravity(t, x,y,vx,vy, steps)
	for k=1,steps or 1 do
		for i=1,#bodies do
			local b = bodies[i]
			if b.g then
				local bx,by = bodies_calc_pos(t,i)
				local dx,dy = bx - x, by - y
				local nx,ny,d = normalize(dx,dy)
				if d > 0 and 1 / d > 0 then
					vx,vy = 
						vx + b.g * nx / d / d, 
						vy + b.g * ny / d / d
				end
			end
		end
		t = t + unit_t
		x,y = x + vx, y + vy
	end
	return x,y,vx,vy,t
end

simtime = 0
local sx = 0
local sy = 0
local vx, vy = 0.25,-0.1
local ang = 0
local engine = 0
local scale = 1
--[[ 
control modes
- thruster, rotate
- rcs
- zoom

- map
]]
local control_mode = 0
local control_mode_thrust = 0
local control_mode_rcs = 1
local control_mode_zoom = 2
local control_mode_name = {
	"thrust", "rcs", "zoom"
}
local path,futurecalc = {},{}
function _draw()
	cls(0)
	local s,c = sin(ang), cos(ang)
	local fx,fy = 0,2116*engine
	local lx,ly = 2,4
	local rx,ry = -2,4
		
--	print(sx,sy,0,8)
	draw_starfield(sx*.05,sy*.05)
	camera(-64,-64)
	local m = m33_ang(ang,0,0,scale,scale)
	tfill(lx,ly,rx,ry,fx,fy,12,1,m)
	local f = .7
	tfill(lx*f,ly,rx*f,ry,fx*f,fy*f,7,10,m)
	bodies_draw(simtime,sx,sy,scale)
	local r = 58
	circ(0,0,r,3)
	local function ctri(s,c,w,fcol,col)
		camera(s * r - 64, c * r-64)
		tfill(0,0,
			s * 5 + c * w,c * 5 - s * w,
			s * 5 - c * w,c * 5 + s * w, fcol,col)
		camera(-64,-64)
	end
	ctri(s,c,3,11,3)
	local vel = (vx*vx+vy*vy)^.5
	if vel < 0.01 then
		circ(0,0,59,10)
	else
		ctri(-vx / vel, -vy / vel,1,5,5)
		ctri(vx / vel, vy / vel,3,10,4)
	end
	local tdx = (-bodies[1].x+sx)*scale
	local tdy = (-bodies[1].y+sy)*scale
	local ntdx,ntdy,td = normalize(tdx,tdy)
	if td > 58 then
		ctri(-ntdx,-ntdy,2,8,8)
	else
		circ(tdx,tdy,max(3,bodies[1].r * scale+2),8)
	end

--	print(#futurecalc,10,10,7)	
	local futurepos = futurecalc[#futurecalc] or {sx,sy,vx,vy,simtime}
	local simsx,simsy = futurepos[1],futurepos[2]
	local simvx,simvy = futurepos[3],futurepos[4]
	local st = futurepos[5]
--	camera(sx-64,sy-64)
--	rectfill(sx-3,sy-3,sx+3,sy+3)

	local function drawpath(path,col)
		local nx,ny
		for i=1,#path do
			local p = path[i]--,path[i-1]
			--	line((sx-p[1])*scale,(sy-p[2])*scale,(sx-q[1])*scale,(sy-q[2])*scale,col)
			pset((sx-p[1])*scale,(sy-p[2])*scale,col)
		end
	end
	drawpath(path,1)
	local function calc_error(x,y,last,prev)
		if not last or not prev then return 10 end
		local ax,ay = last[1]-prev[1],last[2]-prev[2]
		local bx,by = prev[1]-x,prev[2]-y
		return dot(ax,ay,bx,by)^2
	end
	local err = 0
	for i=1,#futurecalc < 200 and 200 or 50 do
		simsx,simsy,simvx,simvy,st = bodies_calc_gravity(st, simsx,simsy,simvx,simvy,1)
		local last = futurecalc[#futurecalc]
		local prev = futurecalc[#futurecalc-1]
		local e = calc_error(simsx,simsy,last,prev)
		err = e + err
		if err < 1000 then
			futurecalc[#futurecalc] = {simsx,simsy,simvx,simvy,st}
		else
		 err = 0
			futurecalc[#futurecalc+1] = {simsx,simsy,simvx,simvy,st}
		end
	end
	
	drawpath(futurecalc,2)
--	print(#futurecalc,10,18,7)	
	draw_smesh(m,0,8,-7,-7,1)
	
	fillp()
	camera()

	print("mode (❎): ".. control_mode_name[control_mode + 1], 0,0,3)
	
	print("v="..round(length(vx,vy),2)..
		
				" vx:"..round(vx,2).." vy:"..round(vy,2)..
				" x:"..round(sx,2).." y:"..round(sy,2), 0,123,3)
end

function round(n,decs)
	local m = 10^decs
	return flr(n*m+.5)/m
end

simtime_target,simtime_speed = 0, 1 * unit_t

function _update()
	if btnp(❎) then
		control_mode = (control_mode + 1)%3
	end

	local s,c = sin(ang), cos(ang)

	local turn = ((btn(0) and 1 or 0) + (btn(1) and -1 or 0))
	local forward = ((btn(2) and 1 or 0) + (btn(3) and -1 or 0))
	
	if control_mode == control_mode_thrust then
		ang = ang - turn * 0.01
		forward = forward * 0.01
		vx,vy = vx + s * forward, vy + c * forward
		engine = engine * .8 + forward * .2
		if forward ~= 0 then
		 futurecalc={}
		end
	else
		engine = engine * .8
	end
	if control_mode == control_mode_zoom then
		scale = min(3,max(0.01,scale * (forward * .1 + 1)))
	end

	if control_mode == control_mode_rcs then
		local rcs_p = 0.005
		vx,vy = vx + turn * rcs_p, vy + forward * rcs_p
		if turn ~= 0 or forward ~= 0 then
			futurecalc={}
		end
	end
	
	simtime_target = simtime_target + simtime_speed
	while simtime < simtime_target do
		sx,sy,vx,vy,simtime = bodies_calc_gravity(simtime, sx,sy,vx,vy)
	
		if #futurecalc > 1 and futurecalc[1][1] == sx and futurecalc[1][2] == sy then
			deli(futurecalc,1)
		end
		while #futurecalc > 1000
		do
			deli(futurecalc,#futurecalc)
		end
		path[#path+1] = {sx,sy}
		if #path > 100 then
			deli(path,1)
		end
	end
end
-->8
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
 
 if linecol then
		line(x1,y1,x2,y2,linecol)
		line(x1,y1,x3,y3,linecol)
		line(x2,y2,x3,y3,linecol)
	end
end

function sgets(x,y,...)
	if x then 
		return sget(x,y),sgets(...) 
	end
end

local function lerp(a,...)
	local b = 1 - a
	local function l(x1,x2,...)
		if not x1 then return end
		return a * x2 + b * x1,l(...)
	end
	return l(...)
end

function draw_smesh(m33,sx,sy,ox,oy,n,sx2,sy2,blend)
	ox = ox or 0
	oy = oy or 0
	for y=sy,sy+7 do
	 local x1,y1 = sgets(sx+0,y,sx+1,y)
	 local x2,y2 = sgets(sx+2,y,sx+3,y)
	 local x3,y3 = sgets(sx+4,y,sx+5,y)
	 if x1 == y1 and x1 == x2 
	 	and x1 == y2 and x1 == x3 
	 	and x1 == y3 and x1 == 0 
	 then
	 	break
	 end
	 local co,lc = sgets(sx+6,y,sx+7,y)

		if blend then	 
		 local x1b,y1b = sgets(sx2+0,y,sx2+1,y)
		 local x2b,y2b = sgets(sx2+2,y,sx2+3,y)
		 local x3b,y3b = sgets(sx2+4,y,sx2+5,y)
		 x1,y1,x2,y2,x3,y3 = lerp(blend,x1,x1b,y1,y1b,x2,x2b,y2,y2b,x3,x3b,y3,y3b)
	 end

	 x1,y1=m33:mulxy(x1+ox,y1+oy)
	 x2,y2=m33:mulxy(x2+ox,y2+oy)
	 x3,y3=m33:mulxy(x3+ox,y3+oy)

	 tfill(x1,y1,x2,y2,x3,y3,co,lc)
	end
end
-->8

-->8
function dot(x1,y1,x2,y2)
	return x1*x2 + y1*y2
end

function normalize(x,y)
	local m = max(abs(x),abs(y))
	if m == 0 then return x,y,0 end
	x,y = x / m, y / m
	local d = (x*x+y*y)^.5
	return x / d, y / d, d * m
end

function length(dx,dy)
	local d = max(abs(dx),abs(dy))
 local n = min(abs(dx),abs(dy)) / d
 return sqrt(n*n + 1) * d
end

function distance(x1,y1,x2,y2)
	local dx,dy = x1-x2,y1-y2
	local d = max(abs(dx),abs(dy))
 local n = min(abs(dx),abs(dy)) / d
 return sqrt(n*n + 1) * d
end
__gfx__
1ddd2f55000000007686676200000000000000000000000000006000000600000000000000000000000000000000000000000000000000000000000000000000
2fcfdd55000660006786976200000000000000000000000000006666666600000000000000000000000000000000000000000000000000000000000000000000
0ded70a9006666006797986200000000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000000000000
0000000000666600679898a200000000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000000000000
00000000066666600000000000000000000000000000000000000066660000000000000000000000000000000000000000000000000000000000000000000000
00000000066666600000000000000000000000000000000006000666666000600000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000066006666666600660000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000066666666666666660000000000000000000000000000000000000000000000000000000000000000
70a4446571a444650000000000000000000000000000000066666666666666660000000000000000000000000000000000000000000000000000000000000000
775b9b42775b9b420000000000000000000000000000000066006666666600660000000000000000000000000000000000000000000000000000000000000000
a9494466a94944660000000000000000000000000000000006000666666000600000000000000000000000000000000000000000000000000000000000000000
a944a466a944a4660000000000000000000000000000000000000066660000000000000000000000000000000000000000000000000000000000000000000000
044449c1444448c10000000000000000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000000000000
040849cc444848c10000000000000000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000000000000
e4a4a9c1a4a4a8c10000000000000000000000000000000000006666666600000000000000000000000000000000000000000000000000000000000000000000
e4e8a9cca4a8a8c10000000000000000000000000000000000006000000600000000000000000000000000000000000000000000000000000000000000000000
__label__
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888777777888eeeeee888eeeeee888eeeeee888888888888888888888888888888888888888888888ff8ff8888228822888222822888888822888888228888
8888778887788ee88eee88ee888ee88ee888ee88888888888888888888888888888888888888888888ff888ff888222222888222822888882282888888222888
888777878778eeee8eee8eeeee8ee8eeeee8ee88888e88888888888888888888888888888888888888ff888ff888282282888222888888228882888888288888
888777878778eeee8eee8eee888ee8eeee88ee8888eee8888888888888888888888888888888888888ff888ff888222222888888222888228882888822288888
888777878778eeee8eee8eee8eeee8eeeee8ee88888e88888888888888888888888888888888888888ff888ff888822228888228222888882282888222288888
888777888778eee888ee8eee888ee8eee888ee888888888888888888888888888888888888888888888ff8ff8888828828888228222888888822888222888888
888777777778eeeeeeee8eeeeeeee8eeeeeeee888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16661111166616661666116616661666111111111111116616661666166616661666166611111166166616661666166111111111111111111111111111111111
16111111116116161616161116111161111111711111161111611666116111611666161111111611161616111611161611111111111111111111111111111111
16611111116116661661161116611161111117771111166611611616116111611616166111111666166616611661161611111111111111111111111111111111
16111111116116161616161616111161111111711111111611611616116111611616161111111116161116111611161611111111111111111111111111111111
16661666116116161616166616661161111111111111166116661616116116661616166616661661161116661666166611111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116661666166611661666166611111ee111ee1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111611616161616111611116111111e1e1e1e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111611666166116111661116111111e1e1e1e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111611616161616161611116111111e1e1e1e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
166611611616161616661666116111111eee1ee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111111111111111111111111111111111111111111
a666aa66a66aa666a666aa66aaaaaa66a666a6aaaa66aaaaaa66a666a666a6a6a666a666a6a6a171116616661666166616661666166611111111116616161111
a6a6a6a6a6a6aa6aa6aaa6aaaaaaa6aaa6a6a6aaa6aaaaaaa6aaa6a6a6a6a6a6aa6aaa6aa6a6a711161111611666116111611666161111111111161116161111
a66aa6a6a6a6aa6aa66aa666aaaaa6aaa666a6aaa6aaaaaaa6aaa66aa666a6a6aa6aaa6aa666a711166611611616116111611616166111111111166611611111
a6a6a6a6a6a6aa6aa6aaaaa6aaaaa6aaa6a6a6aaa6aaaaaaa6a6a6a6a6a6a666aa6aaa6aaaa6a711111611611616116111611616161111711111111616161171
a666a66aa666a666a666a66aa666aa66a6a6a666aa66a666a666a6a6a6a6aa6aa666aa6aa666a171166116661616116116661616166617111111166116161711
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111166616161666161616661666116616661611116617711cc1117717711cc1117711111111111111111166161611111eee1ee11ee111111666161616661616
11111611161611611616161616111611161616111611171111c11117171111c1111711111777177711111611161611111e1e1e1e1e1e11111611161611611616
11111661161611611616166116611611166616111611171111c11117171111c1111711111111111111111666116111111eee1e1e1e1e11111661161611611616
11111611161611611616161616111611161616111611171111c11117171111c1111711111777177711111116161611111e1e1e1e1e1e11111611161611611616
1111161111661161116616161666116616161666116617711ccc117717711ccc117711111111111111111661161611111e1e1e1e1eee11111611116611611166
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1ccc1ccc111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1c1c1c1c111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1c1c1c1c111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1c1c1c1c111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1ccc1ccc111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16661666116616661611116611711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16161611161116161611161111171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16611661161116661611161111171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16161611161116161611161111171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
16161666116616161666116611711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
17711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11771111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
17711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
82888222822882228888822282228222888282228222822888888888888888888888888888888888888888888228888882228822828282228228882288866688
82888828828282888888888288828882882888828288882888888888888888888888888888888888888888888828888888288282828282888282828888888888
82888828828282288888822288228882882882228222882888888888888888888888888888888888888888888828888888288282822882288282822288822288
82888828828282888888828888828882882882888882882888888888888888888888888888888888888888888828888888288282828282888282888288888888
82228222828282228888822282228882828882228222822288888888888888888888888888888888888888888222888888288228828282228282822888822288
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

__gff__
0000000000000000000000000000000080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000220702207023070230702307023070230702207022070200701f0601c0601906015050110400c03007020020100000001000000000000001000010000000000000000000100001000000000000000000
