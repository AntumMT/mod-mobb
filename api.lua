
--- Mob Bridge API
--
--  @topic api


for _, lib in ipairs(mobb.libs) do
	mobb.log("action", "checking for mob library " .. lib .. " ...")

	if core.get_modpath(lib) then
		local init_register = loadfile(mobb.modpath .. "/register/" .. lib .. ".lua")
		if init_register then
			mobb.log("action", "using mob library " .. lib)

			mobb.register = init_register()
			break
		end
	end
end

if not mobb.register then
	return false, "compatible mob library not found, install one of the following: "
		.. table.concat(mobb.libs.default:split("."), ", ")
end

return true
