
-- 0 = y+    1 = z+    2 = z-    3 = x+    4 = x-    5 = y-
local axisnotes = {}
axisnotes[1] = "y is up"
axisnotes[2] = "z is up"
axisnotes[3] = "z is down"
axisnotes[4] = "x is up"
axisnotes[5] = "x is down"
axisnotes[6] = "y is down"

-- An inutitive progression moving thus:
-- x up, x down, y up, y down, z up, z down
local axischain = {}
axischain=[1] = 6
axischain=[2] = 3
axischain=[3] = 4
axischain=[4] = 5
axischain=[5] = 1
axischain=[6] = 2

-- Player preferences

local player_prefs = {}

local function ensure_player_prefs(playername)
	if not player_prefs[playername] then
		player_prefs[playername] = {}
	end
end

local function set_prefs(playername, values)
	ensure_player_prefs(playername)

	for pname,pvalue in pairs(values) do
		if pvalue == 1 then
			player_prefs[playername][pname] = true

		elseif pvalue == 0 then
			player_prefs[playername][pname] = nil

		elseif pvalue ~= nil then
			player_prefs[playername][pname] = pvalue
		end
	end

end

local function get_pref(playername, prefname)
	ensure_player_prefs(playername)

	return player_prefs[playername][prefname]
end

local function send_help(playername)
	minetest.chat_send_player(playername, "Screwdriver: Left-click to choose an upward axis, then right-click to swivel. To turn on orientation help whilst you use the screwdriver, use '/screwdriver messages on'")
	minetest.chat_send_player(playername, "Sprit level: Left-click to reset the orientation of the node, right-click to print orientation information. Messages must be active.")
	minetest.chat_send_player(playername, "Turn messages off with '/screwdriver messages off'")
end

-- Helper functions

local function is_facedir_node(pointed_thing)
	if not pointed_thing or pointed_thing.type ~= "node" then
		return false
	end

	local node = minetest.get_node(pointed_thing.under)

	return node.paramtype == "facedir"
end

local function can_operate(pointed_thing, player)
	if not pointed_thing or pointed_thing.type ~= "node" or is_facedir_node(pointed_thing.under) then
		return false
	end

	local playername = player:get_player_name()

	return minetest.is_protected( pointed_thing.under, playername )
end

-- Getter and setter on param2

local function param2_parts(pos)
	local node = minetest.get_node(pos)
	local rotation = node.param2 % 32 -- get lesser 5 bits
	local remains = node.param2 - rotation -- extra data

	return rotation, remains
end

local function param2_set(pos, rotation, upperbits)
	local node = minetest.get_node(pos)

	node.param2 = upperbits + rotation
	minetest.set_node(pos, node)
end

local function ar_from_facedir(facedir)
	local rot = value % 4
	local axi = (value - rot ) / 4

	return axi,rot
end

local function facedir_from_ar(axis_d, relative_r)
	return axis_d * 4 + relative_r
end

local function axis_message(player, axis, rotation)
	local playername = player:get_player_name()

	if not get_prefs(playername, "messages") then return end

	minetest.chat_send_player(playername, axisnotes[axis+1]..", rotation is "..tostring(rotation))
end

-- Main handlers

local function sd_swivel(itemstack, user, pointed_thing)

	if not can_operate(pointed_thing) then return end

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)
	local axis, rotation = ar_from_facedir(facedir)

	rotation = (rotation + 1) % 4

	rot_message(user, axis, rotation)

	param2_set(pos, facedir_from_ar(axis, rotation), extra)
end

local function sd_flip(itemstack, user, pointed_thing)

	if not can_operate(pointed_thing) then return end

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)
	local axis, rotation = ar_from_facedir(facedir)

	axis = axischain[axis+1]

	rot_message(user, axis, rotation)

	param2_set(pos, facedir_from_ar(axis, rotation), extra)
end

local function sd_reset(itemstack, user, pointed_thing)

	if not can_operate(pointed_thing) then return end

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)

	rot_message(user, 0, 0)

	param2_set(pos, facedir_from_ar(0, 0), extra)

end

local function sd_report(itemstack, user, pointed_thing)

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)
	local axis, rotation = ar_from_facedir(facedir)

	rot_message(user, axis, rotation)

end

-- Tools

minetest.register_tool("screwdriver_plus:screwdriver", {
	description = "Screwdriver+ (try '/screwdriver help')",
	inventory_image = "screwdriver_plus_screwdriver.png",

	on_use = function(itemstack, user, pointed_thing)
		sd_flip(itemstack, user, pointed_thing)
		return itemstack
	end,

	on_place = function(itemstack, user, pointed_thing)
		sd_swivel(itemstack, user, pointed_thing)
		return itemstack
	end,
})

minetest.register_tool("screwdriver_plus:spirit_level", {
	description = "Spirit Level (left-click: reset, right-click: print orientation)",
	inventory_image = "screwdriver_plus_spirit_level.png",

	on_use = function(itemstack, user, pointed_thing)
		sd_reset(itemstack, user, pointed_thing)
		return itemstack
	end,

	on_place = function(itemstack, user, pointed_thing)
		sd_report(itemstack, user, pointed_thing)
		return itemstack
	end,
})

minetest.register_craftitem("screwdriver_plus:steel_cubelet", {
	description = "Steel cubelet",
	wieldimage = "screwdriver_plus_steel_cubelet.png",
})

-- Commands

minetest.register_chatcommand("screwdriver", {
	description = "Configure screwdriver feedback settings",
	params = "messages { on | off }",
	func = function(playername, params)
		if params == "messages on" then
			set_prefs(playername, {messages = true})

		elseif params == "message off" then
			set_prefs(playername, {messages = false})

		elseif params == "help" then
			send_help(playername)

		else
			minetest.chat_send_player("Invalid setting")
		end
	end,
})

-- Recipes
local sp = "screwdriver_plus:steel_cubelet"

minetest.register_craft({
	output = "screwdriver_plus:screwdriver",
	recipe = {
		{sp, "group:stick"}
	}
})

minetest.register_craft({
	output = "screwdriver_plus:spirit_level",
	recipe = {
		{sp, "default:glass", sp},
	}
})

minetest.register_craft({
	output = "screwdriver_plus:steel_cubelet 3",
	type = "shapeless",
	recipe = {"default:steel_ingot"},
})

-- You shattered your steel and recombined it. You really expect a solid ingot? :-P
minetest.register_craft({
	output = "default:iron_lump",
	type = "shapeless",
	recipe = {sp, sp, sp},
})
