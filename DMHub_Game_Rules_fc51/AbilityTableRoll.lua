local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityTableRollBehavior", "ActivatedAbilityBehavior")


ActivatedAbilityTableRollBehavior.summary = 'Roll on Table'

ActivatedAbilityTableRollBehavior.tableType = "custom"
ActivatedAbilityTableRollBehavior.tableid = "none"

ActivatedAbilityTableRollBehavior.resourceAction = "none"

ActivatedAbility.RegisterType
{
	id = 'table_roll',
	text = 'Roll on Table',
	createBehavior = function()
		return ActivatedAbilityTableRollBehavior.new{
            customTable = RollTable.CreateNew(),
		}
	end
}

function ActivatedAbilityTableRollBehavior:SummarizeBehavior(ability, creatureLookup)
    return "Roll on Table"
end

function ActivatedAbilityTableRollBehavior:GetTable()
    if self.tableType == "custom" then
        return self.customTable
    else
        local ref = RollTableReference.CreateRef(self.tableType, self.tableid)
        return ref:GetTable()
    end
end

function ActivatedAbilityTableRollBehavior:Cast(ability, casterToken, targets, options)
	if #targets == 0 then
		return
	end

    local ref
    local t
    if self.tableType == "custom" then
        t = self.customTable
        ref = RollTableReference.CreateRef(t)
    else
        ref = RollTableReference.CreateRef(self.tableType, self.tableid)
        t = ref:GetTable()
    end

    if t == nil then
        return
    end
    
	local tokenids = ActivatedAbility.GetTokenIds(targets)
    local dcaction = ability:RequireSavingThrowsCo(self, casterToken, tokenids, {
        rollType = "table",
        id = "table",
        tableRef = ref,
        text = "Roll",
        explanation = "Roll on Table",
        targets = targets,
    })

    if dcaction == nil then
        --the roll was canceled.
        return
    end

    options.pay = true

    for i,target in ipairs(targets) do
        if target.token ~= nil then
		    local dcinfo = dcaction.info.tokens[target.token.charid]
            if dcinfo ~= nil then
			    options.symbols.cast.roll = dcinfo.result

                local rowIndex = t:RowIndexFromDiceResult(dcinfo.result)
                if rowIndex ~= nil and t.rows[rowIndex] ~= nil then
                    for _,entry in ipairs(t.rows[rowIndex].value.items) do
                        if entry.type == "resource" then
	                        local resourceTable = dmhub.GetTable("characterResources") or {}
                            local resourceInfo = resourceTable[entry.key]
                            if resourceInfo ~= nil then
                                if self.resourceAction == "replenish" then
                                    target.token:ModifyProperties{
                                        description = "Refresh Resource",
                                        execute = function()
                                            target.token.properties:RefreshResource(entry.key, resourceInfo.usageLimit, entry:RollQuantity(), ability.name)
                                        end,
                                    }
                                elseif self.resourceAction == "consume" then
                                    target.token:ModifyProperties{
                                        description = "Consume Resource",
                                        execute = function()
                                            target.token.properties:ConsumeResource(entry.key, resourceInfo.usageLimit, entry:RollQuantity(), ability.name)
                                        end,
                                    }
                                end
                            end
                        elseif entry.type == "item" then
                            local itemTable = dmhub.GetTable("tbl_Gear") or {}
                            local itemInfo = itemTable[entry.key]
                            if itemInfo ~= nil then
                                if self.itemAction == "grant" then

                                    target.token:ModifyProperties{
                                        description = "Grant Item",
                                        execute = function()
                                            target.token.properties:GiveItem(entry.key, entry:RollQuantity())
                                        end,
                                    }

                                elseif self.itemAction == "drop" then
                                    loot.SpawnDroppedItem(target.token, entry.key, entry:RollQuantity())
                                end
                            end
                        elseif entry.type == "monster" then
                            local maxsummons = 200
                            local monsterInfo = assets.monsters[entry.key]
                            if monsterInfo ~= nil then
                                if self.monsterAction == "summon" then
                                    local quantity = entry:RollQuantity()
                                    for i=1,quantity do
                                        maxsummons = maxsummons - 1
                                        if maxsummons <= 0 then
                                            break
                                        end
                                        local loc = target.token.loc
                                        if options.targetArea ~= nil then
                                            loc = options.targetArea.origin
                                        end
                                        local token = game.SpawnTokenFromBestiaryLocally(entry.key, loc)
                                        token.ownerId = target.token.ownerId
                                        token.summonerid = target.token.charid

                                        local notes = token.properties:get_or_add("notes", {})
                                        notes[#notes+1] = {
                                            title = "Summoned",
                                            text = string.format("Summoned by %s", target.token.description),
                                        }

                                        token.partyid = target.token.partyid

                                        token:UploadToken("Summon Monster")
                                        game.UpdateCharacterTokens()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

    end


end


function ActivatedAbilityTableRollBehavior:EditorItems(parentPanel)
	local result = {}
	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

    local tableParent

    local tableTypeOptions = {
        {id = "custom", text = "Custom"},
    }

    for k,tableType in pairs(Compendium.rollableTables) do
        tableTypeOptions[#tableTypeOptions+1] = {id = k, text = tableType.text}
    end

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        gui.Label{
            classes = "formLabel",
            text = "Table Type:",
        },

        gui.Dropdown{
            options = tableTypeOptions,
            idChosen = self.tableType,
            change = function(element)
                self.tableType = element.idChosen
                tableParent:FireEvent("refreshTableType")
                parentPanel:FireEventTree("refreshTable")
            end,
        },
    }

    tableParent = gui.Panel{
        flow = "vertical",
        width = "100%",
        height = "auto",
        create = function(element)
            element:FireEvent("refreshTableType")
        end,

        refreshTableType = function(element)
            local children = {}
            if self.tableType == "custom" then
                local tableEditor = RollTable.CreateEditor{
                    refreshData = function(element)
                        parentPanel:FireEventTree("refreshTable")
                    end,
                }

                tableEditor.data.SetData(nil, self.customTable, {noSubtable = true})

                children[#children+1] = tableEditor
            else

                local tableData = dmhub.GetTable(self.tableType) or {}
                local options = {}

                for k,v in pairs(tableData) do
                    options[#options+1] = {id = k, text = v.name}
                end

                table.sort(options, function(a,b) return a.text < b.text end)

                children[#children+1] = gui.Panel{
                    classes = {"formPanel"},
                    gui.Label{
                        classes = "formLabel",
                        text = "Table:",
                    },
                    gui.Dropdown{
                        options = options,
                        textDefault = "Select Table...",
                        idChosen = self.tableid,
                        change = function(element)
                            self.tableid = element.idChosen
                            parentPanel:FireEventTree("refreshTable")
                        end,
                    },
                }

            end

            element.children = children
        end,
    }

    result[#result+1] = tableParent

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        create = function(element) element:FireEvent("refreshTable") end,
        refreshTable = function(element)
            element:SetClass("collapsed", self:GetTable() ~= nil and self:GetTable():ContainsType("resource") == false)
        end,
        gui.Label{
            classes = "formLabel",
            text = "Resources:",
        },
        gui.Dropdown{
            options = {
                {id = "none", text = "No Behavior"},
                {id = "replenish", text = "Replenish"},
                {id = "consume", text = "Consume"},
            },
            idChosen = self.resourceAction,
            change = function(element)
                self.resourceAction = element.idChosen
            end,
        },
    }

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        create = function(element) element:FireEvent("refreshTable") end,
        refreshTable = function(element)
            element:SetClass("collapsed", self:GetTable() ~= nil and self:GetTable():ContainsType("item") == false)
        end,
        gui.Label{
            classes = "formLabel",
            text = "Items:",
        },
        gui.Dropdown{
            options = {
                {id = "none", text = "No Behavior"},
                {id = "grant", text = "Add to Inventory"},
                {id = "drop", text = "Drop on Map"},
            },
            idChosen = self:try_get("itemAction", "none"),
            change = function(element)
                self.itemAction = element.idChosen
            end,
        },
    }

    result[#result+1] = gui.Panel{
        classes = {"formPanel"},
        create = function(element) element:FireEvent("refreshTable") end,
        refreshTable = function(element)
            element:SetClass("collapsed", self:GetTable() ~= nil and self:GetTable():ContainsType("monster") == false)
        end,
        gui.Label{
            classes = "formLabel",
            text = "Monsters:",
        },
        gui.Dropdown{
            options = {
                {id = "none", text = "No Behavior"},
                {id = "summon", text = "Summon on Map"},
            },
            idChosen = self:try_get("monsterAction", "none"),
            change = function(element)
                self.monsterAction = element.idChosen
            end,
        },
    }



	return result
end