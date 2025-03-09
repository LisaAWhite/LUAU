local mod = dmhub.GetModLoading()

RegisterGameType("GlobalRuleMod")

GlobalRuleMod.TableName = "globalRuleMods"

GlobalRuleMod.applyCharacters = true
GlobalRuleMod.applyMonsters = true

function GlobalRuleMod.CreateNew(name)
	return GlobalRuleMod.new{
		name = name,
	}
end

function GlobalRuleMod:FillClassFeatures(choices, result)
	for i,feature in ipairs(self:GetClassLevel().features) do

		if feature.typeName == 'CharacterFeature' then
			result[#result+1] = feature
		else
			if choices[feature.guid] ~= nil then
				feature:FillChoice(choices, result)
			end
		end
	end
end

--result is filled with a list of { race = GlobalRuleMod object, feature = CharacterFeature or CharacterChoice }
function GlobalRuleMod:FillFeatureDetails(choices, result)
	for i,feature in ipairs(self:GetClassLevel().features) do
		result[#result+1] = {
			race = self,
			feature = feature,
		}
	end
	
end

function GlobalRuleMod:FeatureSourceName()
	return string.format("%s Global Rule Mod Feature", self.name)
end

--this is where a global rule mod stores its modifiers etc, which are very similar to what a class gets.
function GlobalRuleMod:GetClassLevel()
	if self:try_get("modifierInfo") == nil then
		self.modifierInfo = ClassLevel:CreateNew()
	end

	return self.modifierInfo
end

