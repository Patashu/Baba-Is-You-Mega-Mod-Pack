
-- Default `floating` checks the `.values[FLOAT]` property, but this is set too late in the turn and when
-- this is set it doesn't do `updatecode == 1`. Instead we will use our own version which queries for features instead.
local function myfloating(unitid1, unitid2)
	return (hasfeature(getname(mmf.newObject(unitid1)), "is", "float", unitid1) == nil) == (hasfeature(getname(mmf.newObject(unitid2)), "is", "float", unitid2) == nil)
end

local DIRECTION_DOWN_RIGHT = -1

return function (mod)
	mod.warpedidchanges = {}

	function mod.reversedir(dir)
		return (dir + 2) % 4
	end

	-- This function gets the destination tile after the unit moves one tile in the given direction.
	-- It is a replacement for "x + ox, y + oy".
	-- It returns a new x, y, and dir, and an array of warps which look like {leavex, leavey, emergex, emergey}
	function mod.getadjacenttile(unitid,x,y,dir,warps)
		local ndrs = ndirs[dir + 1]
		if dir == DIRECTION_DOWN_RIGHT then
			ndrs = {1, 1}
		end
		local rx, ry, rdir = x + ndrs[1], y + ndrs[2], dir
		if warps == nil then
			warps = {}
		end

		if featureindex["wrap"] == nil and featureindex["portal"] == nil then
			return rx, ry, dir, warps
		end

		local unit = mmf.newObject(unitid)

		if hasfeature(getname(unit),"is","wrap",unitid) ~= nil then
			if rx > roomsizex - 2 then
				rx = rx - (roomsizex - 2)
				table.insert(warps, {roomsizex - 1, ry, 0, ry})
			elseif rx < 1 then
				rx = rx + (roomsizex - 2)
				table.insert(warps, {0, ry, roomsizex - 1, ry})
			end
			
			if ry > roomsizey - 2 then
				ry = ry - (roomsizey - 2)
				table.insert(warps, {rx, roomsizey - 1, rx, 0})
			elseif ry < 1 then
				ry = ry + (roomsizey - 2)
				table.insert(warps, {rx, 0, rx, roomsizey - 1})
			end
		end

		local portals = findfeatureat(nil, "is", "portal", rx, ry)
		if portals ~= nil and dir ~= DIRECTION_DOWN_RIGHT then
			for _, portalid in ipairs(portals) do
				local portal = mmf.newObject(portalid)

				-- Stop if we already used this portal. This protects against infinite loops.
				local alreadyused = false
				for _, warp in ipairs(warps) do
					if warp[1] == portal.values[XPOS] and warp[2] == portal.values[YPOS] then
						alreadyused = true
						break
					end
				end
				if alreadyused then
					break
				end

				if myfloating(unitid, portalid) then
					local forwardsthroughportal = nil
					if dir == portal.values[DIR] then
						forwardsthroughportal = true
					elseif dir == mod.reversedir(portal.values[DIR]) then
						forwardsthroughportal = false
					end

					if forwardsthroughportal ~= nil then
						local matchingportals = findallfeature(getname(portal), "is", "portal", true)
						if #matchingportals >= 2 then
							-- Sort the portals by tileid
							table.sort(matchingportals, function (a, b)
								a = mmf.newObject(a)
								b = mmf.newObject(b)
								return (a.values[YPOS] * roomsizex + a.values[XPOS]) < (b.values[YPOS] * roomsizex + b.values[XPOS])
							end)

							-- Find the portal after the entry portal in tileid order, wrap to the start if necessary.
							-- If we go backwards through the portal then we instead find the portal *before* the entry portal.
							local ouridx = nil
							for idx, unitid in ipairs(matchingportals) do
								if unitid == portalid then
									ouridx = idx
									break
								end
							end

							-- Should never happen
							if ouridx == nil then
								break
							end

							local destidx = ouridx
							local found = false
							-- For whatever reason, `findallfeature` sometimes returns duplicates. So we can't just use
							-- ouridx +/- 1 with wrapping.
							for i = 1, #matchingportals do
								if matchingportals[destidx] ~= portalid then
									found = true
									break
								end
								destidx = destidx + (forwardsthroughportal and 1 or -1)
								if destidx > #matchingportals then
									destidx = 1
								elseif destidx < 1 then
									destidx = #matchingportals
								end
							end

							if found then
								local destportal = mmf.newObject(matchingportals[destidx])
								local newdir = forwardsthroughportal and destportal.values[DIR] or mod.reversedir(destportal.values[DIR])
								table.insert(warps, {portal.values[XPOS], portal.values[YPOS], destportal.values[XPOS], destportal.values[YPOS]})
								return mod.getadjacenttile(unitid, destportal.values[XPOS], destportal.values[YPOS], newdir, warps)
							else
								break
							end
						end
					end
				end
			end
		end

		return rx,ry,rdir,warps
	end

	function mod.dofancyanimation(unitid, rx, ry, rdir, warps)
		-- If the object was warped, we don't just set the unit's location as this causes an ugly animation where the unit moves all the
		-- way across the screen. Instead we let the unit move and then delete it, and at the same time create another unit in and move it into place.
		local unit = mmf.newObject(unitid)
		local leavex, leavey = warps[1][1], warps[1][2]
		local emergex, emergey = warps[#warps][3], warps[#warps][4]
		local newunitid = create(unit.strings[UNITNAME],rx,ry,rdir,emergex,emergey)
		local newunit = mmf.newObject(newunitid)
		
		-- Use the "empty is X" animation
		newunit.values[EFFECT] = 1
		newunit.flags[9] = true
		newunit.flags[CONVERTED] = true

		update(unitid,leavex,leavey)
		addaction(unitid,{"convert","empty",leavex,leavey})

		return newunitid
	end

	mod.tiles["wrap"] = {
		name = "text_wrap",
		sprite = "text_wrap",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {1, 1},
		active = {3, 2},
		tile = {0, 23},
		layer = 20,
	}

	mod.tiles["portal"] = {
		name = "text_portal",
		sprite = "text_portal",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {1, 1},
		active = {3, 2},
		tile = {1, 23},
		layer = 20,
	}
end
