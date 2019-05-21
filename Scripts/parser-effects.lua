
return function (mod)
	function mod.invertEffect(effect)
		if string.sub(effect, 1, 3) == "not" then
			return string.sub(effect, 5)
		else
			return "not " .. effect
		end
	end

	mod.tiles["paradox"] = {
		name = "text_paradox",
		sprite = "text_paradox",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = -100,
		colour = {2, 2},
		active = {2, 2},
		tile = {0, 21},
		layer = 20,
	}

	mod.tiles["slant"] = {
		name = "text_slant",
		sprite = "text_slant",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {0, 2},
		active = {0, 3},
		tile = {1, 21},
		layer = 20,
	}

	mod.tiles["yoda"] = {
		name = "text_yoda",
		sprite = "text_yoda",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {5, 1},
		active = {5, 3},
		tile = {2, 21},
		layer = 20,
	}

	mod.tiles["caveman"] = {
		name = "text_caveman",
		sprite = "text_caveman",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {0, 2},
		active = {0, 3},
		tile = {3, 21},
		layer = 20,
	}

	mod.tiles["clickbait"] = {
		name = "text_clickbait",
		sprite = "text_clickbait",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {2, 1},
		active = {2, 2},
		tile = {4, 21},
		layer = 20,
	}

	mod.tiles["false"] = {
		name = "text_false",
		sprite = "text_false",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {2, 1},
		active = {2, 2},
		tile = {5, 21},
		layer = 20,
	}

	mod.tiles["?"] = {
		name = "text_?",
		sprite = "what",
		sprite_in_root = true,
		unittype = "text",
		tiling = -1,
		type = 20,
		colour = {0, 2},
		active = {0, 3},
		tile = {6, 21},
		layer = 20,
	}
end