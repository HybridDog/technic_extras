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
		mbox_coords[n][m] = (i-8)/16
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
	local a,b,c,mpa,mpb
	c = "y"
	if node.param2 == 0 then
		a = "x"
		b = "z"
	elseif node.param2 == 1 then
		a = "z"
		b = "x"
		mpa = -1
	elseif node.param2 == 2 then
		a = "x"
		b = "z"
		mpb = -1
		mpa = -1
	elseif node.param2 == 3 then
		a = "z"
		b = "x"
		mpb = -1
	end

	local shpos = {[a]=pos[a], [b]=pos[b], [c]=pos[c]+0.5}

	-- get the distance from the approximate to the actual punched pos
	dist[c] = shpos[c]-plpos[c]
	local m = dist[c]/dir[c]
	dist[a] = dist[a]*m
	dist[b] = dist[b]*m
	local tp = vector.subtract(vector.add(plpos, dist), shpos)

	-- multiply to get the coordinates fit to param2
	mpa = mpa or 1
	mpb = mpb or 1
	tp[a] = tp[a]*mpa
	tp[b] = tp[b]*mpb

	-- search for the punched button
	for n,i in pairs(mbox_coords) do
		if tp[a] > i[1]
		and tp[b] > i[2]
		and tp[a] < i[3]
		and tp[b] < i[4] then
			return n
		end
	end
end



local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[technic_extras] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
