local mod = dmhub.GetModLoading()

CharacterPanel.CreateConditionsPanel = function(token)
    return nil
end

local function AurasPanel(m_token)

    local m_auraPanels = {}

    local resultPanel

    resultPanel = gui.Panel{
        width = "100%",
        height = "auto",
        flow = "vertical",

        refreshToken = function(element, tok)
            m_token = tok
        end,


        refresh = function(element)
            if m_token == nil or not m_token.valid then
                element:SetClass("collapsed", true)
                return
            end

            local creature = m_token.properties
            if creature == nil then
                element:SetClass("collapsed", true)
                return
            end

            local newChildren = {}
            local newPanels = {}
            local auras = creature:try_get("auras", {})
            for _,aura in ipairs(auras) do
                local auraid = aura.guid
                local panel = m_auraPanels[auraid] or gui.Panel{
                    width = "100%",
                    height = "auto",
                    flow = "horizontal",
                    vmargin = 4,
                    bgimage = "panels/square.png",
                    bgcolor = "clear",

                    gui.DiamondButton{
                        bgimage = 'panels/square.png',
                        halign = "left",
                        width = 24,
                        height = 24,
                        hmargin = 6,
                        valign = "center",
                        icon = aura.aura.iconid,
                        create = function(element)
                            element:FireEvent("display", aura.aura.display)
                        end,
                    },

                    gui.Label{
                        height = "auto",
                        width = 120,
                        textWrap = false,
                        halign = "left",
                        valign = "center",
                        rmargin = 4,
                        fontSize = 14,
                        minFontSize = 8,
                        color = Styles.textColor,
                        text = string.format("%s (Aura)", aura.aura.name),
                    },

                    gui.DeleteItemButton{
                        width = 12,
                        height = 12,

                        lmargin = 24,
                        halign = "left",
                        valign = "center",
                        data = {
                            entry = nil,
                        },
                        press = function(element)
                            m_token:BeginChanges()
                            m_token.properties:RemoveAura(auraid)
                            m_token:CompleteChanges("Remove Aura")
                        end,
                    },
                }

                newPanels[aura.guid] = panel
                newChildren[#newChildren+1] = panel
            end

            m_auraPanels = newPanels
            element.children = newChildren
        end,
    }

    return resultPanel
end

local function InflictedConditionsPanel(m_token)

	local m_conditions
	local addConditionButton = nil
	local ongoingEffectPanels = {}

    local resultPanel

    resultPanel = gui.Panel{
        width = "100%",
        height = "auto",
        flow = "vertical",

        refreshToken = function(element, tok)
            m_token = tok
        end,

        refresh = function(element)
            if m_token == nil or not m_token.valid then
                for _,p in ipairs(ongoingEffectPanels) do
                    p:SetClass("collapsed", true)
                end
                return
            end

            local creature = m_token.properties
            if creature == nil then
                for _,p in ipairs(ongoingEffectPanels) do
                    p:SetClass("collapsed", true)
                end
                return
            end

            m_conditions = creature:try_get("inflictedConditions", {})
            local count = 0

            local newPanels = false

            for key,cond in pairs(m_conditions) do
                count = count+1
                local panel = ongoingEffectPanels[count]
    
                if panel == nil then

                    newPanels = true

                    local button = gui.DiamondButton{
                        bgimage = 'panels/square.png',
                        halign = "left",
                        width = 24,
                        height = 24,
                        hmargin = 6,
                        valign = "center",

                        click = function(element)

                            local items = {}

                            local duration = m_token.properties:ConditionDuration(element.parent.data.condid)
                            if duration and duration ~= "eot" and duration ~= "eoe" then
                                items[#items+1] = {
                                    text = "Roll Save",
                                    click = function()
                                        m_token.properties:RollConditionSave(element.parent.data.condid)
                                        element.popup = nil
                                    end,
                                }
                            end

                            items[#items+1] = {
                                text = "Remove Condition",
                                click = function()
                                    m_token:BeginChanges()
                                    m_token.properties:InflictCondition(element.parent.data.condid, {purge = true})
                                    m_token:CompleteChanges("Apply Condition")
                                    element.popup = nil
                                end,
                            }

                            element.popup = gui.ContextMenu{
                                entries = items,
                            }
                            
                        end,
                    }

                    local descriptionLabel = gui.Label{
                        height = "auto",
                        width = 120,
                        textWrap = false,
                        halign = "left",
                        valign = "center",
                        rmargin = 4,
                        fontSize = 14,
                        minFontSize = 8,
                        color = Styles.textColor,
                    }

                    local quantityLabel = gui.Label{
                        width = "auto",
                        height = "auto",
                        minWidth = 100,
                        fontSize = 14,
                        bold = true,
                        halign = "left",
                        valign = "center",
                        color = Styles.textColor,
                        characterLimit = 2,
                        textAlignment = "left",

                        press = function(element)
                            local SetDuration = function(duration)
                                m_token:BeginChanges()
                                m_token.properties:InflictCondition(element.parent.data.condid, {force = true, duration = duration})
                                m_token:CompleteChanges("Set Condition Duration")
                            end

                            local entries = {}

                            entries[#entries+1] = {
                                text = "Save Ends",
                                click = function()
                                    SetDuration("save")
                                    element.popup = nil
                                end,
                            }

                            entries[#entries+1] = {
                                text = "EoT",
                                click = function()
                                    SetDuration("eot")
                                    element.popup = nil
                                end,
                            }
                            entries[#entries+1] = {
                                text = "EoE",
                                click = function()
                                    SetDuration("eoe")
                                    element.popup = nil
                                end,
                            }
                            element.popup = gui.ContextMenu{
                                halign = "center",
                                entries = entries,
                            }
                        end,

                        change = function(element)
                            local cond = m_conditions[element.parent.data.condid]
                            local stacks = tonumber(element.text)
                            if stacks == nil then
                                element.text = tostring(cond.stacks)
                                return
                            end

                            m_token:BeginChanges()
                            m_token.properties:InflictCondition(element.parent.data.condid, {stacks = stacks - cond.stacks})
                            m_token:CompleteChanges("Apply Condition")
                        end,
                    }

                    panel = gui.Panel{
                        width = "100%",
                        height = "auto",
                        flow = "horizontal",
                        vmargin = 4,
                        bgimage = "panels/square.png",
                        bgcolor = "clear",

                        button,

                        descriptionLabel,

                        quantityLabel,

                        gui.DeleteItemButton{
                            width = 12,
                            height = 12,

                            lmargin = 24,
                            halign = "left",
                            valign = "center",
                            data = {
                                entry = nil,
                            },
                            press = function(element)
                                m_token:BeginChanges()
                                m_token.properties:InflictCondition(element.parent.data.condid, {purge = true})
                                m_token:CompleteChanges("Remove Condition")
                            end,
                        },


                        refresh = function(element)
                            local cond = m_conditions[element.data.condid]
                            if cond == nil then
                                return
                            end

                            local ongoingEffectsTable = dmhub.GetTable(CharacterCondition.tableName)
                            local ongoingEffectInfo = ongoingEffectsTable[element.data.condid]

                            descriptionLabel.text = ongoingEffectInfo.name

                            local ongoingEffectsTable = dmhub.GetTable(CharacterCondition.tableName)
                            local ongoingEffectInfo = ongoingEffectsTable[element.data.condid]
                            button:FireEvent("icon", ongoingEffectInfo.iconid)
                            button:FireEvent("display", ongoingEffectInfo.display)

                            local duration = cond.duration
                            if duration == "eot" then
                                duration = "EoT"
                            elseif duration == "eoe" then
                                duration = "EoE"
                            else
                                duration = "Save"
                            end

                            quantityLabel.text = duration
                        end,

                        linger = function(element)
                            local cond = m_conditions[element.data.condid]
                            if cond == nil then
                                return
                            end
                            local ongoingEffectsTable = dmhub.GetTable(CharacterCondition.tableName)
                            local ongoingEffectInfo = ongoingEffectsTable[element.data.condid]

                            local duration = cond.duration
                            if duration == "eot" then
                                duration = "EoT"
                            elseif duration == "eoe" then
                                duration = "EoE"
                            elseif type(duration) == "string" then
                                duration = string.upper(duration) .. " ends"
                            else
                                duration = "EoT"
                            end

                            local durationText = string.format(" (%s)", duration)

                            gui.Tooltip(string.format('%s%s: %s', ongoingEffectInfo.name, durationText, ongoingEffectInfo.description))(element)
                        end,
                    }

                    ongoingEffectPanels[count] = panel
                end

                panel.data.condid = key
            end

            for i,p in ipairs(ongoingEffectPanels) do
                p:SetClass("collapsed", i > count)
            end

            element.selfStyle.maxWidth = (count + 1)*40

            if addConditionButton == nil then
                newPanels = true

                addConditionButton = gui.DiamondButton{
                    width = 24,
                    height = 24,
                    halign = "left",
                    valign = "top",
                    hmargin = 6,
                    vmargin = 4,
                    valign = "center",
                    color = Styles.textColor,

                    hover = gui.Tooltip("Add a condition"),
                    press = function(element)

                        local options = {}
                        local conditionsTable = dmhub.GetTable(CharacterCondition.tableName) or {}

                        for k,effect in unhidden_pairs(conditionsTable) do
                            options[#options+1] = gui.Label{
                                classes = {"conditionOption"},
                                bgimage = "panels/square.png",
                                text = effect.name,
                                searchText = function(element, searchText)
                                    if string.starts_with(string.lower(element.text), searchText) then
                                        element:SetClass("collapsed", false)
                                    else
                                        element:SetClass("collapsed", true)
                                    end
                                end,
                                press = function(element)
                                    m_token:BeginChanges()
                                    m_token.properties:InflictCondition(k, {duration = "eot"})
                                    m_token:CompleteChanges("Apply Condition")
                                    addConditionButton.popup = nil
                                end,
                            }
                        end

                        table.sort(options, function(a,b) return a.text < b.text end)

                        local ongoingEffectsTable = dmhub.GetTable("characterOngoingEffects") or {}
                        local statusEffectOptions = {}
                        for k,effect in unhidden_pairs(ongoingEffectsTable) do
                            if effect.statusEffect then
                                statusEffectOptions[#statusEffectOptions+1] = gui.Label{
                                    classes = {"conditionOption"},
                                    bgimage = "panels/square.png",
                                    text = effect.name,
                                    searchText = function(element, searchText)
                                        if string.starts_with(string.lower(element.text), searchText) then
                                            element:SetClass("collapsed", false)
                                        else
                                            element:SetClass("collapsed", true)
                                        end
                                    end,
                                    press = function(element)
                                        m_token:BeginChanges()
                                        m_token.properties:ApplyOngoingEffect(k)
                                        m_token:CompleteChanges("Apply Status Effect")
                                        addConditionButton.popup = nil
                                    end,
                                }
                            end
                        end

                        table.sort(statusEffectOptions, function(a,b) return a.text < b.text end)

                        element.popup = gui.TooltipFrame(
                            gui.Panel{
                                styles = {
                                    Styles.Default,

                                    {
                                        selectors = {"conditionOption"},
                                        width = "95%",
                                        height = 20,
                                        fontSize = 14,
                                        bgcolor = "clear",
                                        halign = "center",
                                    },
                                    {
                                        selectors = {"conditionOption", "searched"},
                                        bgcolor = "#ff444466",
                                    },
                                    {
                                        selectors = {"conditionOption", "hover"},
                                        bgcolor = "#ff444466",
                                    },
                                    {
                                        selectors = {"conditionOption", "press"},
                                        bgcolor = "#aaaaaa66",
                                    },

                                    {
                                        selectors = {"title"},
                                        fontSize = 16,
                                        bold = true,
                                        width = "auto",
                                        height = "auto",
                                        halign = "left",
                                    },

                                },
                                vscroll = true,
                                flow = "vertical",
                                width = 300,
                                height = 800,

                                gui.Label{
                                    fontSize = 18,
                                    bold = true,
                                    width = "auto",
                                    height = "auto",
                                    halign = "center",
                                    text = "Add Condition",
                                },

                                gui.Panel{
                                    bgimage = "panels/square.png",
                                    width = "90%",
                                    height = 1,
                                    bgcolor = Styles.textColor,
                                    halign = "center",
                                    vmargin = 8,
                                    gradient = Styles.horizontalGradient,
                                },

                                gui.Input{
                                    placeholderText = "Search...",
                                    hasFocus = true,
                                    width = "70%",
                                    hpad = 8,
                                    height = 20,
                                    fontSize = 14,
                                    data = {
                                        searchedOption = nil

                                    },
                                    edit = function(element)
                                        element.parent:FireEventTree("searchText", string.lower(element.text))

                                        element.data.searchedOption = nil

                                        local found = element.text == ""
                                        for i,option in ipairs(options) do
                                            if found == false and option:HasClass("collapsed") == false then
                                                found = true
                                                option:SetClass("searched", true)
                                                element.data.searchedOption = option
                                            else
                                                option:SetClass("searched", false)
                                            end
                                        end
                                    end,
                                    submit = function(element)
                                        if element.data.searchedOption ~= nil then
                                            element.data.searchedOption:FireEvent("press")
                                        end
                                    end,
                                },

                                gui.Label{
                                    classes = {"title"},
                                    text = "Conditions",
                                },

                                gui.Panel{
                                    width = "100%",
                                    height = "auto",
                                    flow = "vertical",

                                    children = options,
                                },

                                gui.Label{
                                    classes = {"title"},
                                    text = "Status Effects",
                                },

                                gui.Panel{
                                    width = "100%",
                                    height = "auto",
                                    flow = "vertical",

                                    children = statusEffectOptions,
                                },
                            },

                            {
                                halign = "left",
                                valign = "bottom",
                            }
                        )
                    end,
                }

            end

            if newPanels then
                local children = {}
                for _,child in ipairs(ongoingEffectPanels) do
                    children[#children+1] = child
                end
                children[#children+1] = addConditionButton
                element.children = children
            end


        end,



    }

    return resultPanel
end

CharacterPanel.CreateCharacterDetailsPanel = function(m_token)

    local m_effectEntryPanels = {}
    local m_customConditionPanels = {}

    local resultPanel = nil

    resultPanel = gui.Panel{
        width = "100%",
        height = "auto",
        flow = "vertical",
		bgimage = "panels/square.png",
		bgcolor = "black",

        styles = {
            {
                selectors = {"deleteItemButton"},
                opacity = 0,
            },
            {
                selectors = {"deleteItemButton", "parent:hover"},
                opacity = 1,
            },
        },

        refreshToken = function(element, tok)
            m_token = tok
        end,

        --add to initiative button.
        gui.Button{
            classes = {"collapsed"},
            width = 320,
            height = 30,
            text = "Add to Initiative",
            refreshToken = function(element, tok)
                local q = dmhub.initiativeQueue
                if q == nil or q.hidden then
                    element:SetClass("collapsed", true)
                    return
                end

                element:SetClass("collapsed", tok.properties:try_get("_tmp_initiativeStatus") ~= "NonCombatant")
            end,

            click = function(element)
                Commands.rollinitiative()
            end,
        },

		gui.Label{
			width = "100%",
			height = "auto",
			color = Styles.textColor,
			fontSize = 14,
			bmargin = 4,
			bold = true,
            refreshToken = function(element)
                local creature = m_token.properties
				local resistanceDesc = creature:ResistanceDescription()
				element.text = resistanceDesc
			end,
		},

        --custom effects.
        gui.Panel{
            width = "100%",
            height = "auto",
            flow = "vertical",


            gui.Input{
                width = "80%",
                height = "auto",
                halign = "left",
                fontSize = 12,
                characterLimit = 60,
                placeholderText = "Add Custom Condition...",
                change = function(element)
                    local text = trim(element.text)
                    if text ~= "" then

                        m_token:BeginChanges()
                        local customConditions = m_token.properties:get_or_add("customConditions", {})
                        local key = dmhub.GenerateGuid()
                        customConditions[key] = {
                            text = text,
                            timestamp = dmhub.serverTimeMilliseconds,
                        }
                        m_token:CompleteChanges("Add Custom Condition")
                    end

                    element.text = ""

                    --instantly refresh.
                    resultPanel:FireEventTree("refreshToken", m_token)
                end,
            },

            gui.Panel{
                width = "100%",
                height = "auto",
                flow = "vertical",
                refreshToken = function(element)
                    local children = {}
                    local customConditionPanels = {}
                    for key,entry in pairs(m_token.properties:try_get("customConditions", {})) do
                        local panel
                        panel = m_customConditionPanels[key] or gui.Panel{
                            data = {
                                ord = entry.timestamp,
                            },
                            bgimage = "panels/square.png",
                            bgcolor = "clear",
                            width = "100%",
                            height = "auto",
                            flow = "horizontal",
                            valign = "center",
                            halign = "center",
                            vmargin = 4,
                            hmargin = 4,

                            gui.Label{
                                width = 280,
                                height = "auto",
                                halign = "left",
                                valign = "center",
                                characterLimit = 60,
                                editable = true,
                                fontSize = 14,
                                minFontSize = 8,
                                textWrap = false,
                                rmargin = 4,
                                color = Styles.textColor,
                                text = entry.text,
                                change = function(element)
                                    m_token:BeginChanges()
                                    local customConditions = m_token.properties:get_or_add("customConditions", {})
                                    local newKey = dmhub.GenerateGuid()
                                    local newEntry = DeepCopy(entry)
                                    newEntry.text = trim(element.text)
                                    customConditions[key] = nil
                                    if newEntry.text ~= "" then
                                        customConditions[newKey] = newEntry
                                    end
                                    m_token:CompleteChanges("Change Custom Condition")

                                    --instantly refresh.
                                    resultPanel:FireEventTree("refreshToken", m_token)
                                end,
                            },

                            gui.DeleteItemButton{
                                width = 12,
                                height = 12,

                                lmargin = 24,
                                halign = "left",
                                valign = "center",
                                press = function(element)
                                    m_token:BeginChanges()
                                    m_token.properties:get_or_add("customConditions", {})[key] = nil
                                    m_token:CompleteChanges("Remove Custom Condition")
                                    panel:DestroySelf() --update change immediately.
                                end,
                            },
                        }

                        children[#children+1] = panel
                        customConditionPanels[key] = panel
                    end

                    table.sort(children, function(a,b) return a.data.ord < b.data.ord end)

                    m_customConditionPanels = customConditionPanels
                    element.children = children
                end,
            }
        },


        --ongoing effects.
        gui.Panel{
            width = "100%",
            height = "auto",
            flow = "vertical",

            refreshToken = function(element)
                local creature = m_token.properties
				local ongoingEffectsTable = dmhub.GetTable("characterOngoingEffects")
				local activeOngoingEffects = creature:ActiveOngoingEffects()

                local index = 1
                for _,effectEntry in ipairs(activeOngoingEffects) do
                    local effectInfo = ongoingEffectsTable[effectEntry.ongoingEffectid]
                    if effectInfo ~= nil then

                        m_effectEntryPanels[index] = m_effectEntryPanels[index] or gui.Panel{
                            bgimage = "panels/square.png",
                            bgcolor = "clear",
                            width = "100%",
                            height = "auto",
                            flow = "horizontal",
                            valign = "center",
                            halign = "center",
                            vmargin = 4,
                            hmargin = 4,

                            data = {
                                info = nil,
                                entry = nil,
                            },

                            refreshStatus = function(element, info, entry)
                                element.data.info = info
                                element.data.entry = entry
                            end,

                            linger = function(element)
                                local stacksText = ""
                                if element.data.info.stackable then
                                    stacksText = string.format(" (%d stacks)", element.data.entry.stacks)
                                end
                                local casterText = ""
                                local caster = element.data.entry:DescribeCaster()
                                if caster ~= nil then
                                    casterText = string.format("\nInflicted by %s", caster)
                                end
								gui.Tooltip(string.format('%s%s: %s%s\n%s', element.data.info.name, stacksText, element.data.info.description, casterText, element.data.entry:DescribeTimeRemaining()))(element)

                            end,

                            children = {
                                gui.DiamondButton{
                                    width = 24,
                                    height = 24,
                                    hmargin = 6,
                                    valign = "center",
                                    halign = "left",

                                    refreshStatus = function(element, info, entry)
                                        element:FireEvent("icon", info.iconid)
                                        element:FireEvent("display", info.display)
                                    end,

                                },

                                gui.Label{
                                    width = 120,
                                    height = "auto",
                                    halign = "left",
                                    valign = "center",
                                    fontSize = 14,
                                    minFontSize = 8,
                                    textWrap = false,
                                    rmargin = 4,
                                    color = Styles.textColor,
                                    refreshStatus = function(element, info, entry)
                                        local stacksText = ""
                                        if entry.stacks ~= nil and entry.stacks > 1 then
                                            stacksText = string.format(" x %d", entry.stacks)
                                        end
                                        element.text = info.name .. stacksText
                                    end,
                                },

                                --duration label
                                gui.Label{
                                    width = "auto",
                                    height = "auto",
                                    minWidth = 100,
                                    fontSize = 14,
                                    bold = true,
                                    halign = "left",
                                    valign = "center",
                                    color = Styles.textColor,
                                    characterLimit = 2,
                                    textAlignment = "left",

                                    refreshStatus = function(element, info, entry)
                                        element.text = entry:DescribeTimeRemaining()
                                    end,
                                },

                                gui.DeleteItemButton{
                                    width = 12,
                                    height = 12,

                                    lmargin = 24,
                                    halign = "left",
                                    valign = "center",
                                    data = {
                                        entry = nil,
                                    },
                                    refreshStatus = function(element, info, entry)
                                        element.data.entry = entry
                                    end,
                                    press = function(element)
                                        m_token:BeginChanges()
                                        m_token.properties:RemoveOngoingEffect(element.data.entry.ongoingEffectid)
                                        m_token:CompleteChanges("Remove Ongoing Effect")
                                    end,
                                },

                            },
                        }

                        m_effectEntryPanels[index]:FireEventTree("refreshStatus", effectInfo, effectEntry)

                        index = index+1
                    end
                end

                while #m_effectEntryPanels >= index do
                    m_effectEntryPanels[#m_effectEntryPanels] = nil
                end

                element.children = m_effectEntryPanels

            end,

        },

        --auras.
        AurasPanel(m_token),

        --inflicted conditions.
        InflictedConditionsPanel(m_token),

		CharacterPanel.CharacteristicsPanel(m_token),
		CharacterPanel.ImportantAttributesPanel(m_token),
		CharacterPanel.SkillsPanel(m_token),
        CharacterPanel.AbilitiesPanel(m_token),
    }

    return resultPanel
end

function CharacterPanel.DecorateHitpointsPanel()
	local recoveryid = nil
	local recoveryInfo = nil
	local resourcesTable = dmhub.GetTable(CharacterResource.tableName)
	for k,v in pairs(resourcesTable) do
		if not v:try_get("hidden", false) and v.name == "Recovery" then
			recoveryid = k
			recoveryInfo = v
		end
	end

	local m_token = nil
	local m_hidden = false
	return gui.Panel{
		floating = true,
		width = "100%",
		height = "100%",
		refreshCharacter = function(element, token)
			m_token = token
			m_hidden = recoveryid == nil or token == nil or (not token.valid) or token.properties == nil or token.properties.typeName ~= "character"
			element:SetClass("hidden", m_hidden)
		end,

		gui.Panel{
			halign = "center",
			valign = "bottom",
			cornerRadius = 16,
			y = 8,
			width = 32,
			height = 32,
			bgimage = "panels/square.png",
			borderWidth = 1,
			borderColor = Styles.textColor,
			gradient = Styles.healthGradient,
			bgcolor = "white",

			styles = {
				{
					selectors = {"hover", "~expended"},
					brightness = 2,
					transitionTime = 0.2,
				},
				{
					selectors = {"press", "~expended"},
					brightness = 0.5,
				},
				{
					selectors = {"expended"},
					saturation = 0,
				},
			},

			hover = function(element)
				local usage = m_token.properties:GetResourceUsage(recoveryid, recoveryInfo.usageLimit) or 0
				local max = m_token.properties:GetResources()[recoveryid] or 0
				local quantity = max - usage

				local tooltip = string.format("Recoveries: %d/%d\nRecovery Value: %d\nClick to use.", quantity, max, m_token.properties:RecoveryAmount())
				gui.Tooltip(tooltip)(element)
			end,

			click = function(element)
				if m_token == nil then
					return
				end

				local quantity = max(0, (m_token.properties:GetResources()[recoveryid] or 0) - (m_token.properties:GetResourceUsage(recoveryid, recoveryInfo.usageLimit) or 0))
				if quantity <= 0 then
					return
				end

				if m_token.properties:CurrentHitpoints() >= m_token.properties:MaxHitpoints() then
					return
				end

				m_token:BeginChanges()
				m_token.properties:Heal(m_token.properties:RecoveryAmount(), "Use Recovery")
				m_token.properties:ConsumeResource(recoveryid, recoveryInfo.usageLimit, 1, "Used Recovery")

				m_token:CompleteChanges("Use Recovery")
			end,

			rightClick = function(element)
                element.popup = gui.ContextMenu{
                    entries = {
						{
							text = "Edit Recoveries",
							click = function()
								element.popup = nil
								element:FireEventTree("editRecoveries")
							end,
						}
					},
                }
			end,


			gui.Label{
				width = "100%",
				height = "auto",
				halign = "center",
				valign = "center",
				textAlignment = "center",
				color = "white",
				fontSize = 20,
				characterLimit = 2,
				editRecoveries = function(element)
					element:BeginEditing()
				end,
				change = function(element)
					local n = tonumber(element.text)
					if n == nil then
						element:FireEvent("refreshCharacters", m_token)
						return
					end

					local nresources = m_token.properties:GetResources()[recoveryid] or 0
					local usage = m_token.properties:GetResourceUsage(recoveryid, recoveryInfo.usageLimit) or 0

					local current = nresources - usage
					local delta = n - current

					m_token:BeginChanges()
					if delta > 0 then
						m_token.properties:RefreshResource(recoveryid, recoveryInfo.usageLimit, delta, "Used Recovery")
					else
						m_token.properties:ConsumeResource(recoveryid, recoveryInfo.usageLimit, -delta, "Used Recovery")
					end
					m_token:CompleteChanges("Set Recoveries")
				end,

				characterLimit = 2,
				refreshCharacter = function(element, token)
					if m_hidden then
						return
					end

					local quantity = max(0, (token.properties:GetResources()[recoveryid] or 0) - (token.properties:GetResourceUsage(recoveryid, recoveryInfo.usageLimit) or 0))
					element.text = string.format("%d", quantity)

					element.parent:SetClass("expended", quantity <= 0)
				end,
			},
		}

	}
end

function CharacterPanel.DecoratePortraitPanel(token)
	local m_token = token
	return gui.Panel{
		width = "100%",
		height = "100%",

		gui.Panel{
			y = 19,
			width = 34,
			height = 34,
			halign = "center",
			valign = "bottom",
			flow = "none",

			refreshCharacter = function(element, token)
				m_token = token
				element:SetClass("hidden", token == nil or (not token.valid) or token.properties == nil or token.properties.typeName ~= "character")
			end,

			gui.Panel{
				rotate = 45,
				width = "100%",
				height = "100%",
				bgimage = "panels/square.png",
				bgcolor = "black",
				x = -3,
				borderColor = Styles.textColor,
				borderWidth = 2,
			},

			gui.Label{
				fontSize = 22,
				bold = true,
				color = Styles.textColor,
				halign = "center",
				valign = "center",
				characterLimit = 2,
				editable = true,
				width = "100%",
				height = "auto",
				textAlignment = "center",

				hover = gui.Tooltip("Victories"),

				refreshCharacter = function(element, token)
					if element.parent:HasClass("hidden") then
						return
					end

                    element.text = tostring(token.properties:GetVictories())
				end,

                change = function(element)
                    local n = tonumber(element.text)
					if n ~= nil and round(n) == n then
						m_token:BeginChanges()
						m_token.properties:SetVictories(n)
						m_token:CompleteChanges("Set Victories")
					end
					element.text = string.format("%d", m_token.properties:GetVictories())
				end,
			}
		}
	}
end

local g_edsSetting = setting{
	id = "eds",
	default = 50,
	min = 10,
	max = 1000,
	storage = "game",
}

local multiEditBaseFunction = CharacterPanel.CreateMultiEdit

local g_nseq = 0

CharacterPanel.CreateMultiEdit = function()
	if mod.unloaded then
		return multiEditBaseFunction()
	end

	g_nseq = g_nseq + 1
	local m_nseq = g_nseq


	local m_tokens
	local resultPanel

	local monsterSquadInput = gui.Input{
		fontSize = 16,
		placeholderText = "Enter name...",
		characterLimit = 24,
		selectAllOnFocus = true,
		width = 200,
		height = "auto",
		valign = "center",
		change = function(element)
			local squadid = trim(element.text)
			if squadid ~= "" then
				for _,tok in ipairs(m_tokens) do
					tok:ModifyProperties{
						description = "Set Squad",
						execute = function()
							tok.properties.minionSquad = squadid
						end,
					}
				end
			end
		end,
	}

	local m_selectedSquadId = nil
	local monsterSquadColorPicker = gui.ColorPicker{
		width = 24,
		height = 24,
		halign = "center",
		valign = "center",
		color = "white",
		confirm = function(element)
			local color = element.value.tostring
			for _,tok in ipairs(m_tokens) do
				tok:ModifyProperties{
					description = "Set Color",
					execute = function()
						DrawSteelMinion.SetSquadColor(m_selectedSquadId, color)
					end,
				}
			end

			--notify the game to update to show the new color.
			local monsterTokens = dmhub.GetTokens{
				unaffiliated = true,
			}

			local squadTokens = {}
			for _,tok in ipairs(monsterTokens) do
				if tok.properties.minion and tok.properties:MinionSquad() == m_selectedSquadId then
					squadTokens[#squadTokens+1] = tok.id
				end
			end

			if #squadTokens > 0 then
				game.Refresh{
					tokens = squadTokens,
				}
			end
		end,
	}

    local addToInitiativeButton = gui.Button{
        classes = {"collapsed"},
        width = 320,
        height = 30,
        text = "Add to Initiative",
        tokens = function(element)
            local q = dmhub.initiativeQueue
            if q == nil or q.hidden then
                element:SetClass("collapsed", true)
                return
            end

            local hasNonCombatant = false
            for _,tok in ipairs(m_tokens) do
                if tok.properties:try_get("_tmp_initiativeStatus") == "NonCombatant" then
                    hasNonCombatant = true
                end
            end

            element:SetClass("collapsed", hasNonCombatant == false)
        end,

        click = function(element)
            Commands.rollinitiative()
        end,
    }

    local groupInitiativeButton = gui.Button{
        width = 320,
        height = 30,
        text = "Group Initiative",
        tokens = function(element)
            --only show for non-minions since minions are grouped into squads.
            for _,tok in ipairs(m_tokens) do
                if tok.properties.minion then
                    element:SetClass("collapsed", true)
                    return
                end
            end

            --don't show if tokens all share the same initiative already.
            local initiativeid = false
            for _,tok in ipairs(m_tokens) do
                if initiativeid ~= nil and tok.properties.initiativeGrouping and tok.properties.initiativeGrouping ~= initiativeid then
                    element:SetClass("collapsed", true)
                    return
                end
                initiativeid = tok.properties.initiativeGrouping
            end

            element:SetClass("collapsed", false)
        end,

        click = function(element)
            local guid = dmhub.GenerateGuid()

            local hasPlayers = false
            local existingInitiative = {}
            local info = gamehud.initiativeInterface


            for _,tok in ipairs(m_tokens) do
                if tok.playerControlled then
                    hasPlayers = true
                end
            end

            if hasPlayers then
                --mark this initiativeid as being on the players side.
                guid = "PLAYERS-" .. guid
            end

            for _,tok in ipairs(m_tokens) do
                local initiativeid = InitiativeQueue.GetInitiativeId(tok)
                existingInitiative[initiativeid] = true
                tok:ModifyProperties{
                    description = "Set Initiative",
                    execute = function()
                        tok.properties.initiativeGrouping = guid
                    end,
                }
            end

            if info.initiativeQueue ~= nil and not info.initiativeQueue.hidden then

                for initiativeid,_ in pairs(existingInitiative) do
                    info.initiativeQueue:RemoveInitiative(initiativeid)
                end

                info.initiativeQueue:SetInitiative(guid, 0, 0)
                if hasPlayers then
			        local entry = info.initiativeQueue.entries[guid]
			        if entry ~= nil and entry:try_get("player") ~= true then
				        entry.player = true
			        end
                end

                info.UploadInitiative()
                
            end
        end,
    }

    local ungroupInitiativeButton = gui.Button{
        width = 320,
        height = 30,
        text = "Ungroup Initiative",
        tokens = function(element)
            --only show for non-minions since minions are grouped into squads.
            local haveInitiativeGrouping = false
            for _,tok in ipairs(m_tokens) do
                if tok.properties.minion then
                    element:SetClass("collapsed", true)
                    return
                end

                if tok.properties.initiativeGrouping then
                    haveInitiativeGrouping = true
                end
            end

            element:SetClass("collapsed", not haveInitiativeGrouping)
        end,

        click = function(element)
            local guid = dmhub.GenerateGuid()

            for _,tok in ipairs(m_tokens) do
                tok:ModifyProperties{
                    description = "Set Initiative",
                    execute = function()
                        tok.properties.initiativeGrouping = nil
                    end,
                }
            end
        end,
    }



	local makeCaptainButton = gui.Button{
		width = 320,
		height = 30,
		text = "Make Captain",
		click = function(element)
			local captainid = nil
			for _,tok in ipairs(m_tokens) do
				if (not tok.properties.minion) then
					captainid = tok.id
					tok:ModifyProperties{
						description = "Set Squad",
						execute = function()
							if element.text == "Make Captain" then
								tok.properties.minionSquad = m_selectedSquadId
							else
								tok.properties.minionSquad = nil
							end
						end,
					}
				end
			end

			if captainid ~= nil then
				--search the map for any other captain and remove it.
				local monsterTokens = dmhub.GetTokens{}
				for _,tok in ipairs(monsterTokens) do
					if tok.id ~= captainid and (not tok.properties.minion) and tok.properties:MinionSquad() == m_selectedSquadId then
						tok:ModifyProperties{
							description = "Set Squad",
							execute = function()
								tok.properties.minionSquad = nil
							end,
						}
					end
				end
			end
		end,
	}

	local formSquadButton = gui.Button{
        classes = {"collapsed"},
		width = 320,
		height = 30,
		text = "Form Squad",
		click = function(element)
            DrawSteelMinion.FormSquad(dmhub.selectedOrPrimaryTokens)
		end,
	}


	local monsterSquadPanel = gui.Panel{
		height = 30,
		width = "100%",
		flow = "horizontal",
		tokens = function(element, tokens)
			local nminions = 0
			local monsterType = nil
			local squadid = nil
			local minionParty = nil
			local potentialCaptain = nil
			for _,tok in ipairs(tokens) do
				if (not tok.properties.minion) then
					potentialCaptain = tok
				end
				if tok.properties.minion and tok.properties:has_key("monster_type") and (monsterType == nil or tok.properties.monster_type == monsterType) then
					nminions = nminions + 1
					monsterType = tok.properties.monster_type
					if squadid == nil then
						squadid = tok.properties:MinionSquad()
					elseif squadid ~= tok.properties:MinionSquad() then
						squadid = false
					end

					if minionParty == nil then
						minionParty = tok.ownerId
					elseif minionParty ~= tok.ownerId then
						minionParty = false
					end
				end
			end

			local showCaptainButton = false

			if nminions == #tokens-1 and potentialCaptain ~= nil and potentialCaptain.ownerId == minionParty then
				showCaptainButton = true
				if squadid ~= false and squadid ~= nil and potentialCaptain.properties:MinionSquad() == squadid then
					--this is already the captain. Can edit this squad.
					nminions = nminions + 1
					makeCaptainButton.text = "Remove Captain"
				else
					makeCaptainButton.text = "Make Captain"
					m_selectedSquadId = squadid
				end
			end

			makeCaptainButton:SetClass("collapsed", not showCaptainButton)

            local shouldCollapse = nminions < #tokens
            local haveFormSquad = false

			if nminions == #tokens and squadid ~= nil then
				if squadid == false then
                    haveFormSquad = true
                    shouldCollapse = true
				else
					monsterSquadInput.text = squadid
					monsterSquadColorPicker:SetClass("hidden", false)
					monsterSquadColorPicker.value = DrawSteelMinion.GetSquadColor(squadid)
					m_selectedSquadId = squadid
				end
			end

			element:SetClass("collapsed", shouldCollapse)
            formSquadButton:SetClass("collapsed", not haveFormSquad)
		end,
		gui.Label{
			width = 60,
			height = "auto",
			text = "Squad:",
			fontSize = 14,
			valign = "center",
		},

		monsterSquadInput,

		monsterSquadColorPicker,
	}

	local monsterEVPanel = gui.Panel{
		height = "auto",
		width = "100%",
		flow = "horizontal",
		gui.Label{
			width = "auto",
			height = "auto",
			text = "",
			fontSize = 14,

			multimonitor = "eds",
			monitor = function(element)
				if m_tokens ~= nil then
					element:FireEvent("tokens", m_tokens)
				end
			end,

			tokens = function(element, tokens)
				local monsterTokens = {}
				for _,tok in ipairs(tokens) do
					if tok.properties.typeName == "monster" then
						monsterTokens[#monsterTokens+1] = tok
					end
				end

				if #monsterTokens == 0 then
					element.text = ""
					return
				end

				local ev = 0
				for _,tok in ipairs(monsterTokens) do
                    if tok.properties.minion then
					    ev = ev + tok.properties.ev/GameSystem.minionsPerSquad
                    else
					    ev = ev + tok.properties.ev
                    end
				end

                ev = round(ev)

				local edsDescription
				local eds = g_edsSetting:Get()

				if ev <= eds/2 then
					edsDescription = "<color=#66ff66>Trivial</color>"
				elseif ev <= eds then
					local val = ev
					while val % 5 ~= 0 do
						val = val + 1
					end

					if val - eds/2 >= eds - val then
						edsDescription = "<color=#ffff66>Standard</color>"
					else
						edsDescription = "<color=#66ff66>Easy</color>"
					end
				elseif ev <= eds + 10 then
					edsDescription = "<color=#ff6666>Hard</color>"
				else
					edsDescription = "<color=#990000>Extreme</color>"
				end

				element.text = string.format("%d monsters selected, EV: %d (<b>%s</b>)", #monsterTokens, ev, edsDescription)
			end,
		},
	}

	resultPanel = gui.Panel{
		width = "100%",
		height = "auto",
		flow = "vertical",
		tokens = function(element, tokens)
			m_tokens = tokens
			if #tokens <= 1 then
				element:SetClass("collapsed", true)
			else
				element:SetClass("collapsed", false)
                for _,child in ipairs(element.children) do
                    child:FireEventTree("tokens", tokens)
                end
			end
		end,

		multiEditBaseFunction(),

		gui.Panel{
			width = "100%",
			height = "auto",
			flow = "vertical",

            addToInitiativeButton,
            groupInitiativeButton,
            ungroupInitiativeButton,
			makeCaptainButton,
            formSquadButton,
			monsterSquadPanel,

			gui.Panel{
				flow = "horizontal",
				width = "auto",
				height = "auto",
				gui.Label{
					width = "auto",
					height = "auto",
					text = "EDS:",
					fontSize = 14,
				},
				gui.Label{
					editable = true,
					width = 100,
					height = "auto",
					fontSize = 14,
					text = g_edsSetting:Get(),
					characterLimit = 3,
					multimonitor = "eds",
					monitor = function(element)
						element.text = tostring(g_edsSetting:Get())
					end,
					change = function(element)
						local n = tonumber(element.text)
						if n == nil or n < 10 or n > 1000 then
							element.text = tostring(g_edsSetting:Get())
							return
						end

						g_edsSetting:Set(n)
					end,
				}

			},
			monsterEVPanel,


		}
	}


	return resultPanel
end

CharacterPanel.PopulatePartyMembers = function(element, party, partyMembers, memberPanes)

	local m_folderPanels = element.data.folderPanels or {}
	element.data.folderPanels = m_folderPanels

	local newFolderPanels = {}

	local children = {}
	local newMemberPanes = {}

	for _,charid in ipairs(partyMembers) do

		local token = dmhub.GetCharacterById(charid)
		local creature = token.properties

		if creature ~= nil then
			local key = charid

			local folder = nil
			local squadid = creature:MinionSquad()

			if squadid ~= nil then
				key = squadid .. '-' .. charid

				folder = newFolderPanels[squadid]

				if folder == nil then

					folder = m_folderPanels[squadid]
					if folder == nil then
						local contentPanel = gui.Panel{
							width = "100%",
							height = "auto",
							flow = "vertical",
							halign = "center",
							vmargin = 4,
							hmargin = 4,
						}

						folder = gui.TreeNode{
							text = squadid,
							contentPanel = contentPanel,
							width = "100%-10",
							halign = "left",
							lmargin = 8,
							expanded = true,
							clickHeader = function(element)
								element:FireEventOnParents("ClearCharacterPanelSelection")
								local setFocus = false
								for _,p in ipairs(folder.data.children) do
									if not setFocus then
										gui.SetFocus(p)
										setFocus = true
									else
										element:FireEventOnParents("AddCharacterPanelToSelection", p)
									end
								end
							end,
						}

						local labels = folder:GetChildrenWithClassRecursive("folderLabel")
						for _,label in ipairs(labels) do
							label:SetClass("folderLabel", false)
							label:SetClass("bestiaryLabel", true)
						end

						folder.data.contentPanel = contentPanel
					end

					newFolderPanels[squadid] = folder

					--first time seeing this folder this refresh so re-init children.
					folder.data.children = {}
				end


			end

			local child = memberPanes[key] or CharacterPanel.CreateCharacterEntry(charid)
			newMemberPanes[key] = child
			child:FireEventTree("prepareRefresh")

			if folder ~= nil then
				folder.data.children[#folder.data.children+1] = child
			else
				children[#children+1] = child
			end
		end
	end

	table.sort(children, function(a,b)
		local aname = a.data.token.playerNameOrNil
		local bname = b.data.token.playerNameOrNil
		if aname == nil and bname == nil then
			return a.data.token.description < b.data.token.description
		end

		if aname == nil then
			return false
		end

		if bname == nil then
			return true
		end

		if aname == bname then
			return cond(a.data.primaryCharacter, 0, 1) < cond(b.data.primaryCharacter, 0, 1)
		end

		return aname < bname

	end)

	local folderChildren = {}
	for squadid,folder in pairs(newFolderPanels) do
		local newChildren = folder.data.children
		table.sort(newChildren, function(a,b)
			return a.data.token.description < b.data.token.description
		end)

		folder.data.contentPanel.children = newChildren
		folder.data.ord = squadid

		folderChildren[#folderChildren+1] = folder
	end

	for _,folder in ipairs(folderChildren) do
		children[#children+1] = folder
	end

	element.children = children

	element.data.folderPanels = newFolderPanels

	return newMemberPanes
end

function CharacterPanel.AbilitiesPanel(token)
    local resultPanel

    local m_panels = {}

	resultPanel = gui.Panel{
		width = "100%",
		height = "auto",
		flow = "vertical",
		vmargin = 6,
		styles = {
			{
                selectors = {"notesLabel"},
				fontSize = 14,
                color = Styles.textColor,
                width = "90%",
                height = "auto",
                halign = "center",
			},
		},

        refreshToken = function(element, token)
            local creature = token.properties
            local features = creature:try_get("characterFeatures")
            if features == nil or #features == 0 then
                element:SetClass("collapsed", true)
            else
                element:SetClass("collapsed", false)

                local panelIndex = 1

                if creature.withCaptain and creature.minion then
                    local squad = creature:try_get("_tmp_minionSquad")
                    local hasCaptain = squad ~= nil and squad.hasCaptain
                    local panel = m_panels[panelIndex] or gui.Label{
                        classes = {"notesLabel"},
                        markdown = true,
                    }

                    local hasCaptainColor = cond(hasCaptain, "#ff", "#55")

                    local implemented = DrawSteelMinion.GetWithCaptainEffect(creature.withCaptain) ~= nil
                    local implementedColor = cond(implemented, "#ff", "#55")

                    panel.text = string.format("<b><alpha=%s>With Captain</b> <alpha=%s>%s<alpha=#ff>", hasCaptainColor, implementedColor, creature.withCaptain)

                    
                    panel:SetClass("collapsed", false)
                    m_panels[panelIndex] = panel
                    panelIndex = panelIndex + 1
                end

                for i,feature in ipairs(features) do
                    local panel = m_panels[panelIndex] or gui.Label{
                        classes = {"notesLabel"},
                        markdown = true,
                    }

                    local implemented = feature:try_get("implementation", 1) ~= 1
                    local implementedColor = cond(implemented, "#ff", "#55")

                    panel.text = string.format("<b>%s:</b> <alpha=%s>%s<alpha=#ff>", feature.name, implementedColor, feature.description)

                    panel:SetClass("collapsed", false)
                    m_panels[panelIndex] = panel
                    panelIndex = panelIndex + 1
                end

                for i=panelIndex,#m_panels do
                    m_panels[i]:SetClass("collapsed", true)
                end

                element.children = m_panels
            end
        end,
	}

    return resultPanel
end

function CharacterPanel.SkillsPanel(token)
	local resultPanel

	local panels = {}

	for _,cat in ipairs(Skill.categories) do
		local panel = gui.Label{
			width = "100%",
			height = "auto",
			textAlignment = "left",

			create = function(element)
				element:FireEvent("refreshToken", token)
			end,
			refreshToken = function(element, token)
				local proficiencyList = nil
				for i,skill in ipairs(Skill.SkillsInfo) do
					if skill.category == cat.id and token.properties:ProficientInSkill(skill) then
						if proficiencyList == nil then
							proficiencyList = skill.name
						else
							proficiencyList = proficiencyList .. ", " .. skill.name
						end
					end
				end
				
				if proficiencyList == nil then
					element:SetClass("collapsed", true)
				else
					element:SetClass("collapsed", false)
					element.text = string.format("<b>%s:</b> %s", cat.text, proficiencyList)
				end
			end,
		}

		panels[#panels+1] = panel
	end

	resultPanel = gui.Panel{
		width = "100%",
		height = "auto",
		flow = "vertical",
		vmargin = 6,
		styles = {
			{
				fontSize = 14,
			}
		},
		children = panels,
	}

	return resultPanel
end

--important attributes beyond characteristics
--e.g. things like stability etc.
function CharacterPanel.ImportantAttributesPanel(token)
	local m_token = token

    local resultPanel

    local stabilityPanel = gui.Label{
    }

    resultPanel = gui.Panel{
        flow = "vertical",
        width = "100%",
        height = "auto",

        styles = {
            {
                selectors = {"label"},
                fontSize = 14,
                width = "auto",
                height = "auto",
            },
        },

        stabilityPanel,

		refreshToken = function(element, newToken)
            token = newToken
			m_token = newToken

            local stability = token.properties:Stability()
            stabilityPanel.text = string.format("<b>Stability:</b> %d", stability)
		end,
    }

    return resultPanel
end

function CharacterPanel.CharacteristicsPanel(token)

	local m_token = token

	local resultPanel

	local panels = {}

	for index,attrid in ipairs(creature.attributeIds) do
		local attrInfo = creature.attributesInfo[attrid]
		--local width = string.format("%.2f%%", (100/#creature.attributeIds))
		local halign = "center"
		if index == 1 then
			halign = "left"
		elseif index == #creature.attributeIds then
			halign = "right"
		end
		local panel = gui.Panel{
			width = "auto",
			height = "auto",
			halign = halign,
			flow = "vertical",
			bgimage = "panels/square.png",
			bgcolor = "clear",

			press = function(element)
				m_token.properties:ShowCharacteristicRollDialog(attrid)
			end,

            hover = function(element)
                if m_token == nil or (not m_token.valid) then
                    return
                end
                local text = ""
                local potency = m_token.properties:AttributeForPotencyResistance(attrid)
                if m_token.properties:GetAttribute(attrid):Modifier() ~= potency then
                    local attrName = creature.attributesInfo[attrid].description
                    text = string.format("Your %s counts as %s for resisting potencies.\nBasic Might Score: %d", attrName, ModifierStr(potency), m_token.properties:GetAttribute(attrid):Value())
                    local modifications = m_token.properties:AttributeForPotencyResistanceDescription(attrid)
                    for _,modification in ipairs(modifications) do
                        text = string.format("%s\n%s: %s", text, modification.key, modification.value)
                    end
                end

                if text ~= "" then
                    gui.Tooltip(text)(element)
                end
            end,

            gui.Panel{
                width = "auto",
                height = "auto",
                flow = "horizontal",
                gui.Label{
                    text = attrInfo.description,
                    height = 14,
                    width = "auto",
                    halign = "center",
                },
                gui.Label{
                    classes = {"asterisk"},
                    text = "*",
                    valign = "top",
                    width = "auto",
                    height = "auto",
                    create = function(element)
                        element:FireEvent("refreshToken", token)
                    end,
                    refreshToken = function(element, token)
                        element:SetClass("collapsed", token.properties:GetAttribute(attrid):Modifier() == token.properties:AttributeForPotencyResistance(attrid))
                    end,
                },
            },
			gui.Label{
				text = "0",
				width = "auto",
				height = 14,
				halign = "center",
				valign = "center",
				minWidth = 20,
				lmargin = 4,
				textAlignment = "left",
				create = function(element)
					element:FireEvent("refreshToken", token)
				end,
				refreshToken = function(element, token)
					element.text = ModifierStr(token.properties:GetAttribute(attrid):Modifier())
				end,

			},
		}

		panels[#panels+1] = panel
	end

	resultPanel = gui.Panel{
		flow = "horizontal",
		width = "100%",
		height = "auto",

		styles = {
			{
				height = 18,
				fontSize = 11,
				bold = true,
				uppercase = true,
			},
			{
				selectors = {"label"},
				color = "#dddddd",
			},
            {
                selectors = {"asterisk"},
                color = "#ff00ff",
            },
			{
				selectors = {"label", "parent:hover"},
				color = "#ffffff",
			},
		},

		children = panels,
		refreshToken = function(element, newToken)
            token = newToken
			m_token = newToken
		end,
	}

	return resultPanel

end

function CharacterPanel.SingleCharacterDisplaySidePanel(token)

	local characterDisplaySidebar

	local conditionsPanel = CharacterPanel.CreateConditionsPanel(token)

	local summaryPanel = gui.Panel{
		bgimage = "panels/square.png",
		flow = "horizontal",
		styles = {
			{
				halign = "left",
				valign = "center",
				pad = 2,
				height = "auto",
				width = "100%",
				bgcolor = '#000000aa',
				borderColor = '#000000ff',
				borderWidth = 2,
				flow = 'horizontal',
			},
		},

		gui.Panel{
			id = "LeftPanel",
			valign = "top",
			width = "78% height",
			height = 140,
			bgimage = "panels/square.png",
			bgcolor = "white",
			lmargin = 16,
			borderWidth = 2,
			borderColor = Styles.textColor,

			refreshCharacter = function(element, token)
				element.bgimage = token.portrait
				element.selfStyle.imageRect = token:GetPortraitRectForAspect(78*0.01)
			end,

			CharacterPanel.DecoratePortraitPanel(token),

		},

		gui.Panel({
			id = 'RightPanel',
			valign = "top",
			style = {
				width = '60%',
				height = 'auto',
				halign = 'center',
				flow = 'vertical',
				vmargin = 0,
			},

			children = {

				CharacterPanel.ShowHitpoints(),
				conditionsPanel,
			},
		}),

	}

	characterDisplaySidebar = gui.Panel{
		id = 'sidebar',

		width = "auto",
		height = "auto",
		halign = "left",
		flow = "vertical",

		events = {
			refresh = function(element)
				if token == nil or not token.valid then
					return
				end

				element.data.displayedProperties = token.properties
				element.data.hasInit = true

				characterDisplaySidebar:FireEventTree('refreshCharacter', token)

			end,

			setToken = function(element, tok)
				token = tok
				element.data.token = token
			end,
		},

		data = {
			token = token,
			hasInit = false,
			displayedProperties = nil,
		},

		summaryPanel,
	}

	return characterDisplaySidebar
end