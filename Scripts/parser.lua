
local parser = {}

local FAILED_LETTERS = -10
local NOUN = 0
local VERB = 1
local PROP = 2
local PRECOND = 3
local NOT = 4
local LETTER = 5
local AND = 6
local POSTCOND = 7
local IF = 10
local QUANTIFIER = 11
local QUESTION_MARK = 20

function parser.printState(state)
	local printString = ""
	for idx, token in ipairs(state.tokens) do
		if idx == state.consumed + 1 then
			printString = printString .. "> "
		end
		printString = printString .. token.name .. " "
	end

	if state.consumed >= #state.tokens then
		printString = printString .. ">"
	end

	print(printString)
end

-- Consume the first token and return its name and type. Add its ID to unitIdList.
local function consume(state, unitIdList)
	if state.consumed >= #state.tokens then
		return nil
	end
	state.consumed = state.consumed + 1
	local token = state.tokens[state.consumed]
	table.insert(unitIdList, token.unitId)
	return token.name, token.type
end

local function contains(needle, haystack)
	if haystack == nil then
		return false
	end

	local t = type(haystack)
	if t == "number" or t == "string" then
		return needle == haystack
	end

	for _, x in ipairs(haystack) do
		if x == needle then
			return true
		end
	end
	return false
end

-- Check that the token exists and is one of the specified types or names. `types` can be
-- either a single type or an array of types. Same for names.
local function checkToken(state, idx, types, names)
	local token = state.tokens[state.consumed + idx]
	return token ~= nil and (contains(token.type, types) or contains(token.name, names))
end

-- As above, but we first skip past all of the NOTs.
local function checkFirstNonNotToken(state, startingIdx, types, names)
	for idx = state.consumed + startingIdx, #state.tokens do
		local token = state.tokens[idx]
		if token.type ~= NOT then
			return contains(token.type, types) or contains(token.name, names), idx
		end
	end
	return false, nil
end

function parser.rule(state)
	local success, targets, conds, condUnitIds, predicates = parser.englishRule(state)
	if success then
		return true, targets, conds, condUnitIds, predicates, nil
	end

	local alternateLanguages = {
		{"yoda", parser.yodaRule},
		{"clickbait", parser.clickbaitRule},
		{"caveman", parser.cavemanRule}
	}

	for _, data in ipairs(alternateLanguages) do
		local languageName, parserFunction = data[1], data[2]
		if featureindex[languageName] ~= nil then
			state.consumed = 0
			success, targets, conds, condUnitIds, predicates = parserFunction(state)
			-- Only allow the rule if every consumed token IS that language
			if success then
				for i = 1, state.consumed do
					for _, unitId in ipairs(state.tokens[i].unitId) do
						local unit = mmf.newObject(unitId)
						if not hasfeature(getname(unit), "is", languageName, unitId) then
							success = false
							break
						end
					end

					if not success then
						break
					end
				end

				if success then
					return true, targets, conds, condUnitIds, predicates, languageName
				end
			end
		end
	end

	return false
end

local function getParamTypes(word)
	local realName = unitreference["text_" .. word]
	local wValues = changes[realName]
	if wValues == nil then
		wValues = tileslist[realName]
	end

	if wValues == nil then
		return NOUN, nil
	end

	return wValues.argtype or NOUN, wValues.argextra or nil
end

function parser.englishRule(state)
	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	local done2, predicates = parser.predicates(state)

	if #predicates == 0 then
		return false
	end

	if done2 then
		return true, targets, conds, condUnitIds, predicates
	end

	local done3, ifConds = parser.ifConds(state, condUnitIds)
	if ifConds ~= nil then
		table.insert(conds, ifConds)
	end
	return true, targets, conds, condUnitIds, predicates
end

function parser.yodaRule(state)
	-- We don't know what the allowed verb param types are yet, because we don't know
	-- what the verb is. For now, allow everything, then we will check them later on.
	local done, effects = parser.andSeparatedListWithSeparateIdLists(state, {NOUN, PROP})

	if done then
		return false
	end

	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	-- Yoda rule can only have one verb.
	if not checkToken(state, 1, VERB) then
		return false
	end

	local verbIds = {}
	local verb = consume(state, verbIds)
	local paramTypes, argExtra = getParamTypes(verb)
	local predicates = {}

	for _, data in ipairs(effects) do
		local effect, unitIds, type = data[1], data[2], data[3]
		-- Finally check the verb params.
		if not contains(type, paramTypes) then
			return false
		end
		table.insert(predicates, {verb, effect, activemod.concat(unitIds, verbIds)})
	end

	return true, targets, conds, condUnitIds, predicates
end

function parser.cavemanRule(state)
	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	local done, effects = parser.andSeparatedListWithSeparateIdLists(state, {NOUN, PROP})
	if done then
		return false
	end

	local predicates = {}
	for _, data in ipairs(effects) do
		table.insert(predicates, {"is", data[1], data[2]})
	end

	return true, targets, conds, condUnitIds, predicates
end

function parser.clickbaitRule(state)
	-- Do we allow verbs other than IS? The answer may surprise you! (We don't, because "has baba keke?" is not good grammar.)
	if state.tokens[state.consumed + 1] == nil or state.tokens[state.consumed + 1].name ~= "is" then
		return false
	end

	local globalIds = {}
	consume(state, globalIds)

	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	local done, effects = parser.andSeparatedListWithSeparateIdLists(state, {NOUN, PROP})
	if done then
		return false
	end

	if not checkToken(state, 1, QUESTION_MARK) then
		return false
	end

	consume(state, globalIds)

	local predicates = {}
	for _, data in ipairs(effects) do
		local effect, idList = data[1], data[2]
		table.insert(predicates, {"is", activemod.invertEffect(effect), activemod.concat(idList, globalIds)})
	end

	return true, targets, conds, condUnitIds, predicates
end

-- Parse (NOT*) and return either "not " is there was an odd number
-- of nots or "" otherwise. Add the ID of the nots to unitIdList.
function parser.nots(state, unitIdList)
	local isNot = false
	while checkToken(state, 1, NOT) do
		isNot = not isNot
		consume(state, unitIdList)
	end
	if isNot then
		return "not "
	end
	return ""
end

function parser.subject(state)
	local condUnitIds = {}
	local preConds = parser.preConds(state, condUnitIds)

	local done, targets = parser.andSeparatedListWithSeparateIdLists(state, NOUN)
	if done then
		return true, {}, {}, {}
	end

	local done2, postConds = parser.postConds(state, condUnitIds)
	if done2 then
		return true, {}, {}, {}
	end

	return false, targets, activemod.concat(preConds, postConds), condUnitIds
end

function parser.preConds(state, unitIdList)
	if checkFirstNonNotToken(state, 1, PRECOND) then
		-- Vanilla actually doesn't support multiple preconds, probably because it
		-- only has one precond anyway (Lonely). But we might as well support multiple.
		local done, condNames = parser.andSeparatedList(state, PRECOND, unitIdList)
		local result = {}
		for _, cond in ipairs(condNames) do
			table.insert(result, {cond, {}})
		end
		return result
	end
	return {}
end

-- Parse nots <types> (AND nots <types>)*
-- e.g. parser.andSeparatedListWithSeparateIdLists(state, {NOUN}) parses one or more nouns separated by AND.
-- There must be at least one, otherwise we are done.
-- Returns array of string and adds all unit IDs to the list.
function parser.andSeparatedList(state, types, unitIdList, isIfCondParams, argExtra)
	if not checkFirstNonNotToken(state, 1, types, argExtra) then
		return true, {}
	end
	local result = {parser.nots(state, unitIdList) .. consume(state, unitIdList)}

	while true do
		local isCorrectType, idx = checkFirstNonNotToken(state, 2, types, argExtra)
		if not (checkToken(state, 1, AND) and isCorrectType) then
			return false, result
		end

		-- In this situation: IF A IS ON B > AND C IS LONELY
		-- We don't want to consume the AND C.
		if isIfCondParams then
			local testToken = state.tokens[idx + 1]
			if testToken ~= nil and (testToken.name == "is" or testToken.type == POSTCOND) then
				return false, result
			end
		end

		consume(state, unitIdList) -- AND
		table.insert(result, parser.nots(state, unitIdList) .. consume(state, unitIdList))
	end
end

-- As above, but returns array of {name, unitIdList, type} with separate ID lists for each parsed item.
function parser.andSeparatedListWithSeparateIdLists(state, types)
	if not checkFirstNonNotToken(state, 1, types) then
		return true, {}
	end

	local unitIdList = {}
	local prefix = parser.nots(state, unitIdList)
	local item, itemType = consume(state, unitIdList)
	local result = {{prefix .. item, unitIdList, itemType}}

	while true do
		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, types)) then
			return false, result
		end

		unitIdList = {}
		consume(state, unitIdList) -- AND
		prefix = parser.nots(state, unitIdList)
		item, itemType = consume(state, unitIdList)
		table.insert(result, {prefix .. item, unitIdList, itemType})
	end
end

-- local function flattenAndSeparatedList(andSeparatedList, unitIdList)
-- 	local result = {}
-- 	for _, entry in ipairs(andSeparatedList) do
-- 		local word, unitIds = entry[1], entry[2]
-- 		table.insert(result, word)
-- 		for _, unitId in ipairs(unitIds) do
-- 			table.insert(unitIdList, unitId)
-- 		end
-- 	end
-- 	return result
-- end

function parser.postConds(state, unitIdList)
	if not checkFirstNonNotToken(state, 1, POSTCOND) then
		return false, {}
	end

	local prefix, cond = parser.nots(state, unitIdList), consume(state, unitIdList)
	local paramTypes, argExtra = getParamTypes(cond)
	local done, params = parser.andSeparatedList(state, paramTypes, unitIdList, false, argExtra)
	if done then
		return true, {}
	end
	local postConds = {{prefix .. cond, params}}

	while true do
		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, POSTCOND)) then
			return false, postConds
		end
		consume(state, unitIdList) -- AND
		prefix, cond = parser.nots(state, unitIdList), consume(state, unitIdList)
		paramTypes, argExtra = getParamTypes(cond)
		done, params = parser.andSeparatedList(state, paramTypes, unitIdList, false, argExtra)
		if done then
			return true, {}
		end

		table.insert(postConds, {prefix .. cond, params})
	end
end

function parser.predicates(state)
	if not checkToken(state, 1, VERB) then
		return true, {}
	end

	local predicates = {}

	local verbUnitIds = {}
	local verb = consume(state, verbUnitIds)
	local done, andSeparatedList = parser.andSeparatedListWithSeparateIdLists(state, getParamTypes(verb))
	if done then
		return true, {}
	end

	for _, param in ipairs(andSeparatedList) do
		local effect, effectUnitIds = param[1], param[2]
		table.insert(predicates, {verb, effect, activemod.concat(effectUnitIds, verbUnitIds)})
	end

	while true do
		if not (checkToken(state, 1, AND) and checkToken(state, 2, VERB)) then
			return false, predicates
		end
		verbUnitIds = {}
		consume(state, verbUnitIds) -- AND
		verb = consume(state, verbUnitIds)
		done, andSeparatedList = parser.andSeparatedListWithSeparateIdLists(state, getParamTypes(verb))
		if done then
			return true, predicates
		end

		for _, param in ipairs(andSeparatedList) do
			local effect, effectUnitIds = param[1], param[2]
			table.insert(predicates, {verb, effect, activemod.concat(effectUnitIds, verbUnitIds)})
		end
	end
end

function parser.ifConds(state, unitIdList)
	if not checkToken(state, 1, IF) then
		return false, nil
	end

	local ifConds = {}
	while true do
		if not checkToken(state, 1, {IF, AND}) then
			return false, {"if", ifConds}
		end

		local newUnitIds = {}
		consume(state, newUnitIds) -- AND / IF

		local done, newIfCond = parser.ifCond(state, newUnitIds)
		if newIfCond ~= nil then
			table.insert(ifConds, newIfCond)
			activemod.concat(unitIdList, newUnitIds)
		end

		if done then
			if #ifConds == 0 then
				return true, nil
			end
			return true, {"if", ifConds}
		end
	end
end

function parser.ifCond(state, unitIdList)
	local quantifier = ""
	if checkFirstNonNotToken(state, 1, QUANTIFIER) then
		quantifier = parser.nots(state, unitIdList) .. consume(state, unitIdList)
	end

	local done, parsedTargets, conds, condUnitIds = parser.subject(state)
	if done then
		return true, nil
	end

	local targets = {}
	for _, data in ipairs(parsedTargets) do
		table.insert(targets, data[1])
		activemod.concat(unitIdList, data[2])
	end
	activemod.concat(unitIdList, condUnitIds)

	if not checkToken(state, 1, nil, "is") then
		return true, nil
	end
	consume(state, unitIdList) -- is

	local done2, ifPredicates = parser.ifPredicates(state, unitIdList)
	if #ifPredicates == 0 then
		return true, nil
	end

	return done2, {quantifier, targets, conds, ifPredicates}
end

function parser.ifPredicates(state, unitIdList)
	if not checkFirstNonNotToken(state, 1, {PROP, PRECOND, POSTCOND}) then
		return true, {}
	end

	local ifPredicates = {}
	local thisPredicateUnitIds = {}

	while true do
		if checkFirstNonNotToken(state, 1, PROP) then
			local prop = consume(state, thisPredicateUnitIds)
			table.insert(ifPredicates, {parser.nots(state, thisPredicateUnitIds) .. "cg5with", {prop}})

		elseif checkFirstNonNotToken(state, 1, PRECOND) then
			table.insert(ifPredicates, {parser.nots(state, thisPredicateUnitIds) .. consume(state, thisPredicateUnitIds), {}})

		elseif checkFirstNonNotToken(state, 1, POSTCOND) then
			local prefix, cond = parser.nots(state, unitIdList), consume(state, unitIdList)
			local paramTypes, argExtra = getParamTypes(cond)
			local done, objects = parser.andSeparatedList(state, paramTypes, thisPredicateUnitIds, true, argExtra)
			if done then
				return true, ifPredicates
			end
			table.insert(ifPredicates, {prefix .. cond, objects})
		end

		activemod.concat(unitIdList, thisPredicateUnitIds)
		thisPredicateUnitIds = {}

		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, {PROP, PRECOND, POSTCOND})) then
			return false, ifPredicates
		end
		consume(state, thisPredicateUnitIds) -- AND
	end
end

return function (mod)
	mod.parser = parser
end