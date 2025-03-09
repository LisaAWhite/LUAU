local mod = dmhub.GetModLoading()

local ShowMalice
local CreateEditorPanel

Compendium.Register{
    section = "Rules",
    text = "Malice",
    contentType = "MonsterGroup",
    click = function(contentPanel)
        ShowMalice(contentPanel)
    end,
}

--- @param contentPanel Panel
ShowMalice = function(contentPanel)
    local t = dmhub.GetTable(MonsterGroup.tableName)

    local dataItems = {}

    local rightPanel = gui.Panel{
        width = 1200,
        height = "90%",
        vscroll = true,
        flow = "vertical",
    }

    local itemsListPanel

    itemsListPanel = gui.Panel{
        classes = {"list-panel"},
        vscroll = true,
        monitorAssets = true,
        refreshAssets = function()
            local newDataItems = {}
            local children = {}

            for k,item in pairs(t) do
                newDataItems[k] = dataItems[k] or Compendium.CreateListItem{
                    tableName = MonsterGroup.tableName,
                    key = k,
                    select = itemsListPanel.aliveTime > 0.2,
                    click = function()
                        rightPanel.children = {
                            CreateEditorPanel(k, t[k])
                        }
                    end,
                }

                newDataItems[k].text = item.name

                children[#children+1] = newDataItems[k]
            end

            table.sort(children, function(a,b) return a.text < b.text end)
            dataItems = newDataItems
            itemsListPanel.children = children
        end,
    }

	itemsListPanel:FireEvent('refreshAssets')

	local leftPanel = gui.Panel{
		selfStyle = {
			flow = 'vertical',
			height = '100%',
			width = 'auto',
		},

		itemsListPanel,
		Compendium.AddButton{
			click = function(element)
				dmhub.SetAndUploadTableItem(MonsterGroup.tableName, MonsterGroup.CreateNew{})
			end,
		}
	}

    contentPanel.children = {leftPanel, rightPanel}
end


--- @param key string
--- @param monsterGroup MonsterGroup
CreateEditorPanel = function(key, monsterGroup)
    local m_dirty = false
    local Invalidate = function()
        m_dirty = true
    end

    local resultPanel
    resultPanel = gui.Panel{
        styles = Styles.Form,

        flow = "vertical",
        width = 800,
        height = "90%",
        vscroll = true,


        destroy = function()
            if m_dirty then
                dmhub.SetAndUploadTableItem(MonsterGroup.tableName, monsterGroup)
                m_dirty = false
            end
        end,
        gui.Panel{
            classes = {"formPanel"},
            gui.Label{
                classes = {"formLabel"},
                text = "Name:",
                halign = "left",
            },
            gui.Input{
                classes = {"formInput"},
                text = monsterGroup.name,
                halign = "left",
                change = function(element)
                    monsterGroup.name = element.text
                end,
            }
        },

        gui.Panel{
            width = "auto",
            height = "auto",
            flow = "vertical",

            create = function(element)
                local children = {}
                for i,ability in ipairs(monsterGroup.maliceAbilities) do
                    children[#children+1] = gui.Panel{
                        flow = "vertical",
                        width = 600,
                        height = "auto",

                        gui.Label{
                            width = 300,
                            height = 20,
                            fontSize = 14,
                            color = "white",
                            text = ability.name,
                            lmargin = 4,

                            gui.SettingsButton{
                                halign = "right",
                                width = 12,
                                height = 12,
                                press = function(element)
                                    m_dirty = true
                                    element.root:AddChild(ability:ShowEditActivatedAbilityDialog{
                                    })
                                end,
                            },
                        },

                        gui.Label{
                            width = 600,
                            height = "auto",
                            fontSize = 12,
                            text = ability.description,
                            color = "white",
                        },
                    }
                end

                element.children = children
            end,
        },
    }

    return resultPanel
end
