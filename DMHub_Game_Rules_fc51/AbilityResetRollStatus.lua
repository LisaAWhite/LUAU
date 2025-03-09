local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityResetRollStatusBehavior", "ActivatedAbilityBehavior")

ActivatedAbilityResetRollStatusBehavior.summary = 'Reset Roll Status'

ActivatedAbility.RegisterType
{
    id = "resetrollstatus",
    text = "Reset Roll Status",
    canHaveDC = false,
    createBehavior = function()
        return ActivatedAbilityResetRollStatusBehavior.new{
        }
    end,
}

function ActivatedAbilityResetRollStatusBehavior:SummarizeBehavior(ability, creatureLookup)
    return "Reset Roll Status"
end

function ActivatedAbilityResetRollStatusBehavior:Cast(ability, casterToken, targets, options)
    options.hit_targets = {}
    options.hit_targets_crit = {}
end

function ActivatedAbilityResetRollStatusBehavior:EditorItems(parentPanel)
	local result = {}
	return result
end