local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityDrawSteelCommandBehavior", "ActivatedAbilityBehavior")

ActivatedAbilityDrawSteelCommandBehavior.summary = 'Rule'
ActivatedAbilityDrawSteelCommandBehavior.rule = ''

ActivatedAbility.RegisterType
{
    id = 'draw_steel_command',
    text = 'Rule',
    createBehavior = function()
        return ActivatedAbilityDrawSteelCommandBehavior.new{
        }
    end
}

function ActivatedAbilityDrawSteelCommandBehavior:SummarizeBehavior(ability, creatureLookup)
    return "Rule: " .. self.rule
end


function ActivatedAbilityDrawSteelCommandBehavior:Cast(ability, casterToken, targets, options)
    options.pay = true
    for _,target in ipairs(targets) do
        if target.token ~= nil then
            self:ExecuteCommand(ability, casterToken, target.token, options, self.rule)
        end
    end
end

local function InvokeAbility(ability, abilityClone, targetToken, casterToken, options)

    --record the targets in case we need them.
    abilityClone.recordTargets = true
    abilityClone.keywords = ability.keywords
    abilityClone.notooltip = true
    abilityClone.skippable = true

    local casting = false
    abilityClone.OnBeginCast = function()
        casting = true
    end

    abilityClone.OnFinishCast = function()
        casting = false
    end

    local symbols = { invoker = GenerateSymbols(casterToken.properties), upcast = options.symbols.upcast, charges = options.symbols.charges, cast = options.symbols.cast }
    if casterToken.properties._tmp_aicontrol > 0 then
        casterToken.properties.ai:InvokeAbility(casterToken, targetToken, abilityClone, symbols)
        return
    else
	    gamehud.actionBarPanel:FireEventTree("invokeAbility", targetToken, abilityClone, symbols)
    end

    while casting or gamehud.actionBarPanel.data.IsCastingSpell() do
		coroutine.yield(0.1)
    end


end

local function ExecuteDamage(behavior, ability, casterToken, targetToken, options, match)
    local damageType = match.type or "normal"
    local damage = tonumber(match.damage)

    if damage == nil then
        local complete = false
        local rollid
        rollid = GameHud.instance.rollDialog.data.ShowDialog{
            title = "Damage Roll",
            roll = match.damage,
            completeRoll = function(rollInfo)
                complete = true
                damage = rollInfo.total
            end,
            cancelRoll = function()
                complete = true
            end,
        }

        while not complete do
            coroutine.yield(0.1)
        end
    end

    local bonus = match.bonus
    if bonus ~= nil then
        bonus = regex.ReplaceAll(bonus, ",? or ", ", ")

        local items = regex.Split(bonus, ", *")

        bonus = nil

        for _,item in ipairs(items) do
            local attrid = GameSystem.AttributeByFirstLetter[string.lower(item)] or "-"
            if attrid ~= '-' then
                local newBonus = targetToken.properties:AttributeMod(attrid)
                if bonus == nil or newBonus > bonus then
                    bonus = newBonus
                end
            end
        end
    end


    if damage ~= nil then

        if bonus ~= nil then
            damage = damage + bonus
        end

        local selfName = creature.GetTokenDescription(casterToken)

        local result

        targetToken:ModifyProperties{
            description = "Inflict Damage",
            undoable = false,
            execute = function()
                targetToken.properties.damage_entry = {
                    id = dmhub.GenerateGuid(),
                    accumulate = true,
                }

                result = targetToken.properties:InflictDamageInstance(damage, damageType, ability.keywords, string.format("%s's %s", selfName, ability.name), { criticalhit = false, attacker = casterToken.properties, surges = options.surges})

                targetToken.properties.damage_entry.accumulate = nil
            end,
        }


		options.symbols.cast.damagedealt = options.symbols.cast.damagedealt + result.damageDealt
		options.symbols.cast.damageraw = options.symbols.cast.damageraw + damage
    end
end

local g_tablesLookup = {}

local function GetTableNameRegex(tableName)
    local table = dmhub.GetTable(tableName) or {}
    g_tablesLookup[tableName] = {}
    local pattern = ""
    for k,v in pairs(table) do
        if not v:try_get("hidden", false) then
            local name = regex.ReplaceAll(string.lower(v.name), "[^a-z0-9 ]", "")
            if name ~= "" then
                if pattern ~= "" then
                    pattern = pattern .. "|"
                end

                pattern = pattern .. name
                g_tablesLookup[tableName][name] = k
            end
        end
    end

    return pattern
end


local g_rulePatterns = {
    --old style resistances. DEPRECATED
    {
        pattern = "^(?<attr>[MARIP]) ?(?<gate>(-?[0-9]+|\\[weak\\]|\\[average\\]|\\[strong\\]))",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            --see if the condition gate is exceeded.
            local gate
            if match.gate == "[weak]" then
                gate = casterToken.properties:HighestCharacteristic()-1
            elseif match.gate == "[average]" then
                gate = casterToken.properties:HighestCharacteristic()
            elseif match.gate == "[strong]" then
                gate = casterToken.properties:HighestCharacteristic()+1
            else
                gate = tonumber(match.gate)
            end


            local attrid = GameSystem.AttributeByFirstLetter[string.lower(match.attr)] or "-"
            return (targetToken.properties:AttributeForPotencyResistance(attrid) or 0) >= gate
        end,
    },

    --new style resistances.
    {
        pattern = "^(?<attr>[MARIPmarip]) ?< ?(?<gate>(-?[0-9]+|weak|average|strong))",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            --see if the condition gate is exceeded.
            local gate
            if match.gate == "weak" then
                gate = casterToken.properties:HighestCharacteristic()-1
            elseif match.gate == "average" then
                gate = casterToken.properties:HighestCharacteristic()
            elseif match.gate == "strong" then
                gate = casterToken.properties:HighestCharacteristic()+1
            else
                gate = tonumber(match.gate)
            end


            local attrid = GameSystem.AttributeByFirstLetter[string.lower(match.attr)] or "-"
            return (targetToken.properties:AttributeForPotencyResistance(attrid) or 0) >= gate
        end,
    },
    {
        pattern = {"^(?<damage>[0-9 d+-]+) +damage", "^(?<damage>[0-9]+) +(?<type>[a-z]+) +damage", "^(?<damage>[0-9]+) +\\+ (?<bonus>[a-z, ]+ or [a-z]+ )(?<type>[a-z]+) *damage", },
        execute = ExecuteDamage,
    },

    {
        pattern = "^(?<movement>pull|push|slide|toss) +(?<distance>[0-9]+)",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            local distance = tonumber(match.distance)

            local sizeDifferenceBonus = 0
            if ability.keywords["Weapon"] and ability.keywords["Melee"] then
                local casterSize = casterToken.creatureSizeNumber
                local targetSize = targetToken.properties:CreatureSizeWhenBeingForceMoved()
                if casterSize > targetSize then
                    sizeDifferenceBonus = 1
                end
            end

            local stability = targetToken.properties:ForcedMoveResistance()
            local abilityClone = DeepCopy(MCDMUtils.GetStandardAbility("Forced Movement"))
            abilityClone.name = string.gsub(match.movement, "^%l", string.upper) .. "!"
            abilityClone.range = math.max(0, tonumber(match.distance) - stability + sizeDifferenceBonus + casterToken.properties:ForcedMovementBonus(match.movement))
            abilityClone.description = string.format("You may %s the target %d square%s", match.movement, abilityClone.range, abilityClone.range > 1 and "s" or "")
            abilityClone.invoker = casterToken.properties
            abilityClone.promptOverride = abilityClone.description

            if stability > 0 then
                abilityClone.promptOverride = string.format("%s (stability of %d reduced to %d)", abilityClone.promptOverride, stability, abilityClone.range)
            end
            
            InvokeAbility(ability, abilityClone, targetToken, casterToken, options)
        end,
    },
    {
        pattern = "^(?<condition>prone|grabbed)",
        execute = function(behavior, ability, casterToken, targetToken, options, match)

            local conditionsTable = dmhub.GetTable(CharacterCondition.tableName)
            for k,v in pairs(conditionsTable) do
                if string.lower(v.name) == match.condition then
                    targetToken:ModifyProperties{
                        description = "Inflict Condition",
                        execute = function()
                            targetToken.properties:InflictCondition(k, {
                                duration = "eoe",
                                casterInfo = {
                                    tokenid = casterToken.charid,
                                }
                            })
                        end
                    }
                    break
                end
            end
        end,

    },
    {
        pattern = "^(?<condition>bleeding|dazed|frightened|grabbed|restrained|slowed|taunted|taunt|weakened) (?<effect>persists|ends at the end of your next turn|immediately ends)",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            if match.effect == "persists" then
                return
            end

            if match.condition == "taunt" then
                match.condition = "taunted"
            end

            local conditionsTable = dmhub.GetTable(CharacterCondition.tableName)
            for k,v in pairs(conditionsTable) do
                if (not v:try_get("hidden", false)) and string.lower(v.name) == match.condition then
                    targetToken:ModifyProperties{
                        description = "Remove Condition",
                        execute = function()
                            targetToken.properties:InflictCondition(k, {
                                force = true,
                                purge = match.effect == "immediately ends",
                                duration = "eot",
                            })
                        end,
                    }
                    break
                end
            end
        end,
    },
    {
        pattern = "^(?<condition>bleeding|dazed|frightened( of you)?|grabbed|restrained|slowed|taunted|taunt|weakened)(?<additionalConditions>( and |,)[a-z ]+)? \\((?<duration>EoT|save ends)?\\)",
        knownConditions = {"bleeding", "dazed", "frightened", "frightened of you", "grabbed", "restrained", "slowed", "taunted", "taunt", "weakened"},
        validate = function(entry, match)
            if match.additionalConditions == nil then
                return true
            end

            local additionalConditions = regex.Split(match.additionalConditions, "(,| and )")
            for _,c in ipairs(additionalConditions) do
                local cond = string.lower(trim(c))
                if cond == "" or cond == "," or cond == "and" then
                    --pass

                elseif not table.contains(entry.knownConditions, cond) then
                    return false
                end
            end

            return true
        end,
        execute = function(behavior, ability, casterToken, targetToken, options, match)

            local mod = 0
            if match.condition == "taunt" then
                match.condition = "taunted"
            end
            if match.condition == "frightened of you" then
                match.condition = "frightened"
            end
            if match.save ~= nil then
                local attrid = string.lower(match.save)
                mod = targetToken.properties:AttributeMod(match.save)
            end

            local duration = string.lower(match.duration)
            if string.starts_with(duration, "save") then
                duration = "save"
            end

            local conditions = {match.condition}

            if match.additionalConditions ~= nil then
                local additionalConditions = regex.Split(match.additionalConditions, "(,| and )")
                for _,cond in ipairs(additionalConditions) do
                    local c = string.lower(trim(cond))
                    if c == "taunt" then
                        c = "taunted"
                    end

                    if c == "frightened of you" then
                        c = "frightened"
                    end

                    if c ~= "and" and c ~= "" and c ~= "," then
                        conditions[#conditions+1] = c
                    end
                end
            end

            for _,cond in ipairs(conditions) do
                targetToken:ModifyProperties{
                    description = "Inflict Condition",
                    execute = function()
                        local conditionsTable = dmhub.GetTable(CharacterCondition.tableName)
                        for k,v in pairs(conditionsTable) do
                            if string.lower(v.name) == cond then
                                targetToken.properties:InflictCondition(k, {
                                    duration = duration,
                                    casterInfo = {
                                        tokenid = casterToken.charid,
                                    }
                                })
                                break
                            end
                        end
                    end,
                }
            end
        end,
    },
    {
        pattern = "^swap places with the target",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            casterToken:SwapPositions(targetToken)
        end,
    },
    {
        pattern = "^(the [a-zA-Z]+ )?(you )?shifts? (up to )?(?<distance>[0-9]+)( squares?)?",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            local shift = MCDMUtils.GetStandardAbility("Shift")

			local abilityClone = DeepCopy(shift)
            abilityClone.invoker = casterToken.properties
            abilityClone.range = tonumber(match.distance)

            InvokeAbility(ability, abilityClone, casterToken, casterToken, options)
        end,
    },
    {
        pattern = "^(the [a-zA-Z]+ )?(you )?teleports? (up to )?(?<distance>[0-9]+)( squares?)?",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            local teleport = MCDMUtils.GetStandardAbility("Teleport")

			local abilityClone = DeepCopy(teleport)
            abilityClone.invoker = casterToken.properties
            abilityClone.range = tonumber(match.distance)

            InvokeAbility(ability, abilityClone, casterToken, casterToken, options)
        end,
    },
    {
        pattern = {"^a new target in (reach|range) takes +(?<damage>[0-9]+) +damage", "^a new target in (reach|range) takes (?<damage>[0-9]+) +(?<type>[a-z]+) +damage"},
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            local abilityClone = DeepCopy(MCDMUtils.GetStandardAbility("Target"))

            abilityClone.invoker = casterToken.properties
            abilityClone.range = ability.range
            abilityClone.targetFilter = string.format('target.id != "%s"', targetToken.charid)

            InvokeAbility(ability, abilityClone, casterToken, casterToken, options)

            if abilityClone:has_key("recordedTargets") then
                for _,target in ipairs(abilityClone.recordedTargets) do
                    if target.token ~= nil then
                        ExecuteDamage(behavior, ability, casterToken, target.token, options, match)
                    end

                end
            end


        end,
    }
}

local g_gainResourceIndex = nil

dmhub.RegisterEventHandler("refreshTables", function(keys)
    if mod.unloaded then
        return
    end

	if keys ~= nil and (not keys[CharacterResource.tableName]) then
		return
	end

    g_gainResourceIndex = g_gainResourceIndex or #g_rulePatterns + 1

    g_rulePatterns[g_gainResourceIndex] = {
        pattern = "^gain +(?<amount>[0-9]+) +(?<resource>" .. GetTableNameRegex(CharacterResource.tableName) .. ")",
        execute = function(behavior, ability, casterToken, targetToken, options, match)
            local amount = tonumber(match.amount)
            local resource = match.resource

            local key = g_tablesLookup[CharacterResource.tableName][string.lower(resource)]
            if key ~= nil then
                targetToken:ModifyProperties{
                    description = "Gain Resource",
                    execute = function()
                        targetToken.properties:RefreshResource(key, "unbounded", amount, string.format("Gained %d %s from %s", amount, resource, ability.name))
                    end,
                }
            end
        end,
    }
end)


local function SubstituteGoblinScript(ability, casterToken, targetToken, options, rule)
    local match = regex.MatchGroups(rule, "(?<goblinscript>\\{[^\\}]*\\})", {indexes = true})
    if match ~= nil then
		local index = match.goblinscript.index
		local length = match.goblinscript.length

		local before = string.sub(rule, 1, index-1)
		local after = string.sub(rule, index+length)

        local goblinScript = string.sub(match.goblinscript.value, 2, #match.goblinscript.value - 1)

        local str = tostring(dmhub.EvalGoblinScriptDeterministic(goblinScript, targetToken.properties:LookupSymbol(options.symbols), 0, "SubstituteGoblinScript"))

        rule = before .. str .. after


        return SubstituteGoblinScript(ability, casterToken, targetToken, options, rule)
    end

    return rule
end

function ActivatedAbilityDrawSteelCommandBehavior:ExecuteCommand(ability, casterToken, targetToken, options, rule)

    rule = SubstituteGoblinScript(ability, casterToken, targetToken, options, rule)

    self:ExecuteCommandInternal(ability, casterToken, targetToken, options, rule)

end

function ActivatedAbilityDrawSteelCommandBehavior:ExecuteCommandInternal(ability, casterToken, targetToken, options, rule)
    rule = string.lower(rule)
    if rule == "" then
        return
    end

    --print("Rule:: Before normalize: " .. rule)

    rule = ActivatedAbilityDrawSteelCommandBehavior.NormalizeDamageRuleTextForCreature(casterToken.properties, rule)

    --print("Rule:: Trying to match rule: \"" .. rule .. "\"")
    for _,entry in ipairs(g_rulePatterns) do
        local patterns = entry.pattern
        if type(patterns) == "string" then
            patterns = {patterns}
        end
        for _,pattern in ipairs(patterns) do
            local match = regex.MatchGroups(rule, pattern)
            if match ~= nil and entry.validate ~= nil and not entry.validate(entry, match) then
                match = nil
            end

            if match ~= nil then
                local result = entry.execute(self, ability, casterToken, targetToken, options, match)

                --a result of true means the rule is gated and we should stop processing.
                if result == true then
                    return
                end

                local tail = string.sub(rule, #(match.all or rule) + 1)

                --print("Rule:: Matched \"" .. (match.all or rule) .. " against pattern \"" .. pattern .. "\". Tail: \"" .. tail .. "\"")

                rule = tail
                match = regex.MatchGroups(rule, "^(, *| and | then |; *)")

                if match == nil then
                    match = regex.MatchGroups(rule, "^ ")
                end

                if match ~= nil then
                    local orig = rule
                    rule = string.sub(rule, #(match.all or rule) + 1)

                    self:ExecuteCommandInternal(ability, casterToken, targetToken, options, rule)
                end

                return
            end
        end
    end

    local bestMatch = nil
    local bestMatchInfo = nil
    local rulesTable = dmhub.GetTable("importerPowerTableEffects")
    for _,pattern in pairs(rulesTable) do
        local abilityMatch, matchInfo = pattern:MatchMCDMEffect(nil, ability.name, rule)
        if abilityMatch ~= nil then
            if matchInfo == nil then
                bestMatch = abilityMatch
                break
            end

            if bestMatchInfo == nil or matchInfo.all == nil or #matchInfo.all > #bestMatchInfo.all then
                bestMatch = abilityMatch
                bestMatchInfo = matchInfo
            end
        end
    end

    if bestMatch ~= nil then
        --print("Rule:: Matched standard effect:", bestMatch.name)
        for _,behavior in ipairs(bestMatch.behaviors) do
            if not behavior:IsFiltered(ability, casterToken, options) then
                behavior:Cast(ability, casterToken, behavior:ApplyToTargets(ability, casterToken, {{token = targetToken}}, options), options)
            end
        end
    else
        --print("Rule:: No match")
    end
end

function ActivatedAbilityDrawSteelCommandBehavior.ValidateRule(rule)
    --print("Rule:: Validating rule(" .. rule .. ")")
    rule = string.lower(rule)
    if rule == "" then
        --print("Rule:: Returning true")
        return true
    end

    for _,entry in ipairs(g_rulePatterns) do
        local patterns = entry.pattern
        if type(patterns) == "string" then
            patterns = {patterns}
        end
        for _,pattern in ipairs(patterns) do
            local match = regex.MatchGroups(rule, pattern)
            if match ~= nil then
                --print("Rule:: matched pattern", pattern)
            end

            if match ~= nil and entry.validate ~= nil and not entry.validate(entry, match) then
                --print("Rule:: validate failed")
                match = nil
            end

            if match ~= nil then
                local tail = string.sub(rule, #(match.all or rule) + 1)
                --print("Rule:: Validate Matched \"" .. (match.all or rule) .. "\" against pattern \"" .. pattern .. "\". Tail: \"" .. tail .. "\"")
                rule = tail
                match = regex.MatchGroups(rule, "^(, *| and | then |; *)")

                if match == nil then
                    match = regex.MatchGroups(rule, "^ ")
                end

                if match ~= nil then
                    rule = string.sub(rule, #match.all + 1)
                    --print("Rule:: pared down to (" .. rule .. ")")
                    return ActivatedAbilityDrawSteelCommandBehavior.ValidateRule(rule)
                elseif #trim(rule) > 1 then
                    return rule
                end

                return true
            end
        end
    end

    local bestMatch = nil
    local bestMatchInfo = nil

    local rulesTable = dmhub.GetTable("importerPowerTableEffects")
    for _,pattern in pairs(rulesTable) do
        local abilityMatch, matchInfo = pattern:MatchMCDMEffect(nil, "Ability", rule)
        if abilityMatch ~= nil then
            if matchInfo == nil then
                return true
            end

            if bestMatchInfo == nil or #matchInfo.all > #bestMatchInfo.all then
                bestMatch = abilityMatch
                bestMatchInfo = matchInfo
            end
        end
    end

    if bestMatchInfo ~= nil then
        if bestMatchInfo.all == nil or #bestMatchInfo.all >= #rule then
            --print("Rule:: Returning true")
            return true
        end

        local result = string.sub(rule, #bestMatchInfo.all + 1)
        --print("Rule:: validate matched pattern: (" .. bestMatchInfo.all .. "); rule = (" .. rule .. "); result = (" .. result .. ")")
        return result
    end

    --print("Rule:: Returning (" .. rule .. ")")
    return rule
end


--@param caster: Creature
--@param rule: string
--@param notes: {string}|nil
--@return string
function ActivatedAbilityDrawSteelCommandBehavior.NormalizeDamageRuleTextForCreature(caster, rule, notes)
    --search for something like 7 + M, A, or I damage
    local matchDamageWithCharacteristic = regex.MatchGroups(rule, "(?<number>[0-9]+) \\+ (?<attr>[A-Za-z ]+,? or [A-Za-z]+) ")
    if matchDamageWithCharacteristic == nil then
        --try to find with just a single attribute.
        matchDamageWithCharacteristic = regex.MatchGroups(rule, "(?<number>[0-9]+) \\+ (?<attr>[A-Za-z]) ")
    end
    if matchDamageWithCharacteristic ~= nil then
        local baseDamage = tonumber(matchDamageWithCharacteristic.number)
        local attributes = regex.Split(matchDamageWithCharacteristic.attr, ", or |,| or ")
        local bonusDamage = nil
        local attributeUsed = nil
        for _,attrid in ipairs(attributes) do
            local attr = string.upper(string.trim(attrid))
            attr = GameSystem.AttributeByFirstLetter[string.lower(attr)] or "-"
            if attr ~= '-' then
                local newBonus = caster:AttributeMod(attr)
                if bonusDamage == nil or newBonus > bonusDamage then
                    bonusDamage = newBonus
                    attributeUsed = attr
                end
            end
        end

        if bonusDamage ~= nil then
            local totalDamage = baseDamage + bonusDamage
            rule = regex.ReplaceOne(rule, "[0-9]+ \\+ ([A-Za-z ]+,? or [A-Za-z]+|[A-Za-z]) ", string.format("%d ", totalDamage))
            if notes ~= nil then
                notes[#notes+1] = string.format("<color=#ff4444>Caster's %s of %d included in damage</color>", creature.attributesInfo[attributeUsed].description, bonusDamage)
            end
        end
    end

    return rule
end

--@param caster: Creature|nil
--@param rule: string
--@param notes: {string}|nil
--@return string
function ActivatedAbilityDrawSteelCommandBehavior.DisplayRuleTextForCreature(caster, rule, notes)
    if caster ~= nil then
        local potency = caster:Potency()
        local startingRule = rule

        --old way. Deprecate later?
        rule = regex.ReplaceAll(rule, "(?<attr>[MARIP]) \\[weak\\]", string.format("<color=#ff4444><uppercase>${attr}</uppercase>%d</color>", potency-1))
        rule = regex.ReplaceAll(rule, "(?<attr>[MARIP]) \\[average\\]", string.format("<color=#ff4444><uppercase>${attr}</uppercase>%d</color>", potency))
        rule = regex.ReplaceAll(rule, "(?<attr>[MARIP]) \\[strong\\]", string.format("<color=#ff4444><uppercase>${attr}</uppercase>%d</color>", potency+1))

        --new way.
        rule = regex.ReplaceAll(rule, "(?<attr>[MARIP]) < weak", string.format("<color=#ff4444><uppercase>${attr}</uppercase> < %d</color>", potency-1))
        rule = regex.ReplaceAll(rule, "(?<attr>[MARIP]) < average", string.format("<color=#ff4444><uppercase>${attr}</uppercase> < %d</color>", potency))
        rule = regex.ReplaceAll(rule, "(?<attr>[MARIP]) < strong", string.format("<color=#ff4444><uppercase>${attr}</uppercase> < %d</color>", potency+1))

        if rule ~= startingRule and notes ~= nil then
            notes[#notes+1] = string.format("<color=#ff4444>Caster has a Potency of %d</color>", potency)
        end

        rule = ActivatedAbilityDrawSteelCommandBehavior.NormalizeDamageRuleTextForCreature(caster, rule, notes)

    end

    return ActivatedAbilityDrawSteelCommandBehavior.FormatRuleValidation(rule)
end

function ActivatedAbilityDrawSteelCommandBehavior.FormatRuleValidation(rule)
    --print("Rule:: Validating (" .. rule .. ")")
    local text = ActivatedAbilityDrawSteelCommandBehavior.ValidateRule(rule)
    if type(text) == "string" then
        local before = string.sub(rule, 1, -#text - 1)
        local result = string.format("%s<alpha=#55>%s", before, text)
        --print(string.format("Rule:: Validation: rule = (%s); text = (%s); before = (%s); result = (%s)", rule, text, before, result))
        return result
    else
        return rule
    end
end

function ActivatedAbilityDrawSteelCommandBehavior:EditorItems(parentPanel)
	local result = {}
	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

    result[#result+1] = gui.Panel{
        classes = "formPanel",
        gui.Label{
            classes = "formLabel",
            text = "Rule:",
        },

        gui.Input{
            classes = "formInput",
            halign = "left",
            width = 320,
            fontSize = 14,
            placeholderText = "Enter Rule...",
            x = -10,
            text = self.rule,
            change = function(element)
                self.rule = element.text
                parentPanel:FireEvent("refreshBehavior")
            end,

        },
    }

	return result
end