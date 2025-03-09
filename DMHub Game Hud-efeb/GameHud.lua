local mod = dmhub.GetModLoading()

function GameHud:Think()
	if #self.interactionQueue > 0 and self:AvailableToInteract() then
		local f = self.interactionQueue[1]
		table.remove(self.interactionQueue, 1)
		f()
	end
end

function GameHud:QueueInteraction(f)
	self.interactionQueue[#self.interactionQueue+1] = f
end

--is the player currently available to interact with something that pops up?
function GameHud.AvailableToInteract(self)
	return ActivatedAbility.IsCasting() == false and not self.dialog.sheet.modalDialog
end

function GameHud.ShowInventory(self, token, options)
	if token == nil then
		return
	end
	self.inventoryDialog.data.open(token, options)
end

function GameHud.ToggleInventory(self, token)
	self.inventoryDialog.data.toggleOpen(token)
end

function GameHud.Refresh(self)
	self.dialog.sheet:FireEventTree('refresh')

	if self:try_get("hasRefreshed", false) == false then
		self.hasRefreshed = true
		if dmhub.isDM and dmhub.GetSettingValue("showtutorial") then
			LaunchablePanel.GetOrLaunchPanel("Tutorial")
		end
	end
end

--function which can be called by dmhub to present a tooltip on the map.
function GameHud.ShowTooltipNearLoc(self, loc, text, options)
	options = options or {}
	self.dialog.sheet:FireEvent("tiletooltip", {
		loc = loc,
		text = text,
		halign = options.halign,
		valign = options.valign,
	})
	
end

--called by dmhub to clear map tooltips.
function GameHud.ClearMapTooltip(self)
	self.dialog.sheet.tooltip = nil
end

--functions called by dmhud to indicate that a token is moving or has finished moving.
function GameHud.TokenMoving(self, token, path)
	
	local diagonals = dmhub.GetSettingValue("truediagonals") and math.floor(path.numDiagonals/2) or 0

	local distance = path.numSteps + diagonals
	distance = distance * dmhub.FeetPerTile

	local text = string.format('Movement: %s %s', MeasurementSystem.NativeToDisplayString(distance), string.lower(MeasurementSystem.UnitName()))

    local altitudeDelta = path.destination.altitude - path.origin.altitude
    if altitudeDelta < 0 then
        text = string.format("%s (%d elevation)", text, round(altitudeDelta))
    elseif altitudeDelta > 0 then
        text = string.format("%s (+%d elevation)", text, round(altitudeDelta))
    end

	local walkAndSwim = false

	if token.properties ~= nil then
		if path.mount then
			text = string.format("%s\nMounting or dismounting takes half of movement for the round.", text)
		end

		local moveType = token.properties:CurrentMoveType()
		if moveType == "walk" or moveType == "swim" then

			local waterSteps = math.floor(path.waterSteps) * dmhub.FeetPerTile
			if waterSteps > 0 and waterSteps < distance then
				text = string.format("%s; swim %s %s", text, MeasurementSystem.NativeToDisplayString(waterSteps), string.lower(MeasurementSystem.UnitName()))
				walkAndSwim = true
			end

			local difficultDistance = math.floor(path.difficultSteps) * dmhub.FeetPerTile
			if difficultDistance == distance then
				text = string.format("%s; all in difficult terrain", text)
			elseif difficultDistance > 0 then
				text = string.format("%s; %s %s in difficult terrain", text, MeasurementSystem.NativeToDisplayString(difficultDistance), string.lower(MeasurementSystem.UnitName()))
			end

			local squeezeDistance = math.floor(path.squeezeSteps) * dmhub.FeetPerTile
			if squeezeDistance == distance then
				text = string.format("%s; squeezing through a tight space", text)
			elseif squeezeDistance > 0 then
				text = string.format("%s; %s %s squeezing through tight spaces", text, MeasurementSystem.NativeToDisplayString(squeezeDistance), string.lower(MeasurementSystem.UnitName()))
			end
		end
	end

	if path.teleport then
		--completely different rules for teleporting.
		--make an 'approximated pythag theorem' with nice round numbers.
		local xdelta = math.abs(path.origin.x - path.destination.x)
		local ydelta = math.abs(path.origin.y - path.destination.y)
		local larger = cond(xdelta >= ydelta, xdelta, ydelta)
		local smaller = cond(xdelta >= ydelta, ydelta, xdelta)
		distance = (larger + math.floor(smaller*0.5))*5
		text = string.format('Teleport: %s %s', MeasurementSystem.NativeToDisplayString(distance), string.lower(MeasurementSystem.UnitName()))
	end

	local floorDelta = nil

	if path.destination.floor ~= token.loc.floor then
		local diff = token.loc:FloorDifference(path.destination)
		floorDelta = diff
		if diff == 1 then
			text = text .. ' (+1 Floor)'
		elseif diff == -1 then
			text = text .. ' (-1 Floor)'
		else
			local prefix = '+'
			if diff < 0 then
				prefix = '-'
				diff = -diff
			end

			text = text .. ' (' .. prefix .. tostring(diff) .. ' Floors)'
		end
	end


	local creature = token.properties
	if creature ~= nil and not path.teleport then
		text = string.format('%s\n%s %s %s %s per round', text, creature.GetTokenDescription(token), string.lower(creature:CurrentMoveTypeInfo().tense), MeasurementSystem.NativeToDisplayString(creature:GetEffectiveSpeed(creature:CurrentMoveType())), string.lower(MeasurementSystem.UnitName()))

		if walkAndSwim then
			local otherMode = "walk"
			if creature:CurrentMoveType() == "walk" then
				otherMode = "swim"
			end

			text = string.format("%s\n%s %s %s %s per round", text, creature.GetTokenDescription(token), string.lower(creature.movementTypeById[otherMode].tense), MeasurementSystem.NativeToDisplayString(creature:GetEffectiveSpeed(otherMode)), string.lower(MeasurementSystem.UnitName()))
		end

		local distMoved = creature:DistanceMovedThisTurn()
		if distMoved > 0 then
			text = string.format("%s\nAlready moved %s %s this turn.", text, MeasurementSystem.NativeToDisplayString(distMoved*dmhub.FeetPerTile), string.lower(MeasurementSystem.UnitName()))
		end
	end

	if (not path.valid) and (not path.teleport) and dmhub.isDM then
		text = string.format('%s\nNo path found, move through walls or hold shift to teleport.', text)
	end

	--calculate how it should be aligned, trying to avoid the tooltip going over the arrow or the creature.
	local halign = 'center'
	local valign = 'center'


	local dest = path.destination

	if dest.x > path.origin.x then
		valign = 'top'
	end

	if dest.x < path.origin.x then
		valign = 'top'
	end

	if dest.y > path.origin.y then
		valign = 'top'
	end

	if dest.y < path.origin.y then
		valign = 'bottom'
	end

	--for large tokens make sure the tooltip appears well off the creature.
	local locsOccupied = token:LocsOccupyingWhenAt(dest)
	if locsOccupied ~= nil and #locsOccupied > 1 then
		for _,loc in ipairs(locsOccupied) do
			if valign == "top" and loc.y > dest.y then
				dest = loc
			end

			if valign == "bottom" and loc.y < dest.y then
				dest = loc
			end
		end
		
	end

	self.dialog.sheet:FireEvent("tiletooltip", {
		loc = dest,
		text = text,
		halign = halign,
		valign = valign,
		floorDelta = floorDelta,
	})
end

function GameHud.FinishTokenMoving(self)
	self.dialog.sheet.tooltip = nil
end

--function called by DMHub to indicate that a Loot object is being edited.
function GameHud.EditLoot(self, object)
	local lootobj = object:GetComponent("Loot")
	if lootobj == nil then
		dmhub.Debug('Could not find loot')
		return
	end
	self.inventoryDialog.data.open(lootobj, { isobject = true, isshop = lootobj.shop, showBasic = true })
end

--function called by DMHub to indicate that a Loot object is being looted by a player.
function GameHud.LootContainer(self, token, object)
	local lootobj = object:GetComponent("Loot")
	if lootobj == nil or token == nil then
		dmhub.Debug('Could not find loot')
		return
	end

	if lootobj.instantLoot then
		GameHud.LootAll(lootobj, token)
		if lootobj.destroyOnEmpty then
			lootobj:DestroyObject()
		end
		return
	end

	self.inventoryDialog.data.open(token, {})
	self.tradeInventoryDialog.data.open(lootobj, { isobject = true, isshop = lootobj.shop, title = cond(lootobj.shop, 'Shop', 'Loot'), tradewith = token })
	
end

function GameHud:CreateTopLeftButtonPanel()

	local CreateButtonTooltip = gui.Tooltip

--local undoButton = gui.HudIconButton{
--		icon = 'panels/hud/anticlockwise-rotation.png',
--		events = {
--			click = function(element)
--				if element:HasClass("disabled") then
--					return
--				end
--				dmhub.Undo()
--			end,
--			hover = function(element)
--				if element:HasClass("disabled") then
--					return
--				end
--				if dmhub.undoState.undoDescription == nil then
--					return;
--				end
--
--				local text = string.format("Undo: %s", dmhub.undoState.undoDescription)
--				gui.Tooltip(text)(element)
--			end,
--		}
--	}

--local redoButton = gui.HudIconButton{
--		icon = 'panels/hud/clockwise-rotation.png',
--		events = {
--			click = function(element)
--				if element:HasClass("disabled") then
--					return
--				end
--				dmhub.redo()
--			end,
--			hover = function(element)
--				if element:HasClass("disabled") then
--					return
--				end
--				if dmhub.undoState.redoDescription == nil then
--					return;
--				end
--				local text = string.format("Redo: %s", dmhub.undoState.redoDescription)
--				gui.Tooltip(text)(element)
--			end,
--		}
--	}

	local topLevelButtons = {
		self:CreateToolbarPanel(),

--	gui.HudIconButton{
--		icon = 'panels/hud/exit-door.png',
--		click = function(element)
--			dmhub.LeaveGame()
--		end,
--		hover = CreateButtonTooltip("Leave Game"),
--	},
--
--	gui.HudIconButton{
--		icon = 'panels/hud/gear.png',
--		click = function(element)
--			dmhub.ShowPlayerSettings()
--		end,
--		hover = CreateButtonTooltip("Player Settings"),
--	},
--	
--	undoButton,
--	redoButton,
--
--	gui.HudIconButton{
--		icon = "icons/icon_common/icon_common_51.png",
--
--		create = function(element)
--			element:SetClass('deselected', not dmhub.GetSettingValue("showgrid"))
--			if element.tooltip ~= nil then
--				--redisplay tooltip with new setting.
--				element:FireEvent('hover')
--			end
--		end,
--		click = function(element)
--			dmhub.SetSettingValue("showgrid", not dmhub.GetSettingValue("showgrid"))
--			element:FireEventTree('create')
--		end,
--
--		hover = function(element)
--			local str = string.format('Grid overlay: %s', cond(dmhub.GetSettingValue("showgrid"), 'on', 'off'))
--			if dmhub.isDM then
--				str = string.format("%s\n(Only turns the grid off or on for you. Use grid color in map settings to control the grid for all players)", str)
--			end
--			gui.Tooltip(str)(element)
--		end
--	},

--	gui.HudIconButton{
--		icon = "icons/icon_tool/icon_tool_41.png",
--		click = function(element)
--			dmhub.SetSettingValue("zoom", max(0, dmhub.GetSettingValue("zoom") - 0.1))
--		end,
--	},
--	gui.HudIconButton{
--		icon = "icons/icon_tool/icon_tool_40.png",
--
--		click = function(element)
--			dmhub.SetSettingValue("zoom", min(1, dmhub.GetSettingValue("zoom") + 0.1))
--		end,
--	},

	--gui.HudIconButton{
	--	icon = 'icons/icon_tool/icon_tool_101.png',
	--	click = function(element)
	--		gamehud:ToggleRuler()
	--	end,
	--	hover = function(element)
	--		gui.Tooltip("Measure distances" .. FormatInputForCommand("measure"))(element)
	--	end,
	--},

		gui.Panel{
			flow = "horizontal",
			y = -12,
			x = -2,
			width = "auto",
			height = "auto",

			styles = {
				{
					hmargin = 2,
					flow = 'horizontal',
				}
			},

			self:CreateToolsMenu(),
			self:CreateMainMenu(),
		}
	}

	if dmhub.isDM and false then

		--spacing
		topLevelButtons[#topLevelButtons+1] = gui.Panel{
			style = {
				width = 32,
			}
		}

		--editing mode toggle button
		topLevelButtons[#topLevelButtons+1] = gui.Panel{
			bgimage = 'panels/square.png',
			escapePriority = EscapePriority.EXIT_DM_MODE, --very low priority exit from dm mode
			styles = {
				{
					width = 64,
					height = 64,
					bgcolor = '#92332DFF',
					borderWidth = 2,
					borderColor = 'grey',
					cornerRadius = 8,
					flow = 'none',
				},
				{
					selectors = 'hover',
					brightness = 1.2,
					borderColor = 'white',
				},

				{
					selectors = 'press',
					brightness = 0.6,
				},
				{
					selectors = 'dm-mode',
					inherit_selectors = true,
					borderWidth = 2,
					borderColor = 'white',
					--brightness = 1.5,
				},
			},
			events = {
				click = function(element)
					dmhub.editorMode = not dmhub.editorMode
					element.escapeActivates = dmhub.editorMode
				end,
				hover = CreateButtonTooltip("Toggle DM editing mode"),
			},

			children = {
				gui.Panel{
					bgimage = 'ui-icons/DMHubLogo.png',
					styles = {
						{
							halign = 'center',
							valign = 'center',
							width = '100%',
							height = '100%',
							bgcolor = 'white',
							borderWidth = 0,
						},

						{
							selectors = 'dm-mode',
							inherit_selectors = true,
							--brightness = 3,
						},
					}
				},

				gui.Panel{
					bgimage = 'ui-icons/DMHubLogo-light.png',
					styles = {
						{
							halign = 'center',
							valign = 'center',
							width = '100%',
							height = '100%',
							bgcolor = 'white',
							borderWidth = 0,
						},

						{
							selectors = 'dm-mode',
							inherit_selectors = true,
							brightness = 10,
							transitionTime = 0.5,
						},
					}
				},

			}
		}

	end

	local topLevelMenu = gui.Panel{
		id = 'TopLevelMenu',
		styles = {
			{
				margin = 4,
				flow = 'horizontal',
			}
		},

		width = "auto",
		height = "auto",
		y = 1,

		--the refreshUndo event is triggered by dmhub due to undo state having changed.
		--We refresh the buttons to show current state.
	--refreshUndo = function()
	--	undoButton:SetClass('disabled', dmhub.undoState.undoDescription == nil)
	--	redoButton:SetClass('disabled', dmhub.undoState.redoDescription == nil)
	--
	--	if dmhub.undoState.undoPending then
	--		undoButton:FireEventTree("seticon", 'game-icons/cloud-upload.png')
	--	else
	--		undoButton:FireEventTree("seticon", 'panels/hud/anticlockwise-rotation.png')
	--	end
	--
	--	if dmhub.undoState.redoPending then
	--		redoButton:FireEventTree("seticon", 'game-icons/cloud-upload.png')
	--	else
	--		redoButton:FireEventTree("seticon", 'panels/hud/clockwise-rotation.png')
	--	end
	--end,

		children = topLevelButtons,
	}

	return topLevelMenu
end

setting{
	id = "toolbarplayerconfig",
	default = {},
	storage = "preference",
}

setting{
	id = "toolbargmconfig",
	default = {},
	storage = "preference",
}

function GameHud:CreateToolbarPanel()
    local resultPanel

	local settingName = cond(dmhub.isDM, "toolbargmconfig", "toolbarplayerconfig")

	local SerializeToolbar

	local buttons = {}

	local CreateToolbarButton = function(item)
		
		local monitorEventGuid = nil

		local itemName = item.name
		local geticon = item.geticon
		local getdisabled = item.getdisabled
		local button
		button = gui.HudIconButton{
			icon = item.icon,
			monitor = item.setting,
			events = {
				destroy = function()
					dmhub.DeregisterEventHandler(monitorEventGuid)
				end,
				monitor = function(element)
					if item.setting ~= nil then
						button:SetClassTree("selected", dmhub.GetSettingValue(item.setting))
					end
				end,
				create = function(element)
					if geticon ~= nil then
						button:FireEventTree("seticon", geticon())
					end

					if getdisabled ~= nil then
						button:SetClassTree("disabled", getdisabled())
					end
				end,
				press = function()
					local info = Commands.GetCommandInfo(itemName)
					if info ~= nil and info.click ~= nil then
						info.click()
					end
				end,
				popupPositioning = "panel",
				linger = function(element)
					local info = Commands.GetCommandInfo(itemName)
					local text = itemName
					if info ~= nil then
						if info.gettext ~= nil then
							text = info.gettext()
						end

						if info.bind ~= nil then
							text = string.format("%s <color=#999999>(%s)", text, info.bind)
						end
					end
					gui.Tooltip(text)(element)
				end,
				rightClick = function(element)
					if dmhub.GetSettingValue("uilocked") then
						return
					end
					local menuItems = {
						{
							text = "Remove from toolbar",
							click = function()
								element.popup = nil
								local newButtons = {}
								for _,b in ipairs(buttons) do
									if b ~= element then
										newButtons[#newButtons+1] = b
									end
								end
								buttons = newButtons
								resultPanel:FireEvent("update")
								SerializeToolbar()
							end,
						},
						{
							text = "Reset Toolbar",
							click = function()
								element.popup = nil
								dmhub.ResetSetting(settingName)
							end,
						},
					}

					element.popup = gui.Panel{
						width = "auto",
						height = "auto",
						halign = "right",
						valign = "bottom",
						gui.ContextMenu{
							width = 300,
							x = -element.renderedWidth,
							entries = menuItems,
							click = function()
								element.popup = nil
							end,
						}
					}
				end,
			},
			data = {
				name = item.name,
			},
		}

		if item.setting ~= nil then
			button:SetClassTree("selected", dmhub.GetSettingValue(item.setting))
		end

		if item.monitorEvent ~= nil then
			monitorEventGuid = dmhub.RegisterEventHandler(item.monitorEvent, function()
				button:FireEvent("create")
			end)
		end

		return button
	end

	SerializeToolbar = function()
		local doc = {}
		for _,button in ipairs(buttons) do
			doc[#doc+1] = button.data.name
		end

		dmhub.SetSettingValue(settingName, doc)
	end

	local DeserializeToolbar = function()
		buttons = {}
		local menuItems = LaunchablePanel.GetMenuItems()
		local doc = dmhub.GetSettingValue(settingName)
		for _,itemName in ipairs(doc) do
			for _,item in ipairs(menuItems) do
				if item.name == itemName then
                    buttons[#buttons+1] = CreateToolbarButton(item)
				end
			end
		end
	end

	DeserializeToolbar()



    local addButton = gui.HudIconButton{
        icon = "ui-icons/Plus.png",
		popupPositioning = "panel",

		monitor = "uilocked",

		events = {

			create = function(element)
				element:SetClass("collapsed", dmhub.GetSettingValue("uilocked") or #buttons >= 8)
			end,

			monitor = function(element)
				element:FireEvent("create")
			end,

			click = function(element)
				if element.popup ~= nil then
					element.popup = nil
					return
				end

				local menuItems = LaunchablePanel.GetMenuItems()
				local items = {}
				for _,item in ipairs(menuItems) do
					if item.icon then
						local itemCopy = DeepCopy(item)
						local fn = item.click
						itemCopy.disabled = false
						itemCopy.bind = nil
						itemCopy.click = function()
							buttons[#buttons+1] = CreateToolbarButton(itemCopy)

							SerializeToolbar()

							resultPanel:FireEvent("update")
						end

						items[#items+1] = itemCopy
					end
				end

				element.popup = gui.Panel{
					width = "auto",
					height = "auto",
					halign = "right",
					valign = "bottom",
					gui.ContextMenu{
						width = 300,
						x = -element.renderedWidth,
						entries = items,
						click = function()
							element.popup = nil
						end,
					}
				}
			end,

			rightClick = function(element)
				local menuItems = {
					{
						text = "Reset Toolbar",
						click = function()
							element.popup = nil
							dmhub.ResetSetting(settingName)
						end,
					},
				}

				element.popup = gui.Panel{
					width = "auto",
					height = "auto",
					halign = "right",
					valign = "bottom",
					gui.ContextMenu{
						width = 300,
						x = -element.renderedWidth,
						entries = menuItems,
						click = function()
							element.popup = nil
						end,
					}
				}

			end,
		},
    }

    resultPanel = gui.Panel{
        width = "378",
        height = 44,
		x = -6,
		y = -4,
		margin = 0,
        flow = "horizontal",
		monitor = settingName,

        styles = {
			{
				classes = {"hudIconButton"},
				width = 44,
				height = 44,
				hmargin = 2,
				valign = "center",
			}
		},

		events = {
			monitor = function(element)
				DeserializeToolbar()
				element:FireEvent("update")
			end,

			update = function()
				local children = {}
				for _,button in ipairs(buttons) do
					children[#children+1] = button
				end
				children[#children+1] = addButton
				resultPanel.children = children

				addButton:FireEvent("create")
			end,
		},
        addButton,
    }

	resultPanel:FireEvent("update")

    return resultPanel
end

function GameHud:CreateTopBar()
	local dmControlsPanel = nil
	local layersPanel = nil
	--dmControlsPanel = self:DMGameControlsPanel()
	--layersPanel = self:CreateLayersPanel()

	self.topBarPanel = gui.Panel{
		width = "100%",
		valign = "top",
		height = "auto",
		flow = "horizontal",

		self:CreateTopLeftButtonPanel(),
		self:CreateInitiativeBar(self.tokenInfo),
		dmControlsPanel,
		layersPanel,
	}

	return self.topBarPanel
end

GameHud.instance = false

dmhub.CreateGameHud = function(dialog, tokenInfo)

	local gamehud = GameHud.new{
		dialog = dialog,
		tokenInfo = tokenInfo,
		openInventoryDialogs = {},
		interactionQueue = {},
	}

	GameHud.instance = gamehud

	gamehud.rollDialog = gamehud:CreateRollDialog()
	gamehud.rollOnTableDialog = gamehud:CreateRollOnTableDialog()

	gamehud.rollDialog.data.rollOnTableDialog = gamehud.rollOnTableDialog

	gamehud.inventoryDialog = gamehud:CreateInventoryDialog{
		rearrange = true, --the user can rearrange the items in the inventory by dragging it.
		equipment = true,
		currency = true,
		numRows = 6,
		numCols = 8,
		dialogWidth = 650,
	}
	gamehud.basicInventoryDialog = gamehud:CreateInventoryDialog{
		title = 'Available Items',
		basicInventory = true,
		tooltipAlign = 'right',
	}
	gamehud.basicInventoryDialog.x = 600

	gamehud.tradeInventoryDialog = gamehud:CreateInventoryDialog{
		title = 'Trade',
		tradeInventory = true,
		tooltipAlign = 'right',
		currency = true,
	}
	gamehud.tradeInventoryDialog.x = 600

	gamehud.createItemDialog = gamehud:CreateAddItemDialog{
		
	}

	local g_settingMapTooltips = setting{
		id = "maptooltips",
		default = true,
		storage = "preference",
	}

	local mainDialogPanel = gamehud:MainDialogPanel()

	mainDialogPanel:AddChild(gamehud.basicInventoryDialog)
	mainDialogPanel:AddChild(gamehud.tradeInventoryDialog)
	mainDialogPanel:AddChild(gamehud.inventoryDialog)

	mainDialogPanel:AddChild(gamehud.createItemDialog)

	local presentDialogDoc = mod:GetDocumentSnapshot("presentdialog")

	local m_tilelabel = nil
	local m_tiletooltip = nil

	--the dialog info that we have read from the cloud.
	local m_presentedDialog = nil
	local m_presentedDialogArgs = nil

	--the dialog info that we have written to the cloud.
	local m_presentDialogParentElement = nil
	local m_presentDialog = nil
	local m_presentDialogArgs = nil
	local m_presentDialogUpdateTime = nil

    local m_recordedPopup = nil

	local parentPanel = gui.Panel({
		styles = Styles.Default,
		selfStyle = {
			width = dialog.width,
			height = dialog.height,
		},
		thinkTime = 0.1,

		monitorGame = presentDialogDoc.path,

		events = {
			think = function(element)
				gamehud:Think()

				if m_presentDialog ~= nil and (m_presentDialogParentElement == nil or not m_presentDialogParentElement.valid) then
					element:FireEvent("clearPresentDialog")
				elseif m_presentDialog ~= nil and dmhub.Time() > m_presentDialogUpdateTime + 5 then
					local doc = mod:GetDocumentSnapshot("presentdialog")
					doc:BeginChange()
					doc.data.timestamp = ServerTimestamp()
					doc:CompleteChange("Refresh dialog timestamp")

					m_presentDialogUpdateTime = dmhub.Time()
				end

                m_recordedPopup = element.popup
			end,
			escape = function(element)
				gui.SetFocus(nil)
			end,

			--if this ends up as a host for popups it clears them if clicked.
			press = function(element)
				if element.popup ~= nil and element.popup == m_recordedPopup then
					element.popup = nil
				end
			end,

			presentDialog = function(element, parentElement, dialog, args)
				m_presentDialogParentElement = parentElement
				m_presentDialog = dialog
				m_presentDialogArgs = args

				local doc = mod:GetDocumentSnapshot("presentdialog")
				doc:BeginChange()
				doc.data.dialog = {dialog = dialog, args = args}
				doc.data.timestamp = ServerTimestamp()
				doc:CompleteChange("Present dialog")

				m_presentDialogUpdateTime = dmhub.Time()
			end,

			clearPresentDialog = function(element)
				m_presentDialog = nil
				m_presentDialogArgs = nil

				local doc = mod:GetDocumentSnapshot("presentdialog")
				doc:BeginChange()
				doc.data.dialog = nil
				doc:CompleteChange("Clear dialog")
			end,

			--update the presentDialogDoc.
			refreshGame = function(element)
				local doc = mod:GetDocumentSnapshot("presentdialog")
				
				local data = doc.data
				if TimestampAgeInSeconds(doc.timestamp) > 12 then
					data = {}
				end

				if m_presentedDialog ~= nil and m_presentedDialog.valid and (not dmhub.DeepEqual(m_presentedDialogArgs, data.dialog)) then
					m_presentedDialog:FireEventTree("closePanel")
					m_presentedDialog:DestroySelf()
					m_presentedDialog = nil
					m_presentedDialogArgs = nil
				end

				if (not dmhub.isDM) and data.dialog ~= nil then
					if m_presentedDialog ~= nil and m_presentedDialog.valid and dmhub.DeepEqual(m_presentedDialogArgs, data.dialog) then
						return
					end

					m_presentedDialogArgs = dmhub.DeepCopy(data.dialog)
					if LaunchablePanel.LaunchPanelByName(data.dialog.dialog, data.dialog.args) then
						m_presentedDialog = gui.GetFocus()
					end
				end

			end,

			refreshResolution = function(element)
				element.selfStyle.width = dialog.width
				element.selfStyle.height = dialog.height
			end,

			tiletooltip = function(element, args)
				if not g_settingMapTooltips:Get() then
					return
				end

				local loc = args.loc
				local text = args.text

				local halign = args.halign or 'right'
				local valign = args.valign or 'top'

				if m_tiletooltip ~= nil and m_tiletooltip == element.tooltip then
					m_tilelabel.text = text
					m_tiletooltip.selfStyle.halign = halign
					m_tiletooltip.selfStyle.valign = valign
					m_tiletooltip:FireEventTree("args", args)
					element:FloatTooltipNearTile(loc, m_tiletooltip)
					return
				end

				m_tilelabel = gui.Label{
							text = text,
							bgimage = 'panels/square.png',
							destroy = function(element)
								if m_tilelabel == element then
									m_tilelabel = nil
									m_tiletooltip = nil
								end
							end,
							styles = {
								{
									fontSize = '50%',
									color = 'white',
									width = 'auto',
									height = 'auto',
									maxWidth = 300,
								}
							},
						}
					
				
				local floorDeltaArrow = gui.Panel{
					styles = {
						{
							selectors = {"collapsed"},
							collapsed = 1,
						}
					},
					classes = {cond((args.floorDelta or 0) == 0, "collapsed")},
					width = 212*0.25,
					height = 217*0.25,
					bgimage = "ArrowUpLevel.webm",
					bgcolor = "white",
					scale = {x = 1, y = cond((args.floorDelta or 0) > 0, 1, -1)},
					args = function(element, args)
						element.selfStyle.scale = {x = 1, y = cond((args.floorDelta or 0) > 0, 1, -1)}
						element:SetClass("collapsed", (args.floorDelta or 0) == 0)
					end,
				}

				element:FloatTooltipNearTile(loc,
					gui.TooltipFrame(
						gui.Panel{
							flow = "horizontal",
							width = "auto",
							height = "auto",
							floorDeltaArrow,
							m_tilelabel,
						},
						{
							interactable = false,
							halign = halign,
							valign = valign,
						}
					)
				)

				m_tiletooltip = element.tooltip

			end,
		},

		children = {
			gamehud:CreateShapesLayer(),

			gamehud:RequireRollListenerPanel(),
			gamehud:CreateTopBar(),
			--gamehud:CreateSidePanel(),
			gamehud:CreateActionBar(dialog, tokenInfo),
			gamehud:CreateReactionBar(dialog, tokenInfo),
			gamehud:CreateDocumentsPanel(),
			--gamehud:CreateSessionsPanel(),
			--gamehud:CreateChatPanel(),
			gamehud:CreateFrozenLabel(),
			gamehud:CreateDocks(),
			mainDialogPanel,
			gamehud:ModalDialogPanel(),
			gamehud:CreatePopupPanel(),
			gamehud:CreateRollResultPanel(),
			gamehud.rollOnTableDialog,
			gamehud.rollDialog,

			FullscreenDisplay.Create(),

			gamehud:ConnectionStatusPanel(),
		}
	})

	gamehud.parentPanel = parentPanel

	dialog.sheet = parentPanel

	--if a modding merge has occurred, display info about it here.
	if dmhub.modMergeInfo ~= nil then
		local msg = 'DMHub has been updated, including some lua files which you have changed in your mod.'
		if dmhub.modMergeInfo.conflicts == nil then
			msg = msg .. ' Your changes have been automatically merged with the changes made in DMHub. Happy modding!'
		else
			msg = msg .. ' Unfortunately, we had some trouble automatically merging the changes in these file(s): '
			for i,fname in ipairs(dmhub.modMergeInfo.conflicts) do
				msg = msg .. fname .. ' '
			end

			msg = msg .. '\n\nPlease review these files to make sure everything is in proper order. You can search for the text CONFLICT IN CHANGES in these files to find areas where we had trouble merging the changes automatically. Happy modding!'
		end
		gamehud:ModalMessage{
			title = "Mod Merge",
			message = msg,
		}

		dmhub.ClearMergeInfo()
	end

	return gamehud
end

function GameHud.PresentDialogToUsers(parentElement, dialogid, args)
	GameHud.instance.parentPanel:FireEvent("presentDialog", parentElement, dialogid, args)
end

function GameHud:StatusText()
	return gui.Label{
		width = "100%",
		height = 20,
		textAlignment = "left",
		fontSize = 14,
		halign = "left",
		valign = "bottom",
		hmargin = 8,
		vmargin = 4,
		color = "white",
		text = "",

		thinkTime = 0.1,
		think = function(element)
			element.text = dmhub.status
		end,
	}
end

function GameHud.DicePanel()

	local CreateDice = function(faces)
		return gui.Panel{
			
			bgimage = "ui-icons/d" .. faces .. ".png",
			draggable = true,
			
			styles = {
				{
					bgcolor = "white",
					width = 16,
					height = 16,
					borderWidth = 0,
					cornerRadius = 0,
					valign = "center",
				},
				
				{
					selectors = {"hover"},
					bgcolor = "white",
					brightness = 5,
					transitionTime = 0.1,
					scale = 1.1,
					rotate = 0,
				},
				
				{
					selectors = {"press"},
					bgcolor = "#4d4d4d",
				},
			},
		
			events = {
				hover = gui.Tooltip{ text = string.format('D%d', faces), textAlignment = 'center', valign = 'top' },
				click = function(panel)
					dmhub.Roll{
						numDice = 1,
						numFaces = faces,
						description = "Custom Roll",
					}
				end,

				beginDrag = function(panel)
					dmhub.Debug('dragging dice')
					dmhub.DragDice(string.format('%dd%d', 1, faces))
				end,
			},
		}
	end

	return gui.Panel({
	
		bgimage = "panels/diceframe.png",
		
		selfStyle = {
			halign = "right",
			valign = "bottom",
		},
		
		styles = {
			{
				bgcolor = "white",
				cornerRadius = 5,
				pad = 5, 
				width = 200,
				height = 26,
				
				color = "red",
				valign = "bottom",
				halign = "center",
				flow = "horizontal",
				
			},
			
			{
				selectors = {"hover"},
				transitionTime = 0.5,
				
				borderColor = "white",
				brightness = 1,
			}
			
		},
		children = {
			CreateDice(4),
			CreateDice(6),
			CreateDice(8),
			CreateDice(10),
			CreateDice(12),
			CreateDice(20),
		}
	})
	
end

--panel that goes next to the initiative that has some DM controls such as a rest button and require roll button.
function GameHud:DMGameControlsPanel()

	if not dmhub.isDM then
		return gui.Panel{
			halign = "left",
			width = 1,
			height = 1,
		}
	end

	local dmIlluminationButton = gui.HudIconButton{
		icon = "icons/icon_device/icon_device_57.png",
		create = function(element)
			element:SetClass('deselected', not dmhub.GetSettingValue("dmillumination"))
		end,
		click = function(element)
			local hasIllumination = dmhub.GetSettingValue("dmillumination")
			dmhub.SetSettingValue("dmillumination", not hasIllumination)
			element:FireEventTree('create')

			if element.tooltip ~= nil then
				--redisplay tooltip with new setting.
				element:FireEvent('hover')
			end
		end,
		hover = function(element)
			gui.Tooltip(string.format('GM Darkvision: %s', cond(dmhub.GetSettingValue("dmillumination"), 'on', 'off')))(element)
		end,
	}

	local playerVisionOverlayButton = gui.HudIconButton{
		icon = "icons/icon_game/icon_game_193.png",
		create = function(element)
			element:SetClass('deselected', dmhub.GetSettingValue("showplayervision"))
		end,
		click = function(element)
			local hasOverlay = dmhub.GetSettingValue("showplayervision")
			dmhub.SetSettingValue("showplayervision", not hasOverlay)
			element:FireEventTree('create')

			if element.tooltip ~= nil then
				--redisplay tooltip with new setting.
				element:FireEvent('hover')
			end
		end,
		hover = function(element)
			gui.Tooltip(string.format('Player vision overlay: %s', cond(dmhub.GetSettingValue("showplayervision"), 'off', 'on')))(element)
		end
	}

	self.gameControlsPanel = gui.Panel{
		halign = 'left',
		valign = 'top',
		width = 'auto',
		height = 'auto',
		flow = 'horizontal',

		styles = {
			{
				selectors = {"dmonly", "player"},
				collapsed = 1,
			},
			{
				margin = 4,
				flow = 'horizontal',
			},
			{
				selectors = {'button'},
				priority = 10,
				width = 40,
				height = 40,
			},
			{
				selectors = {'button-icon'},
				width = '80%',
				height = '80%',
				bgcolor = 'white',
				halign = 'center',
				valign = 'center',
			},
		},

		--self:RestButton(),
		--self:RequireRollPanel(),
		dmIlluminationButton,
		playerVisionOverlayButton,
	}

	return gui.Panel{
		flow = "vertical",
		width = "auto",
		height = "auto",
		self.gameControlsPanel,
	}

end


function GameHud:CreatePopupPanel()
	self.popupPanel = gui.Panel{
		selfStyle = {
			width = "100%",
			height = "100%",
		}
	}

	return self.popupPanel
end

function GameHud:CreateFrozenLabel()

	local freezebind = dmhub.GetCommandBinding("togglefreeze")
	local bindtext = "(Players cannot move.)"
	if freezebind ~= nil and dmhub.isDM then
		bindtext = string.format("(Players cannot move. %s to toggle.)", freezebind)
	end


	self.freezeLabel = gui.Panel{
		id = "frozenLabel",
		halign = "center",
		valign = "bottom",
		flow = "vertical",
		height = "auto",
		width = "auto",

		styles = {
			{
				opacity = 0,
				y = 50,
			},
			{
				classes = {"frozen"},
				transitionTime = 0.2,
				opacity = 0.9,
				y = -110,
			},
		},

		monitorGame = "/frozen",
		refreshGame = function(element)
			element:SetClassTree("frozen", dmhub.frozen)
		end,

		press = function(element)
			dmhub.frozen = not dmhub.frozen
		end,
		gui.Label{
			text = "FROZEN",
			width = "auto",
			height = "auto",
			halign = "center",
@if MCDM
			fontFace = "Colvillain",
			fontSize = 48,
			fontWeight = "black",
			color = "white",
@else
			fontFace = "sellyoursoul",
			fontSize = 48,
			color = "#bbbbff",
			bold = true,
@end

		},
		gui.Label{
			text = bindtext,
			width = "auto",
			height = "auto",
			halign = "center",
@if MCDM
			uppercase = true,
			fontFace = "Colvillain",
			fontSize = 18,
			bold = false,
@else
			color = "#bbbbff",
			fontSize = 12,
			bold = true,
@end
		},
	}

	return self.freezeLabel
end


function GameHud:InspectDice()
	if self:try_get("inspectdice") ~= nil then
		self:CloseModal()
		self.inspectdice = nil
		return
	end

	self.inspectdice = gui.Panel{
		width = 1024,
		height = 1024,
		bgcolor = "white",
		bgimage = "#DicePreview",
		halign = "center",
		valign = "center",
	}

	self:ShowModal(self.inspectdice)
end

dmhub.ShowGameContextMenu = function(entries)
	gamehud.dialog.sheet.popupPositioning = "mouse"

	gamehud.dialog.sheet.popup = gui.ContextMenu{
		click = function()
			gamehud.dialog.sheet.popup = nil
		end,
		entries = entries,
	}
end