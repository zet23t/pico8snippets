pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
cartfile = "spc.p8"

mesh_x=0
mesh_y=8

reload(0x4300,0x0000,0x1000,cartfile)
reload(0x5300,0x3000,0x100,carfile)

function save()
	cstore(0x0000,0x4300,0x1000,cartfile)
	cstore(0x3000,0x5300,0x100,cartfile)
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
--	return sset(x,y,v)
end
function dsget(x,y)
	local addr = 64 * y + (x>>1) + 0x4300
	local byte = peek(addr,1)
	return x%2 == 0 and (byte & 0xf) or flr(byte >> 4)
end

local function getcols(i)
	return dsget(mesh_x+6,mesh_y+i),dsget(mesh_x+7,mesh_y+i)
end

local function setcols(i,f,l)
	dsset(mesh_x+6,mesh_y+i,f)
	dsset(mesh_x+7,mesh_y+i,l)
end

-- activate cursor reading
poke(0x5f2d, 1)
local mx,my,but
local mouse_clicked, mouse_moved
local selected_triangle = 0
local tcorner_put = 0

function local_pos(x,y)
	local cx,cy = peek2(0x5f28), peek2(0x5f2a)
	return x+cx,cy+y
end

function is_cursor_inside(x,y,w,h)
	local cx,cy = peek2(0x5f28), peek2(0x5f2a)
	local rmx,rmy = cx + mx, cy + my
	return rmx >= x and rmy >= y and rmx < x + w and rmy < y + h
end

function is_clicked(x,y,w,h)
	return mouse_clicked and is_cursor_inside(x,y,w,h)
end

hover_stack = {}
hover_active = {}

function push(t,id)
	t[#t+1] = id
	t[id] = (t[id] or 0) + 1
end

function has(t,id)
	return (t[id] or 0) > 0
end

function pop(t)
	if #t > 0 then
		local id = t[#t]
		t[id] = max(0,(t[id] or 0) - 1)
		deli(t,#t)
	end
end

function hover_spr(id,sprid,x,y,col)
	local hashover = has(hover_stack,id)
	if hashover then
		push(hover_active,id)
		rectfill(x-2,y-2,x+10,y+10,col)
	end
	spr(sprid,x,y)
	if not is_cursor_inside(x,y,8,8) then
		return hashover
	end
	push(hover_stack,id)
	return true
end

function hover_area(id,x,y,w,h,parent_id)
	if not has(hover_stack,parent_id) and 
		not (parent_id == "root" and #hover_stack == 0) then
		return
	end
	local hashover = has(hover_stack,id)
	if hashover then
		push(hover_active,id)
	end
	if not is_cursor_inside(x,y,w,h) then
		return hashover
	end
	push(hover_stack,id)
	return true
end

function endhover(x1,y1,x2,y2)
	local current = hover_active[#hover_active]
	pop(hover_active)
	if not is_cursor_inside(x1,y1,x2-x1,y2-y1) then
		pop(hover_stack)
	end
end

function _draw()
	mouse_clicked = false
	active_click = but
	prevx,prevy = mx or 0,my or 0
	mx,my,but = stat(32),stat(33),stat(34) ~= 0
	
	if but and not active_click then
		active_click = true
		mouse_moved = false
		click_x, click_y = mx,my
	end

	if not but and active_click then
		mouse_clicked = not mouse_moved
	end
	if click_x ~= mx or click_y ~= my then
	 mouse_moved = true
	end
	
	cls(0)
		
	-- color picking
	local scolpick = 6
	local grid = 5
	camera(-31,-127+scolpick * 2)	
	rectfill(0,0,scolpick*16,scolpick*2,1)
	local tcol,lcol = getcols(selected_triangle)
	rectfill(tcol*scolpick,0,tcol*scolpick+scolpick,scolpick,8)
	rectfill(lcol*scolpick,scolpick,lcol*scolpick+scolpick,scolpick*2,8)

	for i=0,15 do
		local x1 = i * scolpick
		local a,b,c,d = x1+1,1,x1+scolpick-1,scolpick-1
		rectfill(a,b,c,d,i)
		rectfill(a,b+scolpick,c,d+scolpick,i)
		if is_clicked(a,b,c,d) then
		printh(i)
			setcols(selected_triangle,i,lcol)
		elseif is_clicked(a,b+scolpick,c,d+scolpick) then
			setcols(selected_triangle,tcol,i)
		end
	end
	--
	
	local m33 = m33_ang(0,grid*.5-1,grid*.5-1,grid)
	camera(-31,-8)
	cellx, celly = local_pos(mx,my)
	cellx, celly = flr(cellx / grid), flr(celly / grid)
	
	for x=0,15*grid,grid do
		for y=0,15*grid,grid do
			rectfill(x,y,x+grid-1,y+grid-1,
				(x/grid+y/grid)%2)
		end
	end
	draw_smesh(m33,mesh_x,mesh_y,0,0,8)

	local x1,y1,x2,y2,x3,y3 = draw_smesh(m33,mesh_x,mesh_y+selected_triangle,0,0,1,nil,nil,nil,-1,-1)
	if highlighted_triangle then
		draw_smesh(m33,mesh_x,mesh_y+highlighted_triangle,0,0,1,nil,nil,nil,-1,9,-1)
	end
	
	local lx,ly = local_pos(mx,my)
	local lpx,lpy = local_pos(prevx,prevy)
	local handle = true
	local function in_rect(x,y,rx,ry,w,h)
		return x >= rx and y >= ry and x < rx+w and y < ry + h
	end
	local function corner(x,y,p,...)
		if not x then return end
		x,y = flr(x),flr(y)
		rectfill(x,y,x+2,y+2,2)
		rect(x-1,y-1,x+3,y+3,8)
		local isin = in_rect(lpx,lpy,x,y,grid,grid)
		if p == 0 and (lpx~=lx or lpy~=ly) then
			printh(tostr(isin)..": "..p..", "..x..", "..y)
		end
		if but and handle and isin then
			x,y = flr((lx-1)/grid),flr((ly-1)/grid)
			dsset(mesh_x+p,mesh_y+selected_triangle,x)
			dsset(mesh_x+p+1,mesh_y+selected_triangle,y)
			handle = false
		end
		return corner(...)
	end
	corner(x1,y1,0,x2,y2,2,x3,y3,4)
	
	highlighted_triangle = nil

	camera(0,0)
	fillp()
	rectfill(0,8,30,128,6)
	local function btnpn(b)
		return btnp(b) and 1 or 0
	end
--	selected_triangle =
--	 ((selected_triangle + btnpn(➡️) - btnpn(⬅️)) % 4)
--	 + flr((selected_triangle+btnpn(⬇️)*4-btnpn(⬆️)*4)/4)%2 * 4
	for i=0,7 do
		local x = (i%4)*6 + 1
		local y = flr(i/4)*6 + 9
		local fc,lc = getcols(i)
		rectfill(x,y,x+4,y+4,fc)
		rect(x+1,y+1,x+3,y+3,lc)
		local col = 7
		if hover_area("tri",x,y,6,6,"root") then
			endhover(x,y,6,6)
			highlighted_triangle = i
			if btn(❎) then
				for j=0,7 do
					dsset(mesh_x+j,mesh_y+highlighted_triangle,0)
				end
				tcorner_put = 0
			end
			if mouse_clicked then
				selected_triangle = i
				tcorner_put = 0
			end
			col = 3
		end
		if selected_triangle == i then
			col = 8
		end
		rect(x,y,x+4,y+4,col)
	end
	
	
	rectfill(0,0,128,7,7)
	local function statusprint(s)
		local w = 0
		for i=1,#s do
			local c = sub(s,i,i)
			if c > "z" then
				w = w + 8
			else
				w = w + 4
			end
		end
		print(s,127-w,2,0)
	end
	if cellx >= 0 and celly >= 0 and cellx < 16 and celly < 16 and #hover_stack == 0 then
		statusprint("❎ to set #"..tcorner_put.."◆ ".. cellx..":"..celly)
		if btnp(❎) then
			dsset(mesh_x+tcorner_put*2,mesh_y+selected_triangle,cellx)
			dsset(mesh_x+tcorner_put*2+1,mesh_y+selected_triangle,celly)
			tcorner_put=(tcorner_put+1)%3
		end
		local movex = btnpn(➡️) - btnpn(⬅️)
		local movey = btnpn(⬇️) - btnpn(⬆️)
		for i=0,5 do
			local x,y = mesh_x+i,mesh_y+selected_triangle
			dsset(x,y,dsget(x,y)+(i%2==0 and movex or movey))
		end
	end
	if highlighted_triangle then
		statusprint("❎ to delete triangle")
	end
	draw_open_menu()	
	
	spr(3,16,0)
	if is_clicked(16,0,8,8) then
		--printh("save")
		save()
	end

	
	spr(1,mx-1,my-1)
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

function tcontains(px,py,x1,y1,x2,y2,x3,y3)
	
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
 
 if linecol and linecol >= 0 then
		line(x1,y1,x2,y2,linecol)
		line(x1,y1,x3,y3,linecol)
		line(x2,y2,x3,y3,linecol)
	end
end

function sgets(x,y,...)
	if x then 
		return dsget(x,y),sgets(...) 
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

function draw_smesh(m33,sx,sy,
			ox,oy,n,sx2,sy2,blend,
			override_col,override_line)
	ox = ox or 0
	oy = oy or 0
	for y=sy,sy+n-1 do
	 local x1,y1 = sgets(sx+0,y,sx+1,y)
	 local x2,y2 = sgets(sx+2,y,sx+3,y)
	 local x3,y3 = sgets(sx+4,y,sx+5,y)
	 if not(x1 == y1 and x1 == x2 
	 	and x1 == y2 and x1 == x3 
	 	and x1 == y3 and x1 == 0)
	 then
		 local co,lc = sgets(sx+6,y,sx+7,y)
		 co,lc = override_col or co, override_line or lc
	
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
		 if n == 1 then
		 	return x1,y1,x2,y2,x3,y3
		 end
		end
	end
end
-->8
-- open menu

function draw_open_menu()
	if hover_spr("open",2,3,0,6) then
		rectfill(0,8,128,36,6)
		for i=0,6 do
			local x,y = i*17,9
			local m33 = m33_ang(0,x,y,1)
			local col = 1
			if hover_area("highlight"..i, x,y,16,16, "open") then
				col = 2
				endhover(x,y,16,16)
			end
			rectfill(x,y,x+15,24,col)
			draw_smesh(m33,i*8,8,0,0,8)		
			if is_clicked(x,y,16,16) then
				printh("ok "..i)
			end
		end
		endhover(0,7,128,36)
	end
end
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
00000000110000000111000011111111111001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000016100000199911001c6666c1188118810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000017610000199999101c6666c1018888100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000017761000192222211cccccc1001881000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000017776100192444211c7777c1018888100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000017611000124442101c7777c1188118810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000011161000122222101ccccc10111001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001110000111110011111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
71a4446571a444650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
775b9b42775b9b420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a9494466a94944660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a944a466a944a4660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
044448c1444448c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
040848c1444848c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e4a4a8c1a4a4a8c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e4e8a8c1a4a8a8c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
