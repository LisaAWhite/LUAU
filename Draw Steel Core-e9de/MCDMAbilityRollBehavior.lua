local mod = dmhub.GetModLoading()

--register the ability to modify power roll damage during spell casting.
ActivatedAbilityModifyCastBehavior.RegisterParam{
    id = "ability_damage",
    text = "Ability Damage",
}

ActivatedAbilityModifyCastBehavior.RegisterParam{
    id = "ability_boon",
    text = "Number of Edges",
}

ActivatedAbilityModifyCastBehavior.RegisterParam{
    id = "ability_bane",
    text = "Number of Banes",
}

ActivatedAbilityModifyCastBehavior.RegisterParam{
    id = "ability_surges",
    text = "Number of Surges",
}

RegisterGameType("ActivatedAbilityPowerRollBehavior", "ActivatedAbilityBehavior")

ActivatedAbilityPowerRollBehavior.summary = 'Roll on Power Table'
ActivatedAbilityPowerRollBehavior.rule = ''

local function FormatTierText(text)
    text = ActivatedAbilityDrawSteelCommandBehavior.FormatRuleValidation(text)
    local damageGroups = regex.MatchGroups(text, "^(?<damage>[0-9]+).*?damage")
    if damageGroups ~= nil then
        text = string.format("<b>%s</b>%s", damageGroups.damage, string.sub(text, string.len(damageGroups.damage)+1))
    end

    return text
end

local function BoonsAndBanesToMod(boons, banes)
    if boons >= 2 and banes == 0 then
        return 0
    elseif banes >= 2 and boons == 0 then
        return 0
    end

    return (min(2, boons) - min(2, banes))*2
end

--result has {total = number, boons = nil|number, banes = nil|number, autosuccess = bool?, autofailure = bool?, tiers = nil|number}
local function DiceResultToTier(result)
    if result.autosuccess then
        return 3
    end

    if result.autofailure then
        return 1
    end
    local tier = 1
    if result.total >= 17 then
        tier = 3
    elseif result.total >= 12 then
        tier = 2
    end

    if (result.boons or 0) >= 2 and (result.banes or 0) == 0 then
        tier = tier + 1
    elseif (result.banes or 0) >= 2 and (result.boons or 0) == 0 then
        tier = tier - 1
    end

    tier = tier + (result.tiers or 0)
    if tier > 3 then
        tier = 3
    elseif tier < 1 then
        tier = 1
    end

    return tier
end

local g_TierNames = GameSystem.TierNames

ActivatedAbilityPowerRollBehavior.tierNames = g_TierNames

ActivatedAbility.RegisterType
{
    id = 'power_roll',
    text = 'Ability Power Roll',
    createBehavior = function()
        return ActivatedAbilityPowerRollBehavior.new{
            tiers = {"", "", ""},
            roll = "2d10 + Might or Agility",
        }
    end,
}

function ActivatedAbilityPowerRollBehavior:SummarizeBehavior(ability, creatureLookup)
    return "Ability Power Roll"
end

local function CalculateMultitargetsFromRollProperties(rollMessage, rollResult)

    rollResult = rollResult or rollMessage

    if not rollMessage.properties:has_key("multitargets") then
        return nil
    end

    local multitargets = {}
    for _,target in ipairs(rollMessage.properties.multitargets) do
        local rollInfo = {
            total = rollResult.total,
            boons = rollResult.boons,
            banes = rollResult.banes,
            autosuccess = rollResult.autosuccess,
            autofailure = rollResult.autofailure,
            tiers = rollResult.tiers,
        }

        if target.boons ~= nil then
            local bonusFromBoonsAndBanes = 0
            if rollInfo.boons + rollInfo.banes == 1 then
                bonusFromBoonsAndBanes = 2
            elseif rollInfo.boons + rollInfo.banes == -1 then
                bonusFromBoonsAndBanes = -2
            end

            if target.boons > 0 then
                rollInfo.boons = math.min(rollInfo.boons + target.boons, 2)
            else
                rollInfo.banes = math.min(rollInfo.banes - target.boons, 2)
            end

            if rollInfo.boons + rollInfo.banes == 1 then
                bonusFromBoonsAndBanes = bonusFromBoonsAndBanes - 2
            elseif rollInfo.boons + rollInfo.banes == -1 then
                bonusFromBoonsAndBanes = bonusFromBoonsAndBanes + 2
            end

            rollInfo.total = rollInfo.total - bonusFromBoonsAndBanes
        end

        local tier = rollMessage.properties:try_get("overrideTier") or DiceResultToTier(rollInfo)

        multitargets[#multitargets+1] = {
            token = dmhub.GetCharacterById(target.tokenid),
            tier = tier,
        }
    end
    return multitargets
end

ActivatedAbilityPowerRollBehavior.GetPowerTablePopulateCustom = function(rollProperties, caster)
    return function(parentPanel)
        local m_diceFaces = {}
        local m_numDice = 0
        local m_endTime = nil
        local m_mod = 0
        local m_rollInfo
        local m_rollInfoKey
        local m_finished = false
        local m_tierFinished = nil
        local tbl = gui.Table{
            width = "100%",
            height = "auto",
            flow = "vertical",
            styles = {
                {
                    selectors = {"row", "highlight"},
                    bgcolor = Styles.textColor,
                },
                {
                    selectors = {"label", "highlight"},
                    color = "black",
                },
                {
                    selectors = {"row", "flash"},
                    brightness = 3,
                    transitionTime = 1,
                },
                {
                    selectors = {"row", "selectable", "hover"},
                    bgcolor = "#ff7777",
                    brightness = 2,
                    transitionTime = 0.1,
                }
            },
            think = function(element)
                if m_rollInfo ~= nil then
                    --check if we have an update to the message.

                    local message
                    for _,msg in ipairs(chat.messages) do
                        if msg.key == m_rollInfoKey then
                            message = msg
                            break
                        end
                    end

                    if message ~= nil then
                        m_rollInfo = message

                        local tier = DiceResultToTier(m_rollInfo)

                        tier = m_rollInfo.properties:try_get("overrideTier") or tier

                        if m_tierFinished ~= nil and tier ~= m_tierFinished then
                            m_tierFinished = tier
                            element:FireEventTree("tier", m_tierFinished, true)
                        end
                    end
                end

                if m_endTime ~= nil and dmhub.Time() > m_endTime then
                    element:FireEvent("diceend")
                    m_endTime = nil
                    m_finished = true

                    local tier = DiceResultToTier(m_rollInfo)


                    local multitargets = CalculateMultitargetsFromRollProperties(m_rollInfo)

                    tier = m_rollInfo.properties:try_get("overrideTier") or tier

                    m_tierFinished = tier
                    element:FireEventTree("tier", tier, true, multitargets)
                end
            end,
            beginRoll = function(element, rollInfo, rollid)

                m_diceFaces = {}
                m_numDice = 0
                m_endTime = nil
                m_finished = false
                m_tierFinished = nil

                element.thinkTime = 0.1
                m_rollInfo = rollInfo
                m_rollInfoKey = rollid
                m_mod = rollInfo.total
                for _,roll in ipairs(rollInfo.rolls) do
                    m_mod = m_mod - roll.result
					local events = chat.DiceEvents(roll.guid)
					if events ~= nil then
						events:Listen(element)
                        m_numDice = m_numDice + 1
					end
                    
                end
            end,
            diceend = function(element)
            end,

            diceface = function(element, diceguid, num, timeRemaining)
                if m_finished then
                    return
                end

                local endTime = dmhub.Time() + timeRemaining
                m_diceFaces[diceguid] = num
                if m_endTime == nil or endTime > m_endTime then
                    m_endTime = endTime
                end

                local total = m_mod
                local count = 0
                for _,value in pairs(m_diceFaces) do
                    count = count + 1
                    total = total + value
                end

                if count == m_numDice then
                    local tier = DiceResultToTier{
                        total = total,
                        boons = m_rollInfo.surges,
                        banes = m_rollInfo.shields,
                        autofailure = m_rollInfo.autofailure,
                        autosuccess = m_rollInfo.autosuccess,
                        tiers = m_rollInfo.tiers,
                    }

                    element:FireEventTree("tier", tier)
                end
            end,
        }

        local children = {}
        for i=1,#g_TierNames do
            local tier = g_TierNames[i]
            local tierText = rollProperties.tiers[i]

            if caster ~= nil then
                tierText = ActivatedAbilityDrawSteelCommandBehavior.DisplayRuleTextForCreature(caster, tierText)
            end

            local row = gui.TableRow{
                width = "100%",
                height = "auto",
                press = function(element)
                    if (not element:HasClass("selectable")) or element:HasClass("highlight") then
                        return
                    end

                    m_tierFinished = i
                    rollProperties.overrideTier = i
                    rollProperties.overrideMessage = string.format("%s overrode the result", dmhub.userDisplayName)
                    m_rollInfo:UploadProperties(rollProperties)

                    element.parent:FireEventTree("tier", i, true)
                end,
                tier = function(element, tierNumber, finish, multitargets)
                    element:SetClassTree("highlight", tierNumber == i)
                    if tierNumber == i and finish then
                        element:PulseClass("flash")
                    end

                    if finish then
                        element:SetClass("selectable", true)
                    end
                end,
                gui.Label{ text = tier, width = "16%", fontSize = 18, height = 20, valign = "center", },
                gui.Panel{
                    vpad = 4,
                    fontSize = 18,
                    width = "66%",
                    height = "auto",
                    valign = "center",
                    gui.Label{
                        text = FormatTierText(tierText),
                        width = 500,
                        height = "auto",
                        refreshMods = function(element)
                            local tierText = rollProperties.tiers[i]
                            if caster ~= nil then
                                tierText = ActivatedAbilityDrawSteelCommandBehavior.DisplayRuleTextForCreature(caster, tierText)
                            end
                            element.text = FormatTierText(tierText)
                        end,
                    },
                },

                gui.Panel{
                    vpad = 4,
                    width = "17%",
                    height = "auto",
                    halign = "right",
                    valign = "center",
                    flow = "horizontal",
                    wrap = true,
                    tier = function(element, tierNumber, finish, multitargets)
                        if multitargets == nil then
                            element.children = {}
                        end

                        local children = {}

                        for _,target in ipairs(multitargets or {}) do
                            if target.tier == i then
                                children[#children+1] = gui.CreateTokenImage(target.token, {
                                    width = 32,
                                    height = 32,
                                    halign = "right",
                                    valign = "center",
                                    bgcolor = "white",
                                })
                            end
                        end

                        element.children = children
                    end,
                },
            }

            children[#children+1] = row
        end

        tbl.children = children

        

        parentPanel.children = {tbl}
    end
end


local g_activeRoll = nil --the active roll object of the roll we are currently doing.
local g_activeRollPanel = nil --the panel showing the roll that is currently active.

function ActivatedAbilityPowerRollBehavior:Cast(ability, casterToken, targets, options)

    if self:try_get("resistanceRoll", false) then
        return self:CastResistance(ability, casterToken, targets, options)
    end

    local caster = casterToken.properties
    local roll = dmhub.EvalGoblinScript(self.roll, casterToken.properties:LookupSymbol(options.symbols), "Power table roll")

	local modifiersApplied = nil
    local appliedTargetCreature = nil

    local modifiersOnCaster = caster:GetActiveModifiers()

    local paramModifications = options.symbols.cast:GetParamModifications("ability_damage")

    for _,damageMod in ipairs(paramModifications) do
        local mod = CharacterModifier.new{
            behavior = "power",
            rollType = "ability_power_roll",
            activationCondition = true,
            keywords = {},
            modtype = "none",
            guid = dmhub.GenerateGuid(),
            name = damageMod.name,
            description = damageMod.description,
            damageModifier = damageMod.value,
        }

        modifiersOnCaster[#modifiersOnCaster+1] = {
            mod = mod,
        }
    end

    local paramSurges = options.symbols.cast:GetParamModifications("ability_surges")
    for _,surgeMod in ipairs(paramSurges) do
        local mod = CharacterModifier.new{
            behavior = "power",
            rollType = "ability_power_roll",
            activationCondition = true,
            keywords = {},
            modtype = "none",
            guid = dmhub.GenerateGuid(),
            name = surgeMod.name,
            description = surgeMod.description,
            surges = surgeMod.value,
            damageModifier = 0,
        }

        modifiersOnCaster[#modifiersOnCaster+1] = {
            mod = mod,
        }
    end

    for i,boonbane in ipairs({"ability_boon", "ability_bane"}) do
        local mult = cond(i == 1, 1, -1)

        local paramModifications = options.symbols.cast:GetParamModifications(boonbane)
        for _,boonMod in ipairs(paramModifications) do
            local modtype = "none"
            for _,option in ipairs(ActivatedAbilityPowerRollBehavior.s_modificationTypes) do
                if option.value == boonMod.value*mult then
                    modtype = option.id
                end
            end

            local mod = CharacterModifier.new{
                behavior = "power",
                rollType = "ability_power_roll",
                activationCondition = true,
                keywords = {},
                modtype = modtype,
                guid = dmhub.GenerateGuid(),
                name = boonMod.name,
                description = boonMod.description,
                damageModifier = 0,
            }

            modifiersOnCaster[#modifiersOnCaster+1] = {
                mod = mod,
            }
        end
    end

    --our behavior-builtin modifiers
    for _,modInfo in ipairs(self:try_get("modifiers", {})) do

        local mod = CharacterModifier.new{
            behavior = "power",
            rollType = "ability_power_roll",
            activationCondition = modInfo.condition,
            keywords = {},
            modtype = modInfo.type,
            guid = dmhub.GenerateGuid(),
            name = modInfo.text,
            description = modInfo.details,
        }

        modifiersOnCaster[#modifiersOnCaster+1] = {
            mod = mod,
        }
    end

    local multitargets = {}

    local baseBoons = nil

    for i,target in ipairs(targets or {}) do
        local boons = 0
        local boonsText = nil
        local targetCreature = target.token.properties

        if appliedTargetCreature == nil then
            appliedTargetCreature = targetCreature
        end

        local modifiersOnTarget = targetCreature:GetActiveModifiers()

        local candidateModifiers = {}

        --the attacker's modifiers.
        for _,mod in ipairs(modifiersOnCaster) do
            local m = mod.mod:DescribeModifyPowerRoll(mod, caster, "ability_power_roll", {})
            if m ~= nil then
                if options.symbols ~= nil then
                    m.modifier:InstallSymbolsFromContext(options.symbols)
                end

                m.hint = m.modifier:HintModifyPowerRolls(mod, caster, "ability_power_roll", {
                    ability = ability,
                    target = targetCreature,
                })
                if m.hint ~= nil then
                    candidateModifiers[#candidateModifiers+1] = m
                end
            end
        end

        --the defender's modifiers.
        for _,mod in ipairs(modifiersOnTarget) do
            --this is run from the defender's perspective.
            local m = mod.mod:DescribeModifyPowerRoll(mod, targetCreature, "enemy_ability_power_roll", {})
            if m ~= nil then
                if options.symbols ~= nil then
                    m.modifier:InstallSymbolsFromContext(options.symbols)
                end

                --this is told from the caster's perspective.
                m.hint = m.modifier:HintModifyPowerRolls(mod, caster, "enemy_ability_power_roll", {
                    ability = ability,
                    target = targetCreature,
                })

                if m.hint ~= nil then
                    candidateModifiers[#candidateModifiers+1] = m
                end
            end
        end

        --if we are attacking as part of a minion squad signature, any excess targeting
        --gets to do free strikes against the targets.
        if options.symbols.targetPairs ~= nil and ability.categorization == "Signature Ability" and casterToken.properties.minion then
            local numAttackers = 0

            for i,pair in ipairs(options.symbols.targetPairs) do
                if pair.b == target.token.charid then
                    numAttackers = numAttackers + 1
                end
            end

            if numAttackers > 1 then

                local mod = CharacterModifier.new{
                    behavior = "power",
                    rollType = "ability_power_roll",
                    activationCondition = true,
                    keywords = {},
                    modtype = "none",
                    guid = dmhub.GenerateGuid(),
                    name = cond(numAttackers-1 == 1, "Extra Attacker", "Extra Attackers"),
                    description = string.format("There %s %d extra minion attacker%s, each of which does free strike against the target.", cond(numAttackers-1 == 1, "is", "are"), numAttackers-1, cond(numAttackers-1 > 1, "s", "")),
                    damageModifier = casterToken.properties:OpportunityAttack()*(numAttackers-1),
                }
                
                candidateModifiers[#candidateModifiers+1] = {
                    modifier = mod,
                    hint = mod:HintModifyPowerRolls(mod, caster, "ability_power_roll", {
                        ability = ability,
                        target = targetCreature,
                    })
                }

                print("MODIFIER:: Add", candidateModifiers[#candidateModifiers])
            end
        end



        local candidateRoll = roll
        for _,mod in ipairs(candidateModifiers) do
            if mod.hint ~= nil and mod.hint.result then
                candidateRoll = mod.modifier:ModifyPowerRolls(mod.context, caster, "ability_power_roll", candidateRoll, {
                    ability = ability,
                    target = targetCreature,
                })
            end
        end

		local rollInfo = dmhub.ParseRoll(candidateRoll)

        candidateModifiers = DeepCopy(candidateModifiers)

        if modifiersApplied == nil then
            modifiersApplied = candidateModifiers
            baseBoons = boons
        end


		multitargets[#multitargets+1] = {
			token = target.token,
			boons = boons - baseBoons,
			text = boonsText,
            modifiers = candidateModifiers,
		}

    end


    local m_result = {
        total = nil,
        boons = nil,
        banes = nil,
    }

    local m_canceled = false

    local tiers = DeepCopy(self.tiers)
    if ability.description ~= "" and ability.effectImplemented == false and ActivatedAbilityDrawSteelCommandBehavior.ValidateRule(ability.description) == true then
        --append the rule to the tiers if it is a valid rule that could
        --appear on a power roll.
        for i=1,#tiers do
            tiers[i] = trim(tiers[i])
            if string.ends_with(tiers[i], ".") then
                tiers[i] = trim(string.sub(tiers[i], 1, string.len(tiers[i])-1))
            end
            tiers[i] = string.format("%s; %s", tiers[i], ability.description)
        end
    end

    for i,tier in ipairs(tiers) do
        tiers[i] = ActivatedAbilityDrawSteelCommandBehavior.DisplayRuleTextForCreature(caster, tiers[i])
    end

    local multitargetProperties = nil

    local rollProperties = RollPropertiesPowerTable.new{
        tiers = tiers,
    }

    local m_rollInfo = nil

    local rollKey
    rollKey = GameHud.instance.rollDialog.data.ShowDialog{
        description = ability.name .. ": Power Roll",
        title = "Roll on Power Table",
        type = "ability_power_roll",
        ability = ability,
        roll = roll,
        showDialogDuringRoll = true,
        amendable = true,
        modifiers = modifiersApplied,
        multitargets = multitargets,
        creature = caster,
        targetCreature = appliedTargetCreature,

        rollProperties = rollProperties,

        PopulateCustom = ActivatedAbilityPowerRollBehavior.GetPowerTablePopulateCustom(rollProperties, caster),

        rollActive = function(activeRoll)
            g_activeRoll = activeRoll
        end,

        beginRoll = function(rollInfo)
            if #targets > 0 and targets[1].token ~= nil and ability.keywords["Strike"] and ability.keywords["Melee"] then

                local damage = 5
                local tier = DiceResultToTier(rollInfo)
                local command = rollProperties.tiers[tier]

                local damageMatch = regex.MatchGroups(roll, "(?<damage>[0-9]+).*?damage")
                if damageMatch ~= nil then
                    damage = tonumber(damageMatch.damage)
                end

                local outcome = "Hit"
                if tier == 1 then
                    outcome = "Block"
                elseif tier == 3 then
                    outcome = "Critical"
                end
                
                casterToken:AnimateAttack{
                    targetid = targets[1].token.charid,
                    rollid = rollKey,
                    damage = damage,
                    outcome = "Hit",
                }



            end
        end,

        completeRoll = function(rollInfo)
            m_rollInfo = rollInfo
            m_result = {
                total = rollInfo.total,
                boons = rollInfo.boons,
                banes = rollInfo.banes,
                tiers = rollInfo.tiers,
                autofailure = rollInfo.autofailure,
                autosuccess = rollInfo.autosuccess,
            }
            options.symbols.cast.boonsApplied = rollInfo.boons
            options.symbols.cast.banesApplied = rollInfo.banes
        end,

        cancelRoll = function()
            m_canceled = true
        end,
    }

    local holdOpenRefreshAt = nil
    local refreshAtPanel = nil

    while m_canceled == false and m_result.total == nil do
        coroutine.yield(0.1)

        if g_activeRollPanel ~= nil and g_activeRollPanel.valid and g_activeRoll.guid == rollKey and dmhub.HoldAmendableRollOpen ~= nil and dmhub.HoldAmendableRollOpen() and (holdOpenRefreshAt == nil or holdOpenRefreshAt < dmhub.Time()-2) then
            holdOpenRefreshAt = dmhub.Time()
            refreshAtPanel = g_activeRollPanel
            g_activeRollPanel:FireEvent("recordInteracting")
        elseif refreshAtPanel ~= nil and refreshAtPanel.valid and (not dmhub.HoldAmendableRollOpen()) then
            refreshAtPanel:FireEvent("clearInteracting")
            refreshAtPanel = nil
            holdOpenRefreshAt = nil
        end
    end

    if refreshAtPanel ~= nil and refreshAtPanel.valid then
        refreshAtPanel:FireEvent("clearInteracting")
    end

    if m_canceled then
        return
    end

    options.pay = true

    if ability.keywords["Strike"] then
        --trigger the attack trigger when attacking.

        for _,target in ipairs(targets or {}) do
            local targetToken = target.token
            if targetToken ~= nil then
                local args = {
                    outcome = string.format("tier%d", rollProperties:try_get("overrideTier") or DiceResultToTier(m_result)),
                    degree = rollProperties:try_get("overrideTier") or DiceResultToTier(m_result),
                    target = GenerateSymbols(targetToken.properties),
                    ability = GenerateSymbols(ability),
                }

                casterToken.properties:TriggerEvent("attack", args)
            end
        end
    end

    local multitargetResults = CalculateMultitargetsFromRollProperties(m_rollInfo, m_result)

    local triggerInfo = {
        surges = 0,
        tierone = false,
        tiertwo = false,
        tierthree = false,
    }

    for numTarget,target in ipairs(targets or {}) do

        local targetToken = target.token
        local tier = rollProperties:try_get("overrideTier") or DiceResultToTier(m_result)

        local targetRollProperties = rollProperties

        if targetToken ~= nil then
            if multitargetResults ~= nil then
                for i,multitarget in ipairs(multitargetResults) do
                    if multitarget.token.charid == targetToken.charid then
                        tier = multitarget.tier
                        if multitargets[i].rollProperties ~= nil then
                            targetRollProperties = multitargets[i].rollProperties
                        end
                        break
                    end
                end
            end

            local command = targetRollProperties.tiers[tier]

            if ability.keywords["Strike"] then
                targetToken.properties:TriggerEvent("attacked", {
                    outcome = tier,
                    roll = m_result.total,
                    attacker = GenerateSymbols(casterToken.properties),
                })
            end

            local surges = 0
            if m_rollInfo.properties ~= nil and m_rollInfo.properties.multitargets ~= nil and m_rollInfo.properties.multitargets[numTarget] ~= nil then
                surges = m_rollInfo.properties.multitargets[numTarget].surges or 0
            end

            options.surges = surges
            triggerInfo.surges = triggerInfo.surges + surges
            triggerInfo.tierone = triggerInfo.tierone or tier == 1
            triggerInfo.tiertwo = triggerInfo.tiertwo or tier == 2
            triggerInfo.tierthree = triggerInfo.tierthree or tier == 3

            triggerInfo.keywords = StringSet.new{
                strings = table.keys(ability.keywords)
            }

            self:ExecuteCommand(ability, casterToken, targetToken, options, command)
        end
    end

    triggerInfo.naturalroll = m_rollInfo.naturalRoll

    casterToken.properties:DispatchEvent("rollpower", triggerInfo)

end

ActivatedAbilityPowerRollBehavior.ExecuteCommand = ActivatedAbilityDrawSteelCommandBehavior.ExecuteCommand
ActivatedAbilityPowerRollBehavior.ExecuteCommandInternal = ActivatedAbilityDrawSteelCommandBehavior.ExecuteCommandInternal

ActivatedAbilityPowerRollBehavior.s_modificationTypes = {
{text = "None", id = "none", mod = "", value = 0},
{text = "Edge", id = "edge", mod = "1 edge", value = 1},
{text = "Double Edge", id = "double_edge", mod = "2 edge", value = 2},
{text = "Bane", id = "bane", mod = "1 bane", value = -1},
{text = "Double Bane", id = "double_bane", mod = "2 banes", value = -2},
{text = "Tier 3", id = "tier3", mod = "autosuccess", value = 0},
{text = "Tier 1", id = "tier1", mod = "autofailure", value = 0},
{text = "Tier Up", id = "tierup", mod = "tierup", value = 0},
{text = "Tier Down", id = "tierdown", mod = "tierdown", value = 0},
{text = "+1", id = "plusone", mod = "+1", value = 1},
{text = "+2", id = "plustwo", mod = "+2", value = 2},
{text = "+3", id = "plusthree", mod = "+3", value = 3},
{text = "-1", id = "minusone", mod = "-1", value = -1},
{text = "-2", id = "minustwo", mod = "-2", value = -2},
{text = "-3", id = "minusthree", mod = "-3", value = -3},
}

ActivatedAbilityPowerRollBehavior.s_modificationTypesById = {}

local g_modificationIdToText = {}
for _,option in ipairs(ActivatedAbilityPowerRollBehavior.s_modificationTypes) do
    g_modificationIdToText[option.id] = option.text
    ActivatedAbilityPowerRollBehavior.s_modificationTypesById[option.id] = option
end

function ActivatedAbilityPowerRollBehavior:EditorItems(parentPanel)
	local result = {}
	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

    local rollPanel = gui.Panel{
        classes = {"formPanel", cond(self:try_get("resistanceRoll", false), "collapsed")},
        gui.Label{
            classes = {"formLabel"},
            text = "Roll:",
        },

        gui.GoblinScriptInput{
            halign = "right",
            value = self.roll,
            events = {
                change = function(element)
                    self.roll = element.value
                end,
            },

			documentation = {
				help = string.format("This GoblinScript determines the roll to use for the power table."),
				output = "roll",
				examples = {
					{
						script = "2d10 + Might or Agility",
						text = "2d10 + Might or Agility is used for the roll. Whichever is higher out of Might or Agility will be used.",
					},
					{
						script = "2d10 + 4",
						text = "2d10 + 4 is used for the roll.",
					},
				},
				subject = creature.helpSymbols,
				subjectDescription = "The creature that is casting the spell.",
				symbols = ActivatedAbility.helpCasting,
			},
        },
    }

    local resistanceTypePanel
    local resistanceRollCheck = gui.Check{
        text = "Resistance Roll",
        value = self:try_get("resistanceRoll", false),
        change = function(element)
            self.resistanceRoll = element.value
            rollPanel:SetClass("collapsed", self:try_get("resistanceRoll", false))
            resistanceTypePanel:SetClass("collapsed", not self:try_get("resistanceRoll", false))
        end,
    }

    resistanceTypePanel = gui.Panel{
        classes = {"formPanel", cond(self:try_get("resistanceRoll", false), nil, "collapsed")},

        gui.Label{
            classes = {"formLabel"},
            text = "Attribute:",
        },

        gui.Dropdown{
            classes = {"formDropdown"},
            idChosen = self:ResistanceAttr(),
            options = creature.attributeDropdownOptions,
            change = function(element)
                self.resistanceAttr = element.idChosen
            end,
        },
    }

    result[#result+1] = resistanceRollCheck
    result[#result+1] = resistanceTypePanel

    result[#result+1] = rollPanel

    result[#result+1] = gui.Panel{
        width = "100%",
        height = "auto",
        flow = "vertical",

        create = function(element)
            if #element.children == 1 and self:has_key("modifiers") then
                element:FireEvent("refreshBehavior")
            end
        end,

        refreshBehavior = function(element)
            local children = {}
            for i,modifier in ipairs(self:try_get("modifiers", {})) do
                children[#children+1] = gui.Panel{
                    classes = {"formPanel"},
                    gui.Label{
                        classes = {"formLabel"},
                        width = 120,
                        text = g_modificationIdToText[modifier.type],
                        lmargin = 20,
                    },

                    gui.GoblinScriptInput{
                        halign = "right",
                        width = 300,
                        value = modifier.condition,
                        events = {
                            change = function(element)
                                modifier.condition = element.value
                            end,
                        },

                        documentation = {
                            help = string.format("This GoblinScript determines whether the modifier will apply."),
                            output = "boolean",
                            examples = {
                                {
                                    script = "Might > 4",
                                    text = "The modifier will apply if the caster's Might is greater than 4.",
                                },
                            },
                            subject = creature.helpSymbols,
                            subjectDescription = "The creature that is casting the ability.",
                            symbols = ActivatedAbility.helpCasting,
                        },

                    },

                    gui.DeleteItemButton{
                        width = 12,
                        height = 12,
                        hmargin = 8,
                        click = function(element)
                            local modifiers = self:try_get("modifiers", {})
                            table.remove(modifiers, i)
                            parentPanel:FireEvent("refreshBehavior")
                        end,
                    },
                }

                children[#children+1] = gui.Panel{
                    classes = {"formPanel"},
                    gui.Label{
                        classes = {"formLabel"},
                        width = 120,
                        text = "Name:",
                        lmargin = 20,
                    },
                    gui.Input{
                        width = 280,
                        fontSize = 14,
                        hmargin = 0,
                        text = modifier.text,
                        characterLimit = 80,
                        change = function(element)
                            modifier.text = element.text
                        end,
                    }
                }

                children[#children+1] = gui.Panel{
                    classes = {"formPanel"},
                    gui.Label{
                        classes = {"formLabel"},
                        width = 120,
                        text = "Details:",
                        lmargin = 20,
                    },
                    gui.Input{
                        width = 280,
                        fontSize = 14,
                        hmargin = 0,
                        text = modifier.details,
                        characterLimit = 240,
                        change = function(element)
                            modifier.details = element.text
                        end,
                    }
                }

            end

            children[#children+1] = element.children[#element.children]

            element.children = children
        end,

        gui.Panel{
            classes = {"formPanel"},

            gui.Dropdown{
                textOverride = "Add Modifier...",
                classes = {"formDropdown"},

                options = {
                    {text = "Edge", id = "edge"},
                    {text = "Double Edge", id = "double_edge"},
                    {text = "Bane", id = "bane"},
                    {text = "Double Bane", id = "double_bane"},
                },
                idChosen = "none",
                change = function(element)
                    local modifiers = self:get_or_add("modifiers", {})
                    modifiers[#modifiers+1] = {
                        type = element.idChosen,
                        condition = "",
                        text = "",
                    }

                    parentPanel:FireEvent("refreshBehavior")
                end,
            }
        },
    }

    local rows = {}

    for i=1,#g_TierNames do
        local tier = g_TierNames[i]
        rows[#rows+1] = gui.TableRow{
            gui.Label{ text = tier },
            gui.Input{
                text = self.tiers[i],
                characterLimit = 160,
                halign = "right",
                change = function(element)
                    self.tiers[i] = element.text
                end
            },
        }
    end

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        gui.Table{
            width = 400,
            height = "auto",
            flow = "vertical",
            minHeight = 30,
            halign = "left",
            styles = {
                Styles.Table,
                {
                    classes = {"input"},
                    width = 300,
                },

            },

            children = rows,
        }
    }


    return result
end

RegisterGameType("RollPropertiesPowerTable", "RollProperties")

function RollPropertiesPowerTable:ResetMods()
    self.surges = nil
    self.shields = nil
    if self:has_key("baseTiers") == false then
        self.baseTiers = DeepCopy(self.tiers)
    else
        self.tiers = DeepCopy(self.baseTiers)
    end
end

function RollPropertiesPowerTable:GetOutcome(rollInfo)
    local tier = DiceResultToTier(rollInfo)
    return {
        outcome = string.format("Tier %d", tier),
        color = "white",
    }
end

--@param delta number
--@return nil
function RollPropertiesPowerTable:ModifyDamage(damage)
    if damage == 0 then
        return
    end

    for i,tier in ipairs(self.tiers) do
        local match = regex.MatchGroups(tier, "(?<damage>\\d+)\\s+([a-zA-Z]+\\s+)?damage", {indexes = true})
        if match ~= nil then
            local index = match.damage.index
            local length = match.damage.length

            local before = string.sub(tier, 1, index-1)
            local after = string.sub(tier, index+length)

            local damageValue = round(tonumber(match.damage.value))
            damageValue = max(0, round(damageValue + damage))

            self.tiers[i] = string.format("%s%d%s", before, damageValue, after)
        end
    end
end

local g_tableStyles = {
    gui.Style{
        selectors = {"label"},
        color = "#cccccc",
        valign = "center",
    },
    gui.Style{
        selectors = {"row", "highlighted"},
        transitionTime = 1.0,
        bgcolor = Styles.textColor,
    },
    gui.Style{
        selectors = {"label", "parent:highlighted"},
        transitionTime = 1.0,
        color = "black",
    },
	gui.Style{
		selectors = {"row", "flash"},
		brightness = 3,
		transitionTime = 0.3,
	},
    gui.Style{
        selectors = {"label", "parent:collapsedAnim"},
        transitionTime = 0.5,
        uiscale = {x = 1, y = 0.001},
    },
    gui.Style{
        selectors = {"amendable", "row", "hover"},
        bgcolor = "#ff7777",
    },
}

local g_boonsBanesStyles = {
    gui.Style{
        selectors = {"collapsedAnim"},
        transitionTime = 0.5,
        uiscale = {x = 1, y = 0.001},
    },
    gui.Style{
        selectors = {"label"},
        color = Styles.textColor,
        valign = "center",
        width = "20%",
        height = "100%",
        bgimage = "panels/square.png",
        fontSize = 16,
        textAlignment = "center",
        borderWidth = 1,
        borderColor = Styles.textColor,
    },
    gui.Style{
        selectors = {"label", "selected"},
        bgcolor = Styles.textColor,
        color = "black",
        bold = true,
    },
    gui.Style{
        selectors = {"label", "hover", "~selected", "parent:active"},
        bgcolor = Styles.textColor,
        color = "black",
        brightness = 0.9,
    },
}

local g_boonsLabels = {"Bane x 2", "Bane", "None", "Edge", "Edge x 2"}

function RollPropertiesPowerTable:CustomPanel(message)

    local m_resultPanel = nil

    local messageGuid = message.key

    local m_endAt = {}

    local m_activeAmendableRoll = false

    local m_rows = nil

    local m_lastKnownTotal = nil

    local m_listening = {}
    local m_mod = 0
    local m_complete = false

    local m_boons = 0
    local m_banes = 0
    local m_tiers = 0

    local m_boonsBanesPanel = nil
    local boonsBanesLabels = nil

    if not message.isComplete then
        boonsBanesLabels = {}
        for i,text in ipairs(g_boonsLabels) do
            boonsBanesLabels[#boonsBanesLabels+1] = gui.Label{
                text = text,
                fontSize = 14,

                press = function(element)
                    local isActive = g_activeRoll ~= nil and g_activeRoll.amendable and g_activeRoll.guid == messageGuid
                    if isActive  then
                        local oldMod = BoonsAndBanesToMod(m_boons, m_banes)
                        local currentValue = m_boons - m_banes
                        local newValue = i - 3

                        local delta = newValue - currentValue
                        if delta ~= 0 then
                            if delta < 0 then
                                m_banes = m_banes - delta
                            else
                                m_boons = m_boons + delta
                            end

                            if m_banes > 2 then
                                m_boons = m_boons - (m_banes - 2)
                                m_banes = 2
                            end

                            if m_boons > 2 then
                                m_banes = m_banes - (m_boons - 2)
                                m_boons = 2
                            end

                            g_activeRoll = g_activeRoll:Amend{
                                categories = {},
                                amendable = true,
                                boons = m_boons,
                                banes = m_banes,
                            }
                            messageGuid = g_activeRoll.guid

                            if m_lastKnownTotal ~= nil then
                                local newMod = BoonsAndBanesToMod(m_boons, m_banes)

                                local total = m_lastKnownTotal + newMod - oldMod

                                local index = self:try_get("overrideTier") or DiceResultToTier{ total = total, boons = m_boons, banes = m_banes, tiers = m_tiers }
                                if m_rows ~= nil then
                                    for i,row in ipairs(m_rows) do
                                        if row ~=nil and row.valid then
                                            row:SetClassImmediate("highlighted", i == index)
                                        end
                                    end
                                end
                            end

                        end
                    end

                end,
            }
        end

        m_boonsBanesPanel = gui.Panel{
            styles = g_boonsBanesStyles,
            classes = {"boonbanePanel"},
            width = "100%",
            height = 22,
            flow = "horizontal",
            children = boonsBanesLabels,

            collapse = function(element)
                element:SetClass("collapsedAnim", true)
                element:ScheduleEvent("die", 0.5)
                m_boonsBanesPanel = nil
                boonsBanesLabels = nil
            end,

            die = function(element)
                element:DestroySelf()
            end,
        }
    end

    local tbl = gui.Table{
        width = "100%",
        height = "auto",
        halign = "center",
        flow = "vertical",
        styles = {
            Styles.Table,
            g_tableStyles,
        },

        recordInteracting = function(element)
            message:UploadRealtimeInteraction(dmhub.userid, { guid = dmhub.GenerateGuid(), message = dmhub.userDisplayName .. " is reviewing the roll", timestamp = dmhub.serverTime })
        end,

        clearInteracting = function(element)
            message:UploadRealtimeInteraction(dmhub.userid, nil)
        end,

		refreshInfo = function(element, info, diceStyle, complete, rollInfo)
            if m_complete then
                return
            end

            local isActive = g_activeRoll ~= nil and g_activeRoll.amendable and g_activeRoll.guid == messageGuid

            m_tiers = info.tiers or 0
            m_boons = info.boons or 0
            m_banes = info.banes or 0

            if boonsBanesLabels ~= nil then
                local selectedIndex = 3 + m_boons - m_banes
                for i,label in ipairs(boonsBanesLabels) do
                    label:SetClassImmediate("selected", i == selectedIndex)
                end
                m_boonsBanesPanel:SetClass("active", isActive)
            end

            local refreshAmendable = false
            if m_activeAmendableRoll ~= isActive then
                m_activeAmendableRoll = isActive
                refreshAmendable = true

                --make the active roll panel point at this, to record the panel that is doing the roll.
                if isActive then
                    g_activeRollPanel = element
                elseif g_activeRollPanel == element then
                    g_activeRollPanel = nil
                end
            end

            if m_rows == nil then
                m_rows = {}

                m_lastKnownTotal = info.total
                local index = self:try_get("overrideTier") or DiceResultToTier(rollInfo)

                for i, tier in ipairs(self.tiers) do
                    if index == i or (not complete) then
                        m_rows[#m_rows+1] = gui.TableRow{
                            height = "auto",
                            gui.Label{ text = g_TierNames[i], width = 90, height = "auto", },
                            gui.Label{ text = FormatTierText(tier), width = 240, height = "auto", },
                            width = "100%",
                            press = function(element)
                                if element:HasClass("amendable") then
                                    self.overrideTier = i
                                    self.overrideMessage = string.format("%s overrode the result", dmhub.userDisplayName)
                                    message:UploadProperties(self)

                                    for j,row in ipairs(m_rows) do
                                        if row ~=nil and row.valid then
                                            row:SetClassImmediate("highlighted", i == j)
                                        end
                                    end
                                end
                            end,
                            collapse = function(element)
                                element:FireEvent("remove")
                                element:SetClass("collapsedAnim", true)
                                element:ScheduleEvent("destroy", 0.5)
                            end,
                            fade = function(element)
                                element:SetClass("highlighted", false)
                            end,
                            destroy = function(element)
                                element:FireEvent("remove")
                                element:DestroySelf()
                            end,
                            remove = function(element)
                                for i,row in ipairs(m_rows) do
                                    if row == element then
                                        table.remove(m_rows, i)
                                    end
                                end
                            end,
                        }
                    end
                end

                element.children = m_rows
            end


            m_mod = info.mod or 0

            if complete then
                m_complete = true
                m_lastKnownTotal = info.total
                local index = self:try_get("overrideTier") or DiceResultToTier(rollInfo)
                if #m_rows == 3 then
                    for i,row in ipairs(m_rows) do
                        if row ~= nil and row.valid then
                            row:SetClassImmediate("highlighted", i == index)
                            if i == index then
                                row:PulseClass("flash")
                                row:ScheduleEvent("fade", 3)
                            else
                                row:ScheduleEvent("collapse", 1)
                            end
                        end
                    end
                end

                if m_boonsBanesPanel ~= nil then
                    m_boonsBanesPanel:ScheduleEvent("collapse", 1)
                end

                for k,v in pairs(m_listening) do
				    local events = chat.DiceEvents(k)
                    if events ~= nil then
                        events:Unlisten(element)
                    end
                end
            elseif not m_complete then

                for i,roll in ipairs(info.rolls) do
                    if roll.guid ~= nil and roll.guid ~= '' and m_listening[roll.guid] == nil and (not roll.dropped) then
                        m_listening[roll.guid] = true

						local events = chat.DiceEvents(roll.guid)
						if events ~= nil then
							events:Listen(element)
						end
                    end
                end
            end

            if refreshAmendable then
                element:SetClassTree("amendable", m_activeAmendableRoll)
            end
        end,

        diceend = function(element)
            element:FireEventOnParents("forceShowResult")
        end,

		diceface = function(element, diceguid, num, timeRemaining)
            if m_complete or self:has_key("overrideTier") then
                return
            end

            if m_endAt ~= nil then
                local endAt = dmhub.Time() + timeRemaining
                m_endAt[diceguid] = endAt
                local count = 0
                for k,v in pairs(m_endAt) do
                    count = count + 1
                    if m_endAt[diceguid] > endAt then
                        endAt = m_endAt[diceguid]
                    end
                end

                if count == 2 then
                    m_endAt = nil
                    element:ScheduleEvent("diceend", endAt - dmhub.Time())
                end
            end

            m_listening[diceguid] = num

            local total = m_mod
            for k,v in pairs(m_listening) do
                if type(v) == "number" then
                    total = total + v
                end
            end

            m_lastKnownTotal = total
            local index = DiceResultToTier{ total = total, boons = m_boons, banes = m_banes, tiers = m_tiers }
            for i,row in ipairs(m_rows) do
                if row ~=nil and row.valid then
                    row:SetClassImmediate("highlighted", i == index)
                end
            end
        end,
    }

    local m_label = nil
    local m_showingInteraction = false

    m_resultPanel = gui.Panel{
        flow = "vertical",
        width = "100%",
        height = "auto",
		refreshInfo = function(element, info, diceStyle, complete, rollInfo)
            tbl:FireEvent("refreshInfo", info, diceStyle, complete, rollInfo)

            local text = self:try_get("overrideMessage")

            if text ~= nil then
                m_showingInteraction = false
            else
                local interactions = message.realtimeInteractions
                if interactions ~= nil or m_showingInteraction then
                    if complete or interactions == nil then
                        text = nil
                        m_showingInteraction = false
                    else
                        local mostRecent = nil
                        for k,v in pairs(interactions) do
                            if mostRecent == nil or mostRecent.timestamp < v.timestamp then
                                mostRecent = v
                            end
                        end

                        if mostRecent ~= nil and mostRecent.timestamp < dmhub.serverTime - 5 then
                            mostRecent = nil
                        end

                        if mostRecent ~= nil then
                            text = mostRecent.message
                            m_showingInteraction = true
                        else
                            m_showingInteraction = false
                        end
                    end
                end
            end


            if text ~= nil then
                if m_label == nil then
                    m_label = gui.Label{
                        color = Styles.textColor,
                        width = "100%",
                        height = "auto",
                        fontSize = 16,
                        text = text,
                        
                        data = {
                            interacting = false,
                            text = "",
                            count = 0,
                        },

                        updateLabel = function(element, text, interacting)
                            element.data.text = text
                            if interacting ~= element.data.interacting or interacting == false then
                                element.text = text
                            end
                            element.data.interacting = interacting
                            if interacting then
                                element.thinkTime = 0.5
                            else
                                element.thinkTime = nil
                            end
                        end,

                        think = function(element)
                            element.data.count = element.data.count + 1
                            local text = element.data.text
                            for i=1,element.data.count%4 do
                                text = text .. "."
                            end

                            element.text = text
                        end,
                    }
                    local items = {m_label}
                    for _,child in ipairs(element.children) do
                        items[#items+1] = child
                    end

                    element.children = items

                    element:FireEventOnParents("moveToBottomNowAndDelayed")
                    --local chatPanel = element:Get("chat-panel")
                    --chatPanel:FireEvent("keepAtBottom")
                end

                m_label:FireEvent("updateLabel", text, m_showingInteraction)
                m_label:SetClass("collapsed", false)
            elseif m_label ~= nil then
                m_label:SetClass("collapsed", true)
            end
        end,
        tbl,
        m_boonsBanesPanel,
    }

    return m_resultPanel
end


RollCheck.RegisterCustom{
    id = "resistance_power_roll",
    rollType = "resistance_power_roll",
	Describe = function(check, isplayer)
        return "Roll Resistance vs " .. check.info.attrid
    end,
	GetRoll = function(check, creature)
        return "2d10 + " .. creature:AttributeMod(check.info.attrid)
    end,
	GetModifiers = function(check, creature)
        return creature:GetModifiersForPowerRoll(check:GetRoll(creature), "resistance_power_roll:" .. check.info.attrid)
    end,
	ShowDialog = function(check, dialogOptions)
        dialogOptions.rollProperties = RollPropertiesPowerTable.new{
            tiers = DeepCopy(check.info.tiers)
        }
        dialogOptions.PopulateCustom = ActivatedAbilityPowerRollBehavior.GetPowerTablePopulateCustom(dialogOptions.rollProperties, dialogOptions.creature)
        return GameHud.instance.rollDialog.data.ShowDialog(dialogOptions)
    end,
}

function ActivatedAbilityPowerRollBehavior:ResistanceAttr()
    return self:try_get("resistanceAttr", "inu")
end

--cast vs resistance.
function ActivatedAbilityPowerRollBehavior:CastResistance(ability, casterToken, targets, options)
	local tokenids = ActivatedAbility.GetTokenIds(targets)
    local dcaction = ability:RequireSavingThrowsCo(self, casterToken, tokenids, {
        id = "resistance_power_roll",
        rollType = "resistance_power_roll",
        text = "Resistance",
        explanation = "Roll Resistance vs " .. ability.name,
        targets = targets,
        info = {
            attrid = self:ResistanceAttr(),
            tiers = DeepCopy(self.tiers),
        },
    })

    if dcaction == nil then
        --the roll was canceled.
        return
    end

    options.pay = true

    for i,target in ipairs(targets) do
        if target.token ~= nil then
		    local dcinfo = dcaction.info.tokens[target.token.charid]
            if dcinfo ~= nil then
                local tier = DiceResultToTier{ total = dcinfo.result, boons = dcinfo.boons, banes = dcinfo.banes }
                local command = self.tiers[tier]
                self:ExecuteCommand(ability, casterToken, target.token, options, command)
            end
        end
    end
end

RollCheck.RegisterCustom{
    id = "power_roll_custom",
    rollType = "power_roll_custom",
	Describe = function(check, isplayer)
        return check.info.explanation
    end,
	GetRoll = function(check, creature)
        return "2d10 + " .. creature:AttributeMod(check.info.attrid)
    end,
	GetModifiers = function(check, creature)
        return {}
    end,
	ShowDialog = function(check, dialogOptions)
        dialogOptions.rollProperties = RollPropertiesPowerTable.new{
            tiers = DeepCopy(check.info.tiers)
        }
        dialogOptions.PopulateCustom = ActivatedAbilityPowerRollBehavior.GetPowerTablePopulateCustom(dialogOptions.rollProperties, dialogOptions.creature)
        return GameHud.instance.rollDialog.data.ShowDialog(dialogOptions)
    end,
}

--cast custom.
function ActivatedAbilityPowerRollBehavior:CastCustom(ability, casterToken, targets, options)
	local tokenids = ActivatedAbility.GetTokenIds(targets)
    local dcaction = ability:RequireSavingThrowsCo(self, casterToken, tokenids, {
        id = "power_roll_custom",
        rollType = "power_roll_custom",
        text = "Custom Roll",
        explanation = ability.explanation,
        targets = targets,
        info = {
            attrid = self:ResistanceAttr(),
            tiers = DeepCopy(self.tiers),
            explanation = ability.explanation,
        },
    })

    if dcaction == nil then
        --the roll was canceled.
        return
    end

    options.pay = true

    for i,target in ipairs(targets) do
        if target.token ~= nil then
		    local dcinfo = dcaction.info.tokens[target.token.charid]
            if dcinfo ~= nil then
                local tier = DiceResultToTier{ total = dcinfo.result, boons = dcinfo.boons, banes = dcinfo.banes }
                if self:has_key("callback") then
                    self.callback(target.token, tier)
                end
            end
        end
    end
end

function ActivatedAbilityPowerRollBehavior.CustomRoll(options)
    local ability = DeepCopy(MCDMUtils.GetStandardAbility("Ability Power Roll"))
    local explanation = options.explanation or "Custom Power Roll"
    for i,behavior in ipairs(ability.behaviors) do
        if behavior.typeName == "ActivatedAbilityPowerRollBehavior" then
            behavior.tiers = options.tiers
            behavior.resistanceAttr = options.resistanceAttr or behavior.resistanceAttr
            behavior.callback = options.callback
        end
    end

    local targets = {}
    for _,target in ipairs(options.targets) do
        targets[#targets+1] = {
            token = target,
        }
    end

    ability:Cast(options.caster, targets, {
        symbols = {}
    })
end