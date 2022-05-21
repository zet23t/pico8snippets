------------------------------------------------------------

rectfill_component = class()
function rectfill_component_new(fill, border)
    return rectfill_component.new {fill=fill, border=border}
end
function rectfill_component:draw(ui_rect)
	local x,y = ui_rect:to_world(0,0)
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
	local x,y = ui_rect:to_world(0,0)
	local w,h = ui_rect.w, ui_rect.h
	local sx,sy,sw,sh = self.sx,self.sy,self.sw,self.sh
	local t,r,b,l = self.t, self.r, self.b, self.l
	sspr(sx,sy,l,t,x,y)
	sspr(sx+l,sy,sw-l-r,t,x+r,y,w-r-l,t)
	sspr(sx+sw-r,sy,r,t,x+w-r,y)
	
	sspr(sx,sy+t,l,sh-t-b,x,y+t,l,h-b-t)
	sspr(sx+l,sy+t,sw-l-r,sh-t-b,x+l,y+t,w-l-r,h-b-t)
	sspr(sx+sw-r,sy+t,r,sh-t-b,x+w-r,y+t,r,h-b-t)

	sspr(sx,sy+sh-b,l,b,x,y+h-b)
	sspr(sx+l,sy+sh-b,sw-l-r,b,x+r,y+h-b,w-r-l,b)
	sspr(sx+sw-r,sy+sh-b,r,b,x+w-r,y+h-b)
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
	local w = text_width(self.text)
	local x,y = ui_rect:to_world(0,0)
	local t,r,b,l = self.t, self.r, self.b, self.l
	local maxpos_x = ui_rect.w - r - l
	local maxpos_y = ui_rect.h - t - b
	print(self.text, 
		x + l + self.align_v * maxpos_x - w * self.align_v, 
		y + t + self.align_h * maxpos_y - 6 * self.align_h + 1, self.color)
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

drag_component = class()
function drag_component_new()
	return drag_component.new{}
end
function drag_component:is_pressed_down(ui_rect, mx, my)
	ui_rect.x = mx - self.mx + ui_rect.x
	ui_rect.y = my - self.my + ui_rect.y
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
	-- printc(x,y,ui_rect.w,ui_rect.h,#clip_stack)
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
	ui_rect.x = self.l
	ui_rect.y = self.t
	ui_rect.w = ui_rect.parent.w - self.r - ui_rect.x
	ui_rect.h = ui_rect.parent.h - self.b - ui_rect.y
end

------------------------------------------------------------

function desuffixed_pairs(t)
	local values = {}
	for k,v in pairs(t) do
		local name, id, icon = unpack(split(k,"_"))
		assert(id)
		values[id] = {name, v,icon}
	end
	local i = 0
	return function()
		i = i + 1
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
		x = x + w + 5
		local entry = ui_rect_new(0,0,10,10,ui_rect)
		local rf = entry:add_component(rectfill_component_new(6))		
		local menu,menu_c
		entry:add_component {
			layout_update = function(cmp, ui_rect)
				ui_rect.x = start_x
				ui_rect.y = 9
				ui_rect.w = w + 2
				ui_rect.h = 8
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
				local root = ui_rect:root()
				local x,y = ui_rect:to_world(start_x, entry.y + 8)
				menu = ui_rect_new(x, y, 10, 10, root)
				menu_c = menu:add_component(menu_component_new(v))
			end
		}
		entry:add_component(text_component_new(k,0))
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
				mouse_enter = function(self) r.fill = 7 end,
				mouse_exit = function(self) r.fill = 6 end,
			}
			entry:add_component(text_component_new(k,0,0,0,0,11,0))
			local event_handler = entry:add_component{
				was_triggered = function(self,ui_rect_e,mx,my)
					if type(v) == "function" then
						v(ui_rect_e,mx,my,k)
						ui_rect:remove()
					end
				end,
			}

			if type(v) == "table" then
				local submenu,submenu_c
				function event_handler:draw(ui_rect)
					local x,y = ui_rect:to_world(ui_rect.w-5,1)
					for i=0,6 do
						rectfill(x,y+i,x+3-abs(i-3),y+i,5)
					end
				end
				function event_handler:is_mouse_over(ui_rect)
					local x,y = ui_rect:to_world(ui_rect.w-2,0)
					submenu = ui_rect_new(x, y, 10, 10, ui_rect:root())
					--printc(ui_rect,ui_rect.w)
					submenu_c = submenu:add_component(menu_component_new(v,menu_c))
				end
			end
			if icon then
				entry:add_component(sprite_component_new(icon,1))
			end
			y = y + 9
		else
			entry:add_component(rectfill_component_new(5))
			y = y + 3
		end
	end
	ui_rect.w = maxw + 2
	ui_rect.h = y + 1
end
function menu_component:show(change)
	self.show_count = self.show_count + change
	return self.show_count > 0 and self
end
function menu_component:update(ui_rect)
	self.timeout = self.timeout - 1
	if self.timeout < 0 then
		ui_rect:remove()
	end
end
function menu_component:is_mouse_over(ui_rect)
	if self.owner then self.owner.timeout = 5 end
	self.timeout = 5
end