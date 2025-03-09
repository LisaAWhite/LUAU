local mod = dmhub.GetModLoading()

CharacterModifier.DeregisterType("d20")

local g_powerRollTypes = {
    {
        id = "all",
        text = "All Our Power Rolls",
    },
    {
        id = "ability_power_roll",
        text = "Ability Rolls",
    },
    {
        id = "test_power_roll",
        text = "Tests",
    },
    {
        id = "resistance_power_roll",
        text = "Resistance Rolls",
    },
    {
        id = "enemy_ability_power_roll",
        text = "Enemy Ability Rolls vs Us",
    },
}

local function RollTypeMatches(modifier, rollType)
    if modifier.rollType == "all" then
        return true
    end

    return rollType == modifier.rollType
end


CharacterModifier.RegisterType('power', "Modify Power Rolls")

--Something like Shift 2/3/4 will become {"Shift 2", "Shift 3", "Shift 4}
local function BreakTextIntoTiers(text)
    local result = {"", "", ""}
    local pattern = "^(?<prefix>.*?)(?<tier1>\\d+)/(?<tier2>\\d+)/(?<tier3>\\d+)(?<postfix>.*)$"
    local match = regex.MatchGroups(text, pattern)

    while match ~= nil do

        result[1] = result[1] .. match.prefix .. match.tier1
        result[2] = result[2] .. match.prefix .. match.tier2
        result[3] = result[3] .. match.prefix .. match.tier3

        text = match.postfix
        match = regex.MatchGroups(text, pattern)
    end

    result[1] = result[1] .. text
    result[2] = result[2] .. text
    result[3] = result[3] .. text

    return result
end

local g_powerRollsAbilityAdditionalSymbols = {
	ability = {
		name = "Ability",
		type = "ability",
		desc = "The ability being used for this roll.",
	},
	target = {
		name = "Target",
		type = "creature",
		desc = "The creature that is being targeted with this ability.",
	},
}

local g_powerRollSymbols = DeepCopy(CharacterModifier.defaultHelpSymbols)
for k,v in pairs(g_powerRollsAbilityAdditionalSymbols) do
    g_powerRollSymbols[k] = v
end

function CharacterModifier:CheckRollRequirement(rollInfo)
    local requirement = self:try_get("rollRequirement", "none")
    if requirement == "none" then
        return true
    end

    local edges = rollInfo.boons or 0
    local banes = rollInfo.banes or 0

    print("BOONS:: requirement =", requirement)
    if requirement == "bane" then
        return banes > edges and edges < 2
    elseif requirement == "doublebane" then
        return banes >= 2 and edges <= 0
    elseif requirement == "edge" then
        print("BOONS:: edge requirement", edges, banes, edges > banes and banes < 2)
        return edges > banes and banes < 2
    elseif requirement == "doubleedge" then
        return edges >= 2 and banes <= 0
    end

    return true
end

CharacterModifier.TypeInfo.power = {

    init = function(modifier)
        print("POWER:: INIT")
        modifier.rollType = "ability_power_roll"
        modifier.modtype = "none"
        modifier.activationCondition = false
        modifier.keywords = {}
    end,

    triggerOnUse = function(modifier, creature, modContext)
		if modifier:try_get("hasCustomTrigger", false) and modifier:has_key("customTrigger") then
			modifier.customTrigger:Trigger(modifier, creature, modifier:AppendSymbols{}, nil, modContext)
		end
	end,

    hintPowerRoll = function(self, creature, rollType, options)

        if (self.activationCondition == false) or (not RollTypeMatches(self, rollType)) then
            return {
                result = false,
                justification = {}
            }
        end

        if self:has_key("keywords") and options.ability ~= nil then
            for keyword,_ in pairs(self.keywords) do
                if not options.ability:HasKeyword(keyword) then
                    return {
                        result = false,
                        justification = {string.format("Ability does not have the '%s' keyword", keyword)},
                    }
                end
            end
        end

        if self:HasResourcesAvailable(creature) == false then
			return {
				result = false,
				justification = {"You have expended all uses of this ability."},
			}
		end

        if self.activationCondition == true then
            return {
                result = true,
                justification = {}
            }
        end

		local lookupFunction = creature:LookupSymbol(self:AppendSymbols{
			ability = GenerateSymbols(options.ability),
			target = GenerateSymbols(options.target),
		})

        return {
            result = GoblinScriptTrue(dmhub.EvalGoblinScriptDeterministic(self.activationCondition, lookupFunction, 0, "Power Roll Activation Condition")),
            justification = {},
        }
    end,

    shouldShowInPowerRollDialog = function(self, creature, rollType, roll, options)

        if self:try_get("attribute", "all") ~= "all" and (rollType == "test_power_roll" or rollType == "resistance_power_roll") and options ~= nil then
            if self.attribute ~= options.attribute then
                return false
            end
        end

        if #self:try_get("skills", {}) > 0 and rollType == "test_power_roll" and options.skills ~= nil then
            local hasSkill = false
            for _,skillid in ipairs(self.skills) do
                for _,skillid2 in ipairs(options.skills) do
                    if skillid == skillid2 then
                        hasSkill = true
                        break
                    end
                end
            end

            if not hasSkill then
                return false
            end
        end


        if not RollTypeMatches(self, rollType) then
            return false
        end

        if not self:PassesFilter(creature) then
            return false
        end

        return true
    end,

    modifyPowerRoll = function(self, creature, rollType, roll, options)
        if self.modtype == "none" then
            return roll
        end

        return roll .. " " .. ActivatedAbilityPowerRollBehavior.s_modificationTypesById[self.modtype].mod
    end,


    modifyRollProperties = function(self, creature, rollProperties)
        if rollProperties.typeName ~= "RollPropertiesPowerTable" then
            return
        end

        print("BOONS:: ModifyRollProperties")

        local damageModifier = self:try_get("damageModifier", "")
        if damageModifier ~= "" then
            local damage = dmhub.EvalGoblinScriptDeterministic(damageModifier, creature:LookupSymbol(self:AppendSymbols({})), 0, "Power Roll Damage Modifier")
            if damage ~= 0 then
                for i,tier in ipairs(rollProperties.tiers) do
                    local match = regex.MatchGroups(tier, "(?<damage>\\d+)\\s+([a-zA-Z]+\\s+)?damage", {indexes = true})
                    if match ~= nil then
                        local index = match.damage.index
                        local length = match.damage.length

                        local before = string.sub(tier, 1, index-1)
                        local after = string.sub(tier, index+length)

                        local damageValue = round(tonumber(match.damage.value))
                        damageValue = round(damageValue + damage)

                        rollProperties.tiers[i] = string.format("%s%d%s", before, damageValue, after)
                        printf("ROLL PROPERTIES: [%d]: %s -> %s", i, tier, rollProperties.tiers[i])
                    end
                end
            end
        end

        for i,adjustment in ipairs(self:try_get("adjustments", {})) do
            local pattern = "^(?<prefix>.*)" .. adjustment.type .. "\\s+(?<value>\\d+)(?<postfix>.*)$"

            local lookupFunction = creature:LookupSymbol(self:AppendSymbols{
            })

            for j,tier in ipairs(rollProperties.tiers) do
                local match = regex.MatchGroups(tier, pattern)
                if match ~= nil then
                    local adj = dmhub.EvalGoblinScriptDeterministic(adjustment.value, lookupFunction, 1, "Determine adjustment")
                    local value = tonumber(match.value)
                    value = value + (adj or 0)
                    rollProperties.tiers[j] = string.format("%s%s %d%s", match.prefix, adjustment.type, value, match.postfix)
                end
            end
        end

        local surges = self:try_get("surges", "")
        if surges ~= "" then
            rollProperties.surges = rollProperties:try_get("surges", 0) + dmhub.EvalGoblinScriptDeterministic(surges, creature:LookupSymbol(self:AppendSymbols({})), 0, "Power Roll Surges")
        end

        local shields = self:try_get("shields", "")
        if shields ~= "" then
            rollProperties.shields = rollProperties:try_get("shields", 0) + dmhub.EvalGoblinScriptDeterministic(shields, creature:LookupSymbol(self:AppendSymbols({})), 0, "Power Roll Shields")
        end

        if self:has_key("addText") and trim(self.addText) ~= "" then
            local tieredText = BreakTextIntoTiers(self.addText)
            for i,tier in ipairs(rollProperties.tiers) do
                rollProperties.tiers[i] = string.format("%s; %s", tier, tieredText[i])
            end
        end
    end,

    createEditor = function(modifier, element)
        local Refresh
        local firstRefresh = true

        Refresh = function()
            if firstRefresh then
                firstRefresh = false
            end

            local conditionType = "condition"
            if modifier.activationCondition == false then
                conditionType = "never"
            elseif modifier.activationCondition == true then
                conditionType = "always"
            end

            local children = {}

            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    classes = {"formLabel"},
                    text = "Apply To:",
                },

                gui.Dropdown{
					height = 30,
					width = 260,
                    valign = "center",
					fontSize = 16,
                    options = g_powerRollTypes,
                    idChosen = modifier.rollType,
                    change = function(element)
                        modifier.rollType = element.idChosen
                        Refresh()
                    end,
                }
            }

            if modifier.rollType == "test_power_roll" or modifier.rollType == "resistance_power_roll" then
                local options = DeepCopy(creature.attributeDropdownOptions)
                options[#options+1] = {
                    id = "all",
                    text = "All",
                }
                children[#children+1] = gui.Panel{
                    classes = {"formPanel"},
                    gui.Label{
                        classes = {"formLabel"},
                        text = "Characteristic:",
                    },

                    gui.Dropdown{
                        height = 30,
                        width = 260,
                        valign = "center",
                        fontSize = 16,
                        options = options,
                        idChosen = modifier:try_get("attribute", "all"),
                        change = function(element)
                            modifier.attribute = element.idChosen
                            Refresh()
                        end,
                    }
                }
            end

            if modifier.rollType == "test_power_roll" then
                local skills = modifier:try_get("skills", {})
                for i,skillid in ipairs(skills) do
                    local skill = Skill.SkillsById[skillid]
                    if skill ~= nil then
                        children[#children+1] = gui.Label{
                            text = skill.name,
                            fontSize = 18,
                            height = 30,
                            width = 160,
                            halign = "left",
                            gui.DeleteItemButton{
                                halign = "right",
                                valign = "center",
                                height = 12,
                                width = 12,
                                click = function()
                                    table.remove(skills, i)
                                    Refresh()
                                end,
                            },
                        }
                    end
                end

                children[#children+1] = gui.Dropdown{
                    height = 30,
                    width = 260,
                    fontSize = 16,
                    valign = "center",
                    hasSearch = true,
                    textDefault = "Add Skill...",
                    options = Skill.skillsDropdownOptions,
                    change = function(element)
                        skills[#skills+1] = element.idChosen
                        modifier.skills = skills
                        Refresh()
                    end,
                }
            end

            children[#children+1] = modifier:UsageLimitEditor{}

            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    text = "Resource Cost:",
                    classes = {"formLabel"},
                },

				gui.Dropdown{
					height = 30,
					width = 260,
					fontSize = 16,
                    valign = "center",
					idChosen = modifier:try_get("resourceCostType", "none"),
					options = {
						{
							id = "none",
							text = "None",
						},
						{
							id = "cost",
							text = "Malice/Heroic Resources",
						},
						{
							id = "multicost",
							text = "Malice/Heroic Resources+",
						},
					},
					change = function(element)
                        modifier.resourceCostType = element.idChosen
                        Refresh()
					end,
				}
            }

            if modifier:try_get("resourceCostType", "none") ~= "none" then
                children[#children+1] = gui.Panel{
                    classes = {"formPanel"},
                    gui.Label{
                        text = "Cost:",
                        classes = {"formLabel"},
                    },

                    gui.Input{
                        classes = {"formInput"},
                        width = 40,
                        halign = "left",
                        characterLimit = 3,
                        text = modifier:try_get("resourceCostAmount", 1),
                        change = function(element)
                            if tonumber(element.text) ~= nil then
                                modifier.resourceCostAmount = tonumber(element.text)
                            else 
                                element.text = modifier:try_get("resourceCostAmount", 1)
                            end
                            Refresh()
                        end,
                    }
                }
            end


            if modifier.rollType == "ability_power_roll" or modifier.rollType == "enemy_ability_power_roll" then
                local keywordsFound = {}
                for keyword,val in sorted_pairs(modifier:try_get("keywords", {})) do
                    if val == true then
                        keywordsFound[keyword] = true
                        children[#children+1] = gui.Panel{
                            classes = {"formPanel"},
                            data = {ord = keyword},
                            width = 200,
                            height = 14,
                            minHeight = 14,
                            gui.Label{
                                text = keyword,
                                width = "auto",
                                height = 14,
                                fontSize = 14,
                                color = Styles.textColor,
                            },
                            gui.DeleteItemButton{
                                width = 12,
                                height = 12,
                                halign = "right",
                                click = function(element)
                                    modifier.keywords[keyword] = nil
                                    Refresh()
                                end,
                            },
                        }
                    end
                end

                local dropdownOptions = {}
				for keyword,_ in pairs(GameSystem.abilityKeywords) do
                    if not keywordsFound[keyword] then
                        dropdownOptions[#dropdownOptions+1] = {
                            id = keyword,
                            text = keyword,
                        }
                    end
                end

                children[#children+1] = gui.Dropdown{
                    selfStyle = {
                        height = 30,
                        width = 240,
                        fontSize = 16,
                        halign = "left",
                    },
                    valign = "center",
                    sort = true,
                    options = dropdownOptions,
                    textDefault = "Add Keyword...",
                    change = function(element)
                        if element.idChosen ~= nil and GameSystem.abilityKeywords[element.idChosen] then
                            modifier:get_or_add("keywords", {})[element.idChosen] = true
                        end
                        Refresh()
                    end,
                }
            end

			children[#children+1] = modifier:FilterConditionEditor()

            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    text = "Roll Requirement:",
                    classes = {"formLabel"},
                },

				gui.Dropdown{
					height = 30,
					width = 260,
					fontSize = 16,
                    valign = "center",
					idChosen = modifier:try_get("rollRequirement", "none"),
					options = {
						{
							id = "none",
							text = "None",
						},
						{
							id = "bane",
							text = "Bane on the Roll",
						},
						{
							id = "doublebane",
							text = "Double Bane on the Roll",
						},
						{
							id = "edge",
							text = "Edge on the Roll",
						},
						{
							id = "doubleedge",
							text = "Double Edge on the Roll",
						},
					},
					change = function(element)
                        modifier.rollRequirement = element.idChosen
                        Refresh()
					end,
				}
            }

			children[#children+1] = gui.Panel{
				classes = {"formPanel"},
				gui.Label{
					text = "Activation:",
					classes = {"formLabel"},
				},

				gui.Dropdown{
					height = 30,
					width = 260,
					fontSize = 16,
                    valign = "center",
					idChosen = conditionType,
					options = {
						{
							id = "never",
							text = "Never",
						},
						{
							id = "always",
							text = "Always",
						},
						{
							id = "condition",
							text = "Condition",
						},
					},
					change = function(element)
						if element.idChosen ~= conditionType then
							if element.idChosen == "never" then
								modifier.activationCondition = false
							elseif element.idChosen == "always" then
								modifier.activationCondition = true
							else
								modifier.activationCondition = ""
							end
							Refresh()
						end
					end,
				}

			}

            if modifier.activationCondition ~= true and modifier.activationCondition ~= false then
                local helpSymbols = CharacterModifier.defaultHelpSymbols
                if modifier.rollType == "ability_power_roll" or modifier.rollType == "enemy_ability_power_roll" then
                    helpSymbols = g_powerRollSymbols
                end

                children[#children+1] = gui.GoblinScriptInput{
					placeholderText = "Enter activation criteria...",
					value = modifier.activationCondition,
					change = function(element)
						modifier.activationCondition = element.value
						Refresh()
					end,

					documentation = {
						domains = modifier:Domains(),
						help = string.format("This GoblinScript is used to determine whether or not this modifier will be applied to a given roll. It determines the default value for the checkbox that appears next to it when the roll occurs. The player can always override the value manually."),
						output = "boolean",
						examples = {
						},
						subject = creature.helpSymbols,
						subjectDescription = "The creature affected by this modifier",
						symbols = modifier:HelpAdditionalSymbols(helpSymbols),
					},
				}

            end


            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    classes = {"formLabel"},
                    text = "Roll Mod:",
                },

                gui.Dropdown{
                    options = ActivatedAbilityPowerRollBehavior.s_modificationTypes,
                    valign = "center",
                    idChosen = modifier.modtype,
                    change = function(element)
                        modifier.modtype = element.idChosen
                    end,
                }
            }

            local helpSymbols = DeepCopy(CharacterModifier.defaultHelpSymbols)
            helpSymbols.target = {
                name = "Target",
                type = "creature",
                desc = "The target of the power roll.",
            }

            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    classes = {"formLabel"},
                    text = "Damage:",
                },

                gui.GoblinScriptInput{
					placeholderText = "Enter damage...",
					value = modifier:try_get("damageModifier", ""),
					change = function(element)
						modifier.damageModifier = element.value
					end,

					documentation = {
						domains = modifier:Domains(),
						help = string.format("This GoblinScript is used to determine the amount of damage that will be added to the roll."),
						output = "number",
						examples = {
						},
						subject = creature.helpSymbols,
						subjectDescription = "The creature that is attacking",
						symbols = helpSymbols,
					},
				},
            }

            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    classes = {"formLabel"},
                    text = "Surges:",
                },

                gui.GoblinScriptInput{
					placeholderText = "Enter surges...",
					value = modifier:try_get("surges", ""),
					change = function(element)
						modifier.surges = element.value
					end,

					documentation = {
						domains = modifier:Domains(),
						help = string.format("This GoblinScript is used to determine the amount of surges that will be added to the roll."),
						output = "number",
						examples = {
						},
						subject = creature.helpSymbols,
						subjectDescription = "The creature that is attacking",
						symbols = helpSymbols,
					},
				},
            }


            local adjustmentsSymbols = modifier:HelpAdditionalSymbols(helpSymbols)
            adjustmentsSymbols.charges = {
                name = "Charges",
                type = "number",
                desc = "The number of applications of this adjustment being applied.",
            }

            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    classes = {"formLabel"},
                    text = "Adjustments:",
                },

                gui.Panel{
                    classes = {"formLabel"},
                    flow = "vertical",
                    create = function(element)
                        local children = {}
                        local adjustments = modifier:try_get("adjustments", {})
                        for i,adjustment in ipairs(adjustments) do
                            local panel = gui.Panel{
                                flow = "horizontal",
                                width = "100%",
                                height = 30,
                                gui.Dropdown{
                                    width = 120,
                                    halign = "left",
                                    options = {
                                        {
                                            id = "push",
                                            text = "push",
                                        },
                                        {
                                            id = "pull",
                                            text = "pull",
                                        },
                                        {
                                            id = "slide",
                                            text = "slide",
                                        },
                                        {
                                            id = "toss",
                                            text = "toss",
                                        },
                                    },
                                    idChosen = adjustment.type,
                                    change = function(element)
                                        adjustments[i].type = element.idChosen
                                        Refresh()
                                    end,
                                },

                                gui.GoblinScriptInput{
                                    placeholderText = "Enter adjustment...",
                                    value = adjustment.value,
                                    width = 180,
                                    change = function(element)
                                        adjustment.value = element.value
                                        Refresh()
                                    end,

                                    documentation = {
                                        domains = modifier:Domains(),
                                        help = string.format("This GoblinScript is used to determine the adjustment made to the power table value."),
                                        output = "number",
                                        examples = {
                                        },
                                        subject = creature.helpSymbols,
                                        subjectDescription = "The creature affected by this modifier",
                                        symbols = adjustmentsSymbols,
                                    },
                                },

                                gui.DeleteItemButton{
                                    halign = "right",
                                    width = 12,
                                    height = 12,
                                    click = function()
                                        table.remove(adjustments, i)
                                        Refresh()
                                    end,
                                }
                            }

                            children[#children+1] = panel
                        end

                        children[#children+1] = gui.AddButton{
                            width = 16,
                            height = 16,
                            halign = "left",
                            click = function(element)
                                adjustments[#adjustments+1] = {
                                    type = "push",
                                    value = 1,
                                }
                                modifier.adjustments = adjustments
                                Refresh()
                            end,
                        }

                        element.children = children
                    end,
                },
            }


            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    classes = {"formLabel"},
                    text = "Add Rule",
                    hover = function(element)
                        gui.Tooltip("This will add the text to the end of all tiers of the power roll.")(element)
                    end,
                },

                gui.Input{
                    classes = {"formInput"},
                    text = modifier:try_get("addText", ""),
                    change = function(element)
                        modifier.addText = element.text
                        Refresh()
                    end,
                },
            }

            children[#children+1] = gui.Check{
				style = {
					height = 30,
					width = 160,
					fontSize = 18,
					halign = "left",
				},

				text = "Has Custom Trigger",
				value = modifier:try_get("hasCustomTrigger", false),
				change = function(element)
					modifier.hasCustomTrigger = element.value
					if element.value and modifier:has_key("customTrigger") == false then
						modifier.customTrigger = TriggeredAbility.Create{
							trigger = "d20roll",
						}
					end
					Refresh()
				end,
			}

			if modifier:try_get("hasCustomTrigger", false) then
				children[#children+1] = gui.PrettyButton{
					halign = "left",
					width = 220,
					height = 50,
					fontSize = 24,
					text = "Edit Trigger",
					click = function(element)
						if modifier:has_key("customTrigger") then
							element.root:AddChild(modifier.customTrigger:ShowEditActivatedAbilityDialog{
								title = "Edit Trigger",
								hide = {"appearance", "abilityInfo"},
							})
						end
					end,
				}
			end

            element.children = children
        end

        Refresh()
    end,
}

function CharacterModifier:DescribeModifyPowerRoll(modContext, creature, rollType, options)
    if self:ShouldShowInPowerRollDialog(modContext, creature, rollType, options) then
        return {
            modifier = self,
            context = modContext,
        }
    end

    return nil
end

function CharacterModifier:ShouldShowInPowerRollDialog(modContext, creature, rollType, options)
	local typeInfo = CharacterModifier.TypeInfo[self.behavior] or {}
    local shouldShow = typeInfo.shouldShowInPowerRollDialog
    if shouldShow ~= nil then
        self:InstallSymbolsFromContext(modContext)
        self:InstallSymbolsFromContext(options)
        local result = shouldShow(self, creature, rollType, nil, options)
        return result
    end

    return false
end

function CharacterModifier:HintModifyPowerRolls(modContext, creature, rollType, options)
	local typeInfo = CharacterModifier.TypeInfo[self.behavior] or {}
    local hint = typeInfo.hintPowerRoll
    if hint ~= nil then
        local result = hint(self, creature, rollType, options)
        return result
    end

    return nil
end

function CharacterModifier:ModifyPowerRolls(modContext, creature, rollType, roll, options)
	local typeInfo = CharacterModifier.TypeInfo[self.behavior] or {}
    local modifyPowerRoll = typeInfo.modifyPowerRoll
    if modifyPowerRoll ~= nil then
        self:InstallSymbolsFromContext(modContext)
        self:InstallSymbolsFromContext(options)
        return modifyPowerRoll(self, creature, rollType, roll, options)
    end

    return roll
end

function CharacterModifier:ApplyToRoll(context, casterCreature, targetCreature, rollType, roll)
    local result = self:ModifyPowerRolls(context, casterCreature, rollType, roll, {})
    return result
end