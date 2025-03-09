local mod = dmhub.GetModLoading()


function creature:Kit()
    return nil
end

function character:KitID()
    return self:try_get("kitid")
end

function character:Kit()
	local table = dmhub.GetTable(Kit.tableName)
	local kit = table[self:KitID()]
	if kit ~= nil then

		if self:has_key("kitid2") and self:GetNumberOfKits() > 1 then
			local kit2 = table[self.kitid2]
			if kit2 ~= nil then
				kit = Kit.CombineKits(self, kit, kit2)
			end
		end

		return kit
	elseif self:has_key("kitid2") and self:GetNumberOfKits() > 1 then
		return table[self.kitid2]
	end

	return nil
end

--how we calculate the basic features a character gets.
function character:GetClassFeatures(options)
	options = options or {}
	local result = {}

	local levelChoices = self:GetLevelChoices()

	local characterType = self:CharacterType()
	if characterType ~= nil then
		characterType:FillClassFeatures(levelChoices, result)
	end

	local race = self:Race()
	if race ~= nil then
		race:FillClassFeatures(self:CharacterLevel(), levelChoices, result)
	end

	local subrace = self:Subrace()
	if subrace ~= nil then
		subrace:FillClassFeatures(self:CharacterLevel(), levelChoices, result)
	end

    local career = self:Background()
    if career ~= nil then
        career:FillClassFeatures(levelChoices, result)
    end

    local culture = self:GetCulture()
    if culture ~= nil and culture.init then
        culture:FillClassFeatures(self:GetLevelChoices(), result)
    end

	local kit = self:Kit()
	if kit ~= nil then
		kit:FillClassFeatures(self, levelChoices, result)
	end

	for i,entry in ipairs(self:GetClassesAndSubClasses()) do
		if i == 1 then
			result[#result+1] = entry.class:GetPrimaryFeature()
			
		end

		entry.class:FillFeaturesForLevel(levelChoices, entry.level, i ~= 1, result)
	end
	
	for i,featid in ipairs(self:try_get("creatureFeats", {})) do
		local featTable = dmhub.GetTable(CharacterFeat.tableName) or {}
		local featInfo = featTable[featid]
		if featInfo ~= nil then
			featInfo:FillClassFeatures(levelChoices, result)
		end
	end

	--handle cases where we duplicates choices of skill or tool proficiencies from multiple sources, in which case the player gets some extra
	--choices to replace them with other proficiencies of their choice.
	if levelChoices[CharacterSkillsChoice.guid] ~= nil or levelChoices[CharacterToolsChoice.guid] ~= nil or options.duplicatesTable ~= nil then
		local skillDuplicates = {}
		local toolDuplicates = {}
		for i,feature in ipairs(result) do
			for j,mod in ipairs(feature.modifiers) do
				mod:AccumulateDuplicateProficiencies(skillDuplicates, toolDuplicates)
			end
		end

		local numSkillDups = 0
		local numToolDups = 0
		for k,count in pairs(skillDuplicates) do
			if count > 1 then
				numSkillDups = numSkillDups + count - 1
			end
		end
		
		for k,count in pairs(toolDuplicates) do
			if count > 1 then
				numToolDups = numToolDups + count - 1
			end
		end


		if numSkillDups > 0 then
			local choice = CharacterSkillsChoice.Create(numSkillDups, skillDuplicates)
			choice:FillChoice(levelChoices, result)
			if options.duplicatesTable ~= nil then
				options.duplicatesTable[#options.duplicatesTable+1] = choice
			end
		end

		if numToolDups > 0 then
			local choice = CharacterToolsChoice.Create(numToolDups, toolDuplicates)
			choice:FillChoice(levelChoices, result)
			if options.duplicatesTable ~= nil then
				options.duplicatesTable[#options.duplicatesTable+1] = choice
			end
		end

	end

	return result
end


--returns a list of { class/race/background/characterType = Class/Race/Background, levels = {list of ints}, feature = CharacterFeature or CharacterChoice }
function character:GetClassFeaturesAndChoicesWithDetails()
	local result = {}

	local characterType = self:CharacterType()
	if characterType ~= nil then
		characterType:FillFeatureDetails(self:GetLevelChoices(), result)
	end

	local race = self:Race()
	if race ~= nil then
		race:FillFeatureDetails(self:CharacterLevel(), self:GetLevelChoices(), result)
	end

	local subrace = self:Subrace()
	if subrace ~= nil then
		subrace:FillFeatureDetails(self:CharacterLevel(), self:GetLevelChoices(), result)
	end

    local career = self:Background()
    if career ~= nil then
        career:FillFeatureDetails(self:GetLevelChoices(), result)
    end

    local culture = self:GetCulture()
    if culture ~= nil and culture.init then
        culture:FillFeatureDetails(self:GetLevelChoices(), result)
    end

	local kit = self:Kit()
	if kit ~= nil then
		kit:FillFeatureDetails(self, self:GetLevelChoices(), result)
	end

	local classFeatures = {}

	for i,entry in ipairs(self:GetClassesAndSubClasses()) do
		entry.class:FillFeatureDetailsForLevel(self:GetLevelChoices(), entry.level, i ~= 1, classFeatures)
	end



	for _,f in ipairs(classFeatures) do
		result[#result+1] = f
	end

	for i,featid in ipairs(self:try_get("creatureFeats", {})) do
		local featTable = dmhub.GetTable(CharacterFeat.tableName) or {}
		local featInfo = featTable[featid]
		if featInfo ~= nil then
			featInfo:FillFeatureDetails(self:GetLevelChoices(), result)
		end
	end

	--get the choices for replacing tool and skill proficiencies that were duplicated.
	local duplicatesTable = {}
	self:GetClassFeatures{
		duplicatesTable = duplicatesTable
	}

	for i,dupChoice in ipairs(duplicatesTable) do
		result[#result+1] = {
			feature = dupChoice,
			race = race,
		}
	end

	return result
end

--resource grouping options.
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
        id = "Hidden",
        text = "Hidden",
    },
}