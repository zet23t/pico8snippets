pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
#include scripts/uitk.lua
#include scripts/util.lua
#include scripts/math.lua

function _init()
	ui_tk_enable_mouse()
	
	-- a sprite that can be clicked. Used as parent for proxy objects
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

	local window_skin = sprite9_component_new(64,0,8,16,10,3,3,3)


	-- the root element for everything
	ui_root = ui_rect_new(0,0,128,128)
	-- adding a rect fill component for the background
	ui_root:add_component(proxy_instance(window_skin))
	local resizer = ui_rect_new(110,118,8,8, ui_root)
	local resizer_icon = resizer:add_component(sprite_component_new(23))
	function resizer_icon:mouse_enter()
		ui_tk_set_cursor(cursor_resize)
	end
	function resizer_icon:mouse_exit()
		ui_tk_set_cursor(cursor_normal)
	end
	function resizer_icon:layout_update(ui_rect)
		ui_rect:to_front()
		ui_rect.x = ui_rect.parent.w - ui_rect.w - 2
		ui_rect.y = ui_rect.parent.h - ui_rect.h - 2
	end
	function resizer_icon:is_pressed_down(ui_rect, mx, my)
		ui_rect.parent.w = clamp(30,128,mx - self.mx + ui_rect.parent.w)
		ui_rect.parent.h = clamp(30,128,my - self.my + ui_rect.parent.h)
		ui_tk_set_cursor(cursor_resize)
		self:layout_update(ui_rect)
	end
	function resizer_icon:was_pressed_down(ui_rect, mx, my)
		self.mx, self.my = mx,my
	end
	function resizer_icon:was_released()
		ui_tk_set_cursor(cursor_normal)
	end

	ui_root:add_component(text_component_new("demo",7,1,2,2,3,0,0))

	local window_content = ui_rect_new(2,10,100,10,ui_root)
	-- window_content:add_component(sprite_component_new(23))
	window_content:add_component(sprite9_component_new(72,0,8,8,3,3,3,3))
	window_content:add_component(parent_size_matcher_component_new(10,2,10,2))

	local window_content_clipper = ui_rect_new(0,0,0,0,window_content)
	window_content_clipper:add_component(clip_component_new(1,1,1,1))
	window_content_clipper:add_component(parent_size_matcher_component_new())
	-- if true then return end

	-- a colored rectangle that reacts on mouse enter / exit
	local btn = ui_rect_new(8,18,32,10,window_content_clipper)
	local fill = rectfill_component_new(3,4)
	function fill:mouse_enter()
		self.fill = 4
	end
	function fill:mouse_exit()
		self.fill = 3
	end
	btn:add_component(fill)

	-- a button tht looks like a classic button
	local btn = ui_rect_new(42,18,32,9,window_content_clipper)
	-- a scale 9 for the background
	
	btn:add_component(proxy_instance(button_skin))

	-- a text component for the caption
	local t = text_component_new("tick",1)
	function t:was_triggered()
		self.text = self.text == "tick" and "tock!" or "tick"
	end
	btn:add_component(t)

	-- a dragable button element
	local n = 1
	for x=10,80,50 do
		for y=30,110,16 do
			local btn = ui_rect_new(x,y,44,12,window_content_clipper)
			btn:add_component(proxy_instance(button_skin))
			btn:add_component(drag_component_new())
			btn:add_component(text_component_new("drag #"..n,1,0,0,0,8))
			btn:add_component(sprite_component_new(5,2,2))
			btn:add_component {
				was_pressed_down = function(self, ui_rect)
					ui_rect:to_front()
				end}
			n = n + 1
		end
	end
end

function _update()
	ui_tk_update(ui_root)
end

function _draw()
	cls()
	ui_tk_draw(ui_root)
	exec_late_commands()
end


__gfx__
00000000110000007777777d1111111d7777777d01110000111111111110011100777700ddddddd6000000000000000000000000000000000000000000000000
0000000017100000766666611ffffff77ffffff1199911001c6666c118811881079999d0d6666667000000000000000000000000000000000000000000000000
0070070016710000766666611ffffff77ffffff1199999101c6666c10188881079999995d6666667000000000000000000000000000000000000000000000000
0007700016671000766666611ffffff77ffffff1192222211cccccc10018810079999995d6666667000000000000000000000000000000000000000000000000
0007700016667100766666611ffffff77ffffff1192444211c7777c10188881079999995d6666667000000000000000000000000000000000000000000000000
0070070016511100766666611ffffff77ffffff1124442101c7777c11881188179999995d6666667000000000000000000000000000000000000000000000000
0000000011161000766666611ffffff77ffffff1122222101ccccc101110011179999995d6666667000000000000000000000000000000000000000000000000
0000000000111000d1111111d7777777d11111110111110011111100000000007999999567777777000000000000000000000000000000000000000000000000
00000000111111000000000000000000000000000000000000000000000000077ffffff500000000000000000000000000000000000000000000000000000000
00000000177771000000000000000000000000000000000000000000000000757666666500000000000000000000000000000000000000000000000000000000
00000000176610110000000000000000000000000000000000000000000007507666666500000000000000000000000000000000000000000000000000000000
00000000166661d10000000000000000000000000000000000000000000075077666666500000000000000000000000000000000000000000000000000000000
00000000161666d10000000000000000000000000000000000000000000750757666666500000000000000000000000000000000000000000000000000000000
00000000110166d10000000000000000000000000000000000000000007507507666666100000000000000000000000000000000000000000000000000000000
00000000001dddd10000000000000000000000000000000000000000075075000d66661000000000000000000000000000000000000000000000000000000000
00000000001111110000000000000000000000000000000000000000750750000055510000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
