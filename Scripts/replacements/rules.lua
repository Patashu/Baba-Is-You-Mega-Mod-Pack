
local pendingfeatures = nil

local function clearpendingfeatures()
	pendingfeatures = {
		features = {},
		featureindex = {},
		visualfeatures = {},
		notfeatures = {}
	}
end

local function commitpendingfeatures()
	features = pendingfeatures.features
	featureindex = pendingfeatures.featureindex
	visualfeatures = pendingfeatures.visualfeatures
	notfeatures = pendingfeatures.notfeatures
	clearpendingfeatures()
end

local function adddefaultfeature(target, verb, effect)
	local newfeature = {{target, verb, effect}, {}, {}}
	table.insert(pendingfeatures.features, newfeature)

	pendingfeatures.featureindex[target] = pendingfeatures.featureindex[target] or {}
	table.insert(pendingfeatures.featureindex[target], newfeature)

	pendingfeatures.featureindex[verb] = pendingfeatures.featureindex[verb] or {}
	table.insert(pendingfeatures.featureindex[verb], newfeature)

	pendingfeatures.featureindex[effect] = pendingfeatures.featureindex[effect] or {}
	table.insert(pendingfeatures.featureindex[effect], newfeature)
end

local function join(array, func, separator)
	local result = ""
	for _, elem in ipairs(array) do
		local text = func(elem)
		if text ~= nil and text ~= "" then
			if result == "" then
				result = text
			else
				result = result .. separator .. text
			end
		end
	end
	return result
end

-- Get all of the features which might affect rule parsing.
local function getcodeaffectingfeatures()
	local result = {}
	local words = {["text"] = 1}
	local careaboutfloat = {["text"] = 1}
	local haveportals = false

	if pendingfeatures.featureindex["word"] ~= nil then
		for _, feature in ipairs(pendingfeatures.featureindex["word"]) do
			if feature[1][2] == "is" and feature[1][3] == "word" then
				words[feature[1][1]] = 1
				table.insert(result, feature)
			end
		end
	end

	for _, name in ipairs({"slant", "yoda", "caveman", "false", "clickbait"}) do
		if pendingfeatures.featureindex[name] ~= nil then
			for _, feature in ipairs(pendingfeatures.featureindex[name]) do
				if words[feature[1][1]] ~= nil and feature[1][2] == "is" and feature[1][3] == name then
					table.insert(result, feature)
				end
			end
		end
	end

	if pendingfeatures.featureindex["portal"] ~= nil then
		for _, feature in ipairs(pendingfeatures.featureindex["portal"]) do
			if feature[1][2] == "is" and feature[1][3] == "portal" then
				haveportals = true
				careaboutfloat[feature[1][1]] = 1
				table.insert(result, feature)
			end
		end
	end

	if pendingfeatures.featureindex["wrap"] ~= nil then
		for _, feature in ipairs(pendingfeatures.featureindex["wrap"]) do
			if feature[1][1] == "text" and feature[1][2] == "is" and feature[1][3] == "wrap" then
				table.insert(result, feature)
			end
		end
	end

	if haveportals and pendingfeatures.featureindex["float"] ~= nil then
		for _, feature in ipairs(pendingfeatures.featureindex["float"]) do
			if careaboutfloat[feature[1][1]] ~= nil and feature[1][2] == "is" and feature[1][3] == "float" then
				table.insert(result, feature)
			end
		end
	end

	return result
end

-- Get a string summary of all of the features in the array.
-- Once summarisefeatures(getcodeaffectingfeatures()) stops changing we have reached convergence.
local function summarisefeatures(featurelist)
	return join(featurelist, function (feature)
		return feature[1][1] .. " " .. feature[1][2] .. " " .. feature[1][3] .. ":" .. join(feature[2], function (x) return x[1] end, ",") 
	end, ";")
end

local DIRECTION_DOWN_RIGHT = -1

local function codeiteration()
	MF_removeblockeffect(0)

	clearpendingfeatures()
	adddefaultfeature("text", "is", "push")
	adddefaultfeature("level", "is", "stop")

	local checkthese = {}

	for i,v in ipairs(findallfeature(nil, "is", "word")) do
		table.insert(checkthese, v)
	end

	local firstwords = {}
	local alreadyused = {}
	
	if (#codeunits > 0) then
		for i,v in ipairs(codeunits) do
			table.insert(checkthese, v)
		end
	end

	if (#checkthese > 0) then
		for iid,unitid in ipairs(checkthese) do
			local unit = mmf.newObject(unitid)
			local x,y = unit.values[XPOS],unit.values[YPOS]
			local ox,oy,nox,noy = 0,0
			local tileid = x + y * roomsizex

			setcolour(unit.fixed)
			
			if (alreadyused[tileid] == nil) then
				for _, dir in ipairs({0, 3}) do
					local forwardstext = codecheck(unitid, x, y, dir)

					-- We do not allow the `reversetext` check to warp. This ensures that a loop
					-- "[portal >] BABA IS [portal >]" will start somewhere.
					local dircoords = ndirs[dir + 1]
					local reversetext = gettextattile(x - dircoords[1], y - dircoords[2])
					
					if (#reversetext == 0) and (#forwardstext > 0) then
						table.insert(firstwords, {unitid, dir})
						alreadyused[tileid] = 1
					end
				end

				if hasfeature(getname(unit), "is", "slant", unitid) then
					local forwardstext = codecheck(unitid, x, y, DIRECTION_DOWN_RIGHT)
					local reversetext = gettextattile(x - 1, y - 1)
					if (#reversetext == 0) and (#forwardstext > 0) then
						table.insert(firstwords, {unitid, DIRECTION_DOWN_RIGHT})
						alreadyused[tileid] = 1
					end
				end
			end
		end
		
		docode(firstwords)
		grouprules()
		postrules()
	end
end

function code()
	if updatecode == 1 then
		updatecode = 0

		features = {}
		featureindex = {}
		visualfeatures = {}
		notfeatures = {}

		local codeaffectingfeatures = nil
		local codeaffectingfeaturessummaries = {""}
		local done = false

		while not done do
			codeiteration()
			codeaffectingfeatures = getcodeaffectingfeatures()
			local newsummary = summarisefeatures(codeaffectingfeatures)
			commitpendingfeatures()

			for idx, summary in ipairs(codeaffectingfeaturessummaries) do
				if summary == newsummary then
					-- Either the current summary is equal to the previous summary, in which case
					-- we have convergence, or it's equal to some previous summary we already went through, in which case
					-- we have a paradox (e.g. ROCK IS WORD, [physical rock] IS NOT WORD).
					-- (Vanilla would get stuck in a loop in the latter case.)

					if idx < #codeaffectingfeaturessummaries then
						destroylevel()
						if unitreference["text_paradox"] ~= nil then
							create("text_paradox", math.floor((roomsizex - 1)/2), math.floor((roomsizey - 1)/2), 0)
						end
					end
					done = true
					break
				end
			end
			table.insert(codeaffectingfeaturessummaries, newsummary)
		end

		doruleeffects()
		domaprotation()

		-- The global `wordunits` tracks objects which require an updatecode = 1 when they change.
		-- We don't use this table during rule parsing, but we still need to build it.
		-- Notice that this doesn't only contain units which are WORD. I don't want to rename it
		-- because then I'd have to add lots of files to the mod.
		local alreadyhandled = {["text"] = 1}
		local function addwordunits(noun)
			if alreadyhandled[noun] == nil then
				alreadyhandled[noun] = 1
				for _, unitid in ipairs(findall({noun, {}})) do
					table.insert(wordunits, {unitid, {}})
				end
			end
		end
		wordunits = {}
		for _, feature in ipairs(codeaffectingfeatures) do
			-- E.g. for ROCK IS WORD, add all rocks to wordunits.
			-- Test if there is no "never" condition? I'm not too bothered, since adding too much
			-- to wordunits just means you sometimes reparse rules when you don't need to, it doesn't cause a bug.
			addwordunits(feature[1][1])

			-- Also add any condition parameters, e.g. ROCK NEAR BABA IS WORD, add all babas to
			-- wordunits. (Vanilla doesn't do this, and it causes a bug.)
			for _, cond in ipairs(feature[2]) do
				if cond[1] == "if" or cond[1] == "not if" then
					for _, ifcond in ipairs(cond[2]) do
						local quantifier, targets, targetconds, innerconds = ifcond[1], ifcond[2], ifcond[3], ifcond[4]
						for _, target in ipairs(targets) do
							addwordunits(target)
						end
						for _, cond in ipairs(targetconds) do
							for _, param in ipairs(cond[2]) do
								-- param == "not x" or "group"?
								addwordunits(param)
							end
						end
						for _, cond in ipairs(innerconds) do
							for _, param in ipairs(cond[2]) do
								-- param == "not x" or "group"?
								addwordunits(param)
							end
						end
					end
				elseif cond[2] ~= nil then
					for _, param in ipairs(cond[2]) do
						-- param == "not x" or "group"?
						addwordunits(param)
					end
				end
			end
		end

		-- In some cases Hempuli will assume that if wordunits is not empty then featureindex["word"] is not nil.
		-- This is a fine assumption in Vanilla but our approach breaks this assumption.
		if #wordunits > 0 then
			featureindex["word"] = featureindex["word"] or {}
		end
	end
end

--[[
function dumpobj(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dumpobj(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end
]]--

function docode(firstwords)
	local donefirstwords = {}
	local limiter = 0
	
	if (#firstwords > 0) then
		for k,unitdata in ipairs(firstwords) do
			local unitid = unitdata[1]
			local dir = unitdata[2]
			
			local unit = mmf.newObject(unitdata[1])
			local x,y = unit.values[XPOS],unit.values[YPOS]
			local tileid = x + y * roomsizex
			
			--MF_alert("Testing " .. unit.strings[UNITNAME] .. ": " .. tostring(donefirstwords[tileid]) .. ", " .. tostring(dir))
			limiter = limiter + 1
			
			if (limiter > 10000) then
				timedmessage("error - too complicated rules!")
			end
			
			if (donefirstwords[tileid] == nil) or ((donefirstwords[tileid] ~= nil) and (donefirstwords[tileid][dir] == nil)) and (limiter < 10000) then
				local name = unit.strings[NAME]

				local readingx, readingy, readingdir = x, y, dir
				
				if (donefirstwords[tileid] == nil) then
					donefirstwords[tileid] = {}
				end
				
				donefirstwords[tileid][dir] = 1
				
				local variations = 1
				local done = false
				local sentences = {}
				local variantcount = {}
				local combo = {}
				
				local finals = {}
				
				local steps = 0
				local warps = {}
				
				while (done == false) do
					local words, newwarps = nil, {}
					if steps == 0 then
						words = gettextattile(readingx, readingy)
					else
						words, readingx, readingy, readingdir, newwarps = codecheck(unitdata[1], readingx, readingy, readingdir)
					end
					steps = steps + 1
					
					sentences[steps] = {}
					local sent = sentences[steps]
					
					table.insert(variantcount, #words)
					table.insert(combo, 1)
					
					if (#words > 0) then
						variations = variations * #words
						
						if (variations > #finals) then
							local limitdiff = variations - #finals
							for i=1,limitdiff do
								table.insert(finals, {})
							end
						end
						
						for i,v in ipairs(words) do
							local tile = mmf.newObject(v)
							local tilename = tile.strings[NAME]
							local tiletype = tile.values[TYPE]
							
							if (tile.strings[UNITTYPE] ~= "text") then
								tiletype = 0
							end
							
							table.insert(sent, {tilename, tiletype, v, readingdir})
						end

						-- Don't follow the same warp more than once (infinite loop protection)
						for _, warp in ipairs(newwarps) do
							for _, otherwarp in ipairs(warps) do
								if warp[1] == otherwarp[1] and warp[2] == otherwarp[2] then
									done = true
									break
								end
							end
							if done then
								break
							else
								table.insert(warps, warp)
							end
						end
					else
						done = true
					end
				end
				
				if (#sentences > 2) then
					for i=1,variations do
						-- Parser rewrite
						local sent = getsentencevariant(sentences,combo)
						local tokens = {}
						local currentLetters = ""
						local currentLetterIds = {}
						local currentLetterDirections = {}

						for idx=1, #sentences do
							if (variantcount[idx] > 0) then
								local s = sent[idx]
								local name, type, unitId, readingDir = s[1], s[2], s[3], s[4]
								
								if type == 5 then
									-- Handle Letters. I don't really know how this works, so it probably fails in some edge cases.
									-- But everything I tried works, including the tricks that the vanilla ABC levels use.
									currentLetters = currentLetters .. name
									table.insert(currentLetterIds, unitId)
									table.insert(currentLetterDirections, readingDir)

									local lName, lType, found, secondaryFound = findword(currentLetters, sent[idx + 1] or {-1, -1, -1}, name)

									if secondaryFound then
										-- This seems to handle situations like W[ALL] and GHOSTAR.
										table.insert(firstwords, {sent[idx - 1][3], dir})
									end

									-- As far as I can tell, `found` doesn't mean that we actually found the whole word yet, just that
									-- there are still possible words which our letters might be a prefix of.
									if not found then
										-- No hope for these letters. We represent the failed attempt at tokenizing a word
										-- with a token of type FAILED_LETTERS (-10).
										table.insert(tokens, {name = currentLetters, type = -10, unitId = currentLetterIds, isLetters = true, readingDirs = currentLetterDirections})
										break
									end

									-- We didn't find the whole word yet, but the rest might still be coming.
									if lType == -1 then
										local nextS = sent[idx + 1]
										if nextS == nil or nextS[2] ~= 5 then
											-- Next tile is not a letter, so we won't ever find the whole word.
											table.insert(tokens, {name = currentLetters, type = -10, unitId = currentLetterIds, isLetters = true, readingDirs = currentLetterDirections})
											break
										end
									else
										-- We actually found a word!
										table.insert(tokens, {name = lName, type = lType, unitId = currentLetterIds, isLetters = true, readingDirs = currentLetterDirections})
										currentLetters = ""
										currentLetterIds = {}
										currentLetterDirections = {}
									end
								else
									-- unitId is a bad name for this field, sorry. It's actually an array of unit IDs.
									-- (For letters, a token could consist of more than one unit.)
									table.insert(tokens, {name = name, type = type, unitId = {unitId}, readingDirs = {readingDir}})
								end
							end
						end

						local parserState = {consumed = 0, tokens = tokens}

						local success, targets, conds, condUnitIds, predicates, language = activemod.parser.rule(parserState)

						if success then
							-- Find all of the features that this rule will generate. This is the cartesian product of the targets and the predicates.
							for _, target in ipairs(targets) do
								local target, targetUnitIds = target[1], target[2]
								for _, predicate in ipairs(predicates) do
									local verb, effect, predicateUnitIds = predicate[1], predicate[2], predicate[3]

									-- Determine the specific list of text unit IDs for this feature. That is, the unit IDs specific to this
									-- target, the unit IDs specific to this predicate, and all of the unit IDs for the conditions (which
									-- are shared across all features the rule generates.)
									-- This is how the game can cross out only part of a rule if only some of it was blocked.
									local combinedUnitIds = activemod.concat({}, targetUnitIds, condUnitIds, predicateUnitIds)

									local extras = {language = language}
									if featureindex["false"] ~= nil then
										for _, unitIdList in ipairs(combinedUnitIds) do
											for _, unitId in ipairs(unitIdList) do
												local unit = mmf.newObject(unitId)
												if hasfeature(getname(unit), "is", "false", unitId) then
													extras.isFalse = true
													break
												end
											end
											if extras.isFalse then
												break
											end
										end

										if extras.isFalse then
											effect = activemod.invertEffect(effect)
										end
									end

									-- It is necessary to take a shallow copy of conds here, because addoption and postrules will
									-- mess with these and we don't want them to affect more rules than they should.
									addoption({target, verb, effect}, activemod.concat({}, conds), combinedUnitIds, nil, nil, extras)
								end
							end
						end

						-- If there are tokens left over from the parse attempt, put the last unit that was parsed
						-- back into firstwords.
						-- e.g. BABA IS FLAG IS YOU, we parsed BABA IS FLAG successfully, so put FLAG back into
						-- firstwords so that FLAG IS YOU can be parsed.
						-- e.g. FLAG BABA IS YOU, we failed, consuming 1 token, try again starting from BABA.
						-- e.g. IS BABA IS YOU, we failed, consuming no tokens, try again starting from BABA.

						local newFirstWordIndex = parserState.consumed
						if not success and newFirstWordIndex == 0 and tokens[1].isLetters and #tokens[1].unitId > 1 then
							-- If we started with letters and didn't even manage to get through that, try again
							-- with the first letter missing. This will ensure things like X Y Z B A B A IS YOU will eventually
							-- get to the BABA.
							local newFirstWordsDir = tokens[1].readingDirs[2]
							if newFirstWordsDir ~= 1 and newFirstWordsDir ~= 2 then
								table.insert(firstwords, {tokens[1].unitId[2], newFirstWordsDir})
							end
						else
							if not success then
								-- If we weren't successful with the last parse then instead just try again with the first one missing,
								-- in case we consumed some tokens which are important for the next rule.
								newFirstWordIndex = 2
							elseif newFirstWordIndex <= 1 then
								newFirstWordIndex = 2
							end

							-- Don't bother if it's the last unit because 1 unit on its own cannot make a rule.
							if newFirstWordIndex < #tokens then
								local newFirstWordsDir = tokens[newFirstWordIndex].readingDirs[1]
								if newFirstWordsDir ~= 1 and newFirstWordsDir ~= 2 then
									table.insert(firstwords, {tokens[newFirstWordIndex].unitId[1], newFirstWordsDir})
								end
							elseif #tokens >= 2 and tokens[#tokens].type == -10 then
								-- If the last token is failed letters, then the last comment is a lie. Our list of tokens
								-- is incomplete, so there might still be enough to make a new rule.
								local newFirstWordsDir = tokens[#tokens].readingDirs[1]
								if newFirstWordsDir ~= 1 and newFirstWordsDir ~= 2 then
									table.insert(firstwords, {tokens[#tokens].unitId[1], newFirstWordsDir})
								end
							end
						end

						combo = updatecombo(combo,variantcount)
					end
				end
			end
		end
	end
end

function gettextattile(x, y, onlyslant)
	local tileid = x + y * roomsizex
	local result = {}

	if (unitmap[tileid] ~= nil) then
		for i,b in ipairs(unitmap[tileid]) do
			local v = mmf.newObject(b)
			local name = getname(v)
			
			if (v.strings[UNITTYPE] == "text" or hasfeature(name, "is", "word", b)) and (not onlyslant or hasfeature(name, "is", "slant", b)) then
				table.insert(result, b)
			end
		end
	end

	return result
end

function codecheck(unitid, x, y, dir)
	local rx, ry, rdir, warps = activemod.getadjacenttile(unitid, x, y, dir)
	return gettextattile(rx, ry, dir == DIRECTION_DOWN_RIGHT), rx, ry, rdir, warps
end

local function handleallincondparams(params)
	local alreadyused = {}
	local newparams = {}
	local allfound = false
	
	--alreadyused[target] = 1
	
	for a,b in ipairs(params) do
		if (b ~= "all") then
			alreadyused[b] = 1
			table.insert(newparams, b)
		else
			allfound = true
		end
	end
	
	if allfound then
		for a,mat in pairs(objectlist) do
			if (alreadyused[a] == nil) and (a ~= "group") and (a ~= "all") and (a ~= "text") then
				table.insert(newparams, a)
				alreadyused[a] = 1
			end
		end
	end

	return newparams
end

function addoption(option,conds_,ids,visible,notrule,extras_)
	--MF_alert(option[1] .. ", " .. option[2] .. ", " .. option[3])
	
	local visual = true
	
	if (visible ~= nil) then
		visual = visible
	end
	
	local extras = extras_ or {}

	local conds = {}
	
	if (conds_ ~= nil) then
		conds = conds_
	else
		print("nil conditions in rule: " .. option[1] .. ", " .. option[2] .. ", " .. option[3])
	end
	
	if (#option == 3) then
		local rule = {option, conds, ids}
		for key, value in pairs(extras) do
			rule[key] = value
		end
		table.insert(pendingfeatures.features, rule)
		local target = option[1]
		local verb = option[2]
		local effect = option[3]
	
		if (pendingfeatures.featureindex[effect] == nil) then
			pendingfeatures.featureindex[effect] = {}
		end
		
		if (pendingfeatures.featureindex[target] == nil) then
			pendingfeatures.featureindex[target] = {}
		end
		
		if (pendingfeatures.featureindex[verb] == nil) then
			pendingfeatures.featureindex[verb] = {}
		end
		
		table.insert(pendingfeatures.featureindex[effect], rule)
		
		table.insert(pendingfeatures.featureindex[verb], rule)
		
		if (target ~= effect) then
			table.insert(pendingfeatures.featureindex[target], rule)
		end
		
		if visual then
			local visualrule = copyrule(rule)
			table.insert(pendingfeatures.visualfeatures, visualrule)
		end
		
		if (notrule ~= nil) then
			local notrule_effect = notrule[1]
			local notrule_id = notrule[2]
			
			if (pendingfeatures.notfeatures[notrule_effect] == nil) then
				pendingfeatures.notfeatures[notrule_effect] = {}
			end
			
			local nr_e = pendingfeatures.notfeatures[notrule_effect]
			
			if (nr_e[notrule_id] == nil) then
				nr_e[notrule_id] = {}
			end
			
			local nr_i = nr_e[notrule_id]
			
			table.insert(nr_i, rule)
		end
		
		if (#conds > 0) then
			for i, cond in ipairs(conds) do
				if cond[1] == "if" or cond[1] == "not if" then
					for _, ifcond in ipairs(cond[2]) do
						ifcond[2] = handleallincondparams(ifcond[2])
						for _, targetcond in ipairs(ifcond[3]) do
							targetcond[2] = handleallincondparams(targetcond[2])
						end
						for _, innercond in ipairs(ifcond[4]) do
							innercond[2] = handleallincondparams(innercond[2])
						end
					end
				elseif cond[2] ~= nil then
					if #cond[2] > 0 then
						cond[2] = handleallincondparams(cond[2])
					end
				end
			end
		end

		local targetnot = string.sub(target, 1, 3)
		local targetnot_ = string.sub(target, 5)
		
		if (targetnot == "not") and (objectlist[targetnot_] ~= nil) then
			for i,mat in pairs(objectlist) do
				if (i ~= "empty") and (i ~= "all") and (i ~= "level") and (i ~= "group") and (i ~= targetnot_) and (i ~= "text") then
					local rule = {i,verb,effect}
					--print(i .. " " .. verb .. " " .. effect)
					local newconds = {}
					for a,b in ipairs(conds) do
						table.insert(newconds, b)
					end
					addoption(rule,newconds,ids,false,{effect,#pendingfeatures.featureindex[effect]})
				end
			end
		end
		
		if (effect == "all") then
			if (verb ~= "is") then 
				for i,mat in pairs(objectlist) do
					if (i ~= "empty") and (i ~= "all") and (i ~= "level") and (i ~= "group") and (i ~= "text") then
						local rule = {target,verb,i}
						local newconds = {}
						for a,b in ipairs(conds) do
							table.insert(newconds, b)
						end
						addoption(rule,newconds,ids,false)
					end
				end
			end
		end

		if (target == "all") then
			for i,mat in pairs(objectlist) do
				if (i ~= "empty") and (i ~= "all") and (i ~= "level") and (i ~= "group") and (i ~= "text") then
					local rule = {i,verb,effect}
					local newconds = {}
					for a,b in ipairs(conds) do
						table.insert(newconds, b)
					end
					addoption(rule,newconds,ids,false)
				end
			end
		end
	end
end

function doruleeffects()
	local newruleids = {}
	local ruleeffectlimiter = {}
	local alreadytrue = {}
	local playrulesound = false
	local rulesoundshort = ""

	for i,rules in ipairs(features) do
		local rule = rules[1]
		local conds = rules[2]
		local ids = rules[3]
		local isFalse = rules.isFalse
		
		if (ids ~= nil) then
			local idlist = {}
			local effectsok = false
			
			if (#ids > 0) then
				for a,b in ipairs(ids) do
					table.insert(idlist, b)
				end
			end
			
			if (#idlist > 0) then
				for a,d in ipairs(idlist) do
					for c,b in ipairs(d) do
						if (b ~= 0) then
							local bunit = mmf.newObject(b)
							
							if isFalse and not alreadytrue[b] then
								MF_setcolour(b,2,2)
							elseif bunit.strings[UNITTYPE] == "text" then
								setcolour(b,"active")
								alreadytrue[b] = 1
							end
							newruleids[b] = 1
							
							if (ruleids[b] == nil) and (#undobuffer > 1) then
								if (ruleeffectlimiter[b] == nil) then
									local x,y = bunit.values[XPOS],bunit.values[YPOS]
									local c1,c2 = getcolour(b,"active")
									MF_particles("bling",x,y,5,c1,c2,1,1)
									ruleeffectlimiter[b] = 1
								end
								playrulesound = true
							end
						end
					end
				end
			end
		end
	end

	ruleids = newruleids
	
	if playrulesound then
		local pmult,sound = checkeffecthistory("rule")
		rulesoundshort = sound
		local rulename = "rule" .. tostring(math.random(1,5)) .. rulesoundshort
		MF_playsound(rulename)
	end
	
	ruleblockeffect()
end

function ruleblockeffect()
	local handled = {}
	
	for i,rules in pairs(features) do
		local rule = rules[1]
		local conds = rules[2]
		local ids = rules[3]
		local blocked = false
		
		for a,b in ipairs(conds) do
			if (b[1] == "never") then
				blocked = true
				break
			end
		end
		
		--MF_alert(rule[1] .. " " .. rule[2] .. " " .. rule[3] .. ": " .. tostring(blocked))
		
		if blocked then
			for a,d in ipairs(ids) do
				for c,b in ipairs(d) do
					if (handled[b] == nil) then
						local blockid = MF_create("Ingame_blocked")
						local bunit = mmf.newObject(blockid)
						
						local runit = mmf.newObject(b)
						
						bunit.x = runit.x
						bunit.y = runit.y
						
						bunit.values[XPOS] = runit.values[XPOS]
						bunit.values[YPOS] = runit.values[YPOS]
						bunit.layer = 1
						bunit.values[ZLAYER] = 20
						bunit.values[TYPE] = b
						
						local c1,c2 = getuicolour("blocked")
						MF_setcolour(blockid,c1,c2)
						
						handled[b] = 2
					end
				end
			end
		else
			for a,d in ipairs(ids) do
				for c,b in ipairs(d) do
					if (handled[b] == nil) then
						handled[b] = 1
					elseif (handled[b] == 2) then
						MF_removeblockeffect(b)
					end
				end
			end
		end
	end
end

function postrules()
	local limit = #pendingfeatures.features
	
	local protects = {}
	
	for i,rules in ipairs(pendingfeatures.features) do
		if (i <= limit) then
			local rule = rules[1]
			local conds = rules[2]
			local ids = rules[3]
			
			if (rule[1] == rule[3]) and (rule[2] == "is") then
				table.insert(protects, i)
			end

			local rulenot = 0
			local neweffect = ""
			
			local nothere = string.sub(rule[3], 1, 3)
			
			if (nothere == "not") then
				rulenot = 1
				neweffect = string.sub(rule[3], 5)
			end
			
			if (rulenot == 1) then
				local newconds = {}
				
				if (#conds > 0) then
					for a,cond in ipairs(conds) do
						local newcond = {cond[1],cond[2]}
						local condname = cond[1]
						local params = cond[2]
						
						local prefix = string.sub(condname, 1, 3)
						
						if (prefix == "not") then
							condname = string.sub(condname, 5)
						else
							condname = "not " .. condname
						end
						
						newcond[1] = condname
						newcond[2] = {}
						
						if (#params > 0) then
							for m,n in ipairs(params) do
								table.insert(newcond[2], n)
							end
						end
						
						table.insert(newconds, newcond)
					end
				else
					table.insert(newconds, {"never"})
				end
				
				local newbaserule = {rule[1],rule[2],neweffect}
				
				local target = rule[1]
				local verb = rule[2]
				
				for a,b in ipairs(pendingfeatures.featureindex[target]) do
					local same = comparerules(newbaserule,b[1])
					
					if same then
						--MF_alert(rule[1] .. ", " .. rule[2] .. ", " .. neweffect .. ": " .. b[1][1] .. ", " .. b[1][2] .. ", " .. b[1][3])
						local theseconds = b[2]
						
						if (#newconds > 0) then
							if (newconds[1] ~= "never") then
								for c,d in ipairs(newconds) do
									table.insert(theseconds, d)
								end
							else
								theseconds = {"never"}
							end
						end
						
						b[2] = theseconds
					end
				end
			end
		end
	end
	
	if (#protects > 0) then
		for i,v in ipairs(protects) do
			local rule = pendingfeatures.features[v]
			
			local baserule = rule[1]
			local conds = rule[2]
			
			local target = baserule[1]
			
			local newconds = {{"never"}}
			
			if (conds[1] ~= "never") then
				if (#conds > 0) then
					newconds = {}
					
					for a,b in ipairs(conds) do
						local condword = b[1]
						local condgroup = {}
						
						local newcondword = "not " .. condword
						
						if (string.sub(condword, 1, 3) == "not") then
							newcondword = string.sub(condword, 5)
						end
						
						if (b[2] ~= nil) then
							for c,d in ipairs(b[2]) do
								table.insert(condgroup, d)
							end
						end
						
						table.insert(newconds, {newcondword, condgroup})
					end
				end		
			
				if (pendingfeatures.featureindex[target] ~= nil) then
					for a,rules in ipairs(pendingfeatures.featureindex[target]) do
						local targetrule = rules[1]
						local targetconds = rules[2]
						
						local object = targetrule[3]
						
						if (targetrule[1] == target) and (targetrule[2] == "is") and (target ~= object) and (getmat(object) ~= nil) and (object ~= "group") then
							if (#newconds > 0) then
								if (newconds[1] == "never") then
									targetconds = {}
								end
								
								for c,d in ipairs(newconds) do
									table.insert(targetconds, d)
								end
							end
							
							rules[2] = targetconds
						end
					end
				end
			end
		end
	end
end

function iscond(word)
	local found = false
	
	for i,v in pairs(conditions) do
		if (word == i) or (word == "not " .. i) then
			found = true
			local args = v.arguments
			return true,args
		end
	end
	
	return false,0
end

function grouprules()
	local isgroup = {}
	local groupis = {}
	local groups = findgroup()
	
	if (pendingfeatures.featureindex["group"] ~= nil) then
		for i,rule in ipairs(pendingfeatures.featureindex["group"]) do
			local baserule = rule[1]
			local conds = rule[2]
			
			if (baserule[1] == "group") then
				table.insert(groupis, rule)
			end

			if (baserule[3] == "group") and (baserule[1] ~= "group") then
				table.insert(isgroup, rule)
			end
		end
	end
	
	local ends = {}
	local starts = {}
	
	if (#groupis > 0) then
		for i,rule in ipairs(groupis) do
			local baserule = rule[1]
			local conds = rule[2]
			local ids = rule[3]
			
			local verb = baserule[2]
			local effect = baserule[3]
			
			table.insert(ends, {effect,verb,conds,ids})
		end
	end			
	
	if (#isgroup > 0) then
		for i,rule in ipairs(isgroup) do
			local baserule = rule[1]
			local conds = rule[2]
			local ids = rule[3]
			
			local verb = baserule[2]
			local target = baserule[1]
			
			table.insert(starts, {target,verb,conds,ids})
		end
	end
	
	for i,v in ipairs(starts) do
		local ids = v[4]
		
		if (v[2] ~= "is") then
			local conds = {}
			if (#v[3] > 0) then
				for a,b in ipairs(v[3]) do
					table.insert(conds, b)
				end
			end
			
			for a,b in ipairs(starts) do
				if (b[2] == "is") then
					if (#b[3] > 0) then
						for c,d in ipairs(b[3]) do
							table.insert(conds, d)
						end
					end
					
					addoption({v[1],v[2],b[1]},conds,ids,false)
				end
			end
		end
		
		for a,b in ipairs(ends) do
			local conds = {}
			
			if (#v[3] > 0) then
				for c,d in ipairs(v[3]) do
					table.insert(conds, d)
				end
			end
			
			if (#b[3] > 0) then
				for c,d in ipairs(b[3]) do
					table.insert(conds, d)
				end
			end
			
			if (v[2] == "is") then
				addoption({v[1],b[2],b[1]},conds,ids,false)
			end
		end
	end
	
	if (#pendingfeatures.features > 0) and (#groups > 0) then
		for i,rules in ipairs(pendingfeatures.features) do
			local rule = rules[1]
			local conds = rules[2]
			
			if (#conds > 0) then
				for m,n in ipairs(conds) do
					if (n[2] ~= nil) then
						if (#n[2] > 0) then
							local thisrule = n[2]
							local limit = #n[2]
							local delthese = {}

							for a=1,limit do
								local b = thisrule[a]
								
								if (b == "group") then
									if (#groups > 0) then
										for c,d in ipairs(groups) do
											if (d[1] ~= "group") then
												table.insert(n[2], d[1])
												
												if (d[2] ~= nil) then
													for e,f in ipairs(d[2]) do
														if (f ~= "group") then
															table.insert(n[2], f)
														end
													end
												end
											end
										end
									end
									
									table.insert(delthese, a)
								end
							end
							
							if (#delthese > 0) then
								local offset = 0
								for a,b in ipairs(delthese) do
									local id = b + offset
									table.remove(n[2], id)
									offset = offset - 1
								end
							end
						end
					end
				end
			end
		end
	end
end

function copyrule(rule)
	local baserule = rule[1]
	local conds = rule[2]
	local ids = rule[3]
	
	local newbaserule = {}
	local newconds = {}
	local newids = {}
	
	newbaserule = {baserule[1],baserule[2],baserule[3]}
	
	if (#conds > 0) then
		for i,cond in ipairs(conds) do
			local newcond = {cond[1]}
			
			if (cond[2] ~= nil) then
				local condnames = cond[2]
				newcond[2] = {}
				
				for a,b in ipairs(condnames) do
					table.insert(newcond[2], b)
				end
			end
			
			table.insert(newconds, newcond)
		end
	end
	
	if (#ids > 0) then
		for i,id in ipairs(ids) do
			local iid = {}
			
			for a,b in ipairs(id) do
				table.insert(iid, b)
			end
			
			table.insert(newids, iid)
		end
	end
	
	local newrule = {newbaserule, newconds, newids}
	for key, value in pairs(rule) do
		if type(key) ~= "number" then
			newrule[key] = value
		end
	end
	
	return newrule
end

function updatecombo(combo_,variants)
	local increment = 1
	local combo = {}
	
	for i,v in ipairs(variants) do
		combo[i] = combo_[i]
		if (v > 1) then
			combo[i] = combo[i] + increment
			increment = 0
			
			if (combo[i] > v) then
				combo[i] = 1
				increment = 1
			end
		elseif (v == 0) then
			--print("no variants here?")
		end
	end
	
	if (increment == 0) then
		return combo
	else
		return nil
	end
end

function comparerules(baserule1,baserule2)
	local same = true
	
	for i,v in ipairs(baserule1) do
		if (v ~= baserule2[i]) then
			same = false
		end
	end
	
	return same
end

function findword(text,nexts,tilename)
	local name = ""
	local wtype = -1
	local found = false
	local secondaryfound = false
	
	local alttext = "text_" .. text
	
	if (string.len(text) > 0) then
		for i,v in pairs(unitreference) do
			if (string.len(text) > string.len(tilename) + 1) and (string.sub(i, 1, 2) == string.sub(text, -2)) and (i ~= text) then
				--MF_alert(i .. ", " .. text .. ", " .. tilename)
				secondaryfound = true
			end
			
			if (string.len(text) > string.len(tilename) + 1) and (string.sub(i, 1, 7) == "text_" .. string.sub(text, -2)) and (i ~= alttext) then
				--MF_alert(i .. ", " .. text .. ", " .. tilename)
				secondaryfound = true
			end
			
			if (string.len(i) >= string.len(text)) and (string.sub(i, 1, string.len(text)) == text) then
				found = true
			end
			
			if (string.len(i) >= string.len(alttext)) and (string.sub(i, 1, string.len(alttext)) == alttext) then
				found = true
			end
		end
	else
		found = true
	end
	
	if (string.len(text) > string.len(tilename)) and ((unitreference[text] ~= nil) or (unitreference[alttext] ~= nil)) then
		local realname = unitreference[text] or unitreference[alttext]
		
		local tiledata = tileslist[realname]
		
		if (tiledata ~= nil) then
			name = tiledata.name
			wtype = tonumber(tiledata.type) or 0
		end
		
		if (changes[realname] ~= nil) then
			local c = changes[realname]
			
			if (c.name ~= nil) then
				name = c.name
			end
			
			if (c.type ~= nil) then
				wtype = tonumber(c.type)
			end
		end
		
		if (unitreference[text] ~= nil) then
			objectlist[text] = 1
		elseif (((text == "all") or (text == "empty")) and (unitreference[alttext] ~= nil)) then
			objectlist[text] = 1
		end
		
		if (string.sub(name, 1, 5) == "text_") then
			name = string.sub(name, 6)
		end
		
		if (wtype == 5) then
			wtype = -1
		end
	end
	
	return name,wtype,found,secondaryfound
end

function getsentencevariant(sentences,combo)
	local result = {}
	
	for i,words in ipairs(sentences) do
		local currcombo = combo[i]
		
		local current = words[currcombo]
		
		table.insert(result, current)
	end
	
	return result
end