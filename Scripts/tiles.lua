
local tileNames = {
	"object120",
	"object121",
	"object122",
	"object123",
	"object124",
	"object125",

	-- If necessary, overwrite these to make space
	"object037", -- text_rose
	"object026", -- rose
	"object033", -- text_lava
	"object010", -- lava
	"object077", -- text_dust
	"object065", -- dust
	"object091", -- text_fence
	"object100", -- fence
	"object111", -- text_brick
	"object110", -- brick
	"object102", -- text_hedge
	"object101", -- hedge
	"object063", -- text_hand
	"object051", -- hand
	"object019", -- text_fungus
	"object031", -- fungus
}

return function (mod)
	mod.onLoad(function (dir)
		local usedUpTileIds = {}
		for name, tab in pairs(mod.tiles) do
			local tid = tab.tile[1] * 10000 + tab.tile[2]
			if usedUpTileIds[tid] ~= nil then
				print("Tile ID collision! " .. usedUpTileIds[tid] .. " and " .. name)
			else
				usedUpTileIds[tid] = name
			end
		end

		local tileCount = 0
		for _, tile in ipairs(mod.enabledTiles) do
			local tileTable = mod.tiles[tile]
			if tileTable == nil then
				print("No such tile! " .. tile)
			else
				local tileName = tileNames[tileCount + 1]
				if tileName == nil then
					print("Ran out of tileNames!")
					break
				end
				tileTable.grid = {11 + math.floor(tileCount / 11), tileCount % 11}
				tileslist[tileName] = tileTable
				tileCount = tileCount + 1
			end
		end
	end)

	mod.onUnload(function (dir)
		loadscript("Data/values")
	end)
end
