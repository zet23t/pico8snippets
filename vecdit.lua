-- multiscreen support ...?
--poke(0x5f36,1)
--_map_display(1)

cartfile = "spc.p8"

mesh_x=0
mesh_y=8
mesh_size = 8
scale = 5

local function mesh_is_valid(t)
	for i=0,3 do
		if dsget(mesh_x+i*2,mesh_y+t)~=0 or dsget(mesh_x+i*2+1,mesh_y+t)~=0 then
			return true
		end
	end
end
local function mesh_get_xy(t,i,...)
	if i then
		return dsget(mesh_x+i*2,mesh_y+t), dsget(mesh_x+i*2+1,mesh_y+t), mesh_get_xy(t,...)
	end
end

local function mesh_set_xy(t,i,x,y,...)
	dsset(mesh_x+i*2,mesh_y+t,x)
	dsset(mesh_x+i*2+1,mesh_y+t,y)
	if ... then 
		mesh_set_xy(t,i+1,...)
	end
end

local function mesh_swap(t1,t2)
	local swp = {mesh_get_xy(t1,0,1,2,3)}
	mesh_set_xy(t1,0,mesh_get_xy(t2,0,1,2,3))
	mesh_set_xy(t2,0,unpack(swp))
end

local function triangle_get(i)
	local function dg(j,...)
		if j then
			return dsget(mesh_x+j,mesh_y+i),dg(...)
		end
	end
	return dg(0,1,2,3,4,5)
end

local function triangle_set(i,x1,y1,x2,y2,x3,y3,fill, line)
	local function ds(...)
		for j=1,select('#',...) do
			local v = select(j,...)
			if v then 
				dsset(mesh_x+j-1,mesh_y+i,v)
			end
		end
	end
	
	ds(x1,y1,x2,y2,x3,y3,fill,line)
end


local function info_component_new(info)
	return {
		mouse_enter=function() push_status(info) end,
		mouse_exit=function()pop_status()end
	}
end


function load_file(file)
	cartfile = file
	load_cartsprites(file)
	update_title()
end

selected_triangles = {}
undo_step = 0
undo_list = {}
function undo()
	if undo_step > 0 then
		undo_list[undo_step].undo()
		undo_step = undo_step - 1
		-- printc("Undo => ",undo_step)
	end
end
function redo()
	if undo_step < #undo_list then
		undo_step = undo_step + 1
		undo_list[undo_step].redo()
		-- printc("redo => ",undo_step)
	end
end
function undo_redo(f_undo,f_redo)
	while deli(undo_list,undo_step+1) do end
	add(undo_list, {undo=f_undo, redo=f_redo})
	undo_step = #undo_list
	f_redo()
end
function record_undo_states(before, after)
	after = after or get_current_mesh_data()
	undo_redo(function()set_current_mesh_data(before)end, function()set_current_mesh_data(after)end)
end
function get_current_mesh_data()
	local data = {mesh_x=mesh_x,mesh_y=mesh_y,mesh_size=mesh_size,columns={},selected_triangles=flat_copy(selected_triangles)}
	for t=0,mesh_size-1 do
		data.columns[t] = {mesh_get_xy(t,0,1,2,3)}
	end
	return data
end
function set_current_mesh_data(mesh)
	mesh_x, mesh_y, mesh_size = mesh.mesh_x, mesh.mesh_y, mesh.mesh_size
	selected_triangles = flat_copy(mesh.selected_triangles)
	for t=0,mesh_size-1 do
		local row=mesh.columns[t]
		mesh_set_xy(t,0,unpack(row))
	end
end

function _init()
	ui_tk_enable_mouse()
	
	local button_skin = sprite9_component_new(16,0,8,8,2,2,2,2)
	function button_skin:mouse_enter()
		self.sx = 32
	end
	function button_skin:mouse_exit()
		self.sx = 16
	end
	function button_skin:is_pressed_down()
		self.sx = 24
	end
	function button_skin:was_released(rect)
		self.sx = rect.flags.is_mouse_over and 32 or 16
	end

	-- a sprite that can be clicked. Used as parent for proxy objects
	local toggle_button_skin = sprite9_component_new(16,0,8,8,2,2,2,2)
	function toggle_button_skin:init(rect)
		self.ui_rect = assert(rect)
	end
	function toggle_button_skin:mouse_enter()
		self.sx = self.is_on and 24 or 32
	end
	function toggle_button_skin:mouse_exit()
		self.sx = self.is_on and 72 or 16
	end
	function toggle_button_skin:is_pressed_down()
		self.sx = self.is_on and 32 or 24
	end
	function toggle_button_skin:was_released(rect)
		local exitstate = self.is_on and 72 or 16
		local enterstate = self.is_on and 24 or 32
		self.sx = rect.flags.is_mouse_over and enterstate or exitstate
	end
	function toggle_button_skin:was_triggered(rect)
		if not self.can_not_toggle_off or not self.is_on then
			self.is_on = not self.is_on
		end
		self:was_released(rect)
		if self.toggle_group then
			for i=1,#self.toggle_group do
				local t = self.toggle_group[i]
				if t ~= self then
					t:set_state(false)
				end
			end
		end
		if self.on_toggle then
			self:on_toggle(self.is_on)
		end
	end
	function toggle_button_skin:set_state(state)
		self.is_on = state
		self:was_released(self.ui_rect)
	end


	local window_skin = sprite9_component_new(64,0,8,16,10,3,3,3)


	-- the root element for everything
	ui_root = ui_rect_new(0,0,128,128)
	-- adding a rect fill component for the background
	ui_root:add_component(proxy_instance(window_skin))
	local title = ui_root:add_component(text_component_new("vecdit",7,1,2,2,3,0,0))
	function update_title()
		title.text = "vecdit - "..cartfile.." : ("..mesh_x..", "..mesh_y..")"
	end
	update_title()

	local function main_renderer_bg_setter(bg,lines)
		return {
			no_sub_menu = true,
			func = function()
				main_renderer.bg = bg
				main_renderer.line = lines
			end,
			draw = function(self, ui_rect)
				local x,y = ui_rect:to_world(0,0)
				local id = main_renderer.bg == bg and 11 or 10
				spr(id,x+2,y)
			end
		}
	end
	
	ui_root:add_component(menubar_component_new {
		file_1 = {
			open_1_5 = {
				get_menu = function(self)
					local m = {}
					for i,v in ipairs(ls()) do
						m[v.."_"..i] = function() load_file(v) end
					end
					return m
				end,
			},
			save_2_6 = function() printh("save") end,
		},
		edit_2 = {
			copy_1 = function() printh("Settings") end,
			cut_2 = function() printh("Settings") end,
			paste_3 = function() printh("Settings") end,
		},
		view_3 = {
			["bright background_1"] = main_renderer_bg_setter(7,6),
			["neutral background_2"] = main_renderer_bg_setter(13,5),
			["dark background_3"] = main_renderer_bg_setter(0,1)
		},
		about_4 = function()printc("About")end
	})

	local editor_content = ui_rect_new(0,31,128,100,ui_root)
	
	do
		local function draw_highlighted_tris(selected_triangles, x,y)
			local c = flr(time()*5%5)
			if c > 1 then
				fillp(0b0101101001011010.1)
				for i=1,#selected_triangles do
					local t = selected_triangles[i]
					local x1,y1,x2,y2,x3,y3 = xys_add(x,y,multiply_all(scale,triangle_get(t)))
					tfill(x1,y1,x2,y2,x3,y3,c,c)
					--lines(c+7,true,)
				end
				fillp()
			end
		end

		local tool_mode = {highlighted_points = {}}
		function tool_mode.draw(cmp,ui_rect)
			-- mx, my = ui_rect:to_world(mx, my)
			-- circfill(mx,my,2,4)
			local x,y = ui_rect:to_world(0,0)
			local m33 = m33_offsetted(main_renderer_mesh_component.matrix, x,y)
			local highlighted_tris = tool_mode_move.highlighted_tris or {}
			draw_highlighted_tris(
				#highlighted_tris == 0 and selected_triangles or highlighted_tris, flr_all(x+scale*.5,y+scale*.5))
			
			for i=1,#tool_mode_move.highlighted_points do
				local t,i = unpack(tool_mode_move.highlighted_points[i])
				local x,y = m33:mulxy(mesh_get_xy(t,i))
				circfill(x+1,y+1,2,9)
			end
			
			for t=0,7 do
				if (#selected_triangles==0 or tab_contains(selected_triangles,t)) and mesh_is_valid(t) then
					local x1,y1,x2,y2,x3,y3 = xys_add(1,1,m33:mulxy(mesh_get_xy(t,0,1,2)))
					circ(x1,y1,2,8)
					circ(x2,y2,2,8)
					circ(x3,y3,2,8)
				end
			end
		end
		
		tool_mode_select = proxy_instance(tool_mode)
		tool_mode_move = proxy_instance(tool_mode)
		tool_mode_rotate = proxy_instance(tool_mode)
		tool_mode_add = proxy_instance(tool_mode)
		tool_mode_remove = proxy_instance(tool_mode)
		tool_mode_colorize = proxy_instance(tool_mode)

		local function get_points(mx,my)
			local lx,ly = ceil_all(mx / scale, my / scale)
			lx,ly = clamp(0,15,lx - 1, ly - 1)
			local hlist = {}
			for t=0,mesh_size-1 do
				if mesh_is_valid(t) and (#selected_triangles==0 or tab_contains(selected_triangles,t)) then
					for i=0,2 do
						local x,y = mesh_get_xy(t,i)
						if x == lx and y == ly then
							add(hlist, {t,i})
						end
					end
				end
			end
			return hlist,lx,ly
		end
		local function get_triangles(mx,my)
			local lx,ly = mx / scale - .5, my / scale - .5
			local tris = {}
			for t=mesh_size-1,0,-1 do
				if tcontains(0.2,lx,ly,triangle_get(t)) then
					add(tris,t)
				end
			end
			return tris
		end
		
		function tool_mode_select.mouse_enter()
			push_status("click to add/remove triangles")
		end
		function tool_mode_select.mouse_exit() pop_status() end
		function tool_mode_select.draw(cmp, ui_rect)
			--selected_triangles
			local high = tool_mode_select.highlighted_tris
			if not high then return end
			local x,y = flr_all(xys_add(scale*.5,scale*.5, ui_rect:to_world(0,0)))

			draw_highlighted_tris(selected_triangles, x,y)

			if tool_mode_select.adding == nil then
				for i=1,#high do
					local t = high[i]
					lines(time()*8%3+4,true,xys_add(x,y,multiply_all(scale,triangle_get(t))))
					break
				end
			end
		end

		function tool_mode_select.is_mouse_over(cmp,ui_rect, mx, my)
			if tool_mode_select.adding == nil then
				tool_mode_select.highlighted_tris = get_triangles(mx,my)
			end
		end

		function tool_mode_select.is_pressed_down(cmp,ui_rect, mx, my)
			local tri = get_triangles(mx,my)[1]
			if not tri then return end
			del(selected_triangles, tri)
			if tool_mode_select.adding == true then
				add(selected_triangles, tri)
			end
		end
		function tool_mode_select.was_pressed_down(cmp,ui_rect,mx,my)
			tool_mode_select.prev_selection = flat_copy(selected_triangles)
			-- printc("capture ",#tool_mode_select.prev_selection)
			local tris = get_triangles(mx,my)
			tool_mode_select.adding = (#tris == 0 or not del(selected_triangles,tris[1])) and true or false
		end
		function tool_mode_select.was_released(cmp,ui_rect,mx,my)
			local tris = flat_copy(selected_triangles)
			local before = tool_mode_select.prev_selection
			undo_redo(
				function()
					-- printc("undo ",#tris," to ",#before) 
					selected_triangles = flat_copy(before) 
				end,
				function() 
					-- printc("redo ",#before," to ",#tris) 
					selected_triangles = flat_copy(tris) 
				end)
			tool_mode_select.adding = nil
		end

		local function get_moving_triangles(selected_points, mx,my)
			if #selected_points > 0 then
				return {}
			end

			local tlist = get_triangles(mx,my)
			
			if #selected_triangles > 0 then
				for i=1,#tlist do
					if tab_contains(selected_triangles,tlist[i]) then
						return selected_triangles
					end
				end
				return {}
			end
			
			return {tlist[1]}
		end

		function tool_mode_move.is_mouse_over(cmp,ui_rect, mx, my)
			if not tool_mode_move.mouse_down then
				local points, highlighted = get_points(mx,my), tool_mode_move.highlighted_points
				if not tab_compare_i(points, highlighted) then
					tool_mode_move.highlighted_points = points
				else
					highlighted.count = (highlighted.count or 0) + 1
				end
				tool_mode_move.highlighted_tris = get_moving_triangles(tool_mode_move.highlighted_points, mx, my)
			end
		end

		function tool_mode_move.was_triggered(cmp,ui_rect,mx,my)
			local tripoints,list = {},{}
			local maxn = 0
			for ti in all(tool_mode_move.selected_points) do
				local tl = tripoints[ti[1]]
				if not tl then
					tl = {t=ti[1]}
					tripoints[ti[1]] = tl
					add(list,tl)
				end
				add(tl, ti[2])
				maxn = max(maxn, #tl)
			end
			
			if tool_mode_move.mouse_moved or maxn < 2 then
				return
			end
			
			local cx,cy = ui_rect:to_world(mx-6,my-6)
			local expand_button = ui_rect_new(cx,cy, 12,12, ui_root)
			expand_button:add_component(proxy_instance(button_skin))
			expand_button:add_component(sprite_component_new(32,2,2))
			expand_button:add_component({
				mouse_exit = function()
					expand_button:remove()
				end,
				was_triggered = function()
					expand_button:remove()
					local before = get_current_mesh_data()
					local x1,y1 = tool_mode_move.start_x, tool_mode_move.start_y
					local x2,y2 = x1,y1
					x1 += x1 < 10 and 1 or -1
					y2 += y2 < 10 and 1 or -1
					for tl in all(list) do
						for j=2,3 do
							if (tl[j]) mesh_set_xy(tl.t,tl[j],x1,y1)
						end
					end
					record_undo_states(before)
				end
			})

		end

		function tool_mode_move.was_pressed_down(cmp,ui_rect,mx,my)
			tool_mode_move.mouse_down = true
			tool_mode_move.mouse_moved = false
			tool_mode_move.selected_points,
				tool_mode_move.start_x,
				tool_mode_move.start_y = get_points(mx,my)

			tool_mode_move.prev_x,tool_mode_move.prev_y = tool_mode_move.start_x,tool_mode_move.start_y
			tool_mode_move.selected_triangles = get_moving_triangles(tool_mode_move.selected_points,mx,my)
			tool_mode_move.start_mesh_status = get_current_mesh_data()
		end
		function tool_mode_move.is_pressed_down(cmp,ui_rect, mx, my)
			local lx,ly = ceil_all(mx / scale, my / scale)
			lx,ly = clamp(0,15,lx - 1, ly - 1)
			tool_mode_move.mouse_moved = tool_mode_move.mouse_moved or lx~=tool_mode_move.start_x or ly ~= tool_mode_move.start_y
			local dx,dy = lx - tool_mode_move.prev_x, ly - tool_mode_move.prev_y
			tool_mode_move.prev_x,tool_mode_move.prev_y = lx,ly
			tool_mode_move.end_x, tool_mode_move.end_y = lx, ly
			local hlist,tlist = tool_mode_move.selected_points,tool_mode_move.selected_triangles
			for i=1,#hlist do
				local t,i = unpack(hlist[i])
				mesh_set_xy(t,i,lx,ly)
			end
			for i=1,#tlist do
				local t = tlist[i]
				for j=0,2 do mesh_set_xy(t,j, clamp(0,15,xys_add(dx,dy,mesh_get_xy(t,j)))) end
			end
		end
		function tool_mode_move.was_released(cmp, ui_rect, mx, my)
			tool_mode_move.mouse_down = false
			local start_mesh_status = tool_mode_move.start_mesh_status
			record_undo_states(start_mesh_status)
		end

		active_tool_mode = tool_mode_select

		local function selected_triangles_action(redo)
			local tris = flat_copy(selected_triangles)
			undo_redo(function() 
					selected_triangles = flat_copy(tris)
				end,redo)
		end
		local function select_all_triangles()
			selected_triangles_action(
				function()
					selected_triangles = {}
					for i=0,mesh_size-1 do
						if mesh_is_valid(i) then
							add(selected_triangles, i)
						end
					end
				end)
		end
		local function deselect_all_triangles()
			selected_triangles_action(
				function()
					selected_triangles = {}
				end)
		end
		local function invert_triangles()
			selected_triangles_action(function()
					for i=0,mesh_size-1 do
						if not del(selected_triangles,i) and mesh_is_valid(i) then
							add(selected_triangles,i)
						end
					end
				end)
		end
		local function layer_change(dir)
			local decreasing = dir < 0
			return function()
				local start = get_current_mesh_data()
				for i=decreasing and 0 or mesh_size-1, decreasing and mesh_size-2 or 1, -dir do
					local next = i - dir
					if not tab_contains(selected_triangles,i) and tab_contains(selected_triangles,next) then
						del(selected_triangles, next)
						add(selected_triangles, i)
						mesh_swap(i,next)
					end
				end
				record_undo_states(start)
			end
		end

		local x = 2
		for tool in all{
			{icon=26,action=undo, info="undo last action"},
			{icon=27,action=redo, info="redo last undo"},
			{},
			{icon=28,action=select_all_triangles, info="select all triangles"},
			{icon=29,action=deselect_all_triangles, info="clear triangle selection"},
			{icon=30,action=invert_triangles, info="invert triangle selection"},
			{},
			{icon=15,action=layer_change(1), info="move selection behind"},
			{icon=31,action=layer_change(-1), info="move selection to front"},
		} do
			if tool.icon then
				local btn = ui_rect_new(x,18,12,12,ui_root)
				local bs = btn:add_component(proxy_instance(button_skin))
				btn:add_component(sprite_component_new(tool.icon,2,2))
				bs.was_triggered = tool.action
				if tool.info then
					function bs:mouse_enter(...) button_skin.mouse_enter(self,...) push_status(tool.info) end
					function bs:mouse_exit(...) button_skin.mouse_exit(self,...) pop_status() end
				end
				x = x + 12
			else
				x = x + 2
			end
		end

		-- tooolbar
		local toggle_groups = {}
		for i,v in ipairs {
			{icon=25,toggle_group="tool", tool_mode = tool_mode_select, info="toggles triangle selections"},
			{icon=18,toggle_group="tool", tool_mode = tool_mode_move, info="moves points of selection"},
			{icon=19,toggle_group="tool", tool_mode = tool_mode_rotate, info="rotates selected triangles"},
			{icon=20,toggle_group="tool", tool_mode = tool_mode_add, info="adds new triangles"},
			{icon=21,toggle_group="tool", tool_mode = tool_mode_remove, info="removes triangles"},
			{icon=22,toggle_group="tool", tool_mode = tool_mode_colorize, info="paints triangles"},
		} do
			local btn = ui_rect_new(2, (i-1) * 12,12,12,editor_content)
			local c = btn:add_component(proxy_instance(v.toggle_group and toggle_button_skin or button_skin))
			if v.icon then
				btn:add_component(sprite_component_new(v.icon,2,2))
			end
			if v.info then
				btn:add_component(info_component_new(v.info))
			end
			if v.toggle_group then
				local list = toggle_groups[v.toggle_group] or {}
				toggle_groups[v.toggle_group] = list
				list[#list + 1] = c
				c.can_not_toggle_off = true
				c.toggle_group = list
				function c:on_toggle(on)
					if on then 
						active_tool_mode = v.tool_mode
					end
				end
				if #list == 1 then
					c:set_state(true)
				end
			end
		end
	end

	
	local tabs_view = ui_rect_new(97,0,30,72,editor_content)
	tabs_view:add_component(sprite9_component_new(72,0,8,8,3,3,3,3))
	local tabs_content = ui_rect_new(0,0,0,0,tabs_view)
	tabs_content:add_component(parent_size_matcher_component_new(1,1,1,1))
	tabs_content:add_component(clip_component_new())
	local tab_lib_content = ui_rect_new(0,0,128,64,tabs_content)
	tab_lib_content:add_component{
		draw = function(self, ui_rect)
			--
			palt(0,false)
			local x, y = ui_rect:to_world(0,0)
			local mx,my = self.cell_x, self.cell_y
			for sy=0,15 do
				memcpy(64*32, 0x4300 + sy * 64 * 8,64*8)
				for sx=0,15 do
					local tx, ty = x+sx*5,y+sy*5
					local rcol = 
						(mx == sx and my == sy and 9) or
						(mesh_x == sx * 8 and mesh_y == sy * 8 and 8)
						
					if rcol then
						rect(tx, ty, tx+5,ty+5,rcol)
					end
					sspr(sx * 8,32,8,8,tx+1,ty+1, 4, 4)
				end
			end

			palt(0,true)
		end,
		is_mouse_over = function(self, ui_rect, mx, my)
			self.cell_x, self.cell_y = clamp(0,16,flr_all(multiply_all(1/5, mx, my)))
		end,
		was_triggered = function(self, ui_rect, mx, my)
			mesh_x, mesh_y = self.cell_x * 8, self.cell_y * 8
			main_renderer_mesh_component:set_mesh(mesh_x, mesh_y)
		end
	}
	do
		local x = 0
		for tab in all {
				{icon=5,info="select mesh"},
				{icon=16,info="mesh properties"}
			} 
		do
			local tab_rect = ui_rect_new(x,71,16,13, tabs_view)
			tab_rect:add_component(sprite9_component_new(104,0,8,8,1,4,5,2))
			tab_rect:add_component(sprite_component_new(tab.icon,4,2))
			tab_rect:add_component(info_component_new(tab.info))

			tab_rect:to_back()
			x+=14
		end
	end


	local editor_view_content = ui_rect_new(15,0,16.5*scale,16.5*scale,editor_content)
	-- editor_view_content:add_component(sprite_component_new(23))
	editor_view_content:add_component(sprite9_component_new(72,0,8,8,3,3,3,3))
	--editor_view_content:add_component(parent_size_matcher_component_new(18,28,10,15))
	--local vecview = ui_rect_new(0,0,0,0,editor_view_content)
	--vecview:add_component(parent_size_matcher_component_new(1,1,1,1))

	local window_content_clipper = ui_rect_new(0,0,0,0,editor_view_content)
	window_content_clipper:add_component(clip_component_new(0,0,0,0))
	window_content_clipper:add_component(parent_size_matcher_component_new(1,1,1,1))
	main_renderer = window_content_clipper:add_component {
		bg = 0, line = 1, highlighted_line = 2
	}
	function main_renderer:draw(ui_rect)
		local x,y = ui_rect:to_world(0,0)
		local w,h = ui_rect.w, ui_rect.h
		local q = scale * .5
		rectfill(x,y,x+w,y+h,self.bg)
		for i=0,15 do
			local p = (i+.5)*scale
			rectfill(x+q,y+p,x+16*scale-q,y+p,i == self.y and self.highlighted_line or self.line)
			rectfill(x+p,y+q,x+p,y+16*scale-q,i == self.x and self.highlighted_line or self.line)
		end
	end

	function main_renderer:is_mouse_over(ui_rect, mx, my)
		self.x, self.y = flr_all(mx/scale, my/scale)
	end
	
	main_renderer_mesh_component = window_content_clipper:add_component(mesh_component_new(0,8,m33_ang(0,scale*.5-1,scale*.5-1,scale,scale)))
	local tool_proxy = setmetatable({},{__index = function(t,k) return active_tool_mode[k] end })
	window_content_clipper:add_component(tool_proxy)
	
	local status_bar = ui_rect_new(2,117,124,9, ui_root)
	status_bar:add_component(sprite9_component_new(96,0,8,8,3,3,3,3))
	local status_bar_text = status_bar:add_component(text_component_new("",1,1,2,1,2,0))
	local status_stack = {}
	function push_status(status)
		add(status_stack,status_bar_text.text)
		status_bar_text.text = status
	end
	function pop_status()
		status_bar_text.text = deli(status_stack,#status_stack)
	end

	load_file(cartfile)
end

function _update()
	ui_tk_update(ui_root)
	exec_late_commands()
end

function _draw()
	cls()
	ui_tk_draw(ui_root)
end



