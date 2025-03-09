local mod = dmhub.GetModLoading()

CharacterResource.heroicResourceId = "2d3d5511-4b80-46d1-a8c6-4705b9aa45ca"
CharacterResource.maliceResourceId = "101bab52-7f7c-4bab-92c2-9f8e0cfb7ec8"

monster.resourceid = CharacterResource.maliceResourceId
character.resourceid = CharacterResource.heroicResourceId

monster.resourceRefresh = "global"
creature.resourceRefresh = "unbounded"

function creature:GetHeroicOrMaliceResourcesAvailable()
    local resources = self:GetResources()
    return resources[self.resourceid] or 0
end

function creature:ResourceName()
    local t = dmhub.GetTable(CharacterResource.tableName)
    return t[self.resourceid].name
end