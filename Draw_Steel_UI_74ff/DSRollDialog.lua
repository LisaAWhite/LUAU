local mod = dmhub.GetModLoading()

--This file implements the main roll prompt dialog that appears when you get a dice roll prompt.

local g_holdingRollOpen = false
dmhub.HoldAmendableRollOpen = function()
    return g_holdingRollOpen
end

local g_activeRoll = nil
local g_activeRollArgs = nil

setting{
	id = "privaterolls",
	description = "Default Roll Visibility",
	storage = "preference",
	default = "visible",
	editor = "dropdown",
	section = "Game",

	enum = {
		{
			value = "visible",
			text = "Visible to Everyone",
		},
		{
			value = "dm",
			text = cond(dmhub.isDM, "Visible to GM only", "Visible to you and GM"),
		}
	}
}

setting{
	id = "privaterolls:save",
	description = "Save roll visibility preferences",
	storage = "preference",
	default = true,
	editor = "check",
}

local g_rollOptionsDM = {
	{
		id = "visible",
		text = "Visible to Everyone",
	},
	{
		id = "dm",
		text = "Visible to GM only",
	},
}

local g_rollOptionsPlayer = {
	{
		id = "visible",
		text = "Visible to Everyone",
	},
	{
		id = "dm",
		text = "Visible to you and GM",
	},
}

local g_boonsBanesStyles = {
    gui.Style{
        selectors = {"label"},
        color = Styles.textColor,
        valign = "center",
        width = "20%",
        height = "100%",
        bgimage = "panels/square.png",
        fontSize = 16,
        textAlignment = "center",
        borderWidth = 1,
        borderColor = Styles.textColor,
    },
    gui.Style{
        selectors = {"label", "selected"},
        bgcolor = Styles.textColor,
        color = "black",
        bold = true,
    },
    gui.Style{
        selectors = {"label", "hover", "~selected"},
        bgcolor = Styles.textColor,
        color = "black",
        brightness = 0.9,
    },
}

local g_boonsLabels = {"Bane x 2", "Bane", "None", "Edge", "Edge x 2"}


function GameHud.CreateRollDialog(self)

	--the creature doing the roll
	local creature = nil

	--creature targeted by the roll.
	local targetCreature = nil

	--a table of multiple tokens targeted by this roll.
	local m_multitargets = nil

    local GetCurrentMultiTarget = function()
        if m_multitargets == nil or targetCreature == nil then
            return nil
        end

        for i,target in ipairs(m_multitargets) do
            if target.token.properties == targetCreature then
                return i
            end
        end

        return nil
    end

	local m_symbols = nil

	local rollType = ''
	local rollSubtype = ''
	local rollProperties = nil

	local resultPanel
	local CalculateRollText

	local rollAllPrompts = nil
	local rollActive = nil
	local beginRoll = nil
	local completeRoll = nil
	local cancelRoll = nil

	local m_shown = 0
    local m_richStatus = nil

	local OnShow = function(richStatus)
		chat.events:Push()
		chat.events:Listen(resultPanel)
        if m_richStatus ~= nil then
            dmhub.PopUserRichStatus(m_richStatus)
            m_richStatus = nil
        end

        m_richStatus = dmhub.PushUserRichStatus(richStatus)

		m_shown = m_shown+1
	end

	local OnHide = function()
        if m_richStatus ~= nil then
            dmhub.PopUserRichStatus(m_richStatus)
            m_richStatus = nil
        end

		if m_shown > 0 then
			chat.events:Pop()
			m_shown = m_shown-1
		end
	end

    local RelinquishPanel = function()
		--relinquish the coroutine owning this panel.
		resultPanel.data.coroutineOwner = nil
        g_holdingRollOpen = false
    end


	local styles = {
		Styles.Panel,
		{
			selectors = {'framedPanel'},
			width = 940,
			height = 700,
			halign = "center",
			valign = "center",
			bgcolor = 'white',
		},
		{
			selectors = {'main-panel'},
			width = '100%-32',
			height = '100%-32',
			flow = 'vertical',
			halign = 'center',
			valign = 'center',
		},
		{
			selectors = {'buttonPanel'},
			width = '100%',
			height = 60,
			flow = 'horizontal',
			valign = 'bottom',
		},
		{
			selectors = {'title'},
			width = 'auto',
			height = 'auto',
			color = 'white',
			halign = 'center',
			valign = 'top',
			fontSize = 28,
		},
		{
			selectors = {'explanation'},
			width = 'auto',
			height = 'auto',
			color = 'white',
			halign = 'center',
			valign = 'top',
			fontSize = 20,
		},
		{
			selectors = {'roll-input'},
			width = '90%',
			halign = 'center',
			priority = 20,
			fontSize = 22,
			height = 34,
			valign = 'center',
		},
		{
			selectors = {'checkbox'},
			height = 24,
			width = 'auto',
		},
		{
			selectors = {'checkbox-label'},
			fontSize = 18,
		},
		{
			selectors = {'modifiers-panel'},
			flow = 'vertical',
			height = 'auto',
			width = 'auto',
		},

		Styles.AdvantageBar,

        {
            selectors = {"hiddenWhenRolling", "rolling"},
            hidden = 1,
        },
        {
            selectors = {"hiddenWhenRolling", "finishedRolling"},
            hidden = 1,
        },
        {
            selectors = {"shownWhenFinished", "~finishedRolling"},
            collapsed = 1,
        },
        {
            selectors = {"shownWhenRollingOrFinished", "~finishedRolling", "~rolling"},
            collapsed = 1,
        },

        {
            selectors = {"icon"},
            bgcolor = "white",
            height = 32,
            width = 32,
        },

        {
            selectors = {"icon", "hover"},
            brightness = 2.0,
            transitionTime = 0.2,
        },
        {
            selectors = {"icon", "override"},
            bgcolor = "#ffff88",
            transitionTime = 0.2,
        },
        {
            selectors = {"icon", "override", "inactive"},
            bgcolor = "#666633",
            transitionTime = 0.2,
        },
	}

	local title = gui.Label{
		id = "rollDialogTitle",
		classes = {'title'},
		color = Styles.textColor,
	}

	local explanation = gui.Label{
		classes = {'explanation'},
	}

	local ShowTargetHints

	local rollInput = gui.Input{
		classes = {'roll-input'},
		events = {
			edit = function(element)
                if element:HasClass("rolling") or element:HasClass("finishedRolling") then
                    return
                end
				chat.PreviewChat(string.format('/roll %s', element.text))
				ShowTargetHints(element.text)
			end,
			change = function(element)
                if element:HasClass("rolling") or element:HasClass("finishedRolling") then
                    return
                end
				chat.PreviewChat(string.format('/roll %s', element.text))
			end,
		},
	}


	local autoRollCheck = gui.Check{
		text = "Auto-roll",
		value = false,
		valign = "bottom",
	}
	local autoHideCheck = gui.Check{
		text = "Auto-hide",
		value = false,
		valign = "bottom",
	}
	local autoQuickCheck = gui.Check{
		text = "Auto-quick",
		value = false,
		valign = "bottom",
	}

	local rollAllPromptsCheck = gui.Check{
		text = "Roll all prompts",
		value = true,
		valign = "bottom",
	}

	local autoRollId = nil

	local autoRollPanel = gui.Panel{
		valign = "bottom",
		width = "80%",
		height = "auto",
		flow = "vertical",
		autoHideCheck,
		autoQuickCheck,
		autoRollCheck,
	}

	local prerollCheck = gui.Check{
		text = "Pre-roll dice",
        classes = {"hiddenWhenRolling"},
		value = dmhub.GetSettingValue("preroll"),
		valign = "bottom",
		vmargin = 6,
		change = function(element)
			dmhub.SetSettingValue("preroll", element.value)
			CalculateRollText()
		end,
		textCalculated = function(element)
			element:SetClass("collapsed", (not dmhub.isDM))
		end,
	}

	local updateRollVisibility
	local hideRollDropdown = gui.Dropdown{
        classes = {"hiddenWhenRolling"},
		width = 300,
		height = 32,
		valign = "center",
		fontSize = 18,
		idChosen = dmhub.GetSettingValue("privaterolls"),
		options = cond(dmhub.isDM, g_rollOptionsDM, g_rollOptionsPlayer),
		valign = "bottom",
		prepare = function(element)
			element.idChosen = dmhub.GetSettingValue("privaterolls")
		end,

		change = function(element)
			updateRollVisibility:FireEvent("prepare")
		end,
	}

	updateRollVisibility = gui.Check{
        classes = {"hiddenWhenRolling"},
		text = "Use roll visibility setting for all rolls",
		valign = "bottom",
		value = dmhub.GetSettingValue("privaterolls:save"),
		prepare = function(element)
			updateRollVisibility:SetClass("hidden", hideRollDropdown.idChosen == dmhub.GetSettingValue("privaterolls"))
		end,
	}

	local m_options

	--a selectors which allows alternate roll options to be selected, e.g. choosing between an Athletics and Acrobatics check.
	local alternateRollsBar


	--targets we record damage or other things about.
	local targetHints = nil

	ShowTargetHints = function(rollText)
		for i,hint in ipairs(targetHints or {}) do
			local str = rollText

			if m_multitargets ~= nil and m_multitargets[i] ~= nil then
				local boons = m_multitargets[i].boons
				if boons ~= nil and boons > 0 then
					str = string.format("%s + %dd4", str, boons)
				elseif boons ~= nil and boons < 0 then
					str = string.format("%s - %dd4", str, -boons)
				end
			end

			if hint.half then
				str = str .. " HALF"
			end
			
			creature.UploadExpectedCreatureDamage(hint.charid, resultPanel.data.rollid, str)
		end
	end

	local RemoveTargetHints = function()
		for _,hint in ipairs(targetHints or {}) do
			creature.UploadExpectedCreatureDamage(hint.charid, resultPanel.data.rollid, nil)
		end
	end

	local rollDisabledLabel
	local rollDiceButton
	local cancelButton
    local proceedAfterRollButton
    local rollAgainButton

	local modifierChecks = {}
	local modifierDropdowns = {}

	local m_boons = 0

	local boonBar
    local surgesBar

	local m_activeModifiers = {}

	local m_customContainer
	local m_tableContainer

    local GetEnabledModifiers = function()
        local enabledModifiers = {}
		for i,mod in ipairs(m_options.modifiers or {}) do
			if mod.modifier then
				local ischecked = false
				local force = mod.modifier:try_get("force", false)
                if mod.override ~= nil then
                    ischecked = mod.override
				elseif force then
					ischecked = true
				elseif mod.hint ~= nil then
					ischecked = mod.hint.result
				end

                            print("BOONS:: CHECK mod fails =", i, mod.failsRequirement)
                if ischecked and (not mod.failsRequirement) then
                    enabledModifiers[#enabledModifiers+1] = mod
                end
            end
        end

        return enabledModifiers
    end


	--this is the current 'base roll' that is being calculated based on.
	local baseRoll = '1d6'
	CalculateRollText = function(calculationOptions)
		m_activeModifiers = {}

		local rollDisallowed = nil

		local roll = baseRoll

        local enabledModifiers = GetEnabledModifiers()

		if GameSystem.UseBoons then
			roll = GameSystem.ApplyBoons(roll, m_boons)
		end

		if creature then
			local syms = {
				target = GenerateSymbols(targetCreature)
			}

			if m_symbols ~= nil then
				for k,v in pairs(m_symbols) do
					syms[k] = v
				end
			end
			roll = dmhub.NormalizeRoll(roll, creature:LookupSymbol(syms), "Calculate roll")
		end

		local afterCritMods = {}

		if creature then
			for i,mod in ipairs(enabledModifiers) do
				--call this generic function which might be modified by mods.
				roll = mod.modifier:ApplyToRoll(mod.context, creature, targetCreature, rollType, roll)

				if rollType == 'damage' then
					if mod.modFromTarget then
						roll = mod.modifier:ModifyDamageAgainstUs(mod.context, targetCreature, creature, roll)

					elseif mod.modifier:CriticalHitsOnly() then
						afterCritMods[#afterCritMods+1] = mod
					else
						roll = mod.modifier:ModifyDamageRoll(mod, creature, targetCreature, roll)
					end
				end

				m_activeModifiers[#m_activeModifiers+1] = mod.modifier
			end

			for i,dropdown in ipairs(modifierDropdowns) do
				for j,option in ipairs(dropdown.data.mod.modifierOptions) do
					if option.id == dropdown.idChosen and option.mod ~= nil then
						if rollType == 'damage' then
							roll = option.mod:ModifyDamageRoll(option, creature, targetCreature, roll)
						end

						m_activeModifiers[#m_activeModifiers+1] = option.mod

						if option.disableRoll then
							rollDisallowed = option.disableRoll
						end
					end
				end
			end
		end

		if rollDisallowed ~= nil then
			rollDisabledLabel:SetClass("collapsed-anim", false)
			rollDisabledLabel.text = rollDisallowed
		else
			rollDisabledLabel:SetClass("collapsed-anim", true)
		end

		rollDiceButton:SetClass("hidden", rollDisallowed ~= nil)

		local rollInfo = dmhub.ParseRoll(roll, creature)

		local newText = dmhub.RollToString(rollInfo)

		if #afterCritMods > 0 then
			for i,mod in ipairs(afterCritMods) do
				newText = mod.modifier:ModifyDamageRoll(mod, creature, targetCreature, newText)
			end

			rollInfo = dmhub.ParseRoll(newText, creature)
			newText = dmhub.RollToString(rollInfo)
		end

		if dmhub.isDM and dmhub.GetSettingValue("preroll") then
			local cats = dmhub.RollInstantCategorized(newText)
			newText = ""
			for k,n in pairs(cats) do
				newText = string.format("%s%s%s [%s]", newText, cond(newText == "", "", " "), n, k)
			end

			newText = dmhub.RollToString(dmhub.ParseRoll(newText, creature))
		end

		if GameSystem.CombineNegativesForRolls then
			newText = dmhub.NormalizeRoll(newText, nil, nil, {"NormalizeNegatives"})
		end

		if newText ~= rollInput.text then
			rollInput.text = newText
		else
			rollInput:FireEvent('change')
		end

		if rollProperties ~= nil then
            resultPanel:FireEventTree("prepareBeforeRollProperties", rollInfo)

            enabledModifiers = GetEnabledModifiers()

			rollProperties:ResetMods()

			for i,mod in ipairs(enabledModifiers) do
				mod.modifier:ModifyRollProperties(mod.context, creature, rollProperties)
			end
		end

		ShowTargetHints(newText)

        calculationOptions = calculationOptions or {}
        calculationOptions.rollInfo = dmhub.ParseRoll(newText, creature)
		resultPanel:FireEventTree("textCalculated", calculationOptions)


		if rollProperties ~= nil then
			if not m_customContainer:HasClass("collapsed") then
				m_customContainer:FireEventTree("refreshMods")
			end

			if not m_tableContainer:HasClass("collapsed") then
				m_tableContainer:FireEventTree("refreshMods")
			end

            if m_multitargets == nil then
                rollProperties.multitargets = nil
            else
                rollProperties.multitargets = {}
                for _,target in ipairs(m_multitargets) do
                    local t = DeepCopy(target)
                    t.tokenid = target.token.charid
                    t.token = nil
                    rollProperties.multitargets[#rollProperties.multitargets+1] = t
                end
            end
		end

        return roll
	end

	local rerollFudgedButton = gui.HudIconButton{
		icon = "panels/hud/clockwise-rotation.png",
		halign = "right",
		valign = "center",
        width = 32,
        height = 32,
		press = function(element)
			CalculateRollText()
		end,
		textCalculated = function(element)
			element:SetClass("hidden", (not dmhub.isDM) or (not dmhub.GetSettingValue("preroll")))
		end,
	}

	local rollInputContainer = gui.Panel{
		width = "auto",
		flow = "horizontal",
		width = '80%',
		halign = 'center',
		height = 34,
		valign = 'center',
		rollInput,
		rerollFudgedButton,
	}

	local tableStyles = {
		Styles.Table,
		gui.Style{
			selectors = {"label"},
			pad = 6,
			fontSize = 20,
			width = "auto",
			height = "auto",
			color = Styles.textColor,
			valign = "center",
		},
		gui.Style{
			selectors = {"row"},
			width = "auto",
			height = "auto",
			bgimage = "panels/square.png",
			borderColor = Styles.textColor,
			borderWidth = 1,
		},
		gui.Style{
			selectors = {"row", "oddRow"},
			bgcolor = "#222222ff",
		},
		gui.Style{
			selectors = {"row", "evenRow"},
			bgcolor = "#444444ff",
		},
	}

	m_customContainer = gui.Panel{
		width = "94%",
		height = "auto",
		halign = "center",
		valign = "bottom",
		flow = "vertical",
		styles = tableStyles,
	}

	m_tableContainer = gui.Table{
		width = "60%",
		height = "auto",
		halign = "center",
		valign = "bottom",
		flow = "vertical",
		styles = tableStyles,
	}

    local RecalculateMultiTargets

    local m_lastCalculationOptions = nil

	local multitokenContainer = gui.Panel{
        styles = {
            {
                selectors = {"tokenContainer"},
                bgimage = "panels/square.png",
                bgcolor = "#00000000",
            },
            {
                selectors = {"tokenContainer", "selected"},
                bgimage = "panels/square.png",
                bgcolor = "#ffffff18",
            },
            {
                selectors = {"tokenContainer", "hover"},
                bgimage = "panels/square.png",
                bgcolor = "#ffffff22",
            },
            {
                selectors = {"icon"},
                bgimage = "game-icons/surge.png",
                width = 16,
                height = 16,
                bgcolor = "#ffffff33",
            },
            {
                selectors = {"icon", "activated"},
                bgcolor = "white",
            },
        },
		width = "auto",
		height = "auto",
        maxWidth = 400,
		halign = "center",
		valign = "top",
		flow = "horizontal",
        wrap = true,
		prepare = function(element, options)
			if m_multitargets == nil or #m_multitargets <= 1 then
				element:SetClass("collapsed", true)
				return
			end

			element:SetClass("collapsed", false)

			local children = {}

			for i,target in ipairs(m_multitargets) do
                local nameLabel = gui.Label{
                    fontSize = 12,
                    bold = true,
                    color = Styles.textColor,
                    width = "95%",
                    height = "auto",
                    halign = "center",
                    textOverflow = "truncate",
                    text = target.token.name,
                    textAlignment = "center",
                }
				local boonLabel = gui.Label{
					fontSize = 10,
					color = cond(target.text == nil, Styles.textColor, "#9999ffff"),
					width = "95%",
					height = "auto",
					halign = "center",
					valign = "top",
                    textAlignment = "center",
                    characterLimit = 28,

					hover = function(element)
						if target.text ~= nil then
							gui.Tooltip(target.text)(element)
						end
					end,

                    recalculatedMultiTargets = function(element, multitargets)
                        if multitargets == nil then
                            return
                        end

                        local maintarget = multitargets[GetCurrentMultiTarget()]
                        local multitarget = multitargets[i]

                        if maintarget == nil or multitarget == nil then
                            return
                        end
                        

                        if maintarget == multitarget then
                            element.text = ""
                            return
                        end

                        local maintargetModifiers = {}
                        local multitargetModifiers = {}

                        for _,mod in ipairs(maintarget.modifiers) do
                            if mod.modifier ~= nil then
                                local ischecked = false
                                local force = mod.modifier:try_get("force", false)
                                if mod.override ~= nil then
                                    ischecked = mod.override
                                elseif force then
                                    ischecked = true
                                elseif mod.hint ~= nil then
                                    ischecked = mod.hint.result
                                end

                                if ischecked then
                                    maintargetModifiers[mod.modifier.name] = true
                                end
                            end
                        end

                        for _,mod in ipairs(multitarget.modifiers) do
                            if mod.modifier ~= nil then
                                local ischecked = false
                                local force = mod.modifier:try_get("force", false)
                                if mod.override ~= nil then
                                    ischecked = mod.override
                                elseif force then
                                    ischecked = true
                                elseif mod.hint ~= nil then
                                    ischecked = mod.hint.result
                                end

                                if ischecked then
                                    multitargetModifiers[mod.modifier.name] = true
                                end
                            end
                        end

                        local text = ""

                        for k,_ in pairs(maintargetModifiers) do
                            if multitargetModifiers[k] == nil then
                                text = text .. " <s><color=#BBBBBB>" .. k .. "</color></s>"
                            end
                        end

                        for k,_ in pairs(multitargetModifiers) do
                            if maintargetModifiers[k] == nil then
                                text = text .. " <b>" .. k .. "</b>"
                            end
                        end

                        element.text = text
                    end,
				}

                local surges = {}
                for surgeNum=3,1,-1 do
                    surges[#surges+1] = gui.Panel{
                        classes = {"icon"},
		                textCalculated = function(element, calculationOptions)
                            if m_multitargets == nil or m_multitargets[i] == nil then
                                return
                            end
                            element:SetClass("activated", (m_multitargets[i].surges or 0) >= surgeNum)

                            local surgesAvailable = creature:GetAvailableSurges()
                            for i=1,#m_multitargets do
                                surgesAvailable = surgesAvailable - (m_multitargets[i].surges or 0)
                            end

                            element:SetClass("hidden", (surgeNum - (m_multitargets[i].surges or 0)) > surgesAvailable)
                        end,
                        press = function(element)
                            if m_multitargets[i].surges == surgeNum then
                                m_multitargets[i].surges = surgeNum - 1
                            else
                                m_multitargets[i].surges = surgeNum
                            end
                            RecalculateMultiTargets()
                        end,
                    }
                end

				local tokenPanel = gui.Panel{
                    classes = {"tokenContainer", cond(targetCreature == target.token.properties, "selected")},
					width = 80,
					height = 80,
					flow = "vertical",
                    halign = "center",

                    press = function(element)
                        for i,child in ipairs(element.parent.children) do
                            child:SetClass("selected", child == element)
                        end
				        targetCreature = target.token.properties
                        m_options.targetCreature = targetCreature
                        m_options.modifiers = m_multitargets[i].modifiers

                        local calculationOptions = m_lastCalculationOptions or {}
                        calculationOptions.surges = target.surges or 0

                        resultPanel:FireEventTree('prepare', m_options)
						CalculateRollText(calculationOptions)

                        RecalculateMultiTargets()
                    end,

                    gui.Panel{
                        flow = "horizontal",
                        width = "100%",
                        height = 48,
                        gui.CreateTokenImage(target.token, {
                            halign = "center",
                            valign = "top",
                            width = 48,
                            height = 48,
                            bgcolor = "white",
                        }),

                        gui.Panel{

                            floating = true,
                            halign = "right",
                            flow = "vertical",
                            height = "100%",
                            width = 16,
                            children = surges,
                        }
                    },

                    nameLabel,
					boonLabel,
				}

				children[#children+1] = tokenPanel
			end

			element.children = children
		end,
	}

	alternateRollsBar = gui.Panel{
		classes = {'advantage-bar'},
		prepare = function(element, options)
			if options.alternateOptions == nil or #options.alternateOptions <= 1 then
				element:SetClass("collapsed-anim", true)
				return
			end

			local chooseAlternate = options.chooseAlternate
			local children = {}
			for optionIndex,alternate in ipairs(options.alternateOptions) do
				children[#children+1] = gui.Label{
					bgimage = 'panels/square.png',
					classes = {'advantage-element', cond(options.alternateChosen == optionIndex, "selected")},
					text = alternate.text,
					press = function(element)
						chooseAlternate(optionIndex)
					end,
				}
				
			end

			element.children = children
			element:SetClass("collapsed-anim", false)
		end,
	}

	if GameSystem.UseBoons then

        local boonsBanesLabels = {}

        local m_currentBoons = 0

        for i,text in ipairs(g_boonsLabels) do
            boonsBanesLabels[#boonsBanesLabels+1] = gui.Label{
                text = text,
                press = function(element)
                    local delta = (i - 3) - m_currentBoons
                    m_boons = m_boons + delta
                    if GetCurrentMultiTarget() ~= nil then
                        local index = GetCurrentMultiTarget()
                        m_multitargets[index].boonsOverride = (m_multitargets[index].boonsOverride or 0) + delta
                    end
					CalculateRollText()
                end,
                textCalculated = function(element, calculationOptions)
                    local rollInfo = (calculationOptions or {}).rollInfo or {}
                    m_currentBoons = (rollInfo.boons or 0) - (rollInfo.banes or 0)
                    element:SetClass("selected", m_currentBoons == i-3)
                end,
            }
        end

        boonBar = gui.Panel{
            styles = g_boonsBanesStyles,
            classes = {"boonbanePanel"},
            halign = "center",
            width = "60%",
            height = 22,
            flow = "horizontal",

			prepare = function(element, options)
				element:SetClass("collapsed", not GameSystem.AllowBoonsForRoll(options))
				m_boons = 0

                if GetCurrentMultiTarget() ~= nil then
                    local index = GetCurrentMultiTarget()
                    m_boons = (m_multitargets[index].boonsOverride or 0)
                end
			end,

            children = boonsBanesLabels,
        }

        boonBar:AddChild(gui.Panel{
            classes = {"icon"},
            bgimage = "panels/hud/anticlockwise-rotation.png",
            floating = true,
            halign = "right",
            x = 20,
            width = 16,
            height = 16,
            textCalculated = function(element, calculationOptions)
                element:SetClass("hidden", m_boons == 0)
            end,
            press = function(element)
                m_boons = 0
                CalculateRollText()
            end,
        })
	end


    local CreateSurgeIcon = function(index)
        return gui.Panel{
            classes = {"icon","surges"},
		    textCalculated = function(element, calculationOptions)
                local surgesAvailable = creature:GetAvailableSurges()
                if m_multitargets ~= nil and #m_multitargets > 1 then
                    local mainTarget = GetCurrentMultiTarget()
                    for i=1,#m_multitargets do
                        if i ~= mainTarget and m_multitargets[i].surges ~= nil then
                            surgesAvailable = surgesAvailable - m_multitargets[i].surges
                        end
                    end
                end

                m_lastCalculationOptions = calculationOptions
                calculationOptions = calculationOptions or {}
                element:SetClass("collapsed", rollProperties == nil or rollProperties.typeName ~= "RollPropertiesPowerTable" or creature == nil or surgesAvailable < index)
                if rollProperties ~= nil and (not element:HasClass("collapsed")) then
                    element:SetClass("override", calculationOptions.surges ~= nil)
                    element:SetClass("inactive", (calculationOptions.surges or rollProperties:try_get("surges", 0)) < index)
                    if (not element:HasClass("inactive")) then
                        rollProperties:ModifyDamage(creature:HighestCharacteristic())
                    end
                end
            end,

            press = function(element)
                local surgesOverride = index
                if not element:HasClass("inactive") then
                    surgesOverride = surgesOverride-1
                end

                if surgesOverride > 3 then
                    surgesOverride = 3
                end

                local options = m_lastCalculationOptions or {}
                options.surges = surgesOverride

                if m_multitargets ~= nil and GetCurrentMultiTarget() <= #m_multitargets then
                    m_multitargets[GetCurrentMultiTarget()].surges = surgesOverride
                end

                CalculateRollText(options)
                RecalculateMultiTargets()
            end,
        }
    end

    surgesBar = gui.Panel{
        styles = {
            {
                flow = "horizontal",
            },

            {
                selectors = {"surges"},
                bgimage = "game-icons/surge.png",
            },
            {
                selectors = {"inactive"},
                bgcolor = "#666666",
                transitionTime = 0.2,
            },

        },
        width = 400,
        height = "auto",
        halign = "center",

		prepare = function(element, options)
			element:SetClass("collapsed", not string.find(options.type or "", "ability_power_roll"))
		end,

        gui.Panel{
            halign = "center",
            valign = "center",
            width = "auto",
            height = "auto",
            CreateSurgeIcon(1),
            CreateSurgeIcon(2),
            CreateSurgeIcon(3),
            CreateSurgeIcon(4),
            CreateSurgeIcon(5),
            CreateSurgeIcon(6),
            CreateSurgeIcon(7),
            CreateSurgeIcon(8),
            CreateSurgeIcon(9),
            CreateSurgeIcon(10),
            CreateSurgeIcon(11),
            CreateSurgeIcon(12),

            --a button to reset surge overrides. Only visible if we have overrides.
            gui.Panel{
                classes = {"icon"},
		        bgimage = "panels/hud/anticlockwise-rotation.png",
                floating = true,
                halign = "right",
                x = 20,
                width = 16,
                height = 16,
		        textCalculated = function(element, calculationOptions)
                    element:SetClass("hidden", calculationOptions == nil)
                end,
                press = function(element)

                    if m_multitargets ~= nil and GetCurrentMultiTarget() <= #m_multitargets then
                        m_multitargets[GetCurrentMultiTarget()].surges = 0
                    end

                    CalculateRollText()
                end,
            },
        },
    }

	local modifiersPanel = gui.Panel{
		classes = {'modifiers-panel'},
        width = 0, --take up no space so the multi-target panel can be centered.
		events = {

            -- Here we get a pass at deciding any modifications to which modifiers are available
            -- that will modify rollProperties (e.g. damage) after edges and banes have been calculated.
            --- @param element Panel
            --- @param rollInfo ChatMessageDiceRollInfoLua
            prepareBeforeRollProperties = function(element, rollInfo)
                local children = element.children
                for i,child in ipairs(children) do
                    local mod = child.data.mod
                    if mod ~= nil and mod.modifier ~= nil and mod.modifier:try_get("rollRequirement", "none") ~= "none" then
                        local passes = mod.modifier:CheckRollRequirement(rollInfo)
                        child:SetClass("collapsed", not passes)
                        mod.failsRequirement = not passes

                        --modify the failsRequirement in the modifier list.
                        if child.data.modifierIndex ~= nil and m_options.modifiers[child.data.modifierIndex] ~= nil then
                            m_options.modifiers[child.data.modifierIndex].failsRequirement = not passes
                        end
                    end
                end
            end,


			prepare = function(element, options)

				modifierChecks = {}
				modifierDropdowns = {}
				if creature == nil or options.modifiers == nil then
					element.children = {}
					element:SetClass('collapsed-anim', true)
					return
				end

				element:SetClass('collapsed-anim', false)

				local addedCritical = false

				local children = {}

				for modifierIndex,mod in ipairs(options.modifiers) do
					if mod.modifier then
                        mod.context = mod.context or {}
						local ischecked = false
						local force = mod.modifier:try_get("force", false)
                        if mod.override ~= nil then
                            ischecked = mod.override
						elseif force then
							ischecked = true
						elseif mod.hint ~= nil then
							ischecked = mod.hint.result
						end

						local check --gui.Check that will come out of this.

						local tooltip = mod.modifier:GetSummaryText()
						for i,justification in ipairs(mod.hint.justification) do
							tooltip = string.format("%s\n<color=%s>%s", tooltip, cond(ischecked, '#aaffaa', '#ffaaaa'), justification)
						end

						local text = mod.modifier.name
						if mod.modFromTarget then
							text = string.format("Target is %s", text)
						end

						--resource usage gets an availability description.
						local availability = mod.modifier:DescribeResourceAvailability(creature, mod.context.charges or 1)
						if availability then
							text = string.format("%s (%s)", text, availability)
						end

						local classes = nil

						if force then
							classes = {"collapsed-anim"}
						end

						check = gui.Check{
							classes = classes,
							text = text,
							value = ischecked,
							data = {
								mod = mod,
                                modifierIndex = modifierIndex,
							},
							events = {
								change = function(element)
                                    mod.override = element.value

                                    resultPanel:FireEventTree('prepare', m_options)
									CalculateRollText()
                                    RecalculateMultiTargets()
								end,
								linger = gui.Tooltip{
									text = tooltip,
									maxWidth = 600,
								},
							},
						}

						children[#children+1] = check
						modifierChecks[#modifierChecks+1] = check

                        if mod.modifier:try_get("resourceCostType", "none") == "multicost" and ischecked then
                            mod.context.charges = mod.context.charges or 1
                            local panel = gui.Panel{
                                flow = "horizontal",
                                width = 160,
                                height = 18,
                                gui.Label{
                                    text = "Charges:",
                                    fontSize = 16,
                                    width = 70,
                                    height = "auto",
                                    valign = "center",
                                },
                                gui.Input{
                                    text = mod.context.charges,
                                    characterLimit = 2,
                                    width = 24,
                                    height = 14,
                                    fontSize = 14,
                                    selectAllOnFocus = true,
                                    change = function(element)
                                        local num = tonumber(element.text)
                                        if num == nil then
                                            element.text = mod.context.charges
                                            return
                                        end

                                        mod.context.charges = num

                                        resultPanel:FireEventTree('prepare', m_options)
                                        CalculateRollText()
                                        RecalculateMultiTargets()
                                    end,
                                }
                            }

                            children[#children+1] = panel
                        end

					elseif mod.check then
						--this is a checkbox that is passed in that we will pass the results of straight out.

						local check = gui.Check{
							text = mod.text,
							value = mod.value,
							data = {
								mod = mod,
							},
							events = {
								change = function(element)
									element.data.mod.change(element.value)
								end,
								linger = function(element)
									if mod.tooltip ~= nil then
										gui.Tooltip{
											text = element.data.mod.tooltip,
											maxWidth = 600,
										}(element)
									end
								end,
							},
						}

						children[#children+1] = check
					elseif mod.modifierOptions then
						local dropdown = gui.Dropdown{
							width = 300,
							height = 26,
							valign = "center",
							fontSize = 18,
							idChosen = mod.hint.result,
							options = mod.modifierOptions,
							data = {
								mod = mod,
							},
							change = function(element)
								CalculateRollText()
							end,
						}

						local panel = gui.Panel{
							flow = "horizontal",
							height = 36,
							width = "80%",
							gui.Label{
								text = mod.text .. ":",
								classes = "explanation",
								halign = "left",
								valign = "center",
								width = 120,
							},
							linger = gui.Tooltip{
								text = mod.tooltip,
								maxWidth = 600,
							},
							dropdown,
						}

						modifierDropdowns[#modifierDropdowns+1] = dropdown
						children[#children+1] = panel
					end
				end

				element.children = children
			end
		},
	}

	local CancelRollDialog = function()
		RemoveTargetHints()
		if cancelRoll ~= nil then
			if not rollAllPromptsCheck:HasClass("collapsed-anim") and rollAllPromptsCheck.value and rollAllPrompts ~= nil then
				rollAllPrompts()
			end
			cancelRoll()
		end
		resultPanel:SetClass('hidden', true)
		chat.PreviewChat('')
		OnHide()
        RelinquishPanel()
	end

    rollAgainButton = gui.PrettyButton{
        text = "Re-roll",
        floating = true,
        classes = {"shownWhenRollingOrFinished"},
		style = {
			width = 200,
			height = 50,
			halign = 'left',
		},

        press = function(element)
            if g_activeRoll == nil then
                return
            end

            local guid = dmhub.GenerateGuid()

            g_activeRoll = g_activeRoll:Amend{
                guid = guid,
				roll = g_activeRollArgs.roll,
                amendmentRerolls = true,
				description = g_activeRollArgs.description .. " -- Re-rolled!",
				amendable = g_activeRollArgs.amendable,
				tokenid = g_activeRollArgs.tokenid,
				silent = g_activeRollArgs.rollIsSilent,
				instant = g_activeRollArgs.instant,
				creature = g_activeRollArgs.creature,
                properties = g_activeRollArgs.properties,
				begin = function(rollInfo)
                    resultPanel:FireEventTree("beginRoll", rollInfo, guid)
                end,
            }
        end,
    }

    proceedAfterRollButton = gui.PrettyButton{
        text = "Accept Result",
        classes = {"shownWhenRollingOrFinished"},
		style = {
			width = 200,
			height = 50,
			halign = 'right',
		},

        events = {},

    }

	rollDiceButton = gui.PrettyButton{
		text = 'Roll Dice',
        classes = {"hiddenWhenRolling"},
		style = {
			width = 200,
			height = 50,
			halign = 'right',
		},
		events = {
			press = function(element)
				resultPanel:FireEvent('submit')
			end,
			enter = function(element)
				element:FireEvent("press")
			end,
		}
	}

	cancelButton = gui.PrettyButton{
		text = 'Cancel',
        classes = {"hiddenWhenRolling"},
		escapeActivates = true,
		escapePriority = EscapePriority.EXIT_ROLL_DIALOG,
		style = {
			width = 200,
			height = 50,
			halign = 'right',
		},
		events = {
			press = function(element)
				CancelRollDialog()
			end,
		}
	}

	rollDisabledLabel = gui.Label{
		classes = {'explanation', "collapsed-anim"},
		color = "#ffaaaaff",
		valign = "bottom",
	}

	local buttonPanel = gui.Panel{
		classes = {'buttonPanel'},
		children = {
			rollDiceButton,
			cancelButton,
            proceedAfterRollButton,
            rollAgainButton,
		},
	}

	local mainPanel = gui.Panel{
		classes = {'main-panel'},
		children = {
			title,
			gui.Divider{ width = "50%" },
			explanation,
			alternateRollsBar,
            gui.Panel{
                width = "100%",
                height = "auto",
                flow = "horizontal",
			    modifiersPanel,

                gui.Panel{
                    width = 430,
                    height = 100,
                    vscroll = true,
                    halign = "center",
                    valign = "bottom",
                    vmargin = 12,

			        multitokenContainer,
                }
            },
			boonBar,
            surgesBar,
			m_tableContainer,
			m_customContainer,
			rollInputContainer,
			autoRollPanel,
			prerollCheck,
			hideRollDropdown,
			updateRollVisibility,
			rollAllPromptsCheck,
			rollDisabledLabel,
			buttonPanel,
		}
	}

    RecalculateMultiTargets = function()
        if m_multitargets == nil or rollProperties == nil then
            return
        end

        local index = nil
        for i,target in ipairs(m_multitargets) do
            if target.token.properties == targetCreature then
                index = i
                break
            end
        end

        if index == nil then
            return
        end

        for i=1,#m_multitargets do
            index = index+1
            if index > #m_multitargets then
                index = 1
            end

            targetCreature = m_multitargets[index].token.properties
            m_options.targetCreature = targetCreature
            m_options.modifiers = m_multitargets[index].modifiers
            resultPanel:FireEventTree('prepare', m_options)
            local roll = CalculateRollText{
                surges = m_multitargets[index].surges or 0,
            }

	        local rollInfo = dmhub.ParseRoll(roll, m_multitargets[index].token.properties)

            m_multitargets[index].modifiersUsed = DeepCopy(m_activeModifiers)
            m_multitargets[index].rollProperties = DeepCopy(rollProperties)
            m_multitargets[index].rollProperties.multitargets = nil
            m_multitargets[index].boons = (rollInfo.boons or 0) - (rollInfo.banes or 0)
        end

        local normalizedBoons = m_multitargets[index].boons
        for i=1,#m_multitargets do
            m_multitargets[i].boons = m_multitargets[i].boons - normalizedBoons
            rollProperties.multitargets[i].boons = m_multitargets[i].boons
        end

        resultPanel:FireEventTree("recalculatedMultiTargets", m_multitargets)
        for i=1,#m_multitargets do
            print("TARGET:: RECALC", i, "SURGES = ", m_multitargets[i].surges or 0, "tiers = ", m_multitargets[i].rollProperties.tiers)
        end
    end

	local delayRoll = 0
	local rollIsSilent = false

    local showDialogDuringRoll = false

	resultPanel = gui.Panel{
		classes = {'framedPanel', 'hidden'},
        opacity = 0.99,

		styles = styles,

		children = {
            gui.CloseButton{
                halign = "right",
                valign = "top",
                escapeActivates = true,
                escapePriority = EscapePriority.EXIT_ROLL_DIALOG,
                press = function(element)
					cancelButton:FireEventTree("press")
                end,
            },
			mainPanel,
		},

		data = {

			rollid = nil,

			coroutineOwner = nil,

			ShowDialog = function(options)

				if not resultPanel.valid then
					return
				end

				if coroutine.GetCurrentId() ~= nil then
					if resultPanel.data.coroutineOwner == nil then
						resultPanel.data.coroutineOwner = coroutine.GetCurrentId()
					else
						while resultPanel.valid and resultPanel.data.coroutineOwner ~= coroutine.GetCurrentId() and coroutine.IsCoroutineWithIdStillRunning(resultPanel.data.coroutineOwner) do
							coroutine.yield(0.01)
						end

                        if resultPanel.valid then
						    resultPanel.data.coroutineOwner = coroutine.GetCurrentId()
                        end
					end
				end

				if options.delay ~= nil then

					local a,b = coroutine.running()

					if dmhub.inCoroutine then
						local t = dmhub.Time()
						while dmhub.Time() < t + delay do
							coroutine.yield(0.02)
						end
					else

						local delay = options.delay

						local optionsCopy = {}
						for k,v in pairs(options) do
							optionsCopy[k] = v
						end
						
						optionsCopy.rollid = dmhub.GenerateGuid()
						optionsCopy.delay = nil

						dmhub.Schedule(delay, function()
							if resultPanel.valid then
								resultPanel.data.ShowDialog(optionsCopy)
							end
						end)


						return optionsCopy.rollid
					end
				end

				if dmhub.inCoroutine then
					while not resultPanel:HasClass("hidden") do
						coroutine.yield(0.02)

						if not resultPanel.valid then
							return
						end
					end
				elseif not resultPanel:HasClass("hidden") then
					local rollid = dmhub.GenerateGuid()
					--not in a coroutine so just reschedule this.
					dmhub.Schedule(1.0, function()
						if resultPanel.valid then
							local optionsCopy = {}
							for k,v in pairs(options) do
								optionsCopy[k] = v
							end
							
							optionsCopy.rollid = rollid

							resultPanel.data.ShowDialog(optionsCopy)
						end
					end)

					return rollid
				end

				if options.skipDeterministic and dmhub.IsRollDeterministic(options.roll) then
					--this is a quick, happy path that we try to take if the roll is deterministic and we don't need to show the dialog.
					--This is used to avoid the significant performance cost of creating the UI elements.

					local activeModifiers = false
					for _,mod in ipairs(options.modifiers or {}) do
						if mod.modifier then

							local ischecked = false
							local force = mod.modifier:try_get("force", false)
							if force then
								ischecked = true
							elseif mod.hint ~= nil then
								ischecked = mod.hint.result
							end

							if ischecked then
								activeModifiers = true
								break
							end
						end
					end

					if not activeModifiers then

						local guid = dmhub.GenerateGuid()

						local tokenid = nil
						if options.creature ~= nil then
							tokenid = dmhub.LookupTokenId(creature)
						end

						dmhub.Roll{
							guid = guid,
							description = options.description,
							tokenid = tokenid,
							silent = true,
							instant = true,
							roll = options.roll,
							creature = options.creature,
							properties = options.rollProperties,
							complete = function(rollInfo)
								if options.completeRoll ~= nil then
									options.completeRoll(rollInfo)
								end
							end
						}

						return guid
					end
				end

				if options.tableRef ~= nil then
					--delegate table rolls to the specialized dialog for them.
					return resultPanel.data.rollOnTableDialog.data.ShowDialog(options)
				end

                showDialogDuringRoll = options.showDialogDuringRoll

                --ensure these buttons are shown when showing the dialog.
                resultPanel:SetClassTree("rolling", false)
                resultPanel:SetClassTree("finishedRolling", false)

				if options.PopulateTable ~= nil then
					m_tableContainer:SetClass("collapsed", false)
					options.PopulateTable(m_tableContainer)
				else
					m_tableContainer:SetClass("collapsed", true)
				end

				if options.PopulateCustom ~= nil then
					m_customContainer:SetClass("collapsed", false)
					options.PopulateCustom(m_customContainer, options.creature)
				else
					m_customContainer:SetClass("collapsed", true)
				end

				rollDiceButton.hasFocus = true

				m_symbols = options.symbols

				resultPanel.data.rollid = options.rollid or dmhub.GenerateGuid()
				rollIsSilent = false
				delayRoll = 0

                local richStatus = "Rolling dice"
                if options.type == "ability_power_roll" then
                    if options.ability ~= nil then
                        richStatus = string.format("Rolling power for %s", options.ability.name)
                    else
                        richStatus = "Rolling power"
                    end
                elseif options.title then
                    richStatus = string.format("Rolling %s", options.title)
                end

				if resultPanel:HasClass('hidden') then
					resultPanel:SetClass('hidden', false)
					OnShow(richStatus)
				end

				if not options.nofadein then
					resultPanel:PulseClass("fadein")
				end

				m_options = options

				targetHints = options.targetHints

				rollType = options.type
				rollSubtype = options.subtype
				rollProperties = options.rollProperties

				creature = options.creature
				targetCreature = options.targetCreature
				m_multitargets = options.multitargets

				title.text = options.title or 'Roll Dice'
				explanation.text = options.explanation or ''
				if rollInput.text == options.roll then
					--force the edit event if we already have this set.
					rollInput:FireEvent('edit')
				end

				rollAllPrompts = options.rollAllPrompts
				rollActive = options.rollActive
				beginRoll = options.beginRoll
				completeRoll = options.completeRoll
				cancelRoll = options.cancelRoll

				resultPanel:FireEventTree('prepare', options)

				baseRoll = options.roll
				CalculateRollText()

                RecalculateMultiTargets()

				if options.numPrompts ~= nil and options.numPrompts > 1 then
					rollAllPromptsCheck.value = true
					rollAllPromptsCheck.data.SetText(string.format("Roll all %d prompts", options.numPrompts))
					rollAllPromptsCheck:SetClass("collapsed-anim", false)
				else
					rollAllPromptsCheck.value = false
					rollAllPromptsCheck:SetClass("collapsed-anim", true)
				end

				if options.skipDeterministic and dmhub.IsRollDeterministic(rollInput.text) and dmhub.IsRollDeterministic(options.roll) then
					rollIsSilent = true
					if options.delayInstant ~= nil then
						delayRoll = options.delayInstant
					end
					rollDiceButton:FireEventTree("press")
				elseif options.autoroll == true or dmhub.GetSettingValue("autorollall") or (options.creature ~= nil and options.creature._tmp_aicontrol > 0) then
					if options.delayInstant ~= nil then
						delayRoll = options.delayInstant or 0.05
					else
						--TODO: Work out why instant rolls have a problem if we don't include a small delay.
						delayRoll = 0.05
					end
					rollDiceButton:FireEventTree("press")
				elseif options.autoroll == "cancel" then
					cancelButton:FireEventTree("press")
				elseif options.autoroll ~= nil then

					local autoroll = dmhub.GetSettingValue(string.format("%s:autoroll", options.autoroll.id))
					local hideFromPlayers = dmhub.GetSettingValue(string.format("%s:hideFromPlayers", options.autoroll.id))
					local quickRoll = dmhub.GetSettingValue(string.format("%s:quickRoll", options.autoroll.id))

					autoRollPanel:SetClass("collapsed-anim", false)
					autoRollCheck.value = autoroll or false
					autoRollCheck.data.SetText(string.format("Auto-roll %s in future", options.autoroll.text))
					autoHideCheck.data.SetText(string.format("Hide %s from players", options.autoroll.text))
					autoQuickCheck.data.SetText(string.format("Skip rolling animation for %s", options.autoroll.text))
					autoRollId = options.autoroll.id

					autoHideCheck.value = hideFromPlayers or false
					autoQuickCheck.value = quickRoll or false


					if autoroll then
						rollDiceButton:FireEventTree("press")
					end
				else
					autoRollPanel:SetClass("collapsed-anim", true)
					autoRollId = nil
				end

				return resultPanel.data.rollid
			end,

			IsShown = function()
				return not resultPanel:HasClass('hidden')
			end,

			Cancel = function()
				CancelRollDialog()
			end,
		},

		events = {
			submit = function(element)

                RecalculateMultiTargets()

				RemoveTargetHints()

                local showingDialog = showDialogDuringRoll

                local completeFunction

                if showingDialog then
                    resultPanel:SetClassTree("rolling", true)
                    resultPanel:SetClassTree("finishedRolling", false)
                    g_holdingRollOpen = true

                    proceedAfterRollButton.events.press = function()
                        resultPanel:SetClass('hidden', true)
                        RelinquishPanel()
                        showingDialog = false
                    end
                else
                    resultPanel:SetClass('hidden', true)
                    RelinquishPanel()
                end

                OnHide()

				local dmonly = false
				local instant = false

				if autoRollId ~= nil then
					
					dmonly = autoHideCheck.value
					instant = autoQuickCheck.value

					dmhub.SetSettingValue(string.format("%s:autoroll", autoRollId), autoRollCheck.value)
					dmhub.SetSettingValue(string.format("%s:hideFromPlayers", autoRollId), autoHideCheck.value)
					dmhub.SetSettingValue(string.format("%s:quickRoll", autoRollId), autoQuickCheck.value)

				end

				if hideRollDropdown.idChosen == "dm" then
					dmonly = true
				end

				if hideRollDropdown.idChosen ~= dmhub.GetSettingValue("privaterolls") and updateRollVisibility.value then
					--update the setting for private rolls from now on.
					dmhub.SetSettingValue("privaterolls", hideRollDropdown.idChosen)
				end

				dmhub.SetSettingValue("privaterolls:save", updateRollVisibility.value)

				if rollAllPrompts ~= nil and rollAllPromptsCheck.value then
					rollAllPrompts()
				end

				--we must save off anything from the surrounding scope since this dialog might be reused after this.
				local activeRollFn = rollActive
				local beginRollFn = beginRoll
				local completeRollFn = completeRoll
				local creatureUsed = creature
				local modifiersUsed = dmhub.DeepCopy(m_activeModifiers)
                local multitargetsUsed = m_multitargets

				local tokenid = nil
				
				if creature ~= nil then
					tokenid = dmhub.LookupTokenId(creature)
				end

				rollProperties = rollProperties or RollProperties.new{}

                completeFunction = function(rollInfo)
					local resourceConsumed = false

                    local surgesUsed = 0

                    local surgesNote = nil

                    if multitargetsUsed ~= nil then
                        for i,target in ipairs(multitargetsUsed) do
                            if target.surges ~= nil and target.surges > 0 then
                                surgesUsed = surgesUsed + target.surges
                                if surgesNote == nil then
                                    surgesNote = string.format("Used %d %s attacking %s", target.surges, cond(target.surges > 1, "surges", "surge"), target.token.name)
                                else
                                    surgesNote = string.format("%s, %d %s attacking %s", surgesNote, target.surges, cond(target.surges > 1, "surges", "surge"), target.token.name)
                                end
                            end

                            for i,modifier in ipairs(target.modifiersUsed or {}) do
                                local consume = modifier:ConsumeResource(creatureUsed)
                                resourceConsumed = consume or resourceConsumed
                            end
                        end
                    else
                        for i,modifier in ipairs(modifiersUsed) do
                            local consume = modifier:ConsumeResource(creatureUsed)
                            resourceConsumed = consume or resourceConsumed
                        end
                    end


                    if surgesUsed > 0 then
                        resourceConsumed = true
                        creatureUsed:ConsumeSurges(surgesUsed, surgesNote)
                    end

					local ongoingEffects = {}
					for i,modifier in ipairs(modifiersUsed) do
						local newOngoingEffects = modifier:ApplyOngoingEffectsToSelfOnRoll(creature)
						if newOngoingEffects ~= nil then
							for j,c in ipairs(newOngoingEffects) do
								ongoingEffects[#ongoingEffects+1] = c
							end
						end
					end

					if resourceConsumed or #ongoingEffects > 0 then
						local creatureToken = dmhub.LookupToken(creatureUsed)
						if creatureToken ~= nil then
							for i,cond in ipairs(ongoingEffects) do
								creatureUsed:ApplyOngoingEffect(cond.ongoingEffect, cond.duration, nil, {
									untilEndOfTurn = cond.durationUntilEndOfTurn,
								})
							end
							creatureToken:Upload('Used resource')
						end
					end

					if completeRollFn ~= nil then
						completeRollFn(rollInfo)
					end
                end

                local activeRoll
                local rollArgs = {
					guid = resultPanel.data.rollid,
					description = m_options.description,
					amendable = m_options.amendable,
					tokenid = tokenid,
					silent = rollIsSilent,
					delay = delayRoll,
					dmonly = dmonly,
					instant = instant,
					roll = rollInput.text,
					creature = creature,
					properties = rollProperties,
					begin = function(rollInfo)
						if beginRollFn ~= nil then
							beginRollFn(rollInfo)
						end

                        resultPanel:FireEventTree("beginRoll", rollInfo, resultPanel.data.rollid)
					end,
					complete = function(rollInfo)

                        if showingDialog then
                            resultPanel:SetClassTree("rolling", false)
                            resultPanel:SetClassTree("finishedRolling", true)

                            proceedAfterRollButton.events.press = function()
                                resultPanel:SetClass('hidden', true)
                                RelinquishPanel()

                                completeFunction(rollInfo)
                            end

                            return
                        end

                        completeFunction(rollInfo)

                        if g_activeRoll == activeRoll then
                            g_activeRoll = nil
                        end
					end
                }

                g_activeRollArgs = rollArgs
				activeRoll = dmhub.Roll(rollArgs)

                g_activeRoll = activeRoll
                
				if activeRollFn ~= nil then
					activeRollFn(activeRoll)
				end

				chat.PreviewChat('')
			end,
		},
	}

	return resultPanel
end
