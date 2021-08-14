
--- Mob Bridge API
--
--  @topic api


local register

for _, lib in ipairs(mobb.libs) do
	mobb.log("action", "checking for mob library " .. lib .. " ...")

	if core.get_modpath(lib) then
		local init_register = loadfile(mobb.modpath .. "/register/" .. lib .. ".lua")
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

		return typematch, base.required == true, base.fields
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
		for k in pairs(def) do
			if base[k] == nil then
				return false, self:format_prefix(prefix) .. "unrecognized field: " .. k
			end
		end

		for field, base_def in pairs(base) do
			local value = def[field]
			local typematch, required, fields = self:type(base_def, value)

			if required and value == nil then
				return false, self:format_prefix(prefix) .. "missing required field: " .. field
			end

			if value ~= nil and not typematch then
				return false, self:format_prefix(prefix, field) .. "field wrong type"
			end

			if type(value) == "table" and type(fields) == "table" then
				local next_field = field
				if prefix ~= "" then
					next_field = prefix .. "." .. next_field
				end

				local ret, err = self:fields(fields, value, next_field)
				if not ret then
					return false, err
				end
			end

			if value ~= nil and type(base_def.check_value) == "function" then
				local ret, err = base_def.check_value(value)
				if not ret then
					return false, err
				end
			end
		end

		return true
	end,
}



--- Physical definition.
--
--  @table PhyscialDef
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

--- Behavior definition.
--
--  @table BehaviorDef
--  @tparam[opt] CombatDef combat
--  @tparam[opt] SpeedDef speed
--  @tparam[opt] SearchDef search
--  @tparam[opt] table modes List of mode definitions (`ModeDef`).
local behavior_def = {
	combat = {"table", fields={}},
	speed = {"table", fields={}},
	search = {"table", fields={}},
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
local animation_def = {}


--- Mob definition.
--
--  @table MobDef
--  @tfield[opt] string nametag
--  @field hp Can be `int` or `table` ({min=<value>, max=<value>}).
--  @tfield boolean hostile
--  @tfield[opt] boolean knockback (default: true)
--  @tfield[opt] boolean sneaky (default: false)
--  @tfield[opt] boolean floats (default: false)
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
	hp = {
		{"number", "table"},
		required = true,
		fields = {min={"number", required=true}, max={"number", required=true}},
	},
	hostile = {"boolean", required=true},
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
	behavior = {"table", fields=behavior_def},
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
