local mod = dmhub.GetModLoading()

local playersControlInitiativeSetting = setting{
	id = "permission:playersinitiative",
	description = "Players can control initiative",
	editor = "check",
	default = true,

	storage = "game",
	section = "game",
	classes = {"dmonly"},
}

local CanControlInitiative = function()
	return dmhub.isDM or playersControlInitiativeSetting:Get()
end

--Functions which control the GameHud's handling of the initiative bar.
--This drives the display of the initiative bar at the top of the screen.

--the card width as a percentage of the height
local CardWidthPercent = 78

local function AddInitiativeEntryPanel (element, info, playerControlled)
	local parentElement = element
	local tokens = dmhub.GetTokens{
		playerControlled = playerControlled
	}

	local count = 0
	local entries = {}

	for _,tok in ipairs(tokens) do
		local initiativeId = InitiativeQueue.GetInitiativeId(tok)
		if info.initiativeQueue ~= nil and not info.initiativeQueue:HasInitiative(initiativeId) then
			if entries[initiativeId] == nil then
				count = count + 1
			end
			entries[initiativeId] = entries[initiativeId] or {}
			local list = entries[initiativeId]
			list[#list+1] = tok
		end
	end

	if count > 0 then
		local allKey = {}
		local allTokens = {}
		for key,list in pairs(entries) do
			allKey[#allKey+1] = key
			for _,item in ipairs(list) do
				allTokens[#allTokens+1] = item
			end
		end

		entries[allKey] = allTokens

	end

	local panels = {}

	for key,list in pairs(entries) do

		local ord = 0

		local tok = list[1]
		local text = tok.name
		if (text == nil or text == "") and tok.properties:GetMonsterType() ~= nil then
			text = tok.properties:GetMonsterType()
		end

		if text == nil or text == "" then
			text = "Unnamed Token"
		end

		if type(key) == "table" then
			text = "All"
			ord = -1
		end

		local tokens = {}
		for i,tok in ipairs(list) do
			tokens[#tokens+1] = gui.CreateTokenImage(tok, {
				width = 32,
				height = 32,
				x = (i-1)*48 / #list,
				halign = "left",
				valign = "center",
				floating = true,
			})
		end

		local panel = gui.Panel{
			classes = {"entryPanel"},
			bgimage = "panels/square.png",
			data = {
				ord = ord,
			},
			click = function(element)
                print("SetInitiative::")
				if type(key) == "table" then
					for _,k in ipairs(key) do
						info.initiativeQueue:SetInitiative(k, 0, 0)
					end
				else
					info.initiativeQueue:SetInitiative(key, 0, 0)
				end
				info.UploadInitiative()

				parentElement.popup = nil
			end,
			gui.Panel{
				flow = "horizontal",
				width = 24 + 48,
				height = 32,
				valign = "center",
				children = tokens,
				halign = "left",
			},
			gui.Label{
				width = 180,
				height = 32,
				fontSize = 16,
				halign = "left",
				valign = "center",
				textAlignment = "left",
				text = text,
				color = Styles.textColor,
			}
		}

		panels[#panels+1] = panel
	end

	table.sort(panels, function(a,b)
		return a.data.ord < b.data.ord
	end)

	if #panels == 0 then
		panels[#panels+1] = gui.Label{
			text = "No entries",
			width = "auto",
			height = "auto",
			color = Styles.textColor,
			fontSize = 16,
		}
	end

	element.popup = gui.TooltipFrame(
		gui.Panel{
			styles = {
				Styles.Default,

				{
					selectors = {"entryPanel"},
					flow = "horizontal",
					height = 48,
					width = "100%",
					bgcolor = "clear",
				},
				{
					selectors = {"entryPanel", "hover"},
					bgcolor = "#ff444466",
				},
			},

			vscroll = true,
			flow = "vertical",
			width = 300,
			height = "auto",
			maxHeight = 600,

			children = panels,
		},

		{
			halign = "center",
			valign = "bottom",
		}
	)
end

--Create the initiative bar.
--   self: the GameHud object
--   info: the dmhub info object which gives us access to important game information. Some parameters we use here:
--      info.initiativeQueue: this is the initiative queue data. See initiative-queue.lua for the definition of this object. It is
--                            networked between systems.
--      info.UploadInitiative(): Whenever we change info.initiativeQueue we must call this to ensure that initiativeQueue gets networked.
--      info.tokens: This contains a table of tokens currently in the game. We scan this to check that we can see tokens and should show their initiative.
--      info.selectedOrPrimaryTokens: This contains a table of tokens that are selected, which we use to choose which tokens to roll dice for.
function GameHud.CreateInitiativeBar(self, info)

	self.initiativeInterface = info

	local mainInitiativeBar = nil
	local choiceInitiativeBar = nil

	--The label we display instructing the DM to click to start tracking initiative. Only shows up when the DM is hovering over the initiative bar.
	local clickLabel = gui.Label({
				id = 'initiative-click-prompt',
				text = 'Click to start tracking initiative',

				events = {
					refresh = function(element)
						element:SetClass('hidden', info.initiativeQueue ~= nil and info.initiativeQueue.hidden == false)
					end,
				},

				selfStyle = {
					fontSize = '40%',
					color = '#ccccbb',
					valign = 'bottom',
					halign = 'center',
					vmargin = 12,
					textAlignment = 'center',
					width = 'auto',
					height = 'auto',
				},

				styles = {
					{
						opacity = 0,
					},
					{
						selectors = {'hover-initiative'},
						opacity = 1,
						transitionTime = 0.2,
					}
				}
			})

	choiceInitiativeBar = self:CreateInitiativeBarChoicePanel(info)
	self.choiceInitiativeBar = choiceInitiativeBar

	local addCharacters
	local addMonsters

	if dmhub.isDM then

		addCharacters = gui.AddButton{
			halign = "left",
			valign = "center",
			floating = true,
			x = -60,
			width = 24,
			height = 24,
			hover = gui.Tooltip("Add Character to initiative"),
			click = function(element)
				AddInitiativeEntryPanel(element, info, true)
			end,
		}

		addMonsters = gui.AddButton{
			halign = "right",
			valign = "center",
			floating = true,
			x = 60,
			width = 24,
			height = 24,
			hover = gui.Tooltip("Add Monster to initiative"),
			click = function(element)
				AddInitiativeEntryPanel(element, info, false)
			end,
		}
	end

	--The parent / top-level initiative bar.
	return gui.Panel({
		floating = true,
		selfStyle = {
			valign = 'top',
			halign = 'center',
		},

		className = 'initiative-panel',

		styles = {
			{
				width = 600,
				height = 120,
				bgcolor = 'white',
			},
			{
				selectors = {'initiative-panel'},
				inherit_selectors = true,
				bgcolor = 'black',
			},
			{
				selectors = { 'initiative-panel', 'no-initiative' },
				y = -300,
				transitionTime = 0.5,
			},

			--make it so the close button on child panels are on the right, unless
			--the panel is on the left side of the carousel in which case it goes on the left.
			{
				selectors = {'close-button'},
				priority = 5,
				halign = "right",
			},

			{
				selectors = {'close-button', 'parent:hadTurn'},
				priority = 5,
				halign = "left",
			},

			{
				selectors = {'initiativeArrow'},
				bgimage = "panels/initiative-arrow.png",
				bgcolor = "white",
				y = -40,
				width = 63,
				height = 45,
				valign = "top",
				opacity = 0,
				hidden = 1,
			},
			{
				selectors = {'initiativeArrow', 'parent:turn'},
				y = 10,
				transitionTime = 0.3,
				opacity = 1,
				hidden = 0,
			},

			{
				selectors = {"initiativeEntryPanel"},
				height = "100%",
				width = tostring(CardWidthPercent) .. "% height",
				valign = 'top',
				halign = 'center',
				flow = 'none',

				--make it so when the initiative queue is recalculated, entries will slide along into place over time
				--rather than instantly jumping to their new location.
				moveTime = 0.5,
			},
			{
				selectors = {"initiativeEntryBackground"},
				width = "100%+32",
				height = "100%+32",
				valign = "center",
				halign = "center",
				borderWidth = 16,
				borderColor = "#000000aa",
				borderFade = true,
			},
			{
				selectors = {"initiativeEntryBorder"},
				bgcolor = "clear",
				width = "100%",
				height = "100%",
				border = 2,
				borderColor = Styles.textColor,
				opacity = 1,
			},
			{
				selectors = {"initiativeEntryBorder", "parent:turn"},
				brightness = 3,
				transitionTime = 0.5,
			},
			{
				selectors = {"initiativeEntryBorder", "parent:hadTurn"},
				brightness = 0.3,
				transitionTime = 0.5,
			},

		},

		events = {

			--when we hover/dehover make sure the prompt label is shown or not.
			hover = function(element)
				clickLabel:SetClass('hover-initiative', true)
			end,

			dehover = function(element)
				clickLabel:SetClass('hover-initiative', false)
			end,

			refresh = function(element)
				--detect if we are using initiative. If we aren't, then hide the initiative bar completely for players
				--and simply show a slither of it for the DM so they can click on it to activate initiative.
				element:SetClass('no-initiative', info.initiativeQueue == nil or info.initiativeQueue.hidden)
				element:SetClass('hidden', element:HasClass('no-initiative'))
			end,

			click = function(element)
				--when clicked, if initiative isn't active, initialize the initiative queue.
				--This means creating it in the game document and then uploading it. This will cause all
				--players to now see the initiative queue.
				if info.initiativeQueue == nil or info.initiativeQueue.hidden then
					UploadDayNightInfo()
					info.initiativeQueue = InitiativeQueue.Create()
					info.UploadInitiative()
				end
			end,
		},

		children = {
			--background shadow
			gui.Panel{
				id = "initiativeShadow",
				interactable = false,
				bgimage = 'panels/initiative/shadow.png',
				width = "160%",
				height = 400,
				valign = "top",
				halign = "center",
			},

			--text at the top saying initiative.
			gui.Panel{
				halign = "center",
				valign = "top",
				width = "auto",
				height = "auto",
				flow = "vertical",

				gui.Label({
					text = 'Draw Steel',

					vmargin = 8,
					fontFace = "SupernaturalKnight",
					fontSize = 30,
					color = Styles.textColor,
					valign = 'top',
					halign = 'center',
					textAlignment = 'center',
					width = 'auto',
					height = 'auto',
				}),

				gui.Label{
					text = '',
					fontFace = "Varta",
					fontSize = 22,
					color = Styles.textColor,
					valign = 'top',
					halign = 'center',
					textAlignment = 'center',
					width = 180,
					height = 24,
					vmargin = 0,
					y = -6,

					refresh = function(element)
						if info.initiativeQueue == nil or info.initiativeQueue.hidden then
							element.text = ''
						else
							element.text = string.format('Round %d', info.initiativeQueue.round)
						end
					end,

					gui.Panel{
						classes = {"clickableIcon"},
						bgimage = "panels/hud/clockwise-rotation.png",
						bgcolor = Styles.textColor,
						floating = true,
						halign = "right",
						valign = "center",
						width = 16,
						height = 16,

						hover = gui.Tooltip("Skip to next round"),

						refresh = function(element)
							if (not dmhub.isDM) or info.initiativeQueue == nil or info.initiativeQueue.hidden or (not info.initiativeQueue:ChoosingTurn()) then

								--If there is no initiative then hide the button.
								element:AddClass('hidden')
							else
								element:RemoveClass('hidden')
							end
						end,

						click = function(element)
							if info.initiativeQueue ~= nil then
								info.initiativeQueue:NextRound()
								self:NewRound()
								info.UploadInitiative()
							end
						end,
					},
				},

				addCharacters,
				addMonsters,

			},

			clickLabel,

			mainInitiativeBar,
			choiceInitiativeBar,

			--button to close the initiative queue.
			gui.CloseButton({
				escapeActivates = false,

				events = {
					refresh = function(element)
						--only show this if initiative is currently actually active.
						element:SetClass('hidden', info.initiativeQueue == nil or info.initiativeQueue.hidden)
					end,

					--when clicked we destroy the initiative queue by setting it to nil and upload changes. This will
					--remove the initiative queue completely from player view.
					click = function(element)
						if info.initiativeQueue ~= nil then
							UploadDayNightInfo()
							info.initiativeQueue.hidden = true
							info.UploadInitiative()

							for initiativeid,_ in pairs(info.initiativeQueue.entries) do
								local tokens = self:GetTokensForInitiativeId(info, initiativeid)
								for _,tok in ipairs(tokens) do
									tok.properties:DispatchEvent("endcombat", {})
								end
							end


						end
					end
				},

				selfStyle = {
					halign = 'center',
					valign = 'top',
					x = 102,
					y = 4,
					width = 20,
					height = 20,
				},

				styles = {
					{
						--only show the close initiative button to the DM, so for players hide it.
						selectors = {'player'},
						hidden = 1,
					},
				}
			}),

		----The button that can be pressed to roll for initiative.
		--gui.Panel({
		--
		--	--show a D20 icon.
		--	bgimage = 'ui-icons/d20.png',
		--
		--	events = {
		--		refresh = function(element)
		--			--This button is hidden if initiative isn't active, or if no tokens are currently selected.
		--			if info.initiativeQueue == nil or info.initiativeQueue.hidden or #info.selectedOrPrimaryTokens == 0 then
		--				element:SetClass('hidden', true)
		--			else
		--				element:SetClass('hidden', false)
		--
		--				--see if all our tokens have initiative already, if they do then we mark this as greyed, otherwise
		--				--we want the player to click it so we make it bright and appealing to click.
		--
		--				local hasInitiative = true
		--				for i,tok in ipairs(info.selectedOrPrimaryTokens) do
		--					local initiativeId = InitiativeQueue.GetInitiativeId(tok)
		--					if not info.initiativeQueue:HasInitiative(initiativeId) then
		--						hasInitiative = false
		--					end
		--				end
		--
		--				element:SetClass('highlight', not hasInitiative)
		--			end
		--		end,
		--
		--		refreshSelectedTokens = function(element)
		--			--when the selected tokens have been changed trigger a refresh to see if this should be shown or not.
		--			element:FireEvent('refresh')
		--		end,
		--
		--		click = function(element)
		--			--when the player clicks this, we trigger an initiative roll.
		--
		--			--Iterate over the selected tokens and roll for each of them. (Note: the most common case is just one token is selected)
		--			--Monsters of the same type should only have one roll and will have the same
		--			--initiative ID, so record the initiative ID's we have rolled for and don't
		--			--roll the same initiative ID multiple times.
		--			local initiativeIdsSeen = {}
		--			for i,token in ipairs(info.selectedOrPrimaryTokens) do
		--				if token.properties ~= nil then
		--
		--					--get the initiative ID for this token. This will be the token id for a character,
		--					--or the monster type (prefixed by MONSTER-) for monsters.
		--					local initiativeId = InitiativeQueue.GetInitiativeId(token)
		--					if initiativeIdsSeen[initiativeId] == nil then
		--
		--						initiativeIdsSeen[initiativeId] = true
		--
		--						--We call creature.RollInitiative here (see creature.lua)
		--						local dexterity = token.properties.attributes.dex.baseValue 
		--						token.properties:RollInitiative()
		--					end
		--				end
		--			end
		--		end,
		--
		--		--When the roll for initiative button is hovered show a nice tooltip.
		--		hover = gui.Tooltip("Click to roll for initiative"),
		--	},
		--
		--	--Styling for roll for initiative button.
		--	selfStyle = {
		--		halign = 'left',
		--		valign = 'bottom',
		--		width = 48,
		--		height = 48,
		--	},
		--
		--	styles = {
		--		--button is a little dull by default and highlights a purple color when hovered.
		--		{
		--			bgcolor = '#aaaaaaff',
		--		},
		--		{
		--			--if we want people to click this because they haven't rolled initiative yet.
		--			selectors = { 'highlight' },
		--			brightness = 5.5,
		--			bgcolor = '#ffffffff',
		--		},
		--		{
		--			selectors = { 'hover' },
		--			bgcolor = '#ffaaff',
		--			transitionTime = 0.1,
		--		},
		--		{
		--			selectors = { 'press' },
		--			brightness = 1.5,
		--			transitionTime = 0.1,
		--		},
		--	},
		--}),

		},
	})
end

function GameHud.CreateInitiativeBarChoicePanel(self, info)

	local choicePanel

	--anthem data.
	local m_anthemEventInstance = nil
	local m_anthemTokenId = nil

	local StopAnthem = function()
		if m_anthemEventInstance ~= nil then
			m_anthemEventInstance:Stop()
			m_anthemEventInstance = nil
			m_anthemTokenId = nil

			choicePanel.monitorGame = nil
		end
	end

	local entries = {}

	local CreateContainer = function(playerside)
		local m_label = gui.Label{

			styles = {
				{
					color = Styles.textColor,
				},
				{
					selectors = {"inactive"},
					color = "#666666",
				},
				{
					selectors = {"inactive", "hover"},
					color = "#ffffff",
				},
			},

			press = function(element)
				if element:HasClass("inactive") and CanControlInitiative() then
					info.initiativeQueue.playersTurn = not info.initiativeQueue.playersTurn
					info.UploadInitiative()
				end
			end,

			bgimage = "panels/square.png",
			bgcolor = "#000000bb",
			cornerRadius = 6,
			pad = 2,
			fontSize = 16,
			width = "auto",
			height = "auto",
			text = cond(playerside, "Player's Turn", "Monster's Turn"),
		}

		local m_wonInitiativeIndicator = gui.Panel{
			bgimage = "panels/initiative/initiative-icon2.png",
			bgcolor = "white",
			width = 16,
			height = 16,
			halign = "left",
			valign = "center",
			hmargin = 6,
			linger = function(element)
				gui.Tooltip(string.format("%s %s Initiative", cond(playerside, "Players", "Monsters"), cond(info.initiativeQueue.playersGoFirst == playerside, "Won", "Lost")))(element)
			end,

			press = function(element)
				if CanControlInitiative() and (not element:HasClass("won")) then
					info.initiativeQueue.playersGoFirst = playerside
					info.UploadInitiative()

					element.tooltip = nil
				end
			end,

			styles = {
				{
					selectors = {"won"},
					brightness = 2.0,
				},
				{
					selectors = {"~won"},
					brightness = 0.2,
				},
				{
					selectors = {"~won", "hover"},
					brightness = 0.6,
				},
			}
		}

		return gui.Panel{
			styles = {
				{
					selectors = {"initiativeEntryContainer"},
					bgcolor = "clear",
				},
				{
					selectors = {"initiativeEntryContainer", "drag-target"},
					bgcolor = "#ffffff22",
					borderWidth = 2,
					borderColor = "white",
				},
				{
					selectors = {"initiativeEntryContainer", "drag-target-hover"},
					bgcolor = "#ffffff44",
					borderColor = "yellow",
				},
			},
			dragTarget = true,
			classes = {"initiativeEntryContainer"},
			halign = cond(playerside, "left", "right"),
			width = 260,
			height = 96,
			bgimage = "panels/square.png",
			flow = "horizontal",
			data = {
				player = playerside,
				label = m_label,
				wonInitiativeIndicator = m_wonInitiativeIndicator,
			},

			gui.Panel{
				floating = true,
				flow = "horizontal",
				height = "auto",
				width = "auto",
				halign = "center",
				valign = "bottom",
				y = 32,
				m_wonInitiativeIndicator,
				m_label,
			},
		}
	end

	local playerContainer = CreateContainer(true)
	local monsterContainer = CreateContainer(false)

	choicePanel = gui.Panel{
		width = 600,
		height = 96,
		y = 80,
		flow = "none",

		styles = {
			{
				selectors = {"initiativeEntryPanel"},

			},
			{
				selectors = {"initiativeEntryBackground"},
				width = "100%+32",
				height = "100%+32",
				valign = "center",
				halign = "center",
				borderWidth = 16,
				borderColor = "#000000aa",
				borderFade = true,
			},
			{
				selectors = {"initiativeEntryBorder"},
				bgcolor = "clear",
				width = "100%",
				height = "100%",
				border = 2,
				borderColor = Styles.textColor,
				opacity = 1,
			},
			{
				selectors = {"initiativeEntryBorder", "~parent:unselectable", "parent:hover"},
				brightness = 3,
				transitionTime = 0.5,
			},
			{
				selectors = {"initiativeEntryBorder", "parent:hadTurn"},
				brightness = 0.3,
				transitionTime = 0.5,
			},

			{
				selectors = {"avatar", "parent:hadTurn"},
				saturation = 0.2,
			},
		},

		playerContainer,
		monsterContainer,

		--The 'End Turn' button which is pressed to end the current token's turn. It is only shown to the DM
		--and to players if it is currently their turn (their token is first in the initiative queue).
		gui.FancyButton({
			floating = true,
			bgimage = 'panels/square.png',
			text = 'End Turn',
			y = 60,
			halign = "center",
			valign = "bottom",
			width = 120,
			height = 36,
			fontSize = 20,
			events = {
				click = function(element)
					self:NextInitiative()
					info.UploadInitiative()
				end,

				refresh = function(element)
					if info.initiativeQueue == nil or info.initiativeQueue.hidden or (not self:has_key('currentInitiativeId')) or info.initiativeQueue.currentTurn == false or info.initiativeQueue:ChoosingTurn() then

						--If there is no initiative then hide the button.
						element:AddClass('hidden')
					else
						--Find the list of tokens for the first entry in the initiative queue. If we have control of any of them show
						--the button, otherwise don't.
						local tokens = self:GetTokensForInitiativeId(info, self.currentInitiativeId)
						local foundControllable = false
						for i,tok in ipairs(tokens) do
							if tok.canControl then
								foundControllable = true
								break
							end
						end

						--note that the dm always shows entries, and doesn't auto-remove entries since they might be for a different map.
						if foundControllable or dmhub.isDM then
							element:RemoveClass('hidden')
						else
							element:AddClass('hidden')
						end
					end
				end,

			},
		}),



		refresh = function(element)

			if info.initiativeQueue == nil or info.initiativeQueue.hidden then
				--initiative queue is inactive so just hide this.
				element:SetClass('hidden', true)
				return
			else
				element:SetClass('hidden', false)
			end

			self.currentInitiativeId = info.initiativeQueue.currentTurn or nil

			local isPlayersTurn = info.initiativeQueue:IsPlayersTurn()

			playerContainer.data.label:SetClass("inactive", not isPlayersTurn)
			monsterContainer.data.label:SetClass("inactive", isPlayersTurn)

			playerContainer.data.wonInitiativeIndicator:SetClass("won", info.initiativeQueue.playersGoFirst)
			monsterContainer.data.wonInitiativeIndicator:SetClass("won", not info.initiativeQueue.playersGoFirst)
			
			local playerChildren = {playerContainer.data.label.parent}
			local monsterChildren = {monsterContainer.data.label.parent}
			local newEntries = {}
			for k,v in pairs(info.initiativeQueue.entries) do
				local isplayer = info.initiativeQueue:IsEntryPlayer(k)
				if entries[k] ~= nil and entries[k].data.isplayer == isplayer then
					newEntries[k] = entries[k]
				else
					newEntries[k] = self:CreateInitiativeEntry(info, k, {
						click = function(element)
                            if element:HasClass("turn") then
                                --already our turn.
                                return
                            end
							if CanControlInitiative() == false then --or element:HasClass("unselectable") then
								return
							end
							info.initiativeQueue:SelectTurn(k)
							info.UploadInitiative()

							local tokens = self:GetTokensForInitiativeId(info, v.initiativeid)
							for i,tok in ipairs(tokens) do
								if tok.properties ~= nil then
									tok.properties:BeginTurn()
								end
							end
						end,
					})
					newEntries[k]:SetClass("player", isplayer)
					newEntries[k]:SetClass("monster", not isplayer)

					--parent this panel to a new panel so we can center it.
					gui.Panel{
						halign = "center",
						valign = "center",
						height = "auto",
						width = 1,
						newEntries[k],
					}
				end

				local panel = newEntries[k]
				panel.data.isplayer = isplayer

				local turn = info.initiativeQueue.currentTurn == k
				local unmoved = info.initiativeQueue:EntryUnmoved(v)
				panel:SetClass("turn", turn)
				panel:SetClass("unmoved", unmoved)
				panel:SetClass("hadTurn", not unmoved)
				panel:SetClass("unselectable", (not unmoved) or (isPlayersTurn ~= isplayer))

				if isplayer then
					playerChildren[#playerChildren+1] = panel.parent
				else
					monsterChildren[#monsterChildren+1] = panel.parent
				end
			end

			playerContainer.children = playerChildren
			monsterContainer.children = monsterChildren

			entries = newEntries


			--calculate anthem of the currently playing token.
			local anthemToken = nil
			if self:try_get("currentInitiativeId") ~= nil then
				local tokens = self:GetTokensForInitiativeId(info, self.currentInitiativeId)
				for i,tok in ipairs(tokens) do
					local anthem = tok.anthem
					if anthem ~= nil and anthem ~= "" then
						anthemToken = tok
					end
				end
			end

			if anthemToken ~= nil then
				if anthemToken.charid ~= m_anthemTokenId then
					StopAnthem()
					m_anthemTokenId = anthemToken.charid
					local asset = assets.audioTable[anthemToken.anthem]
					if asset ~= nil then
						m_anthemEventInstance = asset:Play()
						m_anthemEventInstance.volume = anthemToken.anthemVolume
						element.monitorGame = anthemToken.monitorPath
						printf("MONITOR:: Monitoring %s", anthemToken.monitorPath)
					end
				end
			else
				StopAnthem()
			end

		end,


		disable = function(element)
			StopAnthem()
		end,

		--fired when the token playing the anthem changes. Will update the volume of the anthem.
		refreshGame = function(element)
			printf("MONITOR:: REFRESH GAME...")
			if m_anthemEventInstance ~= nil and m_anthemTokenId ~= nil then
				local tok = dmhub.GetTokenById(m_anthemTokenId)
				if tok ~= nil then
					m_anthemEventInstance.volume = tok.anthemVolume
			printf("MONITOR:: REFRESH GAME... SET VOL %f", tok.anthemVolume)
				else
					StopAnthem()
				end
			end
		end,
	}

	return choicePanel
end

function GameHud:NextInitiative()
	local info = self.initiativeInterface
	local mainInitiativeBar = self.choiceInitiativeBar

	--End the turn in initiative queue data and upload the changes.
	if self:has_key('currentInitiativeId') then
		local tokens = self:GetTokensForInitiativeId(info, self.currentInitiativeId)
		for i,tok in ipairs(tokens) do
			if tok.properties ~= nil then
				tok.properties:EndTurn(tok)
			end
		end
		
		local newRound = info.initiativeQueue:NextTurn(self.currentInitiativeId)
		if newRound then
			self:NewRound()
		end

		--recalculate self.currentInitiativeId
		mainInitiativeBar:FireEvent("refresh")

	end
end

function GameHud:NewRound()
	local info = self.initiativeInterface

	for initiativeid,_ in pairs(info.initiativeQueue.entries) do
		local tokens = self:GetTokensForInitiativeId(info, initiativeid)
		for _,tok in ipairs(tokens) do
			tok.properties:DispatchEvent("beginround")
		end
	end
end


local function CreateBossTurnsPanel()
	local m_panels = {}
	return gui.Panel{
		width = "auto",
		height = "auto",
		flow = "horizontal",
		halign = "left",
		valign = "bottom",
		margin = 4,
		floating = true,

		refreshBossTurns = function(element, initiativeQueue, entry)
			local total = entry.turnsPerRound
			local consumed = entry.turnsTaken
			if entry.round < initiativeQueue.round then
				consumed = 0
			elseif entry.round > initiativeQueue.round then
				consumed = total
			end

			if total ~= #m_panels then
				while total < #m_panels do
					m_panels[#m_panels] = nil
				end

				while total > #m_panels do
					m_panels[#m_panels+1] = gui.Panel{
						bgimage = "panels/square.png",
						bgcolor = "white",
						borderWidth = 1,
						borderColor = "white",
						width = 10,
						height = 10,
						cornerRadius = 5,
						hmargin = 2,
					}
				end

				element.children = m_panels
			end

			for i,p in ipairs(m_panels) do
				local isConsumed = i > total - consumed
				p.selfStyle.bgcolor = cond(isConsumed, "black", "white")
			end

		end,
	}
end

--Creates a single initiative entry. This consists of a panel with an image, a display of the initiative number, etc.
function GameHud.CreateInitiativeEntry(self, info, initiativeid, options)

	options = options or {}

	--A function which will conveniently return the token for this entry. If there are multiple tokens (because it's a monster entry)
	--it will just return the first one.
	local GetMatchingToken = function()
		local tokens = self:GetTokensForInitiativeId(info, initiativeid)
		if #tokens > 0 then
			return tokens[1]
		else
			return nil
		end
	end

	local token = GetMatchingToken()
	--if token == nil and not dmhub.isDM then
	--	return nil
	--end

	--this label shows how many tokens this entry represents. Will just be empty text if there is only one token.
	local quantityLabel = gui.Label({
				text = '',
				y = 2,
				margin = 4,
				style = {
					valign = 'bottom',
					halign = 'right',
					textAlignment = 'center',
					hpad = 0,
					width = 'auto',
					height = 'auto',
					fontSize = '30%',
				}
			})


	local closeButton = nil

	--The DM has an 'X' button which lets them remove initiative entries.
	if CanControlInitiative() then

		closeButton = gui.CloseButton({
			events = {
				--remove the initiative entry.
				click = function(element)
					
					if self:has_key("currentInitiativeId") and self.currentInitiativeId == initiativeid then
						--if it's currently this creature's turn, move to next
						info.initiativeQueue:CancelTurn(initiativeid)
					else
						info.initiativeQueue:RemoveInitiative(initiativeid)
					end

					info.UploadInitiative()
				end
			},

			selfStyle = {
				halign = "left",
				valign = "top",
				hmargin = 0,
				vmargin = 0,
				width = 24,
				height = 24,
			},
		})

		--this isn't shown by default, only when hovering over the panel.
		closeButton:AddClass('hidden')
	end

	local playerColor = "black"
	if token ~= nil then
		playercolor = token.playerColor.tostring
	end

	local orderLabel = gui.Label{
		classes = {"hidden"},
		floating = true,
		halign = "center",
		valign = "center",
		width = "auto",
		height = "auto",
		fontSize = 62,
		bold = true,
		color = Styles.textColor,
		text = "2",
		textOutlineWidth = 0.2,
		textOutlineColor = "black",
	}

	local m_bossTurnsPanel = nil

	--this is the initiative entry panel.
	return gui.Panel({
		classes = {"initiativeEntryPanel"},

		draggable = CanControlInitiative(),
		drag = function(element, target)
			if target == nil or (not target:HasClass("initiativeEntryContainer")) then
				return
			end

			local entry = info.initiativeQueue.entries[initiativeid]
			if entry ~= nil and entry:try_get("player") ~= target.data.player then
				entry.player = target.data.player
				info.UploadInitiative()
			end
		end,
		canDragOnto = function(element, target)
			if target ~= nil and target:HasClass("initiativeEntryContainer") then
				return true
			end

			return false
		end,

		events = {
			click = function(element)

				if options.click ~= nil then
					options.click(element)
					return
				end

				local tokens = self:GetTokensForInitiativeId(info, initiativeid)
				if tokens ~= nil and #tokens > 0 then
					for i,tok in ipairs(tokens) do
						if i == 1 then
							dmhub.SelectToken(tok.id)
							dmhub.CenterOnToken(tok.id)
						else
							dmhub.AddTokenToSelection(tok.id)
						end
					end
				end

			end,

			refresh = function(element)
				--check if the token still exists. If it doesn't we collapse this entry unless we're the DM.
				token = GetMatchingToken()
				--if token == nil and not dmhub.isDM then
				--	element:AddClass('collapsed')
				--else
					element:RemoveClass('collapsed')
				--end

				local entry = info.initiativeQueue.entries[initiativeid]
				if entry ~= nil and entry.round == info.initiativeQueue.round+1 then
					orderLabel.text = tostring(entry.turn)
					orderLabel:RemoveClass("hidden")
				else
					orderLabel:AddClass("hidden")
				end

				if entry ~= nil and entry.turnsPerRound > 1 then
					if m_bossTurnsPanel == nil then
						m_bossTurnsPanel = CreateBossTurnsPanel()
						element:AddChild(m_bossTurnsPanel)
					end

					m_bossTurnsPanel:FireEvent("refreshBossTurns", info.initiativeQueue, entry)
				elseif m_bossTurnsPanel ~= nil then
					m_bossTurnsPanel:DestroySelf()
					m_bossTurnsPanel = nil
				end
			end,

			--If we're the DM and the close button is available, then show/hide it when we hover or dehover this panel.
			hover = function(element)
				local tokens = self:GetTokensForInitiativeId(info, initiativeid)
				if tokens ~= nil and #tokens > 0 then
					for _,tok in ipairs(tokens) do
						dmhub.PulseHighlightToken(tok.id)
					end
				end

				if closeButton ~= nil then
					closeButton:RemoveClass('hidden')
				end

				local tooltip = nil
				if token ~= nil then
					if token.canLocalPlayerSeeName then
						tooltip = token.name
					end

					if tooltip == nil or tooltip == '' or token.properties:MinionSquad() ~= nil then
						if dmhub.isDM and token.properties ~= nil and token.properties:GetMonsterType() ~= nil then
							tooltip = token.properties:GetMonsterType()

							if token.properties:MinionSquad() ~= nil and #tokens > 1 then
								local minionType = nil
								local captainType = nil

								for i,tok in ipairs(tokens) do
									if tok.properties ~= nil then
										if tok.properties.minion then
											minionType = tok.properties:GetMonsterType()
										else
											captainType = tok.properties:GetMonsterType()
										end
									end
								end

								if minionType ~= nil then
									tooltip = token.properties:MinionSquad()
									if captainType ~= nil then
										tooltip = string.format("%s\nCaptain: %s", tooltip, captainType)
									end
								end

							end
						else
							tooltip = 'NPC/Monster'
						end
					else
						local playerName = token.playerName
						if playerName ~= tooltip then
							tooltip = string.format('%s (%s)', tooltip, playerName)
						end
					end
				elseif dmhub.isDM and info.initiativeQueue ~= nil and info.initiativeQueue:HasInitiative(initiativeid) then
					tooltip = info.initiativeQueue:DescribeEntry(initiativeid) .. "\nNot on this map"
				end

				if tooltip ~= nil and tooltip ~= "" then
					gui.Tooltip(tooltip)(element)
				end
			end,

			dehover = function(element)
				if closeButton ~= nil then
					closeButton:AddClass('hidden')
				end
			end,
		},

		children = {
			gui.Panel{
				classes = {"initiativeEntryBackground"},
				bgimage = "panels/square.png",
		
				selfStyle = {
					bgcolor = 'white',

					--make the background a nice gradient that is in the player's color.
					gradient = {
						type = 'radial',
						point_a = { x = 0.5, y = 0.8, },
						point_b = { x = 0.5, y = 0, },
						stops = {
							{
								position = 0,
								color = playerColor,
							},

							{
								position = 1,
								color = '#000000',
							},
						}
					},
				},
			},

			--an image which will display the avatar of the token for this initiative entry.
			gui.Panel{
				classes = {"avatar"},
				bgimage = 'panels/square.png',
				height = "100%",
				width = "100%",
				valign = 'top',
				halign = 'center',
				bgcolor = 'white',

				refresh = function(element)
					--find which token this represents and display their avatar.
					--Also count the number of tokens so we can display the quantity.
					local tokens = self:GetTokensForInitiativeId(info, initiativeid)
					local found = false
					local quantity = 0

					for i,tok in ipairs(tokens) do
						if tok.canSee or tok.playerControlled then

							if found == false then
								token = tok

								--set the image shown here with the current portion of the image.
								element.bgimage = token.portrait
								element.selfStyle.imageRect = token:GetPortraitRectForAspect(CardWidthPercent*0.01)
								found = true
							end

							quantity = quantity+1
						end
					end

					if found == false then
						--we can't see any of the tokens associated with this entry so show that it is unknown.
						element.bgimage = 'game-icons/perspective-dice-six-faces-random.png'
						element.selfStyle.imageRect = nil
					end

					--display the quantity here.
					if quantity <= 1 then
						quantityLabel.text = ''
					else
						quantityLabel.text = string.format("x%d", quantity)
					end
				end,
			},

			gui.Panel{
				classes = {"initiativeEntryBorder"},
				bgimage = "panels/square.png",
			},

			quantityLabel,


			gui.Panel{
				classes = {"initiativeArrow"},
				floating = true,
				press = function(element)
				end,
			},

			closeButton,

			orderLabel,
		}
	})
end

--This utility function is given an initiative ID and finds the list of tokens that match that initiative ID.
--For a character this will give back that single character token.
--For monsters it will give back all monsters of that type.
function GameHud.GetTokensForInitiativeId(self, info, initiativeid)
	local result = {}
	if string.starts_with(initiativeid, 'MONSTER-') then
		local monsterType = string.sub(initiativeid, 9, -1)

		for k,tok in pairs(info.tokens) do
			if tok.properties ~= nil and (tok.properties:GetMonsterType() == monsterType or tok.properties:MinionSquad() == monsterType) and (dmhub.isDM or not tok.invisibleToPlayers) then
				result[#result+1] = tok
			end
		end
	elseif info.tokens[initiativeid] then
		result[#result+1] = info.tokens[initiativeid]
    else
        for k,tok in pairs(info.tokens) do
            if tok.properties.initiativeGrouping == initiativeid then
                result[#result+1] = tok
            end
        end
	end

	return result
end