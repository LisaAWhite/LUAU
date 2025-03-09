local mod = dmhub.GetModLoading()

CharacterModifier.RegisterType("suppressabilities", "Suppress Abilities")


CharacterModifier.TypeInfo.suppressabilities = {

	init = function(modifier)
    end,

    createEditor = function(modifier, element)
        local Refresh

        Refresh = function()

            local children = {}

			children[#children+1] = modifier:FilterConditionEditor()

            children[#children+1] = gui.Panel{
                classes = {"formPanel"},
                gui.Label{
                    classes = {"formLabel"},
                    text = "Name:",
                },
                gui.Input{
                    classes = {"formInput"},
                    text = modifier:try_get("name", ""),
                    characterLimit = 64,
                    change = function(element)
                        modifier.name = element.text
                    end,
                }
            }

            for keyword,_ in pairs(GameSystem.abilityKeywords) do
                children[#children+1] = gui.Check{
                    text = keyword,
                    height = 30,
                    width = 160,
                    fontSize = 18,
                    halign = "left",

                    value = modifier:try_get("keywords", {})[keyword] == true,

                    change = function(element)
                        modifier:get_or_add("keywords", {})[keyword] = cond(element.value, true, nil)
                    end,

                }
            end

            element.children = children
        end

        Refresh()
    end,

    modifyAbility = function(modifier, creature, ability)
        if modifier:has_key("name") and string.lower(ability.name) == string.lower(modifier.name) then
            return nil
        end
        if modifier:has_key("keywords") then
            for keyword,_ in pairs(modifier.keywords) do
                if not ability.keywords[keyword] then
                    return nil
                end
            end
        end

        return ability
    end,
}