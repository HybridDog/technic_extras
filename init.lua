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

		local light = node.param1
		if light then
			light = light/256
		else
			light = minetest.get_node_light(pos) or 0
			light = light/15
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
	minetest.register_craft({
		output = "technic:light_catcher",
		recipe = {
			{"technic:coal_dust", "technic:coal_dust", "technic:coal_dust"},
			{"weirdores:antimese", "weirdores:antimese", "weirdores:antimese"},
			{"weirdores:antimese", "technic:solar_array_hv", "weirdores:antimese"},
		}
	})
end


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[technic_extras] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
