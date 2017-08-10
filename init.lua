
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
axischain[1] = 6
axischain[2] = 3
axischain[3] = 4
axischain[4] = 5
axischain[5] = 1
axischain[6] = 2

local screw_materials = {}
screw_materials["screwdriver:screwdriver_steel"]   = { wear_rate = 50,   material = "default:steel_ingot", material_name = "steel", color = "white:0" }
screw_materials["screwdriver:screwdriver_bronze"]  = { wear_rate = 80,   material = "default:bronze_ingot", material_name = "bronze" , color = "orange:90" }
screw_materials["screwdriver:screwdriver_gold"]    = { wear_rate = 160,  material = "default:gold_ingot", material_name = "gold" , color = "yellow:60" }
screw_materials["screwdriver:screwdriver_diamond"] = { wear_rate = 400,  material = "default:diamond", material_name = "diamond" , color = "blue:90" }
screw_materials["screwdriver:screwdriver_mese"]    = { wear_rate = 1000, material = "default:mese_crystal", material_name = "mese" , color = "yellow:100" }

local function get_next_axis(rawaxis)
	return axischain[rawaxis+1] - 1
end

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

-- Helper functions

local function db(message)
	minetest.debug(dump(message) )
end

local function is_facedir_node(pointed_thing)
	local node = minetest.get_node(pointed_thing.under)

	if not pointed_thing or pointed_thing.type ~= "node" then
		return false
	end

	local node_def = minetest.registered_nodes[node.name]

	db(node_def.paramtype2)
	return node_def.paramtype2 == "facedir"
end

local function cant_operate(pointed_thing, player)
	if not pointed_thing or pointed_thing.type ~= "node" or not is_facedir_node(pointed_thing) then
		return true
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
	local rot = facedir % 4
	local axi = ( (facedir - rot ) / 4 ) % 6

	return axi,rot
end

local function facedir_from_ar(axis_d, relative_r)
	return axis_d * 4 + relative_r
end

-- Player feedback

player_huds = {}

local function remove_hud(player, id)
	db("Removing hud "..tostring(id).." for "..player:get_player_name() )
	local playername = player:get_player_name()

	if not player_huds[playername] then return end

	local savedid = player_huds[playername].hid

	-- check hud not yet removed
	if not id then -- remove current
		if savedid == nil then return end -- nothing to remove

		db("Removing current HUD")

	elseif savedid ~= id then -- tried to remove obsolete, or non-existent
		db("HUD "..tostring(id).." no longer relevant.")
		return
	end
	-- here, savedid must be non-nil

	db("Removing "..tostring(savedid) )

	-- remove it
	player:hud_remove(savedid)
	player_huds[playername].hid = nil
end

local function set_hud(player, message)
	-- remove pre-existing hud
	remove_hud(player)

	-- write new hud
	local hid = player:hud_add({
		hud_elem_type = "text",
		direction = 0,
		name = "orientation",
		text = message,
		position = {x=0.05, y=0.85},
		scale = {x=200, y=50},
		number = 0xFFFFFF,
		alignment = {x=1, y=-1},

	})

	db("Setting hud "..tostring(hid) )

	-- save hud id
	player_huds[player:get_player_name()] = { hid=hid, time=os.time() }

	-- set timeout to remove hud
	minetest.after(1, function()
		remove_hud(player, hid)
	end)
end

local function rot_message(player, axis, rotation)
	local playername = player:get_player_name()

	set_hud(player, axisnotes[axis+1]..", Y-rotation is "..tostring(rotation))
end

local function add_wear(itemstack)
	local maxu = screw_materials[itemstack:get_name()].wear_rate

	itemstack:add_wear(math.ceil(65536 / maxu))
end

-- Main handlers

local function sd_swivel(itemstack, user, pointed_thing)

	if cant_operate(pointed_thing, user) then return end

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)
	local axis, rotation = ar_from_facedir(facedir)

	rotation = (rotation + 1) % 4

	rot_message(user, axis, rotation)

	param2_set(pos, facedir_from_ar(axis, rotation), extra)

	return add_wear(itemstack)
end

local function sd_flip(itemstack, user, pointed_thing)

	if cant_operate(pointed_thing, user) then return end

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)
	local axis, rotation = ar_from_facedir(facedir)

	axis = get_next_axis(axis)

	rot_message(user, axis, rotation)

	param2_set(pos, facedir_from_ar(axis, rotation), extra)

	return add_wear(itemstack)
end

local function sd_reset(itemstack, user, pointed_thing)

	if cant_operate(pointed_thing, user) then return end

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)

	rot_message(user, 0, 0)

	param2_set(pos, facedir_from_ar(0, 0), extra)

	return add_wear(itemstack)

end

local function sd_report(itemstack, user, pointed_thing)
	if not is_facedir_node(pointed_thing) then return end

	local pos = pointed_thing.under
	local facedir, extra = param2_parts(pos)
	local axis, rotation = ar_from_facedir(facedir)

	rot_message(user, axis, rotation)

	return add_wear(itemstack)
end

-- Tools

local function capitalize(mystr)
	return mystr -- TODO make firsst letter upper case
end

local function register_screwtools(material, material_name, color)

	minetest.register_tool("screwdriver:screwdriver_"..material_name, {
		description = capitalize(material_name).." Screwdriver+ (try '/screwdriver help')",
		inventory_image = "screwdriver_plus_tip.png^[colorize:"..color.."^screwdriver_plus_screwdriver.png",

		on_use = function(itemstack, user, pointed_thing)
			itemstack = sd_flip(itemstack, user, pointed_thing)
			return itemstack
		end,

		on_place = function(itemstack, user, pointed_thing)
			sd_swivel(itemstack, user, pointed_thing)
			return itemstack
		end,
	})

	minetest.register_tool("screwdriver:spiritlevel_"..material_name, {
		description = capitalize(material_name).." Spirit Level (left-click: reset, right-click: print orientation)",
		inventory_image = "screwdriver_plus_spiritlevel_"..material_name..".png",

		on_use = function(itemstack, user, pointed_thing)
			itemstack = sd_reset(itemstack, user, pointed_thing)
			return itemstack
		end,

		on_place = function(itemstack, user, pointed_thing)
			itemstack = sd_report(itemstack, user, pointed_thing)
			return itemstack
		end,
	})

	-- Recipes

	minetest.register_craft({
		output = "screwdriver:screwdriver_"..material_name,
		recipe = {
			{material, "group:stick"}
		}
	})

	minetest.register_craft({
		output = "screwdriver:spirit_level_"..material_name,
		recipe = {
			{material, "default:glass", material},
		}
	})

end

for _,matdef in pairs(screw_materials) do
	register_screwtools(matdef.material, matdef.material_name, matdef.color)
end

minetest.register_alias("screwdriver:screwdriver_steel", "screwdriver:screwdriver")
