
--- Mobs Redo Registration
--
--  @topic mobs


return function(name, def)
	local new_def = {
		nametag = def.nametag,
		passive = not def.behavior.hostile,
		walk_velocity = def.behavior.speed:get("walk"),
		run_velocity = def.behavior.speed:get("run"),
		jump_height = def.behavior.jump_height,
		stepheight = def.behavior.step_height,
		view_range = def.behavior.search:get("radius"),
		damage = def.behavior.combat.damage,
		knock_back = def.behavior.knockback,
		follow = def.behavior.follow,
		reach = def.behavior.combat.radius,
		attack_players = def.behavior.search:get("target") == "player",
		makes_footstep_sound = not def.behavior.sneaky,
		sounds = {
			distance = def.sounds.distance,
			random = def.sounds.random,
			war_cry = def.sounds.war_cry,
			attack = def.sounds.war_cry,
			shoot_attack = def.sounds.shoot_attack,
			damage = def.sounds.damage,
			death = def.sounds.death,
			jump = def.sounds.jump,
			fuse = def.sounds.fuse,
			explode = def.sounds.explode,
		},
		drops = {},
		collisionbox = def.physical.collisionbox,
		selectionbox = def.physical.selectionbox,
		visual = def.visual.type,
		visual_size = def.visual.size,
		textures = def.visual.textures,
		mesh = def.visual.mesh,
		animation = {
			stand_start = def.animation.idle.start,
			stand_end = def.animation.idle.stop,
			stand_speed = def.animation.idle.speed,
			walk_start = def.animation.walk.start,
			walk_end = def.animation.walk.stop,
			walk_speed = def.animation.walk.speed,
			run_start = def.animation.run.start,
			run_end = def.animation.run.stop,
			run_speed = def.animation.run.speed,
			punch_start = def.animation.attack.start,
			punch_end = def.animation.attack.stop,
			punch_speed = def.animation.attack.speed,
			die_start = def.animation.death.start,
			die_end = def.animation.death.stop,
			die_speed = def.animation.death.speed,
			die_loop = def.animation.death.loop,
			die_rotate = def.animation.death.rotate,
		},
	}

	if type(def.hp) == "table" then
		new_def.hp_min = def.hp.min
		new_def.hp_max = def.hp.max
	else
		new_def.hp_min = def.hp
		new_def.hp_max = def.hp
	end

	if def.modes.idle then
		new_def.stand_chance = def.mode.idle.chance and def.mode.idle.chance * 100
	end
	if def.modes.walk then
		new_def.walk_chance = def.mode.walk.chance  and def.mode.walk.chance * 100
	end

	if type(new_def.follow) == "string" then
		new_def.follow = {new_def.follow}
	end

	for _, drop in ipairs(def.drops) do
		local drop_chance = drop.chance
		if not drop_chance then
			drop_chance = 1
		end

		drop_chance = 1 / drop_chance

		table.insert(new_def.drops, {name=drop.name, min=drop.min, max=drop.max, chance=drop_chance})
	end

	for k, v in pairs(def.mobs_fields) do
		if k ~= "spawn" then
			new_def[k] = v
		end
	end

	mobs:register_mob(name, new_def)

	local base_name = name
	while base_name:find(":") == 1 do
		base_name = base_name:sub(2)
	end

	if def.spawn then
		mobs:spawn({
			name = base_name,
			nodes = def.spawn.nodes,
			interval = def.spawn.interval,
			chance = def.spawn.chance,
			min_light = def.spawn.light_range.min,
			max_light = def.spawn.light_range.max,
			min_height = def.spawn.height_range.min,
			max_height = def.spawn.height_range.max,
			active_object_count = def.spawn.active_object_count,
		})
	end
end
