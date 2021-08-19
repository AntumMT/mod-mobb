
--- Mob Bridge API
--
--  @topic api


local register

for _, lib in ipairs(mobb.libs) do
	mobb.log("action", "checking for mob library " .. lib .. " ...")

	if core.get_modpath(lib) then
		local init_register, err = loadfile(mobb.modpath .. "/register/" .. lib .. ".lua")
		-- file not existing just means we don't support that lib
		if err and err:find("No such file or directory$") then
			err = nil
		end

		if err then
			error(err)
		end

		if init_register then
			mobb.log("action", "using mob library " .. lib)

			register = init_register()
			break
		end
	end
end

if not register then
	mobb.register = function(name)
		local err_msg = "compatible mob library not available, cannot register"
		if type(name) == "string" then
			err_msg = err_msg .. " \"" .. name .. "\""
		end

		mobb.log("error", err_msg)
	end

	return false, "compatible mob library not found, install one of the following: "
		.. table.concat(mobb.libs.default:split("."), ", ")
end


local check = {
	format_prefix = function(self, prefix, append)
		local formatted = ""
		if prefix ~= "" then
			formatted = prefix
		end

		if append then
			if formatted ~= "" then
				formatted = formatted .. "."
			end

			formatted = formatted .. append
		end

		if formatted ~= "" then
			formatted = "(" .. formatted .. ") "
		end

		return formatted
	end,

	-- @return typematch, required, fields
	type = function(self, base, subject)
		local typematch

		if base == nil then
			return false, false
		end

		if subject == nil then
			typematch = true -- set to `true` so doesn't fail if field is not required
		else
			local sub_type = type(subject)

			if type(base) == "string" then
				typematch = sub_type == base
			else
				local allowed_types = {}
				if type(base[1]) == "string" then
					allowed_types[base[1]] = true
				elseif type(base[1]) == "table" then
					for k, v in pairs(base[1]) do
						if type(k) == "number" and type(v) == "string" then
							allowed_types[v] = true
						else
							allowed_types[k] = v
						end
					end
				end

				typematch = allowed_types[sub_type] == true
			end
		end

		return typematch, base.required == true
	end,

	-- @return typematch, err
	fields = function(self, base, def, prefix)
		prefix = prefix or ""

		local err
		if def == nil then
			err = "definition required"
		elseif type(def) ~= "table" then
			err = "definition must be a table"
		end

		if err then
			if prefix == "" then
				err = "mob " .. err
			end
			return false, self:format_prefix(prefix) .. err
		end

		-- check for unknown fields
		for field in pairs(def) do
			if base[field] == nil then
				return false, self:format_prefix(prefix) .. "unrecognized field: " .. field
			end
		end

		for field, base_def in pairs(base) do
			local value = def[field]
			local typematch, required = self:type(base_def, value)

			if required and value == nil then
				return false, self:format_prefix(prefix) .. "missing required field: " .. field
			end

			if value ~= nil and not typematch then
				return false, self:format_prefix(prefix, field) .. "field wrong type"
			end

			if type(def[field]) == "table" and type(base_def.fields) == "table" then
				local next_field = field
				if prefix ~= "" then
					next_field = prefix .. "." .. next_field
				end

				if value == nil then
					-- make sure parent field exists
					value = {}
				end

				local ret, err = self:fields(base_def.fields, value, next_field)
				if not ret then
					return false, err
				end

				-- update definition
				def[field] = value
			end

			if value ~= nil and type(base_def.check_value) == "function" then
				local ret, err = base_def.check_value(value)
				if not ret then
					return false, err
				end
			end

			-- check for default value
			if type(base_def) == "table" then
				if base_def.default ~= nil and base_def.default ~= "nil" then
					if def[field] == nil then
						def[field] = base_def.default
					end
				end
			end

			-- check for injections
			if type(base_def) == "table" and type(base_def.inject) == "function" then
				if def[field] == nil then
					def[field] = {}
				end

				if type(def[field]) == "table" then
					local new_keys = base_def.inject()
					for k, v in pairs(new_keys) do
						def[field][k] = v
					end
				else
					mobb.log("warning", "cannot inject into non-table field \"" .. k .. "\"")
				end
			end
		end

		return true
	end,
}



--- Physical definition.
--
--  @table PhysicalDef
--  @tfield table collisionbox
--  @tfield[opt] table selectionbox
--  @tfield[opt] number rotation
local physical_def = {
	collisionbox = {
		"table",
		check_value = function(value)
			if #value < 6 then
				return false, "(physical.collisionbox) requires 6 values"
			end

			return true
		end,
	},
	selectionbox = {
		"table",
		check_value = function(value)
			if #value < 6 then
				return false, "(physical.selectionbox) requires 6 values"
			end

			return true
		end,
	},
	rotation = "number",
}

--- Visual definition.
--
--  @table VisualDef
--  @tfield[opt] string type
--  @tfield[opt] string mesh
--  @tfield string table
--  @tfield[opt] table size
local visual_def = {
	type = "string",
	mesh = "string",
	textures = {
		"table",
		required=true,
		check_value = function(value)
			if #value < 1 then
				return false, "(visual.textures) table cannot be empty"
			end

			return true
		end,
	},
	size = {
		"table",
		fields={{x="number", required=true}, {y="number", required=true}},
	},
}

--- Item drop definition.
--
--  @table DropDef
--  @tfield string name
--  @tfield[opt] int min (default: 1)
--  @tfield[opt] int max (default: 1)
--  @tfield[opt] number chance Probability of drop between 0.0 to 1.0 (default: 1)
local drop_def = {
	name = {"string", required=true},
	min = "number",
	max = "number",
	chance = {
		"number",
		check_value = function(value)
			local ret, err = true
			if value > 1 then
				ret, err = false, "(drops.chance) must not be more than 1.0"
			elseif value < 0 then
				ret, err = false, "(drops.chance) must not be less than 0"
			end

			return ret, err
		end,
	},
}

--- Spawn definition.
--
--  @table SpawnDef
--  @tfield table nodes
--  @tfield[opt] int interval
--  @tfield[opt] int chance
--  @tfield[opt] table light_range
--  @tfield[opt] table height_range
--  @tfield[opt] int active_object_count
local spawn_def = {
	nodes = "table",
	interval = "number",
	chance = "number",
	light_range = {
		"table",
		fields = {min={"number", required=true}, max={"number", required=true}},
		default = {min=0, max=14},
	},
	height_range = {
		"table",
		fields = {min={"number", required=true}, max={"number", required=true}},
		default = {min=-31000, max=31000},
	},
	active_object_count = "number",
}

--- Combat definition.
--
--  @table CombatDef
--  @tfield[opt] int damage
--  @tfield[opt] int radius
local combat_def = {
	damage = "number",
	radius = "number",
}

--- Individual mode definition.
--
--  @table ModeDef
--  @tfield number chance Value ranging between 0.0-1.0.
local mode_def = {
	chance = {
		"number",
		check_value = function(value)
			if value > 1 then
				return false, "(mode.chance) can not be greater than 1.0"
			elseif value < 0 then
				return false, "(mode.chance) can not be less than 0"
			end

			return true
		end,
	},
}

--- Modes definition.
--
--  @table ModesDef
--  @tfield ModeDef idle
--  @tfield ModeDef walk
local modes_def = {
	idle = {"table"},
	walk = {"table"},
}

--- Behavior definition.
--
--  @table BehaviorDef
--  @tfield bool hostile
--  @tfield[opt] bool knockback
--  @tfield[opt] CombatDef combat
--  @tfield table speed Fields can be "walk" & "run"
--  @tfield[opt] table search Fields: radius (number), target (string)
--  @tfield[opt] ModesDef modes List of mode definitions.
--  @tfield[opt] number step_height
--  @tfield[opt] number jump_height
--  @tfield[opt] bool sneaky (default: false)
local behavior_def = {
	hostile = {"boolean", required=true},
	knockback = {"boolean", default=true},
	combat = {"table", fields=combat_def},
	speed = {
		"table",
		fields = {walk="number", run="number"},
		inject = function()
			local _call = function(self, t)
				local value
				if t == "walk" or t == "run" then
					local value = self[t]
					if value == nil then
						-- default speed for walk & run
						value = 1
					end
				end

				return value
			end

			return {["get"]=_call}
		end,
	},
	search = {
		"table",
		fields = {radius="number", target="string"},
		inject = function()
			return {["get"]=function(self, t) return self[t] end}
		end,
	},
	modes = {"table", fields=modes_def},
	step_height = "number",
	jump_height = "number",
	follow = {{"string", "table"}},
	sneaky = {"boolean", default=false},
}

--- Sounds definition.
--
--  @table SoundsDef
--  @tfield[opt] string random Sound played at random intervals.
--  @tfield[opt] string death Sound played when mob dies.
--  @tfield[opt] string war_cry Sound played while mob is attacking.
--  @tfield[opt] string attack Sound played when mob inflicts damage on target entity.
--  @tfield[opt] string damage Sound played when mob receives damage.
local sounds_def = {
	random = "string",
	death = "string",
	war_cry = "string",
	attack = "string",
	damage = "string",
}

--- Animation definition.
--
--  @table AnimationDef
--  @tfield int start
--  @tfield int stop
--  @tfield[opt] int speed
--  @tfield[opt] bool loop
--  @tfield[opt] bool rotate
--  @tfield[opt] number duration
--  @usage
--  animation = {
--    idle = {start=0, stop=80, speed=15},
--    death = {start=81, stop=101, speed=28, loop=false, rotate=false, duration=2.12},
--  }
local animation_def = {}
for _, ani in ipairs({"idle", "walk", "run", "attack", "death"}) do
	animation_def[ani] = {
		"table",
		--required = true, -- FIXME: not all animation types should be required
		fields = {
			start = {"number", required=true},
			stop = {"number", required=true},
			speed = "number",
			loop = "boolean",
			duration = "number",
		},
	}

	if ani == "death" then
		animation_def[ani].fields.rotate = {{"boolean", "number"}}
	end
end


--- Mob definition.
--
--  @table MobDef
--  @tfield[opt] string nametag
--  @field hp Can be `int` or `table` ({min=<value>, max=<value>}).
--  @tfield PhysicalDef physical Physical definition.
--  @tfield VisualDef visual Visual definition.
--  @tfield[opt] table drops List of item drop definitions (`DropDef`).
--  @tfield[opt] SpawnDef spawn Spawning definition.
--  @tfield[opt] BehaviorDef behavior FIXME: should this be required?
--  @tfield[opt] SoundsDef sounds
--  @tfield[opt] AnimationDef animation
--  @tfield[opt] table mobs_fields See: [Mobs Redo API](https://notabug.org/TenPlus1/mobs_redo/src/master/api.txt)
local mob_def = {
	nametag = "string",
	hp = {
		{"number", "table"},
		required = true,
		fields = {min={"number", required=true}, max={"number", required=true}},
	},
	physical = {"table", required=true, fields=physical_def},
	visual = {"table", required=true, fields=visual_def},
	drops = {
		"table",
		check_value = function(value)
			local idx = 1
			for _, d in ipairs(value) do
				local ret, err = check:fields(drop_def, d, "drops["..idx.."]")
				if not ret then
					return false, err
				end
				idx = idx + 1
			end

			return true
		end,
	},
	spawn = {"table", fields=spawn_def},
	behavior = {
		"table",
		required=true,
		fields=behavior_def,
	},
	sounds = {"table", fields=sounds_def},
	animation = {"table", fields=animation_def},
	mobs_fields = "table",
}


--- Registers a mob.
--
--  @tparam string name Mob technical name.
--  @tparam MobDef def Mob definition.
mobb.register = function(name, def)
	if name == nil then
		error("registration failed: mob name required")
	elseif type(name) ~= "string" then
		error("registration failed: mob name must be a string")
	end

	local ret, err = check:fields(mob_def, def)
	if not ret then
		error("\"" .. name .. "\" registration failed: " .. err)
	end

	def.behavior.combat = def.behavior.combat or {}
	def.modes = def.modes or {}

	def.mobs_fields = def.mobs_fields or {}

	return register(name, def)
end


return true
