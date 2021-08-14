
--- Mobs Redo Registration
--
--  @topic mobs


return function(name, def)
	local new_def = {
		nametag = def.nametag,
		type = "monster",
		passive = not def.behavior.hostile,
		walk_velocity = def.behavior.speed:get("walk"),
		run_velocity = def.behavior.speed:get("run"),
		--stand_chance = def.mode_chance.idle * 100,
		--walk_chance = def.mode_chance.walk * 100,
		jump = type(def.stepheight) == "number" and def.stepheight > 0,
		jump_height = def.stepheight,
		stepheight = def.stepheight,
		view_range = def.behavior.search:get("radius"),
		damage = def.behavior.combat.damage,
		knock_back = def.knockback,
		floats = def.floats,
		reach = def.behavior.combat.radius,
		attack_chance = def.behavior.combat.chance,
		attack_players = def.behavior.search:get("type") == "player",
		attack_type = "dogfight",
		blood_amount = 0,
		makes_footstep_sound = not def.sneaky,
		sounds = {
			distance = def.sounds.distance,
			random = def.sounds.random,
			war_cry = def.sounds.war_cry,
			attack = def.sounds.war_cry,
			damage = def.sounds.damage,
			death = def.sounds.death,
			jump = def.sounds.jump,
		},
		drops = {},
		visual = "mesh",
		collisionbox = def.collisionbox,
		textures = def.textures,
		mesh = def.mesh,
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

	for _, drop in ipairs(def.drops) do
		local drop_chance = drop.chance
		if not drop_chance then
			drop_chance = 1
		end

		drop_chance = 1 / drop_chance

		table.insert(new_def.drops, {name=drop.name, min=drop.min, max=drop.max, chance=drop_chance})
	end

	mobs:register_mob(name, new_def)

	--[[ TODO:
	mobs:spawn({
		name = def.name,
		nodes = def.spawn.nodes,
		interval = def.spawn.interval,
		chance = def.spawn.chance,
		min_light = def.spawn.light_range.min,
		max_light = def.spawn.light_range.max,
		min_height = def.spawn.height_range.min,
		max_height = def.spawn.height_range.max,
		active_object_count = def.spawn.count.max,
	})
	]]
end
