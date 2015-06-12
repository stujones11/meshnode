MESHNODE_MAX_SPEED = 2
MESHNODE_MAX_LIFT = 1
MESHNODE_YAW_AMOUNT = 0.02
MESHNODE_MAX_RADIUS = 16
MESHNODE_SAVE_OBJECTS = false
MESHNODE_SHOW_IN_CREATIVE = true
MESHNODE_AUTOCONF = false
MESHNODE_AUTOSAVE = false
MESHNODE_AUTOSAVE_TIME = 60
MESHNODE_UPDATE_TIME = 2
MESHNODE_BREAKABLILITY = 100
MESHNODE_RELOAD_DISTANCE = 32
MESHNODE_MAX_OBJECTS = 4096

if minetest.is_singleplayer() then
	MESHNODE_MAX_RADIUS = 40
	MESHNODE_AUTOCONF = true
	MESHNODE_SAVE_OBJECTS = true
	MESHNODE_AUTOSAVE = true
	MESHNODE_AUTOSAVE_TIME = 4
	MESHNODE_UPDATE_TIME = 1
end

if minetest.setting_getbool("creative_mode") then
	MESHNODE_BREAKABLILITY = 25
end

meshnode = {
	new_id = 1,
	nodes = {},
	timer = 0,
}

function meshnode:new(ref)
	ref = ref or {}
	setmetatable(ref, self)
	self.__index = self
	return ref
end

local modpath = minetest.get_modpath(minetest.get_current_modname())
local input = io.open(modpath.."/meshnode.conf", "r")
if input then
	dofile(modpath.."/meshnode.conf")
	input:close()
end

if MESHNODE_AUTOCONF then
	local max = tonumber(minetest.setting_get("max_objects_per_block")) or 0
	local str = tostring(max + MESHNODE_MAX_OBJECTS)
	minetest.setting_set("max_objects_per_block", str)
end

local worldpath = minetest.get_worldpath()
input = io.open(worldpath.."/meshnodes.txt", "r")
if input then
	local data = input:read('*all')
	if data then
		local tmp = minetest.deserialize(data) or {}
		if tmp.new_id and tmp.nodes then
			meshnode.new_id = tmp.new_id
			for id, ref in pairs(tmp.nodes) do
				local node = meshnode:new(ref)
				meshnode.nodes[id] = node
			end
		end
	end
	input = nil
end

local face_rotation = {
	{x=0, y=0, z=0}, {x=0, y=90, z=0}, {x=0, y=180, z=0}, {x=0, y=-90, z=0},
	{x=90, y=0, z=0}, {x=90, y=0, z=90}, {x=90, y=0, z=180}, {x=90, y=0, z=-90},
	{x=-90, y=0, z=0}, {x=-90, y=0, z=-90}, {x=-90, y=0, z=180}, {x=-90, y=0, z=90},
	{x=0, y=0, z=-90}, {x=90, y=90, z=0}, {x=180, y=0, z=90}, {x=0, y=-90, z=-90},
	{x=0, y=0, z=90}, {x=0, y=90, z=90}, {x=180, y=0, z=-90}, {x=0, y=-90, z=90},
	{x=180, y=180, z=0}, {x=180, y=90, z=0}, {x=180, y=0, z=0}, {x=180, y=-90, z=0},
}

function meshnode:save()
	if MESHNODE_SAVE_OBJECTS == false then
		return
	end
	local tmp = {
		new_id = self.new_id,
		nodes = {},
	}
	for id, ref in pairs(self.nodes) do
		local def = {
			id = ref.id,
			pos = ref.pos,
			yaw = ref.yaw,
			node = ref.node,
			parent_id = ref.parent_id,
			fencecons = ref.fencecons,
			rotation = ref.rotation,
			offset = ref.offset,
		}
		tmp.nodes[id] = def
	end
	local output = io.open(worldpath.."/meshnodes.txt",'w')
	if output then
		output:write(minetest.serialize(tmp))
		io.close(output)
	end
end

function meshnode:is_loaded(pos)
	local objects = minetest.get_objects_inside_radius(pos, MESHNODE_RELOAD_DISTANCE)
	for _, object in pairs(objects) do
		if object:is_player() then
			return true
		end
	end
	return false
end

function meshnode:update()
	if self.object then
		local pos = self.object:getpos()
		local yaw = self.object:getyaw()
		if pos and yaw then
			self.pos = pos
			self.yaw = yaw
			return
		end
	end
	if meshnode:is_loaded(self.pos) then
		local object = nil
		if self.node.name == "meshnode:controller" then
			object = meshnode:add_entity(self)
			if object then
				object:setyaw(self.yaw)
				self.object = object
			end
		elseif self.parent_id then
			local parent = self.nodes[self.parent_id]
			if not parent.object then
				return
			end
			local pos = parent.object:getpos()
			if pos then
				object = meshnode:add_entity(self)
				if object then
					object:set_attach(parent.object, "", self.offset, self.rotation)
					self.object = object
				end
			end
		end
		if object then
			local hp = object:get_hp() or 9
			if hp < 10 then
				hp = hp + 1
			end
			object:set_hp(hp)
		end
	end
end

function meshnode:add_entity(ref)
	if #meshnode.nodes >= MESHNODE_MAX_OBJECTS then
		return
	end
	local object = nil
	local item = minetest.registered_items[ref.node.name]
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
			if ref.node.name == "meshnode:controller" then
				object = minetest.add_entity(ref.pos, "meshnode:ctrl")
			elseif item.drawtype == "fencelike" then
				textures = {
					"meshnode_trans.png",
					"meshnode_trans.png",
					"meshnode_trans.png",
					"meshnode_trans.png",
					t[1],
				}
				if ref.fencecons then
					for i = 1, 4 do
						if ref.fencecons[i] == 1 then
							textures[i] = t[1]
						end
					end
				else
					local get_drawtype = function(pos)
						local node = minetest.get_node(pos)
						local item = minetest.registered_items[node.name]
						if item then
							return item.drawtype
						end
					end			
					ref.fencecons = {}
					local p = ref.pos
					if get_drawtype({x=p.x, y=p.y, z=p.z + 1}) == "fencelike" then
						textures[1] = t[1]
						ref.fencecons[1] = 1
					end
					if get_drawtype({x=p.x - 1, y=p.y, z=p.z}) == "fencelike" then
						textures[2] = t[1]
						ref.fencecons[2] = 1
					end
					if get_drawtype({x=p.x + 1, y=p.y, z=p.z}) == "fencelike" then
						textures[3] = t[1]
						ref.fencecons[3] = 1
					end
					if get_drawtype({x=p.x, y=p.y, z=p.z - 1}) == "fencelike" then
						textures[4] = t[1]
						ref.fencecons[4] = 1
					end
				end
				object = minetest.add_entity(ref.pos, "meshnode:mesh")
				properties.textures = textures
				properties.mesh = "meshnode_fence.x"
				properties.visual = "mesh"
			elseif item.drawtype == "plantlike" then
				object = minetest.add_entity(ref.pos, "meshnode:mesh")
				properties.textures = {textures[1]}
				properties.mesh = "meshnode_plant.x"
				properties.visual = "mesh"
			elseif string.find(ref.node.name, "stairs:slab") then
				object = minetest.add_entity(ref.pos, "meshnode:mesh")
				properties.textures = {textures[1]}
				properties.mesh = "meshnode_slab.x"
				properties.visual = "mesh"
			elseif string.find(ref.node.name, "stairs:stair") then
				object = minetest.add_entity(ref.pos, "meshnode:mesh")
				properties.textures = {textures[1]}
				properties.mesh = "meshnode_stair.x"
				properties.visual = "mesh"
			elseif item.drawtype == "normal" or
				item.drawtype == "allfaces_optional" or
				item.drawtype == "glasslike" then
				object = minetest.add_entity(ref.pos, "meshnode:mesh")
				properties.visual = "cube"
			end
			if object then
				object:set_properties(properties)
				local entity = object:get_luaentity()
				if entity then
					entity.meshnode_id = ref.id
					return object
				else
					object:remove()
				end
			end
		end
	end
end

function meshnode:create(pos, parent)
	local node = minetest.get_node_or_nil(pos)
	if not node then
		return
	end
	local ref = nil
	local rotation = {x=0, y=0, z=0}
	local offset = {x=0, y=0, z=0}
	local facedir = node.param2
	if facedir then
		rotation = face_rotation[facedir + 1]
	end
	local id = tostring(self.new_id)
	local def = {
		id = id,
		pos = pos,
		node = node,
		rotation = rotation,
		offset = offset,
	}
	local object = meshnode:add_entity(def)
	if object then
		ref = meshnode:new(def)
		ref.object = object
		ref.yaw = object:getyaw()
		if parent then
			offset = vector.subtract(pos, parent.object:getpos())
			offset = vector.multiply(offset, 10)
			object:set_attach(parent.object, "", offset, rotation)
			ref.parent_id = parent.id
			ref.offset = offset
		end
		self.nodes[id] = ref
		self.new_id = self.new_id + 1
	end
	return ref
end

