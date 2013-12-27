MESHNODE_MAX_SPEED = 2
MESHNODE_MAX_LIFT = 1
MESHNODE_YAW_AMOUNT = 0.02
MESHNODE_MAX_RADIUS = 50
MESHNODE_SHOW_IN_CREATIVE = true

meshnode = {
	face_rotation = {
		{x=0, y=0, z=0}, {x=0, y=90, z=0}, {x=0, y=180, z=0}, {x=0, y=-90, z=0},
		{x=90, y=0, z=0}, {x=90, y=0, z=90}, {x=90, y=0, z=180}, {x=90, y=0, z=-90},
		{x=-90, y=0, z=0}, {x=-90, y=0, z=-90}, {x=-90, y=0, z=180}, {x=-90, y=0, z=90},
		{x=0, y=0, z=-90}, {x=90, y=90, z=0}, {x=180, y=0, z=90}, {x=0, y=-90, z=-90},
		{x=0, y=0, z=90}, {x=0, y=90, z=90}, {x=180, y=0, z=-90}, {x=0, y=-90, z=90},
		{x=180, y=180, z=0}, {x=180, y=90, z=0}, {x=180, y=0, z=0}, {x=180, y=-90, z=0},
	}
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

function meshnode:create(pos, parent)
	local node = minetest.get_node(pos)
	local item = minetest.registered_items[node.name]
	local object = nil
	local rotation = {x=0, y=0, z=0}
	if item then
		if item.tiles then
			local t = item.tiles
			local textures = {t[1], t[1], t[1], t[1], t[1], t[1]}
			if #t == 3 then
				textures = {t[1], t[2], t[3], t[3], t[3], t[3]}
			elseif #t == 6 then
				textures = t
			end
			local properties = {textures=textures}
			if item.drawtype == "fencelike" then
				textures = {
					"meshnode_trans.png",
					"meshnode_trans.png",
					"meshnode_trans.png",
					"meshnode_trans.png",
					t[1],
				}
				local p = pos
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
				end
				object = minetest.add_entity(pos, "meshnode:mesh")
				properties.textures = textures
				properties.mesh = "meshnode_fence.x"
				properties.visual = "mesh"
			elseif item.drawtype == "plantlike" then
				object = minetest.add_entity(pos, "meshnode:mesh")
				properties.textures = {textures[1]}
				properties.mesh = "meshnode_plant.x"
				properties.visual = "mesh"
			elseif string.find(node.name, "stairs:slab") then
				object = minetest.add_entity(pos, "meshnode:mesh")
				properties.textures = {textures[1]}
				properties.mesh = "meshnode_slab.x"
				properties.visual = "mesh"
			elseif string.find(node.name, "stairs:stair") then
				object = minetest.add_entity(pos, "meshnode:mesh")
				properties.textures = {textures[1]}
				properties.mesh = "meshnode_stair.x"
				properties.visual = "mesh"
			elseif item.drawtype == "normal" or
				item.drawtype == "allfaces_optional" or
				item.drawtype == "glasslike" then
				object = minetest.add_entity(pos, "meshnode:mesh")
				properties.visual = "cube"
			end
			if object then
				object:set_properties(properties)
				local facedir = node.param2
				if item.paramtype2 == "facedir" and facedir then
					rotation = self.face_rotation[facedir + 1]
				end
				if parent then
					local offset = vector.subtract(pos, parent:getpos())
					offset = vector.multiply(offset, {x=10,y=10,z=10})
					object:set_attach(parent, "", offset, rotation)
				end
			end
		end
	end
	return object, rotation
end

