dofile(minetest.get_modpath(minetest.get_current_modname()).."/meshnode.lua")

local gropus = {cracky=3, oddly_breakable_by_hand=3}
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
		if fields.connect and not fields.quit then
			local minp = minetest.string_to_pos(fields.minp)
			local maxp = minetest.string_to_pos(fields.maxp)
			if is_valid_pos(minp) and is_valid_pos(maxp) then
				local node = minetest.get_node(pos)
				minetest.remove_node(pos)
				local positions = {}
				local parent = minetest.add_entity(pos, "meshnode:ctrl")
				if parent then
					for x = minp.x, maxp.x, get_step(minp.x, maxp.x) do
						for y = minp.y, maxp.y, get_step(minp.y, maxp.y) do
							for z = minp.z, maxp.z, get_step(minp.z, maxp.z) do
								local node_pos = vector.add(pos, {x=x, y=y, z=z})
								meshnode:create(node_pos, parent)
								table.insert(positions, node_pos)
							end
						end
					end
					for _, pos in pairs(positions) do
						minetest.remove_node(pos)
					end
				end
			else
				local name = sender:get_player_name()
				minetest.chat_send_player(name, "Invalid Position!")
			end
		end
	end,
})

