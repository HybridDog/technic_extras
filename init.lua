local load_time_start = os.clock()

-- Allows pumping stuff out of generators
for _,ltier in pairs({"lv", "mv", "hv"}) do
	local name = "technic:"..ltier.."_generator"
	local tube = minetest.registered_nodes[name].tube
	-- lv currently doesn't support pipeworks
	if tube then
		tube.input_inventory = "src"
		minetest.override_item(name, {tube=tube})
	end
end

local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[technic_extras] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
