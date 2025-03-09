local mod = dmhub.GetModLoading()

RegisterGameType("InfoDocument")
RegisterGameType("InfoDocumentSection")

function InfoDocument.OnDeserialize(self)
	self:get_or_add("ord", 0)
end

function InfoDocument:AddSection()
	self.sections[#self.sections+1] = InfoDocumentSection.new{
		title = "Description",
		text = "",
	}
end

--called by DMHub to validate an info document is valid.
function IsValidInfoDocument(doc)
	return doc ~= nil and doc.typeName == "InfoDocument"
end

--called by DMHub to create an info document.
function CreateInfoDocument()
	local maxOrd = 1
	for k,p in pairs(dmhub.infoBubbles) do
		if p.document ~= nil and p.document.ord ~= nil and p.document.ord > maxOrd then
			maxOrd = p.document.ord
		end
	end
	return InfoDocument.new{
		ord = maxOrd+1,
		sections = {
			InfoDocumentSection.new{
				title = "Description",
				text = "",
			}
		}
	}
end

function GameHud:CreateDocumentsPanel()
	local result = gui.Panel{
		id = 'document-dialog-panel',
		bgimage = 'panels/square.png',
		interactable = false,

		styles = {
			{
				width = self.dialog.width,
				height = self.dialog.height,
				valign = 'center',
				halign = 'center',
				bgcolor = 'clear',
			},
			{
				selectors = {'document-dialog'},
				priority = 5,
				valign = 'top',
				halign = 'left',
				cornerRadius = 12,
				borderColor = 'black',
				borderWidth = 2,
				bgcolor = 'grey',
			},
		}
	}

	self.documentsPanel = result

	return result
end

function GameHud:CreateDocumentDialog()
	local dialogWidth = 500
	local dialogHeight = 600
	local resultPanel
	local mainPanel

	local currentInfo

	local leftPanelChildren = {}
	local leftPanel = gui.Panel{
		classes = {'left-panel'},
		vscroll = true,

		events = {
			refreshDocument = function(element, info)
				local children = {}

				local bubbles = dmhub.infoBubbles
				local bubblesSorted = {}

				for k,bubble in pairs(bubbles) do
					if bubble.document ~= nil then
						bubblesSorted[#bubblesSorted+1] = bubble
					end
				end

				table.sort(bubblesSorted, function(a,b)
					return a.document.ord < b.document.ord
				end)

				for i,bubble in ipairs(bubblesSorted) do
					local id = bubble.id
					local child = leftPanelChildren[bubble.id] or gui.Panel{
						bgimage = 'panels/square.png',
						classes = {'left-panel-child'},
						flow = "horizontal",

						gui.Label{
							classes = {'left-panel-child-bubble'},
							x = -4,
							text = bubble.icon,
							refreshDocument = function(element, info)
								element.text = bubble.icon
							end,
						},


						gui.Label{
							classes = {'left-panel-child-label'},
							text = bubble.description,
							refreshDocument = function(element, info)
								element.text = bubble.description
							end,
						},

						events = {
							click = function(element)
								resultPanel:FireEvent('refreshDocument', dmhub.infoBubbles[id])
							end,
						},
					}
					leftPanelChildren[bubble.id] = child
					children[#children+1] = child

					child:SetClass('selected', bubble.id == info.id)
				end

				element.children = children
			end,
		}
	}

	local title = gui.Label{
		bgimage = 'panels/square.png',
		editable = true,
		selfStyle = {
			fontSize = 20,
			color = 'white',
			bgcolor = 'clear',
			borderWidth = 0,

			width = 'auto',
			height = 'auto',
			halign = 'center',
			valign = 'top',
		},
		events = {
			refreshDocument = function(element, info)
				element.text = info.description
			end,
			change = function(element)
				currentInfo.description = element.text
				resultPanel:FireEventTree('refreshDocument', currentInfo)
			end,
		}
	}

	local bubbleIcon = gui.Label{
		bgimage = 'panels/square.png',
		characterLimit = 3,
		editable = true,
		selfStyle = {
			bgcolor = 'black',
			color = 'white',
			cornerRadius = '50% height',
			borderColor = 'white',
			borderWidth = 1,
			width = 25,
			height = 25,
			fontSize = 13,
			halign = "center",
			valign = "center",
			textAlignment = "center",
		},
		events = {
			refreshDocument = function(element, info)
				element.text = info.icon
			end,
			change = function(element)
				currentInfo.icon = element.text
			end,
		},
	}

	local lockIcon = gui.Panel{
		width = 16,
		height = 16,
		bgcolor = "white",
		selfStyle = {
			bgimage = "panels/square.png",
		},
		linger = gui.Tooltip("Unlock to allow dragging on the map"),
		refreshDocument = function(element, info)
			element.selfStyle.bgimage = cond(info.locked, 'icons/icon_tool/icon_tool_30.png', 'icons/icon_tool/icon_tool_30_unlocked.png')
		end,

		press = function(element)
			currentInfo.locked = not currentInfo.locked
			element:FireEvent("refreshDocument", currentInfo)
		end,
	}

	local titlePanel = gui.Panel{
		selfStyle = {
			flow = 'horizontal',
			width = 'auto',
			height = 'auto',
			pad = 0,
            tmargin = 4,
			valign = 'top',
		},
		children = {
			title,
			--padding.
			gui.Panel{
				width = 8,
				height = 8,
			},
			bubbleIcon,
			--padding.
			gui.Panel{
				width = 30,
				height = 8,
			},
			lockIcon,
		}
	}

	local addPanel = gui.Label{
		bgimage = 'panels/square.png',
		text = '+',
		classes = {'document-add'},
		events = {
			click = function(element)
				currentInfo:BeginChanges()
				currentInfo.document:AddSection()
				currentInfo:CompleteChanges('Add Info Bubble Section')
				resultPanel:FireEventTree('refreshDocument', currentInfo)
			end,
		},
	}

	local documentPanel = gui.Panel{
		bgimage = 'panels/square.png',
		classes = {'document-panel'},
		vscroll = true,
		events = {
			refreshDocument = function(element, info)
				local children = {}
				for i,entry in ipairs(info.document.sections) do
					local index = i
					children[#children+1] = gui.Panel{
						bgimage = 'panels/square.png',
						classes = {'document-entry'},
						children = {
							gui.Label{
								id = 'document-title',
								editable = true,
								classes = {'document-title'},
								text = entry.title,
								events = {
									change = function(element)
										info:BeginChanges()
										info.document.sections[index].title = element.text
										info:CompleteChanges("Update Info Bubble Title")
									end,
								},
							},
							gui.Input{
								classes = {'document-body'},
								text = entry.text,
								placeholderText = 'Enter info...',
								multiline = true,
								events = {
									change = function(element)
										info:BeginChanges()
										info.document.sections[index].text = element.text
										info:CompleteChanges("Update Info Bubble Text")
									end,
								},
							},
							gui.DeleteItemButton{
								floating = true,
                                width = 16,
                                rmargin = 4,
                                tmargin = 4,
                                height = 16,
                                halign = "right",
                                valign = "top",

								events = {
									click = function(element)
										info:BeginChanges()
										table.remove(info.document.sections, index)
										info:CompleteChanges("Remove Info Bubble Section")
										resultPanel:FireEvent('refreshDocument', dmhub.infoBubbles[currentInfo.id])
									end,
								},
							},
						},
					}
				end
				element.children = children
			end
		},
	}

	local mainInnerPanel = gui.Panel{
		classes = {'main-inner-panel'},
		children = {titlePanel, documentPanel},
	}

	mainPanel = gui.Panel{
		classes = {'main-panel'},
		children = {mainInnerPanel, addPanel},
	}

	local dialogPanel = gui.Panel{
		classes = {"framedPanel"},
		valign = 'top',
		halign = 'left',
		width = dialogWidth,
		height = dialogHeight,
		children = {
			leftPanel,
			mainPanel,

			gui.CloseButton{
				escapeActivates = true,
				valign = 'top',
				halign = 'right',
				events = {
					click = function(element)
						resultPanel:SetClass('hidden', true)
					end,
				},
			},

		},
	}

	resultPanel = gui.Panel{
		draggable = true,
		x = -dialogWidth/2,
		y = -dialogHeight/2,
		events = {
			drag = function(element)
				element.x = element.xdrag
				element.y = element.ydrag
			end,

			refreshDocument = function(element, info)
				if info ~= nil then
					currentInfo = info
				end

				if currentInfo == nil then
					return
				end
				leftPanel:FireEventTree('refreshDocument', currentInfo)
				mainPanel:FireEventTree('refreshDocument', currentInfo)
			end,
		},
		selfStyle = {
			halign = 'center',
			valign = 'center',
			width = 1,
			height = 1,
		},

		styles = {
			Styles.Default,
			Styles.Panel,
			{
				selectors = {'left-panel'},
				halign = 'left',
				height = '100%',
				valign = 'center',
				width = 220,
				x = -40,
				hmargin = 4,
				flow = 'vertical',
			},
			{
				selectors = {'left-panel-child-label'},
				halign = 'left',
				width = "98%-56",
				height = 22,
				hmargin = 6,
				valign = "center",
				fontSize = 16,
				minFontSize = 12,
				color = Styles.textColor,
				textAlignment = 'left',
			},
			{
				selectors = {'left-panel-child-bubble'},
				halign = "left",
				valign = "center",
				width = 48,
				height = 48,
				bgimage = "panels/square.png",
				bgcolor = "black",
				borderWidth = 2,
				borderColor = Styles.textColor,
				cornerRadius = 24,
				textAlignment = "center",
				fontFace = "CrimsonText",
				fontSize = 32,
			},
			{
				selectors = {'left-panel-child'},
				flow = "horizontal",
				halign = 'left',
				valign = 'top',
				lmargin = 8,
				tmargin = 24,
				width = '95%',
				height = 26,
				y = -6,
				cornerRadius = 2,
				borderWidth = 2,
				borderColor = Styles.textColor,
				bgcolor = '#00000000',
			},
			{
				selectors = {'left-panel-child', 'hover'},
			},
			{
				selectors = {'left-panel-child', 'selected'},
			},
			{
				selectors = {'main-inner-panel'},
				halign = "center",
				valign = "top",
				width = "100%-8",
				height = "100%-50",
				borderWidth = 2,
				borderColor = Styles.textColor,
				cornerRadius = 2,
				bgimage = "panels/square.png",
				bgcolor = "#00000000",
				flow = "vertical",
			},
			{
				selectors = {'main-panel'},
				flow = 'vertical',
				width = '100%-180',
				height = '100%-12',
				halign = 'right',
				valign = 'center',
			},
			{
				selectors = {'document-panel'},
				bgcolor = 'black',
				flow = 'vertical',
				width = '96%',
				height = '100%-70',
				valign = 'top',
				halign = 'center',
			},
			{
				selectors = {'document-entry'},
				bgcolor = 'black',
                borderWidth = 2,
                borderColor = Styles.textColor,
				vmargin = 8,
				color = 'white',
				cornerRadius = 0,
				flow = 'vertical',
				halign = 'center',
				valign = 'top',
				width = '92%',
				height = 'auto',
				minHeight = 30,
			},
			{
				selectors = {'document-add'},
				halign = "center",
				valign = 'top',
				bgcolor = 'black',
				color = Styles.textColor,
				cornerRadius = 2,
				borderWidth = 2,
				borderColor = Styles.textColor,
                tmargin = 8,
				width = '100%-8',
				height = 30,
				textAlignment = 'center',
				fontSize = 32,
			},
			{
				selectors = {'document-add', 'hover'},
				borderColor = '#ffffff',
			},
			{
				selectors = {'document-add', 'press'},
				borderColor = '#555555',
			},

			{
				selectors = {'document-title'},
				priority = 10,
				color = Styles.textColor,
				fontSize = 14,
				vmargin = 4,
				hmargin = 4,
				halign = 'left',
				width = '80%',
				height = 24,
			},
			{
				priority = 10,
				selectors = {'document-body'},
                borderWidth = 2,
                borderColor = Styles.textColor,
                color = Styles.textColor,
				vmargin = 4,
				width = '90%',
				height = 'auto',
				minHeight = 60,
				fontSize = 14,
				valign = 'center',
				halign = 'center',
				textAlignment = 'topleft',
			},
		},

		children = {
			dialogPanel,

			--resize panel.
			gui.Panel{
				bgimage = 'panels/dialog-handle.png',
				opacity = 0,
				draggable = true,
				swallowPress = true,
				x = dialogWidth-32,
				y = dialogHeight-32,
				hoverCursor = "diagonal-expand",
				dragBounds = { x1 = 100, y1 = -1000, x2 = 1000, y2 = -100 },
				styles = {
					{
						bgcolor = 'grey',
						width = 32,
						height = 32,
						valign = 'top',
						halign = 'left',
						cornerRadius = 8,
					},
					{
						selectors = {'hover'},
						brightness = 1.5,
					},
				},
				events = {
					dragging = function(element)
						dialogPanel.selfStyle.width = max(370, element.xdrag+32)
						dialogPanel.selfStyle.height = element.ydrag+32
					end,
					drag = function(element)
						element.x = element.xdrag
						element.y = element.ydrag
					end,
				},
			},
		}
	}

	return resultPanel
end

function GameHud:IsDocumentDialogOpen()
	local documentDialog = self:try_get('documentDialog')
	if documentDialog == nil then
		return false
	end

	return not documentDialog:HasClass('hidden')
end

local loadid = dmhub.GenerateGuid()

function GameHud:DisplayDocument(info)
	local documentDialog = self:try_get('documentDialog')
	if documentDialog == nil or loadid ~= self:try_get("documentDialogLoadID") then
		if documentDialog ~= nil then
			documentDialog:DestroySelf()
		end

		documentDialog = self:CreateDocumentDialog()
		self.documentDialogLoadID = loadid
		self.documentDialog = documentDialog
		self.documentsPanel.children = {documentDialog}
	else
		documentDialog:SetClass('hidden', not documentDialog:HasClass('hidden'))
	end

	if not documentDialog:HasClass('hidden') then
		documentDialog:FireEvent("refreshDocument", info)
	end
end

--called by dmhub when we need to refresh the info bubbles dialog.
function GameHud:RefreshInfoBubbles()
	local documentDialog = self:try_get('documentDialog')
	if documentDialog ~= nil and not documentDialog:HasClass('hidden') then
		--don't do this right now because updating while editing is very problematic.
		--though this means multiple DM's editing at the same time won't work so well.
		--documentDialog:FireEvent("refreshDocument")
	end
end

--show the tip for an info bubble
function GameHud:ShowInfoBubbleTip(info)

	local styles = {
		{
			selectors = {'heading'},
			fontSize = 30,
			color = 'white',
			textAlignment = 'left',
			width = '95%',
			height = 'auto',
			halign = 'center',
			valign = 'top',
		},
		{
			selectors = {'separator'},
			width = '96%',
			height = 2,
			halign  = 'center',
			bgcolor = '#ffffff99',
			vmargin = 4,
		},
		{
			selectors = {'title'},
			fontSize = 24,
			color = 'white',
			textAlignment = 'left',
			width = '95%',
			height = 'auto',
			halign = 'center',
		},
		{
			selectors = {'text'},
			fontSize = 14,
			color = 'white',
			textAlignment = 'left',
			width = '95%',
			height = 'auto',
			halign = 'center',
		},
	}

	local children = {}
	children[#children+1] = gui.Label{
		classes = {'heading'},
		text = info.description,
	}

	for i,section in ipairs(info.document.sections) do
		children[#children+1] = gui.Panel{
			bgimage = 'panels/square.png',
			classes = {'separator'},
		}
		children[#children+1] = gui.Label{
			classes = {'title'},
			text = section.title,
		}
		children[#children+1] = gui.Label{
			classes = {'text'},
			text = section.text,
		}
	end

	gamehud.popupPanel.popup = gui.Panel{
		interactable = false,
		bgimage = 'panels/square.png',
		selfStyle = {
			opacity = 1,
			bgcolor = 'black',
			borderWidth = 2,
			borderColor = 'white',
			width = 400,
			height = 'auto',
			flow = 'vertical',
			vpad = 4,
		},
		styles = styles,
		children = children,
	}

end

function GameHud:HideInfoBubbleTip(info)
	gamehud.popupPanel.popup = nil
end
