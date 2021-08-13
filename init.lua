
mobb = {}
mobb.modname = core.get_current_modname()
mobb.modpath = core.get_modpath(mobb.modname)

mobb.log = function(lvl, msg)
	if not msg then
		msg = lvl
		lvl = nil
	end

	msg = "[" .. mobb.modname .. "] " .. msg

	if not lvl then
		core.log(msg)
	else
		core.log(lvl, msg)
	end
end

dofile(mobb.modpath .. "/settings.lua")

local ret, err
if #mobb.libs < 1 then
	ret = false
	err =  "no supported mob libraries configured, please check \"mobb.order_preference\" setting"
else
	ret, err = dofile(mobb.modpath .. "/api.lua")
end

if not ret then
	core.log("error", err)
	mobb = nil
end
