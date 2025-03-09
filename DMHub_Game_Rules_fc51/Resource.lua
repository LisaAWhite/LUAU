local mod = dmhub.GetModLoading()

--this implements Resource rules. Note that part of this file includes adding functionality to creatures
--to control how they manage their resources.

--- @class CharacterResource
CharacterResource = RegisterGameType("CharacterResource")

local g_sharedGlobalResourceDoc = "globalResources"

function creature:GetResourceTable(refreshType)
	if refreshType == "global" then
		local doc = mod:GetDocumentSnapshot(g_sharedGlobalResourceDoc)
		return doc.data, doc
	else
		return self:get_or_add('resources', {})
	end
end

function CharacterResource.CreateNew()
	return CharacterResource.new{
		name = 'New Resource',
	}
end

CharacterResource.name = "none"
CharacterResource.resourceToRefreshType = {}

CharacterResource.tableName = "characterResources"

CharacterResource.nameToId = {}

CharacterResource.unbounded = 0

--maps a lower level resourceid to a higher level resourceid
CharacterResource.levelingMap = {}

CharacterResource.spellSlotIds = {}

--if true, this is a 'reaction' action that allows abilities to have reaction conditions.
CharacterResource.isreaction = false

CharacterResource.hasLargeDisplay = false
CharacterResource.largeIconid = "none"

CharacterResource.combatid = ""
CharacterResource.refreshid = ''
CharacterResource.grouping = "Class Specific"
CharacterResource.groupingOptions = {
    {
        id = "Class Specific",
        text = "General",
    },
    {
        id = "Actions",
        text = "Actions",
    },
    {
        id = "Hit Dice",
        text = "Hit Dice",
    },
    {
        id = "Spell Slots",
        text = "Spell Slots",
    },
    {
        id = "Hidden",
        text = "Hidden",
    },
}


CharacterResource.iconid = ''
CharacterResource.useQuantity = false
CharacterResource.largeQuantity = false
CharacterResource.textColor = "light"
CharacterResource.usageLimit = 'long'
CharacterResource.diceType = 'none'
CharacterResource.spellSlot = 'none'
CharacterResource.levelsFrom = 'none'
CharacterResource.mayBeNegative = false
CharacterResource.legendaryAction = 'none'
CharacterResource.clearOutsideOfCombat = false
CharacterResource.display = {
	normal = {
		hueshift = 0,
		saturation = 1,
		brightness = 1,
	},
	expended = {
		hueshift = 0,
		saturation = 0.5,
		brightness = 0.5,
	},
	highlight = {
		hueshift = 1,
		saturation = 1.0,
		brightness = 1.5,
	},
}

CharacterResource.displayIndexes = {"normal", "expended", "highlight"}
CharacterResource.displayIds = {}
for index,displayType in ipairs(CharacterResource.displayIndexes) do
	CharacterResource.displayIds[displayType] = index
end

function CharacterResource:GetDisplayStyle(id)
	if self:has_key("_tmp_styles") == false then
		self._tmp_styles = self:CreateStyles()
	end
	return self._tmp_styles[self.displayIds[id or "normal"]]
end

function CharacterResource.BaseOf(id, other)
	if id == other then
		return true
	end

	local count = 0
	while id ~= nil do
		if id == other then
			return true
		end
		id = CharacterResource.levelingMap[id]
		count = count+1
	end
end

function CharacterResource.Related(id, other)
	return CharacterResource.BaseOf(id, other) or CharacterResource.BaseOf(other, id)
end

--given a resource id, returns a list starting with this id and then successor ids in the leveling progression.
function CharacterResource.GetLevelProgression(id)
	local resourceTable = dmhub.GetTable("characterResources") or {}
	local result = {}
	local count = 0
	while id ~= nil and count < 100 and resourceTable[id] ~= nil do
		result[#result+1] = id
		id = CharacterResource.levelingMap[id]
		count = count+1
	end

	return result
end

function CharacterResource:GetSpellSlot()
	if self.spellSlot == 'none' then
		return nil
	end

	return tonumber(self.spellSlot)
end

function CharacterResource:CreateStyles()
	local result = {}
	for _,k in ipairs(self.displayIndexes) do
		local display = self.display[k]
		
		local style = dmhub.DeepCopy(display)
		if style.bgcolor == nil then
			style.bgcolor = 'white'
		end

		local bgimage = style.bgimage or self.iconid
		style.bgimage = nil --save until after initialization to make sure readable is set properly.
		style.selectors = {k}
		result[#result+1] = gui.Style(style)

		result[#result].bgimageReadable = true --resources like to be readable so we can use alpha testing on them.

		result[#result].bgimage = bgimage
	end
	return result
end

function CharacterResource:TooltipText(quantity, numExpended)
	local availability
	if quantity == 1 then
		availability = cond(numExpended == 0, "available", "expended")
	else
		availability = string.format("%d/%d", quantity-numExpended, quantity)
	end
	return string.format("%s: %s\nRefreshes %s", self.name, availability, self:RefreshDescription())
	
end

function CharacterResource:GetImage(displayMode)
	return self.display[displayMode].bgimage or self.iconid
end

function CharacterResource.GetDropdownOptions(grouping, includeNone)
	local result = {}
	local resourceTable = dmhub.GetTable("characterResources") or {}
	for k,resource in pairs(resourceTable) do
		if (not resource:try_get("hidden", false)) and (grouping == nil or resource.grouping == grouping )then
			result[#result+1] = {
				id = k,
				text = resource.name,
			}
		end
	end

	table.sort(result, function(a,b) return a.text < b.text end)

	if includeNone then
		table.insert(result, 1, {
			id = 'none',
			text = 'None',
		})
	end

	
	return result
end

function CharacterResource.GetActionOptions()
	return CharacterResource.GetDropdownOptions("Actions", true)
end


CharacterResource.displayModeOptions ={
	{
		id = 'normal',
		text = 'Normal',
	},
	{
		id = 'expended',
		text = 'Expended',
	},
	{
		id = 'highlight',
		text = 'Highlight',
	},
}

CharacterResource.diceTypeOptions ={
	{
		id = 'none',
		text = 'None',
	},
	{
		id = '4',
		text = 'd4',
	},
	{
		id = '6',
		text = 'd6',
	},
	{
		id = '8',
		text = 'd8',
	},
	{
		id = '10',
		text = 'd10',
	},
	{
		id = '12',
		text = 'd12',
	},
}

CharacterResource.diceTypeOptionsNoNil = {}
for i,entry in ipairs(CharacterResource.diceTypeOptions) do
	if i ~= 1 then
		CharacterResource.diceTypeOptionsNoNil[#CharacterResource.diceTypeOptionsNoNil+1] = entry
	end
end

CharacterResource.spellSlotOptions ={
	{
		id = 'none',
		text = 'None',
	},
	{
		id = '1',
		text = 'One',
	},
	{
		id = '2',
		text = 'Two',
	},
	{
		id = '3',
		text = 'Three',
	},
	{
		id = '4',
		text = 'Four',
	},
	{
		id = '5',
		text = 'Five',
	},
	{
		id = '6',
		text = 'Six',
	},
	{
		id = '7',
		text = 'Seven',
	},
	{
		id = '8',
		text = 'Eight',
	},
	{
		id = '9',
		text = 'Nine',
	},
}

function CharacterResource.RegisterRefreshOptions(options)
	CharacterResource.usageLimitOptions = options

	CharacterResource.usageLimitOptionsWithPerSpell = {}

	for _,option in ipairs(CharacterResource.usageLimitOptions) do
		CharacterResource.usageLimitOptionsWithPerSpell[#CharacterResource.usageLimitOptionsWithPerSpell+1] = option
	end

	CharacterResource.usageLimitOptionsWithPerSpell[#CharacterResource.usageLimitOptionsWithPerSpell+1] =
	{
		id = 'perspell',
		text = 'Until Effect Expires',
		refreshDescription = 'until effect ends',
	}

	CharacterResource.usageLimitMap = {}
	for i,option in ipairs(CharacterResource.usageLimitOptions) do
		CharacterResource.usageLimitMap[option.id] = option
	end
end

--different types of usage limit options as presentable in a dropdown.
CharacterResource.RegisterRefreshOptions{
	{
		id = 'none',
		text = 'No usage limit',
		refreshDescription = 'always',
	},
	{
		id = 'round',
		text = 'Per Round',
		refreshDescription = 'each round',
	},
	{
		id = 'encounter',
		text = 'Per Encounter',
		refreshDescription = 'each encounter',
	},
	{
		id = 'short',
		text = 'Per Short Rest',
		refreshDescription = 'on short rest',
	},
	{
		id = 'long',
		text = 'Per Long Rest',
		refreshDescription = 'on long rest',
	},
	{
		id = 'day',
		text = 'Per Day',
		refreshDescription = 'daily',
	},
	{
		id = 'never',
		text = 'Manual Refresh',
		refreshDescription = 'manually',
	},
	{
		id = 'unbounded',
		text = 'Unbounded',
		refreshDescription = 'unbounded',
	},
	{
		id = 'global',
		text = 'Global/Shared',
		refreshDescription = 'global',
	},
}

function CharacterResource:RefreshDescription()
	return CharacterResource.usageLimitMap[self.usageLimit].refreshDescription
end

function CharacterResource:AllowResourceBelowZero(caster)
    if self.usageLimit == "unbounded" and self.mayBeNegative then
        return 100
    end
    return 0
end

function CharacterResource:ClampQuantity(quantity)
    if quantity > 999 then
        quantity = 999
    end
    if self.mayBeNegative then
        return quantity
    end

    return math.max(0, quantity)
end

creature.shortRestId = 'none'
creature.longRestId = 'none'

function creature:GetResourceRefreshId(refreshType)

	if refreshType == 'round' then
		if dmhub.initiativeQueue then
			return dmhub.initiativeQueue:GetRoundIdForToken(dmhub.LookupToken(self))
		else
			return dmhub.GenerateGuid()
		end
	elseif refreshType == 'short' then
		return self.shortRestId
	elseif refreshType == 'long' then
		return self.longRestId
	elseif refreshType == 'encounter' then
		if dmhub.initiativeQueue == nil then
			return "none"
		end

		return dmhub.initiativeQueue.guid
	elseif refreshType == 'never' then
		return "manual"
	end

	return ''
end

function creature:GetResourceUsage(key, refreshType)
	if refreshType == 'none' then
		return 0
	end

	local resourceTable = self:GetResourceTable(refreshType)
	local resource = resourceTable[key]
	if resource == nil then
		return 0
	end

	local refreshid = self:GetResourceRefreshId(refreshType)
	if resource.refreshid ~= refreshid then
		return 0
	end

	return resource.used
end

--can afford the exact resource provided (not a leveled version).
function creature:CanAffordExactResource(key, refreshType, quantity)
	if quantity == nil then
		quantity = 1
	end

	return (self:GetResources()[key] or 0) - self:GetResourceUsage(key, refreshType) < quantity
end

--which resource do we have? tries leveling up the resource.
function creature:ResourceToConsume(key)
	if key == nil or key == "none" then
		return nil
	end
	local resourceTable = dmhub.GetTable("characterResources")
	if resourceTable[key] == nil then
		return nil
	end

	local refreshType = resourceTable[key].usageLimit
	if refreshType == 'none' then
		return key
	end

	local resourcesAvailable = self:GetResources()

	if CharacterResource.levelingMap[key] ~= nil then
		--see if we can find a leveled version to spend instead.
		local count = 0
		local keyid = key
		while count < 100 and keyid ~= nil and (resourcesAvailable[keyid] or 0) == 0 do
			keyid = CharacterResource.levelingMap[keyid]
			count = count+1
		end

		if keyid ~= nil then
			key = keyid
		end
	end

	return key
end

--records resource usage for the resource with the given key, which is an arbitrary string
--and the given refreshType, which is one of the standard refresh types.
function creature:ConsumeResource(key, refreshType, quantity, note)
	if refreshType == 'none' then
		return 0
	end

	if CharacterResource.levelingMap[key] ~= nil then
		--see if we can find a leveled version to spend instead.
		local count = 0
		local keyid = key
		while count < 100 and keyid ~= nil and (not creature:CanAffordExactResource(keyid, refreshType, quantity)) do
			keyid = CharacterResource.levelingMap[keyid]
			count = count+1
		end

		if keyid ~= nil then
			key = keyid
		end
		
	end

	local resourceTable = self:GetResourceTable(refreshType)

	local globalDoc = nil

	if refreshType == "global" then
		globalDoc = mod:GetDocumentSnapshot(g_sharedGlobalResourceDoc)
		globalDoc:BeginChange()
	end

	if resourceTable[key] == nil then
		resourceTable[key] = CharacterResource.new{
			refreshid = '',
			used = 0,
		}
	end

	if quantity == nil then
		quantity = 1
	end

	local resource = resourceTable[key]


	if refreshType == "unbounded" or refreshType == "global" then
        local before = resource.unbounded

        if resource.clearOutsideOfCombat then
            local q = dmhub.initiativeQueue
            if q == nil or q.hidden then
                --this is totally irrelevant outside of combat.
                return 0
            end

            if resource.combatid ~= q.guid then
                before = 0
            end

            resource.combatid = q.guid
        end

        local resourceInfo = dmhub.GetTable(CharacterResource.tableName)[key]
        if resourceInfo ~= nil then
		    resource.unbounded = resourceInfo:ClampQuantity(before - quantity)
        end
        local used = before - resource.unbounded
        quantity = used
        if quantity <= 0 then
            return 0
        end
	else
		local refreshid = self:GetResourceRefreshId(refreshType)

		if resource.refreshid ~= refreshid then
			resource.refreshid = refreshid
			resource.used = 0
		end

		resource.used = resource.used + quantity
	end

	local anim = self:GetOrAddAnimation{
		animType = "consumeResource",
		resources = {},
	}

	anim.resources[key] = (anim.resources[key] or 0) + quantity
    local result = quantity

	local totalResources = self:GetResources()[key] or 0
	local usage = self:GetResourceUsage(key, refreshType)

	local quantity = totalResources
	if refreshType ~= "unbounded" and refreshType ~= "global" then
		quantity = string.format("%d/%d", totalResources - usage, quantity)
	end

	if globalDoc ~= nil then
		globalDoc:CompleteChange("Consume Resource")
	end

	self:GetStatHistory(key):Append{
		set = quantity,
		note = note or "Manually Set",
		refreshid = self:GetResourceRefreshId(refreshType),
	}

    return result
end

function creature:RefreshResource(key, refreshType, quantity, note)
	if refreshType == 'none' then
		return 0
	end

	local animQuantity = 0

	local resourceTable, globalDoc = self:GetResourceTable(refreshType)

	local resourceEntry = resourceTable[key]

    local resource = dmhub.GetTable(CharacterResource.tableName)[key]

	if refreshType == "global" then

        local before = 0

        local combatid = nil
        
        if resourceEntry ~= nil then
            before = resourceEntry.unbounded
        end

        if resource.clearOutsideOfCombat then
            local q = dmhub.initiativeQueue
            if q == nil or q.hidden then
                --this is totally irrelevant outside of combat.
                return 0
            end

            if resourceEntry ~= nil and resourceEntry.combatid ~= q.guid then
                before = 0
            end

            combatid = q.guid
        end


		globalDoc:BeginChange()
		if resourceEntry == nil then
			resourceTable[key] = CharacterResource.new{
				refreshid = '',
				used = 0,
			}
			resourceEntry = resourceTable[key]
		end

		resourceEntry.unbounded = resource:ClampQuantity(before + quantity)
        resourceEntry.combatid = combatid
		globalDoc:CompleteChange("Refresh Resource")

	elseif refreshType == "unbounded" then

		if resourceEntry == nil then
			resourceTable[key] = CharacterResource.new{
				refreshid = '',
				used = 0,
			}
			resourceEntry = resourceTable[key]
		end



        local before = resourceEntry.unbounded

        if resource.clearOutsideOfCombat then
            local q = dmhub.initiativeQueue
            if q == nil or q.hidden then
                --this is totally irrelevant outside of combat.
                return
            end

            if resourceEntry.combatid ~= q.guid then
                before = 0
            end

            resourceEntry.combatid = q.guid
        end

		animQuantity = quantity


		resourceEntry.unbounded = resource:ClampQuantity(before + quantity)
	else

		if resourceEntry == nil then
			return 0
		end

		local refreshid = self:GetResourceRefreshId(refreshType)
		if resourceEntry.refreshid ~= refreshid then
			resourceEntry.refreshid = refreshid
			resourceEntry.used = 0
		elseif resourceEntry.used > 0 then
			if quantity and type(quantity) ~= "number" then
				resourceEntry.used = 0
			elseif type(quantity) == "number" then
				animQuantity = math.min(quantity, resourceEntry.used)
				resourceEntry.used = resourceEntry.used - quantity
				if resourceEntry.used < 0 then
					resourceEntry.used = 0
				end
			else
				resourceEntry.used = resourceEntry.used - 1
				animQuantity = 1
			end
		end
	end

	if animQuantity > 0 then
		local anim = self:GetOrAddAnimation{
			animType = "refreshResource",
			resources = {},
		}

		anim.resources[key] = (anim.resources[key] or 0) + animQuantity
	end

	local totalResources = self:GetResources()[key] or 0
	local usage = self:GetResourceUsage(key, refreshType)

	local quantity = totalResources
	if refreshType ~= "unbounded" and refreshType ~= "global" then
		quantity = string.format("%d/%d", totalResources - usage, quantity)
	end

	self:GetStatHistory(key):Append{
		set = quantity,
		note = note or "Manually Set",
		refreshid = self:GetResourceRefreshId(refreshType),
	}

    return animQuantity or 0
end

function creature:AddUnboundedResource(key, quantity, note)
	local resourceTable = self:get_or_add('resources', {})

	if resourceTable[key] == nil then
		resourceTable[key] = CharacterResource.new{
			refreshid = '',
			used = 0,
		}
	end

    local resource = dmhub.GetTable(CharacterResource.tableName)[key]
	
	local resourceEntry = resourceTable[key]
	resourceEntry.unbounded = resource:ClampQuantity(resourceEntry.unbounded + quantity)

	local totalResources = self:GetResources()[key] or 0

	local quantity = totalResources

	self:GetStatHistory(key):Append{
		set = quantity,
		note = note or "Manually Set",
		refreshid = self:GetResourceRefreshId("unbounded"),
	}
end

--the creature will remove any hit dice usage from its resources and return them in a separate table.
function creature:ExtractHitDiceUsage()
	local result = {}
	local resourceTable = self:get_or_add('resources', {})
	for k,entry in pairs(resourceTable) do
		if string.starts_with(k, "hitDie") then
			result[k] = entry
		end
	end

	for k,entry in pairs(result) do
		resourceTable[k] = nil
	end

	return result
end

function creature:RestoreHitDiceUsage(usage)
	self:ExtractHitDiceUsage() --get rid of any current usages we have.

	if usage == nil then
		return
	end

	local resourceTable = self:get_or_add('resources', {})
	for k,entry in pairs(usage) do
		resourceTable[k] = entry
	end
end

dmhub.RegisterEventHandler("refreshTables", function(updated)
	if updated ~= nil and (not updated[CharacterResource.tableName]) then
		return
	end

	CharacterResource.levelingMap = {}
	CharacterResource.nameToId = {}

	local resourceTable = dmhub.GetTable("characterResources") or {}

	for k,resourceInfo in pairs(resourceTable) do
		CharacterResource.nameToId[resourceInfo.name] = k

		if resourceInfo.levelsFrom ~= "none" and resourceTable[resourceInfo.levelsFrom] ~= nil then
			CharacterResource.levelingMap[resourceInfo.levelsFrom] = k
		end

		if resourceInfo.name == "Legendary Action" then
			CharacterResource.legendaryAction = k
		end
	end

	CharacterResource.spellSlotIds = {}
	local firstSpellSlot = CharacterResource.nameToId[GameSystem.firstLevelSpellSlotName]
	if firstSpellSlot ~= nil then
		CharacterResource.spellSlotIds = CharacterResource.GetLevelProgression(firstSpellSlot)
	end
end)

dmhub.RegisterEventHandler("refreshTables", function(updated)
	if updated ~= nil and (not updated[CharacterResource.tableName]) then
		return
	end

	CharacterResource.resourceToRefreshType = {}

	local resourceTable = dmhub.GetTable("characterResources") or {}

	for k,resourceInfo in pairs(resourceTable) do
		resourceInfo._tmp_styles = resourceInfo:CreateStyles()
		CharacterResource.resourceToRefreshType[k] = resourceInfo.usageLimit
	end
end)

--represents all resources a character has, exposed to goblin script.
RegisterGameType("CharacterResourceCollection")

CharacterResourceCollection.helpSymbols = {
	__name = "resources",
}
CharacterResourceCollection.lookupSymbols = {}

local g_resourceLookupRecursionProtection = nil

dmhub.RegisterEventHandler("refreshTables", function()
	CharacterResourceCollection.helpSymbols = {
		__name = "resources",
	}
	CharacterResourceCollection.lookupSymbols = {}

	local resourceTable = dmhub.GetTable("characterResources") or {}

	for k,resourceInfo in pairs(resourceTable) do
		local symbolName = string.gsub(string.lower(resourceInfo.name), "%W", "")
		CharacterResourceCollection.lookupSymbols[symbolName] = function(c)
            if g_resourceLookupRecursionProtection ~= nil and g_resourceLookupRecursionProtection == dmhub.FrameCount() then
                --cannot recurse into resource lookups.
                return
            end

            g_resourceLookupRecursionProtection = dmhub.FrameCount()
			local result = (c.creature:GetResources()[k] or 0) - c.creature:GetResourceUsage(k, resourceInfo.usageLimit)
            g_resourceLookupRecursionProtection = nil
            return result
		end

		CharacterResourceCollection.helpSymbols[symbolName] = {
			name = resourceInfo.name,
			type = "number",
			desc = "The number of " .. resourceInfo.name .. " this creature has.",
		}
	end

end)



function CharacterResourceCollection.CreateFromCreature(c)

	local result = CharacterResourceCollection.new{
		creature = c
	}

	return result
end