local mod = dmhub.GetModLoading()


local SetGlobalRuleMod = function(tableName, ruleModPanel, ruleModid)
	local ruleModTable = dmhub.GetTable(tableName) or {}
	local ruleMod = ruleModTable[ruleModid]
	local UploadGlobalRuleMod = function()
		dmhub.SetAndUploadTableItem(tableName, ruleMod)
	end

	local children = {}

	--the name of the ruleMod.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		gui.Label{
			text = 'Name:',
			valign = 'center',
			minWidth = 240,
		},
		gui.Input{
			text = ruleMod.name,
			change = function(element)
				ruleMod.name = element.text
				UploadGlobalRuleMod()
			end,
		},
	}

	--who the mod applies to.
	children[#children+1] = gui.Panel{
		classes = {"formPanel"},
		gui.Label{
			text = 'Apply To:',
			valign = 'center',
			minWidth = 240,
		},
		gui.Dropdown{
			options = {
				{
					id = "none",
					text = "Disabled",
				},
				{
					id = "monsters",
					text = "Monsters",
				},
				{
					id = "characters",
					text = "Characters",
				},
				{
					id = "all",
					text = "All Creatures",
				},
			},
			idChosen = cond(ruleMod.applyCharacters, cond(ruleMod.applyMonsters, "all", "characters"), cond(ruleMod.applyMonsters, "monsters", "none")),
			change = function(element)
				ruleMod.applyCharacters = element.idChosen == "characters" or element.idChosen == "all"
				ruleMod.applyMonsters = element.idChosen == "monsters" or element.idChosen == "all"
				UploadGlobalRuleMod()
			end,
		},
	}

	children[#children+1] = ruleMod:GetClassLevel():CreateEditor(ruleMod, 0, {
		change = function(element)
			ruleModPanel:FireEvent("change")
			UploadGlobalRuleMod()
		end,
	})
	ruleModPanel.children = children
end

function GlobalRuleMod.CreateEditor()
	local ruleModPanel
	ruleModPanel = gui.Panel{
		data = {
			SetGlobalRuleMod = function(tableName, ruleModid)
				SetGlobalRuleMod(tableName, ruleModPanel, ruleModid)
			end,
		},
		vscroll = true,
		classes = 'class-panel',
		styles = {
			{
				halign = "left",
			},
			{
				classes = {'class-panel'},
				width = 1200,
				height = '90%',
				halign = 'left',
				flow = 'vertical',
				pad = 20,
			},
			{
				classes = {'label'},
				color = 'white',
				fontSize = 22,
				width = 'auto',
				height = 'auto',
			},
			{
				classes = {'input'},
				width = 200,
				height = 26,
				fontSize = 18,
				color = 'white',
			},
			{
				classes = {'formPanel'},
				flow = 'horizontal',
				width = 'auto',
				height = 'auto',
				halign = 'left',
				vmargin = 2,
			},

		},
	}

	return ruleModPanel
end
