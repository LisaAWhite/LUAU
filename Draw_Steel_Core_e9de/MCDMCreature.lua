local mod = dmhub.GetModLoading()

--- @field creature.minion boolean
creature.minion = false

--- @field creature.minionDead boolean
creature.minionDead = false

--- @field creature.initiativeGrouping false|string
creature.initiativeGrouping = false

--- @alias SquadInfo table


--- @field creature._tmp_minionSquad SquadInfo

function creature:MinionSquad()
	if self:has_key("minionSquad") then
		return self.minionSquad
	end

	if self.minion then
		return string.format("%s Squad 1", self.monster_type)
	end

	return nil
end

local g_baseInvalidate = creature.Invalidate
function creature:Invalidate()
	g_baseInvalidate(self)

	if mod.unloaded then
		return
	end

	self._tmp_adjacentLocs = nil
	self._tmp_occupiedLocs = nil
	self._tmp_flankfromanydirection = nil
    self._tmp_highestCharacteristic = nil
    self._tmp_maxSurgeCount = nil
end

local g_creatureSingleMaxHitpoints = creature.MaxHitpoints
function creature.MaxHitpoints(self, modifiers)
	if (not mod.unloaded) and self.minion and self:has_key("_tmp_minionSquad") then
		local squad = self:MinionSquad()
		if squad ~= nil then
			local liveMinions = self._tmp_minionSquad.liveMinions
			return liveMinions * g_creatureSingleMaxHitpoints(self)
		end
	end

	return g_creatureSingleMaxHitpoints(self, modifiers)
end

function creature:Potency()
    return self:HighestCharacteristic()
end

--@param attrid string
--@return number|nil
function creature:AttributeForPotencyResistance(attrid)
    local customAttr = CustomAttribute.attributeInfoByLookupSymbol[string.lower(creature.attributesInfo[attrid].description) .. "potencyresistance"]
    local value = nil
    if customAttr ~= nil then
        local result = self:GetCustomAttribute(customAttr)
        return result
    else
        local attr = self:GetAttribute(attrid)
        if attr ~= nil then
            return attr:Modifier()
        end
    end

    return nil
end

--@param attrid string
--@return { key: string, value: string}[]
function creature:AttributeForPotencyResistanceDescription(attrid)
    local customAttr = CustomAttribute.attributeInfoByLookupSymbol[string.lower(creature.attributesInfo[attrid].description) .. "potencyresistance"]
    if customAttr ~= nil then
        local baseValue = customAttr:CalculateBaseValue(self)
        local result = self:DescribeModifications(customAttr.id, baseValue)
        return result
    end

    return nil
end

function creature:ForcedMovementBonus(moveType)
    local result = 0

    local customAttr = CustomAttribute.attributeInfoByLookupSymbol["forcedmovementbonus"]
    if customAttr ~= nil then
        result = result + self:GetCustomAttribute(customAttr)
    end

    local customAttr = CustomAttribute.attributeInfoByLookupSymbol[moveType .. "bonus"]
    if customAttr ~= nil then
        result = result + self:GetCustomAttribute(customAttr)
    end

    return result
end

function creature:HighestCharacteristic()
    if not self:has_key("_tmp_highestCharacteristic") then
        local highest = nil
        for _,attrid in ipairs(creature.attributeIds) do
            local value = self:AttributeMod(attrid)
            if highest == nil or value > highest then
                highest = value
            end
        end

        self._tmp_highestCharacteristic = highest
    end

    return self._tmp_highestCharacteristic
end

function creature:ConsumeSurges(ncount, note)
    local surgeid = CharacterResource.nameToId["Surges"]
    if surgeid == nil then
        return
    end

    self:AddUnboundedResource(surgeid, -ncount, note or "Consumed Surges")
end

function creature:GetAvailableSurges()
    local surgeid = CharacterResource.nameToId["Surges"]
    if surgeid == nil then
        return 0
    end

    return self:GetUnboundedResourceQuantity(surgeid)
end

function creature:GetMaxSurgeCount()
    if not self:has_key("_tmp_maxSurgeCount") then
        local customAttr = CustomAttribute.attributeInfoByLookupSymbol["maximumsurges"]
        if customAttr == nil then
            self._tmp_maxSurgeCount = 3
        else
            self._tmp_maxSurgeCount = self:GetCustomAttribute(customAttr)
        end
    end

    return self._tmp_maxSurgeCount
end

local g_minionSquadTables = {}

local g_baseRefreshToken = creature.RefreshToken

function creature:RefreshToken(token)
	if (not mod.unloaded) and self.minion then
        self:RefreshSquadInfo(token)
	end

	g_baseRefreshToken(self, token)

    if not mod.unloaded then
        self:RefreshInitiativeInfo(token)
    end
end

function creature:RefreshInitiativeInfo(token)
	local q = dmhub.initiativeQueue
	if q == nil or q.hidden then
		self._tmp_initiativeStatus = nil
	else
		local initiativeid = InitiativeQueue.GetInitiativeId(token)
		local initiativeEntry = q:GetFirstInitiativeEntry()
		if initiativeEntry ~= nil and initiativeEntry.initiativeid == initiativeid then
			self._tmp_initiativeStatus = "OurTurn"
		elseif not q:HasInitiative(initiativeid) then
			self._tmp_initiativeStatus = "NonCombatant"
		elseif q:HasHadTurn(initiativeid) then
			self._tmp_initiativeStatus = "Done"
		elseif q:ChoosingTurn() and q:IsPlayersTurn() == q:IsEntryPlayer(initiativeid) then
			self._tmp_initiativeStatus = "ActiveAndReady"
		else
			self._tmp_initiativeStatus = "Active"
		end

	end
end

local g_OnCreateFromBestiary = monster.OnCreateFromBestiary

function monster.OnCreateFromBestiary(self, token)
    g_OnCreateFromBestiary(self, token)

    if mod.unloaded then
        return
    end

    if self.minion then
        --clear out any squad information for minions.
        self.squadpos = nil

        --try to assign our minion to a fresh squad of undamaged minions.
        for i=1,100 do
		    local squadid = string.format("%s Squad %d", self.monster_type, i)
		    local minionSquad = g_minionSquadTables[squadid]
            if minionSquad == nil or (minionSquad.damage_taken or 0) == 0 then
                --this is a fresh squad to put our minion into.
                self.minionSquad = squadid
                break
            end
            
        end
    end
end

--- Refresh info about the squad.
--- @param token CharacterToken
function creature:RefreshSquadInfo(token)
    if not self.minion then
        return
    end

	--create a shared table for our minion squad.
	local squad = self:MinionSquad()
	if self:has_key("_tmp_minionSquad") == false or self._tmp_minionSquad.name ~= squad then
		local minionSquad = g_minionSquadTables[squad]

		if minionSquad == nil then
			minionSquad = {
				name = squad,
			}
			g_minionSquadTables[squad] = minionSquad
		end

		self._tmp_minionSquad = minionSquad
	end

	if self._tmp_minionSquad.updateid ~= dmhub.gameupdateid then

		self._tmp_minionSquad.updateid = dmhub.gameupdateid
		self._tmp_minionSquad.tokens = {}
        self._tmp_minionSquad.captain = nil

		local squad = self:MinionSquad()
		local tokens = dmhub.GetTokens{
			haveProperties = true,
		}

		local liveMinions = 0
		local damage_taken = self._tmp_minionSquad.damage_taken or 0
		local damage_taken_seq = self._tmp_minionSquad.damage_taken_seq or 0
		local damage_taken_minion_count = self._tmp_minionSquad.liveMinions or nil

		for _,tok in ipairs(tokens) do
			if tok.properties:MinionSquad() == squad then
				if tok.properties.minion then
					self._tmp_minionSquad.tokens[#self._tmp_minionSquad.tokens+1] = tok
					if (not tok.properties.minionDead) and tok.properties.minion then
						liveMinions = liveMinions + 1
					end

					if tok.properties:has_key("squadpos") then
						self._tmp_minionSquad.pos = tok.properties.squadpos
					end

					if tok.properties:has_key("damage_taken_seq") and tok.properties.damage_taken_seq > damage_taken_seq then
						damage_taken_seq = tok.properties.damage_taken_seq
						damage_taken = tok.properties.damage_taken
						damage_taken_minion_count = tok.properties:try_get("damage_taken_minion_count")
					end
				else
					self._tmp_minionSquad.captain = tok
				end
			end
		end

		if damage_taken_minion_count == nil then
			damage_taken_minion_count = liveMinions
		end

		local health_single = g_creatureSingleMaxHitpoints(self)

		if damage_taken_minion_count > liveMinions then
			damage_taken = damage_taken - (damage_taken_minion_count - liveMinions) * health_single
			if damage_taken < 0 then
				damage_taken = 0
			end
		end

        local newHasCaptain = self._tmp_minionSquad.captain ~= nil and self._tmp_minionSquad.captain.valid and (not self._tmp_minionSquad.captain.properties:IsDead())
        local needInvalidate = self._tmp_minionSquad.hasCaptain ~= newHasCaptain

        self._tmp_minionSquad.hasCaptain = newHasCaptain
		self._tmp_minionSquad.liveMinions = liveMinions
		self._tmp_minionSquad.health_single = health_single
		self._tmp_minionSquad.maximum_health = health_single * liveMinions
		self._tmp_minionSquad.damage_taken = damage_taken
		self._tmp_minionSquad.damage_taken_seq = damage_taken_seq
		self._tmp_minionSquad.color = DrawSteelMinion.GetSquadColor(squad)

        if needInvalidate then
            for _,tok in ipairs(self._tmp_minionSquad.tokens) do
                tok.properties:Invalidate()
            end
        end
	end

	if self._tmp_minionSquad.tokens[1].charid == token.charid then
		local onCurrentFloor = false
		local curFloor = dmhub.floorid
		for _,tok in ipairs(self._tmp_minionSquad.tokens) do
			if tok.valid and tok.floorid == curFloor then
				onCurrentFloor = true
				break
			end
		end
		if onCurrentFloor then
			DrawSteelMinion.SquadHud(curFloor, self._tmp_minionSquad)
		end
	end
end

--override moved and make it so when we move if we are pending initiative
--that indicates we automatically declare it our turn.
local g_baseMoved = creature.Moved
function creature:Moved(path)
	g_baseMoved(self, path)

	if mod.unloaded then
		return
	end

	self:TryClaimTurn()
end

--when using an action or a maneuver we also are claiming the turn if 
local g_baseConsumeResource = creature.ConsumeResource
function creature:ConsumeResource(key, refreshType, quantity, note)
	g_baseConsumeResource(self, key, refreshType, quantity, note)

	if mod.unloaded then
		return
	end

	local resourceTable = dmhub.GetTable(CharacterResource.tableName)
	local resourceInfo = resourceTable[key]
	if resourceInfo ~= nil and (resourceInfo.name == "Action" or resourceInfo.name == "Maneuver") then
		self:TryClaimTurn()
	end
end

--function to claim our turn if we are ready to go for initiative.
function creature:TryClaimTurn()
	local token = dmhub.LookupToken(self)
	if token == nil then
		return
	end

	local q = dmhub.initiativeQueue
	if q ~= nil and (not q.hidden) then
		--if we are ready to go into initiative then assume this starts our turn.
		local initiativeid = InitiativeQueue.GetInitiativeId(token)
		local initiativeEntry = initiativeid == q:GetFirstInitiativeEntry()
		if q:HasInitiative(initiativeid) and (not q:HasHadTurn(initiativeid)) and q:ChoosingTurn() and q:IsPlayersTurn() == q:IsEntryPlayer(initiativeid) then
			q:SelectTurn(initiativeid)
			dmhub:UploadInitiativeQueue()
		end
	end
end

--- @return boolean
function creature:IsHero()
    return false
end

--- @return boolean
function character:IsHero()
    return true
end

--- @return Loc[]
function creature:OccupiedLocs()
	if rawget(self, "_tmp_occupiedLocs") == nil then
		local token = dmhub.LookupToken(self)
		if token ~= nil then
			self._tmp_occupiedLocs = token.locsOccupying
		else
			self._tmp_occupiedLocs = {}
		end
	end

	return self._tmp_occupiedLocs
end

--- @return Loc[]
function creature:AdjacentLocations()
	if rawget(self, "_tmp_adjacentLocsxx") == nil then
		local token = dmhub.LookupToken(self)
		if token ~= nil then
			self._tmp_adjacentLocs = MCDMLocUtils.GetTokenAdjacentLocsInOpposingPairs(token)
		else
			self._tmp_adjacentLocs = {}
		end
	end

	return self._tmp_adjacentLocs
end

CustomAttribute.RegisterAttribute{
	id = "flankfromanydirection",
	text = "Flank From Any Direction",
	attributeType = "number",
	category = "Basic Attributes",
}

function creature:FlankFromAnyDirection()
	local result = self:try_get("_tmp_flankfromanydirection")
	if result ~= nil then
		return result ~= 0
	end

	self._tmp_flankfromanydirection = self:CalculateAttribute("flankfromanydirection", 0)
	return self._tmp_flankfromanydirection ~= 0
end

creature.RegisterSymbol{
	symbol = "flankedby",
	lookup = function(c)
		return function(otherCreature, secondCreature)
            if otherCreature == secondCreature then
                return false
            end
			local tok = dmhub.LookupToken(otherCreature)
            if tok == nil then
                return false
            end
			if not c:FlankedBy(tok) then
                return false
            end

            if secondCreature ~= nil then
                local secondTok = dmhub.LookupToken(secondCreature)
                if secondTok == nil then
                    return false
                end

                if not c:FlankedBy(secondTok) then
                    return false
                end

                if #c:GetFlankingTokens({tok, secondTok}) < 2 then
                    return false
                end
            end

			return true
		end
	end,

	help = {
		name = "Flanked By",
		type = "function",
		desc = "Given another creature, tells us if this creature is flanked by that creature. Can be given two creatures in which case it will return true if those two creatures are co-flanking this creature (They must not only be flanking but be flanking with each other).",
		seealso = {},
	},
}

local function GetEnemyCreaturesAtLoc(token, loc, result)
	local tokensAtLoc = dmhub.GetTokensAtLoc(loc)
	if tokensAtLoc ~= nil then
		for _,otherTok in ipairs(tokensAtLoc) do
			if token.charid ~= otherTok.charid and token:IsFriend(otherTok) == false and otherTok:GetLineOfSight(token) > 0 then
				local alreadyFound = false
				for _,existing in ipairs(result) do
					if existing.charid == otherTok.charid then
						alreadyFound = true
						break
					end
				end

				if not alreadyFound then
					result[#result+1] = otherTok
				end
			end
		end
	end
end

local function GetFlankingCreaturesFromOpposingSides(token, locs_a, locs_b, result)
	local enemies_a = {}
	local enemies_b = {}
	for _,loc in ipairs(locs_a) do
		GetEnemyCreaturesAtLoc(token, loc, enemies_a)
	end

	if #enemies_a == 0 then
		return
	end

	for _,loc in ipairs(locs_b) do
		GetEnemyCreaturesAtLoc(token, loc, enemies_b)
	end

	if #enemies_b == 0 then
		return
	end

	if #enemies_a == 1 and #enemies_b == 1 and enemies_a[1].charid == enemies_b[1].charid then
		return
	end

	for _,a in ipairs(enemies_a) do
		local alreadyFound = false
		for _,b in ipairs(result) do
			if a.charid == b.charid then
				alreadyFound = true
				break
			end
		end
		if not alreadyFound then
			result[#result+1] = a
		end
	end

	for _,a in ipairs(enemies_b) do
		local alreadyFound = false
		for _,b in ipairs(result) do
			if a.charid == b.charid then
				alreadyFound = true
				break
			end
		end
		if not alreadyFound then
			result[#result+1] = a
		end
	end
end

local function GetLocsAdjacentToToken(token)
	local locs = token.locsOccupying
    local topLeft = locs[1]
    local bottomRight = locs[1]

    for _,loc in ipairs(locs) do
        if loc.x < topLeft.x or loc.y < topLeft.y then
            topLeft = loc
        end

        if loc.x > bottomRight.x or loc.y > bottomRight.y then
            bottomRight = loc
        end
    end

	topLeft = topLeft:dir(-1,-1)
	bottomRight = bottomRight:dir(1,1)

	local w = bottomRight.x - topLeft.x
	local h = bottomRight.y - topLeft.y

	local result = {}

	local p = topLeft
	for i=1,w do
		result[#result+1] = p
		p = p:dir(1,0)
	end

	for i=1,h do
		result[#result+1] = p
		p = p:dir(0,1)
	end

	for i=1,w do
		result[#result+1] = p
		p = p:dir(-1,0)
	end

	for i=1,h do
		result[#result+1] = p
		p = p:dir(0,-1)
	end

	result[#result+1] = p

	return result
end

local function GetEnemiesAdjacentToToken(token)
	local locs = GetLocsAdjacentToToken(token)
	local result = {}
	for _,loc in ipairs(locs) do
		GetEnemyCreaturesAtLoc(token, loc, result)
	end

	return result
end

function creature:GetFlankingTokens(tokensOverride)
	local token = dmhub.LookupToken(self)
	if token == nil or (not token.valid) then
		return {}
	end

    if self:ImmuneFromFlanking() then
        return {}
    end

	local adjacentEnemies = tokensOverride or GetEnemiesAdjacentToToken(token)
	if #adjacentEnemies <= 1 then
		return {}
	end

    --remove any enemies that we don't have line of sight to.
	for i=#adjacentEnemies,1,-1 do
        local los = adjacentEnemies[i]:GetLineOfSight(token)
        if los <= 0 then
            table.remove(adjacentEnemies, i)
        end
    end

	if #adjacentEnemies <= 1 then
		return {}
	end

	for _,enemy in ipairs(adjacentEnemies) do
		local allflanking = enemy.properties:FlankFromAnyDirection()
		if allflanking then
			return adjacentEnemies
		end
	end

	local result = {}

	local locs = token.locsOccupying
    local topLeft = locs[1]
    local bottomRight = locs[1]

    for _,loc in ipairs(locs) do
        if loc.x < topLeft.x or loc.y < topLeft.y then
            topLeft = loc
        end

        if loc.x > bottomRight.x or loc.y > bottomRight.y then
            bottomRight = loc
        end
    end

	topLeft = topLeft:dir(-1,-1)
	bottomRight = bottomRight:dir(1,1)

	GetFlankingCreaturesFromOpposingSides(token, {topLeft}, {bottomRight}, result)
	GetFlankingCreaturesFromOpposingSides(token, {topLeft:dir(bottomRight.x-topLeft.x)}, {bottomRight:dir(topLeft.x-bottomRight.x)}, result)

	local topLocs = {}
	local botLocs = {}
	for i=1,bottomRight.x-topLeft.x-1 do
		topLocs[#topLocs+1] = topLeft:dir(i, 0)
		botLocs[#botLocs+1] = bottomRight:dir(-i, 0)
	end

	GetFlankingCreaturesFromOpposingSides(token, topLocs, botLocs, result)

	local leftLocs = {}
	local rightLocs = {}
	for i=1,bottomRight.y-topLeft.y-1 do
		leftLocs[#leftLocs+1] = topLeft:dir(0, i)
		rightLocs[#rightLocs+1] = bottomRight:dir(0, -i)
	end

	GetFlankingCreaturesFromOpposingSides(token, leftLocs, rightLocs, result)

	return result
end

function creature:FlankedBy(otherToken, token)
	local flanking = self:GetFlankingTokens()
	for _,tok in ipairs(flanking) do
		if tok.charid == otherToken.charid then
			return true
		end
	end

	return false
end

function creature:ImmuneFromFlanking()
    local flankingAttr = CustomAttribute.LookupCustomAttributeBySymbol("flankingimmunity")
    if flankingAttr == nil then
        return false
    end
    return (self:GetCustomAttribute(flankingAttr) or 0) >= 1
    
end

function creature:Echelon()
    return math.min(4, math.ceil(self:CharacterLevel()/3))
end

function creature:Keywords()
	return {}
end

function creature:GetNumDeathSavingThrowSuccesses()
    return 0
end

function creature:GetNumDeathSavingThrowFailures()
    return 0
end

--- @return boolean
function creature:IsDeadOrDying()
	return self:IsDead()
end

--- @return boolean
function creature:IsDying()
	return false
end

--- @return boolean
function creature:IsDown()
	return self:IsDead()
end

--- @return boolean
function character:IsDead()
	return self:CurrentHitpoints() <= -self:BloodiedThreshold()
end

--- @return boolean
function monster:IsDead()
	return self:CurrentHitpoints() <= 0
end

CustomAttribute.RegisterAttribute{id = "extraturns", text = "Extra Turns", attributeType = "number", category = "Basic Attributes"}

function creature:TurnsPerRound()
    return 1 + self:CalculateAttribute("extraturns", 0)
end

CustomAttribute.RegisterAttribute{id = "forcedmoveresistance", text = "Stability", attributeType = "number", category = "Forced Movement"}

--- @return number
function creature:BaseForcedMoveResistance()
	return self.stability
end

--- @return number
function creature:BaseReach()
	return self.reach
end

--- @return number
function creature:BaseWeight()
	return self.weight
end

--- @return number
function creature:Stability()
    return math.tointeger(math.max(0, self:CalculateAttribute("forcedmoveresistance", self:BaseForcedMoveResistance())))
end

--- @return number
function creature:ForcedMoveResistance()
    return self:Stability()
end

--- If the creature can teleport.
--- @return boolean
function creature:CanTeleport()
    local movementSpeeds = self:try_get("movementSpeeds", {})
    if movementSpeeds ~= nil then
        return (movementSpeeds["teleport"] or 0) > 0
    end

    return false
end

creature.stability = 0
creature.reach = 1
creature.range = 0
creature.weight = 1
creature.creatureSize = "1M"

CustomAttribute.RegisterAttribute{id = "creaturesizewhenforcemoved", text = "Size When Force Moved", attributeType = "number", category = "Forced Movement"}

function creature:CreatureSizeWhenBeingForceMoved()
    local token = dmhub.LookupToken(self)
    local size = 3
    if token ~= nil and token.valid then
        size = token.size
    else
        size = self:GetBaseCreatureSizeNumber() or size
    end

    return self:CalculateAttribute("creaturesizewhenforcemoved", size)
end

function creature:GetReach()
    local reach = self:BaseReach()
    local customAttr = CustomAttribute.attributeInfoByLookupSymbol.reach
    if customAttr ~= nil then
        reach = reach + self:GetCustomAttribute(customAttr)
    end

    return reach
end

function creature:BonusRange()
    local customAttr = CustomAttribute.attributeInfoByLookupSymbol.bonusrange
    if customAttr ~= nil then
        return self:GetCustomAttribute(customAttr)
    end

    return 0
end

creature.RegisterSymbol{
    symbol = "reach",
    lookup = function(c)
        return c:GetReach()
    end,
    help = {
        name = "Reach",
        type = "number",
        desc = "The reach of the creature.",
        seealso = {},
    }
}

CustomAttribute.RegisterAttribute{id = "weight", text = "Weight", attributeType = "number", category = "Basic Attributes"}

creature.RegisterSymbol{
    symbol = "weight",
    lookup = function(c)
        return c:GetWeight()
    end,
    help = {
        name = "Weight",
        type = "number",
        desc = "The weight of the creature.",
        seealso = {},
    }
}

function creature:GetWeight()
    return self:CalculateAttribute("weight", self:BaseWeight())
end

function creature:GrappleTN()
    return 7 + self:CalculateAttribute("mgt", 0)
end

function creature:BloodiedThreshold()
    return math.floor(self:MaxHitpoints()/2)
end

CustomAttribute.RegisterAttribute{id = "recoveryvalue", text = "Recovery Value", attributeType = "number", category = "Basic Attributes"}

creature.RegisterSymbol{
    symbol = "recoveryvalue",
    lookup = function(c)
        return c:RecoveryAmount()
    end,
    help = {
        name = "Recovery Value",
        type = "number",
        desc = "The Recovery Value of the creature.",
        seealso = {},
    }
}

creature.RegisterSymbol{
    symbol = "stamina",
    lookup = function(c)
        return c:CurrentHitpoints()
    end,
    help = {
        name = "Stamina",
        type = "number",
        desc = "The Stamina of the creature.",
        seealso = {"Maximum Stamina", "Recovery Value"},
    }
}

creature.RegisterSymbol{
    symbol = "maximumstamina",
    lookup = function(c)
        return c:MaxHitpoints()
    end,
    help = {
        name = "Maximum Stamina",
        type = "number",
        desc = "The Maximum Stamina of the creature.",
        seealso = {"Stamina", "Recovery Value"},
    }
}

function creature:RecoveryAmount()
	local baseValue = math.floor(self:MaxHitpoints()/3)
	return self:CalculateAttribute("recoveryvalue", baseValue)
end


function creature.ResistanceDescription(self)
	local entries = self:CalculateResistances()
	if #entries <= 0 then
		return ""
	end

    local items = {}

	--handle damage reduction portion.
	local damageReductionEntries = {}
	for _,entry in ipairs(entries) do
		if entry.apply == 'Damage Reduction' then
            local keywordDescription = "Damage"

            if entry:try_get("keywords") ~= nil then
                for keyword,_ in pairs(entry.keywords) do
                    if keywordDescription == "Damage" then
                        keywordDescription = keyword
                    else
                        keywordDescription = keywordDescription .. "/" .. keyword
                    end
                end
            end

            local damageTypeDescription = ""

            if entry:has_key("damageType") and string.lower(entry.damageType) ~= "all" then
                damageTypeDescription = entry.damageType .. " "
            end

            --upper case the first character of damage type description.
            if damageTypeDescription ~= "" then
                damageTypeDescription = string.upper(string.sub(damageTypeDescription, 1, 1)) .. string.sub(damageTypeDescription, 2)
            end

            items[#items+1] = string.format("%s%s %s %d.", damageTypeDescription, keywordDescription, cond(entry:try_get("dr", 0) < 0, "vulnerability", "immunity"), math.abs(entry:try_get("dr", 0)))
		end
	end

    return string.join(items, "\n")
end

function creature:AbilityCategoryPlural(abilityCategory)
    return abilityCategory
end

function character:AbilityCategoryPlural(abilityCategory)
	if abilityCategory == "Basic Attack" then
		return "Free Strikes"
	end

	if abilityCategory == "Ability" then
		return "Abilities"
	end

    local classes = self:GetClassesAndSubClasses()
    if #classes > 0 then
        local entry = classes[1].class:try_get("abilityCategoryNames", {})[abilityCategory]
        if entry ~= nil then
            return entry.plural or abilityCategory
        end
    end

    return abilityCategory
end

function creature:GetHeroicResourceName()
    return "Heroic Resource"
end

function character:GetHeroicResourceName()
    local classes = self:GetClassesAndSubClasses()
    if #classes > 0 then
        return classes[1].class.heroicResourceName
    end

    return "Heroic Resource"
end

--We modify the important GetActivatedAbilities function.
--options:
--  excludeGlobal: no global modifiers.
--  bindCaster: make sure the abilities all have _tmp_boundCaster set so they can resolve who their caster is.
--  allLoadouts: get abilities from all loadouts, not just the equipped loadout.
--  characterSheet: is getting for display on character sheets.
--
--An important property is that innate abilities are not clones unless bindCaster is true. This allows the character sheet
--and other parts of the app to modify the innate abilities to update the creature.
function creature:GetActivatedAbilities(options)
	options = options or {}
	local result = {}

	local boundCaster = self
	if not options.bindCaster then
		boundCaster = nil
	end

	self:FillMonsterActivatedAbilities(options, result)

    local kit = self:Kit()
    if kit ~= nil then
		for _,a in ipairs(kit:SignatureAbilities()) do
			local ability = a
			if options.bindCaster and (not options.characterSheet) then
				ability = ability:MakeTemporaryClone()
				ability._tmp_boundCaster = self
			end
			result[#result+1] = ability
		end
    end

	for i,a in ipairs(self.innateActivatedAbilities) do
		local ability = a
		if options.bindCaster and (not options.characterSheet) then
            ability = ability:MakeTemporaryClone()
			ability._tmp_boundCaster = self
		end
		result[#result+1] = ability
	end

	local modifiers = self:GetActiveModifiers()

	for i,mod in ipairs(modifiers) do
		if (not mod._global) or (not options.excludeGlobal) then
			mod.mod:FillActivatedAbilities(mod, self, result)
		end
	end


	if self:has_key("ongoingEffects") then
		for i,cond in ipairs(self.ongoingEffects) do
			if cond:try_get('endAbility') ~= nil and not cond:Expired() then
				result[#result+1] = cond.endAbility
			end
		end
	end

	for i,aura in ipairs(self:try_get("auras", {})) do
		aura:FillActivatedAbilities(self, result)
	end

	--lookup any objects existing with affinity to our character (e.g. auras we control) and see if they provide us with abilities.
	local charid = dmhub.LookupTokenId(self)
	if charid ~= nil then
		local objects = game.GetObjectsWithAffinityToCharacter(charid)
		for _,obj in ipairs(objects) do
			for _,entry in ipairs(obj.attachedRulesObjects) do
				entry:FillActivatedAbilities(self, result)
			end
		end
	end

	local gearTable = dmhub.GetTable('tbl_Gear')
	for k,info in pairs(self:try_get('inventory', {})) do
		local itemInfo = gearTable[k]
		if itemInfo ~= nil and itemInfo:has_key("consumable") then
            ability = itemInfo.consumable:MakeTemporaryClone()
			ability._tmp_boundCaster = self
			result[#result+1] = ability
		end
	end

	local hasMeleeAndRanged = false

	--split out into melee and ranged abilities.
    if not options.characterSheet then
        for i=1,#result do
            local ability = result[i]:BifurcateIntoMeleeAndRanged(self)
            result[i] = ability
        end
    end
	
	local reach = self:GetReach()

	if reach > 1 and (not options.characterSheet) then
		for i=1,#result do
			local ability = result[i]
			if ability:HasKeyword("Melee") then
				ability = ability:MakeTemporaryClone()
				result[i] = ability
				local range = ability:GetRange(self)
				if reach > range then
					ability.range = reach
				end
			end
		end
	end

	--let our modifiers modify the abilities we are returning.
	if not options.characterSheet then
		local j = 1
		local nitems = #result
		for i=1,#result do
			local ability = result[i]
			for i,mod in ipairs(modifiers) do
				ability = mod.mod:ModifyAbility(mod, self, ability)
				if ability == nil then
					break
				end

                local variations = ability:GetVariations()
                if variations ~= nil then
                    for i=1,#variations do
                        mod.mod:ModifyAbility(mod, self, variations[i])
                    end
                end
			end

			if ability ~= nil then
				result[j] = ability
				j = j+1
			end
		end

		while j <= nitems do
			result[j] = nil
			j = j+1
		end
	end

	return result
end

function character:GetClass()
	local classes = self:try_get("classes")
    if classes == nil or #classes == 0 then
        return nil
    end


	local classesTable = dmhub.GetTable(Class.tableName)
    return classesTable[classes[1].classid]

end

function character:BaseHitpoints()
    local c = self:GetClass()
    if c == nil then
        return 1
    end

    return dmhub.EvalGoblinScriptDeterministic(c.hitpointsCalculation, self:LookupSymbol{}, 1, "Base hitpoints")
end

function creature:RollConditionSave(condid, abilityOptions)

	abilityOptions = abilityOptions or {}
	abilityOptions.symbols = abilityOptions.symbols or {}

	local entry = self:try_get("inflictedConditions", {})[condid]
	if entry == nil or entry.duration == "eoe" then
		return
	end

	local token = dmhub.LookupToken(self)
	if token == nil then
		return
	end

	if entry.duration == "eot" then
		token:ModifyProperties{
			description = "Purge condition",
			execute = function()
				self:InflictCondition(condid, {purge = true})
			end,
		}
		return
	end

	local conditionTable = dmhub.GetTable(CharacterCondition.tableName)
	local conditionInfo = conditionTable[condid]
	local abilityTemplate = MCDMUtils.GetStandardAbility("Save")
	local ability = abilityTemplate:MakeTemporaryClone()
	MCDMUtils.DeepReplace(ability, "<<condition>>", conditionInfo.name)

    --this is from when saves could be associated with an ability.
	--MCDMUtils.DeepReplace(ability, "<<attribute>>", entry.duration)

	ability:Cast(token, {{token = token}}, abilityOptions)
end

creature.RegisterSymbol{
    symbol = "lastdamagedby",
    lookup = function(c)
		return function(other)
			local result = nil
			if type(other) == "string" then
				result = c:LastDamagedBy(other)
			end

			return result or 0
		end
    end,
    help = {
        name = "LastDamagedBy",
        type = "function",
        desc = "The numeric timestamp when this creature last damaged you.",
        seealso = {},
    }
}

creature.RegisterSymbol{
    symbol = "endturntimestamp",
    lookup = function(c)
		return c:GetEndTurnTimestamp()
    end,
    help = {
        name = "End Turn Timestamp",
        type = "number",
        desc = "The numeric timestamp when this creature ended its last turn.",
        seealso = {},
    }
}

--override default InflictCondition to include MCDM condition rules.

--- Inflict a condition on a creature. (Or purge the condition using the 'purge' argument.)
--- @param conditionid string
--- @param args {duration:string, force: nil|boolean, purge: nil|boolean, casterInfo:nil|{tokenid:string}}
function creature:InflictCondition(conditionid, args)
    local conditionsTable = dmhub.GetTable(CharacterCondition.tableName)
	local conditionInfo = conditionsTable[conditionid]

	local inflictedConditions = self:get_or_add("inflictedConditions", {})

	local entry = inflictedConditions[conditionid] or {}
	inflictedConditions[conditionid] = entry

	if entry.duration ~= "eoe" or args.force then
		entry.stacks = 1
		entry.duration = args.duration
		entry.casterInfo = args.casterInfo
	end

    print("EXECUTE RULE:: INFLICT PURGE CONDITION = ", args.purge or false, " CONDITION ID = ", conditionid, "table =", inflictedConditions)

	--the condition gets purged if we are purging it.
	if args.purge then
		inflictedConditions[conditionid] = nil
        print("EXECUTE RULE:: PURGED TO", inflictedConditions)
	end


	self.inflictedConditions = inflictedConditions
end

--- Get the duration the given condition will last on the creature, or nil if it doesn't have this condition.
--- @param conditionid string
--- @return nil|string
function creature:ConditionDuration(conditionid)
	local inflictedConditions = self:try_get("inflictedConditions", {})
	local entry = inflictedConditions[conditionid]
	if entry == nil then
		return nil
	end

	return entry.duration

end

creature.RegisterSymbol{
	symbol = "conditionstacks",
	lookup = function(c)
		return function(condName)
			local inflictedConditions = c:try_get("inflictedConditions", {})
			local conditionsTable = dmhub.GetTable(CharacterCondition.tableName)
			for k,v in pairs(conditionsTable) do
				if not v:try_get("hidden", false) and string.lower(v.name) == string.lower(condName) then
					local entry = inflictedConditions[k]
					if entry ~= nil then
						return entry.stacks
					end

				end
			end

			local ongoingEffectsTable = dmhub.GetTable("characterOngoingEffects") or {}

			local result = 0

			--try looking at ongoing effects.
			local ongoingEffects = c:ActiveOngoingEffects()
			for _,effect in ipairs(ongoingEffects) do
				local effectInfo = ongoingEffectsTable[effect.ongoingEffectid]
				if effectInfo ~= nil and string.lower(effectInfo.name) == string.lower(condName) then
					result = result + effect.stacks
				end
			end

			return result
		end
	end,

	help = {
		name = "Condition Stacks",
		type = "number",
		desc = "The number of stacks of the given condition the creature has.",
		seealso = {},
	},
}

function creature:PowerRollBonus()
	return 0
end

creature.RegisterSymbol{
	symbol = "powerrollbonus",
	lookup = function(c)
		return c:PowerRollBonus()
	end,

	help = {
		name = "Power Roll Bonus",
		type = "number",
		desc = "The bonus that monsters get to their power rolls. Zero for heroes.",
		seealso = {},
	},
}

function creature:GetModifiersForPowerRoll(roll, rollType, options)
	local result = {}
    local modifiers = self:GetActiveModifiers()
	for _,mod in ipairs(modifiers) do
		local m = mod.mod:DescribeModifyPowerRoll(mod, self, rollType, options)
		if m ~= nil then
			m.hint = m.modifier:HintModifyPowerRolls(mod, self, rollType, options)
			if m.hint ~= nil then
				result[#result+1] = m
			end
		end
	end

	return result
end

function creature:ShowCharacteristicRollDialog(attrid)

	local attrInfo = creature.attributesInfo[attrid]

	local rollProperties = RollPropertiesPowerTable.new{
		tiers = {
			"Tier 1 Result",
			"Tier 2 Result",
			"Tier 3 Result",
		}
	}

	local rollType = "test_power_roll"
	local roll = string.format("2d10 + %d", self:GetAttribute(attrid):Modifier())
	local modifiers = self:GetModifiersForPowerRoll(roll, rollType, {attribute = attrid})

	GameHud.instance.rollDialog.data.ShowDialog{
		title = string.format("%s Test", attrInfo.description),
		description = string.format("%s Test", attrInfo.description),
		creature = self,

		type = rollType,
		roll = roll,
		modifiers = modifiers,

		rollProperties = rollProperties,
        PopulateCustom = ActivatedAbilityPowerRollBehavior.GetPowerTablePopulateCustom(rollProperties),

		completeRoll = function(rollInfo)
		end,

		cancelRoll = function()
		end,
	}
end

--hitpoints handling overridden. We include handling of minions.
local g_creatureCurrentHitpoints = creature.CurrentHitpoints
function creature.CurrentHitpoints(self)

	if (not mod.unloaded) and self.minion and self:has_key("_tmp_minionSquad") then
		local damage_taken = self._tmp_minionSquad.damage_taken or 0
		local maxhp = self:MaxHitpoints()
		return maxhp - damage_taken
	end

	return g_creatureCurrentHitpoints(self)
end

local g_creatureSetCurrentHitpoints = creature.SetCurrentHitpoints
function creature.SetCurrentHitpoints(self, amount, note)
	if (not mod.unloaded) and self.minion and self:has_key("_tmp_minionSquad") then
		local token = dmhub.LookupToken(self)
		if token ~= nil then
			local damage_taken_seq = self._tmp_minionSquad.damage_taken_seq + 1
			local damage_taken = self:MaxHitpoints() - amount
			if damage_taken < 0 then
				damage_taken = 0
			end

			local tokenCount = 0
			for _,tok in ipairs(self._tmp_minionSquad.tokens) do
				if tok ~= nil and tok.valid then
					tokenCount = tokenCount + 1
				end
			end

            self._tmp_minionSquad.damage_taken = damage_taken

			for _,tok in ipairs(self._tmp_minionSquad.tokens) do
				if tok ~= nil and tok.valid then
					tok:ModifyProperties{
						description = note,
						combine = true,
						undoable = false,
						execute = function()
							tok.properties.damage_taken = damage_taken
							tok.properties.damage_taken_seq = damage_taken_seq
							tok.properties.damage_taken_minion_count = tokenCount
						end,
					}
				end
			end

		end

		return
	end

	g_creatureSetCurrentHitpoints(self, amount, note)
end

local g_creatureSetTemporaryHitpoints = creature.SetTemporaryHitpoints
function creature.SetTemporaryHitpoints(self, amount, note, options)

	g_creatureSetTemporaryHitpoints(self, amount, note, options)

	if mod.unloaded then
		return
	end
end

--removes temporary hitpoints, returning the overflow amount.
local g_creatureRemoveTemporaryHitpoints = creature.RemoveTemporaryHitpoints
function creature:RemoveTemporaryHitpoints(amount, note)
	return g_creatureRemoveTemporaryHitpoints(self, amount, note)
end

local g_creatureTemporaryHitpoints = creature.TemporaryHitpoints
function creature.TemporaryHitpoints(self)
	return g_creatureTemporaryHitpoints(self)
end

local g_creatureTemporaryHitpointsStr = creature.TemporaryHitpointsStr
function creature.TemporaryHitpointsStr(self)
	return g_creatureTemporaryHitpointsStr(self)
end

function creature.TakeDamage(self, amount, note, info)
    info = info or {}
	if type(amount) == 'string' then
		amount = dmhub.RollInstant(amount)
	end

	if type(amount) ~= 'number' then
		return
	end

	if amount <= 0 and note == nil then
		return
	end

	if amount < 0 then
		amount = 0
	end

	if self.damage_entry.accumulate then
		self.damage_entry.damage = (self.damage_entry.damage or 0) + amount
	else
		self.damage_entry = {
			id = dmhub.GenerateGuid(),
			damage = amount,
		}
	end

	if self.minion then
		self:SetCurrentHitpoints(self:CurrentHitpoints() - amount, note)

		local eventArg = shallow_copy_table(info)
		eventArg.damage = amount
		eventArg.damagetype = eventArg.damagetype or "none"
		self:DispatchEvent("losehitpoints", eventArg)

		return
	end

	local isDyingAtStart = self:IsDeadOrDying()

	local original_amount = amount

	local instadeath = false

	if amount > 0 then
		if self:IsUnconsciousButStable() then
			self:ResetDeathSavingThrowStatus()
		elseif isDyingAtStart then
			if amount >= self:MaxHitpoints() then
				self:AddDeathSavingThrowFailure(3)
			else
				self:AddDeathSavingThrowFailure()
			end
		end

		amount = self:RemoveTemporaryHitpoints(amount, note or string.format("%d Damage", original_amount))

		if amount >= self:MaxHitpoints() + self:CurrentHitpoints() then
			instadeath = true
		end
	end

	self.damage_taken = self.damage_taken + amount
	local damage_taken_maybe_negative = self.damage_taken
	self:CheckBelowZeroHitpoints()

	local eventArg = shallow_copy_table(info)
	eventArg.damage = amount
	eventArg.damagetype = eventArg.damagetype or "none"
    eventArg.hasattacker = eventArg.attacker ~= nil
    eventArg.surges = info.surges or 0
	self:DispatchEvent("losehitpoints", eventArg)

    if eventArg.attacker ~= nil then
        local attacker = eventArg.attacker
        local args = {
            target = self,
            damage = amount,
            damagetype = eventArg.damagetype,
            keywords = eventArg.keywords,
            surges = eventArg.surges,
        }
        attacker:DispatchEvent("dealdamage", args)
    end


	--if this caused us to start dying we should set dying status.
	if (not isDyingAtStart) and self:IsDeadOrDying() then

		if self:try_get("transformInfo") and self.transformInfo.endWhenZeroHitpoints then
			self.damage_taken = damage_taken_maybe_negative --set damage_taken to possibly be negative to let it carry over when ending an effect.
			self:RemoveOngoingEffect(self.transformInfo.ongoingEffect)
			self:Invalidate()
			self:CheckBelowZeroHitpoints()
		end

		if self:IsDeadOrDying() then

            self:RemoveAurasOnDeath()

			if self:IsDead() then
				self:ResetDeathSavingThrowStatus()		
			end

			self:DispatchEvent("zerohitpoints", eventArg)

			eventArg.victim = self
			eventArg.hasattacker = eventArg.attacker ~= nil

			if eventArg.attacker ~= nil then
                --NOTE: We have to TriggerEvent here not DispatchEvent because
                --DispatchEvent does not currently have support for dispatching
                --creature objects and other self-referential objects.
				eventArg.attacker:TriggerEvent("kill", eventArg)
			end

            eventArg.victim = nil
            eventArg.attacker = nil
            eventArg.hasattacker = nil

			for _,tok in ipairs(dmhub.allTokens) do
				if tok.properties ~= self then
					tok.properties:DispatchEvent("creaturedeath", eventArg)
				end
			end

			self:CancelConcentration()

			if instadeath then
				self:AddDeathSavingThrowFailure(3)
			end
		end
	end

	local attackerid = nil
	if info.attacker ~= nil then
		local attackerTok = dmhub.LookupToken(info.attacker)
		if attackerTok ~= nil then
			attackerid = attackerTok.charid
		end
	end

	local statHistory = self:GetStatHistory("hitpoints")
	self:GetStatHistory("hitpoints"):Append{
		attackerid = attackerid,
		note = note or string.format("%d Damage", original_amount),
		set = self:CurrentHitpoints(),
		disposition = "bad",
	}
end

function creature.Heal(self, amount, note)
	if type(amount) == 'string' then
		amount = dmhub.RollInstant(amount)
	end

	if type(amount) ~= 'number' then
		return
	end

	if amount <= 0 then
		return
	end

	if self.minion then
		self:SetCurrentHitpoints(math.min(self:MaxHitpoints(), self:CurrentHitpoints() + amount), note)
		return
	end

	self:CheckBelowZeroHitpoints()

	self.damage_taken = self.damage_taken - amount
	if self.damage_taken < 0 then
		self.damage_taken = 0
	end

	self:ResetDeathSavingThrowStatus()

	self:GetStatHistory("hitpoints"):Append{
		note = note or string.format("%d Healing", amount),
		set = self:CurrentHitpoints(),
		disposition = "good",
	}

	self.damage_entry = {
		id = dmhub.GenerateGuid(),
		heal = amount,
	}


	self:DispatchEvent("regainhitpoints", {})
end

--this is called by the engine to tell the 'cost' of moving through
--another token. We can return "difficult" to signal difficult terrain.
--return true to mean we can move through with no cost. false means
--we cannot move through.
function creature:CostToMoveThroughToken(otherToken)
    local ourToken = dmhub.LookupToken(self)
    if ourToken ~= nil and (not otherToken:IsFriend(ourToken)) then
        --moving through an enemy is regarded as difficult terrain.
        return "difficult"
    end

    --moving through a friend is fine.
    return true
end

--- @param token CharacterToken
--- @param info {type: string, amount: number, instances: number, aura: AuraInstance}
function creature:AuraDamage(token, info)
    token:ModifyProperties{
        description = info.aura.name,
        execute = function()

			self.damage_entry = {
				id = dmhub.GenerateGuid(),
				damage = 0,
				accumulate = true,
			}

            for i=1,info.instances do
                self:InflictDamageInstance(info.amount, info.type, {}, info.aura.name, {})
            end

            self.damage_entry.accumulate = nil
        end,
    }
end