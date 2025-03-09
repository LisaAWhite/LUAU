local mod = dmhub.GetModLoading()

RegisterGameType("AIAssistant")

AIAssistant.tableName = "aiassistant"
AIAssistant.name = "Assistant"
AIAssistant.isdefault = false
AIAssistant.importer = "none"
AIAssistant.temperature = 0.4
AIAssistant.welcomeMessage = ""

setting{
    id = "aifactoids",
    default = {},
    description = "AI Factoids",
    storage = "preference",
}

function AIAssistant.CreateNew()
    return AIAssistant.new{
        context = {},
    }
end

function AIAssistant:ProcessFactoid(text)
    local factoids = dmhub.GetSettingValue("aifactoids")
    if text == "!facts" then
        local result = {}
        for k,v in pairs(factoids) do
            result[#result+1] = {
                id = k,
                text = v,
            }
        end

        table.sort(result, function(a,b) return a.id < b.id end)
        local response = ""
        for _,entry in ipairs(result) do
            response = string.format("%s\n%s: %s", response, entry.id, entry.text)
        end

        local context = self:GenerateContext({})

        local numChars = 0
        for _,c in ipairs(context) do
            numChars = numChars + #c.content
        end

        local percentFull = round(((100*numChars)/3)/2000)

        if response == "" then
            return string.format(tr("I don't know any facts yet. Try typing something like !location the party is in a bustling city by a river\nMy memory is around %d%% full of things I can know"), percentFull)
        else
            return string.format(tr("I know the following facts: %s\nMy memory is around %d%% full of things I can know."),  response, percentFull)
        end
    end


    local i,j,label,content = string.find(text, "^!(%w+):(.*)")


    if i == nil then
        content = text

        for j=1,1000 do
            label = string.format("fact%d", j)
            if factoids[label] == nil then
                break
            end
        end
    end

    content = trim(content)
    if content == "" then
        factoids[label] = nil
        dmhub.SetSettingValue("aifactoids", factoids)
        return string.format("Fact %s has been cleared", label)
    else
        factoids[label] = content
        dmhub.SetSettingValue("aifactoids", factoids)
        return string.format("This fact has been recorded under the label %s", label)
    end

end

function AIAssistant:GenerateContext(m_context)
    local result = DeepCopy(self.context)

	local partyMembers = dmhub.GetCharacterIdsInParty(GetDefaultPartyID())

    local partyDesc = ""
    local characterNotes = {}
    for _,charid in ipairs(partyMembers) do
	    local token = dmhub.GetCharacterById(charid)
        if token ~= nil and token.properties ~= nil and token.properties.typeName == "character" then
            local arms = ""
            local itemid = token.properties:Equipment()["mainhand1"]
            local itemTable = dmhub.GetTable(equipment.tableName)
            if itemid ~= nil and itemTable[itemid] ~= nil then
                arms = string.format(". Armed with %s", itemTable[itemid].name)
                itemid = token.properties:Equipment()["offhand1"]
                if itemid ~= nil and itemTable[itemid] ~= nil then
                arms = string.format("%s and %s", arms, itemTable[itemid].name)
                end
            end
            partyDesc = partyDesc .. "\n" .. string.format("%s: a %s%s", token.name, token.properties:GetCharacterSummaryText(), arms)

            local notes = token.properties:try_get("notes")
            if type(notes) == "table" and #notes > 0 then
                local notesText = string.format("These are %s's character notes:", token.name)
                for _,note in ipairs(notes) do
                    notesText = string.format("%s\n\n%s: %s", notesText, note.title, note.text)
                end

                characterNotes[#characterNotes+1] = notesText
            end
        end
    end

    if partyDesc ~= "" then
        result[#result+1] = {
            role = "system",
            content = string.format("These are the player characters for this game:\n%s", partyDesc),
        }

        for _,charNote in ipairs(characterNotes) do
            result[#result+1] = {
                role = "system",
                content = charNote,
            }
        end
    end

    local factoids = dmhub.GetSettingValue("aifactoids")
    for k,fact in pairs(factoids) do
        result[#result+1] = {
            role = "system",
            content = fact,
        }
    end

    local contentSize = 0
    for _,entry in ipairs(result) do
        contentSize = contentSize + #entry.content
    end

    for _,entry in ipairs(m_context) do
        contentSize = contentSize + #entry.content
    end

    while contentSize > 6000 and #m_context > 1 do
        contentSize = contentSize - #m_context[1].content
        table.remove(m_context, 1)
    end
    
    for _,c in ipairs(m_context) do
        result[#result+1] = c
    end

    return result
end

local CreateEditor

Compendium.Register{
    section = "Modding",
    text = "AI Assistants",
    click = function(contentPanel)
        Compendium.ObjectTableEditor{
            contentPanel = contentPanel,
            tableid = AIAssistant.tableName,
            createInstance = AIAssistant.CreateNew,
            createEditor = CreateEditor,
        }
    end,
}

local messageRoles = {
    {
        id = "user",
        text = "User",
    },
    {
        id = "assistant",
        text = "Assistant",
    },
    {
        id = "system",
        text = "System",
    },
}

CreateEditor = function(key)
    local tableData = dmhub.GetTable(AIAssistant.tableName)
    local item = tableData[key]

    local Upload = function()
        dmhub.SetAndUploadTableItem(AIAssistant.tableName, item)
    end

    local resultPanel

    resultPanel = gui.Panel{
        styles = {Compendium.Styles},
        classes = {"mainContentPanel"},

        vscroll = true,

        gui.Panel{
            classes = {"formPanel"},
            gui.Label{
                classes = {"formLabel"},
                text = "Name:",
            },
            gui.Input{
                text = item.name,
                placeholderText = "Assistant Name...",
                characterLimit = 20,
                change = function(element)
                    item.name = element.text
                    Upload()
                end,
            },
        },

        gui.Panel{
            classes = {"formPanel"},
            gui.Label{
                classes = {"formLabel"},
                text = "Temperature:",
            },
            gui.Input{
                text = tostring(item.temperature),
                placeholderText = "Temperature...",
                characterLimit = 8,
                change = function(element)
                    local n = tonumber(element.text)
                    if n ~= nil and n >= 0 and n <= 1 then
                        item.temperature = n
                    else
                        element.text = tostring(item.temperature)
                    end
                    Upload()
                end,
            },
        },

        gui.Button{
            text = "Make Default",
            classes = {cond(item.isdefault, "collapsed")},
            click = function(element)
                for otherKey,otherItem in pairs(tableData) do
                    local newDefault = (otherKey == key)
                    if newDefault ~= otherItem.isdefault then
                        otherItem.isdefault = newDefault
                        dmhub.SetAndUploadTableItem(AIAssistant.tableName, otherItem)
                    end
                end
                resultPanel:FireEventTree("refresh")
            end,
            refresh = function(element)
                element:SetClass("collapsed", item.isdefault)
            end,
        },

        gui.Label{
            text = "Default Assistant",
            classes = {cond(not item.isdefault, "collapsed")},
            refresh = function(element)
                element:SetClass("collapsed", not item.isdefault)
            end,
        },

        gui.Panel{
            classes = {"formPanel"},
            gui.Label{
                classes = {"formLabel"},
                valign = "center",
                text = "Welcome Message:",
            },
            gui.Input{
                text = item.welcomeMessage,
                textAlignment = "topleft",
                hpad = 8,
                vpad = 8,
                placeholderText = "Enter Welcome Message...",
                width = 600,
                height = "auto",
                minHeight = 60,
                maxHeight = 400,
                multiline = true,

                characterLimit = 1024,
                change = function(element)
                    item.welcomeMessage = element.text
                    Upload()
                end,
            },
        },

        gui.Panel{
            classes = {"formPanel"},
            gui.Label{
                classes = {"formLabel"},
                text = "Importer:",
            },
            gui.Dropdown{
                create = function(element)
                    local options = {
                        {
                            text = "(None)",
                            id = "none",
                        }
                    }

                    local importers = import.importers
                    for key,importer in pairs(importers) do
                        options[#options+1] = {
                            id = key,
                            text = importer.description,
                        }
                    end

                    element.options = options
                    element.idChosen = item.importer
                end,
                change = function(element)
                    item.importer = element.idChosen
                    Upload()
                end,
            }
        },

        gui.Panel{
            flow = "vertical",
            width = "auto",
            height = "auto",

            create = function(element)
                element:FireEvent("refresh")
            end,

            refresh = function(element)
                local children = {}
                for n,message in ipairs(item.context) do
                    children[#children+1] = gui.Panel{
                        flow = "horizontal",
                        vmargin = 8,
                        height = "auto",
                        width = 800,
                        gui.Dropdown{
                            valign = "center",
                            options = messageRoles,
                            idChosen = message.role,
                            change = function(element)
                                message.role = element.idChosen,
                                Upload()
                            end,
                        },

                        gui.Input{
                            valign = "center",
                            minHeight = 40,
                            width = 600,
                            height = "auto",
                            hmargin = 8,
                            characterLimit = 1024,
                            placeholderText = "Enter message...",
                            multiline = true,
                            text = message.content,
                            change = function(element)
                                message.content = element.text
                                Upload()
                            end,
                        },

                        gui.DeleteItemButton{
                            valign = "center",
                            width = 16,
                            height = 16,
                            click = function(element)
                                table.remove(item.context, n)
                                Upload()
                                resultPanel:FireEventTree("refresh")
                            end,
                        },
                    }
                end

                children[#children+1] = gui.Dropdown{
                    textOverride = "Add Context...",
                    options = messageRoles,
                    idChosen = "",
                    change = function(element)
                        item.context[#item.context+1] = {
                            role = element.idChosen,
                            content = "",
                        }
                        Upload()
                        resultPanel:FireEventTree("refresh")
                    end,
                }

                element.children = children
            end,
        }


    }

    return resultPanel
end