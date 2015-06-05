dofile(minetest.get_modpath(minetest.get_current_modname()).."/meshnode.lua")

local groups = {cracky=3, oddly_breakable_by_hand=3}
if MESHNODE_SHOW_IN_CREATIVE == false then
	groups.not_in_creative_inventory=1
end

local function is_valid_pos(pos)
	if pos then
		if pos.x and pos.y and pos.z then
			return math.abs(pos.x) <= MESHNODE_MAX_RADIUS and
				math.abs(pos.y) <= MESHNODE_MAX_RADIUS and
				math.abs(pos.z) <= MESHNODE_MAX_RADIUS
		end
	end
end

local function get_step(a, b)
	if a > b then
		return -1
	end
	return 1
end

minetest.register_entity("meshnode:ctrl", {
	physical = true,
	visual = "cube",
	visual_size = {x=1, y=1},
	textures = {
		"meshnode_top.png",
		"meshnode_side.png",
		"meshnode_side.png",
		"meshnode_side.png",
		"meshnode_side.png",
		"meshnode_side.png",
	},
	player = nil,
	speed = 0,
	lift = 0,
	on_activate = function(self, staticdata, dtime_s)
		self.object:set_armor_groups({cracky=50})
		if staticdata == "expired" then
			self.object:remove()
		end
	end,
	on_rightclick = function(self, clicker)
		if self.player == nil then
			clicker:set_attach(self.object, "", {x=0,y=15,z=0}, {x=0,y=90,z=0})
			self.player = clicker
		else
			self.player:set_detach()
			self.player = nil
		end
	end,
	on_step = function(self, dtime)
		if self.player then
			local velocity = self.object:getvelocity()
			local yaw = self.object:getyaw()
			local speed = self.speed
			local lift = self.lift
			local ctrl = self.player:get_player_control()
			if ctrl.up then
				speed = speed + 0.1
			elseif ctrl.down then
				speed = speed - 0.1
			else
				speed = speed * 0.99
			end
			if speed > MESHNODE_MAX_SPEED then
				speed = MESHNODE_MAX_SPEED
			elseif speed < 0 - MESHNODE_MAX_SPEED then
				speed = 0 - MESHNODE_MAX_SPEED
			end
			if ctrl.jump then
				lift = lift + 0.1
			elseif ctrl.sneak then
				lift = lift - 0.1
			else
				lift = lift * 0.9
			end
			if lift > MESHNODE_MAX_LIFT then
				lift = MESHNODE_MAX_LIFT
			elseif lift < 0 - MESHNODE_MAX_LIFT then
				lift = 0 - MESHNODE_MAX_LIFT
			end
			if ctrl.left then
				yaw = yaw + MESHNODE_YAW_AMOUNT
			elseif ctrl.right then
				yaw = yaw - MESHNODE_YAW_AMOUNT
			end
			velocity.x = math.cos(yaw) * speed
			velocity.y = lift
			velocity.z = math.sin(yaw) * speed
			self.object:setyaw(yaw)
			self.object:setvelocity(velocity)
			self.speed = speed
			self.lift = lift
		else
			self.object:setvelocity({x=0, y=0, z=0})
			self.speed = 0
			self.lift = 0
		end
	end,
	get_staticdata = function(self)
		return "expired"
	end,
})

minetest.register_entity("meshnode:mesh", {
	physical = true,
	visual_size = {x=1, y=1},
	on_activate = function(self, staticdata, dtime_s)
		if staticdata == "expired" then
			self.object:remove()
		end
	end,
	get_staticdata = function(self)
		return "expired"
	end,
})

local possible_drawtypes = {"fencelike", "plantlike", "normal", "allfaces_optional", "glasslike", "nodebox"}
local function node_allowed(pos)
	local nname = minetest.get_node(pos).name
	if nname == "air" then
		return
	end
	local dt = minetest.registered_nodes[nname]
	if not dt then
		return
	end
	dt = dt.drawtype
	for _,i in pairs(possible_drawtypes) do
		if i == dt then
			return true
		end
	end
end

-- automatically detects minp and maxp if possible
local function get_minmax(pos, max)
	local tab = {pos}
	local num = 2
	local tab_avoid = {[pos.x.." "..pos.y.." "..pos.z] = true}
	local minp = {x=0, y=0, z=0}
	local maxp = {x=0, y=0, z=0}
	while tab[1] do
		for n,p in pairs(tab) do
			--[[
			for i = -1,1 do
				for j = -1,1 do
					for k = -1,1 do
						local p2 = {x=p.x+i, y=p.y+j, z=p.z+k}]]
			for i = -1,1,2 do
				for _,p2 in pairs({
					{x=p.x+i, y=p.y, z=p.z},
					{x=p.x, y=p.y+i, z=p.z},
					{x=p.x, y=p.y, z=p.z+i},
				}) do
					local pstr = p2.x.." "..p2.y.." "..p2.z
					if not tab_avoid[pstr]
					and node_allowed(p2) then
						tab_avoid[pstr] = true
						local p = vector.subtract(p2, pos)
						for _,c in pairs({"x","y","z"}) do
							minp[c] = math.min(minp[c], p[c])
							maxp[c] = math.max(maxp[c], p[c])
						end
						num = num+1
						table.insert(tab, p2)
						if max
						and num > max then
							return false
						end
					end
				end
			end
			tab[n] = nil
		end
	end
	return minp, maxp
end

minetest.register_node("meshnode:controller", {
	description = "Meshnode Controller",
	paramtype2 = "facedir",
	tiles = {"meshnode_top.png", "meshnode_side.png", "meshnode_side.png"},
	is_ground_content = true,
	groups = groups,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", "size[5,3]"
			.."field[0.5,1;2,0.5;minp;Minp;${minp}]"
			.."field[3.0,1;2,0.5;maxp;Maxp;${maxp}]"
			.."button_exit[1.0,2;3,0.5;connect;Generate Entity]"
		)
		meta:set_string("infotext", "Meshnode Controller")
		local minp, maxp = get_minmax(pos, 9000)
		if minp then
			meta:set_string("minp", minp.x..","..minp.y..","..minp.z)
			meta:set_string("maxp", maxp.x..","..maxp.y..","..maxp.z)
		end
	end,
	after_place_node = function(pos, placer)
		if worldedit then
			local name = placer:get_player_name()
			local meta = minetest.get_meta(pos)
			if worldedit.pos1[name] then
				local p = vector.subtract(worldedit.pos1[name], pos)
				meta:set_string("minp", p.x..","..p.y..","..p.z)
			end
			if worldedit.pos2[name] then
				local p = vector.subtract(worldedit.pos2[name], pos)
				meta:set_string("maxp", p.x..","..p.y..","..p.z)
			end
		end
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		if not fields.connect then
			return
		end
		local minp = minetest.string_to_pos(fields.minp)
		local maxp = minetest.string_to_pos(fields.maxp)
		if not is_valid_pos(minp)
		or not is_valid_pos(maxp) then
			local name = sender:get_player_name()
			minetest.chat_send_player(name, "Invalid Position!")
			return
		end
		local parent = minetest.add_entity(pos, "meshnode:ctrl")
		if not parent then
			return
		end
		minetest.remove_node(pos)
		meshnode.create_objects(pos, minp, maxp, parent)
	end,
})

