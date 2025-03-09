local mod = dmhub.GetModLoading()

ActivatedAbilityCast.boonsApplied = 0
ActivatedAbilityCast.banesApplied = 0

GameSystem.RegisterGoblinScriptField{
    target = ActivatedAbilityCast,
    name = "Boons",
    type = "number",
    desc = "The number of boons applied while using this ability.",
    seealso = {},
    examples = {},
    calculate = function(c)
        return c.boonsApplied
    end,
}

GameSystem.RegisterGoblinScriptField{
    target = ActivatedAbilityCast,
    name = "Banes",
    type = "number",
    desc = "The number of banes applied while using this ability.",
    seealso = {},
    examples = {},
    calculate = function(c)
        return c.banesApplied
    end,
}