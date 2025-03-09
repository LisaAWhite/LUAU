local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityReplenishBehavior", "ActivatedAbilityBehavior")

ActivatedAbility.RegisterType
{
	id = 'replenish_resources',
	text = 'Replenish Resources',
	createBehavior = function()
        local options = CharacterResource.GetDropdownOptions()
		return ActivatedAbilityReplenishBehavior.new{
            resourceid = options[1].id,
		}
	end
}

ActivatedAbilityReplenishBehavior.summary = 'Replenish Resources'
ActivatedAbilityReplenishBehavior.mode = 'replenish'
ActivatedAbilityReplenishBehavior.quantity = '1'
ActivatedAbilityReplenishBehavior.allowSubstitution = false
ActivatedAbilityReplenishBehavior.chooseResourceFromList = false

function ActivatedAbilityReplenishBehavior:Cast(ability, casterToken, targets, options)
    printf("TRIGGER:: Replenish: %d", #targets)
    if #targets == 0 then
        return
    end

	local resourceTable = dmhub.GetTable("characterResources") or {}

    local resourceName = "Resource"

    if self.chooseResourceFromList then
        local resourceNames = {}
        for _,resourceid in ipairs(self:try_get("resourceOptions", {})) do
            local resourceInfo = resourceTable[self.resourceid]
            if resourceInfo ~= nil then
                resourceNames[#resourceNames+1] = resourceInfo.name
            end
        end

        resourceName = table.concat(resourceNames, ", ")
    else
        local resourceInfo = resourceTable[self.resourceid]
        if resourceInfo ~= nil then
            resourceName = resourceInfo.name
        end
    end

    local quantity = nil
    local rollComplete = false

    local roll = dmhub.EvalGoblinScript(self.quantity, casterToken.properties:LookupSymbol(options.symbols), string.format("Resource roll for %s", ability.name))

    local rollResults = {}

    if tonumber(roll) ~= nil then
        rollComplete = true

        for _,target in ipairs(targets) do
            rollResults[target.token.charid] = { result = tonumber(roll) }
        end
        quantity = tonumber(roll)
    else
        local dcaction = ability:RequireSavingThrowsCo(self, casterToken, ActivatedAbility.GetTokenIds(targets), {
            rollType = "custom",
            id = "",
            text = ability.name,
            explanation = "Roll for " .. resourceName,
            roll = roll,
            targets = targets,
        })

        if dcaction == nil then
            return
        end

        rollResults = dcaction.info.tokens
    end

    for _,target in ipairs(targets) do
        if target.token ~= nil and rollResults[target.token.charid] ~= nil then
            local quantity = rollResults[target.token.charid].result

            local resourceidToQuantity = {}

            if quantity <= 0 then
                --pass

            elseif self.chooseResourceFromList then

                local finished = false
                local canceled = false

                local m_pinnedResource = nil

                local RecalculateResources = function()
                    if #self:try_get("resourceOptions", {}) == 0 or (m_pinnedResource ~= nil and self.resourceOptions == 1) then
                        return
                    end

                    local assigned = 0
                    for i,resourceid in ipairs(self.resourceOptions) do
                        resourceidToQuantity[resourceid] = resourceidToQuantity[resourceid] or 0
                        assigned = assigned + resourceidToQuantity[resourceid]
                    end


                    while assigned > quantity do
                        local startingAssigned = assigned
                        for i,resourceid in ipairs(self.resourceOptions) do
                            if assigned > quantity and m_pinnedResource ~= i and resourceidToQuantity[resourceid] > 0 then
                                resourceidToQuantity[resourceid] = resourceidToQuantity[resourceid] - 1
                                assigned = assigned - 1
                            end
                        end
                        if startingAssigned == assigned then
                            break
                        end
                    end

                    while assigned < quantity do
                        local startingAssigned = assigned
                        for i,resourceid in ipairs(self.resourceOptions) do
                            if assigned < quantity and m_pinnedResource ~= i then
                                resourceidToQuantity[resourceid] = resourceidToQuantity[resourceid] + 1
                                assigned = assigned + 1
                            end
                        end
                        if startingAssigned == assigned then
                            break
                        end
                    end
                end


                local dialogPanel

                local items = {}

                for i,resourceid in ipairs(self:try_get("resourceOptions", {})) do
                    local resourceInfo = resourceTable[resourceid]

                    local iconid = resourceInfo.iconid
                    if resourceInfo.hasLargeDisplay then
                        iconid = resourceInfo.largeIconid
                    end

                    items[#items+1] = gui.Label{
                        fontSize = 24,
                        width = "auto",
                        height = "auto",
                        text = resourceInfo.name,
                        bmargin = -16,
                    }

                    items[#items+1] = gui.Panel{
                        flow = "horizontal",
                        halign = "center",
                        valign = "center",
                        width = "auto",
                        height = 160,

                        gui.PagingArrow{
                            facing = -1,
                            height = "30%",
                            refreshResources = function(element)
                                element:SetClass("hidden", resourceidToQuantity[resourceid] <= 0)
                            end,
                            click = function(element)
                                resourceidToQuantity[resourceid] = resourceidToQuantity[resourceid] - 1
                                m_pinnedResource = i
                                dialogPanel:FireEventTree("refreshResources")
                            end,
                        },

                        gui.Panel{
                            bgimage = iconid,
                            bgimageMask = mod.images.resourceMask,
                            bgcolor = "white",
                            width = 160,
                            height = 160,
                            hmargin = 10,
                            cornerRadius = 80,

                            gui.Panel{
                                bgimage = "panels/square.png",
                                width = 130,
                                height = 130,
                                cornerRadius = 65,
                                borderWidth = 2,
                                borderColor = Styles.textColor,
                            },

                            gui.Label{
                                refreshResources = function(element)
                                    element.text = string.format("%d", resourceidToQuantity[resourceid])
                                end,
                                change = function(element)
                                    local n = tonumber(element.text)
                                    if n ~= nil and round(n) == n and n >= 0 and n <= quantity then
                                        resourceidToQuantity[resourceid] = n
                                        m_pinnedResource = i
                                        dialogPanel:FireEventTree("refreshResources")
                                    else
                                        element.text = tostring(resourceidToQuantity[resourceid])
                                    end
                                end,
                                textAlignment = "center",
                                editable = true,
                                halign = "center",
                                valign = "center",
                                width = "auto",
                                height = "auto",
                                hpad = 16,
                                vpad = 16,
                                fontSize = 48,
                                bold = true,
                            }
                        },

                        gui.PagingArrow{
                            facing = 1,
                            height = "30%",
                            refreshResources = function(element)
                                element:SetClass("hidden", resourceidToQuantity[resourceid] >= quantity)
                            end,
                            click = function(element)
                                resourceidToQuantity[resourceid] = resourceidToQuantity[resourceid] + 1
                                m_pinnedResource = i
                                dialogPanel:FireEventTree("refreshResources")
                            end,
                        },
                    }
                end

                dialogPanel = gui.Panel{
                    height = "auto",
                    width = 600,
                    classes = {"framedPanel"},
                    styles = {
                        Styles.Panel,
                        Styles.Default,
                    },

                    refreshResources = function(element)
                        RecalculateResources()
                    end,

                    gui.CloseButton{
                        floating = true,
                        halign = "right",
                        valign = "top",
                        click = function(element)
                            finished = true
                            canceled = true
                        end,
                    },

                    gui.Panel{
                        flow = "vertical",
                        width = "80%",
                        height = "auto",
                        maxHeight = 800,
                        vscroll = true,

                        gui.Label{
                            classes = {"dialogTitle"},
                            text = "Choose Resources",
                        },

                        gui.Divider{
                        },

                        gui.Panel{
                            flow = "vertical",
                            width = "auto",
                            height = "auto",
                            children = items,
                        },

                        gui.Panel{
                            flow = "horizontal",
                            width = "auto",
                            height = "auto",

                            gui.Label{
                                fontSize = 32,
                                width = "auto",
                                height = "auto",
                                halign = "left",
                                text = "Total:",
                            },

                            gui.Label{
                                fontSize = 32,
                                width = 80,
                                height = "auto",
                                textAlignment = "right",
                                characterLimit = 2,
                                halign = "right",
                                text = string.format("%d", quantity),
                                editable = true,
                                change = function(element)
                                    local n = tonumber(element.text)
                                    if n ~= nil and n == round(n) then
                                        quantity = n
                                        m_pinnedResource = nil
                                        dialogPanel:FireEventTree("refreshResources")
                                    else
                                        element.text = tostring(quantity)
                                    end
                                end,
                            },

                        },

                        gui.Divider{
                        },

                        gui.PrettyButton{
                            text = "Confirm",
                            click = function()
                                finished = true
                            end,
                        },
                    },
                }

                dialogPanel:FireEventTree("refreshResources")

                gui.ShowModal(dialogPanel)

--            gamehud:ModalDialog{
--                title = string.format("%s: Choose Resources", ability.name),
--                buttons = {
--                    {
--                        text = "Confirm",
--                        click = function()
--                            finished = true
--                        end,
--                    },
--                    {
--                        text = "Cancel",
--                        click = function()
--                            finished = true
--                            canceled = true
--                        end,
--                    },
--                },

--                width = 810,
--                height = 768,

--                flow = "vertical",

--                gui.Panel{
--                    flow = "vertical",
--                    vscroll = true,
--                    width = 600,
--                    height = 500,
--                    halign = "center",
--                    valign = "center",

--                    create = function(element)
--                        local children = {}

--                        children[#children+1] = gui.Panel{
--                            flow = "horizontal",
--                            valign = "top",
--                            width = 600,
--                            height = 30,

--                            gui.Label{
--                                text = "Total:",
--                                width = 300,
--                                height = 50,
--                                classes = "formLabel",
--                            },

--                            gui.Label{
--                                text = tostring(quantity),
--                                width = 300,
--                                height = 50,
--                                classes = "formLabel",
--                            },
--                        }

--                        children[#children+1] = gui.Panel{
--                            valign = "top",
--                            width = 600,
--                            height = 50,
--                        }

--                        local lastTouchedIndex = nil

--                        local resourceOptions = self:try_get("resourceOptions", {})

--                        for i,resourceid in ipairs(resourceOptions) do
--                            local resourceInfo = resourceTable[resourceid]
--                            children[#children+1] = gui.Panel{
--                                valign = "top",
--                                flow = "horizontal",
--                                width = 600,
--                                height = 30,

--                                gui.Label{
--                                    text = string.format("%s:", resourceInfo.name),
--                                    width = 300,
--                                    classes = "formLabel",
--                                },

--                                gui.Label{
--                                    text = tostring(resourceidToQuantity[resourceid]),
--                                    width = 300,
--                                    classes = "formLabel",
--                                    editable = true,
--                                    characterLimit = 3,
--                                    refresh = function(element)
--                                        element.text = tostring(resourceidToQuantity[resourceid])
--                                    end,
--                                    change = function(element)
--                                        local n = tonumber(element.text)
--                                        if n ~= nil and n == round(n) and n >= 0 and n <= quantity and #resourceOptions > 1 then

--                                            --find out how much we are changing this resource by.
--                                            --we iterate over the other resources and try to take from them.
--                                            --we prefer not to take from the most recently touched resource, leaving it to the end.
--                                            local delta = round(n) - resourceidToQuantity[resourceid]

--                                            for j,targetid in ipairs(resourceOptions) do
--                                                if j ~= i and j ~= lastTouchedIndex and delta ~= 0 then
--                                                    if delta > 0 then
--                                                        local change = math.min(delta, resourceidToQuantity[targetid])
--                                                        resourceidToQuantity[targetid] = resourceidToQuantity[targetid] - change
--                                                        delta = delta - change
--                                                    else
--                                                        resourceidToQuantity[targetid] = resourceidToQuantity[targetid] - delta
--                                                        delta = 0
--                                                    end
--                                                end
--                                            end

--                                            if lastTouchedIndex ~= nil then
--                                                resourceidToQuantity[resourceOptions[lastTouchedIndex]] = resourceidToQuantity[resourceOptions[lastTouchedIndex]] - delta
--                                            end

--                                            lastTouchedIndex = i

--                                            resourceidToQuantity[resourceid] = round(n)
--                                        end

--                                        element.parent.parent:FireEventTree("refresh")
--                                    end,
--                                },

--                            }
--                        end

--                        element.children = children
--                    end,
--                }

--            }

                while not finished do
                    coroutine.yield(0.1)
                end

                gui.CloseModal()

                if canceled then
                    resourceidToQuantity = {}
                end

            else
                resourceidToQuantity[self.resourceid] = quantity
            end

            local hasSomeResources = false
            for _,quantity in pairs(resourceidToQuantity) do
                if quantity > 0 then
                    hasSomeResources = true
                    break
                end
            end

            if hasSomeResources then
                options.pay = true
                target.token:ModifyProperties{
                    description = cond(self.mode == "replenish", "Replenish Resource", "Consume Resource"),
                    execute = function()
                        for resourceid,quantity in pairs(resourceidToQuantity) do
                            local resourceInfo = resourceTable[resourceid]
                            if self.mode == "replenish" then
                                if self.allowSubstitution then
                                    --try to substitute for a lower level resource if applicable.
                                    local resourcesAvailable = target.token.properties:GetResources()
                                    local ncount = 0
                                    while ncount < 100 and self.allowSubstitution == true and (target.token.properties:GetResourceUsage(resourceid, resourceInfo.usageLimit) == 0 or (resourcesAvailable[resourceid] or 0) <= 0) and resourceTable[resourceInfo.levelsFrom] ~= nil do
                                        resourceid = resourceInfo.levelsFrom
                                        resourceInfo = resourceTable[resourceid]
                                        ncount = ncount+1
                                    end
                                end

                                target.token.properties:RefreshResource(resourceid, resourceInfo.usageLimit, quantity, ability.name)

                            else
                                target.token.properties:ConsumeResource(resourceid, resourceInfo.usageLimit, quantity, ability.name)
                            end
                        end
                    end,
                }
            end

        end
    end



end


function ActivatedAbilityReplenishBehavior:EditorItems(parentPanel)
	local result = {}

	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

    local options = CharacterResource.GetDropdownOptions()

    result[#result+1] = gui.Check{
        text = "Choose Resource from List",
        value = self.chooseResourceFromList,
        change = function(element)
            self.chooseResourceFromList = element.value
            parentPanel:FireEvent("refreshBehavior")
        end,
    }

    if self.chooseResourceFromList then
        local resourceTable = dmhub.GetTable("characterResources") or {}
        for index,resourceid in ipairs(self:try_get("resourceOptions", {})) do
            local resourceInfo = resourceTable[resourceid]
            if resourceInfo ~= nil then
                result[#result+1] = gui.Panel{
                    classes = "formPanel",
                    gui.Label{
                        classes = "formLabel",
                        text = resourceInfo.name,
                    },

                    gui.DeleteItemButton{
                        width = 12,
                        height = 12,
                        click = function(element)
                            local options = self:try_get("resourceOptions", {})
                            table.remove(options, index)
                            parentPanel:FireEvent("refreshBehavior")
                        end,
                    },
                }
            end
        end

        result[#result+1] = gui.Panel{
            classes = "formPanel",
            gui.Label{
                classes = "formLabel",
                text = "Add Resource:",
            },

            gui.Dropdown{
                idChosen = self.resourceid,
                options = options,
                textOverride = "Choose...",
                change = function(element)
                    self.resourceid = element.idChosen
                    local options = self:get_or_add("resourceOptions", {})
                    options[#options+1] = element.idChosen
                    parentPanel:FireEvent("refreshBehavior")
                end,
            },
        }
    else
        result[#result+1] = gui.Panel{
            classes = "formPanel",
            gui.Label{
                classes = "formLabel",
                text = "Resource:",
            },

            gui.Dropdown{
                idChosen = self.resourceid,
                options = options,
                change = function(element)
                    self.resourceid = element.idChosen
                    parentPanel:FireEvent("refreshBehavior")
                end,

            },
        }
    end

    result[#result+1] = gui.Check{
        text = "Substitute lower level resources",
        value = self.allowSubstitution,
        create = function(element)
            local resourceTable = dmhub.GetTable("characterResources") or {}
            local resourceInfo = resourceTable[self.resourceid]
            if self.mode ~= "replenish" or resourceInfo == nil or resourceTable[resourceInfo.levelsFrom] == nil then
                element:SetClass("collapsed", true)
            else
                element:SetClass("collapsed", false)
            end
        end,
        change = function(element)
            self.allowSubstitution = element.value
            parentPanel:FireEvent("refreshBehavior")
        end,
    }

    result[#result+1] = gui.Panel{
        classes = "formPanel",
        gui.Label{
            classes = "formLabel",
            text = "Mode:",
        },

        gui.Dropdown{
            idChosen = self.mode,
            options = {
                {
                    id = "replenish",
                    text = "Replenish Resources"
                },
                {
                    id = "expend",
                    text = "Expend Resources"
                },
            },
            change = function(element)
                self.mode = element.idChosen
                parentPanel:FireEvent("refreshBehavior")
            end,

        },
    }



    result[#result+1] = gui.Panel{
        classes = "formPanel",
        gui.Label{
            classes = "formLabel",
            text = "Quantity:",
        },

        gui.GoblinScriptInput{
            value = self.quantity,
            events = {
                change = function(element)
                    self.quantity = element.value
                end,
            },


			documentation = {
				help = string.format("This GoblinScript determines the number of resources to replenish."),
				output = "roll",
				examples = {
					{
						script = "1",
						text = "1 resource is replenished.",
					},
					{
						script = "-1",
						text = "1 resource is expended",
					},
					{
						script = "2d6",
						text = "2d6 resources are replenished.",
					},
				},
				subject = creature.helpSymbols,
				subjectDescription = "The creature that is casting the spell",
				symbols = ActivatedAbility.helpCasting,
			},
        },

    }


    return result
end