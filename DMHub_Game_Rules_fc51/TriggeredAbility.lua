local mod = dmhub.GetModLoading()

--This file implements Triggered Abilities. They build heavily on Activated Abilities, just that they occur
--in response to some trigger rather than when the player decides.

RegisterGameType("TriggeredAbility", "ActivatedAbility")

ActivatedAbility.OnTypeRegistered = function()
	TriggeredAbility.Types = {}

	for i,t in ipairs(ActivatedAbility.Types) do
		TriggeredAbility.Types[#TriggeredAbility.Types+1] = t
	end

	TriggeredAbility.Types[#TriggeredAbility.Types+1] = {
		id = 'momentary',
		text = 'Momentary Effect',
		createBehavior = function()
			return ActivatedAbilityApplyMomentaryEffectBehavior.new{
				name = "Momentary Effect",
				momentaryEffect = CharacterOngoingEffect.Create{}
			}
		end,
	}

	TriggeredAbility.TypesById = GetDropdownEnumById(TriggeredAbility.Types)
end

ActivatedAbility.OnTypeRegistered()


TriggeredAbility.TargetTypes = {
	{
		id = 'self',
		text = 'None/Self',
	},
	{
		id = 'all',
		text = 'All Creatures in Range',
	},
	{
		id = 'attacker',
		text = 'Creature Attacking Me',
		condition = function(ability)
			return ability.trigger == "attacked" or ability.trigger == "hit"
		end,
	},
	{
		id = 'target',
		text = 'Target',
		condition = function(ability)
			return ability.trigger == "damage" or ability.silent
		end,
	},
}

TriggeredAbility.triggers = {

	{
		id = "regainhitpoints",
		text = "Regain Hitpoints",
	},
	{
		id = "losehitpoints",
		text = "Lose Hitpoints",
        symbols = {
			damage = {
				name = "Damage",
				type = "number",
				desc = "The amount of damage taken when triggering this event.",
			},
			damagetype = {
				name = "Damage Type",
				type = "text",
				desc = "The type of damage taken when triggering this event.",
			},
            keywords = {
                name = "Keywords",
                type = "set",
                desc = "The keywords used to apply the damage.",
            },
            attacker = {
                name = "Attacker",
                type = "creature",
                desc = "The attacking creature. Only valid if Has Attacker is true.",
            },
            hasattacker = {
                name = "Has Attacker",
                type = "boolean",
                desc = "True if the damage has an attacker.",
            }
        },

        examples = {
            {
				script = "damage > 8 and (damage type is slashing or damage type is piercing)",
				text = "The triggered ability only activates if more than 8 damage was done and the damage was slashing or piercing damage."
			}
        },
	},
	{
		id = "zerohitpoints",
		text = "Drop to Zero Hitpoints",

        symbols = {
			damage = {
				name = "Damage",
				type = "number",
				desc = "The amount of damage taken when triggering this event.",
			},
			damagetype = {
				name = "Damage Type",
				type = "text",
				desc = "The type of damage taken when triggering this event.",
			},
        },

        examples = {
            {
				script = "damage > 8 and (damage type is slashing or damage type is piercing)",
				text = "The triggered ability only activates if more than 8 damage was done and the damage was slashing or piercing damage."
			}
        },

	},
	{
		id = "kill",
		text = "Kill a Creature",
	},
	{
		id = "creaturedeath",
		text = "Creature Dies",
	},
	{
		id = "saveagainstdamage",
		text = "Made Saving Throw Against Damage",
	},
	{
		id = "move",
		text = "Begin Movement",
	},
	{
		id = "finishmove",
		text = "Complete Movement",
	},
    {
        id = "forcemove",
        text = "Force Moved",
    },
    {
        id = "teleport",
        text = "Teleports",
    },
	{
		id = "beginturn",
		text = "Begin Turn",
	},
	{
		id = "endturn",
		text = "End Turn",
	},
	{
		id = "beginround",
		text = "Begin Round",
		hide = function()
			return not GameSystem.HaveBeginRoundTrigger
		end,
	},
	{
		id = "endcombat",
		text = "End of Combat",
	},
	{
		id = "rollinitiative",
		text = "Rolled Initiative",
	},
	{
		id = "attack",
		text = "Attack an Enemy",
	},

	{
		id = "fumble",
		text = "Fumble an Attack",
		hide = function()
			--make sure our attack properties have a "fumble"
			local properties = GameSystem.GetRollProperties("attack", 0)
			for _,outcome in ipairs(properties:Outcomes()) do
				if outcome.failure and outcome.degree > 1 then
					return false
				end
			end

			return true
		end,
	},
	{
		id = "collide",
		text = "Collide with a Creature or Object",
	},
	{
		id = "fall",
		text = "Land from a fall",
	},
}

function TriggeredAbility.GetTriggerById(triggerid)
    for _,trigger in ipairs(TriggeredAbility.triggers) do
        if trigger.id == triggerid then
            return trigger
        end
    end
    
    return nil
end


function TriggeredAbility.RegisterTrigger(trigger)
	local index = #TriggeredAbility.triggers+1
	for i,entry in ipairs(TriggeredAbility.triggers) do
		if entry.id == trigger.id then
			index = i
			break
		end
	end
	TriggeredAbility.triggers[index] = trigger
	table.sort(TriggeredAbility.triggers, function(a,b) return a.text < b.text end)
end

TriggeredAbility.RegisterTrigger{
    id = "dealdamage",
    text = "Damage an Enemy",
    symbols = {
        {
            name = "Damage",
            type = "number",
            desc = "The amount of damage dealt.",
        },
        {
            name = "Damage Type",
            type = "text",
            desc = "The type of damage dealt.",
        },
        {
            name = "Keywords",
            type = "set",
            desc = "The keywords used to apply the damage.",
        },
        {
            name = "Target",
            type = "creature",
            desc = "The target creature.",
        },
    }
}

table.sort(TriggeredAbility.triggers, function(a,b) return a.text < b.text end)

function TriggeredAbility.GetTriggerDropdownOptions(includeNone)
	local result = {}

	if includeNone then
		result[#result+1] = {
			id = "none",
			text = "None",
		}
	end

	for _,item in ipairs(TriggeredAbility.triggers) do
		if item.hide == nil or (not item.hide()) then
			result[#result+1] = item
		end
	end

	table.sort(result, function(a,b)
		return a.text < b.text
	end)

	return result
end

TriggeredAbility.effects = {
	{
		id = "sethitpoints",
		text = "Set Hitpoints",
	}
}

ActivatedAbility.name = ""
ActivatedAbility.castingTime = "none"
TriggeredAbility.conditionFormula = ""
TriggeredAbility.save = 'none'
TriggeredAbility.savedc = '10'
TriggeredAbility.mandatory = true

function TriggeredAbility.OnDeserialize(self)
	ActivatedAbility.OnDeserialize(self)
end

function TriggeredAbility.Create(options)
	options = options or {}
	local args = ActivatedAbility.StandardArgs()
	args.trigger = "losehitpoints"
	for k,op in pairs(options) do
		args[k] = op
	end
	return TriggeredAbility.new(args)
end

local g_triggerDepth = 0
local g_triggerDepthFrame = -1

function TriggeredAbility:subjectHasRequiredCondition(subject, caster)
    if self:try_get("characterConditionRequired", "none") == "none" then
        return true
    end

    local conditionCaster = subject:HasCondition(self.characterConditionRequired)
    if self:try_get("characterConditionInflictedBySelf") then
        return conditionCaster == dmhub.LookupTokenId(caster)
    else
        return conditionCaster ~= false
    end
end

--auraControllerToken: token controlling an aura this is triggered from, or can be nil for a regular trigger attached to the creature it's triggering on.
function TriggeredAbility:Trigger(characterModifier, creature, symbols, auraControllerToken, modContext)

	local casterToken = dmhub.LookupToken(creature)
	if casterToken == nil then
		return
	end

    local subjectTarget = self:try_get("subject", "self")
    local subject = symbols and symbols.subject

    if subject ~= nil and subjectTarget == "self" then
        return
    end

    if subject == nil and subjectTarget ~= "self" and subjectTarget ~= "any" and subjectTarget ~= "selfandallies" and subjectTarget ~= "selfandheroes" then
        return
    end

    if not self:subjectHasRequiredCondition(subject or creature, creature) then
        return
    end

    local subjectToken

    if subject ~= nil then
        subjectToken = dmhub.LookupToken(subject)
        if subjectToken == nil then
            return
        end
        local range = tonumber(self:try_get("subjectRange"))
        if range ~= nil then
            local distance = subjectToken:Distance(casterToken)
            if distance > range then
                --out of range.
                return
            end
        end

        if subjectTarget == "selfandallies" or subjectTarget == "allies" then
            if not casterToken:IsFriend(subjectToken) then
                return
            end
        elseif subjectTarget == "enemy" then
            if casterToken:IsFriend(subjectToken) then
                return
            end
        elseif subjectTarget == "selfandheroes" or subjectTarget == "otherheroes" then
            if not subjectToken.properties:IsHero() then
                return
            end
        end
    end

	modContext = modContext or {}
	symbols = symbols or {}
	if symbols.upcast == nil and modContext.stacks ~= nil then
		symbols.upcast = modContext.stacks-1
	end

    if symbols.subject == nil then
        symbols.subject = creature
    end

	local condition = dmhub.EvalGoblinScript(self.conditionFormula, creature:LookupSymbol(symbols))
	if tonumber(condition) == 0 then
		--we fail the trigger condition
		return
	end

	local targets
	
	if self.targetType == 'all' then
		targets = {}
		local range = self:GetRange()
		for i,tok in ipairs(dmhub.allTokens) do
			if (tok.id ~= casterToken.id or self:try_get("selfTarget", false)) and self:TargetPassesFilter(casterToken, tok) and range+5 > tok:DistanceInFeet(casterToken) then
				targets[#targets+1] = {
					loc = tok.loc,
					token = tok,
				}
			end
		end
	elseif self.targetType == 'attacker' or self.targetType == 'target' then
		if symbols[self.targetType] == nil then
			printf("TRIGGER: No %s found for triggered ability requiring one.", self.targetType)
			return
		end

		local attackerCreature = symbols[self.targetType]("self")
		local attackerToken = dmhub.LookupToken(attackerCreature)

		if attackerToken == nil then
			printf("TRIGGER: No attacker token found for triggered ability requiring one.")
			return
		end
		
		targets = {
			{
				loc = attackerToken.loc,
				token = attackerToken,
			}
		}

	else
		targets = {
			{
				loc = casterToken.loc,
				token = casterToken,
			},
		}
	end

	local options = { symbols = symbols }
	local needCoroutine = self:CastInstantPortion(casterToken, targets, options)
	if not needCoroutine then
		if options.pay then
			self:ConsumeResources(casterToken, {
				costOverride = options.costOverride,
			})

		end

		return
	end

	local nframe = dmhub.FrameCount()

	if nframe ~= g_triggerDepthFrame then
		g_triggerDepth = 0
		g_triggerDepthFrame = nframe
	end

	if g_triggerDepth > 8 then
		printf("Too many triggers stacked in the same frame, aborting.")
		return
	end

	g_triggerDepth = g_triggerDepth + 1


	if dmhub.inCoroutine then
		TriggeredAbility.TriggerCo(self, targets, characterModifier, casterToken, creature, symbols, auraControllerToken, modContext)
	else
		dmhub.Coroutine(TriggeredAbility.TriggerCo, self, targets, characterModifier, casterToken, creature, symbols, auraControllerToken, modContext)
	end

	g_triggerDepth = g_triggerDepth - 1

end

function TriggeredAbility:TriggerCo(targets, characterModifier, casterToken, creature, info, auraControllerToken, modContext)

	if self.save ~= 'none' then
		local tokenInfo = {
			[casterToken.id] = {}
		}

		local savedc = self.savedc
		local creatureLookup = creature:LookupSymbol()
		savedc = tonumber(dmhub.EvalGoblinScript(savedc, creature:LookupSymbol(info))) or 0

		local explanation
		if characterModifier ~= nil then
			explanation = string.format("Roll to trigger %s ability", cond(self.name == "", characterModifier.name, self.name))
		else
			explanation = "Roll for triggered ability"
		end

		local actionid = dmhub.SendActionRequest(RollRequest.new{
			checks = {
				RollCheck.new{
					type = "save",
					explanation = explanation,
					id = self.save,
					dc = savedc,
					text = creature.attributesInfo[self.save].description,
					options = nil,
				},
			},

			tokens = tokenInfo,
		})

		local req = dmhub.GetPlayerActionRequest(actionid)
		while req ~= nil and req.info.tokens[casterToken.id].status ~= 'complete' and req.info.tokens[casterToken.id].status ~= 'cancel' do
			coroutine.yield(0.1)
			req = dmhub.GetPlayerActionRequest(actionid)
		end

		if req == nil or req.info.tokens[casterToken.id].status == 'cancel' then
			return
		end

		if req.info.tokens[casterToken.id].result < savedc then
			--this fails since the save failed.
			return
		end
	end

	if auraControllerToken == nil then
		auraControllerToken = casterToken
	end

	self:Cast(auraControllerToken, targets,

	{
		symbols = info,
		alreadyInCoroutine = true,
		complete = function()
		end,
	}
	)
end

function TriggeredAbility:RenderTokenDependent(token, result)
	local text = ""
	if self.mandatory then
		text = "This ability will activate automatically."
	elseif token.properties:TriggeredAbilityEnabled(self) then
		text = "This ability will activate automatically. Click to prevent it from activating."
	else
		text = "Activation of this ability is disabled. Click to enable it."
	end

	result[#result+1] = gui.Label{
		text = text,
		italics = true,
	}
end
