local mod = dmhub.GetModLoading()

local g_deadMinionPulseSpeed = 0.5
local g_deadMinionIconStyles = {
    gui.Style{
        width = 48,
        height = 48,
        bgimage = "ui-icons/Pin_Boss.png",
        bgcolor = "red",
        opacity = 0.8,
    },
    gui.Style{
        selectors = {"big"},
        scale = 1.2,
        transitionTime = g_deadMinionPulseSpeed,
    },
    gui.Style{
        selectors = {"hover"},
        scale = 1.2,
        opacity = 1,
        transitionTime = 0.2,
    },
    gui.Style{
        selectors = {"press"},
        brightness = 2,
    }
}

--the wounded icon configuration.
TokenUI.RegisterIcon{
    id = "wounded",
    icon = "ui-icons/wounded-border.png",
    Filter = function(creature)
        --this controls if the icon should display.
	    return (not creature.minion) and creature.damage_taken >= creature:MaxHitpoints()/2 and dmhub.GetSettingValue("showwoundedicon")
    end,

    --Only show to those who can't see the health bar.
    showToAll = true,
    showToGM = true,
    showToController = true,
    showToFriends = true,
    showToEnemies = true,
}

TokenUI.RegisterIcon{
    id = "captain",
    Calculate = function(creature)
        if (not creature:has_key("minionSquad")) or creature.minion then
            return nil
        end

        return {
            id = "captain",
            icon = "panels/hud/crown.png",
            style = {
                bgcolor = DrawSteelMinion.GetSquadColor(creature.minionSquad)
            }
        }
    end,

    showToAll = true,
    showToGM = true,
    showToController = true,
    showToFriends = true,
    showToEnemies = true,
}

local g_triggeredResource = ""
local g_triggeredResourceRefreshType = ""
local g_triggeredStyles = {
    {
        selectors = {"depleted"},
        transitionTime = 0.4,
        hidden = 1,
        scale = 2,
        opacity = 0,
    },
}

TokenHud.RegisterPanel{
    id = "drawsteel",
    ord = -1,
	create = function(token, sharedInfo)
        if g_triggeredResource == "" then
            g_triggeredResource = CharacterResource.nameToId["Trigger"] or ""
            g_triggeredResourceRefreshType = CharacterResource.resourceToRefreshType[g_triggeredResource] or ""
        end
        local m_triggeredActionIndicatorPanel = gui.Panel{
            interactable = false,
            classes = {"depleted"},
            styles = g_triggeredStyles,
            width = 92,
            height = 92,
            cornerRadius = 46,
            bgimage = "panels/square.png",
            bgcolor = "clear",
            borderWidth = 2,
            borderColor = "#ff00ffbb",
            refresh = function(element)
                local q = dmhub.initiativeQueue
                if q == nil or q.hidden then
                    element:SetClass("depleted", true)
                    return
                end
                local c = token.properties
				local resources = c:GetResources()
			    local resourcesUsed = c:GetResourceUsage(g_triggeredResource, g_triggeredResourceRefreshType)
                if (resources[g_triggeredResource] or 0) - resourcesUsed <= 0 then
                    element:SetClass("depleted", true)
                    return
                end

                if c.typeName == "monster" then
                    for _,ability in ipairs(c.innateActivatedAbilities) do
                        if ability:try_get("resourceCost") == g_triggeredResource then
                            element:SetClass("depleted", false)
                            return
                        end
                    end

                    --doesn't have a trigger.
                    element:SetClass("depleted", true)
                else
                    element:SetClass("depleted", false)
                end
            end,
        }

        local m_turnIndicatorPanel = gui.Panel{
            classes = {"hidden-anim"},
            interactable = false,
            width = 92,
            height = 92,
            bgimage = "panels/square.png",
            bgcolor = "clear",
            borderWidth = 1,
            borderColor = "white",
            cornerRadius = 46,
            brightness = 3,

            styles = {
                gui.Style{
                    selectors = {"hidden-anim"},
                    hidden = 1,
                    opacity = 0,
                    transitionTime = 0.5,
                },
            },
        }

        local m_minionDeathPanel = nil

        return gui.Panel{
            interactable = false,

            width = 96,
            height = 96,
            halign = "center",
            valign = "center",
            flow = "none",

            thinkTime = 0.2,
            think = function(element)
                element:FireEventTree("updateInitiative")

                if token.properties.minion and token.properties:has_key("_tmp_minionSquad") then
                    local squad = token.properties._tmp_minionSquad
                    local death = squad.damage_taken >= squad.health_single

                    if death then
                        if m_minionDeathPanel == nil then
                            m_minionDeathPanel = gui.Panel{
                                styles = g_deadMinionIconStyles,
                                click = function(element)
                                    print("TOKEN CLICKED")
                                    game.DeleteCharacters{token.charid}
                                end,

                                thinkTime = g_deadMinionPulseSpeed,
                                think = function(element)
                                    element:SetClass("big", not element:HasClass("big"))
                                end,
                            }

                            element:AddChild(m_minionDeathPanel)
                        end
                    else
                        if m_minionDeathPanel ~= nil then
                            m_minionDeathPanel:DestroySelf()
                            m_minionDeathPanel = nil
                        end
                    end


                    
                end
            end,

            m_triggeredActionIndicatorPanel,

            m_turnIndicatorPanel,

            gui.Panel{
                classes = {"hidden"},
                bgimage = "panels/initiative/initiative-icon2.png",
                interactable = true,
                width = 48,
                height = 48,
                bgcolor = "white",
                halign = "center",
                valign = "center",

                data = {
                    prevStatus = nil,
                },


                styles = {
                    gui.Style{
                        opacity = 0.5,
                    },
                    gui.Style{
                        selectors = {"big"},
                        scale = 1.2,
                        transitionTime = 0.5,
                        brightness = 1.2,
                        easing = "easeInOutSine",
                    },
                    gui.Style{
                        selectors = {"hover"},
                        scale = 1.2,
                        brightness = 1.2,
                        transitionTime = 0.2,
                        opacity = 1,
                    },
                },

                think = function(element)
                    element:SetClass("big", not element:HasClass("big"))

                end,

                updateInitiative = function(element)
                    local status = token.initiativeStatus

                    if status == "OurTurn" and element.data.prevStatus == "ActiveAndReady" and element:HasClass("hidden") == false then
                        element:FireEvent("spawnChild")
                    end

                    local show = status == "ActiveAndReady"
                    element:SetClass("hidden", not show)
                    element.thinkTime = cond(show, 0.5)

                    element.data.prevStatus = status

                    m_turnIndicatorPanel:SetClass("hidden-anim", status ~= "OurTurn")
                end,

                click = function(element)
                    if token.canControl then
                        element:SetClass("hidden", true)
                        local initiativeid = dmhub.initiativeQueue.GetInitiativeId(token)
                        dmhub.initiativeQueue:SelectTurn(initiativeid)
                        dmhub:UploadInitiativeQueue()

                        local tokens = GameHud.GetTokensForInitiativeId(GameHud.instance, GameHud.instance.initiativeInterface, initiativeid)
                        for i,tok in ipairs(tokens) do
                            if tok.properties ~= nil then
                                tok.properties:BeginTurn()
                            end
                        end

                        element:FireEvent("spawnChild")
                    end
                end,

                spawnChild = function(element)
                    element.parent:AddChild(gui.Panel{
                        bgimage = "panels/initiative/initiative-icon2.png",
                        interactable = false,
                        width = 48,
                        height = 48,
                        bgcolor = "white",
                        halign = "center",
                        valign = "center",
                        styles = {
                            gui.Style{
                                scale = 1.2,
                            },
                            gui.Style{
                                selectors = {"activate"},
                                opacity = 0,
                                brightness = 4,
                                transitionTime = 0.3,
                                scale = 3,
                            },
                        },
                        create = function(element)
                            element:SetClass("activate", true)
                            element:ScheduleEvent("remove", 1)
                        end,
                        remove = function(element)
                            element:DestroySelf()
                        end,
                    })
                end,
            },
        }
    end,
}

-- Function to calculate relative luminance
local function luminance(r, g, b)
    local function transform(component)
        if component <= 0.03928 then
            return component / 12.92
        else
            return ((component + 0.055) / 1.055) ^ 2.4
        end
    end
    return 0.2126 * transform(r) + 0.7152 * transform(g) + 0.0722 * transform(b)
end

-- Function to calculate contrast ratio
local function contrast_ratio(l1, l2)
    return (l1 + 0.05) / (l2 + 0.05)
end

local luminance_bg_black = luminance(0,0,0)

function TokenHud.UseLightBackgroundColor(color)
    local lum = luminance(color.r, color.g, color.b)
    if contrast_ratio(lum, luminance_bg_black) < 3.0 then
        return true
    else
        return false
    end
end

TokenHud.RegisterPanel{
	id = "nameLabel",
	create = function(token, sharedInfo)

        local bglabel = gui.Label{
                x = 2,
                y = 2,
				hpad = 16,
				vpad = 8,
				text = '',
                fontFace = "Book",
				interactable = false,
				fontSize = 14,
				minFontSize = 8,
				maxWidth = 120,
				wrap = false,
				textWrap = false,
				width = "auto",
				height = "auto",
				color = 'white',
				halign = 'center',
				valign = 'bottom',
				textAlignment = 'center',
				brightness = 1,
				italics = false,
			}


        local label = gui.Label{
				hpad = 16,
				vpad = 8,
				text = '',
                fontFace = "Book",
				interactable = false,
				fontSize = 14,
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
						if token.properties ~= nil and (token.canControl or not token.namePrivate) then
                            local textColor = nil
                            local squad = token.properties:MinionSquad()
                            if squad ~= nil then
							   textColor = DrawSteelMinion.GetSquadColor(squad)
                            else
							    textColor = token.playerColor
                            end

                            local text = token:GetNameMaxLength(30)

                            if text ~= nil then
                                local offsetScale = 0.85 ^ math.max(0, #text - 10)
                                bglabel.x = 1.5 * offsetScale
                                bglabel.y = 4 - 1.5 * offsetScale
                            end

							element.selfStyle.italics = token.namePrivate
							element.selfStyle.brightness = cond(token.namePrivate, 0.8, 1)
							element.text = text

							bglabel.selfStyle.italics = token.namePrivate
							bglabel.selfStyle.brightness = cond(token.namePrivate, 0.8, 1)
							bglabel.text = text

                            local lightbg = TokenHud.UseLightBackgroundColor(core.Color(textColor))
                            if lightbg then
                                bglabel.selfStyle.color = textColor
                                element.selfStyle.color = "white"
                            else
                                bglabel.selfStyle.color = "black"
                                element.selfStyle.color = textColor
                            end
						else
							element.text = ''
                            bglabel.text = ''
						end
					end,
				},
			}

	
		return gui.Panel{
			interactable = false,

			valign = "bottom",
			halign = "center",
			width = 120,
			height = 40,

            bglabel,
            label,

		}

	end,
}

TokenHud.RegisterPanel{
	id = "flankingPanel",
	create = function(token, sharedInfo)
        local m_indicators = {}
		return gui.Panel{
			interactable = false,
            width = 1,
            height = 1,
            valign = "center",
            halign = "center",
            monitorGame = "/characters",
            refreshGame = function(element)
                element:FireEvent("refresh")
            end,
			refresh = function(element)
                if token == nil or (not token.valid) then
                    return
                end
                local flankingTokens = token.properties:GetFlankingTokens()
                if #flankingTokens == 0 then
                    m_indicators = {}
                    element.children = {}
                    element:SetClass("collapsed", true)
                    return
                end

                if #m_indicators == #flankingTokens then
                    local match = true
                    for i=1,#flankingTokens do
                        if flankingTokens[i] ~= m_indicators[i].data.token then
                            match = false
                            break
                        end
                    end

                    if match then
                        return
                    end
                end

                element:SetClass("collapsed", false)

                for i,tok in ipairs(flankingTokens) do
                    m_indicators[i] = gui.Panel{
                        width = 1,
                        height = 80,
                        halign = "center",
                        valign = "center",

                        gui.Panel{
                            halign = "center",
                            valign = "top",
                            bgimage = "panels/triangle.png",
                            bgcolor = "red",
                            width = 12,
                            height = 12,
                        },

                        thinkTime = 0.1,
                        think = function(element)
                            if tok.valid then
                                local a = tok.pos
                                local b = token.pos
                                local deltax = a.x - b.x
                                local deltay = -(a.y - b.y)

                                local angle = math.atan2(deltay, deltax)
                                local degrees = angle * (180/math.pi)
                                element.selfStyle.rotate = -degrees-90
                            end
                        end,

                        create = function(element)
                            element:FireEvent("think")
                        end,
                    }
                end

                while #m_indicators > #flankingTokens do
                    m_indicators[#m_indicators] = nil
                end

                element.children = m_indicators

            end,
        }
    end
}

--Draw Steel version of lifebars.
TokenUI.RegisterStatusBar{
    id = "lifebar",

    --showToAll = true,
    showToGM = function() return dmhub.GetSettingValue("hpbarfordm") end,
    showToController = function() return dmhub.GetSettingValue("hpbarforownplayer") end,
    showToFriends = function() return dmhub.GetSettingValue("hpbarforparty") end,
    showToEnemies = function() return dmhub.GetSettingValue("hpbarforenemy") end,

    height = 9,
    width = 1,
    seek = 10, --bar goes up or down 10 hp /second

    --make the fill color change according to current number of hitpoints.
    fillColor = {
        {
            value = 0.67,
            color = "white",

            gradient = Styles.healthGradient,
        },
        {
            value = 0.33,

            color = "white",

            gradient = Styles.bloodiedGradient,
        },
        {
            color = "white",
            gradient = Styles.damagedGradient,

        },
    },
    Calculate = function(creature)
        if dmhub.GetSettingValue("hpbarsonlyincombat") then
            local q = dmhub.initiativeQueue
            if q == nil or q.hidden then
                return nil
            end
        end

        if creature.minion then
            return nil
        end

        return {
            value = creature:CurrentHitpoints(),
            max = creature:MaxHitpoints(),
            width = 1, --math.min(1, math.max(0.25, (max_hp*0.1)/creature:GetCalculatedCreatureSizeAsNumber())),
        }
    end
}
