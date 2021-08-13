
--- Preferred order of supported mob libraries.
--
--  @setting mobb.order_preference
--  @settype enum
--  @default mobkit.mobs
--  @options mobkit.mobs,mobs.mobkit
mobb.libs = {
	default = "mobkit.mobs",
}
for _, lib in ipairs((core.settings:get("mobb.order_preference") or mobb.libs.default):trim():split(".")) do
	lib = lib:trim()
	if lib ~= "" then
		table.insert(mobb.libs, lib)
	end
end
