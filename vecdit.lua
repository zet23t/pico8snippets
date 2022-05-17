cartfile = "spc.p8"

mesh_x=0
mesh_y=8

reload(0x4300,0x0000,0x1000,cartfile)
reload(0x5300,0x3000,0x100,cartfile)

function save()
	cstore(0x0000,0x4300,0x1000,cartfile)
	cstore(0x3000,0x5300,0x100,cartfile)
end

printc(1,2,3)


local function getcols(i)
	local function dg(j,...)
		if j then
			return dsget(mesh_x+j,mesh_y+i),dg(...)
		end
	end
	return dg(6,7,0,1,2,3,4,5)
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
	return true
end

function add_xy(dx,dy,x,y,...)
	if not x then return end
	return x+dx,y+dy,add_xy(dx,dy,...)
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
	local tmx,tmy = (mx - 31) / grid - .5, (my - 8) / grid - .5
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
	local corner_moved = false
	local function corner(x,y,p,...)
		if not x then return end
		x,y = flr(x),flr(y)
		rectfill(x,y,x+2,y+2,2)
		rect(x-1,y-1,x+3,y+3,8)
		local isin = in_rect(lpx,lpy,x,y,grid,grid)
		-- if p == 0 and (lpx~=lx or lpy~=ly) then
		-- 	printh(tostr(isin)..": "..p..", "..x..", "..y)
		-- end
		if but and handle and isin then
			local nx,ny = flr((lx-1)/grid),flr((ly-1)/grid)
			corner_moved = corner_moved or nx ~= x or ny ~= y
			dsset(mesh_x+p,mesh_y+selected_triangle,nx)
			dsset(mesh_x+p+1,mesh_y+selected_triangle,ny)
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
		local fc,lc,tx1,ty1,tx2,ty2,tx3,ty3 = getcols(i)
		rectfill(x,y,x+4,y+4,fc)
		rect(x+1,y+1,x+3,y+3,lc)
		local col = 7
		local ishov = (hover_area("tri",x,y,6,6,"root") and endhover(x,y,6,6))
		if ishov or tcontains(tmx,tmy,tx1,ty1,tx2,ty2,tx3,ty3) then
			highlighted_triangle = i
			if btn(❎) then
				for j=0,7 do
					dsset(mesh_x+j,mesh_y+highlighted_triangle,0)
				end
				tcorner_put = 0
			end
			if but and highlighted_triangle == selected_triangle and not corner_moved then
				local dx,dy = round((mx - click_x) / grid, (my - click_y) / grid)
				if dx~=0 or dy~=0 then
					click_x = click_x + (mx - click_x) * 1.6
					click_y = click_y + (my - click_y) * 1.6
					for i=0,5 do
						local sx,sy = mesh_x+i,mesh_y+highlighted_triangle
						dsset(sx,sy,dsget(sx,sy) + (i%2==0 and dx or dy))
					end
				end
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
		statusprint("🅾️ to set #"..tcorner_put.."◆ ".. cellx..":"..celly)
		if btnp(🅾️) then
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
	if highlighted_triangle and mx < 30 then
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
