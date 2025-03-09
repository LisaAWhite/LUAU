local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityCast")

ActivatedAbilityCast.damagedealt = 0
ActivatedAbilityCast.damageraw = 0

ActivatedAbilityCast.naturalattackroll = 0
ActivatedAbilityCast.attackroll = 0
ActivatedAbilityCast.healing = 0
ActivatedAbilityCast.healroll = 0
ActivatedAbilityCast.roll = 0
ActivatedAbilityCast.spacesMoved = 0

ActivatedAbilityCast.helpSymbols = {
	__name = "spellcast",
	__sampleFields = {"damagedealt"},


	damagedealt = {
		name = "Damage Dealt",
		type = "number",
		desc = "The amount of damage dealt while using this spell.",
		examples = {"Damage Dealt > 5"},
	},

	damageraw = {
		name = "Damage Raw",
		type = "number",
		desc = "The amount of raw damage (before resistance modifiers) dealt while using this spell.",
		examples = {"Damage Raw > 5"},
	},

	damagedealtagainst = {
		name = "Damage Dealt Against",
		type = "number",
		desc = "The amount of damage dealt against a specific target while using this spell.",
		examples = {"Damage Dealt Against(self) > 5"},
	},

	damagerawagainst = {
		name = "Damage Raw Against",
		type = "number",
		desc = "The amount of raw damage (before resistance modifiers) dealt against a specific target while using this spell.",
		examples = {"Damage Raw Against(self) > 5"},
	},

	naturalattackroll = {
		name = "Natural Attack Roll",
		type = "number",
		desc = "The unmodified d20 attack roll made while using this spell.",
	},

	attackroll = {
		name = "Attack Roll",
		type = "number",
		desc = "The attack roll made while using this spell.",
	},

	healing = {
		name = "Healing",
		type = "number",
		desc = "The amount of healing made while using this spell.",
	},
	healroll = {
		name = "Heal Roll",
		type = "number",
		desc = "The healing roll made while using this spell.",
	},
	ability = {
		name = "Ability",
		type = "ability",
		desc = "The ability or spell that is being cast.",
	},
	roll = {
		name = "Roll",
		type = "number",
		desc = "The roll made while using this spell.",
	},
	targetcount = {
		name = "Target Count",
		type = "number",
		desc = "The number of creatures this spell is targeting.",
	},
	spacesmoved = {
		name = "Spaces Moved",
		type = "number",
		desc = "The number of spaces moved while using this spell.",
	}
}

ActivatedAbilityCast.lookupSymbols = {
	datatype = function(c)
		return "cast"
	end,

	ability = function(c)
		return c.ability
	end,

	damagedealt = function(c)
		return c.damagedealt
	end,

	damageraw = function(c)
		return c.damageraw
	end,

	damagedealtagainst = function(c)
		return function(target)
			if type(target) == "function" then
				target = target("self")
			end

			if type(target) == "table" then
				local tok = dmhub.LookupToken(target)
				if tok ~= nil then
					local entry = c.damageTable[tok.charid]
					if entry ~= nil then
						return entry.dealt
					end
				end
			end
		end

	end,

	damagerawagainst = function(c)
		return function(target)
			if type(target) == "function" then
				target = target("self")
			end

			if type(target) == "table" and target.typeName == "creature" then
				local tok = dmhub.LookupToken(target)
				if tok ~= nil then
					local entry = c.damageTable[tok.charid]
					if entry ~= nil then
						return entry.raw
					end
				end
			end

		end
	end,

	naturalattackroll = function(c)
		return c.naturalattackroll
	end,

	attackroll = function(c)
		return c.attackroll
	end,

	healing = function(c)
		return c.healing
	end,

	healroll = function(c)
		return c.healroll
	end,

	roll = function(c)
		return c.roll
	end,

	targetcount = function(c)
		local result = 0
		for i,target in ipairs(c:try_get("targets", {})) do
			if target.token ~= nil then
				result = result+1
			end
		end

		return result
	end,

	spacesmoved = function(c)
		return c.spacesMoved
	end,
}

function ActivatedAbilityCast:CountDamage(targetToken, damageDealt, damageRaw)
	self.damagedealt = self.damagedealt + damageDealt
	self.damageraw = self.damageraw + damageRaw

	self.damageTable = self:try_get("damageTable", {})

	self.damageTable[targetToken.charid] = self.damageTable[targetToken.charid] or { dealt = 0, raw = 0 }
	self.damageTable[targetToken.charid].dealt = self.damageTable[targetToken.charid].dealt + damageDealt
	self.damageTable[targetToken.charid].raw = self.damageTable[targetToken.charid].raw + damageRaw
end

function ActivatedAbilityCast:AddParam(args)
	local params = self:get_or_add("params", {})
	params[args.id] = params[args.id] or {}
	local list = params[args.id]
	list[#list+1] = args
end

function ActivatedAbilityCast:GetParamModifications(id)
	local params = self:try_get("params", {})
	return params[id] or {}
end