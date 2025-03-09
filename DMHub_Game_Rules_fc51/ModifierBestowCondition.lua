local mod = dmhub.GetModLoading()


CharacterModifier.RegisterType('bestowcondition', "Bestow Condition")

CharacterModifier.TypeInfo.bestowcondition = {

	init = function(modifier)
		modifier.conditionid = 'none'
    end,

    bestowConditions = function(modifier, creature, conditionsRecorded)
        if modifier.conditionid ~= 'none' then
            conditionsRecorded[modifier.conditionid] = (conditionsRecorded[modifier.conditionid] or 0) + 1
        end
    end,

    createEditor = function(modifier, element)
        local Refresh

        local firstRefresh = true

        Refresh = function()
            if firstRefresh then
                firstRefresh = false
            else
                element:FireEvent("refreshModifier")
            end

            local children = {}
			children[#children+1] = modifier:FilterConditionEditor()

            local options = {
                {
                    id = "none",
                    text = "(None)",
                }
            }

            local conditionsTable = dmhub.GetTable(CharacterCondition.tableName)
            for key,conditionInfo in pairs(conditionsTable or {}) do
                if conditionInfo:try_get("hidden", false) == false then
                    options[#options+1] = {
                        id = key,
                        text = conditionInfo.name,
                    }
                end
            end

            children[#children+1] = gui.Panel{
                classes = {'formPanel'},
                children = {
                    gui.Label{
                        text = 'Bestow:',
                        classes = {'formLabel'},
                    },
                    gui.Dropdown{
                        selfStyle = {
                            height = 30,
                            width = 260,
                            fontSize = 16,
                        },
                        options = options,

                        idChosen = modifier.conditionid,

                        events = {
                            change = function(element)
                                modifier.conditionid = element.idChosen
                                Refresh()
                            end,
                        },
                    },
                }
            }

            element.children = children
        end

        Refresh()
    end,
}