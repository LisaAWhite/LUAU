local mod = dmhub.GetModLoading()

MCDMUtils = {
    GetStandardAbility = function(name)
        name = string.lower(name)
        local abilityTable = dmhub.GetTable("standardAbilities")
        for key,ability in pairs(abilityTable) do
            if string.lower(ability.name) == name then
                return ability
            end
        end
    
        return nil
    end
}

MCDMUtils.DeepReplace = function(node, from, to)
    if type(node) ~= "table" then
        return
    end

    for k,v in pairs(node) do
        if v == from then
            node[k] = to
        elseif type(v) == "string" then
            node[k] = regex.ReplaceAll(v, from, to)
        else
            MCDMUtils.DeepReplace(v, from, to)
        end
    end
end