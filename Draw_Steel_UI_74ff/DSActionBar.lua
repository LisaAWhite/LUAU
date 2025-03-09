local mod = dmhub.GetModLoading()

setting{
	id = "tinyactionbar",
	text = "Expanded Action Bar",
	description = "Expanded Action Bar",
	storage = "preference",
	default = false,
	editor = "check",
}

--make sure when we load this mod the game hud gets rebuilt so it includes our new action bar.
dmhub.RebuildGameHud()

ActionBar = {

	allowTinyActionBar = true,

	hasLoadoutPanel = true,
	hasCustomizationPanel = true,
	hasMovementTypePanel = true,
	containerUIScale = 1,
	containerPageSize = 8,
	mainPanelMaxWidth = 1300,
	mainPanelHAlign = "center",
	bars = {},
	transparentBackground = false,

	--If set, the spell info tooltip is shown when the spell is clicked, not just as a transient tooltip.
	spellInfoOnClick = false,
	resourcesWithBars = false,
	largeQuantityResourceHorizontal = true,
	actionsMinWidth = 0,

	sortByDisplayOrder = false,
	hasReactionBar = true,
}

local g_profileActionBarRecalculate = dmhub.ProfileMarker("actionbar.Recalculate")
local g_profileActionBarRecalculateResources = dmhub.ProfileMarker("actionbar.RecalculateResources")
local g_profileCast = dmhub.ProfileMarker("actionbar.Cast")

local SlotStyles = {
	{
		selectors = {'preview-dice'},
		hidden = 1,
		opacity = 0,
		transitionTime = 0.5,
	},
	{
		selectors = {'slot'},
		width = 76,
		height = 76,
		hmargin = 2,
		bgcolor = "black",
        bgimage = "panels/square.png",
        borderWidth = 4,
        borderColor = "white",
	},
	{
		selectors = {'slot', 'expended'},
        borderColor = "#888888",
        bgcolor = "white",

        gradient = gui.Gradient{
            point_a = {x=0,y=0},
            point_b = {x=0,y=1},
            stops = {
                {
                    position = 0,
                    color = "#000000",
                },
                {
                    position = 1,
                    color = "#444444",
                },

            },
        }
	},
	{
		selectors = {'slot', 'activeReaction'},
		brightness = 2,
	},
	{
		selectors = {'slot', 'flashReaction'},
		bgcolor = "red",
		transitionTime = 0.15,
	},
	{
		selectors = {'slot','focus'},
        brightness = 2,
	},
	{
		selectors = {'slot','press'},
        brightness = 0.6,
	},
	{
		selectors = {'slot','hover','~expended'},
        brightness = 2,
	},

    {
        selectors = {'slot','maneuver'},
        bgcolor = "white",
        gradient = gui.Gradient{
            point_a = {x=0,y=0},
            point_b = {x=1,y=1},
            stops = {
                {
                    position = 0,
                    color = "#000000",
                },
                {
                    position = 1,
                    color = "#666666",
                },

            },
        }

    },

	{
		selectors = {'slot-highlight'},
		bgcolor = 'clear',
		width = "100%",
		height = "100%",
		halign = 'center',
		valign = 'center',
		bgslice = 20,
		border = 10,
	},
	{
		selectors = {'slot-highlight','parent:focus'},
		bgcolor = 'white',
		brightness = 10,
	},
	{
		selectors = {'slot-highlight','parent:hover'},
		bgcolor = "white",
		brightness = 10,
	},
	{
		selectors = {'slot-highlight','parent:press'},
		bgcolor = 'white',
		brightness = 0.8,
		saturation = 0.0,
	},

	{
		selectors = {'icon'},
		bgcolor = 'white',
		width = "100%",
		height = "100%",
		hmargin = 0,
		brightness = 1.0,
	},
	{
		selectors = {'icon','parent:hover'},
		rotate = -20,
		scale = 1.2,
		transitionTime = 0.1,
	},

	{
		selectors = {'spellIcon'},
		valign = "center",
		halign = "center",
		width = "80%",
		height = "80%",
		hmargin = 0,
        bgcolor = "white",
	},
    {
        selectors = {"spellIcon", "~noadd"},
        blend = "add",
    },
	{
		selectors = {'spellIcon', 'expended'},
        --brightness = 0.3,
	},
	{
		selectors = {'spellIcon','parent:hover'},
		transitionTime = 0.1,
	},

	{
		selectors = {'arrow'},
		x = 16,
		y = -16,
		halign = 'right',
		valign = 'top',
		bgcolor = 'white',
		width = 32,
		height = 32,
	},

	{
		selectors = {'arrow', 'hover'},
		brightness = 4,
		transitionTime = 0.1,
	},

	{
		selectors = {'arrow', 'press'},
		transitionTime = 0.1,
		brightness = 2,
	},

	{
		selectors = {'invalid'},
		color = '#ff2222',
	},

	{
		selectors = {"resourceCostPanel"},
		halign = "right",
		flow = "horizontal",
		width = "auto",
		height = "auto",
	},

	{
		selectors = {"resourceCostIcon"},
		width = 28,
		height = 28,
		bgcolor = "white",
	},

	{
		selectors = {"hotkeyLabel"},
		color = "white",

		bgcolor = "#000000ff",
		borderColor = "#000000ff",
		borderWidth = 16,
		borderFade = true,
		cornerRadius = 16,
		vpad = 4,

		y = 12,
		width = "70%",
		height = "auto",
		textAlignment = "center",
		halign = "center",
		valign = "bottom",
		fontSize = 24,
		minFontSize = 10,

	},

	{
		selectors = {"hotkeyLabel", "expended"},
		color = "#999999",
	},
}

function GameHud.CreateActionBar(self, dialog, tokenInfo)
	local actionBarResultPanel = nil

	local actionBar
	local arrowPanel --paging arrows in the action bar.

	local token = nil
	local creature = nil

	--objects to mark line of sight.
	local m_markLineOfSight = nil
    local m_markLineOfSightSourceToken = nil
	local m_markLineOfSightToken = nil

	--the panel that shows the current spell being cast.
	local m_currentSpellPanel = nil

	--the button used to cast spells and label used to show cast info.
	local castButton
	local skipButton
	local castMessage
	local castMessageContainer
	local castSpellLevelPanel
	local channeledResourcePanel


	local castModesPanel

	local castChargesInput

	local ammoChoicePanel
	local synthesizedSpellsPanel

	--cost of the ability currently being used.
	local currentCostProposal = nil

    local m_targetLineOfSightRays = {}

    local function FreeTargetLineOfSightRays()
        for key,ray in pairs(m_targetLineOfSightRays) do
            ray:DestroyLineOfSight()
        end

        m_targetLineOfSightRays = {}
    end

    local function SetTargetLineOfSightRayForKey(key, ray)
        if m_targetLineOfSightRays[key] ~= nil then
            m_targetLineOfSightRays[key]:DestroyLineOfSight()
        end

        m_targetLineOfSightRays[key] = ray
    end

    ---@param rays table<{a: Token, b: Token}>[]
    local function ReplaceTargetLineOfSightRays(rays)
        local t = {}
        for i,ray in ipairs(rays) do
            local key = string.format("%s-%s", ray.a.id, ray.b.id)
            t[key] = m_targetLineOfSightRays[key] or dmhub.MarkLineOfSight(ray.a, ray.b)
            m_targetLineOfSightRays[key] = nil
        end

        FreeTargetLineOfSightRays()
        m_targetLineOfSightRays = t
    end

    local function RemoveLineOfSightRaysTargetingToken(tokenid)
        local destroyKeys = {}
        for key,ray in pairs(m_targetLineOfSightRays) do
            if string.ends_with(key, tokenid) then
                ray:DestroyLineOfSight()
                destroyKeys[#destroyKeys+1] = key
            end
        end

        for _,key in ipairs(destroyKeys) do
            m_targetLineOfSightRays[key] = nil
        end
    end

	--the spell we are currently casting, if any.
	local currentSpell = nil

	--symbols for the ability being used. Includes upcasting and things.
	local currentSymbols = { mode = 1, charges = 1 }

	--resources bars.
	local resourcesBar
	local actionResourcesBar

	local resourcePanels

	local CurrentCalculateSpellTargeting = nil
	local CalculateSpellTargetFocusing = nil
	local spellRange = nil

	--{string spell category -> {spell panels}}
	local m_spellPanels = {}

	local loadoutPanel = nil

	local movementTypePanel = nil

	local GetLoadoutPanel = function()
		if loadoutPanel == nil then

			local loadoutEntries = {}
			for i=1,creature.numLoadouts do
				local slotIcons = {}
				local slots = {}
				for j=1,2 do
					slotIcons[#slotIcons+1] = gui.Panel{
						classes = {"icon"},
						selfStyle = {},
						width = 24,
						height = 24,
						data = {
							slotid = string.format("%s%d", cond(j == 1, "mainhand", "offhand"), i),
						}
					}
					slots[#slots+1] = gui.Panel{
						bgimage = "panels/square.png",
						classes = {"slot"},
						width = 24,
						height = 24,
						slotIcons[#slotIcons],
					}
				end
				loadoutEntries[i] = gui.Panel{
					flow = "horizontal",
					width = "100%",
					height = 24,

					press = function(element)
						token:ModifyProperties{
							description = "Change loadout",
							execute = function()
								token.properties.selectedLoadout = cond(token.properties.selectedLoadout == i, 0, i)
							end,
						}

						--instantly refresh the token.
						game.Refresh{
							tokens = {token.charid},
						}
					end,

					data = {
						slots = slots,
						icons = slotIcons,
					},
					children = {
						gui.Label{
							text = string.format("%d.", i),
						},
						slots[1],
						slots[2],
					},
				}
			end

			loadoutPanel = gui.Panel {
				flow = "vertical",
				width = 76,
				height = 76,
				hmargin = 4,

				styles = {
					{
						selectors = {"label"},
						width = 16,
						height = 24,
						fontSize = 15,
						textAlignment = "center",
					},
					{
						selectors = {"label", "parent:selected"},
						bold = true,
						color = "white",
					},
					{
						selectors = {"label", "parent:hover"},
						bold = true,
						color = "white",
					},
					{
						selectors = {"slot", "parent:selected"},
						brightness = 4,
					}
				},

				refreshLoadout = function(element)
					local equipment = token.properties:Equipment()
					local gearTable = dmhub.GetTable("tbl_Gear")
					local highestSlotUsed = 0
					for i,entry in ipairs(loadoutEntries) do
						entry:SetClass("selected", i == token.properties.selectedLoadout)
						for j,icon in ipairs(entry.data.icons) do
							local bgimage = nil
							local itemid = equipment[icon.data.slotid]
							if itemid ~= nil then
								highestSlotUsed = i
								local itemInfo = gearTable[itemid]
								if itemInfo ~= nil then
									bgimage = itemInfo.iconid
								end 
							end

							if bgimage == nil then
								icon:SetClass("hidden", true)
							else
								icon:SetClass("hidden", false)
								icon.selfStyle.bgimage = bgimage
							end
						end
					end

					--only show loadout slots that we use.
					for i,entry in ipairs(loadoutEntries) do
						entry:SetClass("hidden", i > highestSlotUsed)
					end
				end,

				children = loadoutEntries
			}
		end

		loadoutPanel:FireEvent("refreshLoadout")

		return loadoutPanel
	end


	local pageNumber = 1
	local numPages = 1
	local pageSize = 32

	--the panels which are shown on pages and can be turned between.
	local pagingPanels = {}


	local CreateFocusPanel = function()
		return gui.Panel{
			classes = {'slot-highlight'},
			bgimage = 'panels/hud/button_09_frame_custom_border.png',
			interactable = false,
		}
	end

	self.castingSpell = false
	local gameUpdateCameWhileCastingSpell = false
	local castingEmoteSet = nil

	--functionality to mark radiuses.
	local radiusMarkers = {}

	local AddCustomAreaMarker = function(locs, color)
		radiusMarkers[#radiusMarkers+1] = dmhub.MarkLocs{
			locs = locs,
			color = color,
		}
    end

	local AddRadiusMarker = function(locOverride, radius, color, filterFunction)
		local locs = token.locsOccupying
		if locOverride ~= nil then
			if type(locOverride) == "table" then
				locs = locOverride
			else
				locs = {locOverride}
			end
		end

		local shape = dmhub.CalculateShape{
			shape = "radiusfromcreature",
			token = token,
			radius = radius,
			locOverride = locs,
		}

		local locs = shape.locations
		if filterFunction ~= nil then
			local newLocs = {}
			for _,loc in ipairs(locs) do
				if filterFunction(loc) then
					newLocs[#newLocs+1] = loc
				end
			end

			locs = newLocs
		end

		radiusMarkers[#radiusMarkers+1] = dmhub.MarkLocs{
			locs = locs,
			color = color,
		}
	end

	local ClearRadiusMarkers = function()
		for i,marker in ipairs(radiusMarkers) do
			marker:Destroy()
		end

		radiusMarkers = {}
	end

	local GetSpellPanel = function(spellCategory, spellIndex, spellObj, spellOptions)

		spellOptions = spellOptions or {}

		local spell
		local resourceTable
		local costInfo

		--for when we are targeting a point and we want to mark clearly where a path ends
		--before it reaches the full distance of the target.
		local pointTargetShapePathEnd = nil
		local pointTargetRadiusPathEnd = nil
		local pointTargetPathEndOvershoot = nil

		local m_pointTargetFallingShape = nil

		local pointTargetShape = nil
		local pointTargetRadius = nil
		local showingMovementArrow = false

		local targetInfo

		--tokens we are force targeting based on them being in a radius. A mapping of tokenid -> token
		local pointForceTargets = {}

		local spellPanel = nil
		if spellIndex ~= nil then
			m_spellPanels[spellCategory] = m_spellPanels[spellCategory] or {}
			spellPanel = m_spellPanels[spellCategory][spellIndex]
		end

		if spellPanel == nil then

			local SetTargetsInRadius = function(tokens)

				for k,tok in pairs(tokens) do
					if pointForceTargets[tok.id] == nil then
						tok.sheet:FireEvent("targetnoninteractive", {})
					end
				end

				for k,tok in pairs(pointForceTargets) do
					if tokens[k] == nil then
						tok.sheet:FireEvent("untarget")
					end
				end

				pointForceTargets = tokens
			end


			local firstTarget = nil
			local m_targetsChosen = {} --list of strings for targets. Can contain duplicates if duplicate targeting is enabled.

            ---@return table<{loc: table, token: Token}>[]
            local function BuildTargetsList()
				--accumulate our target list based on what is selected.
				local targets = {}

				for _,tokenid in ipairs(m_targetsChosen) do
					local token = dmhub.GetTokenById(tokenid)
					if token ~= nil then
						targets[#targets+1] = { loc = token.loc, token = token }
					end
				end

                return targets
            end

			local CalculateSpellTargeting = function(forceCast)
				if currentSpell == nil then
					dmhub.CloudError("nil currentSpell: " .. traceback())
					return
				end

				if currentSpell.targetType == 'point' then
					
				else
					local targets = BuildTargetsList()

					local range = currentSpell:GetRange(token.properties, currentSymbols)

                    --if this spell dictates specific targeting rays to use.
                    local rays = currentSpell:GetTargetingRays(token, range, currentSymbols, targets)
                    if rays ~= nil then
                        ReplaceTargetLineOfSightRays(rays)

                        --record the targeting as symbols.
                        local targetPairs = {}
                        for i,ray in ipairs(rays) do
                            targetPairs[#targetPairs+1] = {a = ray.a.id, b = ray.b.id}
                        end

                        currentSymbols.targetPairs = targetPairs
                    else
                        currentSymbols.targetPairs = nil
                    end

					skipButton:SetClass("collapsed", not currentSpell:try_get("skippable", false))

					if (not currentSpell:CanSelectMoreTargets(token, targets, currentSymbols)) or forceCast then
                        --we can't select more targets, so cast the spell in here.
						token.lookAtMouse = false
						if castingEmoteSet and token.valid then
							token.properties:Emote(castingEmoteSet .. 'cast', {start = true, ttl = 20})
						end

						if currentSpell.sequentialTargeting and currentSymbols.targetnumber == nil then
							currentSymbols.targetnumber = 1
							currentSymbols.targetcount = currentSpell:GetNumTargets(token, currentSymbols)
						end

						--make any active targeted tokens keep their targeting until the spell is done.
						local adoptedTargets = {}
						for k,token in pairs(self.tokenInfo.tokens) do
							if token.sheet.data.targetInfo == targetInfo then
								token.sheet:FireEvent('adoptSelectedTargets', adoptedTargets)
							end
						end

                        targets = currentSpell:PrepareTargets(token, currentSymbols, targets)

                        if m_markLineOfSight ~= nil then
                            SetTargetLineOfSightRayForKey(string.format("%s-%s", m_markLineOfSightSourceToken.id, m_markLineOfSightToken.id), m_markLineOfSight)
                            m_markLineOfSight = nil
                            m_markLineOfSightToken = nil
                            m_markLineOfSightSourceToken = nil
                        end

						g_profileCast:Begin()
						currentSpell:Cast(token, targets, {
							costOverride = currentCostProposal,
							symbols = currentSymbols,
							markLineOfSight = m_targetLineOfSightRays,
							OnFinishCastHandlers = {
								function()
									for _,panel in ipairs(adoptedTargets) do
										if panel ~= nil and panel.valid then
											panel:FireEvent("destroy")
										end
									end
								end,
							},
						})
						g_profileCast:End()
                        m_targetLineOfSightRays = {}
						spellPanel:FireEvent('cancel')
					else

						ammoChoicePanel:FireEvent("refreshSpell")
						synthesizedSpellsPanel:FireEvent("refreshSpell")
						castChargesInput:FireEvent("refreshSpell")

						local synthesizedSpells = synthesizedSpellsPanel.data.synthesized
						castButton:SetClass('collapsed', (not currentSpell:CanCastAsIs(token, targets, currentSymbols)) or (synthesizedSpells ~= nil and #synthesizedSpells > 0))


						local promptText = currentSpell:PromptText(token, targets, currentSymbols, synthesizedSpells)
						castMessage:SetClass('collapsed', false)
						castMessage.data.promptText = promptText
						castMessage:FireEvent("refresh")

						castModesPanel:FireEvent("refreshModes")

						local range = currentSpell:GetRange(token.properties, currentSymbols)

						if range ~= spellRange and CalculateSpellTargetFocusing ~= nil then
							spellRange = range
							CalculateSpellTargetFocusing(range)
						end

						--refresh the radius marker.
						if (currentSpell.targetType == "emptyspace" or currentSpell.targetType == "anyspace") and currentSpell:try_get("targeting", "direct") == "pathfind" then
							ClearRadiusMarkers()
							radiusMarkers[#radiusMarkers+1] = token:MarkMovementRadius(range)
						elseif currentSpell.targetType ~= 'line' and currentSpell.targetType ~= 'cone' and currentSpell.targetType ~= 'self' and currentSpell.targetType ~= 'all' and currentSpell.targetType ~= 'map' then
							local loc = currentSpell:try_get("casterLocOverride")

							if currentSpell.proximityTargeting and firstTarget ~= nil then
								local firstTargetToken = dmhub.GetTokenById(firstTarget)
								if firstTargetToken ~= nil then
									loc = firstTargetToken.locsOccupying
									range = dmhub.EvalGoblinScriptDeterministic(currentSpell.proximityRange, token.properties:LookupSymbol(), dmhub.unitsPerSquare, string.format("Calculate proximity: %s", spell.name))
								end
							end

							ClearRadiusMarkers()

                            local customLocs = currentSpell:CustomTargetShape(token, range, currentSymbols, targets)

                            if customLocs == nil then
							
                                local filterTargetPredicate = currentSpell:TargetLocPassesFilterPredicate(token, currentSymbols)


                                AddRadiusMarker(loc, range, 'white', filterTargetPredicate)

                                local rangeDisadvantage = currentSpell:GetRangeDisadvantage(token.properties, currentSymbols)
                                if rangeDisadvantage ~= nil and rangeDisadvantage > range then
                                    AddRadiusMarker(loc, rangeDisadvantage, 'grey', filterTargetPredicate)
                                end
                            else
                                AddCustomAreaMarker(customLocs, 'white')
                            end
						elseif spell.targetType == 'all' then
							spellPanel:FireEvent("maphover", nil, 'all')
						end
					end
				end
			end

			local namedResourceCostChildren = {}
			local anonymousResourceCostChildren = {}
			local consumableCostChild = gui.Label{
				floating = true,
				fontSize = 12,
				width = 'auto',
				height = 'auto',
				halign = "right",
				valign = "top",
				hmargin = 4,
				vmargin = 4,
			}
			local anonymousCostPanel
			local iconPanel


			anonymousCostPanel = gui.Panel{
				idprefix = "resourceCostPanel",
				classes = {"resourceCostPanel"},
				floating = true,
				valign = "top",

				refreshSpell = function(element)

					local indexActionCostChildren = 1
					local indexNamedResourceCostChildren = 1
					local indexAnonymousResourceCostChildren = 1

					for i,entry in ipairs(costInfo.details) do
						local resourceid = entry.cost
						if #entry.paymentOptions > 0 then
							--if we have ways this creature is going to pay the cost, then we will show the actual payment.
							--this is likely a progressive resource, like bardic inspiration dice.
							resourceid = entry.paymentOptions[1].resourceid
						end
						local index = i
						local resource = resourceTable[resourceid]

						if resource == nil and entry.description == nil then
							dmhub.CloudError(string.format("nil resource and description: %s in cost %s at %s", json(resourceid), json(costInfo), traceback()))
							break
						end

						if entry.description ~= nil then
							--these are 'anonymous' resource costs.
							local resourceLabel = anonymousResourceCostChildren[indexAnonymousResourceCostChildren] or gui.Label{
								fontSize = 12,
								width = 'auto',
								height = 'auto',
								valign = "center",
								bgimage = "panels/square.png",
								bgcolor = "black",
								data = {
									index = index,
								},

								refreshActionbar = function(element, newToken)
									if element:HasClass("collapsed") then
										return
									end

									if element.data.index <= #costInfo.details then
										element.text = costInfo.details[element.data.index].description
									end
								end,
							}

							resourceLabel:SetClass("expended", not entry.canAfford)
							resourceLabel.text = entry.description
							resourceLabel.data.index = index
							anonymousResourceCostChildren[indexAnonymousResourceCostChildren] = resourceLabel
							indexAnonymousResourceCostChildren = indexAnonymousResourceCostChildren+1

						elseif resource.grouping ~= "Actions" then
							--resource costs for a known resource. May be an action or an actual resource.

							local iconPanel = namedResourceCostChildren[indexNamedResourceCostChildren]
							
							if iconPanel == nil then
								iconPanel = gui.Panel{
									idprefix = "resourceicon",
									classes = {"resourceCostIcon"},
									selfStyle = resource:GetDisplayStyle(cond(entry.canAfford, nil, "expended")),
									x = 6,
									y = -6,
									styles = {
										{
											priority = 10,
											width = 46,
											height = 46,
										}

									},
									bgimage = resource.iconid,
									data = {
										id = resource.id,
										quantity = 1,
										canAfford = entry.canAfford,
									}
								}
							end

							if iconPanel.data.id ~= resource.id or iconPanel.data.canAfford ~= entry.canAfford then
								iconPanel.data.id = resource.id
								iconPanel.selfStyle = resource:GetDisplayStyle(cond(entry.canAfford, nil, "expended"))

								iconPanel.bgimage = resource.iconid
								iconPanel.x = 0
								iconPanel.data.canAfford = entry.canAfford
							end

							iconPanel:SetClass("expended", not entry.canAfford)


							if (entry.quantity or 1) ~= iconPanel.data.quantity or entry.canAfford ~= iconPanel.data.canAfford then
								if (entry.quantity or 1) == 1 then
									iconPanel.children = {}
								else
									local children = iconPanel.children
                                    local label
									if #children == 0 then
										label = gui.Label{
											fontSize = 22,
											halign = "center",
											valign = "center",
											textAlignment = "center",
											width = 20,
											height = "auto",
											text = "<b>" .. tostring(entry.quantity) .. "</b>",
                                            textWrap = false,
										}
										iconPanel.children = {label}
										label:SetClass("expended", not entry.canAfford)
                                        label:SetClass(resource.textColor, true)
									else
                                        label = children[1]
										label.text = tostring(entry.quantity)
									end

                                    local color = "white"
                                    if resource.textColor ~= "light" then
                                        color = "black"
                                    end

                                    label.selfStyle.color = color

								end

								iconPanel.data.quantity = entry.quantity or 1
                                iconPanel.data.canAfford = entry.canAfford
							end

							namedResourceCostChildren[indexNamedResourceCostChildren] = iconPanel
							indexNamedResourceCostChildren = indexNamedResourceCostChildren+1
						end
					end

					if costInfo.consumables then
						for k,quantity in pairs(costInfo.consumables) do
							consumableCostChild:SetClass("hidden", false)

							local itemTable = dmhub.GetTable(equipment.tableName)

							local itemInfo = itemTable[k]
							if itemInfo ~= nil and itemInfo:HasCharges() then
								consumableCostChild.text = string.format("%d/%d", itemInfo:RemainingCharges(), itemInfo:MaxCharges())
							else
								local quantity = creature:GetItemQuantityIncludingEquipment(k)
								consumableCostChild.text = string.format("%d", quantity)
							end
						end
					else
						consumableCostChild:SetClass("hidden", true)
					end

					for i,p in ipairs(anonymousResourceCostChildren) do
						p:SetClass("collapsed", i >= indexAnonymousResourceCostChildren)
					end

					for i,p in ipairs(namedResourceCostChildren) do
						p:SetClass("collapsed", i >= indexNamedResourceCostChildren)
					end

					local resourcePanels = {}
					for i,p in ipairs(anonymousResourceCostChildren) do
						resourcePanels[#resourcePanels+1] = p
					end

					for i,p in ipairs(namedResourceCostChildren) do
						resourcePanels[#resourcePanels+1] = p
					end

					anonymousCostPanel.children = resourcePanels
				end,
			}

            local typeIconPanelIcon = gui.Panel{
                width = 42,
                height = 42,
                bgcolor = "white",
                bgimage = "panels/square.png",
            }

            --an icon that will appear in the top left and be driven off of
            --ActivatedAbility:GetTypeIconForActionBar()
            local typeIconPanel = gui.Panel{
                halign = "left",
                valign = "top",
                classes = {"collapsed"},
                width = 42,
                height = 42,
                bgimage = "panels/square.png",
                bgcolor = "#000000aa",

                typeIconPanelIcon,

				refreshSpell = function(element)
                    local icon = spell:GetTypeIconForActionBar()
                    if icon == nil then
                        element:SetClass("collapsed", true)
                    else
                        element:SetClass("collapsed", false)
                        typeIconPanelIcon.selfStyle.bgimage = icon
                        if costInfo.canAfford then
                            typeIconPanelIcon.selfStyle.bgcolor = "white"
                        else
                            typeIconPanelIcon.selfStyle.bgcolor = "#777777"
                        end

                    end
                end,
            }

			local iconPanel = gui.Panel{
					idprefix = "spellIcon",
					classes = {'spellIcon'},

					refreshSpell = function(element)
						element:SetClass("expended", not costInfo.canAfford)
						element.bgimage = spell.iconid
						element.selfStyle = spell.display
                        if not costInfo.canAfford then
                            element.selfStyle.brightness = 0.1
                        else
                            element.selfStyle.brightness = spell.display.brightness or 1
                        end
					end,
				}

			local hotkeyLabel = gui.Label{
				classes = {"hotkeyLabel"},
				floating = true,
				bgimage = "panels/square.png",
				interactable = false,
				text = "",
			}
			
			spellPanel = gui.Panel{
				idprefix = "spellPanel",
				bgimage = 'panels/square.png',
				classes = {'slot'},
				escapePriority = EscapePriority.CANCEL_ACTION_BAR,

				data = {
					GetKeywords = function(element)
						return {spell.name}
					end,
					GetSpell = function()
						return spell
					end,
					spellInfoDisplay = nil,
					reactionFlashTime = nil,

					reactionTraces = nil,
				},

				think = function(element)
					if token == nil then
						return
					end
					local tmp_reactionsCleared = token.properties:try_get("_tmp_reactionsCleared", {})
					if element:HasClass("activeReaction") then
						if element.data.reactionFlashUntil ~= nil and dmhub.Time() < element.data.reactionFlashUntil then
							element:SetClass("flashReaction", not element:HasClass("flashReaction"))
						else
							element:SetClass("activeReaction", false)
							element:SetClass("flashReaction", false)
							element.thinkTime = nil
						end
					end
				end,

				clearreactions = function(element)
					if token.properties:has_key("activeReactions") then
						for _,reaction in ipairs(token.properties.activeReactions) do
							if TimestampAgeInSeconds(reaction.timestamp) < 30 and reaction.ability == spell.name then
								local tmp_reactionsCleared = token.properties:get_or_add("_tmp_reactionsCleared", {})
								tmp_reactionsCleared[reaction.guid] = true
							end
						end
					end

					element:SetClass("flashReaction", false)
					element:SetClass("activeReaction", false)
					element.thinkTime = nil
				end,

				setkeybind = function(element, text)
					if text == nil or text == "" then
						hotkeyLabel:SetClass("collapsed", true)
					else
						hotkeyLabel:SetClass("collapsed", false)
						hotkeyLabel.text = string.format("<b>%s</b>", text)
					end
				end,

				refreshSpell = function(element, newSpell)
					spell = newSpell

                    local isManeuver = spell:IsManeuver()
                    element:SetClass("maneuver", newSpell:IsManeuver())

					element.data.id = spell:try_get("weaponid", spell:try_get("id", spell:try_get("guid"))) --spell:GetID()
					resourceTable = dmhub.GetTable("characterResources")
					costInfo = spell:GetCost(token)

					element:SetClass("expended", not costInfo.canAfford)

					local activeReactionFlashTime = nil
					local activeReaction = false
					if token.properties:has_key("activeReactions") then
						local tmp_reactionsCleared = token.properties:try_get("_tmp_reactionsCleared", {})
						for _,reaction in ipairs(token.properties.activeReactions) do
							if TimestampAgeInSeconds(reaction.timestamp) < 30 and reaction.ability == spell.name and (not tmp_reactionsCleared[reaction.guid]) then
								activeReaction = true
								local timeLeft = 30 - TimestampAgeInSeconds(reaction.timestamp)
								if activeReactionFlashTime == nil or timeLeft > activeReactionFlashTime then
									activeReactionFlashTime = timeLeft
								end
							end
						end
					end

					element:SetClass("activeReaction", activeReaction)
					if activeReaction then
						element.thinkTime = 0.3
						element.data.reactionFlashUntil = dmhub.Time() + activeReactionFlashTime
					else
						element.thinkTime = nil
						element.data.reactionFlashUntil = nil
					end
			
					targetInfo = {
						type = string.lower(spell.typeName),
						action = spell,
						execute = function(targetToken, info) --info has {targetEffects = {list of effect panels}}

							local exists = list_contains(m_targetsChosen, targetToken.id)

							for i,effect in ipairs(info.targetEffect) do
								effect:SetClass('target-selected', true)
                                effect:SetClass('two', false)
                                effect:SetClass('three', false)
							end
							if not exists then
								m_targetsChosen[#m_targetsChosen+1] = targetToken.id
								if firstTarget == nil then
									firstTarget = targetToken.id
								end

                                if m_markLineOfSight ~= nil and m_markLineOfSightToken ~= nil and m_markLineOfSightToken.id == targetToken.id then

                                    SetTargetLineOfSightRayForKey(string.format("%s-%s", m_markLineOfSightSourceToken.id, targetToken.id), m_markLineOfSight)

                                    m_markLineOfSight = nil
                                    m_markLineOfSightToken = nil
                                    m_markLineOfSightSourceToken = nil
                                end
							else
								if spell:CanTargetAdditionalTimes(token, currentSymbols, m_targetsChosen, targetToken) then
									m_targetsChosen[#m_targetsChosen+1] = targetToken.id
                                    local ntargets = 0
                                    for _,tokenid in ipairs(m_targetsChosen) do
                                        if tokenid == targetToken.id then
                                            ntargets = ntargets + 1
                                        end
                                    end

                                    for i,effect in ipairs(info.targetEffect) do
                                        effect:SetClass('two', ntargets >= 2)
                                        effect:SetClass('three', ntargets >= 3)
                                    end

								else
                                    RemoveLineOfSightRaysTargetingToken(targetToken.id)
									local newTargetsChosen = {}
									for _,tokenid in ipairs(m_targetsChosen) do
										if tokenid ~= targetToken.id then
											newTargetsChosen[#newTargetsChosen+1] = tokenid
										end
									end
									m_targetsChosen = newTargetsChosen

									if firstTarget == targetToken.id then
										firstTarget = m_targetsChosen[1]
									end
									for i,effect in ipairs(info.targetEffect) do
										effect:SetClass('target-selected', false)
									end
								end
							end

							CalculateSpellTargeting()
						end,
					}
				end,

				refreshActionbar = function(element, newToken)
					costInfo = spell:GetCost(newToken)
					spellPanel:SetClass("expended", not costInfo.canAfford)
					iconPanel:SetClass("expended", not costInfo.canAfford)
					hotkeyLabel:SetClass("expended", not costInfo.canAfford)
				end,

				hover = function(element)
					if ActionBar.spellInfoOnClick and currentSpell ~= nil and (not spellOptions.synthesized) then
						return
					end

					if spellOptions.invoking then
						return
					end

					for _,reaction in ipairs(token.properties:try_get("activeReactions", {})) do
						local tmp_reactionsCleared = token.properties:try_get("_tmp_reactionsCleared", {})
						if TimestampAgeInSeconds(reaction.timestamp) < 30 and reaction.ability == spell.name and (not tmp_reactionsCleared[reaction.guid]) then
							for _,target in ipairs(reaction.targets) do
								if target.tokenid ~= nil then
									local targetToken = dmhub.GetTokenById(target.tokenid)
									if targetToken ~= nil then
										local line = dmhub.HighlightLine{
											a = token.pos,
											b = targetToken.pos,
											floorIndex = token.floorIndex,
											color = "red",
										}
										element.data.reactionTraces = element.data.reactionTraces or {}
										element.data.reactionTraces[#element.data.reactionTraces+1] = line
									end
								end
							end
						end
					end

					if element:HasClass("editing") then
						element.tooltipParent = nil
					else
						element.tooltipParent = actionBarResultPanel
					end

                    element:FireEvent("showtooltip")
				end,

                showtooltip = function(element)
					local tooltip = CreateAbilityTooltip(spell:GetActiveVariation(token), {token = token, width = 540})
					if tooltip ~= nil then
						if element:HasClass("editing") then
							tooltip.selfStyle.halign = "right"
							tooltip.selfStyle.valign = "center"
							element.tooltip = tooltip
						else
							tooltip.selfStyle.halign = "center"
							tooltip.selfStyle.valign = "top"

							element.data.spellInfoDisplay = tooltip
							m_currentSpellPanel.children = {tooltip}
						end
					end
                end,

				dehover = function(element)
					if element.data.reactionTraces ~= nil then
						for _,line in ipairs(element.data.reactionTraces) do
							line:Destroy()
						end

						element.data.reactionTraces = nil
					end

					if element.data.spellInfoDisplay ~= nil and ((not element:HasClass("focus")) or ActionBar.spellInfoOnClick == false) then
						if element.data.spellInfoDisplay.valid then
							element.data.spellInfoDisplay:DestroySelf()
						end
						element.data.spellInfoDisplay = nil
					end
				end,

				focus = function(element)
					if spell == nil then
						return
					end

                    actionBar:FireEventTree("closeDrawers")

					if spellOptions.forceCasterToken ~= nil and (not spellOptions.adoptCasterToken) then
						tokenInfo:PushSelectedTokenOverride(spellOptions.forceCasterToken)
					end

					element:FireEvent("clearreactions")

					if element.data.spellInfoDisplay == nil or element.data.spellInfoDisplay.valid == false and (not spellOptions.invoking) then
						element:FireEvent("hover")
					end

					m_targetsChosen = {}
					firstTarget = nil

					currentSpell = spell:GetActiveVariation(token)
					spellRange = nil

					self.castingSpell = true

                    local variations = spell:GetVariations(token)
                    if variations ~= nil then
                        if element.data.variationsPanel == nil then
                            local p = gui.Panel{
                                floating = true,
                                flow = "horizontal",
                                halign = "center",
                                valign = "bottom",
                                y = -100,
                                height = "auto",
                                width = "auto",
                            }

                            element.data.variationsPanel = p
                            element:AddChild(p)
                        end

                        local activeVariation = spell:GetActiveVariation(token)

                        local panels = {}
                        for _,v in ipairs(variations) do
                            panels[#panels+1] = gui.Panel{
                                classes = {"slot", cond(v == activeVariation, "active", "expended")},
                                click = function(element)
                                end,
                                press = function(element)
                                    spell:SetActiveVariation(token, v)
                                    element.parent:FireEventTree("refresh")
                                    spellPanel:FireEventTree("showtooltip")
                                    spellPanel:FireEvent("defocus")
                                    spellPanel:FireEvent("focus")
                                end,
                                refresh = function(element)
                                    if token ~= nil and token.valid then
                                        local active = (spell:GetActiveVariation(token) == v)
                                        element:SetClass("active", active)
                                        element:SetClass("expended", not active)
                                    end
                                end,

                                gui.Panel{
                                    classes = {"icon", "spellIcon", "noadd"},
                                    bgimage = v:GetTypeIconForActionBar(),
                                },
                            }
                        end

                        element.data.variationsPanel.children = panels
                        element.data.variationsPanel:SetClass("hidden", false)
                    elseif element.data.variationsPanel ~= nil then
                        element.data.variationsPanel:DestroySelf()
                        element.data.variationsPanel = nil
                    end


					castButton.events.click = function(element)
						if spell.targetType == 'all' or spell.targetType == 'map' then
							--for 'all' types we have a fake map press. The map parameters don't matter.
							spellPanel:FireEvent("mappress")
						else
							CalculateSpellTargeting(true)
						end
					end

					skipButton.events.click = function(element)
						spellPanel:FireEvent('cancel')
					end

					currentCostProposal = spell:GetCost(token, {mode = currentSymbols.mode or 1})
					if not spellOptions.invoking then
						currentSymbols = { mode = 1, charges = spell:DefaultCharges() }
						currentSymbols.upcast = Spell.CalculateUpcast(currentCostProposal).upcast
						currentSymbols.dicefaces = ActivatedAbility.CalculateDiceFaces(currentCostProposal)

						if spellOptions.synthesized and spellOptions.cast ~= nil then
							--synthesized spells try to pass casting info through.
							currentSymbols.cast = spellOptions.cast
						end
					end
					CurrentCalculateSpellTargeting = CalculateSpellTargeting
					resourcesBar:FireEventTree("cost", currentCostProposal)

					if spell:GetCastingEmote() ~= nil then
						castingEmoteSet = spell:GetCastingEmote()
						token.properties:Emote(castingEmoteSet, {start = true, ttl = 20})
					end

					if spell.targetType ~= 'all' and spell.targetType ~= 'none' then
						token.lookAtMouse = true
					end


					resourcesBar:FireEventTree("focusspell")
					--actionResourcesBar:FireEventTree("focusspell")
					castSpellLevelPanel:FireEventTree("focusspell")
					channeledResourcePanel:FireEventTree("focusspell")

					if currentSpell == nil then
						--calculating spell targeting failed/resulted in deselecting the spell.
						return
					end

					local casterLocOverride = spell:try_get("casterLocOverride")
					element.captureEscape = true

                    local potentialTargetTokens = {}

					CalculateSpellTargetFocusing = function(range)
						local spell = currentSpell
						if (spell.targetType == 'self' or spell.targetType == 'target' or spell.targetType == 'all') and synthesizedSpellsPanel:HasClass("collapsed") then
							for k,targetToken in pairs(self.tokenInfo.tokens) do
								if targetToken.sheet.data.targetInfo ~= nil then
									targetToken.sheet:FireEvent('untarget')
								end

								local canTarget = true
								if (spell.targetType == 'self' or spell.targetType == 'all') and targetToken.properties ~= creature then
									canTarget = false
								end

								if creature == targetToken.properties and (spell.targetType == 'target' or spell.targetType == 'all') and spell:try_get("selfTarget", false) == false then
									canTarget = false
								end

								if currentSymbols ~= nil and currentSymbols.forbiddentargets ~= nil and currentSymbols.forbiddentargets[targetToken.charid] then
									canTarget = false
								end

								if canTarget and not spell:TargetPassesFilter(token, targetToken, currentSymbols) then
									canTarget = false
								end

								if canTarget then
									--give us an extra square of range to account for diagonals.
									local valid = range+dmhub.unitsPerSquare > targetToken:Distance(casterLocOverride or token)

									targetToken.sheet.data.targetInfo = targetInfo
									targetToken.sheet:FireEvent('target', { classes = cond(valid, {}, {'invalid'}) })

                                    potentialTargetTokens[#potentialTargetTokens+1] = targetToken
								end
							end
						end
					end

					CalculateSpellTargeting()

					if (spell.targetType == "emptyspace" or spell.targetType == "anyspace") and spell:try_get("targeting", "direct") == "pathfind" then
						ClearRadiusMarkers()
						radiusMarkers[#radiusMarkers+1] = token:MarkMovementRadius(spellRange)
					end


					if spell.targetType ~= 'self' and spell.targetType ~= 'target' and spell.targetType ~= 'all' then
						--make this get map events.
						element.mapfocus = true
					end

                    if (spell.targetType == "self" and spell.castImmediately) or (spell.targetType == "target" and #potentialTargetTokens == 0 and spell.castImmediately) then
                        castButton:FireEvent("click")
                    end

                    print("TARGET::", spell.targetType, #potentialTargetTokens, spell.castImmediately)
                    if spell.targetType == "target" and #potentialTargetTokens == 1 and spell.castImmediately then
                        print("TARGET:: IMMEDIATE!!")
                        element:FireEvent("highlightTargetToken", potentialTargetTokens[1])
                        potentialTargetTokens[1].sheet.data.targetInfo.execute(potentialTargetTokens[1], {targetEffect = {}})
                    end
				end,

				defocus = function(element)

                    if element.data.variationsPanel ~= nil then
                        element.data.variationsPanel:SetClass("hidden", true)
                    end

					--get rid of the spell info.
					if element.data.spellInfoDisplay ~= nil and (not element:HasClass("hover")) then
						if element.data.spellInfoDisplay.valid then
							element.data.spellInfoDisplay:DestroySelf()
						end
						element.data.spellInfoDisplay = nil
					end


					CalculateSpellTargetFocusing = nil

					if showingMovementArrow then
						showingMovementArrow = false
						token:ClearMovementArrow()
					end

					element:FireEvent("unhighlightTargetToken")
					self.castingSpell = false
					currentSpell = nil
					spellRange = nil

                    FreeTargetLineOfSightRays()

					SetTargetsInRadius{}
					element.mapfocus = false
					castButton:SetClass('collapsed', true)
					skipButton:SetClass('collapsed', true)
					castMessage.data.promptText = nil
					castMessageContainer:SetClass('collapsed', true)
					castSpellLevelPanel:SetClass('collapsed', true)
					channeledResourcePanel:SetClass('collapsed', true)
					castChargesInput:SetClass('collapsed', true)
					castModesPanel:SetClass('collapsed', true)
					synthesizedSpellsPanel:SetClass('collapsed', true)
					ammoChoicePanel:FireEvent("refreshSpell", nil)
					element.data.targetToken = nil
					CurrentCalculateSpellTargeting = nil

					castChargesInput.text = ""

					if token ~= nil then
						token.lookAtMouse = false
					end

					if token ~= nil and token.valid and castingEmoteSet ~= nil then
						local emote = castingEmoteSet
						local tok = token
						tok.properties:Emote(emote, {start = false, ttl = 20})

						castingEmoteSet = nil
					end

					resourcesBar:FireEventTree("defocusspell")
					--actionResourcesBar:FireEventTree("defocusspell")
					castSpellLevelPanel:FireEventTree("defocusspell")
					channeledResourcePanel:FireEventTree("defocusspell")

					currentCostProposal = nil
					currentSymbols = { mode = 1, charges = 1 }

					element.captureEscape = false
					for k,token in pairs(self.tokenInfo.tokens) do
						if token.sheet.data.targetInfo == targetInfo then
							token.sheet:FireEvent('untarget')
							token.sheet.data.targetInfo = nil
						end
					end

					ClearRadiusMarkers()
					if pointTargetRadius ~= nil then
						pointTargetRadius:Destroy()
						pointTargetRadius = nil
					end

					if m_pointTargetFallingShape ~= nil then
						m_pointTargetFallingShape:Destroy()
						m_pointTargetFallingShape = nil
					end

					if pointTargetRadiusPathEnd ~= nil then
						for _,marker in ipairs(pointTargetRadiusPathEnd) do
							marker:Destroy()
						end

						pointTargetRadiusPathEnd = nil
					end

					if gameUpdateCameWhileCastingSpell then
						actionBar:FireEvent("refreshGame")
					end

					if spellOptions.forceCasterToken ~= nil then
						tokenInfo:PopSelectedTokenOverride(spellOptions.forceCasterToken)
					end

					if spellOptions.destroyOnDefocus then
						element:DestroySelf()
					end
				end,

				highlightTargetToken = function(element, targetToken)
					element:FireEvent("unhighlightTargetToken")

                    local targets = BuildTargetsList()
                    targets[#targets+1] = {
                        token = targetToken,
                        loc = targetToken.loc,
                    }

					local range = spell:GetRange(token.properties, currentSymbols)
                    local rays = currentSpell:GetTargetingRays(token, range, currentSymbols, targets)
                    if rays ~= nil then
                        --the ability specifies the rays, we try to fish out the
                        --new one to highlight and maintain any existing ones.
                        for _,ray in ipairs(rays) do
                            if ray.b.id == targetToken.id and m_targetLineOfSightRays[string.format("%s-%s", ray.a.id, ray.b.id)] == nil then
                                m_markLineOfSight = dmhub.MarkLineOfSight(ray.a, ray.b)
                                m_markLineOfSightToken = targetToken
                                m_markLineOfSightSourceToken = token
                                break
                            end
                        end
                    else
                        --we just target from the source to the target.
                        m_markLineOfSight = dmhub.MarkLineOfSight(token, targetToken)
                        if m_markLineOfSight ~= nil then
                            m_markLineOfSightToken = targetToken
                            m_markLineOfSightSourceToken = token
                        end
                    end

				end,

				unhighlightTargetToken = function(element, targetToken)
					if m_markLineOfSight ~= nil and (targetToken == nil or targetToken == m_markLineOfSightToken) then
						m_markLineOfSight:Destroy()
						m_markLineOfSight = nil
						m_markLineOfSightToken = nil
                        m_markLineOfSightSourceToken = nil
					end
				end,

				click = function(element)
					if element:HasClass('focus') then
						self:SetFocus(nil)
					else
						self:SetFocus(element)
					end
				end,

				rightClick = function(element)
					local entries = {}
					entries[#entries+1] = {
						text = 'Share to Chat',
						click = function()
							element.popup = nil

							if spell.typeName == "Spell" then
								chat.ShareObjectInfo('Spells', spell.id)
							else
								chat.ShareObjectInfo(nil, nil, { charid = token.charid, ability = spell })
							end
						end,
					}

					if spell:try_get("attackOverride") ~= nil and spell.attackOverride:try_get("weaponid") ~= nil then
						local itemsTable = dmhub.GetTable("tbl_Gear")
						if itemsTable[spell.attackOverride.weaponid] ~= nil then
							entries[#entries+1] = {
								text = "Share Weapon to Chat",
								click = function()
									element.popup = nil

									chat.ShareObjectInfo("tbl_Gear", spell.attackOverride.weaponid)
								end,
							}
						end
					end

					--offer rolls.
					local shareableRolls = spell:GetShareableRolls()
					for _,roll in ipairs(shareableRolls) do
						entries[#entries+1] = {
							text = roll.text,
							click = function()
								element.popup = nil

								dmhub.Roll{
									roll = roll.roll,
									description = roll.description,
									tokenid = token.charid,
								}
							end,
						}
					end

					--offer restoration of an ability that has been expended.
					local spellCost = spell:GetCost(token)
					if spellCost ~= nil then
						for _,entry in ipairs(spellCost.details) do
							if entry.description ~= nil and entry.maxCharges ~= nil and entry.availableCharges ~= nil and entry.availableCharges < entry.maxCharges then
								local multi = entry.maxCharges > entry.availableCharges + 1
								entries[#entries+1] = {
									text = cond(multi, "Refresh One Charge", "Refresh Charges"),
									click = function()
										element.popup = nil
										token:ModifyProperties{
											description = "Refresh charges",
											execute = function()
												token.properties:RefreshResource(entry.cost, entry.refreshType)
											end,
										}
									end,
								}

								if multi then
									entries[#entries+1] = {
										text = "Refresh All Charges",
										click = function()
											element.popup = nil
											token:ModifyProperties{
												description = "Refresh charges",
												execute = function()
													token.properties:RefreshResource(entry.cost, entry.refreshType, true)
												end,
											}
										end,
									}
								end

							end
						end
					end


					local concentration = token.properties:HasConcentration() and token.properties.concentration:try_get("auraid") == spell:try_get("auraid")
					if concentration then
						entries[#entries+1] = {
							text = "Cancel Concentration",
							click = function()
								token:ModifyProperties{
									description = "Cancel concentration",
									execute = function()
										token.properties:CancelConcentration()
									end,
								}

								element.popup = nil
							end,
						}
					end

					if #entries > 0 then
						element.popup = gui.ContextMenu{
							entries = entries,
						}
					end
				end,

				create = function(element)
					element.data.created = true
				end,

				clickaway = function(element)
					if (not element.data.created) or dmhub.tokenHovered ~= nil and dmhub.tokenHovered.sheet ~= nil and dmhub.tokenHovered.sheet.data ~= nil and dmhub.tokenHovered.sheet.data.targetInfo ~= nil then
						return
					end

					if gui.GetFocus() == element and (spell.targetType == 'all' or spell.targetType == 'self' or spell.targetType == 'target') then
						gui.SetFocus(nil)
					end
				end,

				cancel = function(element)
					if gui.GetFocus() == element then
						gui.SetFocus(nil)
					end
				end,

				escape = function(element)

					element:FireEvent('cancel')
				end,

				destroy = function(element)
					if gui.GetFocus() == element then
						gui.SetFocus(nil)
					end
					if pointTargetRadius ~= nil then
						pointTargetRadius:Destroy()
						pointTargetRadius = nil
					end
					if m_pointTargetFallingShape ~= nil then
						m_pointTargetFallingShape:Destroy()
						m_pointTargetFallingShape = nil
					end
					if pointTargetRadiusPathEnd ~= nil then
						for _,marker in ipairs(pointTargetRadiusPathEnd) do
							marker:Destroy()
						end
						pointTargetRadiusPathEnd = nil
					end
				end,


				--map events that we get when in point targeting mode.
				maphover = function(element, loc, point)
					if not token.valid then
						spellPanel:FireEvent('cancel')
					end

					local targetColor = "white"
					local clearMovementArrow = showingMovementArrow
					local prevShape = pointTargetShape
					if m_pointTargetFallingShape ~= nil then
						m_pointTargetFallingShape:Destroy()
						m_pointTargetFallingShape = nil
					end
					local destroyRadiusPathEnd = pointTargetRadiusPathEnd ~= nil
					if point ~= nil then
						local radius = spell:try_get("radius")
						local shape = spell.targetType
						local requireEmpty = false

						local locOverride = spell:try_get("casterLocOverride")

						if (shape == 'emptyspace' or shape == 'anyspace') and currentSpell:try_get("targeting", "direct") == "pathfind" then
							token:MarkMovementArrow(loc)
							showingMovementArrow = true
							clearMovementArrow = false
						elseif (shape == 'emptyspace' or shape == 'anyspace') and (currentSpell:try_get("targeting", "direct") == "straightline" or currentSpell:try_get("targeting", "direct") == "straightpath") then
							local movementInfo = token:MarkMovementArrow(loc, {straightline = true })
							showingMovementArrow = true
							clearMovementArrow = false

							if movementInfo ~= nil then
								local path = movementInfo.path
								local abilityDist = spell:GetRange(token.properties, currentSymbols)/dmhub.unitsPerSquare
								local requestDist = math.min(loc:DistanceInTiles(path.origin), abilityDist)
								local pathDist = path.destination:DistanceInTiles(path.origin)

								if pathDist < requestDist and currentSpell:try_get("targeting", "direct") == "straightline" then
									local prevOvershoot = pointTargetPathEndOvershoot
									pointTargetPathEndOvershoot = abilityDist - pathDist

									local prevPathEnd = pointTargetShapePathEnd
									destroyRadiusPathEnd = false

									targetColor = "#00000000"

									local destPoint = path.destination.point3
									if token.creatureDimensions.x%2 == 0 then
										local offset = (token.creatureDimensions.x-1)*0.5
										destPoint = core.Vector3(destPoint.x+offset, destPoint.y+offset, destPoint.z)
									end


									pointTargetShapePathEnd = {
										dmhub.CalculateShape{
											shape = cond(token.creatureDimensions.x%2 == 1, "radius", "cylinder"),
											token = token,
											targetPoint = destPoint,
											range = spell:GetRange(token.properties, currentSymbols),
											radius = token.creatureDimensions.x*dmhub.unitsPerSquare*0.5,
										}
									}

									local textLabels = {}
									textLabels[#textLabels+1] = {
										point = destPoint,
										text = string.format("-%d<color=#00000000>-</color>", pointTargetPathEndOvershoot),
									}

									for _,collideToken in ipairs(movementInfo.collideWith or {}) do
										local targetPoint = collideToken:PosAtLoc()
										pointTargetShapePathEnd[#pointTargetShapePathEnd+1] = dmhub.CalculateShape{
											shape = cond(collideToken.creatureDimensions.x%2 == 1, "radius", "radiusfromintersection"),
											token = collideToken,
											targetPoint = collideToken:PosAtLoc(),
											range = 0,
											radius = collideToken.creatureDimensions.x*dmhub.unitsPerSquare*0.5,
										}

										textLabels[#textLabels+1] = {
											point = collideToken:PosAtLoc(),
											text = string.format("-%d<color=#00000000>-</color>", pointTargetPathEndOvershoot),
										}
									end

									local needRedraw = prevPathEnd == nil or #prevPathEnd ~= #pointTargetShapePathEnd or prevOvershoot ~= pointTargetPathEndOvershoot
									if not needRedraw then
										for i,loc in ipairs(prevPathEnd) do
											if not loc:Equal(pointTargetShapePathEnd[i]) then
												needRedraw = true
												break
											end
										end

									end

									if needRedraw then

										if pointTargetRadiusPathEnd ~= nil then
											for _,marker in ipairs(pointTargetRadiusPathEnd) do
												marker:Destroy()
											end
											pointTargetRadiusPathEnd = nil
										end

										pointTargetRadiusPathEnd = {}
										for i,loc in ipairs(pointTargetShapePathEnd) do
											pointTargetRadiusPathEnd[#pointTargetRadiusPathEnd+1] = pointTargetShapePathEnd[i]:Mark{ color = "red", video = "divinationline.webm", showLocs = false }
										end

										for i,info in ipairs(textLabels) do
											pointTargetRadiusPathEnd[#pointTargetRadiusPathEnd+1] = dmhub.CreateCanvasOnMap{
												point = info.point,
												sheet = gui.Label{
													interactable = false,
													halign = "center",
													valign = "center",
													color = "red",
													width = "auto",
													height = "auto",
													fontSize = 0.5,
													text = info.text,
												}
											}
										end
									end
								end

								--falling.
								local fallInfo = token:GetFallInfoFromLoc(loc)
								if fallInfo ~= nil then
									local fallShape = dmhub.CalculateShape{
										shape = "radius",
										token = token,
										locOverride = fallInfo.loc,
										targetPoint = token:PosAtLoc(fallInfo.loc),
										radius = token.creatureDimensions.x*dmhub.unitsPerSquare*0.5,
									}

									m_pointTargetFallingShape = fallShape:Mark{ color = "red", video = "divinationline.webm" }
								end


							end
						end

						if point == 'all' then
							--this is for the 'all' target type, targeting within the caster.
							radius = spell:GetRange(token.properties, currentSymbols)
							point = nil
							shape = "RadiusFromCreature"
						end
						if shape == 'emptyspace' or shape == 'emptyspacefriend' or shape == 'anyspace' then
							radius = dmhub.unitsPerSquare*0.5
							requireEmpty = (shape == 'emptyspace')

							if (shape == "emptyspace" or shape == "anyspace") then

								radius = token.creatureDimensions.x*dmhub.unitsPerSquare*0.5
								if token.creatureDimensions.x%2 == 1 then
									shape = "radius"
								else
									--if we are an even number of tiles wide, we want to target a tile intersection
									--we offset the target point to match creature movement behavior.
									shape = "cylinder"
									local offset = (token.creatureDimensions.x-1)*0.5
									point = core.Vector3(point.x+offset, point.y+offset, point.z)
								end
							else
								shape = "radius"
							end
						end

						pointTargetShape = dmhub.CalculateShape{
							shape = shape,
							token = token,
							targetPoint = point,
							range = spell:GetRange(token.properties, currentSymbols),
							radius = radius,
							locOverride = spell:try_get("casterLocOverride"),
							requireEmpty = requireEmpty,
						}
                    elseif spell.targetType == "map" then
                        pointTargetShape = dmhub.CalculateShape{
                            shape = "map",
                            token = token,
                        }
					else
						pointTargetShape = nil
					end

					local targetTokens = self.tokenInfo.TokensInShape(pointTargetShape)
					local filteredTargets = {}
					for k,tok in pairs(targetTokens) do
						if spell:TargetPassesFilter(token, tok, currentSymbols) then
							filteredTargets[k] = tok
						end
					end
					SetTargetsInRadius(filteredTargets)

					if pointTargetRadius ~= nil then
						if pointTargetShape ~= nil and pointTargetShape:Equal(prevShape) then
							--shape unchanged.
							--return
						end

						pointTargetRadius:Destroy()
						pointTargetRadius = nil
					end

					if pointTargetShape ~= nil then
						local video = "divinationline.webm"
						local school = string.lower(spell:try_get("school", ""))
						if school == "Evocation" then
							video = "fire-radius.webm"
						elseif school == "Illusion" then
							video = "illusionline.webm"
						end

						pointTargetRadius = pointTargetShape:Mark{ color = targetColor, video = video }
					end

					if clearMovementArrow and token ~= nil then
						token:ClearMovementArrow()
						showingMovementArrow = false
					end

					if destroyRadiusPathEnd then

						for _,marker in ipairs(pointTargetRadiusPathEnd) do
							marker:Destroy()
						end

						pointTargetRadiusPathEnd = nil
						pointTargetShapePathEnd = nil
					end
				end,

				mappress = function(element, loc, point)
					if pointTargetShape ~= nil then
						local targets = {}

						if spell.targetType == 'emptyspace' or spell.targetType == 'emptyspacefriend' or spell.targetType == 'anyspace' then
							targets[#targets+1] = { loc = loc }
						else
							for k,target in pairs(pointForceTargets) do
								if spell.targetType ~= 'all' or target ~= token or currentSpell:try_get("selfTarget", false) then
									targets[#targets+1] = { loc = target.loc, token = target }
								end
							end
						end
						token.lookAtMouse = false
						if castingEmoteSet and token.valid then
							token.properties:Emote(castingEmoteSet .. 'cast', {start = true, ttl = 20})
						end

						if currentSpell.sequentialTargeting and currentSymbols.targetnumber == nil then
							currentSymbols.targetnumber = 1
							currentSymbols.targetcount = currentSpell:GetNumTargets(token, currentSymbols)
						end

                        targets = currentSpell:PrepareTargets(token, currentSymbols, targets)

                        if m_markLineOfSight ~= nil then
                            SetTargetLineOfSightRayForKey(string.format("%s-%s", m_markLineOfSightSourceToken.id, m_markLineOfSightToken.id), m_markLineOfSight)
                            m_markLineOfSight = nil
                            m_markLineOfSightToken = nil
                            m_markLineOfSightSourceToken = nil
                        end

						g_profileCast:Begin()
						currentSpell:Cast(token, targets, {
							targetArea = pointTargetShape,
							costOverride = currentCostProposal,
							symbols = currentSymbols,
							markLineOfSight = m_targetLineOfSightRays,
						})
						g_profileCast:End()

                        m_targetLineOfSightRays = {}

						m_markLineOfSight = nil
						m_markLineOfSightToken = nil
                        m_markLineOfSightSourceToken = nil
						spellPanel:FireEvent('cancel')
					end
				end,

				CreateFocusPanel(),

				iconPanel,
                typeIconPanel,

				anonymousCostPanel,
				consumableCostChild,
				hotkeyLabel,
			}
		end

		if spellIndex ~= nil and spellPanel ~= nil then
			m_spellPanels[spellCategory][spellIndex] = spellPanel
		end

		spellPanel:FireEventTree("refreshSpell", spellObj)
		return spellPanel
	end

	local styles = SlotStyles

	m_currentSpellPanel = gui.Panel{
		halign = "center",
		valign = "center",
		width = "auto",
		height = "auto",
	}

	skipButton = gui.PrettyButton{
		halign = "center",
		width = 120,
		height = 60,
		fontSize = 22,
		text = "Skip",
		classes = { 'collapsed' },
		events = {},
	}

	castButton = gui.PrettyButton{
		halign = "center",
		width = 120,
		height = 60,
		fontSize = 22,
		text = "Cast",
		classes = { 'collapsed' },
		events = {},
	}

	castMessage = gui.Label{
		data = {
			promptText = '',
		},
		halign = "center",
		width = "auto",
		minWidth = 200,
		textAlignment = "center",
		height = "auto",
		bold = true,
		fontSize = 16,
		classes = { 'collapsed' },
		refresh = function(element)
			if element.data.promptText == nil or element.data.promptText == "" then
				castMessageContainer:SetClass("collapsed", true)
				return
			end

			local upcast = ''

			local upcastInfo = Spell.CalculateUpcast(currentCostProposal)
			if upcastInfo ~= nil and upcastInfo.upcast > 0 then
				upcast = string.format(" (Upcast %d, to level %d)", upcastInfo.upcast, upcastInfo.level)
			end

			element.text = string.format("%s%s", element.data.promptText, upcast)

			castMessageContainer:SetClass("collapsed", element.text == "")
		end,
	}

	castMessageContainer = gui.TooltipFrame(castMessage, {
	})

	castSpellLevelPanel = gui.Panel{
		classes = {"collapsed"},
		width = "auto",
		height = 20,
		flow = "horizontal",
		halign = "center",
		valign = "center",

		styles = {
			{
				selectors = {"levelPanel"},
				width = 16,
				height = 16,
				hmargin = 2,
				valign = "center",
				fontSize = 14,
				color = Styles.textColor,
				textAlignment = "center",
				borderWidth = 1,
				bgimage = "panels/square.png",
				borderWidth = 1,
				borderColor = "#ffffff55",
				bgcolor = "#ffffff22",
			},
			{
				selectors = {"levelPanel", "invalid"},
				color = "red",
				borderColor = "#99999955",
				bgcolor = "#99999922",
			},
			{
				selectors = {"levelPanel", "~invalid", "hover"},
				borderColor = "#ffffffaa",
			},
			{
				selectors = {"levelPanel", "selected"},
				borderColor = "#ffffffff",
				borderWidth = 2,
			},
		},

		data = {
			children = {},
		},
		create = function(element)
			element.data.children = {}
			for i=1,GameSystem.maxSpellLevel do
				local index = i
				local panel = gui.Label{
					classes = {"levelPanel"},
					text = tostring(i),
					press = function(element)
						if element:HasClass("invalid") == false then
							castSpellLevelPanel:FireEvent("select", index)
						end
					end,
				}
				element.data.children[#element.data.children+1] = panel
			end

			element.children = element.data.children
		end,

		select = function(element, level)

			for i,info in ipairs(currentCostProposal.details) do
				if #info.paymentOptions > 0 and info.paymentOptions[1].level ~= nil then
					--this is a payment option that controls upcasting.
					local currentOption = info.paymentOptions[1]
					local index = nil

					--try to find a related resource firstly.
					for j,option in ipairs(info.paymentOptions) do
						if j > 1 and option.level == level and CharacterResource.Related(option.resourceid, currentOption.resourceid) then
							index = j
							break
						end
					end

					if index == nil then
						--now find any resource since we didn't find a related one.
						for j,option in ipairs(info.paymentOptions) do
							if j > 1 and option.level == level then
								index = j
							end
						end
					end

					if index ~= nil then
						--move the option we found to the front.
						local option = info.paymentOptions[index]
						table.remove(info.paymentOptions, index)
						table.insert(info.paymentOptions, 1, option)
						break
					end
				end
			end

			--recalculate with the new cost proposal.
			currentSymbols.upcast = Spell.CalculateUpcast(currentCostProposal).upcast
			currentSymbols.dicefaces = ActivatedAbility.CalculateDiceFaces(currentCostProposal)
			CurrentCalculateSpellTargeting()
			castMessage:FireEvent("refresh")
			castModesPanel:FireEvent("refreshModes")
			
			for i,bar in ipairs(resourcePanels) do
				bar:FireEventTree("focusspell")
			end

			castSpellLevelPanel:FireEventTree("focusspell")
			channeledResourcePanel:FireEventTree("focusspell")

		end,

		focusspell = function(element)
			if currentSpell == nil or (not currentSpell.isSpell) then
				element:SetClass("collapsed", true)
				return
			end

			if currentSpell:try_get("spellcastingFeature") ~= nil and currentSpell.spellcastingFeature.upcastingType ~= "cast" then
				element:SetClass("collapsed", true)
				return
			end

			local castingLevel = currentSpell.level + (currentSymbols.upcast or 0)
			local availableLevels = {}
			local validLevels = {}
			for _,entry in ipairs(currentCostProposal.details) do
				for _,option in ipairs(entry.paymentOptions) do
					if option.level ~= nil then
						availableLevels[option.level] = true
						validLevels[option.level] = true
					end
				end

				for _,option in ipairs(entry.expendedOptions) do
					if option.level ~= nil then
						availableLevels[option.level] = true
					end
				end

			end

			element:SetClass("collapsed", false)
			for i,p in ipairs(element.data.children) do
				p:SetClass("collapsed", not availableLevels[i])
				p:SetClass("invalid", not validLevels[i])
				p:SetClass("selected", i == castingLevel)
			end
		end,
		defocusspell = function(element)
			element:SetClass("collapsed", true)
		end,

	}

	local channeledResourceTitle = gui.Label{
		text = "Channeled Resource",
		fontSize = 14,
		markdown = true,
		color = Styles.textColor,
		halign = "center",
		valign = "top",
		width = "auto",
		maxWidth = 800,
		height = 24,
	}

	local channeledResourceContainer = gui.Panel{
		flow = "horizontal",
		width = "auto",
		height = "auto",
		halign = "center",
	}

	channeledResourcePanel = gui.Panel{
		classes = {"collapsed"},
		width = "auto",
		height = "auto",
		vpad = 8,
		hpad = 16,
		borderFade = true,
		borderWidth = 12,
		tmargin = 2,
		bmargin = 2,
		flow = "vertical",
		halign = "center",
		valign = "center",
		bgimage = "panels/square.png",
		bgcolor = "#00000088",
		borderColor = "#00000088",

		channeledResourceTitle,
		channeledResourceContainer,

		data = {
			children = {},
		},

		styles = {
			{
				selectors = {"levelPanel"},
				width = 16,
				height = 16,
				hmargin = 2,
				valign = "center",
				fontSize = 14,
				color = Styles.textColor,
				textAlignment = "center",
				borderWidth = 1,
				bgimage = "panels/square.png",
				borderWidth = 1,
				borderColor = "#ffffff55",
				bgcolor = "#ffffff22",
			},
			{
				selectors = {"levelPanel", "invalid"},
				color = "red",
				borderColor = "#99999955",
				bgcolor = "#99999922",
			},
			{
				selectors = {"levelPanel", "~invalid", "hover"},
				borderColor = "#ffffffaa",
			},
			{
				selectors = {"levelPanel", "selected"},
				borderColor = "#ffffffff",
				borderWidth = 2,
			},
		},

		focusspell = function(element)
			if currentSpell == nil or currentSpell.channeledResource == "none" then
				element:SetClass("collapsed", true)
				return
			end

			local resourcesTable = dmhub.GetTable(CharacterResource.tableName) or {}
			local resource = resourcesTable[currentSpell.channeledResource]
			if resource == nil then
				element:SetClass("collapsed", true)
				return
			end

			local resources = token.properties:GetResources()[resource.id] or 0
			local resourcesAvailable = resources - token.properties:GetResourceUsage(resource.id, resource.usageLimit)
			local baseCost = 0
			if currentSpell.resourceCost == currentSpell.channeledResource then
				--what we are channeling is also the base cost of the spell, so factor that in.
				resourcesAvailable = resourcesAvailable - currentSpell.resourceNumber
				baseCost = currentSpell.resourceNumber
			end

			if resourcesAvailable <= 0 then
				element:SetClass("collapsed", true)
				return
			end


			channeledResourceTitle.text = currentSpell.channelDescription
			local channelIncrement = currentSpell:try_get("channelIncrement", "")
			channelIncrement = math.max(1, round(tonumber(channelIncrement) or 1))
			local maxChannel = currentSpell:MaxChannel(token.properties, currentSymbols)

			local added = false
			local children = element.data.children
			while #children*channelIncrement <= resourcesAvailable and #children*channelIncrement <= maxChannel do
				local nresources = #children*channelIncrement
				local panel = gui.Label{
					classes = {"levelPanel"},
					text = tostring(#children*channelIncrement),
					data = {
						nresources = nresources,
					},
					press = function(element)
						if element:HasClass("invalid") == false then
							channeledResourcePanel:FireEventTree("select", element.data.nresources)
						end
					end,
				}

				children[#children+1] = panel
				added = true
			end

			for i=1,#children do
				children[i].text = tostring(baseCost + (i-1)*channelIncrement)
				children[i].data.nresources = (i-1)*channelIncrement
				children[i]:SetClass("collapsed", (i-1)*channelIncrement > resourcesAvailable)
				children[i]:SetClass("selected", (i-1)*channelIncrement == currentSymbols.charges)
			end

			if added then
				element.data.children = children

				channeledResourceContainer.children = children
			end

			element:SetClass("collapsed", false)
		end,
		defocusspell = function(element)
			element:SetClass("collapsed", true)
		end,

		select = function(element, charges)

			--recalculate with the new cost proposal.
			currentCostProposal = currentSpell:GetCost(token, {charges = charges, mode = currentSymbols.mode})
			currentSymbols.charges = charges
			currentSymbols.upcast = Spell.CalculateUpcast(currentCostProposal).upcast
			currentSymbols.dicefaces = ActivatedAbility.CalculateDiceFaces(currentCostProposal)

			CurrentCalculateSpellTargeting()
			castMessage:FireEvent("refresh")
			castModesPanel:FireEvent("refreshModes")
			
			for i,bar in ipairs(resourcePanels) do
				bar:FireEventTree("focusspell")
			end

			castSpellLevelPanel:FireEventTree("focusspell")
			channeledResourcePanel:FireEventTree("focusspell")
		end,
	}

	castChargesInput = gui.Input{
		idprefix = "castChargesInput",
		classes = {'collapsed'},
		width = 180,
		height = 34,
		fontSize = 22,
		halign = "center",
		placeholderText = "Enter Charges...",
		edit = function(element)
			local charges = tonumber(element.text)
			if charges ~= nil then
				currentCostProposal = currentSpell:GetCost(token, {charges = charges, mode = currentSymbols.mode})
				currentSymbols.charges = charges
				currentSymbols.upcast = Spell.CalculateUpcast(currentCostProposal).upcast
				currentSymbols.dicefaces = ActivatedAbility.CalculateDiceFaces(currentCostProposal)
			end
		end,
		refreshSpell = function(element)
			if currentSpell == nil or currentSpell:MultiCharge() == false then
				element:SetClass("collapsed", true)
				return
			end

			element:SetClass("collapsed", false)
			if element.text == "" then
				element.hasInputFocus = true
			end
		end,
	}

	ammoChoicePanel = gui.Panel{
		idprefix = "ammoChoice",
		classes = {'collapsed'},
		width = "auto",
		height = "auto",
		halign = "center",
		valign = "center",
		flow = "horizontal",

		data = {
			baseSpell = nil
		},

		refreshSpell = function(element)
			
			if currentSpell == nil or currentSpell:try_get("attackOverride") == nil or currentSpell.attackOverride:try_get("ammoType") == nil then
				element:SetClass("collapsed", true)
				element.data.baseSpell = nil
				return
			end



			if element.data.baseSpell ~= nil then
				--no need for updates if we are still on the same spell.
				return
			end
			
			element.data.baseSpell = currentSpell

			local attack = currentSpell.attackOverride
			local ammoType = attack.ammoType

			local consumeAmmo = attack:try_get("consumeAmmo", {})

			local gearTable = dmhub.GetTable('tbl_Gear')

			local children = {}

			for k,entry in pairs(creature:try_get("inventory", {})) do
				local ammoid = k
				local itemInfo = gearTable[k]
				if itemInfo:try_get("equipmentCategory") == ammoType then
					local ammoPanel = gui.Panel{
						bgimage = 'panels/square.png',
						classes = {'slot', cond(consumeAmmo[k], "focus")},

						data = {
							ord = itemInfo:RarityOrd(),
						},

						gui.Panel{
							classes = {'spellIcon'},
							bgimage = itemInfo.iconid,
						},

						gui.Label{
							text = numtostr(entry.quantity, 0),
							hmargin = 2,
							vmargin = 2,
							fontSize = 12,
							width = "auto",
							height = "auto",
							halign = "right",
							valign = "top",
						},

						CreateFocusPanel(),

						press = function(element)
							for _,child in ipairs(children) do
								child:SetClass("focus", element == child)
							end

							local synthesizedSpell = DeepCopy(ammoChoicePanel.data.baseSpell)
							synthesizedSpell.temporaryClone = true
							
							if itemInfo:try_get("ammoAugmentation") then
								itemInfo:AmmoModifyAbility(creature, synthesizedSpell)
							end

							currentSpell = synthesizedSpell
							spellRange = nil
							synthesizedSpell.attackOverride.consumeAmmo = {[k] = 1}
							currentCostProposal = synthesizedSpell:GetCost(token)

							resourcesBar:FireEventTree("cost", currentCostProposal)

							CurrentCalculateSpellTargeting()
						end,

						linger = function(element)
							element.tooltip = CreateItemTooltip(itemInfo, {})
						end,
					}

					children[#children+1] = ammoPanel
				end
			end

			if #children == 0 then
				element:SetClass("collapsed", true)
				return
			end

			table.sort(children, function(a,b) return a.data.ord < b.data.ord end)

			element:SetClass("collapsed", false)
			element.children = children

			children[1]:FireEvent("press")
		end,
	}


	synthesizedSpellsPanel = gui.Panel{
		idprefix = "synthesizeSpellsPanel",
		classes = {'collapsed'},
		width = "auto",
		height = "auto",
		halign = "center",
		valign = "center",
		flow = "horizontal",
        uiscale = 0.7,

		data = {
			synthesized = nil
		},

		refreshSpell = function(element, addedSpellOptions)
			
			if currentSpell == nil then
				element:SetClass("collapsed", true)
				return
			end

			local synth = currentSpell:SynthesizeAbilities(creature)
			element.data.synthesized = synth
			if synth == nil then
				element:SetClass("collapsed", true)
				return
			end

			element:SetClass("collapsed", false)

			local children = {}
			for _,a in ipairs(synth) do
				local cast = nil
				if currentSymbols ~= nil then
					cast = currentSymbols.cast
				end

				local spellOptions = {
					synthesized = true,
					cast = cast,
				}
				for k,v in pairs(addedSpellOptions or {}) do
					spellOptions[k] = v
				end
				local panel = GetSpellPanel(nil, nil, a, spellOptions)
				
				children[#children+1] = panel
			end

			element.children = children
		end,
	}

	castModesPanel = gui.Panel{
		styles = Styles.AdvantageBar,
		classes = {'advantage-bar', 'collapsed'},
		width = "auto",
		maxWidth = 800,
		height = "auto",
		bgimage = "panels/square.png",
		bgcolor = "#000000bb",
		wrap = true,

		refreshModes = function(element)
			if currentSpell.multipleModes == false or currentSpell:try_get("modeList") == nil then
				element:SetClass("collapsed", true)
				return
			end

			local changeMode = false
			local children = {}

			for i,mode in ipairs(currentSpell.modeList) do
				local available = true
				if mode.condition ~= nil and mode.condition ~= "" then
					available = dmhub.EvalGoblinScriptDeterministic(mode.condition, token.properties:LookupSymbol(), 1, "Mode condition")
					available = type(available) == "number" and available > 0
				end

				if available then
					children[#children+1] = gui.Label{
						classes = {"advantage-element", cond(i == currentSymbols.mode, "selected")},
						text = mode.text,

						click = function(element)
							currentSymbols.mode = i
							currentCostProposal = currentSpell:GetCost(token, { mode = currentSymbols.mode })
							CurrentCalculateSpellTargeting()
							resourcesBar:FireEventTree("cost", currentCostProposal)
							castMessage:FireEvent("refresh")
							castModesPanel:FireEvent("refreshModes")
						end,
					}
				elseif i == currentSymbols.mode then
					changeMode = true
				end
			end

			if changeMode and #children > 0 then
				--need to force a mode change to an available mode.
				children[1]:ScheduleEvent("click", 0.05)
			end


			element.children = children

			element:SetClass("collapsed", false)
		end,
	}

	if ActionBar.hasCustomizationPanel then
		arrowPanel = gui.Panel{
			classes = {'arrow'},
			bgimage = 'panels/open-inventory-arrow.png',
			floating = true,
			selfStyle = {
				height = 54,
				width = 54,
				x = 10,
				y = -10,
				rotate = 180
			},
			events = {
				click = function(element)
					if dmhub.currentToken ~= nil then
						actionBar:FireEvent("edit")
						--self:ShowSpells(dmhub.currentToken, {})
					end
				end,
			},
		}
	end

	resourcePanels = {}

	local resourceStyles = {}


	local resourceSelectionStyles = {
		gui.Style{
			selectors = {"isoption"},
			borderWidth = 2,
			borderColor = "#ffffff77",
		},
		gui.Style{
			selectors = {"isselected"},
			borderWidth = 4,
			borderColor = "#ffffffff",
		},
		gui.Style{
			selectors = {"illegal"},
			borderWidth = 4,
			borderColor = "red",
		},
	}

	local CreateResourcesBar = function(resourceGroupings, options)
		local m_token = nil

		options = options or {}

		local iconSize = options.iconSize or 42
		options.iconSize = nil

		local resourceSize = options.resourceSize or 46
		options.resourceSize = nil

		local resourceGroupPanels = {}


		local resourceIconEvents = {
			linger = function(element)
				local resourceTable = dmhub.GetTable("characterResources") or {}
				local resource = resourceTable[element.data.resourceid]
				local desc = resource.name
				if resource.usageLimit ~= "unbounded" and resource.usageLimit ~= "global" then
					desc = string.format("%s (Refreshes %s)", desc, resource:RefreshDescription())
				end
				--gui.Tooltip(resource:TooltipText(element.data.quantity, element.data.numExpended))(element)
				element.tooltip = gui.StatsHistoryTooltip{ description = desc, entries = m_token.properties:GetStatHistory(element.data.resourceid):GetHistory() }
			end,
			press = function(element)
				local resourceTable = dmhub.GetTable("characterResources") or {}
				local resource = resourceTable[element.data.resourceid]
				
				if currentCostProposal == nil then
					m_token:ModifyProperties{
						description = "Use resources",
						execute = function()
							if element:HasClass("expended") then
								m_token.properties:RefreshResource(element.data.resourceid, resource.usageLimit)
							else
								if element.data.quantity > element.data.numExpended then
									m_token.properties:ConsumeResource(element.data.resourceid, resource.usageLimit)
								end
							end
						end,
					}

					element.data.resourceBar:FireEvent('recalculate', m_token, m_token.properties)
				else

					for i,info in ipairs(currentCostProposal.details) do
						local index = nil
						for j,option in ipairs(info.paymentOptions) do
							if option.resourceid == element.data.resourceid then
								index = j
							end
						end

						if index ~= nil then
							local option = info.paymentOptions[index]
							table.remove(info.paymentOptions, index)
							table.insert(info.paymentOptions, 1, option)
						end
					end

					currentSymbols.upcast = Spell.CalculateUpcast(currentCostProposal).upcast
					currentSymbols.dicefaces = ActivatedAbility.CalculateDiceFaces(currentCostProposal)
					CurrentCalculateSpellTargeting()
					castMessage:FireEvent("refresh")
					castModesPanel:FireEvent("refreshModes")
					
					for i,bar in ipairs(resourcePanels) do
						bar:FireEventTree("focusspell")
					end

					castSpellLevelPanel:FireEventTree("focusspell")
					channeledResourcePanel:FireEventTree("focusspell")

				end
			end,

			focusspell = function(element)
				local resourceTable = dmhub.GetTable("characterResources") or {}
				local resource = resourceTable[element.data.resourceid]
				element:SetClass("focusspell", true)
				if element:HasClass("last") then
					local isoption = false
					local isselected = false
					local illegal = false
					for i,info in ipairs(currentCostProposal.details) do
						for j,option in ipairs(info.paymentOptions) do
							if option.resourceid == element.data.resourceid then
								isoption = true
								break
							end
						end

						if not info.canAfford then
							for j,option in ipairs(info.expendedOptions) do
								if option.resourceid == element.data.resourceid then
									illegal = true
								end
							end
						end

						if #info.paymentOptions > 0 and info.paymentOptions[1].resourceid == element.data.resourceid then
							isselected = true
						end
					end
					element:SetClass("isoption", isoption)
					element:SetClass("isselected", isselected)
					element:SetClass("illegal", illegal)
				end
			end,

			defocusspell = function(element)
				element:SetClass("focusspell", false)
				element:SetClass("isselected", false)
				element:SetClass("isoption", false)
				element:SetClass("illegal", false)
			end,
		}


		local resultPanel
		local params = {
			id = "resourceBar-" .. resourceGroupings[1],
			halign = "center",
			valign = "bottom",
			width = "auto",
			height = "auto",
			minHeight = ActionBar.resourceBarHeight or 80,
			flow = options.flow or "horizontal",

			styles = {
				{
					selectors = {"resourceQuantityLabel"},
					halign = "center",
					valign = "center",
					width = "auto",
					height = "auto",
					bold = true,
					fontSize = 18,
				},
				{
					selectors = {"resourceIcon"},
					width = iconSize,
					height = iconSize,
					valign = "bottom",
					halign = "center",
				},

				{
					selectors = {"resourceIcon", "hover", "~focusspell"},
					brightness = 2.5,
					priority = 50,
				},

				{
					selectors = {"resourceIcon", "behind"},
					scale = 0.8,
				},

				{
					selectors = {"resourceIcon", "topleft"},
					x = -6,
					y = -6,
				},
				{
					selectors = {"resourceIcon", "topleft", "parent:hover"},
					x = -8,
					y = -10,
					transitionTime = 0.2,
				},

				{
					selectors = {"resourceIcon", "topright"},
					x = 6,
					y = -6,
				},
				{
					selectors = {"resourceIcon", "topright", "parent:hover"},
					x = 8,
					y = -10,
					transitionTime = 0.2,
				},

				{
					selectors = {"resourceIcon", "topcenter"},
					x = 0,
					y = -12,
				},
				{
					selectors = {"resourceIcon", "topcenter", "parent:hover"},
					x = 0,
					y = -20,
					transitionTime = 0.2,
				},

				{
					selectors = {"resourceGroupPanel"},
					bgcolor = "clear",
					width = resourceSize,
					height = resourceSize,
					hmargin = 0,
					valign = "bottom",
					halign = "left",
					flow = "none",
				},
				{
					selectors = {"resourceGroupPanel", "largeQuantity"},
					width = "auto",
					flow = cond(ActionBar.largeQuantityResourceHorizontal, "horizontal", "horizontal"),
				},
				{
					selectors = {"resourceGroupPanel", "~largeQuantity", "hover"},
					height = cond(not ActionBar.resourcesWithBars, resourceSize + 24),
				},
			},

			classes = {'resources-bar'},

			create = function(element)
				if token ~= nil then
					element:FireEvent("recalculate", token, token.properties)
				end
			end,

			recalculate = function(element, token, creature)
				if creature == nil then
					element:SetClass("collapsed", true)
					return
				end

				m_token = token
				creature = m_token.properties

				g_profileActionBarRecalculateResources:Begin()

				element:SetClass("collapsed", false)

				local resources = m_token.properties:GetResources()
				local resourceTable = dmhub.GetTable("characterResources") or {}

				local children = {}

				local lastGroup = nil

				local newResourceIconsCache = {}

				local newGroups = {}

				local groupIndex = 1

				for _,grouping in ipairs(element.data.resourceGroupings) do
					local groupingLower = string.lower(grouping)
					for resourceid,quantity in pairs(resources) do
						local resource = resourceTable[resourceid]
						if resource ~= nil and string.lower(resource.grouping) == groupingLower then

							local numExpended = m_token.properties:GetResourceUsage(resource.id, resource.usageLimit)

							local styles = resourceStyles[resource.id] or resource:CreateStyles()
							resourceStyles[resource.id] = styles

							local panelKey = string.format('%s-%s', groupingLower, resource.id)
							local resourceGroupPanel = resourceGroupPanels[panelKey] or gui.Panel{
								id = string.format("resource-group-%s", panelKey),
								classes = {'resourceGroupPanel'},
								bgimage = "panels/square.png",
								data = {
									iconCache = {},
								},
							}

							resourceGroupPanel.data.ord = resource.name
							resourceGroupPanel.data.ordIndex = groupIndex

							resourceGroupPanels[panelKey] = resourceGroupPanel
							newGroups[panelKey] = true

							local newIconCache = {}

							children[#children+1] = resourceGroupPanel

							local displayQuantity = quantity
							local iconChildren = {}

							resourceGroupPanel:SetClass("largeQuantity", resource.largeQuantity)

							if resource.largeQuantity then
								local key = resource.id .. 'largeQuantity'

								local icon = resourceGroupPanel.data.iconCache[key] or gui.Panel{
									id = string.format("resource-icon-%s", key),
									bgimage = resource.iconid,
									classes = {'resourceIcon', "normal", "last"},
									alphaHitTest = true,
									styles = {
										styles,
										resourceSelectionStyles,
									},

									data = {
										resourceid = resource.id,
										resourceBar = resultPanel,
									},

									events = resourceIconEvents,

								}

								icon.data.quantity = quantity
								icon.data.numExpended = numExpended

								resourceGroupPanel.data.iconCache[key] = icon
								newIconCache[key] = true
								iconChildren[#iconChildren+1] = icon

								key = key .. 'label'
								local quantityLabel = resourceGroupPanel.data.iconCache[key] or gui.Label{
									classes = {'resourceQuantityLabel'},
									editable = true,
                                    numeric = true,
									characterLimit = 2,

									--a floating label which shows up to show how much will be deducted.
									gui.Label{
										classes = {'resourceQuantityLabel', 'collapsed'},
										y = -16,
										floating = true,
										interactable = false,
										text = "",
										cost = function(element, cost)
											for _,cost in ipairs(cost.details) do
												for _,option in ipairs(cost.paymentOptions) do
													if option.resourceid == resource.id then
														element.text = tostring(option.quantity)
														element:SetClass("collapsed", false)
														return
													end
												end
											end

											element:SetClass("collapsed", true)
										end,

										defocusspell = function(element)
											element:SetClass("collapsed", true)
										end,
									},

									data = {
										total = 0,
										current = 0,
									},
									characterLimit = 3,
									change = function(element)

										local n = tonumber(element.text)
										if n ~= nil then

											if resource.usageLimit == "unbounded" or resource.usageLimit == "global" then
												n = resource:ClampQuantity(n)
											else
												n = clamp(n, 0, element.data.total)
											end
											local diff = n - element.data.current
											if diff ~= 0 then
                                                element:SetClass("pending", true)
												m_token:ModifyProperties{
													description = "Use resources",
													execute = function()
														if diff > 0 then
															m_token.properties:RefreshResource(resourceid, resource.usageLimit, diff)
														else
															m_token.properties:ConsumeResource(resourceid, resource.usageLimit, -diff)
														end
													end
												}
											end
										end

										--resultPanel:FireEvent('recalculate', m_token, m_token.properties)


									end,
								}

								quantityLabel.data.total = quantity
								quantityLabel.data.current = quantity - numExpended
								quantityLabel.text = tostring(quantity - numExpended)
                                quantityLabel:SetClass("pending", false)


								resourceGroupPanel.data.iconCache[key] = quantityLabel
								newIconCache[key] = true

								key = key .. 'total'
								local totalLabel = resourceGroupPanel.data.iconCache[key] or gui.Label{
									classes = {'resourceQuantityLabel'},
								}

								if resource ~= nil and (resource.usageLimit == "unbounded" or resource.usageLimit == "global") then
									totalLabel.text = ""
								else
									totalLabel.text = "/" .. tostring(quantity)
								end

								resourceGroupPanel.data.iconCache[key] = totalLabel
								newIconCache[key] = true

								iconChildren[#iconChildren+1] = quantityLabel
								iconChildren[#iconChildren+1] = totalLabel
								
								displayQuantity = 0
							end

							for i=1,displayQuantity do
								local isAvailable = i > numExpended
								local lastAvailable = (i == quantity)
								if lastGroup ~= nil and lastGroup ~= grouping then
									local dividerKey = string.format("divider-%s", lastGroup)
									local divider = resourceGroupPanels[dividerKey] or gui.Panel{
										width = 12,
										height = 4,
										data = {
											ord = "div",
										},
									}

									divider.data.ordIndex = groupIndex+0.5
									groupIndex = groupIndex+1


									resourceGroupPanels[dividerKey] = divider

									children[#children+1] = divider
								end

								lastGroup = grouping

								local key = string.format('%s-%d', resource.id, i)

								local icon = resourceGroupPanel.data.iconCache[key] or gui.Panel{
									id = string.format("resource-icon-%s", key),
									classes = {'resourceIcon'},
									alphaHitTest = true,
									styles = {
										styles,
										resourceSelectionStyles,
									},

									data = {
										resourceid = resource.id,
										resourceBar = resultPanel,
									},


									events = resourceIconEvents,

								}

								resourceGroupPanel.data.iconCache[key] = icon

								icon.bgimage = resource.iconid

								icon:SetClass("behind", i ~= quantity)
								icon:SetClass("topleft", i == quantity-1)
								icon:SetClass("topright", i == quantity-2)
								icon:SetClass("topcenter", i == quantity-3)

								icon.data.quantity = quantity
								icon.data.numExpended = numExpended
								icon:SetClass("normal", isAvailable)
								icon:SetClass("last", lastAvailable)
								icon:SetClass("expended", not isAvailable)

								newIconCache[key] = true
								iconChildren[#iconChildren+1] = icon
							end

							for key,item in pairs(resourceGroupPanel.data.iconCache) do
								if newIconCache[key] then
									item:SetClass("collapsed", false)
								else
									item:SetClass("collapsed", true)
									iconChildren[#iconChildren+1] = item
								end
							end

							resourceGroupPanel.children = iconChildren
						end
					end
					
				end

				table.sort(children, function(a,b)
					if a.data.ordIndex == b.data.ordIndex then
						return a.data.ord < b.data.ord
					end

					return a.data.ordIndex < b.data.ordIndex
				end)

				for k,item in pairs(resourceGroupPanels) do
					if newGroups[k] then
						item:SetClass("collapsed", false)
					else
						item:SetClass("collapsed", true)
						children[#children+1] = item
					end
				end

				element.children = children
				g_profileActionBarRecalculateResources:End()
			end,

			data = {
				resourceGroupings = resourceGroupings
			},
		}

		for k,v in pairs(options) do
			params[k] = v
		end

		resultPanel = gui.Panel(params)

		return resultPanel
	end

	resourcesBar = CreateResourcesBar({"Spell Slots", "Class Specific"}, {
        bgimage = "panels/square.png",
        opacity = 0.7,
        bgcolor = "black",
		borderColor = "#000000ff",
		borderWidth = 8,
		borderFade = true,
        cornerRadius = 6,
        hpad = 6,
        halign = "center", resourceSize = 32, iconSize = 32, flow = cond(ActionBar.resourcesWithBars, "vertical", "horizontal") })


    --TODO: show actions somewhere in DS.
	--actionResourcesBar = CreateResourcesBar({"Actions"}, { halign = "left", resourceSize = cond(ActionBar.resourcesWithBars, 16, 40), iconSize = cond(ActionBar.resourcesWithBars, 16, 40), flow = cond(ActionBar.resourcesWithBars, "vertical", "horizontal") })

	local searchInput = gui.Input{
		width = 120,
		height = 22,
		placeholderText = "Search...",

		find = function(element)
			gui.SetFocus(nil)
			gui.SetFocus(element)
		end,
		edit = function(element)
			if element.text == "" then

				return
			end

			local matchCount = 0

			local text = string.lower(element.text)
			for i,panel in ipairs(pagingPanels) do
				if panel.data.GetKeywords ~= nil then
					local keywords = panel.data.GetKeywords(panel)
					local match = false
					for _,word in ipairs(keywords) do
						if string.find(string.lower(word), text) then
							match = true
							break
						end

					end

					panel:SetClass("collapsed", matchCount >= 8 or not match)

					if match then
						matchCount = matchCount + 1
					end

				else
					panel:SetClass("collapsed", true)
				end
			end

		end,
	}

	local resourceAndSearch = gui.Panel{
		width = "auto",
		height = "auto",

		recalculate = function(element, creature)
			searchInput.text = ""
			element:SetClass("collapsed", creature == nil)
		end,

		gui.Panel{
			classes = {"collapsed"},
			y = -30,
			flow = "horizontal",
			floating = true,
			halign = "left",
			valign = "bottom",
			vmargin = 0,
			width = "auto",
			height = "auto",
			find = function(element)
				element:SetClass("collapsed", not element:HasClass("collapsed"))
			end,

			searchInput,

			gui.CloseButton{
				escapeActivates = true,
				escapePriority = EscapePriority.DMHUB_POPUP,
				click = function(element)
					element:FireEvent("press")
				end,
				press = function(element)
					element.parent:SetClass("collapsed", true)

					searchInput.text = ""
					if gui.GetFocus() == searchInput then
						gui.SetFocus(nil)
					end
				end,
			}
		},

		cond(not ActionBar.resourcesWithBars, actionResourcesBar),
	}

	resourcePanels = {resourcesBar, actionResourcesBar}

	local m_categoryActionPanels = {}

	local actionsContainerChildren = {}

	local actionBarActivate = function(element, n)
		local item = element.children[n]
		if item ~= nil and item.enabled then
			item:FireEventTree("click")
		end
	end

	local actionBarKeybind = function(element)
		local children = element.children
		local index = 1
		for i,child in ipairs(children) do
			if child:HasClass("collapsed") == false then
				local key = dmhub.GetCommandBinding("actionbar " .. element.id .. " " .. index)
				child:FireEventTree("setkeybind", key)
				index = index+1
			end
		end
	end

	for i,bar in ipairs(ActionBar.bars) do
		local panel = gui.Panel{
			id = bar.panelid,
            hmargin = bar.hmargin or 0,
			halign = "center",
			valign = "center",
			width = "auto",
			height = "auto",
			flow = "horizontal",
			uiscale = bar.uiscale or 1,
			activate = actionBarActivate,
			labelkeybind = actionBarKeybind,


			data = {
				bar = bar,
			}
		}

        local drawerButton = nil

        if bar.drawer then
            local drawer = gui.Panel{
                halign = "center",
                valign = "bottom",
                y = -100,
                floating = true,
                width = 160,
                height = "auto",
                flow = "horizontal",
                wrap = true,
				escapePriority = EscapePriority.CANCEL_ACTION_BAR,
				captureEscape = false,
				escape = function(element)
                    if element:HasClass("collapsed") then
                        return
                    end
                    drawerButton:FireEvent("press")
                end,
                clickaway = function(element)
                    if element:HasClass("collapsed") then
                        return
                    end
                    drawerButton:FireEvent("press")
                end,
                classes = {"drawer", "collapsed"},
                styles = {
                    {
                        selectors = {"~drawerOpened"},
                        transitionTime = 0.2,
                        opacity = 0,
                    },
                    {
                        selectors = {"slot"},
                        vmargin = 2,
                    },
                }
            }
		    m_categoryActionPanels[bar.category] = drawer

            drawerButton = gui.Panel{
				bgimage = 'panels/square.png',
				classes = {'slot'},
                styles = {
                    {
                        selectors = {"slot", "hover", "~press"},
                        bgcolor = Styles.textColor,
                    },
                    {
                        selectors = {"label"},
                        color = Styles.textColor,
                    },
                    {
                        selectors = {"label", "parent:hover", "~parent:press"},
                        color = Styles.backgroundColor,
                    },
                    {
                        selectors = {"label", "parent:expended", "~parent:press"},
                        color = "#888888",
                    }
                },

				refresh = function(element)
                    local allExpended = true
                    local items = drawer.children
                    for _,item in ipairs(items) do
                        if not item:HasClass("expended") then
                            allExpended = false
                        end
                    end

                    element:SetClass("expended", allExpended)
                end,

                closeDrawers = function(self)
                    if drawer:HasClass("collapsed") == false then
                        self:FireEvent("press")
                    end
                end,
                press = function(self)
                    if drawer:HasClass("collapsed") then
                        --close all other drawers.
                        actionBar:FireEventTree("closeDrawers")
                    end

                    drawer:SetClass("collapsed", not drawer:HasClass("collapsed"))
                    drawer:SetClassTree("drawerOpened", not drawer:HasClass("collapsed"))
                    drawer.captureEscape = drawer:HasClass("collapsed") == false
                    if drawer:HasClass("collapsed") then
                        return
                    end
                end,

                gui.Label{
                    halign = "center",
                    valign = "center",
                    width = "auto",
                    height = "auto",
                    bold = true,
                    fontSize = 40,
                    text = bar.drawerText or "C",
                },
            }

            panel.children = {drawer, drawerButton}
        else
		    m_categoryActionPanels[bar.category] = panel
        end

		local children = {}

		if bar.hasResourcesBar then
			children[#children+1] = resourcesBar
		end

		if bar.hasActionResourcesBar then
			children[#children+1] = actionResourcesBar
		end

		local panelHeading

		panelHeading = gui.Label{
			classes = {"hidden"},
			floating = true,
			fontSize = 14,
			color = "white",
			text = string.format("<b>%s</b>", bar.description or bar.category),
			halign = "center",
			valign = "top",
			y = -16,
			width = "auto",
			height = "auto",
			refreshActionbar = function(element, newToken)
                if bar.calculateDescription ~= nil then
                    element.text = bar.calculateDescription(newToken)
                end
            end,
		}

		--link the heading to the panel so it can be hidden when there are no actions in this category.
		m_categoryActionPanels[bar.category].data.headingLabel = panelHeading
		m_categoryActionPanels[bar.category].data.drawerButton = drawerButton

		children[#children+1] = gui.Panel{
			width = "auto",
			height = "auto",
			valign = "bottom",

			refreshActionbar = function(element, newToken)
                if bar.calculateVisible ~= nil then
                    element:SetClass("collapsed", not bar.calculateVisible(newToken))
                end
            end,

			panelHeading,
			panel,
		}

		actionsContainerChildren[#actionsContainerChildren+1] = gui.Panel{
			width = "auto",
			height = "auto",
			halign = bar.halign,
			valign = "bottom",
			flow = "horizontal",
			children = children,
		}
	end

	local actionsContainerPanel  = gui.Panel{
		width = "auto",
		height = "auto",
		flow = "horizontal",
		minWidth = ActionBar.actionsMinWidth,

		children = actionsContainerChildren,
	}

	local RecalculateActionBarSize = function()
		local tiny = ActionBar.allowTinyActionBar and dmhub.GetSettingValue("tinyactionbar")
		if tiny then
			pageSize = ActionBar.containerPageSize*4
		else
			pageSize = ActionBar.containerPageSize
		end
	end

	RecalculateActionBarSize()


	actionBar = gui.Panel{
		id = "actionBar",

		selfStyle = {
			bgcolor = '#00000066',
			width = 'auto',
			height = "auto",
			halign = 'center',
			valign = 'bottom',
			flow = 'horizontal',
			tmargin = cond(ActionBar.resourcesWithBars, 30, 0),
		},

		classes = {'action-bar', "hideWhenInvoking"},

		children = {
			arrowPanel,
			actionsContainerPanel,
		},

		multimonitor = {"tinyactionbar"},

		events = {
			monitor = function(element)
				RecalculateActionBarSize()
				element:FireEvent("refreshGame")
			end,

			find = function(element)
				resourceAndSearch:FireEventTree("find")
			end,

			edit = function(element)
				if creature ~= nil then
					self:ShowActionBarEditDialog(creature, element, pagingPanels)


					--clear out the panels so they will be recreated since they were pillaged to put in the edit dialog.
					m_spellPanels = {}

					element.data.recalculate(element)
					element:SetClass("collapsed", true)
				end
			end,

			invokeAbility = function(element, casterToken, ability, symbols)
				gui.SetFocus(nil)

				symbols.invoked = true
				currentSymbols = symbols

				tokenInfo:PushSelectedTokenOverride(casterToken)
				actionBar:FireEvent("refresh")

				actionBarResultPanel:SetClassTree("invokingAbility", true)

				local spellPanel = GetSpellPanel(nil, nil, ability, {destroyOnDefocus = true, invoking = true, forceCasterToken = casterToken, adoptCasterToken = true})
				element:AddChild(spellPanel)
				--spellPanel:SetClass("collapsed", true)
				gui.SetFocus(spellPanel)
				spellPanel.data.stickyFocus = true
				spellPanel.data.blockFocus = true

				synthesizedSpellsPanel:FireEvent("refreshSpell", {forceCasterToken = casterToken})



				spellPanel.events.destroy = function(element)
					actionBarResultPanel:SetClassTree("invokingAbility", false)
					actionBar:FireEvent("refresh")
				end

			--currentSpell = ability
			--spellRange = nil
			--currentSymbols = symbols --{ mode = 1, charges = spell:DefaultCharges() }
			--currentCostProposal = {}
			--CurrentCalculateSpellTargeting = CalculateSpellTargeting

			--CalculateSpellTargeting()
			end,

			--newToken is guaranteed to be non-nil.
			refreshActionbar = function(element, newToken)
				local tokenChanged = (token ~= newToken)
				token = newToken
				creature = token.properties

				if tokenChanged then
					element.data.recalculate(element)

					--we want to refresh the display if either our character changes, or any of the game's rules tables change.
					element.monitorGame = { string.format("/characters/%s", token.id), "/assets/objectTables" }
				else
					--actionResourcesBar:FireEvent("recalculate", token, creature)
					resourcesBar:FireEvent("recalculate", token, creature)
					resourceAndSearch:FireEvent("recalculate", creature)

				end
			end,

			refresh = function(element)
				if tokenInfo.selectedToken == nil or tokenInfo.selectedToken.properties == nil then
					token = nil
					element.monitorGame = nil
					element:AddClass('hidden')
					element.data.displayedProperties = nil
					element.data.hasInit = false
					--actionResourcesBar:FireEvent("recalculate") --calling without args will cause it to collapse
					resourcesBar:FireEvent("recalculate") --calling without args will cause it to collapse
					resourceAndSearch:FireEvent("recalculate")
					return
				else
					element:RemoveClass('hidden')
				end

				--if tokenInfo.selectedToken.properties ~= element.data.displayedProperties or element.data.hasInit == false then
					element.data.hasInit = true
					element:FireEventTree('refreshActionbar', tokenInfo.selectedToken)
				--end
			end,

			--fired whenever the monitored path in the game changes. In this case any character data.
			refreshGame = function(element)
				if self.castingSpell then
					gameUpdateCameWhileCastingSpell = true
				else
					element.data.recalculate(element)
					gameUpdateCameWhileCastingSpell = false
				end
			end,

			destroy = function(element)
				if ActionBarElements.actionBar == element then
					ActionBarElements = {}
				end
			end,
		},

		data = {
			recalculate = function(element)

                if token == nil then
                    return
                end

				g_profileActionBarRecalculate:Begin()

				pagingPanels = {}

				local childPanels = {arrowPanel}

				creature = token.properties

				--actionResourcesBar:FireEvent("recalculate", token, creature)
				resourcesBar:FireEvent("recalculate", token, creature)
				resourceAndSearch:FireEvent("recalculate", creature)

				if creature == nil then
					element:SetClass('hidden', true)
					ActionBarElements = { actionBar = element, panels = childPanels }
					g_profileActionBarRecalculate:End()
					return
				end

				element:SetClass('hidden', false)

				if ActionBar.hasLoadoutPanel then
					childPanels[#childPanels+1] = GetLoadoutPanel()
				end

				local sortedPanels = {}

				local isDead = creature:IsDead()
				local isDying = creature:IsDying()
				local isStable = creature:IsStable()
               
				local spells = creature:GetActivatedAbilities{bindCaster = true}
				local spellsByCategory = {}
				for spellIndex,spell in ipairs(spells) do
                    local catinfo = nil
                    for _,bar in ipairs(ActionBar.bars) do
                        if spell.categorization == bar.category or (bar.additionalCategories ~= nil and bar.additionalCategories[spell.categorization]) then
                            catinfo = bar
                        end
                    end

					if catinfo ~= nil then
						spellsByCategory[catinfo.category] = spellsByCategory[catinfo.category] or {}
						local list = spellsByCategory[catinfo.category]
						list[#list+1] = spell
						GetSpellPanel(catinfo.category, #list, spell)
					end
				end

				for catid,spellPanelList in pairs(m_spellPanels) do
					for i,spellPanel in ipairs(spellPanelList) do
						local collapsed = i > #(spellsByCategory[catid] or {})
						spellPanel:SetClass("collapsed", collapsed)
					end
				end

				for k,spellPanelList in pairs(m_spellPanels) do
					sortedPanels[k] = sortedPanels[k] or {}
					local sortedPanelsList = sortedPanels[k]
					for i,spellPanel in ipairs(spellPanelList) do
						sortedPanelsList[#sortedPanelsList+1] = spellPanel
					end
				end

				local tokenFloor = game.GetFloor(token.floorid)

				--panel to allow configuration of movement type.
				if movementTypePanel == nil and ActionBar.hasMovementTypePanel then
					local drawerPanel = gui.Panel{
						classes = {"hidden"},
						flow = "horizontal",
						height = "auto",
						width = "auto",
						escapePriority = EscapePriority.CANCEL_ACTION_BAR,
						captureEscape = true,
						escape = function(element)
							element.children = {}
							element:SetClass("hidden", true)
						end,
						clickaway = function(element)
							element:FireEvent("escape")
						end,
					}

					local iconPanel = gui.Panel{
						classes = {'icon'},
						bgcolor = "#d4d1ba",
						refresh = function(element)
							if token == nil or token.properties == nil then
								return
							end
							local info = token.properties.movementTypeById[token.properties:CurrentMoveType()]
							element.bgimage = info.icon
						end,
					}
					local focusPanel = CreateFocusPanel()

					movementTypePanel = gui.Panel{
						width = 0,
						height = "auto",
						floating = true,
						halign = "right",
						valign = "bottom",
						flow = "horizontal",


						
						gui.Panel{

							bgimage = 'panels/square.png',
							classes = {'slot'},
							width = 32,
							height = 32,

							events = {

								hover = function(element)
									if not iconPanel:HasClass("hidden") then
										local info = creature.movementTypeById[token.properties:CurrentMoveType()]
										gui.Tooltip{
											text = string.format("%s: %s %s per round.", info.verb, MeasurementSystem.NativeToDisplay(token.properties:GetEffectiveSpeed(token.properties:CurrentMoveType())), string.lower(MeasurementSystem.UnitName())),
											valign = "top",
											halign = "center",
										}(element)
									end
								end,

								click = function(element)
									if not drawerPanel:HasClass("hidden") then
										drawerPanel:FireEvent("escape")
										return
									end

									local popoutPanels = {}
									for _,moveType in ipairs(creature.movementTypes) do
										if moveType ~= token.properties:CurrentMoveType() then
											local speed = token.properties:GetSpeed(moveType)
											if speed > 0 then
												local info = creature.movementTypeById[moveType]
												popoutPanels[#popoutPanels+1] = gui.Panel{
													bgimage = 'panels/square.png',
													classes = {'slot'},
													width = 32,
													height = 32,
													flow = "none",

													hover = function(element)
														if not iconPanel:HasClass("hidden") then
															local info = creature.movementTypeById[moveType]
															gui.Tooltip{
																text = string.format("%s: %s %s per round.", info.verb, MeasurementSystem.NativeToDisplay(token.properties:GetEffectiveSpeed(moveType)), string.lower(MeasurementSystem.UnitName())),
																valign = "top",
																halign = "center",
															}(element)
														end
													end,

													click = function(element)
														token:ModifyProperties{
															description = "Change movement type",
															execute = function()
																token.properties:SetCurrentMoveType(moveType)
															end
														}
														drawerPanel:FireEvent("escape")
														if movementTypePanel ~= nil then
															movementTypePanel:FireEventTree("refresh")
														end
													end,

													CreateFocusPanel(),
													gui.Panel{
														classes = {'icon'},
														bgimage = info.icon,
														bgcolor = "#d4d1ba",
													},
												}
												
											end
										end
									end

									if #popoutPanels ~= 0 then
										drawerPanel.children = popoutPanels
										drawerPanel:SetClass("hidden", false)
									end
								end,
							},
							children = {
								focusPanel,

								iconPanel,

							},
						},
						drawerPanel,
					}
				end


				--SORT PAGING PANELS
				if ActionBar.sortByDisplayOrder then
					for k,sortedPanelsList in pairs(sortedPanels) do
						table.sort(sortedPanelsList, function(a,b)
							local spella = a.data.GetSpell and a.data.GetSpell()
							local spellb = b.data.GetSpell and b.data.GetSpell()
							if spella == nil and spellb == nil then
								return false
							end

							if spella == nil then
								return true
							end

							if spellb == nil then
								return false
							end

                            local orda = spella:DisplayOrder()
                            local ordb = spellb:DisplayOrder()
							if orda == ordb then
								local costa = tonumber(spella:try_get("resourceNumber", 0)) or 0
								local costb = tonumber(spellb:try_get("resourceNumber", 0)) or 0

								if costa == costb then
									if spella.name == spellb.name then
										local rangea = tonumber(spella:GetRange(token.properties)) or 0
										local rangeb = tonumber(spellb:GetRange(token.properties)) or 0

										return rangea < rangeb
									end
									return spella.name < spellb.name
								end

								return costa < costb
							end

							return orda < ordb
						end)
					end

				elseif creature:has_key("actionbar") and creature.actionbar.default then
					for k,sortedPanelsList in pairs(sortedPanels) do
						for i,panel in ipairs(sortedPanelsList) do
							panel.data.index = i
						end
						table.sort(sortedPanelsList, function(a,b)
							return cond(a:HasClass("collapsed"), 1000, 0) + (creature.actionbar.default[a.data.id] or a.data.index or 1) < cond(b:HasClass("collapsed"), 1000, 0) + (creature.actionbar.default[b.data.id] or b.data.index or 1)
						end)
					end
					table.sort(pagingPanels, function(a,b)
						return (creature.actionbar.default[a.data.id] or a.data.index or 1) < (creature.actionbar.default[b.data.id] or b.data.index or 1)
					end)
				end

				childPanels[#childPanels+1] = actionsContainerPanel

				if movementTypePanel ~= nil then
					childPanels[#childPanels+1] = movementTypePanel
				end

				--now pagingPanels contains the panels that can be shown, we can calculate the number of pages and which page we are on.
				numPages = #pagingPanels/pageSize
				if pageNumber > numPages then
					pageNumber = 1
				end


				element.children = childPanels

				ActionBarElements = { actionBar = element, panels = childPanels }

				for k,panelList in pairs(sortedPanels) do
					local categoryPanel = m_categoryActionPanels[k]
					if categoryPanel ~= nil then
						categoryPanel.children = panelList
						if categoryPanel.data.headingLabel ~= nil or categoryPanel.data.drawerButton ~= nil then
							local haveVisible = false
							for _,panel in ipairs(panelList) do
								if not panel:HasClass("collapsed") then
									haveVisible = true
									break
								end
							end

                            if categoryPanel.data.headingLabel ~= nil then
							    categoryPanel.data.headingLabel:SetClass("hidden", not haveVisible)
                            end

                            if categoryPanel.data.drawerButton ~= nil then
							    categoryPanel.data.drawerButton:SetClass("hidden", not haveVisible)
                            end
						end
					end
				end


				--clear out any panels that don't have any entries.
				for catid,panel in pairs(m_categoryActionPanels) do
					if sortedPanels[catid] == nil then
						panel.children = {}
					end
				end

				actionsContainerPanel:FireEventTree("labelkeybind")


				g_profileActionBarRecalculate:End()

			end
		},
	}

	local mainActionBarPanel = gui.Panel{
		id = "mainActionBarPanel",


		selfStyle = {
			width = 'auto',
			height = 'auto',
			halign = 'center',
			valign = 'bottom',
			flow = 'vertical',
            bmargin = 8,
		},
		children = {

			--message label which contains any important messages from the engine.
			gui.Label{
				halign = "center",
				valign = "bottom",
				width = "auto",
				height = "auto",
				bold = true,
				fontSize = 16,
				color = "white",
		
				thinkTime = 0.25,
		
				think = function(element)
					element.text = dmhub.diagnosticStatus
				end,
			},



			m_currentSpellPanel,
			castButton,
			skipButton,
			castModesPanel,
			castMessageContainer,
			castSpellLevelPanel,
			channeledResourcePanel,
			synthesizedSpellsPanel,
			ammoChoicePanel,
			castChargesInput,

			gui.Panel{
				classes = {"hideWhenInvoking"},
				flow = "horizontal",
				halign = "center",
				valign = "bottom",
				width = ActionBar.resourceBarWidth or 600,
				height = "auto",
				resourceAndSearch,
				cond(not ActionBar.resourcesWithBars, resourcesBar),
			},
			actionBar,
		},
	}

	actionBarResultPanel = gui.Panel{
		id = "actionBarResultPanel",
		styles = {
			styles,
			{
				selectors = {"hideWhenInvoking", "invokingAbility"},
				priority = 20,
				uiscale = 0,
			},
		},
		classes = {cond(dmhub.GetSettingValue("__previewdice"), "preview-dice")},
		width = "auto",
		height = "auto",
		halign = "center",
		valign = "bottom",
		flow = "horizontal",
		y = 0,

		data = {
			IsCastingSpell = function()
				return currentSpell ~= nil
			end,
		},

		multimonitor = {"__previewdice", "hideactionbar"},
		events = {
			monitor = function(element)
				element:SetClass("preview-dice", dmhub.GetSettingValue("__previewdice"))
				element:SetClass("hidden", dmhub.GetSettingValue("hideactionbar"))
			end,
		},

		gui.Panel{
			classes = {cond(ActionBar.transparentBackground, nil, "collapsed")},
			floating = true,
			width = 1920,
			height = 94,
			halign = "center",
			valign = "bottom",
			bgimage = "panels/square.png",
			bgcolor = "black",
			opacity = 0.6,
			refresh = function(element)
				if tokenInfo.selectedToken == nil or tokenInfo.selectedToken.properties == nil then
					element:SetClass("collapsed", true)
				elseif ActionBar.transparentBackground then
					element:SetClass("collapsed", false)
				end
			end,
		},

		mainActionBarPanel,
		gui.Panel{
			floating = true,
			halign = "left",
			valign = "bottom",
			width = "auto",
			height = "auto",
			uiscale = 0.5,
			x = -50,
			y = 64,
		},
	}

	self.actionBarPanel = actionBarResultPanel

	return actionBarResultPanel
end


--The reaction bar in the bottom left contains our triggered abilities, anything we are concentrating on, and auras affecting us.
function GameHud:CreateReactionBar(dialog, tokenInfo)
	local token = nil
	local creature = nil

	local abilityPanels = {}
	local abilities = {} --list of triggered abilities being displayed.
	local resourceTable = dmhub.GetTable("characterResources")

	local auraPanels = {}
	local auras = {} --list of auras being displayed

	local m_concentrationPanels = {}

	local resultPanel
	resultPanel = gui.Panel{
		id = "reactionBar",
		classes = {"hidden"},
		styles = {
			{
				selectors = {'slotHighlight'},
				halign = "center",
				valign = "center",
				width = 56,
				height = 56,
				bgcolor = 'white',
			},
			{
				selectors = {'slotHighlight', '~active'},
				saturation = 0.2,
				brightness = 0.6,
			},
			{
				selectors = {'abilityPanel'},
				width = 38,
				height = 38,
				bgcolor = 'white',
				bgimage = 'panels/InventorySlot_Background.png',
			},
			{
				selectors = {'abilityPanel', 'expended'},
				bgcolor = '#666666',
			},
			{
				selectors = {'abilityIcon'},
				width = "90%",
				height = "90%",
				halign = "center",
				valign = "center",
			},
			{
				selectors = {'abilityIcon', 'parent:expended'},
				opacity = 0.2,
			},
			{
				selectors = {'resourceCostIcon'},
				width = 16,
				height = 16,
			},
		},

		x = 390,
		y = -20,
		valign = "bottom",
		halign = "left",
		height = "auto",
		width = 50,
		flow = "vertical",

		--called by dmhub whenever the active token changes or a game update occurs.
		refresh = function(element)
			if tokenInfo.selectedToken == nil or tokenInfo.selectedToken.properties == nil or (not ActionBar.hasReactionBar) then
				element:SetClass("hidden", true)
				return
			end

			resourceTable = dmhub.GetTable("characterResources")

			element:SetClass("hidden", false)

			token = tokenInfo.selectedToken
			creature = tokenInfo.selectedToken.properties

			local childPanels = {}

			--AURAS AFFECTING US

			local aurasTouching = token:GetAurasTouching() or {}

			auras = {}
			for _,aura in ipairs(aurasTouching) do
				auras[#auras+1] = aura.auraInstance
			end

			for i,_ in ipairs(auras) do
				local panel = auraPanels[i] or gui.Panel{
					classes = "abilityPanel",

					data = {},

					refresh = function(element)
						local aura = auras[i]
						element:SetClass("collapsed", aura == nil)

						if aura == nil and element.data.marker then
							element:FireEvent("dehover")
						end
					end,

					hover = function(element)
						if auras[i] == nil then
							return
						end

						element.tooltipParent = resultPanel

						local tooltip = CreateAuraTooltip(auras[i])
						tooltip.selfStyle.halign = "center"
						tooltip.selfStyle.valign = "top"
						element.tooltip = tooltip

						local auraInstance = auras[i]
						local area = auraInstance:GetArea()
						if area ~= nil then
							element.data.mark = {
								area:Mark{
									color = "white",
									video = "divinationline.webm",
								}
							}
						end
					end,

					dehover = function(element)
						if element.data.mark ~= nil then
							for _,mark in ipairs(element.data.mark) do
								mark:Destroy()
							end
							element.data.mark = nil
						end
					end,

					gui.PrettyBorder{ width = 4 },

					gui.Panel{
						classes = "abilityIcon",
						refresh = function(element)
							local aura = auras[i]
							if aura == nil then
								return
							end
							element.bgimage = aura.aura.iconid
							element.selfStyle = aura.aura.display
						end,
					},
				}

				auraPanels[i] = panel
			end

			for _,panel in ipairs(auraPanels) do
				childPanels[#childPanels+1] = panel
			end


			--TRIGGERED ABILITIES
			abilities = creature:GetTriggeredAbilities()
			for i,_ in ipairs(abilities) do
				local abilityInfo = nil
				local ability = nil
				local costInfo = nil
				local abilityPanel = abilityPanels[i] or gui.Panel{
					classes = "abilityPanel",

					click = function(element)
						if ability ~= nil and not ability.mandatory then
							token:ModifyProperties{
								description = "Change trigger enabled",
								execute = function()
									creature:SetTriggeredAbilityEnabled(ability, not creature:TriggeredAbilityEnabled(ability))
								end,
							}

							element:FireEventTree("refresh")
						end
					end,

					gui.PrettyBorder{ width = 4 },

					gui.Panel{
						classes = "abilityIcon",
						refresh = function(element)
							if ability == nil then
								return
							end
							element.bgimage = ability.iconid
							element.selfStyle = ability.display
						end,
					},

					gui.Panel{
						classes = {'slotHighlight'},
						bgimage = 'panels/InventorySlot_Focus.png',
						interactable = false,
						refresh = function(element)
							if ability == nil or ability.mandatory or (costInfo ~= nil and not costInfo.canAfford) then
								element:SetClass("hidden", true)
								return
							end

							element:SetClass("hidden", false)
							element:SetClass("active", creature:TriggeredAbilityEnabled(ability))
						end,
					},

					--resource cost panel
					gui.Panel{
						halign = "right",
						valign = "bottom",
						flow = "horizontal",
						width = "auto",
						height = "auto",

						refresh = function(element)
							if ability == nil or ability.mandatory then
								element:SetClass("hidden", true)
								return
							end

							element:SetClass("hidden", false)

							local children = element.children

							for i,entry in ipairs(costInfo.details) do
								if entry.description == nil then
									local resource = resourceTable[entry.cost]
									text = entry.description

									local iconPanel = children[i] or gui.Panel{
										classes = {"resourceCostIcon"},
										selfStyle = resource.display.normal,
									}

									iconPanel.selfStyle = resource.display.normal
									iconPanel.bgimage = resource.iconid

									children[i] = iconPanel
								end
							end

							element.children = children
						end,
					},

					gui.Label{
						fontSize = 12,
						color = "white",
						width = "auto",
						height = "auto",
						halign = "right",
						valign = "top",
						refresh = function(element)
							if costInfo == nil then
								element:SetClass("hidden", true)
								return
							end

							local text = nil

							for i,entry in ipairs(costInfo.details) do
								if entry.description ~= nil then
									text = entry.description
								end
							end

							if text ~= nil then
								element.text = text
								element:SetClass("hidden", false)
							else
								element:SetClass("hidden", true)
							end

						end,
					},

					refresh = function(element)
						abilityInfo = abilities[i]
						if abilityInfo == nil then
							ability = nil
							costInfo = nil
							return
						end

						ability = abilityInfo.ability
						costInfo = ability:GetCost(token)
						element:SetClass("expended", not costInfo.canAfford)

						if element.tooltip ~= nil then
							--re-create the tooltip if it's showing.
							element:FireEvent("hover")
						end
					end,

					showtooltip = function(element)
						if ability == nil then
							return
						end

						element.tooltipParent = resultPanel

						local tooltip = CreateAbilityTooltip(ability:GetActiveVariation(token), {token = token})
						if tooltip ~= nil then
							tooltip.selfStyle.halign = "center"
							tooltip.selfStyle.valign = "top"
							element.tooltip = tooltip
						end

					end,

                    hover = function(element)
                        element:FireEvent("showtooltip")
                    end,
				}

				abilityPanels[i] = abilityPanel
			end

			for i,abilityPanel in ipairs(abilityPanels) do
				abilityPanel:SetClass("collapsed", i > #abilities)
				childPanels[#childPanels+1] = abilityPanel
			end

			--CONCENTRATION
			local newConcentrationPanels = {}

			for _,concentration in ipairs(creature:try_get("concentrationList", {})) do
				local key = concentration.id
				local concentrationPanel
				concentrationPanel = m_concentrationPanels[key] or gui.Panel{
					classes = "abilityPanel",
					gui.PrettyBorder{ width = 4 },

					data = {
					},

					gui.Panel{
						classes = "abilityIcon",
						bgcolor = "white",
						bgimage = "ui-icons/concentration.png",
						refresh = function(element)
							local concentration = creature:GetConcentrationById(key)
							if concentration == nil then
								concentrationPanel:SetClass("collapsed", true)
								if concentrationPanel.data.marker then
									concentrationPanel:FireEvent("dehover")
								end
								return
							end

							concentrationPanel:SetClass("collapsed", false)
						end,
					},

					rightClick = function(element)
						element:FireEvent("click")
					end,

					click = function(element)
						local entries = {}
						entries[#entries+1] = {
							text = "Cancel Concentration",
							click = function()

								token:ModifyProperties{
									description = "Cancel concentration",
									execute = function()
										token.properties:CancelConcentration(creature:GetConcentrationById(key))
									end,
								}

								element.popup = nil
							end
						}

						element.popup = gui.ContextMenu{
							entries = entries,
						}
					end,

					hover = function(element)
						local concentration = creature:GetConcentrationById(key)
						if concentration == nil or concentration:HasExpired() then
							return
						end

						element:FireEvent("dehover")

						element.tooltipParent = resultPanel

						local tooltip = concentration:CreateTooltip(creature)
						tooltip.selfStyle.halign = "right"
						tooltip.selfStyle.valign = "center"
						element.tooltip = tooltip

						local auraid = concentration:try_get("auraid")
						if auraid ~= nil then
							local auraInstance = creature:GetAura(auraid)
							if auraInstance ~= nil then
								local area = auraInstance:GetArea()
								if area ~= nil then
									element.data.mark = {
										area:Mark{
											color = "white",
											video = "divinationline.webm",
										}
									}
								end
							end
						end

						--if this concentration has summons highlight them.
						local summonid = concentration:try_get("summonid")
						if summonid ~= nil and self.castingSpell == false then
							local summonsMarked = {}
							for _,id in ipairs(summonid) do
								local tok = dmhub.GetTokenById(id)
								if tok ~= nil then
									tok.sheet:FireEvent("targetnoninteractive")
									summonsMarked[#summonsMarked+1] = id
								end
							end

							if #summonsMarked > 0 then
								element.data.summonsMarked = summonsMarked
							end
						end

					end,

					--when we dehover a concentration panel we clear any markings we had based on the concentration.
					dehover = function(element)
						if element.data.mark ~= nil then
							for _,mark in ipairs(element.data.mark) do
								mark:Destroy()
							end

							element.data.mark = nil
						end

						if element.data.summonsMarked ~= nil then
							for _,summonTok in ipairs(element.data.summonsMarked) do
								local tok = dmhub.GetTokenById(summonTok)
								if tok ~= nil then
									tok.sheet:FireEvent("untarget")
								end
							end

							element.data.summonsMarked = nil
						end
					end,

					destroy = function(element)
						element:FireEvent("dehover")
					end,
				}

				m_concentrationPanels[key] = concentrationPanel
				childPanels[#childPanels+1] = concentrationPanel
			end

			m_concentrationPanels = newConcentrationPanels

			element.children = childPanels

			element:SetClass("hidden", false)
		end,
	}

	return resultPanel
end

function GameHud:ShowActionBarEditDialog(creature, actionBar, pagingPanels)
	local pagesParent


	local tab = "default"

	for _,panel in ipairs(pagingPanels) do
		panel:SetClass("editing", true)
		panel:SetClass("collapsed", panel:HasClass("empty"))
		panel:Unparent()

		panel:AddChild(gui.Panel{
			floating = true,
			interactable = false,
			width = 48,
			height = 48,
			halign = "center",
			valign = "center",
			bgcolor = "red",
			bgimage = "ui-icons/close.png",
			styles = {
				{
					selectors = {"~parent:suppressed"},
					hidden = 1,
				}
			}
		})

		panel.draggable = true
		panel.dragTarget = true
		panel.canDragOnto = function(element, target)
			return element ~= target and target:HasClass("slot") and target:HasClass("editing")
		end

		if panel.events == nil then
			panel.events = {}
		end

		panel.events.click = function(element)
			--element:SetClass("suppressed", not element:HasClass("suppressed"))
		end

		panel.events.press = nil

		panel.events.drag = function(element, target)
			if target ~= nil then
				local children = pagesParent.children

				local elementIndex = 0
				local targetIndex = 0
				for i,child in ipairs(children) do
					if child == element then
						elementIndex = i
					end

					if child == target then
						targetIndex = i
					end
				end

				if elementIndex ~= 0 and targetIndex ~= 0 then
					children[elementIndex] = target
					children[targetIndex] = element

					local token = dmhub.LookupToken(creature)
					token:ModifyProperties{
						description = "Reorder action bar",
						execute = function()
							creature.actionbar = creature:try_get("actionbar", {})

							creature.actionbar[tab] = creature.actionbar[tab] or {}

							for i,child in ipairs(children) do
								if child:HasClass("empty") == false and child.data.id ~= nil then
									creature.actionbar[tab][child.data.id] = i
								end
							end
						end,
					}



					pagesParent.children = children
				end
			end
		end
	end

	local pages = {}



	pagesParent = gui.Panel{
		flow = "horizontal",
		wrap = true,
		height = "auto",
		width = 72*9,
		children = pagingPanels,
	}

	local dialogPanel
	dialogPanel = gui.Panel{
		id = "ActionBarEdit",
		classes = {"framedPanel"},
		width = 1200,
		height = 800,
		pad = 8,
		flow = "vertical",
		styles = {
			Styles.Default,
			Styles.Panel,
			SlotStyles,
			{
				selectors = {'slot'},
				halign = "left",
			},
			{
				selectors = {'slot', 'drag-target-hover'},
				brightness = 10,
			},
			{
				selectors = {'slot-highlight','parent:drag-target-hover'},
				brightness = 10,
			},
			{
				selectors = {'slot', 'suppressed'},
				saturation = 0,
			},
		},

		gui.Label{
			classes = {"dialogTitle"},
			text = "Edit Actions",
		},

		gui.Panel{
			floating = true,
			halign = "right",
			valign = "bottom",
			margin = 16,
			width = 240,
			height = 32,
			CreateSettingsEditor("tinyactionbar"),
		},

		destroy = function(element)

			actionBar:SetClass("collapsed", false)
			actionBar.data.recalculate(actionBar)
		end,

		pagesParent,

		gui.CloseButton{
			halign = "right",
			valign = "top",
			floating = true,
			escapeActivates = true,
			escapePriority = EscapePriority.EXIT_MODAL_DIALOG,
			click = function()
				gui.CloseModal()
			end,
		},

	}

	gui.ShowModal(dialogPanel)
end
