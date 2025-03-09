local mod = dmhub.GetModLoading()

local function CreateRulerPanel()
	local hud = gamehud
	local persistentSetting = nil
	if dmhub.isDM then
		persistentSetting = CreateSettingsEditor("measure:persistent")
	end
	local resultPanel = gui.Panel{
		width = 340,
		height = 240,
		halign = "right",
		valign = "top",
		flow = "vertical",

		create = function(element)
			dmhub.rulerToolActive = true
		end,

		destroy = function(element)
			dmhub.rulerToolActive = false
		end,

		gui.Label{
			text = "Measuring Tool",
			fontSize = 24,
			bold = true,
			color = "white",
			width = "auto",
			height = "auto",
			halign = "center",
		},
		CreateSettingsEditor("measure:shape"),
		CreateSettingsEditor("measure:coneangle"),
		CreateSettingsEditor("measure:linewidth"),
		CreateSettingsEditor("measure:share"),
		CreateSettingsEditor("measure:snap"),
		persistentSetting,

	}

	return resultPanel
end


LaunchablePanel.Register{
	name = "Measuring Tool",
	icon = "icons/icon_tool/icon_tool_101.png",
	halign = "right",
	valign = "top",
	content = function()
		return CreateRulerPanel()
	end,
}


function GameHud:ShowTooltipNearTile(text, loc)
	self.dialog.sheet:FireEvent("tiletooltip", {
		loc = loc,
		text = text,
	})
		
end
