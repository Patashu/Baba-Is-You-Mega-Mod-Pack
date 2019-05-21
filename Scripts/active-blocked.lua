
return function (mod)
	mod.tiles["active"] = {
		name = "text_active",
		sprite = "text_active",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 3,
		colour = {4, 0},
		active = {4, 1},
		tile = {0, 20},
		layer = 20,
	}

	mod.tiles["blocked"] = {
		name = "text_blocked",
		sprite = "text_blocked",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 3,
		colour = {4, 0},
		active = {4, 1},
		tile = {1, 20},
		layer = 20,
	}

	mod.customConditions["active"] = function (params, unitid, x, y)
		for _,rule in ipairs(features) do
			local _, conds, idLists = rule[1], rule[2], rule[3]
			local never = false
			for _,cond in ipairs(conds) do
				if cond[1] == "never" then
					never = true
					break
				end
			end

			if not never then
				for _, idList in ipairs(idLists) do
					for _, id in ipairs(idList) do
						if id == unitid then
							return true
						end
					end
				end
			end
		end
	end

	mod.customConditions["blocked"] = function (params, unitid, x, y)
		local blockedBySomething = false

		for _, rule in ipairs(features) do
			local _, conds, idLists = rule[1], rule[2], rule[3]
			local never = false
			for _, cond in ipairs(conds) do
				if cond[1] == "never" then
					never = true
					break
				end
			end

			for _, idList in ipairs(idLists) do
				for _, id in ipairs(idList) do
					if id == unitid then
						if never then
							blockedBySomething = true
						else
							return false
						end
					end
				end
			end
		end

		return blockedBySomething
	end
end
