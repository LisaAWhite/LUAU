local mod = dmhub.GetModLoading()

--since we are loading up our token ui make sure any previously running token UI's get destroyed
--so we can reload with our brand new token ui.
dmhub.InvalidateTokenUI()

TokenUI = {}

local g_profileRibbon = dmhub.ProfileMarker("tokenui.ribbon")
local g_profileName = dmhub.ProfileMarker("tokenui.name")
local g_profileStatus = dmhub.ProfileMarker("tokenui.status")
local g_profileMain = dmhub.ProfileMarker("tokenui.main")

local g_menuGradient = gui.Gradient{
    point_a = {x = 0, y = 0},
    point_b = {x = 1, y = 1},
    stops = {
        {
            position = 0,
            color = "#060606",
        },
        {
            position = 1,
            color = "#3c3c3c",
        },
    },
}

RegisterGameType("TokenHud", "Hud")

local RadialStyles = {
	gui.Style{
		flow = 'none',
		height = 8,
		width = 8,
		halign = 'center',
		valign = 'center',
		bgcolor = 'white',
	},
	gui.Style{
		selectors = {'radial-menu-item'},
		width = 50,
		height = 50,
        bgimage = "panels/square.png",
        bgcolor = "white",
        cornerRadius = 25,
        gradient = g_menuGradient,
        borderWidth = 1.2,
        borderColor = Styles.textColor,
	},
	gui.Style{
		selectors = {'radial-menu-icon'},
		width = 60,
		height = 60,
	},
	gui.Style{
		selectors = {'radial-menu-item', 'hover'},
		brightness = 1.2,
		scale = 1.1,
		transitionTime = 0.1,
	},
	gui.Style{
		selectors = {'radial-menu-item', 'press'},
		brightness = 0.8,
		scale = 1.1,
		transitionTime = 0.05,
	},
	gui.Style{
		selectors = {'radial-menu-item', 'selected'},
		brightness = 1.8,
	},
	gui.Style{
		selectors = {'radial-menu-icon', 'hover'},
		brightness = 1.2,
		transitionTime = 0.1,
	},
	gui.Style{
		selectors = {'radial-menu-icon', 'press'},
		brightness = 0.8,
		transitionTime = 0.05,
	},
	gui.Style{
		selectors = {"create"},
		transitionTime = 0.2,
		opacity = 0,
	},

}

local g_statusBarRegistry = {}

TokenUI.RegisterStatusBar = function(args)
	g_statusBarRegistry[args.id] = args
end

TokenUI.ClearStatusBar = function(id)
	g_statusBarRegistry[id] = nil
end

TokenUI.ClearAllStatusBars = function()
	g_statusBarRegistry = {}
end

local function BoolOrFunction(val)
	if type(val) == "function" then
		return val()
	else
		return val
	end
end

local function ShouldShowElement(token, v)
	local show = nil

	if show == nil and v.showToGM ~= nil and dmhub.isDM then
		show = BoolOrFunction(v.showToGM)
	end

	if show == nil and v.showToController ~= nil and token.canControl then
		show = BoolOrFunction(v.showToController)
	end

	if show == nil and v.showToFriends ~= nil and token.isFriendOfPlayer then
		show = BoolOrFunction(v.showToFriends)
	end

	if show == nil and v.showToEnemies ~= nil and dmhub.isDM == false and (not token.isFriendOfPlayer) then
		show = BoolOrFunction(v.showToEnemies)
	end

	if show == nil and v.showToAll ~= nil then
		show = BoolOrFunction(v.showToAll)
	end

	return show
end

local function CalculateStatusBars(token)
	local bars = {}

	if token.properties == nil then
		return bars
	end

	for k,v in pairs(g_statusBarRegistry) do

		if ShouldShowElement(token, v) and (v.Filter == nil or v.Filter(token.properties)) then
			local bar = v.Calculate(token.properties)
			if bar ~= nil then
				bar.base = v
				bars[#bars+1] = bar
			end
		end
	end

	if #bars > 1 then
		table.sort(bars, function(a,b) return (a.order or 0) < (b.order or 0) end)
	end

	return bars
end


local g_statusIconRegistry = {}

TokenUI.RegisterIcon = function(args)
	g_statusIconRegistry[args.id] = args
end

TokenUI.ClearIcon = function(id)
	g_statusIconRegistry[id] = nil
end

TokenUI.ClearAllIcons = function()
	g_statusIconRegistry = {}
end

local CalculateStatusIcons = function(token)
	local result = {}
	if token.invisibleToPlayers then
		result[#result+1] = { id = "invisible", icon = "ui-icons/eye.png" }
	end

	if token.properties ~= nil and token.properties.damage_taken >= token.properties:MaxHitpoints() then 
		--dead tokens don't show any more icons.
		return result
	end

	--iterate over all of our icon calculations and see which ones apply.
	if token.properties ~= nil then
		for k,v in pairs(g_statusIconRegistry) do
			if ShouldShowElement(token, v) then
				if v.Calculate ~= nil then
					local res = v.Calculate(token.properties)
					if res ~= nil then
						result[#result+1] = res
					end

				elseif v.Filter ~= nil and v.Filter(token.properties) then
					local icon = v.icon
					result[#result+1] = { id = k, icon = icon, style = v.style }
				end
			end
		end
	end

--  Just have light status shown by accessories.
--	if token.properties ~= nil and token.properties:IsUsingLight() then 		
--		result[#result+1] = { id = "light", icon = "ui-icons/slot-light.png" }
--	end


	if token.properties ~= nil then
		local effectsMap = {}
		local ongoingEffectsTable = dmhub.GetTable("characterOngoingEffects") or {}
		local conditionsTable = dmhub.GetTable(CharacterCondition.tableName) or {}
		for i,cond in ipairs(token.properties:ActiveOngoingEffects()) do
			if effectsMap[cond.ongoingEffectid] ~= nil then
				local entry = effectsMap[cond.ongoingEffectid]
				entry.quantity = (entry.quantity or 1) + 1
			else
				local casterid = nil
				local hoverText = "test"
				local ongoingEffectInfo = ongoingEffectsTable[cond.ongoingEffectid]
				local casterInfo = cond:try_get("casterInfo")
				local condInfo = conditionsTable[ongoingEffectInfo.condition]
				if condInfo ~= nil and casterInfo ~= nil and casterInfo.tokenid ~= nil then
					local casterToken = dmhub.GetTokenById(casterInfo.tokenid)
					if casterToken ~= nil then
						hoverText = string.format("%s: %s", condInfo.name, casterToken.description)
						casterid = casterInfo.tokenid
					else
						hoverText = "no caster"
					end
				elseif condInfo ~= nil then
					if condInfo.description ~= "" then
						hoverText = string.format("%s: %s", condInfo.name, condInfo.description)
					else
						hoverText = condInfo.name
					end
				else

					local stacksText = ""
					if ongoingEffectInfo.stackable and cond.stacks > 1 then
						stacksText = string.format(" (%d)", cond.stacks)
					end
					if ongoingEffectInfo.description ~= "" then
						hoverText = string.format("%s%s: %s", ongoingEffectInfo.name, stacksText, ongoingEffectInfo.description)
					else
						hoverText = ongoingEffectInfo.name
					end
				end

				result[#result+1] = {
					id = cond.ongoingEffectid,
					icon = ongoingEffectInfo.iconid,
					style = ongoingEffectInfo.display,
					hoverText = hoverText,
					statusIcon = true,
					casterid = casterid,
				}

				effectsMap[cond.ongoingEffectid] = result[#result]
			end
		end

		token.properties:FillCalculatedStatusIcons(result)
	end

	return result
end


local g_animationStyles = {

	gui.Style{
		classes = {"animatedItem"},
		brightness = 5,
		opacity = 0,
		scale = 1.5,
		bgcolor = "white",
		width = 40,
		height = 40,
	},
	gui.Style{
		classes = {"animatedItem", "fadein"},
		transitionTime = 0.6,
		easing = "easeInCubic",
		y = -80,
	},
	gui.Style{
		classes = {"animatedItem", "~fadein"},
		brightness = 1,
		opacity = 1,
		transitionTime = 0.3,
	},
	gui.Style{
		classes = {"animatedItem", "disappear"},
		opacity = 0,
		transitionTime = 0.25,
		scale = 0.1,
	},

	gui.Style{
		classes = {"refreshResource"},
		opacity = 0,
		bgcolor = "white",
		width = 32,
		height = 32,
	},
	gui.Style{
		classes = {"refreshResource", "fadein"},
		transitionTime = 0.6,
		easing = "easeInCubic",
		y = -80,
	},
	gui.Style{
		classes = {"refreshResource", "~fadein"},
		brightness = 1,
		opacity = 1,
		transitionTime = 0.3,
	},
	gui.Style{
		classes = {"refreshResource", "disappear"},
		opacity = 0,
		transitionTime = 0.25,
	},
	
	gui.Style{
		classes = {"consumeResource"},
		opacity = 1,
		bgcolor = "white",
		width = 32,
		height = 32,
	},
	gui.Style{
		classes = {"consumeResource", "fadein"},
		transitionTime = 0.6,
		easing = "easeInCubic",
	},
	gui.Style{
		classes = {"consumeResource", "~fadein"},
		brightness = 1,
		opacity = 0,
		y = -80,
		transitionTime = 0.3,
	},
}

local g_statusPanelStyles = {
	gui.Style{
		selectors = {"statusPanel"},
		wrap = true,
	},
	gui.Style{
		hmargin = 0,
		vmargin = 0,
		halign = "center",
		valign = "center",
		width = "90%",
		height = "90%",
		flow = "horizontal",
		bgcolor = "white",
	},

	gui.Style{
		selectors = {"status-icon"},
		width = 24,
		height = 24,
		halign = "right",
		valign = "top",
		hmargin = 0,
	},

	gui.Style{
		selectors = {"status-icon", "small"},
		width = 14,
		height = 14,
	},

	gui.Style{
		selectors = {"status-icon", "create"},
		transitionTime = 0.3,
		brightness = 2,
		scale = 2,
		opacity = 0,
	},

	gui.Style{
		selectors = {"status-icon", "interactive", "hover"},
		brightness = 1.5,
	},

	gui.Style{
		selectors = {"main-status-icon"},
		width = 70,
		height = 70,
		opacity = 1,
		halign = "center",
		valign = "center",
	},
	
	gui.Style{
		selectors = {"main-status-icon", "create"},
		transitionTime = 0.5,
		brightness = 2,
		scale = 2,
		opacity = 0,
	},
	gui.Style{
		selectors = {"death-saving-throw-status-icon"},
		blend = 'add',
		width = 24,
		height = 24,
		halign = "center",
		valign = "center",
		brightness = 2,
	},
	gui.Style{
		selectors = {"death-saving-throw-status-icon", "success"},
		y = -20,
	},
	gui.Style{
		selectors = {"death-saving-throw-status-icon", "failure"},
		y = 20,
	},
	gui.Style{
		selectors = {"death-saving-throw-status-icon", "create"},
		transitionTime = 1,
		brightness = 8,
		scale = 4,
		opacity = 1,
	},
}

local g_RegisteredPanels = {}

TokenHud.RegisterPanel = function(info)
	local index = #g_RegisteredPanels+1

	for i,entry in ipairs(g_RegisteredPanels) do
		if entry.id == info.id then
			index = i
			break
		end
	end

	g_RegisteredPanels[index] = info

	table.sort(g_RegisteredPanels, function(a,b) return (a.ord or 0) < (b.ord or 0) end)
end

TokenHud.RegisterPanel{
	id = "nameLabel",
	create = function(token, sharedInfo)
	
		return gui.Panel{
			interactable = false,

			valign = "bottom",
			halign = "center",
			width = 120,
			height = 40,

			gui.Label{
				bgimage = "panels/square.png",
				bgcolor = "#000000ff",
				borderColor = "#000000ff",
				borderFade = true,
				borderWidth = 16,
				hpad = 16,
				vpad = 8,
				text = '',
				interactable = false,
				fontSize = 18,
				minFontSize = 8,
				maxWidth = 120,
				wrap = false,
				textWrap = false,
				width = "auto",
				height = "auto",
				y = 4,
				color = 'white',
				halign = 'center',
				valign = 'bottom',
				textAlignment = 'center',
				brightness = 1,
				italics = false,
				events = {
					refresh = function(element)
						g_profileName:Begin()
						if token.properties ~= nil and (token.canControl or not token.namePrivate) then
							element.selfStyle.color = token.playerColor
							element.selfStyle.italics = token.namePrivate
							element.selfStyle.brightness = cond(token.namePrivate, 0.8, 1)
							element.text = token:GetNameMaxLength(30)
						else
							element.text = ''
						end
						g_profileName:End()
					end,
				},
			},
		}

	end,
}


TokenHud.RegisterPanel{
	id = "statusPanel",
	create = function(token, sharedInfo)
		local damagePendingPanel = nil

		--a mapping of rollid key to the panel displaying the little dice etc representing a damage roll.
		--these can be kept around even after the panel is destroyed so must check for valid as well as not nil.
		local damagePanelsByRollId = sharedInfo.damagePanelsByRollId or {}
		sharedInfo.damagePanelsByRollId = damagePanelsByRollId

		local saddleLockIcon = nil
		local deadIcon = nil
		local statusIcons = {}

		local statusBarPanels = {}

		local statusPanel = gui.Panel{
			id = 'StatusPanel',
			classes = {"statusPanel"},
			styles = g_statusPanelStyles,
			blocksGameInteraction = false,

			events = {
				think = function(element)
					element:FireEvent("refresh")
				end,

				refresh = function(element)
					g_profileStatus:Begin()
					local children = {}

					local statusBars = CalculateStatusBars(token)
					local newStatusBarPanels = {}

					for _,bar in ipairs(statusBars) do
						local panel = statusBarPanels[bar.base.id] or gui.Panel{
							interactable = false,
							width = "85%",
							halign = "center",
							height = 12,
							vmargin = 0,
							y = -7,
							update = function(element, barInfo)
								element.selfStyle.height = barInfo.height or barInfo.base.height or 12
							end,

							data = {
								val = nil,
							},
							gui.Panel{
								interactable = false,
								flow = "none",
								width = "100%",
								height = "100%",
								bgimage = "panels/square.png",
								bgcolor = "black",
								update = function(element, barInfo)
									element.selfStyle.bgcolor = barInfo.base.emptyColor or "black"

									local w = barInfo.width or barInfo.base.width
									if w ~= nil then
										element.selfStyle.width = string.format("%f%%", w*100)
									end

								end,

								--the fill.
								gui.Panel{
									interactable = false,
									data = {
										prevTime = nil,
										prevValue = nil,
										value = nil,
										colorTable = nil,
										
									},
									width = "100%",
									height = "100%",
									halign = "left",
									valign = "center",
									bgimage = "panels/square.png",
									update = function(element, barInfo)
										if barInfo.max <= 0 then
											return
										end

										local percent = barInfo.value/barInfo.max
										element.data.value = percent
										element.data.prevTime = dmhub.Time()
										local seek = barInfo.seek or barInfo.base.seek
										if seek == nil then
											element.data.seek = nil
										else
											element.data.seek = seek/barInfo.max
										end

										local col = barInfo.fillColor or barInfo.base.fillColor or "green"
										if type(col) == "table" then
											element.data.colorTable = col
										else
											element.selfStyle.bgcolor = col
											element.data.colorTable = nil
										end

										element:FireEvent("updateFill")
									end,

									updateFill = function(element)
										if element.data.prevValue == nil or element.data.seek == nil or element.data.prevTime == nil then
											element.selfStyle.width = string.format("%f%%", element.data.value*100)
											element.data.prevValue = element.data.value
										else
											local t = dmhub.Time()
											local deltaTime = t - element.data.prevTime
											element.data.prevTime = t

											local totalDelta = math.abs(element.data.prevValue - element.data.value)

											if totalDelta > 0 and (element.data.seek <= 0 or totalDelta/element.data.seek > 3) then
												--make sure seeking never takes longer than 3 seconds.
												element.data.seek = totalDelta/3
											end

											local delta = deltaTime * element.data.seek

											if totalDelta < delta then
												element.data.prevValue = element.data.value
											elseif element.data.prevValue < element.data.value then
												element.data.prevValue = element.data.prevValue + delta
												element:ScheduleEvent("updateFill", 0.01)
											else
												element.data.prevValue = element.data.prevValue - delta
												element:ScheduleEvent("updateFill", 0.01)
											end

											element.selfStyle.width = string.format("%f%%", element.data.prevValue*100)
										end

										if element.data.colorTable ~= nil then
											for i,entry in ipairs(element.data.colorTable) do
												if entry.value == nil or element.data.prevValue >= entry.value then
													element.selfStyle.bgcolor = entry.color

													if entry.gradient ~= nil then
														element.selfStyle.gradient = entry.gradient
													end
													break
												end
											end
										end
									end,
								},

								gui.Label{
                                    interactable = false,
									fontSize = 8,
									width = "auto",
									height = "auto",
									color = "white",
									halign = "center",
									valign = "center",
									update = function(element, barInfo)
										element.text = barInfo.text or barInfo.base.text or string.format("%d / %d", round(barInfo.value), round(barInfo.max))
									end,
								}
							},
						}

						if not dmhub.DeepEqual(panel.data.val, bar) then
							panel:FireEventTree("update", bar)
							panel.data.val = bar
						end

						newStatusBarPanels[bar.base.id] = panel
						children[#children+1] = panel
					end

					statusBarPanels = newStatusBarPanels

					local newStatusIcons = {}
					local icons = CalculateStatusIcons(token)
					local hasStatusIcons = false
					for i,icon in ipairs(icons) do
                        local iconPanel
						iconPanel = statusIcons[icon.id] or gui.Panel{
							bgimage = icon.icon,
							classes = {'status-icon'},
							interactable = (icon.hoverText ~= nil),
							blocksGameInteraction = false,
							selfStyle = icon.style,
							data = {
								quantity = 1,
								highlight = nil,
								casterid = nil,
							},
							create = function(element)
								if icon.hasAltitude then
									element.children = {
										gui.Label{
											width = "100%",
											height = "100%",
											bold = true,
                                            y = icon.yadjust or 0,
											fontSize = 12,
											color = "black",
											textAlignment = "center",
											textOutlineWidth = 0.1,
											textOutlineColor = "white",
											monitorGame = token.monitorPath,
											refreshGame = function(element)
												element:FireEvent("refreshAltitude")
											end,
											refreshAltitude = function(element)
												element.text = string.format("%d", token.floorAltitude)
                                                if icon.hideAtZeroAltitude then
                                                    iconPanel:SetClass("collapsed", token.floorAltitude == 0)
                                                end
											end,
										},
									}
								end
							end,
							linger = function(element)
								if icon.hoverText ~= nil then
									gui.Tooltip(icon.hoverText)(element)
								end
							end,
							hover = function(element)
								if element.data.highlight ~= nil then
									element.data.highlight:Destroy()
									element.data.highlight = nil
								end
								if element.data.casterid ~= nil then
									local caster = dmhub.GetTokenById(element.data.casterid)
									if caster ~= nil then
										local casterPos = caster.pos
										if casterPos ~= nil then
											element.data.highlight = dmhub.HighlightLine{
												color = "red",
												a = casterPos,
												b = token.pos,
											}
										end
									end
								end
							end,
							dehover = function(element)
								if element.data.highlight ~= nil then
									element.data.highlight:Destroy()
									element.data.highlight = nil
								end
							end,
						}

						if icon.hasAltitude then
							iconPanel:FireEventTree("refreshAltitude")
						end

						element.data.hoverText = icon.hoverText
						iconPanel.data.casterid = icon.casterid

						iconPanel:SetClass("small", #icons >= 4)

						newStatusIcons[icon.id] = iconPanel

						if icon.quantity ~= iconPanel.data.quantity then

							iconPanel.data.quantity = icon.quantity
						end

						if icon.statusIcon then
							hasStatusIcons = true
						end

						children[#children+1] = newStatusIcons[icon.id]
					end

					if hasStatusIcons then
						--while we have status icons displayed, refresh every 6 seconds to recalculate them.
						element.thinkTime = 6
					else
						element.thinkTime = nil
					end

					--if we are mounted, show an icon for if we are locked into our saddle.
					if token.mountedOn ~= nil and token.canControl then
						if saddleLockIcon == nil then
							local isUnlocked = false
							saddleLockIcon = gui.Panel{
								idprefix = "saddleLock",
								floating = true,
								halign = "left",
								valign = "bottom",
								hmargin = 12,
								vmargin = 12,
								width = 16,
								height = 16,
								classes = {"status-icon", "interactive"},

								saddleUnlocked = function(element, unlocked)
									isUnlocked = unlocked
									element.bgimage = cond(unlocked, "icons/icon_tool/icon_tool_30_unlocked.png", "icons/icon_tool/icon_tool_30.png")
								end,

								click = function(element)
									token.saddleUnlocked = not isUnlocked
									element:FireEvent("saddleUnlocked", token.saddleUnlocked)
								end,
							}
						end

						saddleLockIcon:FireEvent("saddleUnlocked", token.saddleUnlocked)

						children[#children+1] = saddleLockIcon
					else
						saddleLockIcon = nil
					end

					if token.properties ~= nil and token.properties:IsDown() then
						deadIcon = deadIcon or gui.Panel{
							floating = true,
							classes = {'main-status-icon'},
							interactable = false,
							styles = {
								{
									selectors = {"stable"},
									hueshift = 0.3,
									brightness = 1,
								},
								{
									selectors = {"dead"},
									saturation = 0,
									brightness = 0.05,
								}
							},
						}

						deadIcon.bgimage = 'ui-icons/Pin_Boss.png'

						children[#children+1] = deadIcon

						local successes = math.min(3, token.properties:GetNumDeathSavingThrowSuccesses())
						local failures = math.min(3, token.properties:GetNumDeathSavingThrowFailures())

						if not token.properties:IsDying() then
							successes = 0
							failures = 0
						end

						deadIcon:SetClass("dead", token.properties:IsDead())
						deadIcon:SetClass("stable", token.properties:IsUnconsciousButStable())

						while successes > 0 do

							local key = string.format('success-%d', successes)
							newStatusIcons[key] = statusIcons[key] or gui.Panel{
								id = key,
								x = (successes-2)*30,
								bgimage = "ui-icons/skills/88.png",
								classes = {'death-saving-throw-status-icon', 'success'},
								interactable = false,
								floating = true,
							}

							children[#children+1] = newStatusIcons[key]
							
							successes = successes - 1
						end

						while failures > 0 do

							local key = string.format('failures-%d', failures)
							newStatusIcons[key] = statusIcons[key] or gui.Panel{
								id = key,
								x = (failures-2)*30,
								bgimage = "ui-icons/skills/81.png",
								classes = {'death-saving-throw-status-icon', 'failure'},
								interactable = false,
								floating = true,
							}

							children[#children+1] = newStatusIcons[key]

							failures = failures - 1
						end

					else
						deadIcon = nil
					end

					local hasExpectedDamage = false
					if token.properties ~= nil and token.properties:has_key("expectedDamage") then
						for _,_ in pairs(token.properties.expectedDamage) do
							hasExpectedDamage = true
						end
					end

					local createdDamagePending = false
					if hasExpectedDamage or damagePendingPanel ~= nil then
						if damagePendingPanel == nil then
							local rollingPanels = {}
							local damagePanels = {}
							createdDamagePending = true
							damagePendingPanel = gui.Panel{
								interactable = false,
								floating = true,
								flow = "vertical",
								width = "100%",
								height = "auto",
								valign = "center",
								halign = "center",
								refreshDamage = function(element, damageEntries)
									local newDamagePanels = {}
									local children = {}
									local startRoll = nil

									--when did the combine animation start?
									local combineStart = nil

									--constant for how long the combine animation takes
									local combineDuration = 0.4

									local combinex = nil
									local combiney = nil

									for k,entry in pairs(damageEntries) do

										local diceinfo = entry.dice or {}

										local diceStyle = dmhub.GetDiceStyling(diceinfo.set, diceinfo.color)
										local key = k
										local newPanel
										newPanel = damagePanels[k] or gui.Panel{
											interactable = false,
											flow = "horizontal",
											height = "auto",
											width = "100%",
											wrap = true,
											halign = "center",
											valign = "center",

											data = {
												half = false,
											},

											--start the combine animation which culminates in this panel being destroyed.
											combineAnimation = function(element)
												local children = element.children

												combineStart = dmhub.Time()

												if #children > 0 then
													local xpos = 0
													local ypos = 0
													for _,child in ipairs(children) do
														local pos = child.renderpos
														child.data = child.data or {}
														child.data.startpos = pos
														xpos = xpos + pos.x
														ypos = ypos + pos.y

														child:SetClass("combine", true)
													end

													xpos = xpos / #children
													ypos = ypos / #children
													combinex = xpos
													combiney = ypos
												end

												element:ScheduleEvent("combineTick", 0.01)
											end,

											--one tick of the combine animation.
											combineTick = function(element)
												local t = (dmhub.Time() - combineStart)/combineDuration
												if t >= 1 then
													element:DestroySelf()
													return
												end

												for _,child in ipairs(element.children) do
													if child.data ~= nil and child.data.startpos ~= nil then
														local xpos = combinex - child.data.startpos.x
														local ypos = -(combiney - child.data.startpos.y)
														child.x = lerp(0, xpos, dmhub.ease(t, 'easeinback'))
														child.y = lerp(0, ypos, dmhub.ease(t, 'easeinback'))
													end
												end

												element:ScheduleEvent("combineTick", 0.01)
											end,

											think = function(element)
												if dmhub.Time() > startRoll + 0.7 then
													--the roll must have been canceled or whatnot, so just disappear the damage panel.
													element:DestroySelf()
													return
												end
												for i,message in ipairs(chat.messages) do
													if message.key == key then
														element:FireEventTree("rollMessage", message)
														element.thinkTime = nil
													end
												end
											end,

											rolling = function(element)
												if startRoll == nil then
													startRoll = dmhub.Time()
													element.thinkTime = 0.2
												end
											end,

											refreshDamage = function(element, entry)
												local info = dmhub.ParseRoll(entry.roll)
												local children = {}

												if info ~= nil and info.categories ~= nil then
													for catKey,catInfo in pairs(info.categories) do
														local damageType = string.lower(catKey)
														if string.starts_with(damageType, "magical ") then
															damageType = string.gsub(damageType, "magical ", "")
														end

														local damageInfo = rules.damageTypesToInfo[damageType]
														if damageInfo ~= nil then
															for catid,group in ipairs(catInfo.groups) do
																for i=1,group.numDice do
																	local rollLabel = gui.Label{
																		text = "",
																		interactable = false,
																		fontSize = 16,
																		textAlignment = "center",
																		bold = true,
																		color = diceStyle.color,
																		width = "100%",
																		height = "100%",
																		halign = "center",
																		valign = "center",
																	}

																	children[#children+1] = gui.Panel{
																		interactable = false,
																		flow = "none",
																		bgimage = string.format("ui-icons/d%d-filled.png", group.numFaces),
																		width = 20,
																		height = 20,
																		styles = {
																			{
																				bgcolor = diceStyle.bgcolor,
																			},
																			{
																				selectors = {"combine"},
																				brightness = 30,
																				bgcolor = "white",
																				easing = "easeincirc",
																				transitionTime = combineDuration,
																			}
																		},

																		gui.Panel{
																			interactable = false,
																			bgimage = string.format("ui-icons/d%d.png", group.numFaces),
																			bgcolor = diceStyle.trimcolor,
																			width = 20,
																			height = 20,
																			styles = {
																				{
																					selectors = {"parent:combine"},
																					brightness = 30,
																					easing = "easeincirc",
																					transitionTime = combineDuration,
																				}
																			},
																		},

																		rollLabel,

																		--we get this message when we have found a message with the actual roll
																		--search for our roll and start listening to it and displaying the outcome.
																		rollMessage = function(element, message)
																			local info = message.resultInfo
																			for catid,catInfo in pairs(info) do
																				if catid == catKey then
																					for j,roll in ipairs(catInfo.rolls) do
																						if j == i then
																							local events = chat.DiceEvents(roll.guid)
																							if events ~= nil then
																								events:Listen(element)
																							end
																						end
																					end
																				end
																			end
																								
																		end,
																		diceface = function(element, diceguid, num)
																			if num ~= nil then
																				rollLabel.text = tostring(math.tointeger(num))
																			else
																				rollLabel.text = ""
																			end
																		end,
																	}
																end
															end

															if catInfo.mod ~= nil and catInfo.mod ~= 0 then
																children[#children+1] = gui.Label{
																	interactable = false,
																	color = diceStyle.color,
																	fontSize = 16,
																	bold = true,
																	width = "auto",
																	height = "auto",
																	text = ModStr(catInfo.mod),
																}
															end

															children[#children+1] = gui.Panel{
																interactable = false,
																bgimage = damageInfo.iconid,
																bgcolor = damageInfo.display.bgcolor,
																width = 20,
																height = 20,
																blend = "add",
																styles = {
																	{
																		selectors = {"combine"},
																		brightness = 30,
																		easing = "easeincirc",
																		transitionTime = combineDuration,
																	}
																},
															}

														end
													end

													if #children <= 2 then
														damagePendingPanel.selfStyle.width = "60%"
														
													elseif #children <= 3 then
														damagePendingPanel.selfStyle.width = "80%"
													else
														damagePendingPanel.selfStyle.width = "100%"
													end

													if string.find(entry.roll, "HALF") then
														newPanel.data.half = true
														children[#children+1] = gui.Label{
															interactable = false,
															bgimage = "panels/square.png",
															bgcolor = "clear",
															width = "90%",
															halign = "center",
															valign = "center",
															height = 30,
															border = { y1 = 0, y2 = 3, x1 = 0, x2 = 0 },
															borderColor = diceStyle.color,
															color = diceStyle.color,
															bold = true,
															text = "2",
															fontSize = 16,
															textAlignment = "center",
														}
													end
												end

												element.children = children
											end,
										}

										newPanel:FireEvent("refreshDamage", entry)

										--use this as a chance to purge any expired damage panels
										local purge = {}
										for k,p in pairs(damagePanelsByRollId) do
											if p == nil or not p.valid then
												purge[#purge+1] = k
											end
										end

										for _,k in ipairs(purge) do
											damagePanelsByRollId[k] = nil
										end

										damagePanelsByRollId[k] = newPanel
										newDamagePanels[k] = newPanel
										children[#children+1] = newPanel
									end

									for k,panel in pairs(damagePanels) do
										if not newDamagePanels[k] then
											panel:FireEvent("rolling")
											rollingPanels[#rollingPanels+1] = panel
										end
									end

									local newRollingPanels = {}
									for _,panel in ipairs(rollingPanels) do
										if panel ~= nil and panel.valid then
											newRollingPanels[#newRollingPanels+1] = panel
										end
									end

									rollingPanels = newRollingPanels

									for _,panel in ipairs(rollingPanels) do
										if panel ~= nil and panel.valid then
											children[#children+1] = panel
										end
									end

									damagePanels = newDamagePanels
									element.children = children
								end,
							}
						end

						local expectedDamage = {}
						for k,damage in pairs(token.properties:try_get("expectedDamage", {})) do
							--only consider damage that is in the last 30 seconds. Otherwise it's probably invalid/expired.
							if TimestampAgeInSeconds(damage.timestamp) < 30 then
								expectedDamage[k] = damage
							end
						end
						damagePendingPanel:FireEvent("refreshDamage", expectedDamage)

						if #damagePendingPanel.children == 0 and not createdDamagePending then
							damagePendingPanel = nil
						else
							children[#children+1] = damagePendingPanel
						end

					end

					element.children = children
					statusIcons = newStatusIcons
					g_profileStatus:End()
				end,
			},
		}

		return statusPanel
	end,
}


dmhub.RegisterRemoteEvent("tokenEffect", function(info)
	local token = dmhub.GetTokenById(info.tokenid)
	if token == nil or token.sheet == nil then
		return
	end

	if info.destroy then
		token.sheet:FireEventTree("destroyRemoteEffect", info.sessionid)
		return
	end

	token.sheet:FireEventTree("updateRemoteEffect", info)

	--see if we had this effect playing and it was processed
	if info.processed then
		return
	end

	local sheets = token.sheet.data.PlayEffect(info.effectid, true, {classes = info.classes})
	for _,sheet in ipairs(sheets) do
		if sheet ~= nil then
			local m_lastUpdated = dmhub.Time()

			sheet:SetClassTree("remote", true)
			local m_classes = dmhub.DeepCopy(info.classes)
			local userInfo = dmhub.GetSessionInfo(info.userid)
			if userInfo ~= nil then
				sheet.selfStyle.hueshift = userInfo.displayColor.h
			end
			local m_sessionid = info.sessionid

			sheet.thinkTime = 1
			sheet.events.think = function(element)
				if dmhub.Time() > m_lastUpdated + 3 then
					element:DestroySelf()
				end
			end

			sheet.events.updateRemoteEffect = function(element, info)
				if info.sessionid == m_sessionid then
					m_lastUpdated = dmhub.Time()
					info.processed = true

					for _,c in ipairs(info.classes) do
						local found = false
						for _,existing in ipairs(m_classes) do
							if c == existing then
								found = true
								break
							end
						end

						if not found then
							element:SetClass(c, true)
						end
					end

					for _,c in ipairs(m_classes) do
						local found = false
						for _,existing in ipairs(info.classes) do
							if c == existing then
								found = true
								break
							end
						end

						if not found then
							element:SetClass(c, false)
						end
					end

					m_classes = dmhub.DeepCopy(info.classes)
				end
			end

			sheet.events.destroyRemoteEffect = function(element, sessionid)
				if sessionid == m_sessionid then
					element:DestroySelf()
				end
			end
		end
	end

end)

function CreateTokenHud(token)

	local emotesProcessed = {}
	if token.properties ~= nil and token.properties:has_key('emotes') then
		for k,v in pairs(token.properties.emotes) do
			if TimestampAgeInSeconds(v.timestamp) > 3 then
				emotesProcessed[k] = true
			end
		end
	end

	local targetEffect = nil
	local loopingEmotes = {}

	local effectsPanel = gui.Panel{
		styles = {
			{
				bgcolor = 'white',
				halign = 'center',
				valign = 'center',
				width = 100,
				height = 100,
				flow = 'none',
			},
		}
	}

	local SpawnEffect = function(id, looping, options)
		options = options or {}
		local suffix = ''
		if not looping then
			suffix = '###' .. dmhub.GenerateGuid()
		end

		local tokenEffects = GetTokenEffects(id)
		if tokenEffects == nil then
			--this can happen if the effect has been deleted. Just ignore this error.
			--dmhub.Log('Could not find token effect ' .. id .. " FOR TOKEN " .. dmhub.ToString(options.tokenid) .. " at " .. debug.traceback())
			return nil
		end

		local results = {}

		local children = effectsPanel.children
		for i,effect in ipairs(tokenEffects) do

			local remote = i == 1 and options.remote
			local think = nil
			local destroyRemote = nil
			if remote then
				local tokenid = token.charid
				local m_lastSend = -1
				local m_classesSent = nil
				local remoteSessionid = dmhub.GenerateGuid()
				think = function(element)
					local classes = element.classes
					if m_classesSent == nil or (not dmhub.DeepEqual(m_classesSent, classes)) or dmhub.Time() > m_lastSend + 1 then
						m_lastSend = dmhub.Time()
						m_classesSent = dmhub.DeepCopy(classes)
						dmhub.BroadcastRemoteEvent("tokenEffect", remoteSessionid, {
							userid = dmhub.userid,
							tokenid = tokenid,
							sessionid = remoteSessionid,
							effectid = id,
							classes = classes,
						})
					end
				end

				destroyRemote = function(element)
					dmhub.BroadcastRemoteEvent("tokenEffect", remoteSessionid, {
						userid = dmhub.userid,
						tokenid = tokenid,
						effectid = id,
						destroy = true,
					})
				end
			end

			local bgimageMaskRect = nil
			if effect.mask or effect.behind then
				local maskWidth = (effect.width or 90) / 90
				local maskHeight = (effect.height or 90) / 90
				bgimageMaskRect = {
					e1 = (effect.x or 0)/90 + 0.5 - maskWidth*0.5,
					x2 = (effect.x or 0)/90 + 0.5 + maskWidth*0.5,
					y1 = -(effect.y or 0)/90 + 0.5 - maskHeight*0.5,
					y2 = -(effect.y or 0)/90 + 0.5 + maskHeight*0.5,
				}
			end

			local resultPanel = gui.Panel{
				interactable = false,
				classes = options.classes,
				bgimage = cond(effect.image, effect.image, (effect.video or 'none') .. suffix),
				bgimageTokenMaskInclusive = cond(effect.mask or effect.behind, token.portraitFrame),
				bgimageMaskInvert = cond(effect.behind, 1, 0),
				bgimageMaskRect = bgimageMaskRect,
				x = effect.x or 0,
				y = effect.y or 0,
				thinkTime = cond(think ~= nil, 0.05, nil),
				data = {
					destroying = false,
					loopScheduled = nil,
				},
				styles = {
					{
						width = effect.width or 90, --default width and height make a masked effect exactly fit on the token.
						height = effect.height or 90,
					},
					effect.styles,
				},
				events = {
                    stretch = function(element, stretch, pos)
                        element.selfStyle.x = pos.x*128
                        element.selfStyle.y = -pos.y*128
                        element.selfStyle.stretch = stretch
                    end,

					think = think,
					videoFinished = function(element)
						element:DestroySelf()
					end,

					videoLoop = function(element)
						if element.data.loopScheduled ~= nil then
							element.bgimage = element.data.loopScheduled
						end
					end,

					destroy = function(element)
						if element.data.destroying then
							return
						end

						element.data.destroying = true

						if destroyRemote ~= nil then
							destroyRemote(element)
						end

						if effect.finishEmoji ~= nil and effect.finishEmoji ~= "none" then
							local finishEmoji = assets.emojiTable[effect.finishEmoji]
							if finishEmoji ~= nil then
								element.data.loopScheduled = finishEmoji.id .. '###' .. dmhub.GenerateGuid()
								return
							end
						end

						element:SetClass('fadeout', true)
						element:ScheduleEvent('videoFinished', effect.fadetime or 0)
					end,
				},
			}

			resultPanel:PulseClass("fadein")
			resultPanel:FireEvent("think") --update remotes.

			children[#children+1] = resultPanel
			results[#results+1] = resultPanel
		end
		effectsPanel.children = children

		return results
	end

	
	local current_damage_entry = dmhub.DeepCopy(creature.damage_entry)
	if token.properties ~= nil then
		current_damage_entry = dmhub.DeepCopy(token.properties.damage_entry)
	end

	local animationsPanel = gui.Panel{
        interactable = false,
		id = 'AnimationsPanel',
		width = "100%",
		height = "100%",
		styles = g_animationStyles,

		animation = function(element, token, anim)
			if anim.animType == "floatlabel" then
				if token.sheet == nil then
					return
				end

				token.sheet:FireEvent("floatlabel", anim.text, anim.color)
			elseif anim.animType == "giveItem" then
				local children = element.children

				local delay = 0

				local gearTable = dmhub.GetTable('tbl_Gear')
				for itemid,quantity in pairs(anim.items) do
					local createTime = dmhub.Time()
					local itemInfo = gearTable[itemid]
					local icon = itemInfo:GetIcon()
					local panel = gui.Panel{
						classes = {"animatedItem", "fadein"},
						bgimage = icon,

						fadein = function(element)
							element:SetClass("fadein", false)
						end,
						disappear = function(element)
							element:SetClass("disappear", true)
						end,
						die = function(element)
							element:DestroySelf()
						end,
					}

					panel:ScheduleEvent("fadein", delay + 0.01)
					panel:ScheduleEvent("disappear", delay + 0.6)
					panel:ScheduleEvent("die", delay + 0.6 + 0.25)

					children[#children+1] = panel

					delay = delay + 0.35

				end

				element.children = children
			elseif anim.animType == "refreshResource" or anim.animType == "consumeResource" then

				local resourceTable = dmhub.GetTable(CharacterResource.tableName)

				local children = element.children

				local delay = 0

				for resourceid,quantity in pairs(anim.resources) do

					local resourceInfo = resourceTable[resourceid]
					if resourceInfo ~= nil then
						for i=1,math.min(quantity, 8) do
							local panel = gui.Panel{
                                interactable = false,
								classes = {anim.animType, "fadein"},
								bgimage = resourceInfo.iconid,
								selfStyle = resourceInfo:GetDisplayStyle("normal"),

								fadein = function(element)
									element:SetClass("fadein", false)
								end,
								disappear = function(element)
									element:SetClass("disappear", true)
								end,
								die = function(element)
									element:DestroySelf()
								end,
							}

							panel:ScheduleEvent("fadein", delay + 0.01)
							panel:ScheduleEvent("disappear", delay + 0.6)
							panel:ScheduleEvent("die", delay + 0.6 + 0.25)

							children[#children+1] = panel
							delay = delay + 0.35
						end
					end
				end

				element.children = children
			end
		end
	}

	local sharedInfo = {}

	local damagePanelsByRollId = sharedInfo.damagePanelsByRollId or {}
	sharedInfo.damagePanelsByRollId = damagePanelsByRollId

	local childPanels = {
		effectsPanel,
		animationsPanel,
	}

	for _,p in ipairs(g_RegisteredPanels) do
		childPanels[#childPanels+1] = p.create(token, sharedInfo)
	end

	local rollCheckPanel = nil

	token.sheet = gui.Panel{
		bgimage = 'panels/square.png',
		interactable = false,
		blocksGameInteraction = false,

		styles = {
			{
				width = 100,
				height = 100,

				halign = 'center',
				valign = 'center',

				borderColor = 'clear',
				borderWidth = 0,
				bgcolor = 'clear',
                --worldspace = true,
			},

			{
				selectors = { 'hidden' },
				hidden = 1,
			},

			{
				selectors = { 'collapsed' },
				collapsed = 1,
			},

			{
				selectors = { 'select' },
				borderWidth = 4,
				borderColor = '#ffffffff', --at the moment this is the same as 'focus'. Is there any reason to distinguish focus?
			},

			{
				selectors = { 'focus' },
				borderWidth = 4,
				borderColor = '#ffffffff',
			},

			{
				selectors = { 'target-attack' },
				transitionTime = 0.2,
				borderWidth = 4,
				borderColor = '#ff0000ff',
				bgcolor = '#ff000022',
				brightness = 5,
			},

			{
				selectors = { 'target-attack', 'hover' },
				scale = 1.1,
				transitionTime = 0.2,
				bgcolor = '#ff000044',
				borderWidth = 6,
				brightness = 8,
			},

			{
				selectors = { 'target-attack', 'press' },
				scale = 1.05,
				transitionTime = 0.1,
				bgcolor = '#ff000066',
			},

			{
				selectors = { 'damage' },
				borderColor = '#ff0000ff',
				transitionTime = 0.4,
			},
		},

		selfStyle = {
			cornerRadius = 16,
		},

		data = {
			targetInfo = nil, --information about whatever is targeting this token.
			PlayEffect = function(id, looping, options)
				return SpawnEffect(id, looping, options)
			end,
			firstThink = true,

			nextLabelTime = 0,
		},

		events = {
			playEffect = function(element, id, looping, options)
				element.data.PlayEffect(id, looping, options)
			end,

			--info = { damage = int, message = rollInfo|nil, revealDamage = bool }
			floatdamage = function(element, info, force)
				if not force then
					local nextLabelTime = element.data.nextLabelTime
					local t = dmhub.Time()
					element.data.nextLabelTime = max(t, nextLabelTime) + 1
					if nextLabelTime > t then
						element:ScheduleEvent("floatdamage", nextLabelTime - t, info, true)
						return
					end
				end


				if info.message == nil and not info.revealDamage then
					return
				end

				local newPanel = gui.Panel{
					styles = {
						{
							width = "auto",
							height = 40,
							flow = "horizontal",
						},
						{
							selectors = {"float"},
							transitionTime = 5,
							y = -200,
						},
					},
					create = function(element)
						dmhub.Schedule(4, function()
							if element ~= nil and element.valid then
								element:SetClassTree('fade', true)
							end
						end)
						dmhub.Schedule(5, function()
							if element ~= nil and element.valid then
								element:DestroySelf()
							end
						end)
						element:SetClass('float', true)
					end,

					showMessage = function(element)
						local totalDamage = 0

						local children = {}
						local resultInfo = info.message.resultInfo
						for catid,catInfo in pairs(resultInfo) do
							local damage = catInfo.total
							if info.halfDamage then
								damage = math.floor(damage/2)
							end

							damage = tostring(math.tointeger(damage))
							children[#children+1] = gui.Label{
								color = "white",
								fontSize = 36,
								width = "auto",
								height = "auto",
								bold = true,
								text = damage,
								styles = {
									{
										selectors = {"fade"},
										transitionTime = 0.5,
										opacity = 0,
									}
								},
							}

							totalDamage = totalDamage + damage

							local damageType = string.lower(catid)
							if string.starts_with(damageType, "magical ") then
								damageType = string.gsub(damageType, "magical ", "")
							end

							local damageInfo = rules.damageTypesToInfo[damageType]
							if damageInfo ~= nil then
								children[#children+1] = gui.Panel{
									width = 32,
									height = 32,
									bgimage = damageInfo.iconid,
									valign = "center",
									blend = "add",
									styles = {
										{
											bgcolor = damageInfo.display.bgcolor,
										},
										{
											selectors = {"fade"},
											transitionTime = 0.5,
											bgcolor = "black",
										},
									},
								}
							end



						end

						element.children = children

						if info.revealDamage then
							element:ScheduleEvent("showActualDamage", 1.5, totalDamage)
						end
					end,

					showActualDamage = function(element, expected)
						for _,child in ipairs(element.children) do
							child:SetClassTree("fade", true)
						end

						local arrowPanel = nil
						if expected ~= nil then
							local arrow = "icons/icon_arrow/icon_arrow_28.png"
							if expected < info.damage then
								arrow = "icons/icon_arrow/icon_arrow_29.png"
							elseif expected > info.damage then
								arrow = "icons/icon_arrow/icon_arrow_30.png"
							end

							arrowPanel = gui.Panel{
								interactable = false,
								width = 16,
								height = 16,
								halign = "center",
								valign = "center",
								bgcolor = "red",
								bgimage = arrow,
							}
						end

						element:AddChild(gui.Panel{
							floating = true,
							flow = "horizontal",
							width = "auto",
							height = "auto",
							interactable = false,
							arrowPanel,

							styles = {
								{
									selectors = {"create"},
									transitionTime = 0.5,
									opacity = 0,
								},
								{
									selectors = {"fade"},
									transitionTime = 1,
									opacity = 0,
								}
							},
							gui.Label{
								interactable = false,
								width = "auto",
								height = "auto",
								halign = "center",
								valign = "center",
								fontSize = 36,
								bold = true,
								color = "red",
								text = tostring(math.tointeger(info.damage)),
							},
						})
					end,
				}

				if info.message ~= nil then
					newPanel:FireEvent("showMessage")
				else
					newPanel:FireEvent("showActualDamage")
				end

				element:AddChild(newPanel)
			end,

			floatlabel = function(element, text, color, force)


				if not force then
					local nextLabelTime = element.data.nextLabelTime
					local t = dmhub.Time()
					element.data.nextLabelTime = max(t, nextLabelTime) + 1
					if nextLabelTime > t then
						element:ScheduleEvent("floatlabel", nextLabelTime - t, text, color, true)
						return
					end
				end

				local children = element.children
				children[#children+1] = gui.Label{
					text = text,
					floating = true,
					styles = {
						{
							width = 'auto',
							height = 'auto',
							fontSize = 34,
							color = color,
						},
						{
							selectors = {"float"},
							transitionTime = 5,
							y = -200,
						},
						{
							selectors = {"fade"},
							transitionTime = 1,
							opacity = 0,
						},
					},
					events = {
						create = function(element)
							dmhub.Schedule(4, function()
								if element.valid then
									element:SetClass('fade', true)
								end
							end)
							dmhub.Schedule(5, function()
								if element.valid then
									element:DestroySelf()
								end
							end)
							element:SetClass('float', true)
						end,
					},
				}

				element.children = children
			end,

			floateffect = function(element, effect)
				element:AddChild(
					gui.Panel{
						styles = {
							{
								width = 64,
								height = 64,
							},
							effect.display,
							{
								selectors = {"float"},
								transitionTime = 5,
								y = -200,
							},
							{
								selectors = {"fade"},
								transitionTime = 1,
								bgcolor = "black",
							},
						},

						bgimage = effect.iconid,
						blend = "add",

						events = {
							create = function(element)
								dmhub.Schedule(5, function()
									element:SetClass('fade', true)
								end)
								dmhub.Schedule(6, function()
									element:DestroySelf()
								end)
								element:PulseClass("fade")
								dmhub.Schedule(1, function()
									element:SetClass('float', true)
								end)
							end,
						},
					}
				)
			end,

			think = function(element)
				element:FireEvent("refresh")
			end,

			refresh = function(element)
				g_profileMain:Begin()

				if token.properties ~= nil and current_damage_entry.id ~= token.properties.damage_entry.id then
					current_damage_entry = dmhub.DeepCopy(token.properties.damage_entry)
					local damagePanel = damagePanelsByRollId[current_damage_entry.id]
					local delayFloat = 0
					local halfDamage = false
					if damagePanel ~= nil and damagePanel.valid then
						halfDamage = damagePanel.data.half
						damagePanel:FireEventTree("combineAnimation")
						delayFloat = 0.4
					end

					local damageMessage = nil
					--try to fish out the roll message for this.
					for i,message in ipairs(chat.messages) do
						if message.key == current_damage_entry.id then
							damageMessage = message
						end
					end

					if current_damage_entry.damage then
						element:PulseClass('damage')
						element.data.PlayEffect('redflash')

						--element:ScheduleEvent('floatlabel', delayFloat, string.format("%d", current_damage_entry.damage), 'red')
						element:ScheduleEvent('floatdamage', delayFloat, { damage = current_damage_entry.damage, message = damageMessage, revealDamage = token.canControl, halfDamage = halfDamage })
					elseif current_damage_entry.heal then
						element.data.PlayEffect('curewounds')
						if token.canControl then
							element:ScheduleEvent('floatlabel', delayFloat, string.format("%d", current_damage_entry.heal), '#004d52')
						end
					end
				end

				--one time floating effects
				if token.properties ~= nil and token.properties:has_key('floatEffects') then
					for k,effect in pairs(token.properties.floatEffects) do
						if not emotesProcessed[k] then
							if element.data.firstThink == false then
								element:FireEvent('floateffect', effect)
							end
							emotesProcessed[k] = true
						end
					end
				end

				element.data.firstThink = false

				--one time emotes. Play any we haven't seen yet.
				if token.properties ~= nil and token.properties:has_key('emotes') then
					for k,emote in pairs(token.properties.emotes) do
						if not emotesProcessed[k] then
							element.data.PlayEffect(emote.effect)
							emotesProcessed[k] = true
						end
					end
				end

				--loop emotes. Start any that need starting, stop any that need stopping.
				if token.properties ~= nil then

					local emotes = token.properties:CalculateLoopingEmotes() or {}
					local removes = {}
					local hasEmotes = false
					for k,emotePanel in pairs(loopingEmotes) do
						if emotes[k] == nil then
							removes[#removes+1] = k
						else
							hasEmotes = true
						end
					end

					for i,k in ipairs(removes) do
						for j,emote in ipairs(loopingEmotes[k]) do
							emote:FireEvent('destroy')
						end
						loopingEmotes[k] = nil
					end

					for k,emote in pairs(emotes) do
						if loopingEmotes[k] == nil then
							loopingEmotes[k] = element.data.PlayEffect(k, true, {tokenid = token.id})
							if loopingEmotes[k] then
								hasEmotes = true
							end
						end
					end

					if hasEmotes then
						element.thinkTime = 1
					else
						element.thinkTime = 12
					end
				end
				g_profileMain:End()
			end,

			focus = function(element)
				element:AddClass('focus')
			end,

			defocus = function(element)
				element:RemoveClass('focus')
				element.popup = nil
			end,

			select = function(element)
				element:AddClass('select')
			end,

			deselect = function(element)
				element:RemoveClass('select')
				element.popup = nil
			end,

			targetnoninteractive = function(element, options)
				if targetEffect == nil then
					targetEffect = { interactive = false }
					for i,effect in ipairs(element.data.PlayEffect('targetglow', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end
					for i,effect in ipairs(element.data.PlayEffect('target', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end
					for i,effect in ipairs(element.data.PlayEffect('target2stacks', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end
					for i,effect in ipairs(element.data.PlayEffect('target3stacks', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end

					for i,effect in ipairs(targetEffect) do
						effect:SetClass('target-active', true)
					end
				end
			end,

			target = function(element, options)

				if targetEffect == nil then
					targetEffect = {}
					options.remote = true
					for i,effect in ipairs(element.data.PlayEffect('targetglow', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end

					for i,effect in ipairs(element.data.PlayEffect('target', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end
					for i,effect in ipairs(element.data.PlayEffect('target2stacks', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end
					for i,effect in ipairs(element.data.PlayEffect('target3stacks', true, options)) do
						targetEffect[#targetEffect+1] = effect
					end

					for i,effect in ipairs(targetEffect) do
						effect:SetClass('target-active', element:HasClass('hover'))
					end
				end

			end,

			untarget = function(element)
				if targetEffect ~= nil then
					for i,effect in ipairs(targetEffect) do
						effect:FireEvent('destroy')
					end
					targetEffect = nil
				end
			end,

			--any selected targets will be adopted into the adoptionList to keep alive
			--until later.
			adoptSelectedTargets = function(element, adoptionList)
				if targetEffect ~= nil then
					for i=#targetEffect,1,-1 do
						if targetEffect[i]:HasClass("target-selected") then
							adoptionList[#adoptionList+1] = targetEffect[i]
							table.remove(targetEffect, i)
						end
					end

					if #targetEffect == 0 then
						targetEffect = nil
					end
				end
			end,

			tokenHover = function(element)
				if targetEffect ~= nil and targetEffect.interactive ~= false then
					for i,effect in ipairs(targetEffect) do
						effect:SetClass('target-active', true)
					end

					if gui.GetFocus() ~= nil then
						gui.GetFocus():FireEvent('highlightTargetToken', token)
					end
				end
			end,

			tokenDehover = function(element)
				if targetEffect ~= nil and targetEffect.interactive ~= false then
					for i,effect in ipairs(targetEffect) do
						effect:SetClass('target-active', false)
					end

					if gui.GetFocus() ~= nil then
						gui.GetFocus():FireEvent('unhighlightTargetToken', token)
					end
				end
			end,

			tokenPress = function(element)
				if targetEffect ~= nil and targetEffect.interactive ~= false then
					for i,effect in ipairs(targetEffect) do
						effect:SetClass('target-press', true)
					end
				end
			end,

			tokenUnpress = function(element)
				if targetEffect ~= nil and targetEffect.interactive ~= false then
					for i,effect in ipairs(targetEffect) do
						effect:SetClass('target-press', false)
					end
				end
			end,

			diceroll = function(element, rollInfo)
				if rollCheckPanel ~= nil then
					rollCheckPanel:DestroySelf()
					rollCheckPanel = nil
				end

				if rollInfo.properties == nil or rollInfo.properties.displayType ~= 'save' then
					return
				end

				local mod = 0
				local childSave = gui.Panel{
					floating = true,
					halign = "right",
					valign = "bottom",
					width = 32,
					height = 32,
					hmargin = 8,
					vmargin = 8,
					bgimage = "panels/square.png",
					bgcolor = "clear",

					data = {
						rolls = {},
					},

					diceface = function(element, diceguid, num)
						element.data.rolls[diceguid] = num
						local val = mod
						for _,roll in ipairs(rollInfo.rolls) do
							local n = element.data.rolls[roll.guid]
							if n == nil then
								return
							end

							val = val + n
						end


						local outcome = rollInfo.properties:GetOutcomeOfValue(val)
						local success = outcome.outcome == 'Success'
						if num == 20 then
							success = true
						elseif num == 1 then
							success = false
						end

						if success then
							element.bgimage = "ui-icons/greend20.png"
							element.selfStyle.bgcolor = "white"
						else
							element.bgimage = "ui-icons/redd20.png"
							element.selfStyle.bgcolor = "white"
						end
					end,

					destroy = function(element)
						if element == rollCheckPanel then
							rollCheckPanel = nil
						end

						element:DestroySelf()
					end,
				}

				childSave:ScheduleEvent("destroy", 12)

				rollCheckPanel = childSave

				local info = rollInfo.resultInfo
				for cat,catInfo in pairs(info) do
					for i,roll in ipairs(catInfo.rolls) do
						--for now just ignore dice that ultimately get dropped. Will anyone really notice?
						if not roll.dropped then
							local events = chat.DiceEvents(roll.guid)
							if events ~= nil then
								events:Listen(childSave)
							end
						end
					end

					mod = mod + (catInfo.mod or 0)
				end
				element:AddChild(childSave)
			end,

			tokenClick = function(element, isselected)
				if element.data.targetInfo ~= nil then
					for i,effect in ipairs(targetEffect or {}) do
						effect:SetClass('target-active', element:HasClass('hover'))
					end
					element.data.targetInfo.execute(token, { targetEffect = targetEffect })

					--mark this click as consumed so the token doesn't get selected etc.
					token:ConsumeClick()
					return
				end

				if (not token.canControl) or (not isselected) then
					return
				end

				element.popupPositioning = 'panel'

				token:ConsumeClick()

				local parentElement = element

				local radialMenu
				radialMenu = gui.Panel{
					captureEscape = true,
					escapePriority = EscapePriority.CANCEL_TOKEN_MENU,
					escape = function()
						element.popup = nil
					end,
					styles = RadialStyles,
					children = {

						gui.Panel{
							className = 'radial-menu-item',
							translate = core.Vector2(0,70):Rotate(45),
							styles = {
								{
									selectors = {"create"},
									transitionTime = 0.2,
									translate = core.Vector2(0,-70):Rotate(45),
								},
							},
							events = {
								click = function(element)
									token:ShowSheet()
								end,
							},
							children = {
								gui.Panel{
									bgimage = 'fantasy-icons/Enchantment_34_summoning_scroll.png',
									className = 'radial-menu-icon',
								}
							},
						},

						gui.Panel{
							className = 'radial-menu-item',
							translate = core.Vector2(0,70):Rotate(90),
							styles = {
								{
									selectors = {"create"},
									transitionTime = 0.2,
									translate = core.Vector2(0,-70):Rotate(90),
								},
							},
							events = {
								click = function(element)
									gamehud:ShowInventory(token)
								end,
							},
							children = {
								gui.Panel{
									bgimage = 'fantasy-icons/Tailoring_44_little_bag.png',
									className = 'radial-menu-icon',
								}
							},
						},

						gui.Panel{
							className = 'radial-menu-item',
							translate = core.Vector2(0,70):Rotate(135),
							styles = {
								{
									selectors = {"create"},
									transitionTime = 0.2,
									translate = core.Vector2(0,-70):Rotate(135),
								},
							},
							events = {
								click = function(element)
									parentElement:FireEvent("emojiMenu")
								end,
							},
							children = {
								gui.Panel{
									bgimage = 'fantasy-icons/emoji-icon.png',
									className = 'radial-menu-icon',
									width = 40,
									height = 40,
								}
							},
						},
					},
				}

				element.popup = radialMenu
			end,

			emojiMenu = function(element)
				local parentElement = element
				local emojiItems = {}

				emojiItems[#emojiItems+1] = gui.Panel{
					classes = {'radial-menu-item'},
					translate = core.Vector2(0,70):Rotate(0*45),

					styles = {
						{
							selectors = {"radial-menu-item", "create"},
							transitionTime = 0.2,
							translate = core.Vector2(0,-70):Rotate(0*45),
						},
					},
					click = function(element)
						parentElement.popup = nil
						gamehud:CreateEmojiEditorPanel(token)
					end,

					gui.Label{
						fontSize = 48,
						text = "...",
						y = -14,
						halign = "center",
						valign = "center",
						width = "auto",
						height = "auto",
					},
				}

				token.properties:CalculateLoopingEmotes()
				local loopingEmotes = token.properties:try_get("loopemotes", {})

                if not table.empty(loopingEmotes) then
                    local k = nil
                    for key,_ in pairs(loopingEmotes) do
                        k = key
                        break
                    end
                    local index = 7
                    emojiItems[#emojiItems+1] = gui.Panel{
						classes = {'radial-menu-item'},
						translate = core.Vector2(0,70):Rotate(index*45),

						styles = {
							{
								selectors = {"radial-menu-item", "create"},
								transitionTime = 0.2,
								translate = core.Vector2(0,-70):Rotate(index*45),
							},
                            {
                                selectors = {"X"},
                                width = "12%",
                                height = "80%",
                                halign = "center",
                                valign = "center",
                                bgcolor = "#999999cc",
                                bgimage = "panels/square.png",
                            },
                            {
                                selectors = {"X", "parent:hover"},
                                bgcolor = "#ffffffff",
                            }
						},

						click = function(element)
                            token.properties:CalculateLoopingEmotes()
                            local loopingEmotes = token.properties:try_get("loopemotes", {})
                            for k,_ in pairs(loopingEmotes) do
							    token.properties:Emote(k, {deleteOthers = true})
                            end

							parentElement.popup = nil
						end,

						gui.Panel{
							bgimage = k,
							className = 'radial-menu-icon',
						},

                        gui.Panel{
                            interactable = false,
                            classes = {"X"},
                            rotate = -45,
                        },

                        gui.Panel{
                            interactable = false,
                            classes = {"X"},
                            rotate = 45,
                        },
                    }
                end

				local dataTable = assets.emojiTable
				for index,k in ipairs(GetFavoriteEmoji()) do
                    local command = string.format("emote %s", k)
                    local binding = dmhub.GetCommandBinding(command)
                    local bindingLabel = gui.Label{
                        text = dmhub.GetCommandBinding(command),
                        bgimage = "panels/square.png",
                        bgcolor = "#000000fa",
                        borderColor = "#000000fa",
                        borderWidth = 5,
                        pad = 2,
                        borderFade = true,
                        valign = "top",
                        halign = "right",
                        width = "auto",
                        height = "auto",
                        fontSize = 10,
                        color = "white",
                        refreshBindings = function(element)
                            element.text = dmhub.GetCommandBinding(command)
                        end,
                    }

					emojiItems[#emojiItems+1] = gui.Panel{
						classes = {'radial-menu-item', cond(loopingEmotes[k], 'selected')},
						translate = core.Vector2(0,70):Rotate(index*45),

						styles = {
							{
								selectors = {"radial-menu-item", "create"},
								transitionTime = 0.2,
								translate = core.Vector2(0,-70):Rotate(index*45),
							},
						},


						click = function(element)
							token.properties:Emote(k, {deleteOthers = true})
							parentElement.popup = nil
						end,

                        rightClick = function(element)
                            element.popup = gui.ContextMenu{
                                entries = {
                                    {
                                        text = "Set Keybind...",
                                        click = function()
                                            local dataTable = assets.emojiTable
                                            local emoteid = k
                                            local emote = dataTable[emoteid]
                                            element.popup = Keybinds.ShowBindPopup{
                                                command = string.format("emote %s", emoteid),
                                                name = string.format("%s Emote", emote.description),
                                                destroy = function()
                                                    element.root:FireEventTree("refreshBindings")
                                                end,
                                            }
                                        end,
                                    }
                                }
                            }
                        end,

						gui.Panel{
							bgimage = k,
							className = 'radial-menu-icon',
						},
                        bindingLabel,
					}
				end

				local radialMenu = gui.Panel{
					captureEscape = true,
					escapePriority = EscapePriority.CANCEL_TOKEN_MENU,
					escape = function()
						element.popup = nil
					end,
					styles = RadialStyles,
					children = emojiItems,
				}

				element.popup = radialMenu
			end,

		},

		children = childPanels,
	}

	token.sheet:FireEventTree("refresh")
end

function creature:RefreshReactionAlerts(token)
	local tmp_reactions = self:try_get("_tmp_reactions")
	local first_time = tmp_reactions == nil
	if first_time then
		tmp_reactions = {}
		self._tmp_reactions = tmp_reactions
	end
    local activeReactions = self:try_get("activeReactions")
	if activeReactions == nil or #activeReactions == 0 then
		return
	end

	local tmp_reactions = self:get_or_add("_tmp_reactions", {})

	for _,reaction in ipairs(activeReactions) do
		if (not tmp_reactions[reaction.guid]) and (not first_time) and token.sheet ~= nil then
			token.sheet:FireEvent("floatlabel", reaction.ability, "red")
		end
		tmp_reactions[reaction.guid] = true
	end
end

--creature animation management.
function creature:RefreshAnimations(token)
	if token.canControl then
		self:RefreshReactionAlerts(token)
	end

	local animations = self:try_get("animations")
	if animations == nil then
		self._tmp_anim = ""
		return
	end

	local tmp_anim = self:try_get("_tmp_anim")
	if tmp_anim == nil then
		self._tmp_anim = animations.guid
		return
	end

	if tmp_anim == animations.guid then
		return
	end

	for _,anim in ipairs(animations.anim) do
		self:PlayAnimation(token, anim)
	end

	self._tmp_anim = animations.guid
end

function creature:FloatLabel(text, color)
	self:AddAnimation{
		animType = "floatlabel",
		text = text,
		color = color,
	}
end

function creature:PlayAnimation(token, anim)
	if token.sheet ~= nil then
		token.sheet:FireEventTree("animation", token, anim)
	end
end

function creature:AddAnimation(anim)
	local animations = self:get_or_add("animations", {})

	if animations.guid ~= dmhub.gameupdateid then

		animations.guid = dmhub.gameupdateid
		animations.anim = {}
	end

	animations.anim[#animations.anim+1] = anim
end

function creature:GetOrAddAnimation(anim)
	local animations = self:get_or_add("animations", {})

	if animations.guid ~= dmhub.gameupdateid then

		animations.guid = dmhub.gameupdateid
		animations.anim = {}
	end

	for _,existing in ipairs(animations.anim) do
		if existing.animType == anim.animType then
			return existing
		end
	end

	animations.anim[#animations.anim+1] = anim
	return anim
end
