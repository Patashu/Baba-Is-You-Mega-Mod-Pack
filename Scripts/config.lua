
return function (mod)
	-- Delete or [-- Comment out] tiles to disable them.
	-- If you leave more than 6 enabled, it will start removing vanilla tiles from the mod to make space.
	mod.enabledTiles = {
		"paradox",

		-- Parser effects
		"slant",
		"yoda",
		"caveman",
		"clickbait",
		"?",
		"false",

		-- Active and blocked
		"active",
		"blocked",

		-- If
		"if",
		"every",
		"one",

		-- Warps
		"wrap",
		"portal",

		-- Pathfinders
		"find",
		"evil",
		"repent",
	}

	-- When objects wrap or go through a portal, we delete them and recreate it on the other side for better animations.
	-- Disable this if it causes problems.
	mod.fancyWarpAnimation = true
end