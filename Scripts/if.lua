
return function (mod)
	-- Version of hasfeature which won't cause a stack overflow if there is a dependency cycle
	-- (e.g. rock is group if group is near baba, if baba is near a rock then we get a dependency
	-- cycle trying to figure out if the rule applies)
	local shfstack = {}
	function mod.safehasfeature(unitid, verb, object)
		for _,data in ipairs(shfstack) do
			if data[1] == unitid and data[2] == verb and data[3] == object then
				return false
			end
		end

		local unit = mmf.newObject(unitid)

		table.insert(shfstack, {unitid, verb, object})
		local result = hasfeature(getname(unit), verb, object, unitid)
		table.remove(shfstack)
		
		return result
	end

	-- Just in case, hook movecommand to reset shfstack at the start of each turn 
	local oldMoveCommand
	local function myMoveCommand(ox, oy, dir, playerid)
		shfstack = {}
		oldMoveCommand(ox, oy, dir, playerid)
	end

	mod.onLoad(function (dir)
		oldMoveCommand = movecommand
		movecommand = myMoveCommand
	end)

	mod.onUnload(function (dir)
		movecommand = oldMoveCommand
	end)

	-- This function is pretty much the core of the If test. Of all the `noun`s which
	-- match targetconds, we determine how many of them fail the `conds` (misses) and how many pass `conds` (hits).
	-- Stop counting earlier than normal if we reach maxhits or maxmisses.
	local function countwithconds(noun, targetconds, conds, maxhits, maxmisses)
		local misses = 0
		local hits = 0

		local function tryunit(unitid)
			if testcond(targetconds, unitid) then
				if testcond(conds, unitid) then
					hits = hits + 1
				else
					misses = misses + 1
				end
				-- Return true if we should stop now.
				return (maxhits ~= nil and hits >= maxhits) or (maxmisses ~= nil and misses >= maxmisses)
			end
			return false
		end

		local notnoun = false
		local prefix = string.sub(noun, 1, 3)
		if prefix == "not" then
			notnoun = true
			noun = string.sub(noun, 5)
		end
		if notnoun then
			if noun == "all" then
				-- not all = all \ all = empty set
				return 0, 0
			end
			-- We don't support "not group" here, but neither does vanilla, so we have an excuse :upside-down:
			for name, unitids in pairs(unitlists) do
				if name ~= noun and name ~= "text" then
					for _, unitid in ipairs(unitids) do
						if tryunit(unitid) then
							return hits, misses
						end
					end
				end
			end
		elseif noun == "group" then
			local groupfeatures = featureindex["group"]
			local alreadychecked = {}
			if groupfeatures ~= nil then
				for _, feature in ipairs(groupfeatures) do
					local groupnoun = feature[1][1]
					if alreadychecked[groupnoun] == nil then
						alreadychecked[groupnoun] = 1

						local checklist = unitlists[groupnoun]

						if checklist ~= nil then
							for _, unitid in ipairs(checklist) do
								if activemod.safehasfeature(unitid, "is", "group") then
									if tryunit(unitid) then
										return hits, misses
									end
								end
							end
						end
					end
				end
			end
		else
			local checklist = unitlists[noun]
			if checklist ~= nil then
				for _, unitid in ipairs(checklist) do
					if tryunit(unitid) then
						return hits, misses
					end
				end
			end
		end

		return hits, misses
	end

	mod.customConditions["cg5with"] = function (params, unitid, x, y)
		for _, effect in ipairs(params) do
			if not activemod.safehasfeature(unitid, "is", effect) then
				return false
			end
		end
		return true
	end

	mod.customConditions["if"] = function (params, unitid, x, y)
		for _, ifcond in ipairs(params) do
			local quantifier, targets, targetconds, innerconds = ifcond[1], ifcond[2], ifcond[3], ifcond[4]

			local notquantifier = false
			local quantifierprefix = string.sub(quantifier, 1, 3)
			if quantifierprefix == "not" then
				notquantifier = true
				quantifier = string.sub(quantifier, 5)
			end

			local numquantifier = tonumber(quantifier)

			for _, target in ipairs(targets) do
				local thisresult = false
				if quantifier == "every" then
					local hits, misses = countwithconds(target, targetconds, innerconds, nil, 1)
					thisresult = (misses == 0)
				elseif numquantifier ~= nil then
					local hits, misses = countwithconds(target, targetconds, innerconds, numquantifier + 1, nil)
					thisresult = (hits == numquantifier)
				else
					local hits, misses = countwithconds(target, targetconds, innerconds, 1, nil)
					thisresult = (hits >= 1)
				end

				if notquantifier == thisresult then
					return false
				end
			end
		end

		return true
	end

	mod.tiles["if"] = {
		name = "text_if",
		sprite = "text_if",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 10,
		colour = {0, 1},
		active = {0, 3},
		tile = {0, 22},
		layer = 20,
	}

	mod.tiles["every"] = {
		name = "text_every",
		sprite = "text_every",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 11,
		colour = {5, 0},
		active = {5, 2},
		tile = {1, 22},
		layer = 20,
	}

	mod.tiles["one"] = {
		name = "text_1",
		sprite = "text_1",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 11,
		colour = {5, 0},
		active = {5, 2},
		tile = {2, 22},
		layer = 20,
	}
end
