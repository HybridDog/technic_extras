local load_time_start = os.clock()


-- Allows pumping stuff out of generators
for _,ltier in pairs({"lv", "mv", "hv"}) do
	local name = "technic:"..ltier.."_generator"
	local tube = minetest.registered_nodes[name].tube
	-- lv currently doesnt support pipeworks
	if tube then
		tube.input_inventory = "src"
		minetest.override_item(name, {tube=tube})
	end
end


-- Music player no formspec control
-- the position of the buttons in the texture
local mbox_coords = {
	{1,3}, {5,3}, {9,3}, stop = {13,3},
	{1,7}, {5,7}, {9,7},
	{1,11}, {5,11}, {9,11},
}

-- the size of the buttons and the button coords relative to the approximate punch pos
for n,i in pairs(mbox_coords) do
	mbox_coords[n][3] = i[1]+2
	mbox_coords[n][4] = i[2]+3
	for m,i in pairs(mbox_coords[n]) do
		mbox_coords[n][m] = (i-8.5)/16
	end
end

-- returns the punched button or nil
local function punch_mbox(pos, node, puncher, pt)
	if not (pos and node and puncher and pt) then
		return
	end

	-- abort if the music player is punched not on the top side
	if pt.above.y ~= pt.under.y+1
	or node.param2 > 3 then
		return
	end

	local dir = puncher:get_look_dir()
	local dist = vector.new(dir)

	local plpos = puncher:getpos()
	plpos.y = plpos.y+1.625

	-- get the coords for param2
	local a,mpa,mpb
	if node.param2 == 0 then
		mpb = -1
	elseif node.param2 == 1 then
		mpa = -1
		mpb = -1
		a = true
	elseif node.param2 == 2 then
		mpa = -1
	elseif node.param2 == 3 then
		a = true
	end

	local shpos = {x=pos.x, z=pos.z, y=pos.y+0.5}

	-- get the distance from the approximate to the actual punched pos
	dist.y = shpos.y-plpos.y
	local m = dist.y/dir.y
	dist.x = dist.x*m
	dist.z = dist.z*m
	local tp = vector.subtract(vector.add(plpos, dist), shpos)

	-- multiply to get the coordinates fit to param2
	mpa = mpa or 1
	mpb = mpb or 1
	tp.x = tp.x*mpa
	tp.z = tp.z*mpb
	if a then
		tp.x, tp.z = tp.z, tp.x
	end

	-- search for the punched button
	for n,i in pairs(mbox_coords) do
		if tp.x > i[1]
		and tp.z > i[2]
		and tp.x < i[3]
		and tp.z < i[4] then
			return n
		end
	end
end

-- override the music player
local change_music = minetest.registered_nodes["technic:music_player"].on_receive_fields
local old_punch = minetest.registered_nodes["technic:music_player"].on_punch
minetest.override_item("technic:music_player", {
	paramtype2 = "facedir",
	legacy_facedir_simple = true,
	on_punch = function(pos, node, puncher, pointed_thing)
		local next_track = punch_mbox(pos, node, puncher, pointed_thing)
		if next_track then
			local fields
			if next_track == "stop" then
				fields = {stop = true}
			else
				fields = {["track"..next_track] = true}
			end
			change_music(pos, nil, fields, puncher)
		end
		return old_punch(pos, node, puncher, pointed_thing)
	end
})


-- add the light catching node
local max_power = 31274.2

local S = technic.getter
minetest.register_node(":technic:light_catcher", {
	description = S("Light Catcher"),
	tiles = {"technic_extras_light_catcher.png"},
	groups = {snappy=2, choppy=2, oddly_breakable_by_hand=2, technic_machine=1},
	sounds = default.node_sound_stone_defaults(),
	active = false,
	paramtype = "light",
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("HV_EU_supply", 0)
	end,
	technic_run = function(pos, node)
		local machine_name = S("Light Catcher")

		local light = minetest.get_node_light(pos)
		if light then
			light = light/15
		else
			light = node.param1 or 0
			light = light/256
		end
		local meta = minetest.get_meta(pos)

		if light <= 0 then
			meta:set_string("infotext", S("%s Idle"):format(machine_name))
			meta:set_int("HV_EU_supply", 0)
			return
		end

		local charge_to_give = math.floor(max_power*light^3+0.5)
		meta:set_string("infotext", S("@1 Active (@2 EU)", machine_name, technic.prettynum(charge_to_give)))
		meta:set_int("HV_EU_supply", charge_to_give)
	end,
})

technic.register_machine("HV", "technic:light_catcher", technic.producer)

if minetest.registered_items["weirdores:antimese"] then
	-- Crafting
	minetest.register_craft({
		output = "technic:light_catcher",
		recipe = {
			{"technic:coal_dust", "technic:coal_dust", "technic:coal_dust"},
			{"weirdores:antimese", "weirdores:antimese", "weirdores:antimese"},
			{"weirdores:antimese", "technic:solar_array_hv", "weirdores:antimese"},
		}
	})
end


-- Automatic mk3 mining drill
-- 0 or less for default maximum speed
local speed = 0.1

-- needed to find what the player digs
local function get_pointed_thing(player, range)
	local plpos = player:getpos()
	plpos.y = plpos.y+1.625
	local dir = player:get_look_dir()
	local p2 = vector.add(plpos, vector.multiply(dir, range))
	local _,pos = minetest.line_of_sight(plpos, p2)
	if not pos then
		return
	end
	return {
		under = vector.round(pos),
		above = vector.round(vector.subtract(pos, dir)),
		type = "node"
	}
end

local ranges = {}
local drills = {}
local someone_digging
local timer = 0

-- change the default mk3 drills to get functions, etc.
for i=1,5,1 do
	local name = "technic:mining_drill_mk3_"..i
	local old_item = minetest.registered_items[name]

	ranges[name] = old_item.range or 14

	local old_on_use = old_item.on_use
	drills[name] = old_on_use

	minetest.override_item(name, {
		on_use = function(...)
			someone_digging = true
			timer = -0.5
			return old_on_use(...)
		end
	})
end

-- simulate the players digging with it using a globalstep
minetest.register_globalstep(function(dtime)
	-- abort if noone uses a drill
	if not someone_digging then
		return
	end

	-- abort that it doesn't dig too fast
	timer = timer+dtime
	if timer < speed then
		return
	end
	timer = 0

	local active
	for _,player in pairs(minetest.get_connected_players()) do
		if player:get_player_control().LMB then
			local item = player:get_wielded_item()
			local itemname = item:get_name()
			local func = drills[itemname]
			if func then
				-- player has a mk3 drill as wielditem and holds left mouse button
				local pt = get_pointed_thing(player, ranges[itemname])
				if pt then
					-- simulate the function
					player:set_wielded_item(func(item, player, pt))
				end
				active = true
			end
		end
	end

	-- disable the function if noone currently uses a mk3 drill to reduce lag
	if not active then
		someone_digging = false
	end
end)


-- pencil
local ps = {}
local function enable_formspec(pname, pos)
	if minetest.is_protected(pos, pname) then
		minetest.chat_send_player(pname, "you shouldn't write here, it's protected")
		return
	end
	ps[pname] = pos
	local meta = minetest.get_meta(pos)
	local info = minetest.formspec_escape(meta:get_string("infotext"))
	minetest.show_formspec(pname, "pencil", "size[8,4]"..
		"textarea[0.3,0;8,4.5;newinfo;;"..info.."]"..
		"button[3,5;2,-2;;save]"
	)
end

minetest.register_tool(":technic:pencil", {
	description = "Pencil",
	inventory_image = "technic_pencil.png",
	on_place = function(_, player, pt)
		if not player
		or not pt then
			return
		end
		enable_formspec(player:get_player_name(), pt.under)
	end
})

-- the craft recipe is approximated
minetest.register_craft({
	output = "technic:pencil",
	recipe = {
		{"technic:graphite"},
		{"group:stick"},
	}
})

local change_infotext
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "pencil" then
		return
	end
	change_infotext(player, fields)
end)

function change_infotext(player, fields)
	local pname = player:get_player_name()
	if fields.quit
	or not fields.newinfo then
		ps[pname] = nil
		return
	end
	local pos = ps[pname]
	if not pos then
		return
	end
	if minetest.is_protected(pos, pname) then
		minetest.chat_send_player(pname, "protection seems to be changed")
		return
	end
	minetest.get_meta(pos):set_string("infotext", fields.newinfo)
	minetest.chat_send_player(pname, "you wrote "..fields.newinfo.." at "..minetest.pos_to_string(pos))
end


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[technic_extras] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
