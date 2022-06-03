------------------------------------------------------------

rectfill_component = class()
function rectfill_component_new(fill, border)
    return rectfill_component.new {fill=fill, border=border}
end
function rectfill_component:draw(ui_rect)
	local x,y = ui_rect:to_world()
	local x2,y2 = x + ui_rect.w - 1, y + ui_rect.h - 1
	if self.fill then rectfill(x,y,x2,y2,self.fill) end
	if self.border then rect(x,y,x2,y2,self.border) end
end

------------------------------------------------------------

sprite9_component = class()
function sprite9_component_new(sx, sy, sw, sh, t, r, b, l)
	return sprite9_component.new {
		sx = sx, sy = sy, sw = sw, sh = sh,
		t=t,r=r,b=b,l=l
	}
end

function sprite9_component:draw(ui_rect)
	local x,y = ui_rect:to_world()
	local w,h = ui_rect.w, ui_rect.h
	local sx,sy,sw,sh = self.sx,self.sy,self.sw,self.sh
	local t,r,b,l = self.t, self.r, self.b, self.l
	local xl = x + l
	local swlr = sw-l-r
	local sxswr = sx+sw-r
	local sxl = sx+l
	local syt = sy+t
	local syshb = sy+sh-b
	local yhb = y+h-b
	local wrl = w-r-l
	local xwr = x+w-r
	local shtb = sh-t-b
	local yt = y+t
	local hbt = h-b-t
	wrap_and_repeat(sspr)
		(sx,sy,l,t,x,y)
		(sxl,sy,swlr,t,xl,y,wrl,t)
		(sxswr,sy,r,t,xwr,y)
	
		(sx,syt,l,shtb,x,yt,l,hbt)
		(sxl,syt,swlr,shtb,xl,yt,wrl,hbt)
		(sxswr,syt,r,shtb,xwr,yt,r,hbt)

		(sx,syshb,l,b,x,yhb)
		(sxl,syshb,swlr,b,xl,yhb,wrl,b)
		(sxswr,syshb,r,b,xwr,yhb)
end

------------------------------------------------------------

text_component = class()
function text_component_new(text, color, t, r, b, l, align_v, align_h)
	return text_component.new {
		text = text, color = color,
		l = l or 0, r = r or 0, t = t or 0, b = b or 0,
		align_v = align_v or 0.5,
		align_h = align_h or 0.5
	}
end
function text_component:draw(ui_rect)
	local x,y = ui_rect:to_world()
	local w = text_width(self.text)
	local t,r,b,l = self.t, self.r, self.b, self.l
	local maxpos_x = ui_rect.w - r - l
	local maxpos_y = ui_rect.h - t - b
	x += l + self.align_v * maxpos_x - w * self.align_v
	y += t + self.align_h * maxpos_y - 6 * self.align_h + 1
	
	print(self.text, x, y, self.color)
end

------------------------------------------------------------

sprite_component = class()
function sprite_component_new(id, x, y, w, h)
	return sprite_component.new {
		id = id, 
		x = x or 0, y = y or 0,
		w = w or 1, h = h or 1
	}
end
function sprite_component:draw(ui_rect)
	local x,y = ui_rect:to_world(self.x,self.y)
	spr(self.id, x, y, self.w, self.h)
end

------------------------------------------------------------

mesh_component = class()
function mesh_component_new(mesh_x, mesh_y, matrix, pivot_x, pivot_y, lines)
	return mesh_component.new {
		mesh_x = mesh_x,
		mesh_y = mesh_y,
		lines = lines or 8,
		pivot_x = pivot_x or 0,
		pivot_y = pivot_y or 0,
		matrix = matrix or m33_ident()
	}
end
function mesh_component:draw(ui_rect)
	local m = m33_offsetted(self.matrix, ui_rect:to_world())
	draw_smesh(m,self.mesh_x, self.mesh_y, self.pivot_x, self.pivot_y, self.lines)
end
function mesh_component:set_mesh(mesh_x, mesh_y, lines)
	self.mesh_x, self.mesh_y, self.lines = mesh_x or self.mesh_x,
		mesh_y or self.mesh_y, lines or self.lines
end

------------------------------------------------------------

drag_component = class()
function drag_component_new()
	return drag_component.new{}
end
function drag_component:is_pressed_down(ui_rect, mx, my)
	ui_rect.x += mx - self.mx
	ui_rect.y += my - self.my
end
function drag_component:was_pressed_down(ui_rect, mx, my)
	self.mx, self.my = mx,my
end

------------------------------------------------------------

clip_component = class()
function clip_component_new(t,r,b,l)
	return clip_component.new {t=t or 0,r=r or 0,b=b or 0,l=l or 0}
end
function clip_component:pre_draw(ui_rect)
	local x,y = ui_rect:to_world(self.l, self.t)
	clip_push(x, y,
		ui_rect.w - self.l - self.r,
		ui_rect.h - self.t - self.b, true)
end
function clip_component:post_draw() 
	clip_pop()
end

------------------------------------------------------------

parent_size_matcher_component = class()
function parent_size_matcher_component_new(t,r,b,l)
	return parent_size_matcher_component.new {t=t or 0,r=r or 0,b=b or 0,l=l or 0}
end
function parent_size_matcher_component:layout_update(ui_rect)
	ui_rect:set_rect(
		self.l, self.t,
		ui_rect.parent.w - self.r - self.l,
		ui_rect.parent.h - self.b - self.t)
end

------------------------------------------------------------

-- method to iterate over a table but splitting the keys at undescores and treating
-- the 2nd value as index. E.g. foo_1 is returned as index_1 element with "foo" as name
local function desuffixed_pairs(t)
	local values = {}
	for k,v in pairs(t) do
		local name, id, icon = unpack(split(k,"_"))
		assert(id)
		values[id] = {name, v,icon}
	end
	local i = 0
	return function()
		i += 1
		if not values[i] then return end
		return unpack(values[i])
	end
end

menubar_component = class()
menu_component = class()

function menubar_component_new(menubar)
	return menubar_component.new {menubar=menubar}
end
function menubar_component:init(ui_rect)
	local x = 2
	for k,v in desuffixed_pairs(self.menubar) do
		local w = text_width(k) + 6
		local start_x = x
		x += w + 5
		local menu_c,entry
		local rf = rectfill_component_new(6)
		entry = ui_rect_new(0,0,10,10,ui_rect,
			rf, {
			layout_update = function(cmp, ui_rect)
				ui_rect:set_rect(start_x, 9, w + 2, 8)
			end,
			mouse_enter = function()
				rf.fill = 7
			end,
			mouse_exit = function()
				rf.fill = 6
			end,
			is_mouse_over = function()
				if menu_c then menu_c.timeout = 5 end
			end,
			was_triggered = function()
				if type(v) == "function" then
					return v()
				end
				local x,y = ui_rect:to_world(start_x, entry.y + 8)
				menu_c = ui_rect_new(x, y, 10, 10, ui_rect:root()):add_component(menu_component_new(v))
			end
		},text_component_new(k,0))
	end
end

function menu_component_new(menu,owner)
	return menu_component.new {menu=menu,owner=owner, show_count = 1, timeout = 5}
end
function menu_component:init(ui_rect)
	local menu_c = self
	ui_rect:add_component(rectfill_component_new(6,5))
	local y = 2
	local maxw = 10
	local menu = self.menu
	if menu.get_menu then
		menu = assert(menu:get_menu())
	end
	for k,v in desuffixed_pairs(menu) do
		local w = text_width(k) + 20
		maxw = max(w,maxw)
	end
	for k,v,icon in desuffixed_pairs(menu) do
		local entry = ui_rect_new(1,y,maxw,k=="" and 1 or 8,ui_rect)
		if k ~= "" then
			local r = entry:add_component(rectfill_component_new(6))
			entry:add_component{
				mouse_enter = function() r.fill = 7 end,
				mouse_exit = function() r.fill = 6 end,
			}
			entry:add_component(text_component_new(k,0,0,0,0,11,0))
			local is_table = type(v) == "table"
			local event_handler = entry:add_component{
				was_triggered = function(self,ui_rect_e,mx,my)
					local fn = type(v) == "function" and v or v.func
					if fn then
						fn(ui_rect_e,mx,my,k)
						ui_rect:remove()
					end
				end,
				draw = function(self,ui_rect_e,mx,my)
					if is_table and v.draw then
						v:draw(ui_rect_e,mx,my)
					end
				end
			}

			if is_table and not v.no_sub_menu then
				local submenu_c
				function event_handler:draw(ui_rect)
					local x,y = ui_rect:to_world(ui_rect.w-5,1)
					for i=0,6 do
						rectfill(x,y+i,x+3-abs(i-3),y+i,5)
					end
				end
				function event_handler:is_mouse_over(ui_rect)
					local x,y = ui_rect:to_world(ui_rect.w-2)
					submenu_c = ui_rect_new(x, y, 10, 10, ui_rect:root()):add_component(menu_component_new(v,menu_c))
				end
			end
			if icon then
				entry:add_component(sprite_component_new(icon,1))
			end
			y += 9
		else
			entry:add_component(rectfill_component_new(5))
			y += 3
		end
	end
	ui_rect:set_rect(nil,nil,maxw+2,y+1)
	--local x,y = ui_rect:to_world()
	if ui_rect.x+ui_rect.w > 128 then
		ui_rect.x = 128 - ui_rect.w
	end
end
function menu_component:show(change)
	self.show_count += change
	return self.show_count > 0 and self
end
function menu_component:update(ui_rect)
	self.timeout -= 1
	if self.timeout < 0 then
		ui_rect:remove()
	end
end
function menu_component:is_mouse_over(ui_rect)
	if self.owner then self.owner.timeout = 5 end
	self.timeout = 5
end

------------------------------------------------------------

scrollbar_component = class()

function scrollbar_component_new(axis, shaft_skin_component, slider_skin_component, button_skin_component, icon_less_component, icon_more_component)
	return scrollbar_component.new {
		axis = axis, 
		shaft_skin_component = shaft_skin_component, 
		slider_skin_component = slider_skin_component, 
		button_skin_component = button_skin_component, 
		icon_less_component = icon_less_component, 
		icon_more_component = icon_more_component,
		range=100,
		scope=20,
		pos=0
	}
end

function scrollbar_component:init(ui_rect)
	ui_rect:add_component_proxy(self.shaft_skin_component)

	self.less_rect = ui_rect_new_with_proxy_components(0,0,0,0,ui_rect, 
		self.button_skin_component, self.icon_less_component)
	self.more_rect = ui_rect_new_with_proxy_components(0,0,0,0,ui_rect, 
		self.button_skin_component, self.icon_more_component)
	self.slider_rect = ui_rect_new_with_proxy_components(0,0,0,0,ui_rect,
	 	self.slider_skin_component)

	self.slider_rect:add_component({
		was_pressed_down = function(cmp,ui_rect,mx,my)
			self.dragging = true
			self.drag_x, self.drag_y = mx, my
		end,
		was_released = function(self) self.dragging = false end,
		is_pressed_down = function(cmp,ui_rect,mx,my)
			local dx, dy = mx - self.drag_x, my - self.drag_y
			local d = self.axis == 1 and dx or dy

			local w,h = ui_rect.w, ui_rect.h
			local horizontal = self.axis == 1
			local available_size = horizontal and (w-h*2) or (h-2*w)
			local slider_size = max(horizontal and h or w, self.scope / self.range * available_size)
			local wiggle_room = available_size - slider_size
			local position = self.pos / (self.range-self.scope) * wiggle_room

			local next_position = position + d
			local next_pos = (self.range-self.scope) * next_position / wiggle_room
			self.pos = clamp(0,self.range-self.scope,next_pos)
		end
	})
end

function scrollbar_component:layout_update(ui_rect)
	local w,h = ui_rect.w, ui_rect.h
	local horizontal = self.axis == 1
	local available_size = horizontal and (w-h*2) or (h-2*w)
	local slider_size = max(horizontal and h or w, self.scope / self.range * available_size)
	local wiggle_room = available_size - slider_size
	local position = self.pos / (self.range-self.scope) * wiggle_room
	if self.axis == 1 then
		self.less_rect:set_rect(0,0, h,h)
		self.more_rect:set_rect(w-h,0, h,h)
		self.slider_rect:set_rect(h,0, slider_size,h)
	else
		self.less_rect:set_rect(0,0, w,w)
		self.more_rect:set_rect(0,h-w, w,w)
		self.slider_rect:set_rect(0,w, w,slider_size)
	end
end