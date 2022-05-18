--mx,my,but = stat(32),stat(33),stat(34) ~= 0
local function class()
	local t = {}
	local mt = {__index = t}
	function t.new(t)
		return setmetatable(t or {}, mt)
	end
	return t
end

ui_rect = class()

function ui_tk_draw(root)
	local x,y = ui_tk_get_mouse()
	root:draw()
	spr(1,x,y)
end
local prev_mouse_down, mouse_down
local was_mouse_pressed, was_mouse_released
function ui_tk_update(root)
	local x,y,b = ui_tk_get_mouse()
	mouse_down = b > 0
	was_mouse_pressed = mouse_down and not prev_mouse_down
	was_mouse_released = not mouse_down and prev_mouse_down
	local hits = {}
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
	trigger(self.children, "update_flags", mx, my, hits)
end

local function flag_trigger(self, flag_name, mx, my)
	if self.flags[flag_name] then
		trigger(self.components, flag_name, self, mx, my)
	end
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
    trigger(self.components, "draw", self)
	trigger(self.children, "draw")
end

function ui_rect:to_world(x,y)
    x,y = self.x + x, self.y + y
    if self.parent then
        return self.parent:to_world(x,y)
    end
    return x,y
end

function ui_rect:add_component(cmp)
    add(self.components, cmp)
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
function text_component_new(text, color, t, r, b, l)
	return text_component.new {
		text = text, color = color,
		l = l or 0, r = r or 0, t = t or 0, b = b or 0
	}
end
function text_component:draw(ui_rect)
	local w = text_width(self.text)
	local x,y = ui_rect:to_world(0,0)
	local t,r,b,l = self.t, self.r, self.b, self.l
	print(self.text, 
		x + l + (ui_rect.w - w - l - r) * .5, 
		y + t + (ui_rect.h - 6 - t - b) * .5 + 1, self.color)
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