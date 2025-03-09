local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityFloatTextBehavior", "ActivatedAbilityBehavior")

ActivatedAbilityFloatTextBehavior.summary = 'Float Text'

ActivatedAbility.RegisterType
{
    id = "floattext",
    text = "Float Text",
    canHaveDC = false,
    createBehavior = function()
        return ActivatedAbilityFloatTextBehavior.new{
            text = "Text",
            color = "#ffffffff",
        }
    end,
}

function ActivatedAbilityFloatTextBehavior:SummarizeBehavior(ability, creatureLookup)
    return "Float Text"
end

function ActivatedAbilityFloatTextBehavior:Cast(ability, casterToken, targets, options)
    for _,target in ipairs(targets) do
        if target.token ~= nil then
            target.token:ModifyProperties{
                description = "Float text",
                undoable = false,
                execute = function()
                    target.token.properties:FloatLabel(self.text, self.color)
                end,
            }
        end
    end
end

function ActivatedAbilityFloatTextBehavior:EditorItems(parentPanel)
	local result = {}
	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        gui.Label{
            classes = {"formLabel"},
            text = "Text:",
        },
        gui.Input{
            classes = {"formInput"},
            text = self.text,
            change = function(element)
                self.text = element.text
            end,
        },
    }

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        gui.Label{
            classes = {"formLabel"},
            text = "Color:",
        },
        gui.ColorPicker{
            width = 16,
            height = 16,
            value = self.color,
            change = function(element)
                self.color = element.value
            end,
        },
    }

	return result
end