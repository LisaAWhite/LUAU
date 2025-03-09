local mod = dmhub.GetModLoading()

RegisterGameType("Kit")

local ApplyDamageFromKit

Kit.tableName = "kits"

Kit.damageBonusMatchPattern = "^\\+?(?<tier1>[0-9]+)/\\+?(?<tier2>[0-9]+)/\\+?(?<tier3>[0-9]+)"
Kit.kitTypes = {
	{
		id = "martial",
		text = "Martial",
		keywords = {"Weapon"},
		displayOrd = 1,
		lockedByDefault = true,
	},
	{
		id = "caster",
		text = "Caster",
		keywords = {"Magic", "Psionic"},
		displayOrd = 2,
		lockedByDefault = true,
	},
	{
		id = "stormwight",
		text = "Stormwight",
		keywords = {"Weapon"},
		displayOrd = 0,
		lockedByDefault = true,
	},
	{
		id = "null",
		text = "Null",
		keywords = {"Weapon"},
		displayOrd = 0,
		lockedByDefault = true,
	}
}

Kit.kitTypesById = {}
for _,kitType in ipairs(Kit.kitTypes) do
	Kit.kitTypesById[kitType.id] = kitType
end

Kit.kitTypeToDisplayOrd = {}
for _,kitType in ipairs(Kit.kitTypes) do
	Kit.kitTypeToDisplayOrd[kitType.id] = kitType.displayOrd
end

Kit.lockedKitTypes = {}
for _,kitType in ipairs(Kit.kitTypes) do
	if kitType.lockedByDefault then
		Kit.lockedKitTypes[kitType.id] = true
	end
end

Kit.signatureAbility = false
Kit.kitManeuver = false

function Kit:SignatureAbilities()
	if self:has_key("signatureAbilities") then
		--generally for a combined ability.
		return self.signatureAbilities
	end

	local result = {}
	if self.signatureAbility ~= false then
		result[#result+1] = self.signatureAbility
	end

	if self:has_key("additionalSignatureAbilities") then
		for _,ability in ipairs(self.additionalSignatureAbilities) do
			result[#result+1] = ability
		end
	end
	
	return result
end

Kit.name = "New Kit"
Kit.type = "martial"
Kit.description = ""
Kit.equipmentDescription = ""
Kit.portraitid = ""

Kit.health = 0
Kit.speed = 0
Kit.damage = 0
Kit.range = 0
Kit.reach = 0
Kit.area = 0
Kit.stability = 0

Kit.damageBonusTypes = {
	{
		id = "melee",
		text = "Melee Weapon",
		keywords = {"Melee", "Weapon"},
		keywordsMatchAll = true,
		kitType = "martial",
	},
	{
		id = "ranged",
		text = "Ranged Weapon",
		keywords = {"Ranged", "Weapon"},
		keywordsMatchAll = true,
		kitType = "martial",
	},
	{
		id = "supernatural",
		text = "Supernatural",
		keywords = {"Psionic", "Magic"},
		keywordsMatchAll = false,
		kitType = "caster",
	},
}

local function DamageBonusTypeMatchesAbility(ability, damageBonusType)
	if damageBonusType.keywordsMatchAll then
		for _,keyword in ipairs(damageBonusType.keywords) do
			if not ability.keywords[keyword] then
				return false
			end
		end
		return true
	else
		for _,keyword in ipairs(damageBonusType.keywords) do
			if ability.keywords[keyword] then
				return true
			end
		end
		return false
	end
end

function Kit:DamageBonuses()
	return self:get_or_add("damageBonuses", {})
end

function Kit:FormatDamageBonus(id)
	local bonuses = self:DamageBonuses()[id]
	if bonuses == nil then
		return nil
	end

	return string.format("+%d/+%d/+%d", bonuses[1], bonuses[2], bonuses[3])
end

Kit.weaponTypes = {
	{
		id = "Light",
		text = "Light",
		pattern = "Light Weapon",
	},
	{
		id = "Medium",
		text = "Medium",
		pattern = "Medium Weapon",
	},
	{
		id = "Heavy",
		text = "Heavy",
		pattern = "Heavy Weapon",
	},
	{
		id = "Bow",
		text = "Bow",
	},
	{
		id = "Thrown",
		text = "Thrown",
	},
	{
		id = "Unarmed Strike",
		text = "Unarmed Strike",
	},
	{
		id = "Net",
		text = "Net",
	},
	{
		id = "Polearm",
		text = "Polearm",
	},
	{
		id = "Whip",
		text = "Whip",
	},
}

Kit.weapons = {}
Kit.implement = false


function Kit.CreateNew()
	return Kit.new{
		damageBonuses = {},
	}
end

function Kit:Describe()
	return self.name
end

function Kit:HasWeapons()
	for k,v in pairs(self.weapons) do
		return true
	end

	return false
end

function Kit.DamageBonusPreferred(a, b)
	if b == nil then
		return true
	end
	if a == nil then
		return false
	end

	local damage_a_count = 0
	local damage_b_count = 0
	for _,damage in ipairs(a) do
		damage_a_count = damage_a_count + damage
	end
	for _,damage in ipairs(b) do
		damage_b_count = damage_b_count + damage
	end

	return damage_a_count > damage_b_count
end

--given a creature holding two kits, with a given type of attack bonus it will return
--if the creature is set up to use the first kit's bonus or the second kit's.
--returns true if using kit1, false if using kit2
function Kit.DamageBonusSelected(creature, bonusid, kit1, kit2)
	local a = kit1:DamageBonuses()[bonusid]
	local b = kit2:DamageBonuses()[bonusid]
	if b == nil then
		return true
	end
	if a == nil then
		return false
	end

    local levelChoices = creature:GetLevelChoices()
	if levelChoices ~= nil then
		local bonusChoices = levelChoices["kitBonusChoices"]
		if bonusChoices ~= nil then
			local choice = bonusChoices[bonusid]
			print("SELECTED:: CHOICE FOR ", bonusid, " = ", choice, kit1.id, kit2.id)
			if choice == kit1.id or choice == kit2.id then
				return choice == kit1.id
			end
		end
	end

	return Kit.DamageBonusPreferred(a, b)
end

function Kit.CombineKits(creature, a, b)
	local damageBonuses = DeepCopy(a:DamageBonuses())
	local damage_b = b:DamageBonuses()

	for key,value in pairs(damage_b) do
		if damageBonuses[key] == nil then
			damageBonuses[key] = value
		else
			if not Kit.DamageBonusSelected(creature, key, a, b) then
				damageBonuses[key] = damage_b[key]
			end
		end
	end

	local abilities = a:SignatureAbilities()
    for i=1,#abilities do
        abilities[i] = abilities[i]:MakeTemporaryClone()
        ApplyDamageFromKit(a, abilities[i], nil, function(a,b) return a - b end)
    end
	for _,a in ipairs(b:SignatureAbilities()) do
        local ability = a:MakeTemporaryClone()
        ApplyDamageFromKit(b, ability, nil, function(a,b) return a - b end)
		abilities[#abilities+1] = ability
	end

	local result = Kit.new{
		id = a.id .. b.id,
		name = string.format("%s/%s", a.name, b.name),
		damageBonuses = damageBonuses,
		health = max(a.health, b.health),
		speed = max(a.speed, b.speed),
		damage = max(a.damage, b.damage),
		range = max(a.range, b.range),
		reach = max(a.reach, b.reach),
		area = max(a.area, b.area),
		stability = max(a.stability, b.stability),
		signatureAbilities = abilities,
	}

    for i=1,#abilities do
        abilities[i] = abilities[i]:MakeTemporaryClone()
        local modificationLog = {}
        ApplyDamageFromKit(result, abilities[i], modificationLog)
		if #modificationLog > 0 then
			local log = abilities[i]:get_or_add("modificationLog", {})
			log[#log+1] = string.format("Includes %s from %s kit", string.join(modificationLog, ", "), result.name)
		end
    end

	return result
end

function Kit:StatsFeature(creature)

	return CharacterFeature.new{
		guid = dmhub.GenerateGuid(),
		name = string.format("%s Kit Stats", self.name),
		description = string.format("Health: %d\nSpeed: %d\nStability: %d\nDamage: %d\nRange: %d\nReach: %d", self.health, self.speed, self.stability, self.damage, self.range, self.reach),
		modifiers = {
			CharacterModifier.new{
				attribute = "hitpoints",
				behavior = "attribute",
				description = string.format("Health: %d", self.health),
				name = self.name,
				source = string.format("%s Kit", self.name),
				sourceguid = self.id,
				value = self.health*creature:Echelon(),
			},

			CharacterModifier.new{
				attribute = "speed",
				behavior = "attribute",
				description = string.format("Speed: %d", self.speed),
				name = self.name,
				source = string.format("%s Kit", self.name),
				sourceguid = self.id,
				value = self.speed,
			},

			CharacterModifier.new{
				attribute = "forcedmoveresistance",
				behavior = "attribute",
				description = string.format("Stability: %d", self.stability),
				name = self.name,
				source = string.format("%s Kit", self.name),
				sourceguid = self.id,
				value = self.stability,
			},

			CharacterModifier.new{
				behavior = "kitmodifyability",
				kitType = self.type,
				damage = self.damage,
				range = self.range,
				reach = self.reach,
				area = self.area,
				kit = self,
			}
		}
	}
end

function Kit:FillClassFeatures(creature, choices, result)
	result[#result+1] = self:StatsFeature(creature)

	for i,feature in ipairs(self:GetClassLevel().features) do

		if feature.typeName == 'CharacterFeature' then
			result[#result+1] = feature
		else
			feature:FillChoice(choices, result)
		end
	end
end

--result is filled with a list of { kit = Kit object, feature = CharacterFeature or CharacterChoice }
function Kit:FillFeatureDetails(creature, choices, result)
	local statsFeatures = {}
	self:StatsFeature(creature):FillFeaturesRecursive(choices, statsFeatures)
	for i,resultFeature in ipairs(statsFeatures) do
		result[#result+1] = {
			kit = self,
			feature = resultFeature,
		}
	end

	for i,feature in ipairs(self:GetClassLevel().features) do
		local resultFeatures = {}
		feature:FillFeaturesRecursive(choices, resultFeatures)

		for i,resultFeature in ipairs(resultFeatures) do
			result[#result+1] = {
				kit = self,
				feature = resultFeature,
			}
		end
	end
	
end

function Kit:FeatureSourceName()
	return string.format("%s Kit Feature", self.name)
end

--this is where a kit stores its modifiers etc, which are very similar to what a class gets.
function Kit:GetClassLevel()
	if self:try_get("modifierInfo") == nil then
		self.modifierInfo = ClassLevel:CreateNew()
	end

	return self.modifierInfo
end

function Kit.GetDropdownList()
	local result = {
		{
			id = 'none',
			text = 'Choose...',
		}
	}
	local backgroundsTable = dmhub.GetTable(Kit.tableName)
	for k,v in pairs(backgroundsTable) do
		result[#result+1] = { id = k, text = v.name }
	end
	table.sort(result, function(a,b)
		return a.text < b.text
	end)
	return result
end

ApplyDamageFromKit = function(kit, ability, modificationLog, additionFunction)
    additionFunction = additionFunction or function(a,b) return a + b end

	local powerRollBehavior = nil
	for _,behavior in ipairs(ability.behaviors) do
		if behavior.typeName == "ActivatedAbilityPowerRollBehavior" then
			powerRollBehavior = behavior
			break
		end
	end

    if powerRollBehavior == nil then
        return
    end

	for _,damageBonusType in ipairs(Kit.damageBonusTypes) do
		local bonuses = kit:DamageBonuses()[damageBonusType.id]
		if bonuses ~= nil and DamageBonusTypeMatchesAbility(ability, damageBonusType) then
			for i,bonus in ipairs(bonuses) do
				local tier = powerRollBehavior.tiers[i]
				if tier ~= nil then
					local match = regex.MatchGroups(tier, "(?<damage>\\d+)( [ a-z+]+)? damage", {indexes = true})
					if match ~= nil then
						local index = match.damage.index
						local length = match.damage.length

						local before = string.sub(tier, 1, index-1)
						local after = string.sub(tier, index+length)

						local newTier = string.format("%s%d%s", before, additionFunction(tonumber(match.damage.value), bonus), after)
						powerRollBehavior.tiers[i] = newTier
					end
				end
			end

            if modificationLog ~= nil then
			    modificationLog[#modificationLog+1] = string.format("%s damage", kit:FormatDamageBonus(damageBonusType.id))
            end
		end
	end
end


CharacterModifier.TypeInfo.kitmodifyability = {
	init = function(modifier)
	end,


	willModifyAbility = function(modifier, creature, ability)
		local kitType = Kit.kitTypesById[modifier.kitType]
		for _,keyword in ipairs(kitType.keywords) do
			if ability.keywords[keyword] then
				return true
			end
		end

		return false
	end,


	modifyAbility = function(modifier, creature, ability)
		if ability.keywords["Kit"] then
			--don't modify abilities that come from kits.
			return ability
		end

		if CharacterModifier.TypeInfo.kitmodifyability.willModifyAbility(modifier, creature, ability) == false then
			return ability
		end

		ability = ability:MakeTemporaryClone()

		local powerRollBehavior = nil
		for _,behavior in ipairs(ability.behaviors) do
			if behavior.typeName == "ActivatedAbilityPowerRollBehavior" then
				powerRollBehavior = behavior
				break
			end
		end

		local modificationLog = {}

		local range = 0
		local rangeDescription = ""
		if ability.keywords["Melee"] then
			range = modifier.reach
			rangeDescription = "reach"
		elseif ability.keywords["Ranged"] then
			range = modifier.range
			rangeDescription = "range"
		elseif ability.keywords["Area"] and ability.targetType == "all" then
			--this is 'burst' type area effect. Different to area abilities which also have a range.
			range = modifier.area
			rangeDescription = "area"
		end
		if range > 0 then
			if type(ability.range) == "number" then
				ability.range = ability.range + range
			elseif type(ability.range) == "string" then
				if tonumber(ability.range) ~= nil then
					ability.range = tonumber(ability.range) + range
				else
					ability.range = ability.range .. string.format(" + %d", range)
				end
			end

			modificationLog[#modificationLog+1] = string.format("+%d %s", range, rangeDescription)
		end

		local area = modifier.area
		if type(area) == "number" and area > 0 then
			if ability:has_key("radius") then
				ability.radius = ability.radius + area
				modificationLog[#modificationLog+1] = string.format("+%d %s", area, "area")
			end
		end

		local kit = modifier.kit

        ApplyDamageFromKit(kit, ability, modificationLog)

		if #modificationLog > 0 then
			local log = ability:get_or_add("modificationLog", {})
			log[#log+1] = string.format("Includes %s from %s kit", string.join(modificationLog, ", "), kit.name)
		end

		return ability
	end,
}

function Kit:Render(args, params)
	args = args or {}

    if args.width ~= nil and args.width > 600 then
        args.width = 600
    end

	local abilityPanels = {}

	for _,ability in ipairs(self:SignatureAbilities()) do
		abilityPanels[#abilityPanels+1] = ability:Render({
			pad = 12,
			width = "100%",
		}, {

		})
	end

	local maneuverPanel = nil
	if self.kitManeuver ~= false then
		maneuverPanel = self.kitManeuverAbility:Render({
			pad = 12,
			width = "100%",
		}, {

		})
	end

	local portraitBackground = gui.Panel{
		id = "portrait",
		halign = "center",
		valign = "top",
        floating = true,
        width = "100%",
        height = "100% width",
		bgcolor = "#ffffff06",
		bgimage = self.portraitid,
	}

	local options = {
		width = 500,
		height = "auto",
		flow = "vertical",
		styles = {Styles.Default, SpellRenderStyles},

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

				gui.Label{
                    classes = {"description"},
                    uppercase = true,
                    fontSize = 28,
					text = string.format("<b>%s</b>", self.name),
					width = "auto",
                    height = "auto",
				},
			},
		},

		gui.Panel{
			classes = "divider",
		},

		gui.Label{
			classes = {"description"},
			text = self.description,
			width = "100%",
			height = "auto",
		},

		gui.Label{
			classes = {"description"},
			smallcaps = true,
			fontSize = 22,
			text = "Equipment",
		},

		gui.Label{
			classes = {"description"},
			text = self.equipmentDescription,
			width = "100%",
			height = "auto",
		},

		gui.Label{
			classes = {"description"},
			smallcaps = true,
			fontSize = 22,
			text = "Bonuses",
		},

		gui.Panel{
			flow = "vertical",
			width = "100%",
			height = "auto",
			create = function(element)
				local children = {}
				if self.health ~= 0 then
					children[#children+1] = gui.Label{
						classes = {"description"},
						text = string.format("%s <b>Stamina Bonus:</b> +%d", Styles.bullet, self.health),
						width = "100%",
						height = "auto",
					}
				end
				if self.speed ~= 0 then
					children[#children+1] = gui.Label{
						classes = {"description"},
						text = string.format("%s <b>Speed Bonus:</b> +%d", Styles.bullet, self.speed),
						width = "100%",
						height = "auto",
					}
				end
				if self.range ~= 0 then
					children[#children+1] = gui.Label{
						classes = {"description"},
						text = string.format("%s <b>Distance Bonus:</b> +%d", Styles.bullet, self.range),
						width = "100%",
						height = "auto",
					}
				end
				if self.reach ~= 0 then
					children[#children+1] = gui.Label{
						classes = {"description"},
						text = string.format("%s <b>Reach Bonus:</b> +%d", Styles.bullet, self.reach),
						width = "100%",
						height = "auto",
					}
				end
				if self.area ~= 0 then
					children[#children+1] = gui.Label{
						classes = {"description"},
						text = string.format("%s <b>Area Bonus:</b> +%d", Styles.bullet, self.area),
						width = "100%",
						height = "auto",
					}
				end
				if self.stability ~= 0 then
					children[#children+1] = gui.Label{
						classes = {"description"},
						text = string.format("%s <b>Stability Bonus:</b> +%d", Styles.bullet, self.stability),
						width = "100%",
						height = "auto",
					}
				end

				for _,damageBonusType in ipairs(Kit.damageBonusTypes) do
					local bonus = self:FormatDamageBonus(damageBonusType.id)
					if bonus ~= nil then
						children[#children+1] = gui.Label{
							classes = {"description"},
							text = string.format("%s <b>%s Damage Bonus:</b> %s", Styles.bullet, damageBonusType.text, bonus),
							width = "100%",
							height = "auto",
						}
					end

				end

				element.children = children
			end,
		},

		abilityPanels[1], abilityPanels[2], abilityPanels[3], abilityPanels[4],
		maneuverPanel,
	}

	for k,v in pairs(args or {}) do
		options[k] = v
	end

	return gui.Panel(options)
end

GameSystem.RegisterModifiableAttribute{
	id = "numkits",
	text = "Number of Kits",
	attributeType = "number",
	category = "Basic Attributes",
}

function creature:GetNumberOfKits()
    return 0
end

function character:GetNumberOfKits()
	local c = self:GetClass()
	if c ~= nil then
		return c.numKits
	end

	return 1
end

--modifier that allows access to new types of kits.
CharacterModifier.RegisterType("kitaccess", "Access to new types of kits")

CharacterModifier.TypeInfo.kitaccess = {
	init = function(modifier)
		modifier.kitType = "none"
	end,

	createEditor = function(modifier, element)
		local children = {}
		children[#children+1] = gui.Dropdown{
			idChosen = modifier.kitType,
			options = Kit.kitTypes,
			change = function(element)
				modifier.kitType = element.idChosen
			end,
		}

		element.children = children
	end,

	allowKits = function(modifier, context, casterCreature, result)
		if modifier.kitType == "none" then
			return
		end

		result[modifier.kitType] = true
	end,
}

function CharacterModifier:AllowKits(context, casterCreature, result)
	local typeInfo = CharacterModifier.TypeInfo[self.behavior] or {}
    local allowKits = typeInfo.allowKits
	if allowKits ~= nil then
		allowKits(self, context, casterCreature, result)
	end
end

function creature:KitTypesAllowed()
	local result = {}
	for _,kitType in ipairs(Kit.kitTypes) do
		if Kit.lockedKitTypes[kitType.id] then
			result[kitType.id] = false
		else
			result[kitType.id] = true
		end
	end
	for _,mod in ipairs(self:GetActiveModifiers()) do
		mod.mod:AllowKits(mod, self, result)
	end

	return result
end

function creature:CanHaveKits()
    local result = {}
	for _,mod in ipairs(self:GetActiveModifiers()) do
		mod.mod:AllowKits(mod, self, result)
	end

    return not table.empty(result)
end