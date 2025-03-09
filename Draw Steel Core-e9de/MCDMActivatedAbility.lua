local mod = dmhub.GetModLoading()

ActivatedAbility.effectImplemented = true

local g_hoverableGradient = gui.Gradient{
    point_a = {x=0,y=0},
    point_b = {x=1,y=1},
    stops = {
        {
            position = 0,
            color = Styles.backgroundColor,
        },
        {
            position = 12,
            color = Styles.textColor,
        },
    },
}

local g_highlightGradient = gui.Gradient{
    point_a = {x=0,y=0},
    point_b = {x=1,y=1},
    stops = {
        {
            position = 0,
            color = Styles.backgroundColor,
        },
        {
            position = 4,
            color = Styles.textColor,
        },
    },
}

SpellRenderStyles = {
	gui.Style{
		selectors = "#spellInfo",
		width = "100%",
		height = 'auto',
		flow = 'vertical',
		halign = 'left',
		valign = 'center',
	},
	gui.Style{
		selectors = {"hoverable","#spellInfo"},
        bgcolor = "white",
        gradient = g_hoverableGradient,
    },
	gui.Style{
		selectors = {"hoverable","hovered","#spellInfo"},
        gradient = g_highlightGradient,
        transitionTime = 0.2,
    },

    gui.Style{
        selectors = {"heading", "hovered"},
        brightness = 3,
    },

	gui.Style{
		classes = {"label"},
		fontSize = 14,
		color = 'white',
		width = '100%',
		textAlignment = "left",
		height = 'auto',
		halign = 'left',

		textAlignment = 'left',
	},

	gui.Style{
		classes = {"label","#spellName"},
		color = 'white',
        bgimage = "panels/square.png",
        bgcolor = "#843030",
		fontSize = 14,
		width = '100%',
		height = 'auto',
		halign = 'left',
		valign = 'top',
		wrap = true,
		fontWeight = "black",
	},

	gui.Style{
		classes = {"subheading"},
		color = '#bb6666',
		fontSize = 24,
		bold = true,
	},

	gui.Style{
		classes = {"label","#spellSummary"},

		italics = true,
		color = 'white',
		fontSize = 12,
		width = 'auto',
		height = 'auto',
		halign = 'left',
		valign = 'top',
	},

	gui.Style{
		classes = {"divider"},

		bgimage = 'panels/square.png',
		bgcolor = '#666666',
		halign = "left",
		width = '100%',
		height = 1,
		halign = 'center',
		valign = 'top',
		vmargin = 4,
	},
	gui.Style{
		classes = {"description"},
		color = 'white',
		width = '96%',
	},
}

local g_damageTypeColors = {
    sonic = "#ff0088",
    fire = "#ff8888",
    lightning = "#ff8800",
}

ActivatedAbility.KeywordRemappings = {
    Attack = "Strike",
}

function ActivatedAbility.OnDeserialize(self)
	if not self:has_key("behaviors") then
		self.behaviors = {}
	end

    for k,v in pairs(ActivatedAbility.KeywordRemappings) do
        if self.keywords[k] then
            self.keywords[v] = true
            self.keywords[k] = nil
        end
    end
end

function ActivatedAbility:AddKeyword(keyword)
    keyword = ActivatedAbility.KeywordRemappings[keyword] or keyword
	if self.keywords == ActivatedAbility.keywords then
		self.keywords = {}
	end
	self.keywords[keyword] = true
end

function ActivatedAbility:HasKeyword(keyword)
    keyword = ActivatedAbility.KeywordRemappings[keyword] or keyword
	return self.keywords[keyword] == true
end

function ActivatedAbility:RemoveKeyword(keyword)
    keyword = ActivatedAbility.KeywordRemappings[keyword] or keyword
	self.keywords[keyword] = nil
end



RegisterGoblinScriptSymbol(ActivatedAbility, {
	name = "Keywords",
	type = "set",
	desc = "The keywords this ability has.",
	examples = {"Ability.Keywords has 'Ranged'", "Ability.Keywords has 'Attack'"},
	calculate = function(c)
		local strings = {}
		for k,v in pairs(c.keywords) do
			strings[#strings+1] = string.lower(k)
		end

		return StringSet.new{
			strings = strings,
		}
	end,
})

function ActivatedAbility:HasAttack()
	return self:HasKeyword("Strike")
end

function ActivatedAbility:IsManeuver()
    local resourceTable = dmhub.GetTable(CharacterResource.tableName)
    local resourceInfo = resourceTable[self:ActionResource()]
	return resourceInfo ~= nil and resourceInfo.name == "Maneuver"
end

function ActivatedAbility:Render(options, params)

	params = params or {}
	options = options or {}

	local summary = options.summary
	options.summary = nil

    local selectable = options.selectable
    options.selectable = nil

    local creatureProperties = nil
    if params.token ~= nil then
        creatureProperties = params.token.properties
    end

    local attackBehavior = nil
    for _,behavior in ipairs(self.behaviors) do
        if behavior.typeName == "ActivatedAbilityAttackBehavior" then
            attackBehavior = behavior
            break
        end
    end

	local powerTableBehavior = nil
    for _,behavior in ipairs(self.behaviors) do
        if behavior.typeName == "ActivatedAbilityPowerRollBehavior" then
            powerTableBehavior = behavior
            break
		elseif behavior.typeName == "ActivatedAbilityInvokeAbilityBehavior" and behavior.abilityType == "custom" then
			--if we invoke a power roll ability try to pull that out.
			for _,subbehavior in ipairs(behavior.customAbility.behaviors) do
        		if subbehavior.typeName == "ActivatedAbilityPowerRollBehavior" then
					powerTableBehavior = subbehavior
				end
			end

        end
	end

	local powerRollLabel = nil
	local powerRollTable = nil

    local rulesNotes = {}

	if powerTableBehavior ~= nil then
        local c = nil
        if params.token ~= nil then
            c = params.token.properties
        end

		local roll = powerTableBehavior:DescribeRoll(c, self)

        local triangleBlack = nil
        if not string.find(roll, "2d6") then
            triangleBlack = gui.Panel{
                floating = true,
                rotate = 90,
                width = 6,
                height = 6,
                valign = "center",
                halign = "center",
                bgimage = "panels/triangle.png",
                bgcolor = "black",
            }
        end

        powerRollLabel = gui.Label{
            text = string.format("<b>Roll <u>%s</u></b>:", roll),
			create = function(element)
				if powerTableBehavior:try_get("resistanceRoll", false) then
					element.text = string.format("<b>Target makes a %s resistance roll:</b>", creature.attributesInfo[powerTableBehavior:ResistanceAttr()].description)
				else
            		element.text = string.format("<b>Roll <u>%s</u></b>:", roll)
				end
			end,
			tmargin = 16,

            gui.Panel{
                floating = true,
                rotate = 90,
                width = 8,
                height = 8,
				halign = "left",
                valign = "center",
                x = -10,
                bgimage = "panels/triangle.png",
                bgcolor = "white",
                triangleBlack,
            }
        }

		local rows = {}

		for i,entry in ipairs(powerTableBehavior.tiers) do
			rows[#rows+1] = gui.TableRow{
                width = "100%",
                height = "auto",
				gui.Label{
					text = powerTableBehavior.tierNames[i],
					width = 80,
					valign = "top",
				},

				gui.Label{
					text = ActivatedAbilityDrawSteelCommandBehavior.DisplayRuleTextForCreature(creatureProperties, entry, rulesNotes),
                    markdown = true,
					bold = true,
                    hpad = 4,
                    height = "auto",
					width = (tonumber(options.width) or 600)-100,
					valign = "top",
				}
			}
		end

		powerRollTable = gui.Table{
			width = "100%",
			height = "auto",
			flow = "vertical",
			children = rows,
		}
	end

    local damageLabel = nil

	--TODO: Remove this?
    if attackBehavior ~= nil then
        local c = nil
        if params.token ~= nil then
            c = params.token.properties
        end
        local roll = attackBehavior:DescribeRoll(c, self)
        if attackBehavior.damageType ~= "normal" then
            roll = string.format("%s %s", roll, attackBehavior.damageType)
        end

        local damageColor = g_damageTypeColors[attackBehavior.damageType] or "#ffffff"

        local triangleBlack = nil
        if not string.find(roll, "2d6") then
            triangleBlack = gui.Panel{
                floating = true,
                rotate = 90,
                width = 6,
                height = 6,
                valign = "center",
                halign = "center",
                bgimage = "panels/triangle.png",
                bgcolor = "black",
            }
        end

        damageLabel = gui.Label{
            text = string.format("<b>Damage:</b> <i><color=%s><u>%s</u></color></i>", damageColor, roll),

            gui.Panel{
                floating = true,
                rotate = 90,
                width = 8,
                height = 8,
				halign = "left",
                valign = "center",
                x = -10,
                bgimage = "panels/triangle.png",
                bgcolor = "white",
                triangleBlack,
            }
        }

    end

	--if we have a specific token and there is an aura associated with this ability, add some information about the aura.
	local tokenDependentInfoPanel = nil
	if params.token ~= nil and params.token.properties ~= nil then
		local tokenDependentChildren = {}

		local cost = self:GetCost(params.token)
		if cost.outOfAmmo then
			tokenDependentChildren[#tokenDependentChildren+1] = gui.Label{
				color = "#ffaaaa",
				text = "Out of Ammo",
			}
		end

		if cost.moveCost ~= nil then
			local labelColor = cond(cost.cannotMove, "#ffaaaa", "#aaaaaa")
			local text = string.format("Consumes %s %s of movement", MeasurementSystem.NativeToDisplayString(cost.moveCost), MeasurementSystem.Abbrev())
			if params.token.properties:CurrentMovementSpeed() <= 0 then
				text = "Cannot Move"
			end

			tokenDependentChildren[#tokenDependentChildren+1] = gui.Label{
				color = labelColor,
				text = text,
			}
		end

		if self:try_get("auraid") ~= nil then
			local aura = params.token.properties:GetAura(self.auraid)
			if aura ~= nil then
				tokenDependentChildren[#tokenDependentChildren+1] = gui.Label{
					id = "auraInfo",
					create = function(element)
						local concentrationText = ""
						if params.token.properties:HasConcentration() and params.token.properties.concentration:try_get("auraid") == self.auraid then
							concentrationText = "\nConcentrating on this spell"
						end

						local roundsSince = aura.time:RoundsSince()
						local castTimeText = "this round"
						if roundsSince == 1 then
							castTimeText = "last round"
						elseif roundsSince > 1 then
							castTimeText = string.format("%d rounds ago", roundsSince)
						end
						if aura:has_key("duration") then
							local remainingRounds = aura.duration - roundsSince
							local expiresText = "this round"
							if remainingRounds == 1 then
								expiresText = "next round"
							elseif remainingRounds > 1 then
								expiresText = string.format("in %d rounds", remainingRounds)
							end

							element.text = string.format("Effect cast %s, expires %s%s", castTimeText, expiresText, concentrationText)

						else
							element.text = string.format("Effect cast %s, lasts indefinitely", castTimeText, concentrationText)
						end
					end,
				}
			end
		end

		for _,entry in ipairs(self:try_get("modificationLog", {})) do
			tokenDependentChildren[#tokenDependentChildren+1] = gui.Label{
				text = entry,
				color = "#aaffaa",
			}
		end

        local seenRules = {}
        for _,entry in ipairs(rulesNotes) do
            if seenRules[entry] == nil then
                seenRules[entry] = true
                tokenDependentChildren[#tokenDependentChildren+1] = gui.Label{
                    text = entry,
                }
            end
        end

		self:RenderTokenDependent(params.token, tokenDependentChildren)

		if #tokenDependentChildren > 0 then
			tokenDependentInfoPanel = gui.Panel{
				width = "100%",
				height = "auto",
				flow = "vertical",
				tmargin = 6,
				hmargin = 8,
				children = tokenDependentChildren,
			}
		end
	end

	local description = self.description
	if description ~= "" and self.effectImplemented == false and ActivatedAbilityDrawSteelCommandBehavior.ValidateRule(description) ~= true then
		description = string.format("<alpha=#55>%s<alpha=#ff>", description)
	end

	if self:try_get("modifyDescriptions") ~= nil then
		for _,desc in ipairs(self.modifyDescriptions) do
			description = string.format("%s\n<color=#aaaaff>%s</color>", description, desc)
		end
	end

    local costText = ""

    local headingColor = "#843030"



	if params.token ~= nil and params.token.properties ~= nil then
        local knownRefreshTypes = {rest = true, encounter = true, day = true}
        --look for a cost with a description, this means an ability that has a specific limit per refresh type.
        local costInfo = self:GetCost(params.token)
		for i,entry in ipairs(costInfo.details) do
            if entry.description ~= nil and knownRefreshTypes[entry.refreshType] then
				--costText is disabled for now. We show recharge instead.
                --costText = string.format(" [%s/%s]", tostring(entry.maxCharges), entry.refreshType)
                headingColor = "#5e4a43"
            end
        end
    end

    local resourceTable = dmhub.GetTable(CharacterResource.tableName)

	if self:has_key("resourceCost") and self:has_key("resourceNumber") then
		local resourceInfo = resourceTable[self.resourceCost]
		if resourceInfo ~= nil then
			local name = resourceInfo.name
			costText = string.format(" %d %s", self.resourceNumber, name)
		end
	end

    local actionText = ""
    local resourceInfo = resourceTable[self:ActionResource()]
	if self:has_key("villainAction") then
		actionText = self.villainAction
	elseif resourceInfo == nil then
        actionText = "Free"
    else
        actionText = resourceInfo.name
    end

    if actionText == "Maneuver" then
        headingColor = "#303084"
    end


    local keywords = {}

    for keyword,_ in pairs(self.keywords) do
        keywords[#keywords+1] = keyword
    end

    table.sort(keywords, function(a,b) return a < b end)

    local keywordText = "-"
    if #keywords > 0 then
        keywordText = table.concat(keywords, ", ")
    end


    local descriptionLabel = nil
    
    if trim(description) ~= "" then
        descriptionLabel = gui.Label{
            markdown = true,
            text = string.format("<b>Effect:</b> %s", description),
        }
    end

    local labels = {
		gui.Label{
			text = string.format("<i>%s</i>", self:try_get("flavor", "")),
			width = "100%-80",
		},
		gui.Label{
			text = string.format("<b>Keywords:</b> <i>%s</i>", keywordText),
		},

		gui.Label{
			text = string.format("<b>Distance:</b> <i>%s</i>", self:DescribeRange(creatureProperties)),
		},

		gui.Label{
			text = string.format("<b>Target:</b> <i>%s</i>", self:DescribeTarget(creatureProperties)),
		},

        damageLabel,

		powerRollLabel,
		powerRollTable,

        descriptionLabel,
    }

	local rechargeText = ""
	if tonumber(self.recharge) ~= nil then
		rechargeText = string.format("%d/Encounter: ", round(self.recharge))
	elseif self.recharge then
		rechargeText = "Recharge: "
	end

    local meleeOrRangedVariantText = ""
    if self:try_get("isMeleeVariation") then
        meleeOrRangedVariantText = " (Melee)"
    elseif self:try_get("isRangedVariation") then
        meleeOrRangedVariantText = " (Ranged)"
    end

	local args = {
		id = 'spellInfo',
		styles = SpellRenderStyles,

		gui.Panel{
			id = "headerPanel",
			flow = "horizontal",
			valign = "top",
			width = "100%",
			height = "auto",

			gui.Panel{
				flow = "vertical",
				valign = "left",
				width = "100%",
				height = "auto",
				gui.Label{
                    classes = {"heading"},
					width = "100%",
					id = "spellName",
                    bgcolor = headingColor,
					text = string.format("<b><smallcaps>%s%s</smallcaps>%s</b>%s", rechargeText, self.name, meleeOrRangedVariantText, costText),

                    gui.Panel{
                        floating = true,
                        hmargin = 16,
                        halign = "right",
                        width = "auto",
                        flow = "vertical",
                        valign = "top",
                        gui.Panel{
                            bgimage = "panels/square.png",
                            bgcolor = "black",
                            vmargin = 0,
                            hmargin = 0,
                            width = 28,
                            height = 28,
                            valign = "top",
                            halign = "right",

                            gui.Panel{
                                width = "100%",
                                height = "100%",
                                selfStyle = self.display,
                                bgimage = self.iconid,
                            }
                        },
                        gui.Label{
                            smallcaps = true,
                            bold = true,
                            fontSize = 12,
                            width = "auto",
                            height = "auto",
							valign = "top",
                            halign = "right",
                            text = actionText,
                        },
                    },
				},

                gui.Panel{
                    flow = "vertical",
                    width = "100%-16",
                    height = "auto",
                    lmargin = 16,

                    children = labels,
                },

				tokenDependentInfoPanel,
			},
		},
	}

    if selectable then
        args.bgimage = "panels/square.png"
        args.hover = function(element)
            element:SetClassTree("hovered", true)
        end
        args.dehover = function(element)
            element:SetClassTree("hovered", false)
        end
    end

	for k,op in pairs(options) do
		args[k] = op
	end

	local result = gui.Panel(args)
    if selectable then
        result:SetClassTree("hoverable", true)
        for _,child in ipairs(result.children) do
            child:MakeNonInteractiveRecursive()
        end
    else
	    result:MakeNonInteractiveRecursive()
    end
	return result
end

function ActivatedAbility:DescribeRange(castingCreature)
	if self.targetType == 'self' then
		return 'Self'
	end

    local range = self:GetRange(castingCreature)

    if self.targetType == "cube" then
        return string.format("%s cube within %s", MeasurementSystem.NativeToDisplayString(self:try_get("radius", 5)), MeasurementSystem.NativeToDisplayStringWithUnits(range))
    elseif self.targetType == "line" then
        return string.format("%s x %s line within 1 square", MeasurementSystem.NativeToDisplayString(range), MeasurementSystem.NativeToDisplayString(self:try_get("radius", 5)))
	elseif self.targetType == "all" then
		return string.format("%s burst", MeasurementSystem.NativeToDisplayString(range))
    end

    local result = MeasurementSystem.NativeToDisplayString(range)

    if self:IsMelee() then
        result = string.format("Melee %s", result)
    end

    return result
end

function ActivatedAbility:DescribeTarget()
	local result
    if self.targetType == "cube" or self.targetType == "line" or self.targetType == "all" or self.targetType == "sphere" or self.targetType == "cylinder" then
		if string.lower(self:try_get("targetFilter", "")) == "enemy" then
			result =  "Each enemy"
		elseif string.lower(self:try_get("targetFilter", "")) == "not enemy" then
			if self:try_get("selfTarget") then
				result = "Self and each ally"
			else
				result = "Each ally"
			end
		else
        	result = "Each creature"
		end
    elseif self.targetType == "target" then
        local count = tonumber(self.numTargets) or 1
        if count <= 1 then
            result = "1 creature or object"
        else
            result = string.format("%d creatures", round(count))
        end
    elseif self.targetType == "self" then
        result = "None/self"
	else
    	result = "1 square"
    end

	if self:has_key("targetAdditionalCriteria") then
		result = string.format("%s <color=#aaaaaa>%s</color>", result, self.targetAdditionalCriteria)
	end

	return result
end

function ActivatedAbility:IsForcedMovement()
	if self:try_get("invoker") == nil then
		--forced movement is always invoked by another creature.
		return false
	end

	if #self.behaviors == 0 or self.behaviors[1].typeName ~= "ActivatedAbilityRelocateCreatureBehavior" then
		return false
	end

	return true
end

function ActivatedAbility:CanTargetAdditionalTimes(casterToken, symbols, targets, targetToken)
    if self.repeatTargets then
        return true
    end

    if casterToken.properties.minion and self.categorization == "Signature Ability" and casterToken.properties:has_key("_tmp_minionSquad") then
        --signature abilities can 'stack' targeting up to three times.
        local currentTimes = 0
        for _,target in ipairs(targets) do
            if target == targetToken.id then
                currentTimes = currentTimes + 1
            end
        end

        return currentTimes < 3
    end

    return false
end

local function GetTargetsWithTokens(targets)
    local result = {}
    for _,target in ipairs(targets) do
        if target.token ~= nil then
            result[#result+1] = target
        end
    end

    return result
end

---@param squad Token[] The squad of minions who will do the targeting.
---@param squadTargetsPerToken table<string, boolean>[] for each token, the locs that token can target (encoded as strings)
---@param targets table<{token: Token}> the targets.
---@param targetLocsOccupying table<string, boolean>[] the locs that the targets occupy. parallel with "targets".
---@param output Token[][] The permutations of possibly unused tokens who are still available to target.
---@param outputTargetingCombinations table<{a: Token, b: Token}>[][]|nil An array of combinations of possible targeting of minions to targets.
---@param currentCombinationInternal table<{a: Token, b: Token}>[]|nil The current combination of minions to targets. Optional and for internal use only.
local function GetSquadTargetPermutations(squad, squadTargetsPerToken, targets, targetLocsOccupying, output, outputTargetingCombinations, currentCombinationInternal)
    if currentCombinationInternal == nil then
        currentCombinationInternal = {}
    end

    if #targetLocsOccupying == 0 then
        table.sort(squad, function(a,b) return a.charid < b.charid end)
        for _,candidate in ipairs(output) do
            local match = true
            for i=1,#candidate do
                if candidate[i].charid ~= squad[i].charid then
                    match = false
                    break
                end
            end

            if match then
                return
            end
        end
        output[#output+1] = squad

        if outputTargetingCombinations ~= nil then
            outputTargetingCombinations[#outputTargetingCombinations+1] = table.shallow_copy(currentCombinationInternal)
        end
        return
    end

    local targetLocs = targetLocsOccupying[1]

    for i,token in ipairs(squad) do
        local canTarget = false
        for key,_ in pairs(targetLocs) do
            if squadTargetsPerToken[i][key] then
                canTarget = true
                break
            end
        end

        if canTarget then
            local newSquad = {}
            local newSquadTargets = {}
            for j,tok in ipairs(squad) do
                if i ~= j then
                    newSquad[#newSquad+1] = tok
                    newSquadTargets[#newSquadTargets+1] = squadTargetsPerToken[j]
                end
            end

            local newTargets = {}
            local newTargetLocsOccupying = {}
            for i=2,#targetLocsOccupying do
                newTargetLocsOccupying[#newTargetLocsOccupying+1] = targetLocsOccupying[i]
                newTargets[#newTargets+1] = targets[i]
            end

            currentCombinationInternal[#currentCombinationInternal+1] = {a = token, b = targets[1].token}

            GetSquadTargetPermutations(newSquad, newSquadTargets, newTargets, newTargetLocsOccupying, output, outputTargetingCombinations, currentCombinationInternal)

            currentCombinationInternal[#currentCombinationInternal] = nil
        end
    end
end

---@param casterToken Token The token that is casting the ability.
---@param range number The range of the ability.
---@param symbols table<string, any> The symbols for the ability.
---@param targets table<{target: Token}>[] The targets of the ability.
---@return table<{a: Token, b: Token}>[]|nil The possible targeting combinations of minions to targets.
function ActivatedAbility:GetTargetingRays(casterToken, range, symbols, targets)
    if casterToken.properties.minion and self.categorization == "Signature Ability" and casterToken.properties:has_key("_tmp_minionSquad") then
        local locations = {}
        local squad = casterToken.properties._tmp_minionSquad
        local squadTokens = table.shallow_copy(squad.tokens)

        --put the caster token at the front so they'll get priority.
        for i,tok in ipairs(squadTokens) do
            if tok.id == casterToken.id then
                table.remove(squadTokens, i)
                table.insert(squadTokens, 1, tok)
                break
            end
        end

        targets = GetTargetsWithTokens(targets)

        local targetLocsOccupying = {}
        for _,target in ipairs(targets) do
            local locs = {}
            for _,loc in ipairs(target.token.locsOccupying) do
                locs[loc.str] = true
            end

            targetLocsOccupying[#targetLocsOccupying+1] = locs
        end

        local possibleTargetsForEachToken = {}
        for _,tok in ipairs(squadTokens) do
            if tok ~= nil and tok.valid then
                local shape = dmhub.CalculateShape{
                    shape = "radiusfromcreature",
                    token = tok,
                    radius = range,
                }

                local locs = {}
                for _,loc in ipairs(shape.locations) do
                    locs[loc.str] = true
                end

                possibleTargetsForEachToken[#possibleTargetsForEachToken+1] = locs
            else
                possibleTargetsForEachToken[#possibleTargetsForEachToken+1] = {}
            end
        end

        local possibleSquads = {}
        local targetCombinations = {}
        GetSquadTargetPermutations(squadTokens, possibleTargetsForEachToken, targets, targetLocsOccupying, possibleSquads, targetCombinations)

        local targeting = {}
        if #targetCombinations > 0 then
            for j,target in ipairs(targetCombinations[1]) do
                targeting[#targeting+1] = {a = target.a.id, b = target.b.id}
            end
        end

        if #targetCombinations > 0 then
            print("REPLACE:: COMBINATIONS: ", #targetCombinations[1])
            return targetCombinations[1]
        end
    end

    return nil
end

function ActivatedAbility:PrepareTargets(casterToken, symbols, targets)
    if casterToken.properties.minion and self.categorization == "Signature Ability" and casterToken.properties:has_key("_tmp_minionSquad") then
        --minion squad signature abilities will combine multiple instances
        --if the same target into one target with a multiple 'addedStacks' count.
        local result = {}

        for _,target in ipairs(targets) do
            local found = false
            for _,existing in ipairs(result) do
                if target.token ~= nil and existing.token ~= nil and target.token.id == existing.token.id then
                    existing.addedStacks = (existing.addedStacks or 0) + 1
                    found = true
                    break
                end
            end

            if not found then
                result[#result+1] = target
            end
        end

        return result
    end

    return targets
end


local g_customTargetShapeFunction = ActivatedAbility.CustomTargetShape

function ActivatedAbility:CustomTargetShape(casterToken, range, symbols, targets)
    if (not mod.unloaded) and casterToken.properties.minion and self.categorization == "Signature Ability" and casterToken.properties:has_key("_tmp_minionSquad") then

        local locations = {}
        local squad = casterToken.properties._tmp_minionSquad
        local squadTokens = table.shallow_copy(squad.tokens)

        targets = GetTargetsWithTokens(targets)

        local targetLocsOccupying = {}
        for _,target in ipairs(targets) do
            local locs = {}
            for _,loc in ipairs(target.token.locsOccupying) do
                locs[loc.str] = true
            end

            targetLocsOccupying[#targetLocsOccupying+1] = locs
        end

        local possibleTargetsForEachToken = {}
        for _,tok in ipairs(squadTokens) do
            if tok ~= nil and tok.valid then
                local shape = dmhub.CalculateShape{
                    shape = "radiusfromcreature",
                    token = tok,
                    radius = range,
                }

                local locs = {}
                for _,loc in ipairs(shape.locations) do
                    locs[loc.str] = true
                end

                possibleTargetsForEachToken[#possibleTargetsForEachToken+1] = locs
            else
                possibleTargetsForEachToken[#possibleTargetsForEachToken+1] = {}
            end
        end

        local possibleSquads = {}
        GetSquadTargetPermutations(squadTokens, possibleTargetsForEachToken, targets, targetLocsOccupying, possibleSquads)

        local usableSquadMembers = {}
        for _,memberList in ipairs(possibleSquads) do
            for _,member in ipairs(memberList) do
                local alreadyCounted = false
                for _,existing in ipairs(usableSquadMembers) do
                    if existing.charid == member.charid then
                        alreadyCounted = true
                        break
                    end
                end

                if not alreadyCounted then
                    usableSquadMembers[#usableSquadMembers+1] = member
                end
            end
        end

        for _,tok in ipairs(usableSquadMembers) do
            if tok ~= nil and tok.valid then
                local shape = dmhub.CalculateShape{
                    shape = "radiusfromcreature",
                    token = tok,
                    radius = range,
                }

                local locs = shape.locations
                for _,loc in ipairs(locs) do
                    locations[#locations+1] = loc
                end
            end
        end

        return locations
    end

    return g_customTargetShapeFunction(self, casterToken, range, symbols)
end

local g_numTargetsFunction = ActivatedAbility.GetNumTargets

function ActivatedAbility:GetNumTargets(casterToken, symbols)
    local result = g_numTargetsFunction(self, casterToken, symbols)

    if (not mod.unloaded) and casterToken.properties.minion and self.categorization == "Signature Ability" and result == 1 and casterToken.properties:has_key("_tmp_minionSquad") then
        --minion signature abilities can target one target for each member of the squad.
        return casterToken.properties._tmp_minionSquad.liveMinions
    end

    return result
end

local g_moreTargetsFunction = ActivatedAbility.CanSelectMoreTargets

function ActivatedAbility:CanSelectMoreTargets(casterToken, targets, symbols)
    if not mod.unloaded then
        if casterToken.properties.minion and self.categorization == "Signature Ability" then

            
        end
        
    end

    return g_moreTargetsFunction(self, casterToken, targets, symbols)
end

function ActivatedAbility:PromptText(casterToken, targets, symbols, synthesizedSpells)
	if self:try_get("promptOverride") ~= nil then
		return self.promptOverride
	end

	if synthesizedSpells ~= nil then
		if #synthesizedSpells == 0 then
			return "No valid abilities"
		else
			if self.meleeAndRanged then
				return "Choose Melee or Ranged"
			end
			return "Choose an ability"
		end
	end

	if self:try_get("attackOverride") ~= nil and self.attackOverride:try_get("ammoType") ~= nil then
		return ""
	end

	if self.targetType == 'all' then
		return ""
	end

	local numTargets = self:GetNumTargets(casterToken, symbols)
	if numTargets == 0 then
		return ""
	end

	if numTargets == 1 and #targets == 0 then
		return nil
	end

	if numTargets >= 99 then
		return "Choose Targets"
	end

	if self.sequentialTargeting and symbols.targetnumber ~= nil and symbols.targetcount ~= nil then
		return string.format("Choose Target %d/%d", symbols.targetnumber, symbols.targetcount)
	end

	return string.format("Choose Target %d/%d", #targets+1, numTargets)
	
end

function ActivatedAbility:AffectedByCover(caster)
	if self.keywords["Ranged"] then
		return true
	end

	local behaviors = self:try_get("behaviors", {})
	for _,behavior in ipairs(behaviors) do
		if behavior:AffectedByCover(caster, self) then
			return true
		end
	end

	return false
end

GameSystem.RegisterGoblinScriptField{
	target = ActivatedAbility,
	name = "Categorization",
	type = "text",
	desc = "The categorization of this ability.",
	seealso = {},
	examples = {},
	calculate = function(c)
		return c.categorization
	end,
}

GameSystem.RegisterGoblinScriptField{
	target = ActivatedAbility,
	name = "Keywords",
	type = "set",
	desc = "The keywords this ability has.",
	seealso = {},
	examples = {},
	calculate = function(c)
		local strings = {}

		for keyword,_ in pairs(c.keywords) do
			strings[#strings+1] = keyword
		end

		return StringSet.new{
			strings = strings,
		}
	end,
}

ActivatedAbility.meleeAndRanged = false

function ActivatedAbility:GetTypeIconForActionBar()
    if self:try_get("isMeleeVariation") then
        return "ui-icons/skills/melee-attack-icon.png"
    elseif self:try_get("isRangedVariation") then
        return "ui-icons/skills/ranged-attack-icon.png"
    end
    return nil
end

--if this ability is both melee and ranged we create a temporary clone
--which has each variation and return it.
function ActivatedAbility:BifurcateIntoMeleeAndRanged(creature)
	if (not self:HasKeyword("Melee")) or (not self:HasKeyword("Ranged")) then
		return self
	end

	if self.meleeAndRanged then
		--already done.
		return self
	end

	local result = self:MakeTemporaryClone()

	local melee = DeepCopy(result)
	local ranged = DeepCopy(result)
	melee.keywords["Ranged"] = nil
	ranged.keywords["Melee"] = nil
	melee.range = math.max(creature:GetReach(), self:try_get("meleeRange", 0))

    melee.isMeleeVariation = true
    ranged.isRangedVariation = true

	result.meleeAndRanged = true

	result.meleeVariation = melee
	result.rangedVariation = ranged

	return result
end

--we synthesize melee/ranged abilities into different abilities for each.
function ActivatedAbility:SynthesizeAbilities(creature)

	if #self.behaviors > 0 then
		local result = self.behaviors[1]:SynthesizeAbilities(self, creature)
		if result ~= nil then
			return result
		end
	end

	return nil
end

creature.preferRanged = false

function ActivatedAbility:GetVariations(token)
	if self.meleeAndRanged then
		return {self.meleeVariation, self.rangedVariation}
	end

	return nil
end

function ActivatedAbility:GetActiveVariation(token)
	if self.meleeAndRanged then
		if token.properties.preferRanged then
			return self.rangedVariation
		else
			return self.meleeVariation
		end
	end

	return self
end

function ActivatedAbility:SetActiveVariation(token, variation)
	if self.meleeAndRanged then
		token:ModifyProperties{
			description = "Change stance",
			execute = function()
				if variation == self.meleeVariation then
					token.properties.preferRanged = false
				elseif variation == self.rangedVariation then
					token.properties.preferRanged = true
				end
			end,
		}
	end
end

function ActivatedAbility:DisplayOrder()
    return self:try_get("villainAction", "") .. self.name
end

function ActivatedAbility:GetRange(casterCreature, castingSymbols, selfRange)
	if selfRange == nil or selfRange == "" then
		selfRange = self.range
	end

	local result = nil
	if type(selfRange) == "string" and string.lower(selfRange) == "touch" then
		result = dmhub.unitsPerSquare
	elseif type(selfRange) == "number" then
		result = selfRange
	elseif type(selfRange) == "string" then
		local n = tonumber(selfRange)
		if n ~= nil then
			result = n
		else
			local _,_,range = string.find(selfRange, "^(%d+) feet$")
			if range ~= nil then
				result = tonumber(range)
			end
		end
	end

	if result == nil then
		local caster = casterCreature or self:try_get("_tmp_boundCaster")
		if caster == nil then
			if type(selfRange) == "string" then
				local _,_,range = string.find(selfRange, "^(%d+)")
				if range ~= nil then
					result = tonumber(range)
				end
			end

			--this means we really couldn't work out the range.
			if result == nil then
				result = dmhub.unitsPerSquare
			end
		else

			castingSymbols = castingSymbols or {}
			local symbols = {
				ability = self,
				mode = castingSymbols.mode or 1,
				charges = castingSymbols.charges or 1,
				upcast = castingSymbols.upcast or 0,
			}
			result = dmhub.EvalGoblinScriptDeterministic(selfRange, caster:LookupSymbol(symbols))
		end
	end

	if result == nil then
		result = dmhub.unitsPerSquare
	end

    if casterCreature ~= nil and self:HasKeyword("Ranged") then
        local bonusRange = casterCreature:BonusRange()
        if bonusRange ~= nil then
            result = result + bonusRange
        end
    end

	return result
end