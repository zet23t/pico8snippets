-- creates a new object that inherits all members from t (without overwriting anything)
function proxy_instance(t)
	return setmetatable({},{__index = t})
end

local function class()
	local t = {}
	local mt = {__index = t}
	function t.new(t)
		return setmetatable(t or {}, mt)
	end
	return t
end

ui_rect = class()

cursor_normal = {id = 1, offset_x = -1, offset_y = -1}
cursor_resize = {id = 17, offset_x = -4, offset_y = -4}
cursor = cursor_normal

function ui_tk_set_cursor(c)
	cursor = c
end

function ui_tk_draw(root)
	local x,y = ui_tk_get_mouse()
	root:recursive_trigger("layout_update_size")
	root:recursive_trigger("layout_update")
	root:draw()
	clip()
	spr(cursor.id,x+cursor.offset_x,y+cursor.offset_y)
end

local prev_mouse_down, mouse_down
local was_mouse_pressed, was_mouse_released
function ui_tk_update(root)
	local x,y,b = ui_tk_get_mouse()
	mouse_down = b > 0
	was_mouse_pressed = mouse_down and not prev_mouse_down
	was_mouse_released = not mouse_down and prev_mouse_down
	local hits = {}
	root:recursive_trigger("layout_update_size")
	root:recursive_trigger("layout_update")
	root:collect_hits(x,y,hits)
	root:update_flags(x,y,hits)
	root:update(x,y)
	prev_mouse_down = mouse_down
end
function ui_tk_enable_mouse()
    poke(0x5f2d, 1)
end
-- return x,y and if mouse button is pressed (only one mouse button)
function ui_tk_get_mouse()
    return stat(32),stat(33),stat(34)
end

function trigger(cmps, name,...)
	for i=1,#cmps do
		local c = cmps[i]
        local f = c[name]
        if f then
            f(c, ...)
        end
    end
end

function ui_rect:collect_hits(x, y, list)
	x, y = x - self.x, y - self.y
	local is_inside = x < self.w and y < self.h and x >= 0 and y >= 0
	if is_inside then
		add(list, self, 1)
		list[self] = true
	end

	local has_handled = false
	for i=#self.children, 1, -1 do
		if self.children[i]:collect_hits(x, y, list) then
			has_handled = true
			break
		end
	end

	return is_inside or has_handled
end

function ui_rect:update_flags(mx, my, hits)
	mx, my = mx - self.x, my - self.y
	local mouse_over = hits[self] and mx < self.w and my < self.h and mx >= 0 and my >= 0
	if mouse_over and #clip_stack > 0 then
		local wmx,wmy = ui_tk_get_mouse()
		local x1,y1 = self:to_world(0, 0)
		local x2,y2 = self.w + x1, self.h + y1
		local cx,cy,cw,ch = unpack(clip_stack[#clip_stack])
		x1,x2 = clamp(cx, cx + cw, x1, x2)
		y1,y2 = clamp(cy, cy + ch, y1, y2)
		mouse_over = rect_contains(x1,y1,x2,y2,wmx,wmy)
	end
	local flags = self.flags
	flags.was_mouse_over = flags.is_mouse_over
	flags.is_mouse_over = mouse_over
	flags.was_released = false
	flags.was_triggered = false
	flags.was_pressed_down = false
	local was_mouse_over = flags.was_mouse_over
	if was_mouse_pressed and mouse_over then
		flags.is_pressed_down = true
		flags.was_pressed_down = true
	end
	if was_mouse_released and flags.is_pressed_down then
		flags.is_pressed_down = false
		flags.was_released = true
		if mouse_over then
			flags.was_triggered = true
		end
	end
	trigger(self.components, "pre_draw", self)
	trigger(self.children, "update_flags", mx, my, hits)
	trigger(self.components, "post_draw")
end

local function flag_trigger(self, flag_name, mx, my)
	if self.flags[flag_name] then
		trigger(self.components, flag_name, self, mx, my)
	end
end

function ui_rect:recursive_trigger(name, ...)
	trigger(self.components, name, self, ...)
	trigger(self.children, "recursive_trigger", name, ...)
end

function ui_rect:to_front()
	if not self.parent then return end
	del(self.parent.children,self)
	add(self.parent.children,self)
end

function ui_rect:update(mx, my)
	mx, my = mx - self.x, my - self.y
	local mouse_over = self.flags.is_mouse_over
	local flags = self.flags
	local was_mouse_over = flags.was_mouse_over
	
	if mouse_over ~= was_mouse_over then
		trigger(self.components, mouse_over and "mouse_enter" or "mouse_exit", mx, my)
	end
	
	flag_trigger(self, "is_mouse_over", mx, my)
	flag_trigger(self, "was_released", mx, my)
	flag_trigger(self, "was_pressed_down", mx, my)
	flag_trigger(self, "was_triggered", mx, my)
	flag_trigger(self, "is_pressed_down", mx, my)

	trigger(self.components, "update", self, mx, my)
	trigger(self.children, "update", mx, my)
end

function ui_rect:draw()
    trigger(self.components, "pre_draw", self)
    trigger(self.components, "draw", self)
	trigger(self.children, "draw")
    trigger(self.components, "post_draw", self)
end

function ui_rect:to_world(x,y)
    x,y = self.x + x, self.y + y
    if self.parent then
        return self.parent:to_world(x,y)
    end
    return x,y
end

function ui_rect:add_component(cmp)
    return add(self.components, cmp)
end

function ui_rect:set_parent(p)
	self.parent = p
	add(p.children,self)
end

function ui_rect_new(x,y,w,h,parent)
	local self = ui_rect.new {
		x=x,y=y,w=w,h=h,
		flags = {},
		components={},
		children={}
	}
	if parent then
		self:set_parent(parent)
	end
	return self
end

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

clip_stack = {}
function clip_push(x,y,w,h,clip_previous)
	if #clip_stack > 0 and clip_previous then
		local px1,py1,px2,py2 = unpack(clip_stack[#clip_stack])
		local x1, x2 = clamp(px1, px2, x, x + w)
		local y1, y2 = clamp(py1, py2, y, y + h)
		x,y,w,h = x1, y1, x2-x1, y2-y1
	end
	add(clip_stack, {x,y,w,h})
	clip(x,y,w,h)
end

function clip_pop()
	deli(clip_stack,#clip_stack)
	if #clip_stack == 0 then
		return clip()
	end
	-- printc(unpack(clip_stack[#clip_stack]))
	clip(unpack(clip_stack[#clip_stack]))
end

