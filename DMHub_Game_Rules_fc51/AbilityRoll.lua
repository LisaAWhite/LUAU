local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityRollBehavior", "ActivatedAbilityBehavior")


ActivatedAbilityRollBehavior.summary = 'Roll Dice'
ActivatedAbilityRollBehavior.consequenceText = ''
ActivatedAbilityRollBehavior.roll = ''
ActivatedAbilityRollBehavior.rollDescription = 'Roll Dice'


ActivatedAbility.RegisterType
{
	id = 'roll',
	text = 'Roll Dice',
	createBehavior = function()
		return ActivatedAbilityRollBehavior.new{
		}
	end
}

function ActivatedAbilityRollBehavior:SummarizeBehavior(ability, creatureLookup)
    return "Roll Dice"
end

function ActivatedAbilityRollBehavior:Cast(ability, casterToken, targets, options)

	if #targets == 0 then
		return
	end

	options.symbols = options.symbols or {}

    for i=1,#targets do
        local target = targets[i]
        local creature = nil
        if target ~= nil and target.token ~= nil then
            creature = target.token.properties
        end

        local complete = false
        local rollid
        rollid = GameHud.instance.rollDialog.data.ShowDialog{
            title = self.rollDescription,
            roll = dmhub.EvalGoblinScript(self.roll, casterToken.properties:LookupSymbol(options.symbols), self.rollDescription),
            description = self.rollDescription,
            creature = creature,

            completeRoll = function(rollInfo)
			    options.symbols.cast.roll = rollInfo.total
                options.pay = true
                complete = true
            end,

            cancelRoll = function()
                complete = true
            end,
        }

        while not complete do
			coroutine.yield(0.1)
        end
    end

end

function ActivatedAbilityRollBehavior:EditorItems(parentPanel)
	local result = {}

	result[#result+1] = gui.Panel{
		classes = "formPanel",
		gui.Label{
			classes = {"formLabel"},
			text = "Text:",
		},
		gui.Input{
            classes = {"formInput"},
			text = self.rollDescription,
			change = function(element)
				self.rollDescription = element.text
			end,
		},
	}

	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

	result[#result+1] = gui.Panel{
		classes = "formPanel",
		gui.Label{
			classes = "formLabel",
			text = "Roll:",
		},
		gui.GoblinScriptInput{
			value = self.roll,
			change = function(element)
				self.roll = element.value
			end,

			documentation = {
				domains = parentPanel.data.parentAbility.domains,
				help = string.format("The roll that will be made."),
				output = "number",
				examples = {
					{
						script = "3d6 + 4",
						text = "3d6 + 4 will be rolled.",
					},
					{
						script = "1d6 + Strength Modifier",
						text = "1d6 + the caster's Strength Modifier will be rolled.",
					},
				},
				subject = creature.helpSymbols,
				subjectDescription = "The target of the ability",
				symbols = ActivatedAbility.helpCasting,
			},
		},
	}

	return result
end