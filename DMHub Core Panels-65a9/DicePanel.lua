local mod = dmhub.GetModLoading()

local CreateDicePanel

DockablePanel.Register{
	name = "Dice",
	icon = mod.images.diceIcon,
	notitle = true,
	vscroll = false,
    dmonly = false,
	minHeight = 68,
	maxHeight = 68,
	content = function()
		return CreateDicePanel()
	end,
}

local styles = {

	{
		classes = "dice",
		bgcolor = "white",
		width = 40,
		height = 40,
		valign = "center",
		halign = "center",
		uiscale = 0.95,
		saturation = 0.7,
		brightness = 0.4,
	},

	{
		classes = {"dice", "gmonly"},
		saturation = 0.3,
		brightness = 0.2,
	},
	
	{
	
		classes = {"dice", "hover"},
		scale = 1.1,
		brightness = 2,
	},

	{
		classes = {"diceLines", "gmonly"},
		saturation = 0.5,
		brightness = 0.5,
	},
}

CreateDicePanel = function()

	local amendableRoll = nil

	local diceStyle = dmhub.GetDiceStyling(dmhub.GetSettingValue("diceequipped"), dmhub.GetSettingValue("playercolor"))
	
	local CreateDice = function(faces, params)

		local imageFaces = faces
		if imageFaces == 100 then
			imageFaces = 10
		end

	
		--a single dice
		local args = {
		
			classes = "dice",
			bgimage = string.format("ui-icons/d%d-filled.png", imageFaces),
			bgcolor = diceStyle.bgcolor,

			press = function(panel)
				if amendableRoll ~= nil and amendableRoll.amendable then
					amendableRoll = amendableRoll:Amend{
						numDice = 1,
						numFaces = faces,
						numKeep = 0,
						description = "Custom Roll",
						amendable = true,
					}

					return
				end


				printf("Roll: rolling with numDice = 1; numFaces = %d", math.tointeger(faces))
                amendableRoll = dmhub.Roll{
                    numDice = 1,
                    numFaces = faces,
					numKeep = 0,
                    description = "Custom Roll",
					amendable = true,
                }
            end,

			hover = gui.Tooltip(string.format("D%d", faces)),

			gui.Panel{
				classes = {"diceLines"},
				interactable = false,
				width = "100%",
				height = "100%",
				bgimage = string.format("ui-icons/d%d.png", imageFaces),
				bgcolor = diceStyle.trimcolor,
			}
		}

		if params ~= nil then
			for k,v in pairs(params) do
				args[k] = v
			end
		end

		return gui.Panel(args)
	end
	
	
	local resultPanel = gui.Panel{
	
		width = "100%",
		height = "100%",
		styles = styles,

		bgimage = "panels/square.png",
		bgcolor = "clear",

		multimonitor = {"privaterolls"},
		monitor = function(element)
			element:SetClassTree("gmonly", dmhub.GetSettingValue("privaterolls") == "dm")
		end,

		rightClick = function(element)
			element.popup = gui.ContextMenu{
				entries = {
					{
						text = "Rolls Visible Only to GM",
						check = dmhub.GetSettingValue("privaterolls") == "dm",
						click = function()
							dmhub.SetSettingValue("privaterolls", cond(dmhub.GetSettingValue("privaterolls") == "dm", "visible", "dm"))
							element.popup = nil
						end,
					},
				}

			}
		end,
		
		
		gui.Panel{
		
			width = "105%",
			height = "60%",
			valign = "center",
			halign = "center",
			bgimage = "panels/square.png",
			bgcolor = "clear",
			flow = "horizontal",
			y = -1,


			multimonitor = {"diceequipped", "playercolor"},

			events = {
				monitor = function(element)
					diceStyle = dmhub.GetDiceStyling(dmhub.GetSettingValue("diceequipped"), dmhub.GetSettingValue("playercolor"))
					element:FireEvent("create")
				end,

				create = function(element)
					element.children = {
						CreateDice(4),
						CreateDice(6),
						CreateDice(8),
						CreateDice(20, {uiscale = 1.65, y = 2}),
						CreateDice(10),
						CreateDice(12),
						CreateDice(100, {rotate = 180}),
					}
				end
			}
		},
	}

	resultPanel:SetClassTree("gmonly", dmhub.GetSettingValue("privaterolls") == "dm")

	return resultPanel

end