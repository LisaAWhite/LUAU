local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityAugmentedAbilityBehavior", "ActivatedAbilityBehavior")


function ActivatedAbilityAugmentedAbilityBehavior:SynthesizeAbilities(ability, creature)
	print("Invoke:: SynthesizeAbilities...")
	local abilities = creature:GetActivatedAbilities()

	local typeInfo = CharacterModifier.TypeInfo[self.modifier.behavior]
	local filterFunction = typeInfo.willModifyAbility
	local modifierFunction = typeInfo.modifyAbility

	local result = {}

	for _,a in ipairs(abilities) do
		if a ~= ability and filterFunction(self.modifier, creature, a) then
			local synth = DeepCopy(a)
			synth.temporaryClone = true

			--we copy some casting time and resource usage aspects of the synthesizer into the synthesized
			--ability. Note that we must take care to make sure that it's still a valid instance of
			--the target type.
			synth.actionResourceId = ability:try_get("actionResourceId")
			synth.actionNumber = ability.actionNumber
			synth.castingTime = ability.castingTime
			synth.castingTimeDuration = ability:try_get("castingTimeDuration")
			synth.resourceCost = ability.resourceCost
			synth.resourceNumber = ability.resourceNumber
			synth.usesSpellSlots = ability.usesSpellSlots
			if ability:has_key("level") then
				synth.level = ability.level
			end
			synth = modifierFunction(self.modifier, creature, synth)

			result[#result+1] = synth
		end
	end

	return result
end

function ActivatedAbilityAugmentedAbilityBehavior.AbilityModifierEditor(self, parentPanel, list)
	local element = gui.Panel{
		x = 20,
		width = "auto",
		height = "auto",
		flow = "vertical",
	}

	local typeInfo = CharacterModifier.TypeInfo[self.modifier.behavior] or {}
	local createEditor = typeInfo.createEditor
	if createEditor ~= nil then
		createEditor(self.modifier, element)
	end

	list[#list+1] = element
end

function ActivatedAbilityAugmentedAbilityBehavior:EditorItems(parentPanel)
	local result = {}
	self:AbilityModifierEditor(parentPanel, result)
	return result
end