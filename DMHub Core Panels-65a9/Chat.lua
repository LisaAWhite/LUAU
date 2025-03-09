local mod = dmhub.GetModLoading()


local CreateChatPanel


DockablePanel.Register{
	name = "Chat",
	icon = mod.images.chatIcon,
	minHeight = 200,
	vscroll = false,
	content = function()
		return CreateChatPanel()
	end,
}

local CreateChatMessagePanel = function(message)
	local complete = false
	return gui.Label{
		classes = {'chat-message-panel'},
		markdown = true,
		text = message.formattedText,
		refreshMessage = function(element, message)
			if complete then
				return
			end

			element.text = message.formattedText
			if message.isComplete then
				complete = true
			end
		end
	}
end

local CreateDataMessagePanel = function(message)

	local renderPanel = message.data:Render({summary = true}, {})

	return gui.Panel{
		id = 'SharedObjectPanel',
		classes = {'chat-message-panel'},
		gui.Label{
			classes = {'chat-message-panel'},
			markdown = true,
			text = message.formattedText,
		},
		renderPanel,
	}
end

local CreateObjectMessagePanel = function(message)
	local objectInfo = nil
	local options = {
		summary = true,
	}
	local params = {}
	if message.properties ~= nil then
		objectInfo = message.properties.ability

		if message.properties.charid ~= nil then
			params.token = dmhub.GetTokenById(message.properties.charid)
		end
	end

	if message.tableid ~= nil and objectInfo == nil then
		local dataTable = dmhub.GetTable(message.tableid)
		objectInfo = dataTable[message.objectid]
	end

	local renderPanel = nil
	if objectInfo ~= nil then
		renderPanel = objectInfo:Render(options, params)
	end

	return gui.Panel{
		id = 'SharedObjectPanel',
		classes = {'chat-message-panel'},
		gui.Label{
			classes = {'chat-message-panel'},
			text = message.formattedText,
		},
		renderPanel,
	}
end

local CreateRollCategoryPanel = function(cat, catInfo)

	local headingLabel = nil
	if cat ~= 'default' then
		local text = cat
		
		--remove "magical" at the start of damage strings since it's too verbose.
		--Maybe later add an icon for it?
		if string.starts_with(text, "magical") then
			text = string.gsub(text, "magical ", "")
		end
		headingLabel = gui.Label{
			classes = {'roll-category-label'},
			text = text,
		}
	end

	local resultLabel = gui.Label{
		classes = {'roll-category-total'},
		text = tostring(catInfo.total),
		events = {
			showresult = function(element)
				element:SetClass("show", true)
			end,

			complete = function(element)
				element:SetClass('complete', true)
			end
		},
	}

	local rollsPanel = gui.Panel{
		classes = {'rolls-panel'},
	}

	local rollResultPanel = gui.Panel{
		classes = {'rolls-result-panel'},
		resultLabel,
		headingLabel,
	}

	local panelCache = {}

	return gui.Panel{
		classes = {'roll-category-panel'},
		children = {
			rollsPanel,
			rollResultPanel,
		},

		data = {
			addOutcomePanel = function(outcomePanel)
				rollResultPanel:AddChild(outcomePanel)
			end,
		},
		
		--see ChatPanel.cs GetRollInfo for structure of 'info'
		--diceStyle is from LuaInterface.cs GetDiceStyling().
		refreshInfo = function(element, info, diceStyle, complete)
			resultLabel.text = string.format("%d", math.tointeger(info.total))

			local newPanelCache = {}
			local children = {}
			for i,roll in ipairs(info.rolls) do

				--table of guid key -> face value to give the current value shown
				--for the dice. We display the sum of these.
				local dicefaces = {}

                local nfaces = roll.faces
                if nfaces == 3 then
                    nfaces = 6
                end

				local panel = panelCache[i] or gui.Panel{
					classes = {'single-roll-panel', cond(complete, 'complete', 'preview')},
					bgimage = string.format('ui-icons/d%d-filled.png', nfaces),
					saturation = 0.7,
					brightness = 0.4,
					bgcolor = diceStyle.bgcolor,
					events = {

					},

					gui.Label{
						classes = {'single-roll-panel', cond(complete, 'complete', 'preview')},
						bgimage = string.format('ui-icons/d%d.png', nfaces),
						bgcolor = diceStyle.trimcolor,
						color = diceStyle.color,

						settext = function(element, text)
							element.text = text
						end,

						create = function(element)
							if roll.guid ~= nil and roll.guid ~= '' then
								local events = chat.DiceEvents(roll.guid)
								if events ~= nil then
									events:Listen(element)
								end

								if roll.partnerguid ~= nil then
									events = chat.DiceEvents(roll.partnerguid)
									if events ~= nil then
										events:Listen(element)
									end
								end
							end
						end,


						complete = function(element)
							element.parent:SetClassTree('preview', false)
							element.parent:SetClassTree('complete', true)
						end,

						diceface = function(element, diceguid, num, timeRemaining)
							if element:HasClass('complete') == false then
								element:SetClassTree('preview', true)

								dicefaces[diceguid] = num

								--we sum all the dice faces for this roll. Usually this is just one die
								--and once face, but d100 can have multiple dice.
								local sum = 0
								for k,num in pairs(dicefaces) do
									sum = sum + num
								end
								element.text = tostring(math.tointeger(sum))
							end
						end,
					},
				}

				panel:SetClassTree("dropped", roll.dropped)
				panel:SetClassTree("best", roll.roll == roll.faces)
				panel:SetClassTree("worst", roll.roll == 1)
				local text = string.format("%d", math.tointeger(roll.roll))
				if roll.explodes then
					text = text .. '!'
				end
				if roll.multiply ~= nil and roll.multiply ~= 1 then
					text = string.format("<size=80%%>%s\n<size=50%%>x%s</size></size>", text, tostring(roll.multiply))
				end
				panel:FireEventTree("settext", text)

				newPanelCache[i] = panel
				children[#children+1] = panel
			end

			if info.mod then
				local panel = panelCache['mod'] or gui.Label{
					classes = {'single-roll-panel','complete'},
				}
				panel.text = ModifierStr(info.mod)
				newPanelCache['mod'] = panel
				children[#children+1] = panel
			end

@if MCDM
			if (info.boons or 0) >= 2 and (info.banes or 0) == 0 then
				children[#children+1] = panelCache['doubleboon'] or gui.Panel{
					width = 16,
					height = 16,
					valign = "center",
					bgimage = "panels/triangle.png",
					rotate = 180,
					bgcolor = "green",
					linger = function(element)
						gui.Tooltip("Double Edge -- +Tier")(element)
					end,
				}

				newPanelCache['doubleboon'] = children[#children]
			end

			if (info.banes or 0) >= 2 and (info.boons or 0) == 0 then
				children[#children+1] = panelCache['doublebane'] or gui.Panel{
					width = 16,
					height = 16,
					valign = "center",
					bgimage = "panels/triangle.png",
					bgcolor = "red",
					linger = function(element)
						gui.Tooltip("Double Bane -- -Tier")(element)
					end,
				}

				newPanelCache['doublebane'] = children[#children]
			end

@end

			rollsPanel.children = children
			panelCache = newPanelCache
		end,
	}
end

local CreateRollMessagePanel = function(message)

	local visibilityPanel = gui.VisibilityPanel{
		visible = not message.gmonly,
		hmargin = 6,
		x = 20,
		hover = function(element)
			local message
			if element:HasClass("visible") then
				message = "Visible to everyone"
			else
				message = "Visible only to the player who rolled and the GM"
			end
			gui.Tooltip(message)(element)
		end,
	}
	local headingLabel = gui.Label{
		classes = {'chat-message-panel'},
		width = "94%",
		visibilityPanel,
	}
	local paddingPanel = gui.Panel{
		classes = {'roll-message-padding'},
	}

	local outcomePanel = nil
	local outcomePanelAdded = false

	if message.forcedResult or (message.properties ~= nil and message.properties.typeName == "RollProperties" and message.properties:HasOutcomes()) then
		outcomePanel = gui.Label{
			classes = {'roll-message-outcome', 'hidden', 'appear'},
			text = ' ',
		}
	end

	local customPanel = nil

	if message.properties ~= nil then
		customPanel = message.properties:CustomPanel(message)
	end

	local longFormResultsLabel = gui.Label{
		classes = {"long-form-message-outcome"},
	}

	local catPanels = {}

	local complete = false
	local panel = gui.Panel{
		classes = {'roll-main-panel'},
		refreshMessage = function(element, message)
			visibilityPanel:SetClass("visible", not message.gmonly)

			if complete then
				--we already have this message and it was complete already so don't bother updating.
				return
			end

			headingLabel.text = message.formattedText

			local newCatPanels = {}

			local complete = message.isComplete
			local info = message.resultInfo
			local diceStyle = message.diceStyle

			local children = {headingLabel}

			if outcomePanel ~= nil and message.properties ~= nil then
				local outcome = message.properties:GetOutcome(message)
				if outcome ~= nil and #outcome.outcome < 14 then
					outcomePanel.selfStyle.color = outcome.color or "white"
					outcomePanel.text = outcome.outcome
				elseif outcome ~= nil then
					longFormResultsLabel.text = outcome.outcome
				end
			elseif outcomePanel ~= nil and message.autofailure then
				outcomePanel.selfStyle.color = "red"
				outcomePanel.text = "Failure"
			elseif outcomePanel ~= nil and message.autosuccess then
				outcomePanel.selfStyle.color = "green"
				outcomePanel.text = "Success"
			end

			for cat,catInfo in pairs(info) do

				local catPanel = catPanels[cat] or CreateRollCategoryPanel(cat, catInfo)
				catPanel:FireEvent('refreshInfo', catInfo, diceStyle, complete, message)

				if customPanel ~= nil then
					customPanel:FireEvent("refreshInfo", catInfo, diceStyle, complete, message)
				end

				newCatPanels[cat] = catPanel

				children[#children+1] = catPanel

				if outcomePanel ~= nil and not outcomePanelAdded then
					catPanel.data.addOutcomePanel(outcomePanel)
					outcomePanelAdded = true
				end
			end

			if outcomePanel ~= nil and not outcomePanelAdded then
				children[#children+1] = outcomePanel
			end

			children[#children+1] = paddingPanel

			catPanels = newCatPanels
			element.children = children

			element:SetClass('complete', message.isComplete)

			if message.isComplete then
				complete = true
				element:FireEventTree('complete')
				if outcomePanel ~= nil then
					outcomePanel:SetClass('hidden', false)
					outcomePanel:SetClass('appear', false)
				end
			end
		end,

		headingLabel,
	}

	local avatar = nil

	local avatarPanel = gui.Panel{
		classes = {'roll-avatar-panel'},

		refreshMessage = function(element, message)
			if avatar == nil and message.tokenid ~= nil then
				local token = dmhub.GetCharacterById(message.tokenid)
				if token ~= nil then
					avatar = gui.CreateTokenImage(token, {
						width = 48,
						height = 48,
						valign = "center",
						halign = "center",
					})

					element:AddChild(avatar)

					local name = token:GetNameMaxLength(12)
					if name ~= nil and name ~= "" and token.canLocalPlayerSeeName then
						element:AddChild(gui.Label{
							text = name,
							fontSize = 14,
							color = message.nickColor,
							width = "auto",
							height = "auto",
							halign = "center",
							maxWidth = 60,
							textWrap = false,
						})
					end
				end
			end
		end
	}


	local currentMessage = nil

	local chatMessagePanel = gui.Panel{
		classes = {"chat-message-panel"},
		bgimage = "panels/square.png",
		bgcolor = "clear",
		flow = "vertical",
		linger = function(element)
			if currentMessage == nil or visibilityPanel.tooltip ~= nil then
				return
			end
			gui.Tooltip{
				maxWidth = 500,
				text = string.format("%s = %d\nRolled by %s %s", currentMessage.rollStr, currentMessage.total, currentMessage.playerName, DescribeServerTimestamp(currentMessage.timestamp)),
			}(element)
		end,
		refreshMessage = function(element, message)
			currentMessage = message
			panel:FireEvent("refreshMessage", message)
			avatarPanel:FireEventTree("refreshMessage", message)
		end,

		gui.Panel{
			classes = {'separator'},
		},

		gui.Panel{
			classes = {'chat-message-panel', 'roll-message-panel'},
			gui.Panel{
				width = "100%",
				height = "auto",
				flow = "horizontal",
				vmargin = 0,
				hmargin = 0,
				avatarPanel,
				panel,
			},

			--force the result to show even if it's not complete yet. Useful to allow the user to see it and able to modify it.
			forceShowResult = function(element)
				element:FireEventTree("showresult")
			end,

			longFormResultsLabel,
			customPanel,
		},

	}

	return chatMessagePanel
end

local rightClickHandler = function(element)
	if dmhub.isDM then
		local gmonly = element.data.message.gmonly
		element.popup = gui.ContextMenu{
			entries = {
				{
					text = "Delete Message",
					click = function()
						element.data.message:Delete()
						element.popup = nil
					end,
				},

--				{
--					text = cond(gmonly, "Reveal to players", "Hide from players"),
--					click = function()
--						element.data.message.gmonly = not gmonly
--						element.popup = nil
--					end,
--				}
			}
		}
	end
end

local CreateSingleChatPanel = function(message)
	local result = nil
	if message.messageType == 'roll' then
		result = CreateRollMessagePanel(message)
	elseif message.messageType == 'object' then
		result = CreateObjectMessagePanel(message)
	elseif message.messageType == "data" then
		result = CreateDataMessagePanel(message)
	else
		result = CreateChatMessagePanel(message)
	end

	if result ~= nil then
		result.data.message = message
		if result.events == nil then
			result.events = {}
		end
		result.events.rightClick = rightClickHandler
	end

	return result
end

CreateChatPanel = function()

	local children = {}
	local messagePanels = {}

	local chatPanel = gui.Panel{
		id = 'chat-panel',
		vscroll = true,
		hideObjectsOutOfScroll = true,
		hpad = 6,
		height = "100% available",


		styles = {
			{
				bgcolor = 'black',
				halign = 'center',
				valign = 'bottom',
				width = "100%",
				flow = 'vertical',
			},

			{
				selectors = 'separator',
				bgimage = 'panels/square.png',
				width = '96%',
				height = 1,
				vmargin = 4,
				bgcolor = Styles.textColor,
				gradient = Styles.horizontalGradient,
			},
			{
				selectors = {'visibilityPanel'},
				halign = "right",
				valign = "center",
			},

			{
				selectors = {'chat-message-panel'},
				textAlignment = 'topleft',
				halign = 'left',
				width = '100%',
				height = 'auto',
				color = 'white',
				fontSize = '40%',
				vmargin = 2,
			},

			{
				selectors = {'chat-message-panel', 'roll-message-panel'},
				flow = 'vertical',
			},
			{
				selectors = {'roll-avatar-panel'},
				flow = 'vertical',
				width = "14%",
				height = "auto",
				halign = "left",
				valign = "center",
			},
			{
				selectors = {'roll-main-panel'},
				flow = 'vertical',
				width = "80%",
				height = "auto",
				halign = "right",
			},
			{
				selectors = {'roll-message-outcome'},
				color = 'white',
				fontSize = 18,
				minFontSize = 10,
				halign = 'center',
				valign = 'bottom',
				width = 'auto',
				height = 'auto',
				maxWidth = 70,
			},
			{
				selectors = {'roll-message-outcome', 'appear'},
				scale = 3,
				opacity = 0,
				transitionTime = 0.25,
			},
			{
				selectors = {'long-form-message-outcome'},
				fontSize = 14,
				color = "white",
				width = "100%",
				height = "auto",
			},
			{
				selectors = {'roll-message-padding'},
				width = '100%',
				height = 8,
			},
			{
				selectors = {'rolls-panel'},
				width = '60%',
				height = 'auto',
				valign = "center",
				flow = 'horizontal',
				wrap = true,
			},
			{
				selectors = {'roll-category-label'},
				halign = 'center',
				valign = 'top',
				width = 'auto',
				height = 'auto',
				maxWidth = 64,
				fontSize = 18,
				minFontSize = 8,
				color = 'white',
			},
			{
				selectors = {'roll-category-total'},
				width = 'auto',
				height = 'auto',
				halign = 'center',
				valign = 'bottom',
				bold = true,
				fontSize = 28,
				color = 'clear',
				scale = 3,
			},
			{
				selectors = {'roll-category-total', 'show'},
				scale = 1,
				color = '#ffffff55',
			},
			{
				selectors = {'roll-category-total', 'complete'},
				transitionTime = 0.25,
				scale = 1,
				color = 'white',
			},
			{
				selectors = {'rolls-result-panel'},
				valign = "center",
				width = "25%",
				height = "auto",
				halign = "right",
				flow = "vertical",
			},
			{
				selectors = {'roll-category-panel'},
				flow = 'horizontal',
				width = '100%',
				height = 'auto',
			},
			{
				selectors = {'single-roll-panel'},
				halign = 'left',
				textAlignment = 'center',
				textWrap = false,
				textOverflow = "overflow",
				fontSize = 24,
				color = 'clear',
				bgcolor = '#cccccc',
				bold = true,
				width = 40,
				height = 40,
			},
			{
				selectors = {'single-roll-panel','complete'},
				color = 'white',
			},
			{
				selectors = {'single-roll-panel','complete','best'},
				color = '#aaffaa',
			},
			{
				selectors = {'single-roll-panel','complete','worst'},
				color = '#ffaaaa',
			},
			{
				selectors = {'single-roll-panel','complete','dropped'},
				opacity = 0.3,
			},
			{
				selectors = {'single-roll-panel','label','preview'},
				opacity = 0.6,
			},
		},

		events = {
			create = 'refreshChat',
			refreshChat = function(element)
				local newMessagePanels = {}
				local children = {}
				local newMessage = false
				for i,message in ipairs(chat.messages) do
					newMessage = (messagePanels[message.key] == nil)
					local child = messagePanels[message.key] or CreateSingleChatPanel(message)
					newMessagePanels[message.key] = child
					child:FireEvent('refreshMessage', message)
					children[#children+1] = child
				end

				messagePanels = newMessagePanels
				element.children = children

				--go to the bottom if we have new messages
				if newMessage then
					element.vscrollPosition = 0
					element:ScheduleEvent("moveToBottom", 0.05)
				end
			end,

			moveToBottomNowAndDelayed = function(element)
				element:FireEvent("moveToBottom")
				element:ScheduleEvent("moveToBottom", 0.05)
			end,

			moveToBottom = function(element)
				element.vscrollPosition = 0
			end,
		},
	}

	chat.events:Listen(chatPanel)

	local history = {}
	local historyCursor = nil

	local completionChildren = {}
	local EscapeCompletions = nil
	local completionsPanel = gui.Panel{
		floating = true,

		y = -32,
		selfStyle = {
			halign = 'left',
			valign = 'bottom',
		},

		style = {
			width = 200,
			height = 'auto',
			flow = 'vertical',
		},
		children = {
		},

		events = {
			escape = function(element)
				EscapeCompletions()
			end,
		},
	}

	local completionChildrenStyles = {
		gui.Style{
			bgcolor = '#82231DFF',
			width = '100%',
			height = 20,
			fontSize = '40%',
			color = 'white',
			halign = 'left',
			valign = 'top',
			flow = 'none',
		},
		gui.Style{
			selectors = 'hover',
			transitionTime = 0.1,
			brightness = 1.5,
		},
		gui.Style{
			selectors = 'pressed',
			transitionTime = 0.1,
			brightness = 1.2,
		},
		gui.Style{
			selectors = 'selected',
			transitionTime = 0.1,
			brightness = 1.5,
		},
	}

	local previewPanel = nil
	local inputPanel = nil

	local UpdateCompletions = nil
	UpdateCompletions = function(txt)
		local items = chat.GetCommandCompletions(txt or inputPanel.text) or {}
		while #completionChildren < #items do
			completionChildren[#completionChildren+1] = gui.Label{
				bgimage = 'panels/square.png',
				text = '',
				styles = completionChildrenStyles,
				events = {
					click = function(element)
						inputPanel.text = element.text .. ' '
						inputPanel.caretPosition = string.len(inputPanel.text)
						inputPanel.hasFocus = true
					end,
				},
			}
		end

		for i,element in ipairs(completionChildren) do
			element:SetClass('selected', false)
			if i <= #items then
				element.text = items[i]
				element:SetClass('collapsed', false)
			else
				element:SetClass('collapsed', true)
			end
		end

		completionsPanel.children = completionChildren
	end

	local CompletionsArrow = function(arrow)
		local startIndex = 1
		local endIndex = #completionChildren
		local delta = 1
		if arrow == 'down' then
			startIndex = #completionChildren
			endIndex = 1
			delta = -1
		end

		local ntarget = nil
		local stop = false
		for i = startIndex, endIndex, delta do
			local child = completionChildren[i]
			if child:HasClass('selected') and child:HasClass('collapsed') == false then
				child:SetClass('selected', false)
				stop = true
			elseif child:HasClass('collapsed') == false and stop == false then
				ntarget = i
			end
		end

		if ntarget then
			completionChildren[ntarget]:SetClass('selected', true)
			return true
		end

		return false
	end

	local GetAndClearCompletionSelected = function()
		for i,child in ipairs(completionChildren) do
			if child:HasClass('selected') and child:HasClass('collapsed') == false then
				child:SetClass('selected', false)
				return child.text
			end
		end

		return nil
	end

	EscapeCompletions = function()
		inputPanel.hasFocus = true
	end

	local userChatMessages = {}

	previewPanel = gui.Label{
		width = 330,
		height = 18,
		text = "preview text",
		fontSize = 14,
		italics = true,
		monitorGame = mod:GetDocumentSnapshot("chatEvents").path,
		thinkTime = 0.4,

		data = {
			ellipsis = "",
			firstThink = true,
		},

		refreshGame = function(element)
			element:FireEvent("think", true)
		end,

		think = function(element, artificial)
			local doc = mod:GetDocumentSnapshot("chatEvents")

			local newChatMessages = {}

			for userid,info in pairs(doc.data) do
				local existingInfo = userChatMessages[userid]
				if existingInfo == nil or existingInfo.guid ~= info.guid then
					newChatMessages[userid] = {
						guid = info.guid,
						time = cond(element.data.firstThink, -5, dmhub.Time()),
					}
				else
					newChatMessages[userid] = existingInfo
				end
			end

			userChatMessages = newChatMessages

			local users = {}
			for userid,info in pairs(userChatMessages) do
				if userid ~= dmhub.loginUserid and info.time > dmhub.Time()-5 then
					local name = dmhub.GetDisplayName(userid)
					users[#users+1] = name
				end
			end

			table.sort(users)
			if #users == 0 then
				element.text = ""
				element.data.ellipsis = ""
			else
				if not artificial then
					if #element.data.ellipsis < 3 then
						element.data.ellipsis = element.data.ellipsis .. "."
					else
						element.data.ellipsis = ""
					end
				end
				local names = pretty_join_list(users)
				element.text = string.format("%s %s typing%s", names, cond(#users == 1, "is", "are"), element.data.ellipsis)
			end

			element.data.firstThink = false
		end,

	}

	local chatRealTimeUpdateTime = 0

	inputPanel = gui.Input{
		placeholderText = 'Enter Chat...',
		width = 330,
        minHeight = 24,
        maxHeight = 300,
		height = "auto",
		lineType = "MultiLineSubmit",
		characterLimit = 4096,
		events = {
			deselect = function(element)
				--UpdateCompletions('')
			end,
			tab = function(element)
				local items = chat.GetCommandCompletions(inputPanel.text)
				if #items == 1 then
					inputPanel.text = items[1] .. ' '
					inputPanel.caretPosition = string.len(inputPanel.text)
					UpdateCompletions()
					element.hasFocus = true
				end
			end,
			uparrow = function(element)
				if CompletionsArrow('up') then
					return
				end

				if #history == 0 then
					return
				end

				if historyCursor == nil then
					historyCursor = #history
				else
					historyCursor = historyCursor - 1
					if historyCursor < 1 then
						historyCursor = #history
					end
				end

				element.text = history[historyCursor]
				element.caretPosition = element.text:len()
				element.selectionAnchorPosition = 0

				UpdateCompletions()
			end,
			downarrow = function(element)
				if CompletionsArrow('down') then
					return
				end

				if #history == 0  or historyCursor == nil then
					return
				end

				historyCursor = historyCursor+1
				if historyCursor > #history then
					historyCursor = 1
				end

				element.text = history[historyCursor]
				element.caretPosition = element.text:len()
				element.selectionAnchorPosition = 0

				UpdateCompletions()
			end,
			edit = function(element)
				if historyCursor ~= nil and element.text ~= history[historyCursor] then
					historyCursor = nil
				end
				chat.PreviewChat(element.text)

				UpdateCompletions()

				--send real time updates here.
				if element.text == "" or string.starts_with(element.text, "/") then

					local doc = mod:GetDocumentSnapshot("chatEvents")
					if doc.data[dmhub.loginUserid] ~= nil then
						doc:BeginChange()
						doc.data[dmhub.loginUserid] = nil
						doc:CompleteChange("Preview chat", {undoable = false})
					end

				elseif dmhub.Time() > chatRealTimeUpdateTime + 1 then
					local doc = mod:GetDocumentSnapshot("chatEvents")
					doc:BeginChange()
					doc.data[dmhub.loginUserid] = {
						guid = dmhub.GenerateGuid(),
					}
					doc:CompleteChange("Preview chat", {undoable = false})

					chatRealTimeUpdateTime = dmhub.Time()
				end
			end,
			submit = function(element)

				local completionText = GetAndClearCompletionSelected()
				if completionText ~= nil then
					element.text = completionText .. ' '
					element.hasFocus = true
					element.caretPosition = string.len(element.text)
					return
				end

				local doc = mod:GetDocumentSnapshot("chatEvents")
				if doc.data[dmhub.loginUserid] ~= nil then
					doc:BeginChange()
					doc.data[dmhub.loginUserid] = nil
					doc:CompleteChange("Preview chat", {undoable = false})
				end

				chat.Send(element.text)

				historyCursor = -1

				if element.text ~= '' and history[#history] ~= element.text then
					history[#history+1] = element.text
				end

				element.text = ''

				element.hasFocus = true
				chat.PreviewChat('')

				UpdateCompletions()
			end,
			sendchat = function(element)
				--this includes a chat being sent by rolling dice.
				--Does not include executing a command.
			end,
			slash = function(element)
				element.hasFocus = true
				element.text = '/'
				element.caretPosition = 1
				element.selectionAnchorPosition = nil
				chat.PreviewChat('/')

				UpdateCompletions()
			end,
		},
	}

	chat.events:Listen(inputPanel)

	local resultPanel = gui.Panel{
		selfStyle = {
			width = '100%',
			height = '100%',
			flow = 'vertical',
		},
		children = {
			chatPanel,
			previewPanel,
			inputPanel,
			completionsPanel,
		}
	}

	return resultPanel
end

