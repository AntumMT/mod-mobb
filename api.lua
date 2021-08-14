
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
--  @tfield[opt] number rotation
local physical_def = {
	collisionbox = {
		"table",
		required=true,
		check_value = function(value)
			if #value == 0 then
				return false, "(physical.collisionbox) cannot be empty"
			end

			return true
		end,
	},
	rotation = "number",
}

--- Visual definition.
--
--  @table VisualDef
--  @tparam string mesh
--  @tparam string table
local visual_def = {
	mesh = {"string", required=true},
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
}

--- Item drop definition.
--
--  @table DropDef
--  @tparam string name
--  @tparam[opt] int min (default: 1)
--  @tparam[opt] int max (default: 1)
--  @tparam[opt] number chance Probability of drop between 0.0 to 1.0 (default: 1)
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
local spawn_def = {}

--- Combat definition.
--
--  @table CombatDef
--  @tfield int damage
local combat_def = {
	damage = {
		"number",
		default = 5,
	},
}

--- Behavior definition.
--
--  @table BehaviorDef
--  @tparam bool hostile
--  @tparam[opt] CombatDef combat
--  @tparam table speed Fields can be "walk" & "run"
--  @tparam[opt] table search
--  @tparam[opt] table modes List of mode definitions (`ModeDef`).
local behavior_def = {
	hostile = {"boolean", required=true},
	combat = {
		"table",
		fields = combat_def,
	},
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
		fields={},
		inject = function()
			return {["get"]=function(self, t) return self[t] end}
		end,
	},
	modes = {"table", fields={}},
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
--  @tfield table idle
local animation_def = {}
for _, ani in ipairs({"idle", "walk", "run", "attack", "death"}) do
	animation_def[ani] = {
		"table",
		required = true, -- FIXME: not all animation types should be required
		fields = {start={"number", required=true}, stop={"number", required=true}},
	}
end


--- Mob definition.
--
--  @table MobDef
--  @tfield[opt] string nametag
--  @tfield[opt] string type (mobs)
--  @field hp Can be `int` or `table` ({min=<value>, max=<value>}).
--  @tfield[opt] bool knockback (default: true)
--  @tfield[opt] bool sneaky (default: false)
--  @tfield[opt] bool floats (default: false)
--  @tfield[opt] number step_height (default: 1)
--  @tfield[opt] number jump_height (default: 1)
--  @tfield PhysicalDef physical Physical definition.
--  @tfield VisualDef visual Visual definition.
--  @tfield[opt] table drops List of item drop definitions (`DropDef`).
--  @tfield[opt] SpawnDef spawn Spawning definition.
--  @tfield[opt] BehaviorDef behavior FIXME: should this be required?
--  @tfield[opt] SoundsDef sounds
--  @tfield[opt] AnimationDef animation
local mob_def = {
	nametag = "string",
	type = "string",
	hp = {
		{"number", "table"},
		required = true,
		fields = {min={"number", required=true}, max={"number", required=true}},
	},
	knockback = "boolean",
	sneaky = "boolean",
	floats = "boolean",
	step_height = "number",
	jump_height = "number",
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

	return register(name, def)
end


return true
