local mod = dmhub.GetModLoading()

creature.withCaptain = false

monster.groupid = "none"
monster.role = "soldier"

monster.opportunityAttack = "1"

monster.traitNames = {}

--power roll bonus.
monster.pr = 0

--encounter value.
monster.ev = 1

monster.keywords = {}

function monster:Keywords()
    return monster.keywords
end

function creature:PowerRollBonus()
    return 0
end

function monster:PowerRollBonus()
	return self.pr
end

function creature:MonsterGroup()
    return nil
end

function monster:MonsterGroup()
    return MonsterGroup.Get(self.groupid)
end

function creature:FillMonsterActivatedAbilities(options, result)
end

function monster:FillMonsterActivatedAbilities(options, result)
    if options.excludeGlobal then
        return
    end

    self:FillFreeStrikes(options, result)

    local group = self:MonsterGroup()
    if group ~= nil then
        for _,ability in ipairs(group.maliceAbilities) do
            result[#result+1] = ability:MakeTemporaryClone()
        end
    end
end

function monster:FillFreeStrikes(options, result)
    local signature = self:GetSignatureAbility()
    if signature == nil then
        return
    end

    local powerRoll = nil
    for _,behavior in ipairs(signature.behaviors) do
        if behavior.typeName == "ActivatedAbilityPowerRollBehavior" then
            powerRoll = behavior
            break
        end
    end

    local damageType = "normal"

    if powerRoll ~= nil then
        local matchDamageType = regex.MatchGroups(powerRoll.tiers[3], "[0-9]+ (?<damageType>[a-z]+) damage")
        if matchDamageType ~= nil then
            damageType = matchDamageType.damageType
        end
    end

    local signatureRange = signature:GetRange(self) or 1

    local meleeFreeStrike = MCDMUtils.GetStandardAbility("Melee Free Strike")
    if meleeFreeStrike ~= nil then
        local ability = meleeFreeStrike:MakeTemporaryClone()

        if signature:HasKeyword("Melee") then
            ability.range = math.max(1, signatureRange)
        end

        local freeStrikeDamage = tostring(self:OpportunityAttack())
        ability.behaviors[1].roll = freeStrikeDamage .. "*Charges"
        ability.behaviors[1].damageType = damageType

        if damageType == "normal" then
            ability.description = string.format("%s damage", freeStrikeDamage)
        else
            ability.description = string.format("%s %s damage", freeStrikeDamage, damageType)
        end

        result[#result+1] = ability
    end

    local rangedFreeStrike = MCDMUtils.GetStandardAbility("Ranged Free Strike")
    if rangedFreeStrike ~= nil then
        local ability = rangedFreeStrike:MakeTemporaryClone()

        if signature:HasKeyword("Ranged") then
            ability.range = math.max(5, signatureRange)
        end

        local freeStrikeDamage = tostring(self:OpportunityAttack())
        ability.behaviors[1].roll = freeStrikeDamage .. "*Charges"
        ability.behaviors[1].damageType = damageType

        if damageType == "normal" then
            ability.description = string.format("%s damage", freeStrikeDamage)
        else
            ability.description = string.format("%s %s damage", freeStrikeDamage, damageType)
        end

        result[#result+1] = ability
    end
end

function creature:MakeFreeStrikeAttack(attackerToken, targetToken, symbols)
    print("Non-monsters don't currently implement automated free strikes.")
end

function monster:MakeFreeStrikeAttack(attackerToken, targetToken, symbols)
    local attacks = {}
    self:FillFreeStrikes({}, attacks)

    local distance = attackerToken:Distance(targetToken)

    for _,ability in ipairs(attacks) do
        local range = ability:GetRange(self)

        if range >= distance then
            ability:Cast(attackerToken, {{ token = targetToken }}, { symbols = symbols })
            return
        end
    end

end

creature.RegisterFeatureCalculation{
    id = "mcdmmonster",
    FillFeatures = function(c, result)
        if c.typeName == "monster" then
            c:FillTraitsFromGroup(result)
        end
    end,
}

function monster:FillTraitsFromGroup(result)
    local g = self:MonsterGroup()
    if g ~= nil then
        for _,trait in pairs(g.commonTraits) do
            result[#result+1] = trait
        end
        for _,traitName in ipairs(self.traitNames) do
            local trait = g.traits[traitName]
            if trait ~= nil then
                result[#result+1] = trait
            end
        end
    end
end

function monster:GetTraitsFromGroup()
    local result = {}
    self:FillTraitsFromGroup(result)
    return result

end

function creature:OpportunityAttack()
    return 0
end

function monster:OpportunityAttack()
    return round(tonumber(self.opportunityAttack))
end

function monster:OpportunityAttackRange()
    local ability = self:GetSignatureAbility()
    if ability ~= nil then
        return math.max(ability:GetRange(self), 1)
    end

    return 1
end

function monster:GetSignatureAbility()
    for i,ability in ipairs(self.innateActivatedAbilities) do
        if ability.categorization == "Signature Ability" then
            return ability
        end
    end

    return nil
end

function monster:Level()
    return self.cr
end

function monster:BaseForcedMoveResistance()
	return self.stability
end

function monster:BaseReach()
--    local g = MonsterGroup.Get(self.groupid)
--    if g ~= nil then
--        return g.reach
--    end
	return self.reach
end

function monster:BaseWeight()
--    local g = MonsterGroup.Get(self.groupid)
--    if g ~= nil then
--        return g.weight
--    end
	return self.weight
end

function monster:GetBaseCreatureSize()
    local defaultSize = "1M"
--    local g = MonsterGroup.Get(self.groupid)
--    if g ~= nil then
--        defaultSize = g.size
--    end
	return self:try_get("creatureSize", defaultSize)
end

function monster:SizeDescription()
    return self:GetBaseCreatureSize()
end

--render a 'statblock' for the creature.
function monster:Render(args, options)

	args = args or {}

	local summary = args.summary
	args.summary = nil

	local asset = options.asset
	options.asset = nil

	local token = options.token
	options.token = nil
	
	if asset == nil and token == nil then
		return
	end

	if token == nil then
		token = asset.info
	end

	local charName
	if asset ~= nil then
		charName = asset.name
	else
		charName = token.name
	end

	if charName == "" or charName == nil then
		charName = self:try_get("monster_type")
	end


    local portraitBackground
    if not args.noavatar then
        portraitBackground = gui.Panel{
            id = "portrait",
            halign = "center",
            valign = "top",
            floating = true,
            width = "100%",
            height = "100% width",
            bgcolor = "#ffffff06",
            bgimage = token.portrait,
        }
    end

    args.noavatar = nil




	local abilities = self:GetActivatedAbilities{excludeGlobal = true, allLoadouts = true, bindCaster = true}
	local actionsPanel = nil

    local normalActions = {}

    for _,ability in ipairs(abilities) do
        normalActions[#normalActions+1] = ability:Render({
            pad = 12,
            width = "100%",
        }, {
            token = token,

        })
    end

	actionsPanel = gui.Panel{
		flow = "vertical",
		height = "auto",
		width = "100%",
		children = normalActions,
	}

    local keywordsSorted = {}
    for k,v in pairs(self.keywords) do
        keywordsSorted[#keywordsSorted+1] = k
    end

    table.sort(keywordsSorted)
		
	local options = {
		width = 500,
		height = "auto",
		flow = "vertical",
		styles = {
            Styles.Default,
            SpellRenderStyles,
            {
                selectors = {"description"},
                bold = false,
            },
        },

        portraitBackground,

		gui.Panel{
			width = "100%",
			height = "auto",
			flow = "horizontal",

			gui.Panel{
				flow = "vertical",
				width = "100%",
				height = "auto",
				halign = "left",

                gui.Panel{
                    width = "100%",
                    height = 28,
                    flow = "horizontal",
                    gui.Label{
                        classes = {"description"},
                        smallcaps = true,
                        fontSize = 22,
                        bold = true,
                        width = "auto",
                        height = "auto",
                        text = string.format("%s", charName),
                    },

                    gui.Label{
                        classes = {"description"},
                        smallcaps = true,
                        fontSize = 22,
                        bold = true,
                        width = "auto",
                        height = "auto",
                        halign = "right",
                        text = string.format("Level %d %s%s", round(tonumber(self.cr) or 0), self.role, cond(self.minion, " minion", "")),
                    }
                },

                gui.Panel{
                    width = "100%",
                    height = 22,
                    flow = "horizontal",
                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        fontSize = 20,
                        text = string.join(keywordsSorted, ", "),
                    },

                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        halign = "right",
                        fontSize = 20,
                        text = string.format("EV %d%s", self.ev, cond(self.minion, " for " .. GameSystem.minionsPerSquadText .. " minions", "")),
                    }
                },

                gui.Panel{
                    classes = "divider",
                },

                --stamina and immunity/vulnerability
                gui.Panel{
                    width = "100%",
                    height = 22,
                    flow = "horizontal",
                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        fontSize = 16,
                        text = string.format("<b>Stamina</b> %d", self:MaxHitpoints()),
                    },

                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        halign = "right",
                        fontSize = 16,
                        text = "",
                        create = function(element)
                            local resistances = self:try_get("resistances", {})
                            if #resistances == 0 then
                                return
                            end

                            local text = ""
                            local mode = nil
                            for index,entry in ipairs(resistances) do
                                local newMode = cond(entry.dr > 0, "Immunity", "Vulnerability")
                                if newMode ~= mode then
                                    mode = newMode
                                    text = string.format("%s<b>%s</b> ", text, mode)
                                elseif index > 1 then
                                    text = text .. ", "
                                end

                                local keywords = {}
                                for k,_ in pairs(entry:try_get("keywords", {})) do
                                    keywords[#keywords+1] = k
                                end

                                table.sort(keywords)

                                text = string.format("%s%s %d", text, string.join(keywords), entry.dr)
                            end

                            element.text = text
                        end,
                    }
                },

                --speed and size/stability
                gui.Panel{
                    width = "100%",
                    height = 22,
                    flow = "horizontal",
                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        fontSize = 16,
                        text = string.format("<b>Stamina</b> %d", self:MaxHitpoints()),

                        create = function(element)
                            local str = string.format("<b>Speed</b> %s", tostring(self:WalkingSpeed()))
                            for k,speed in pairs(self:try_get("movementSpeeds", {})) do
                                if speed > 0 then
                                    str = str .. " " .. k
                                end
                            end

                            element.text = str
                        end,
                    },

                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        halign = "right",
                        fontSize = 16,
                        text = string.format("<b>Size</b> %s / <b>Stability</b> %d", self:SizeDescription(), self:BaseForcedMoveResistance()),
                    }
                },

                --with captain & free strike
                gui.Panel{
                    width = "100%",
                    height = 22,
                    flow = "horizontal",
                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        halign = "left",
                        fontSize = 16,
                        text = cond(self.withCaptain,
                                    string.format("<b>With Captain</b> <alpha=%s>%s<alpha=#ff>",
                                                  cond(DrawSteelMinion.GetWithCaptainEffect(self.withCaptain) ~= nil, "#ff", "#55"),
                                                  self.withCaptain or ""),
                                    ""),
                    },
                    gui.Label{
                        classes = {"description"},
                        width = "auto",
                        height = "auto",
                        halign = "right",
                        fontSize = 16,
                        text = string.format("<b>Free Strike</b> %d", self:OpportunityAttack()),
                    },
                },

                --attributes.
                gui.Panel{
                    width = "100%",
                    height = 22,
                    flow = "horizontal",
                    create = function(element)
                        local children = {}
			            for i,attrid in ipairs(creature.attributeIds) do
                            local val = self:GetAttribute(attrid):Value()
                            local info = creature.attributesInfo[attrid]

                            local halign = "center"
                            if i == 1 then
                                halign = "left"
                            elseif i == #creature.attributeIds then
                                halign = "right"
                            end

                            children[#children+1] = gui.Label{
                                classes = {"description"},
                                fontSize = 16,
                                bold = true,
                                width = "auto",
                                height = "auto",
                                halign = halign,
                                text = string.format("%s %s", info.description, ModStr(val)),
                            }
                        end

                        element.children = children
                    end,

                },

			},

		},

		gui.Panel{
			classes = "divider",
		},

        --don't show monster attributes?
--	gui.Panel{
--		flow = "horizontal",
--		height = "auto",
--		width = "100%",
--		create = function(element)
--			local children = {}

--               local attributes = {}

--               local maxAttr = -99
--			for i,attrid in ipairs(creature.attributeIds) do
--                   local val = self:GetAttribute(attrid):Value()
--                   attributes[attrid] = val
--                   if val > maxAttr then
--                       maxAttr = val
--                   end
--               end

--			for i,attrid in ipairs(creature.attributeIds) do
--                   local attrMod = attributes[attrid]
--                   if attrMod == maxAttr then
--                       attrMod = string.format("<b>%s</b>", attrMod)
--                   else
--                       attrMod = tostring(attrMod)
--                   end
--				children[#children+1] = gui.Panel{
--					flow = "vertical",
--					width = 50,
--					height = "auto",
--					halign = "center",
--					gui.Label{
--						halign = "center",
--						width = "auto",
--						height = "auto",
--						text = "<b>" .. string.upper(attrid) .. "</b>",
--					},
--					gui.Label{
--						halign = "center",
--						width = "auto",
--						height = "auto",
--                           fontSize = 22,
--						text = attrMod,
--					}
--				}
--			end

--			element.children = children
--		end,
--	},

--	gui.Panel{
--		classes = "divider",
--	},

		--skills.
		gui.Label{
			classes = "description",
			create = function(element)
				local text = ""

				local skillsTable = dmhub.GetTable(Skill.tableName)
				local items = {}
				for k,skillInfo in pairs(skillsTable) do

					local skillMod = self:SkillModStr(skillInfo)
					local attrMod = ModStr(self:GetAttribute(skillInfo.attribute):Modifier())
					if skillMod ~= attrMod then
						items[#items+1] = string.format("%s", skillInfo.name)
					end
				end

				if #items == 0 then
					element:SetClass("collapsed", true)
				else
					table.sort(items)
					element.text = string.format("<b>Skills:</b> <i>[+1 Boon to Tests] %s</i>", string.join(items, ", "))
				end
			end,
		},

		gui.Panel{
			flow = "vertical",
			height = "auto",
			width = "100%",
			create = function(element)
				local children = {}

                for _,feature in ipairs(self:GetTraitsFromGroup()) do
                    if feature.description ~= "" then
                        children[#children+1] = gui.Label{
                            vmargin = 10,
                            text = string.format("<b>%s:</b> <i>%s</i>", feature.name, feature.description)
                        }
                    end
                end

                for _,feature in ipairs(self:try_get("characterFeatures", {})) do
                    if feature.description ~= "" then
                        children[#children+1] = gui.Label{
                            vmargin = 10,
                            text = string.format("<b>%s:</b> <i>%s</i>", feature.name, feature.description)
                        }
                    end
                end

				for _,note in ipairs(self:try_get("notes", {})) do
					children[#children+1] = gui.Label{
						vmargin = 10,
						text = string.format("<b>%s:</b> <i>%s</i>", note.title, note.text)
					}
				end

				element.children = children
			end,
		},


		actionsPanel,


	}

	for k,v in pairs(args or {}) do
		options[k] = v
	end

	return gui.Panel(options)
end

local g_monsterAbilityNames = {
    ["Signature Ability"] = "Abilities",
    ["Heroic Ability"] = "Villain Abilities",
}

function monster:AbilityCategoryPlural(abilityCategory)
    return g_monsterAbilityNames[abilityCategory] or abilityCategory
end


monster.RegisterSymbol{
    symbol = "freestrikedamage",
    lookup = function(c)
        return c:OpportunityAttack()
    end,
    help = {
        name = "Free Strike Damage",
        type = "number",
        desc = "The free strike damage of the monster.",
        seealso = {},
    }
}

monster.RegisterSymbol{
    symbol = "freestrikerange",
    lookup = function(c)
        return c:OpportunityAttackRange()
    end,
    help = {
        name = "Free Strike Range",
        type = "number",
        desc = "The free strike range of the monster.",
        seealso = {},
    }
}

local g_oldTemporalActiveModifiers = monster.FillTemporalActiveModifiers

function monster:FillTemporalActiveModifiers(result)
    g_oldTemporalActiveModifiers(self, result)

    if mod.unloaded then
        return
    end

    if self.withCaptain and self.minion and self:has_key("_tmp_minionSquad") then
        local squad = self._tmp_minionSquad
        if squad.hasCaptain then
            local feature = DrawSteelMinion.GetWithCaptainEffect(self.withCaptain)
            if feature ~= nil then
                for _,mod in ipairs(feature.modifiers) do
                    result[#result+1] = {
                        mod = mod,
                    }

                end
            end
        end
        
    end

end