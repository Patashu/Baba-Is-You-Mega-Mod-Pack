
local mod = {}

local loaders, unloaders

function mod.onLoad(f)
	table.insert(loaders, f)
end

function mod.onUnload(f)
	table.insert(unloaders, 1, f)
end

-- concat arrays in place
function mod.concat(array, ...)
	for _, array2 in ipairs({...}) do
		for _, x in ipairs(array2) do
			table.insert(array, x)
		end
	end
	return array
end

function mod.load(dir)
	mod.inspect = loadscript(dir .. "inspect")

	mod.tiles = {}
	mod.customConditions = {}
	loaders = {}
	unloaders = {}

	loadscript(dir .. "config")(mod)
	loadscript(dir .. "replacements")(mod)
	loadscript(dir .. "parser")(mod)
	loadscript(dir .. "parser-effects")(mod)
	loadscript(dir .. "if")(mod)
	loadscript(dir .. "active-blocked")(mod)
	loadscript(dir .. "warps")(mod)
	loadscript(dir .. "pathfinders")(mod)
	loadscript(dir .. "tiles")(mod)

	for _, loader in ipairs(loaders) do
		loader(dir)
	end
end

function mod.unload(dir)
	for _, unloader in ipairs(unloaders) do
		unloader(dir)
	end
end

return mod
