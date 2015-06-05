MESHNODE_MAX_SPEED = 2
MESHNODE_MAX_LIFT = 1
MESHNODE_YAW_AMOUNT = 0.02
MESHNODE_MAX_RADIUS = 50
MESHNODE_SHOW_IN_CREATIVE = true

meshnode = {}
local face_rotation = {
	{x=0, y=0, z=0}, {x=0, y=90, z=0}, {x=0, y=180, z=0}, {x=0, y=-90, z=0},
	{x=90, y=0, z=0}, {x=90, y=0, z=90}, {x=90, y=0, z=180}, {x=90, y=0, z=-90},
	{x=-90, y=0, z=0}, {x=-90, y=0, z=-90}, {x=-90, y=0, z=180}, {x=-90, y=0, z=90},
	{x=0, y=0, z=-90}, {x=90, y=90, z=0}, {x=180, y=0, z=90}, {x=0, y=-90, z=-90},
	{x=0, y=0, z=90}, {x=0, y=90, z=90}, {x=180, y=0, z=-90}, {x=0, y=-90, z=90},
	{x=180, y=180, z=0}, {x=180, y=90, z=0}, {x=180, y=0, z=0}, {x=180, y=-90, z=0},
}

local modpath = minetest.get_modpath(minetest.get_current_modname())
local input = io.open(modpath.."/meshnode.conf", "r")
if input then
	dofile(modpath.."/meshnode.conf")
	input:close()
	input = nil
end

function meshnode:get_drawtype(pos)
	local node = minetest.get_node(pos)
	local item = minetest.registered_items[node.name]
	if item then
		return item.drawtype
	end
end

local function get_step(a, b)
	if a > b then
		return -1
	end
	return 1
end

local function getobject(pos, parentpos)
	local node = minetest.get_node(pos)
	local item = minetest.registered_items[node.name]
	if not item then
		return
	end
	if not item.tiles then
		return
	end
	local t = item.tiles
	local textures = {t[1], t[1], t[1], t[1], t[1], t[1]}
	if #t == 3 then
		textures = {t[1], t[2], t[3], t[3], t[3], t[3]}
	elseif #t == 6 then
		textures = t
	end
	local properties = {textures=textures}
	local data = {properties = properties, pos = pos}
	if item.drawtype == "fencelike" then
		textures = {
			"meshnode_trans.png",
			"meshnode_trans.png",
			"meshnode_trans.png",
			"meshnode_trans.png",
			t[1],
		}
		--[[local p = pos
		if self:get_drawtype({x=p.x, y=p.y, z=p.z + 1}) == "fencelike" then
			textures[1] = t[1]
		end
		if self:get_drawtype({x=p.x - 1, y=p.y, z=p.z}) == "fencelike" then
			textures[2] = t[1]
		end
		if self:get_drawtype({x=p.x + 1, y=p.y, z=p.z}) == "fencelike" then
			textures[3] = t[1]
		end
		if self:get_drawtype({x=p.x, y=p.y, z=p.z - 1}) == "fencelike" then
			textures[4] = t[1]
		end]]
		properties.textures = textures
		properties.mesh = "meshnode_fence.x"
		properties.visual = "mesh"
	elseif item.drawtype == "plantlike" then
		properties.textures = {textures[1]}
		properties.mesh = "meshnode_plant.x"
		properties.visual = "mesh"
	elseif string.find(node.name, "stairs:slab") then
		properties.textures = {textures[1]}
		properties.mesh = "meshnode_slab.x"
		properties.visual = "mesh"
	elseif string.find(node.name, "stairs:stair") then
		properties.textures = {textures[1]}
		properties.mesh = "meshnode_stair.x"
		properties.visual = "mesh"
	elseif item.drawtype == "normal" then
		data.usual = true
		properties.visual = "cube"
	elseif item.drawtype == "allfaces_optional"
	or item.drawtype == "glasslike" then
		properties.visual = "cube"
	else
		return
	end
	local rotation = {x=0, y=0, z=0}
	local facedir = node.param2
	if item.paramtype2 == "facedir"
	and facedir then
		rotation = face_rotation[facedir + 1]
	end
	local offset = vector.subtract(pos, parentpos)
	offset = vector.multiply(offset, {x=10,y=10,z=10})
	data.attach = {offset, rotation}
	return data
end

local function get_neighbours(objs, x,y,z)
	local ps = {}
	for i = -1,1,2 do
		for _,pstr in pairs({
			x+i.." "..y.." "..z,
			x.." "..y+i.." "..z,
			x.." "..y.." "..z+i
		}) do
			if objs[pstr]
			and objs[pstr].usual then
				table.insert(ps, pstr)
			end
		end
	end
	return ps
end

function meshnode.create_objects(pos, minp, maxp, parent)
	local todo_objs = {}
	local parentpos = parent:getpos()
	for x = minp.x, maxp.x, get_step(minp.x, maxp.x) do
		for y = minp.y, maxp.y, get_step(minp.y, maxp.y) do
			for z = minp.z, maxp.z, get_step(minp.z, maxp.z) do
				local node_pos = vector.add(pos, {x=x, y=y, z=z})
				local data = getobject(node_pos, parentpos)
				if data then
					todo_objs[x.." "..y.." "..z] = data
				end
			end
		end
	end
	local positions = {}
	for pstr,data in pairs(todo_objs) do
		local x,y,z = unpack(string.split(pstr, " "))
		local allowed = true
		if data.usual then
			local nbs = get_neighbours(todo_objs, x,y,z)
			-- don't spawn unnecessary objects
			if #nbs == 6 then
				allowed = false
			--[[elseif #nbs > 1 then -- this somehow doesnt work
				local textures = data.properties.textures
				for _,pstr in pairs(nbs) do
					local n
					local nx,ny,nz = unpack(string.split(pstr, " "))
					if ny > y then
						n = 1
					elseif ny < y then
						n = 2
					elseif nx > x then
						n = 3
					elseif nx < x then
						n = 4
					elseif nz > z then
						n = 5
					elseif nz < z then
						n = 6
					end
					if n then
						textures[n] = "meshnode_trans.png"
					end
				end]]
			end
		end
		if allowed then
			local pos = data.pos
			table.insert(positions, pos)
			local object = minetest.add_entity(pos, "meshnode:mesh")
			object:set_properties(data.properties)
			local offset, rotation = unpack(data.attach)
			object:set_attach(parent, "", offset, rotation)
		end
	end
	for _, pos in pairs(positions) do
		minetest.remove_node(pos)
	end
end

