local mod = dmhub.GetModLoading()

function creature:GrantTemporaryStamina(amount, note)
	if self:TemporaryHitpoints() > amount then
		return
	end

	self:SetTemporaryHitpoints(amount, note)
end


RegisterGameType("ActivatedAbilityGrantTemporaryStaminaBehavior", "ActivatedAbilityBehavior")

ActivatedAbility.RegisterType
{
	id = 'grant_temporary_stamina',
	text = 'Grant Temporary Stamina',
	createBehavior = function()
		return ActivatedAbilityGrantTemporaryStaminaBehavior.new{
		}
	end
}

ActivatedAbilityGrantTemporaryStaminaBehavior.summary = 'Grant Temporary Stamina'
ActivatedAbilityGrantTemporaryStaminaBehavior.stamina = 5


function ActivatedAbilityGrantTemporaryStaminaBehavior:Cast(ability, casterToken, targets, options)
    if #targets == 0 then
        return
    end

    local granted = false

    for _,target in ipairs(targets) do
        local roll = dmhub.EvalGoblinScript(self.stamina, casterToken.properties:LookupSymbol(options.symbols), string.format("Grant stamina roll for %s", ability.name))
        if tonumber(roll) == nil then
            local result = nil
            local canceled = false
            local rollid = gamehud.rollDialog.data.ShowDialog{
                title = "Grant Stamina",
                description = string.format("Roll to grant stamina"),
                roll = roll,
                creature = casterToken.properties,
                skipDeterministic = true,
                type = "custom",

                cancelRoll = function()
                    canceled = true
                end,
                completeRoll = function(rollInfo)
                    result = rollInfo.total
                end,
            }

            while canceled == false and result == nil do
                coroutine.yield(0.1)
            end

            if tonumber(result) == nil then
                break
            end

            roll = result
        end

        target.token:ModifyProperties{
            description = "Grant Temporary Stamina",
            execute = function()
                target.token.properties:GrantTemporaryStamina(tonumber(roll))
            end,
        }
        granted = true
    end

    if granted then
        options.pay = true
    end
end

function ActivatedAbilityGrantTemporaryStaminaBehavior:EditorItems(parentPanel)
    local result = {}

    self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        gui.Label{
            classes = {"formLabel"},
            text = "Stamina:",
        },
        gui.GoblinScriptInput{
            value = self.stamina,
            change = function(element)
                self.stamina = element.value
            end,

			documentation = {
				help = string.format("This GoblinScript determines the amount of temporary stamina to grant"),
				output = "roll",
				examples = {
					{
						script = "8",
						text = "8 temporary stamina is granted.",
					},
					{
						script = "2*Reason",
						text = "Twice the caster's Reason is granted as temporary stamina.",
					},
					{
						script = "2d6",
						text = "2d6 Temporary Stamina is granted.",
					},
				},
				subject = creature.helpSymbols,
				subjectDescription = "The creature that is using the ability.",
				symbols = ActivatedAbility.helpCasting,
			},
        }
    }

    return result
end