
local function tileissolid(tileid)
	local unitids = unitmap[tileid]
	if unitids ~= nil then
		for _, unitid in ipairs(unitids) do
			local name = getname(mmf.newObject(unitid))
			if hasfeature(name, "is", "stop", unitid) or hasfeature(name, "is", "push", unitid) or hasfeature(name, "is", "pull", unitid) then
				return true
			end
		end
	end
	return false
end

local function lowestmanhattandistance(x, y, targets)
	local result = 9999
	for _, target in ipairs(targets) do
		local d = math.abs(x - target[1]) + math.abs(y - target[2])
		if d < result then
			result = d
		end
	end
	return result
end

local function dopathfind(unitid, x, y, initialdir, targets, targettileids)
	if #targets == 0 then
		return -2
	end

	local tileid = y * roomsizex + x

	-- https://en.wikipedia.org/wiki/A*_search_algorithm
	local closedset = {}
	local camefrom = {}
	local openset = {[tileid] = 1}
	local gscore = {[tileid] = 0}
	local fscore = {[tileid] = lowestmanhattandistance(x, y, targets)}

	local firststep = true
	local solidcache = {}

	while next(openset) ~= nil do -- i.e. openset is not empty
		local currenttileid = nil
		local currentfscore = 9999
		for tileid, _ in pairs(openset) do
			if fscore[tileid] < currentfscore then
				currenttileid = tileid
				currentfscore = fscore[tileid]
			end
		end

		if targettileids[currenttileid] ~= nil then
			local lastdir = -1
			while camefrom[currenttileid] ~= nil do
				local cf = camefrom[currenttileid]
				currenttileid, lastdir = cf[1], cf[2]
			end
			return lastdir
		end

		openset[currenttileid] = nil
		closedset[currenttileid] = 1

		x, y = currenttileid % roomsizex, math.floor(currenttileid / roomsizex)

		for dir = 0, 3 do
			-- Unfortunately, our heuristic function is not admissible if there is wrap/portal, so it's not guaranteed to find the shortest path.
			-- FIXME?
			local nx, ny = activemod.getadjacenttile(unitid, x, y, dir)
			local ntileid = ny * roomsizex + nx
			if closedset[ntileid] == nil and nx >= 1 and nx <= roomsizex - 2 and ny >= 1 and ny <= roomsizey - 2 then
				local issolid = solidcache[ntileid]
				if issolid == nil then
					issolid = tileissolid(ntileid)
					solidcache[ntileid] = issolid
				end

				if not issolid then
					tentativegscore = gscore[currenttileid] + 1
					if firststep and dir ~= initialdir then
						-- Slightly prefer not to change direction on the first step
						tentativegscore = tentativegscore + 0.5
					end
					local skip = false
					if openset[ntileid] == nil then
						openset[ntileid] = 1
					elseif gscore[ntileid] ~= nil and tentativegscore >= gscore[ntileid] then
						skip = true
					end

					if not skip then
						camefrom[ntileid] = {currenttileid, dir}
						gscore[ntileid] = tentativegscore
						fscore[ntileid] = tentativegscore + lowestmanhattandistance(nx, ny, targets)
					end
				end
			end
		end

		firststep = false
	end

	return -2
end

local function trybreakrule(unitids, targets, targettileids)
	for _, unitidlist in ipairs(unitids) do
		for _, unitid in ipairs(unitidlist) do
			local unit = mmf.newObject(unitid)
			local x, y = unit.values[XPOS], unit.values[YPOS]

			if x - 1 >= 1 and x + 1 <= roomsizex - 2 and not tileissolid(y * roomsizex + x - 1) and not tileissolid(y * roomsizex + x + 1) then
				-- Can break the rule by pushing horizontally
				table.insert(targets, {x - 1, y})
				targettileids[y * roomsizex + x - 1] = 0
				table.insert(targets, {x + 1, y})
				targettileids[y * roomsizex + x + 1] = 2
			end

			if y - 1 >= 1 and y + 1 <= roomsizey - 2 and not tileissolid((y - 1) * roomsizex + x) and not tileissolid((y + 1) * roomsizex + x) then
				-- Can break the rule by pushing vertically
				table.insert(targets, {x, y - 1})
				targettileids[(y - 1) * roomsizex + x] = 3
				table.insert(targets, {x, y + 1})
				targettileids[(y + 1) * roomsizex + x] = 1
			end
		end
	end
end

local function performfind(unitid, findees)
	local unit = mmf.newObject(unitid)
	local x, y, initialdir = unit.values[XPOS], unit.values[YPOS], unit.values[DIR]
	local tileid = y * roomsizex + x

	local alreadyhandled = {}
	local targets = {}
	local targettileids = {}
	for _, findee in ipairs(findees) do
		if alreadyhandled[findee] == nil then
			alreadyhandled[findee] = 1
			for _, funitid in ipairs(findall({findee, {}})) do
				if funitid ~= unitid then
					local funit = mmf.newObject(funitid)
					local fname = getname(funit)
					local fx, fy = funit.values[XPOS], funit.values[YPOS]
					local ftileid = fy * roomsizex + fx
					if not tileissolid(ftileid) then
						table.insert(targets, {fx, fy})
						targettileids[ftileid] = 1
					end
				end
			end
		end
	end
	return dopathfind(unitid, x, y, initialdir, targets, targettileids)
end

return function (mod)
	function mod.addFindMoves(movingUnits)
		local findfeatures = featureindex["find"]
		if findfeatures ~= nil then
			local finders = {}
			for _, feature in ipairs(findfeatures) do
				local finder, findee, conds = feature[1][1], feature[1][3], feature[2]
				for _, unitid in ipairs(findall({finder, conds})) do
					if finders[unitid] == nil then
						finders[unitid] = {findee}
					else
						table.insert(finders[unitid], findee)
					end
				end
			end
			for unitid, findees in pairs(finders) do
				local finddir = performfind(unitid, findees)
				if finddir >= 0 then
					local unit = mmf.newObject(unitid)
					updatedir(unitid, finddir)
					table.insert(movingUnits, {unitid = unitid, reason = "find", state = 0, moves = 1, dir = finddir, xpos = unit.values[XPOS], ypos = unit.values[YPOS]})
				end
			end
		end
	end

	function mod.addEvilAndRepentMoves(movingUnits)
		local evils = findallfeature(nil, "is", "evil")
		if evils ~= nil and #evils > 0 then
			local youfeatures = featureindex["you"]
			local targets = {}
			local targettileids = {}
			if youfeatures ~= nil then
				for _, feature in ipairs(youfeatures) do
					if feature[1][2] == "is" and feature[1][3] == "you" then
						trybreakrule(feature[3], targets, targettileids)
					end
				end
			end

			for _, unitid in ipairs(evils) do
				local unit = mmf.newObject(unitid)
				local thesetargets = targets
				local thesetargettileids = targettileids
				local reason = "evil"
				if hasfeature(getname(unit), "is", "repent", unitid) then
					reason = "repent"
					local name = getname(unit)
					local evilfeatures = featureindex["evil"]
					thesetargets = {}
					thesetargettileids = {}
					if evilfeatures ~= nil then
						for _, feature in ipairs(evilfeatures) do
							if feature[1][1] == name and feature[1][2] == "is" and feature[1][3] == "evil" then
								trybreakrule(feature[3], thesetargets, thesetargettileids)
							end
						end
					end
				end

				local x, y, initialdir = unit.values[XPOS], unit.values[YPOS], unit.values[DIR]
				local tileid = y * roomsizex + x

				if thesetargettileids[tileid] ~= nil then
					-- We're in position to do the evil push, now do it
					updatedir(unitid, thesetargettileids[tileid])
					table.insert(movingUnits, {unitid = unitid, reason = reason, state = 0, moves = 1, dir = thesetargettileids[tileid], xpos = x, ypos = y})
				else
					-- We still need to get into position to make our evil push, so pathfind there
					local evildir = dopathfind(unitid, x, y, initialdir, thesetargets, thesetargettileids)
					if evildir >= 0 then
						updatedir(unitid, evildir)
						table.insert(movingUnits, {unitid = unitid, reason = reason, state = 0, moves = 1, dir = evildir, xpos = x, ypos = y})	
					end
				end
			end
		end
	end

	mod.tiles["find"] = {
		name = "text_find",
		sprite = "text_find",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 1,
		argtype = {0},
		colour = {5, 0},
		active = {5, 2},
		tile = {0, 24},
		layer = 20,
	}

	mod.tiles["evil"] = {
		name = "text_evil",
		sprite = "text_evil",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {2, 1},
		active = {2, 2},
		tile = {1, 24},
		layer = 20,
	}

	mod.tiles["repent"] = {
		name = "text_repent",
		sprite = "text_repent",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {5, 0},
		active = {5, 2},
		tile = {2, 24},
		layer = 20,
	}
end
