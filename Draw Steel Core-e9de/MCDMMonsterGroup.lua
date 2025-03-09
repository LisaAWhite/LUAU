local mod = dmhub.GetModLoading()

RegisterGameType("MonsterGroup")

function MonsterGroup.CreateNew(args)
    local params = {
        attacks = {},
        traits = {},
    }

    for k,v in pairs(args) do
        params[k] = v
    end

    return MonsterGroup.new(params)
end

MonsterGroup.tableName = "MonsterGroup"

MonsterGroup.name = "Monster Group"
MonsterGroup.reach = 5
MonsterGroup.size = "1M"
MonsterGroup.weight = 1

MonsterGroup.commonTraits = {}
MonsterGroup.languages = {}
MonsterGroup.keywords = {}
MonsterGroup.attacks = {}
MonsterGroup.traits = {}

function MonsterGroup.Get(id)
    local t = dmhub.GetTable(MonsterGroup.tableName)
    return t[id]
end

function MonsterGroup:Render(args, options)
	args = args or {}

    local panelParams = {
        styles = Styles.Default,
        width = 500,
        height = "auto",
        flow = "vertical",

        gui.Label{
            classes = {"title"},
            text = self.name,
            width = "auto",
            height = "auto",
        }
    }

	for k,v in pairs(args or {}) do
		panelParams[k] = v
	end

    return gui.Panel(panelParams)

end