
-- GENERATED FILE, DO NOT EDIT (or do, I'm not your mom)
return function (mod)
	mod.onLoad(function (dir)
		loadscript(dir .. "replacements/blocks")
		loadscript(dir .. "replacements/conditions")
		loadscript(dir .. "replacements/movement")
		loadscript(dir .. "replacements/rules")
		loadscript(dir .. "replacements/tools")

	end)
	mod.onUnload(function (dir)
		loadscript("Data/blocks")
		loadscript("Data/conditions")
		loadscript("Data/movement")
		loadscript("Data/rules")
		loadscript("Data/tools")

	end)
end
