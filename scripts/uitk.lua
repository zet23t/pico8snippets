-- creates a new object that inherits all members from t (without overwriting anything)
function proxy_instance(t)
	return setmetatable({},{__index = t})
end

function class()
	local t = {}
	local mt = {__index = t}
	function t.new(tt)
		assert(tt~=t)
		return setmetatable(tt or {}, mt)
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

function ui_rect:root()
	return self.parent and self.parent:root() or self
end

function ui_rect:to_front()
	if not self.parent then return end
	del(self.parent.children,self)
	add(self.parent.children,self)
end

function ui_rect:remove()
	if self.parent then
		late_command(function()
			del(self.parent.children, self)
			self.parent = nil
		end)
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
    add(self.components, cmp)
	if cmp.init then cmp:init(self) end
	return cmp
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

---

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

