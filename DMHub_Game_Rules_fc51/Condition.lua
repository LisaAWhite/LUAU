local mod = dmhub.GetModLoading()

RegisterGameType("CharacterCondition", "CharacterFeature")

CharacterCondition.name = "New Condition"
CharacterCondition.description = ""
CharacterCondition.tableName = "charConditions"
CharacterCondition.emoji = "none"
CharacterCondition.immunityPossible = false
CharacterCondition.trackCaster = false
CharacterCondition.source = "Condition"
CharacterCondition.stackable = false

CharacterCondition.conditionsByName = {}

function CharacterCondition.OnDeserialize(self)
	if not self:has_key("guid") then
		self.guid = dmhub.GenerateGuid()
	end
end

function CharacterCondition.FillDropdownOptions(options)
	local result = {}
	local dataTable = dmhub.GetTable(CharacterCondition.tableName)
	for k,condition in unhidden_pairs(dataTable) do
		result[#result+1] = {
			id = k,
			text = condition.name,
		}
	end

	table.sort(result, function(a,b) return a.text < b.text end)
	for i,item in ipairs(result) do
		options[#options+1] = item
	end
end

function CharacterCondition.CreateNew()
	return CharacterCondition.new{
		guid = dmhub.GenerateGuid(),
		iconid = "ui-icons/skills/1.png",
		display = {
			bgcolor = '#ffffffff',
			hueshift = 0,
			saturation = 1,
			brightness = 1,
		}
	}
end

function CharacterCondition:GetUnderlyingConditions()
	local result = self:try_get("underlying")
	if result == nil then
		result = {}
	end

	return result
end

function CharacterCondition:AddUnderlyingCondition(condid)
	local underlying = self:get_or_add("underlying", {})
	underlying[condid] = true
end

function CharacterCondition:RemoveUnderlyingCondition(condid)
	local underlying = self:get_or_add("underlying", {})
	underlying[condid] = nil
end

local UploadConditionWithId = function(id)
	local dataTable = dmhub.GetTable(CharacterCondition.tableName) or {}
	dmhub.SetAndUploadTableItem(CharacterCondition.tableName, dataTable[id])
end

local SetData = function(tableName, conditionPanel, condid)
	local dataTable = dmhub.GetTable(tableName) or {}
	local condition = dataTable[condid]
	local UploadCondition = function()
		dmhub.SetAndUploadTableItem(tableName, condition)
	end

	if conditionPanel.data.condid ~= "" and conditionPanel.data.condid ~= condid and dmhub.ToJson(dataTable[conditionPanel.data.condid]) ~= conditionPanel.data.conditionjson then
		UploadConditionWithId(conditionPanel.data.condid)
	end

	conditionPanel.data.condid = condid
	conditionPanel.data.conditionjson = dmhub.ToJson(condition)

	local children = {}

	--the name of the condition.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		gui.Label{
			text = 'Name:',
			valign = 'center',
			minWidth = 240,
		},
		gui.Input{
			text = condition.name,
			change = function(element)
				condition.name = element.text
				UploadCondition()
			end,
		},
	}

	--the condition's icon.
	local iconEditor = gui.IconEditor{
		library = "ongoingEffects",
		bgcolor = condition.display['bgcolor'] or '#ffffffff',
		margin = 20,
		width = 64,
		height = 64,
		halign = "left",
		value = condition.iconid,
		change = function(element)
			condition.iconid = element.value
			UploadCondition()
		end,
		create = function(element)
			element.selfStyle.hueshift = condition.display['hueshift']
			element.selfStyle.saturation = condition.display['saturation']
			element.selfStyle.brightness = condition.display['brightness']
		end,
	}

	local iconColorPicker = gui.ColorPicker{
		value = condition.display['bgcolor'] or '#ffffffff',
		hmargin = 8,
		width = 24,
		height = 24,
		valign = 'center',
		borderWidth = 2,
		borderColor = '#999999ff',

		confirm = function(element)
			iconEditor.selfStyle.bgcolor = element.value
			condition.display['bgcolor'] = element.value
		end,

		change = function(element)
			iconEditor.selfStyle.bgcolor = element.value
		end,
	}

	local iconPanel = gui.Panel{
		width = 'auto',
		height = 'auto',
		flow = 'horizontal',
		halign = 'left',
		iconEditor,
		iconColorPicker,
	}

	children[#children+1] = iconPanel

	local emojiOptions = {
		{
			id = "none",
			text = "No Emoji",
		}
	}

	for k,emoji in pairs(assets.emojiTable) do
		if (not emoji.hidden) and emoji.emojiType == 'Status' and emoji.looping then
			emojiOptions[#emojiOptions+1] = {
				id = k,
				text = emoji.description,
			}
		end
	end

	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		gui.Label{
			text = 'Emoji:',
			valign = "center",
			minWidth = 200,
			width = 'auto',
			height = 'auto',
		},
		gui.Dropdown{
			classes = "formDropdown",
			options = emojiOptions,
			idChosen = condition.emoji,
			change = function(element)
				condition.emoji = element.idChosen
				UploadCondition()
			end,
		},
	}

	--condition description.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		height = 'auto',
		gui.Label{
			text = "Details:",
			valign = "center",
			minWidth = 240,
		},
		gui.Input{
			text = condition.description,
			multiline = true,
			minHeight = 50,
			height = 'auto',
			width = 400,
			textAlignment = "topleft",
			change = function(element)
				condition.description = element.text
				UploadCondition()
			end,
		}
	}

	--this condition is stackable.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		height = 'auto',
		gui.Check{
			value = condition.stackable,
			text = "Stackable",
			change = function(element)
				condition.stackable = not condition.stackable
				UploadCondition()
			end,
		},
	}

	--immunity to this condition is possible.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		height = 'auto',
		gui.Check{
			value = condition.immunityPossible,
			text = "Creatures can be immune",
			change = function(element)
				condition.immunityPossible = not condition.immunityPossible
				UploadCondition()
			end,
		},
	}

	--track caster who applied this condition.
	children[#children+1] = gui.Panel{
		classes = {'formPanel'},
		height = 'auto',
		gui.Check{
			value = condition.trackCaster,
			text = "Track Caster",
			change = function(element)
				condition.trackCaster = not condition.trackCaster
				UploadCondition()
			end,
		},
	}

	--underlying conditions.
	children[#children+1] = gui.Panel{
		flow = "vertical",
		width = 400,
		height = "auto",

		create = function(element)
			element:FireEvent("refreshUnderlying")
		end,

		refreshUnderlying = function(element)
			local currentChildren = element.children

			local children = {}

			if #condition:GetUnderlyingConditions() > 0 then
				children[#children+1] = gui.Label{
					width = "auto",
					height = "auto",
					fontSize = 22,
					text = "Underlying Conditions",
				}
			end

			local dataTable = dmhub.GetTable(CharacterCondition.tableName) or {}
			for id,_ in pairs(condition:GetUnderlyingConditions()) do
				local underlyingCond = dataTable[id]
				if underlyingCond ~= nil then
					children[#children+1] = gui.Label{
						bgimage = "panels/square.png",
						bgcolor = "#00000088",
						text = underlyingCond.name,
						fontSize = 18,
						cornerRadius = 4,
						width = 200,
						height = 22,

						gui.DeleteItemButton{
							halign = "right",
							width = 16,
							height = 16,
							click = function(element)
								condition:RemoveUnderlyingCondition(id)
								UploadCondition()
								element.parent:DestroySelf()
							end,
						}
					}
				end
			end

			children[#children+1] = currentChildren[#currentChildren]
			element.children = children
		end,

		gui.Dropdown{
			create = function(element)
				element:FireEvent("refreshUnderlying")
			end,

			refreshUnderlying = function(element)
				local options = {
					{
						id = "none",
						text = "Add Underlying Condition...",
					}
				}

				local dataTable = dmhub.GetTable(CharacterCondition.tableName) or {}
				for id,info in pairs(dataTable) do
					if info:try_get("hidden", false) == false and id ~= condid and (not condition:GetUnderlyingConditions()[id]) then
						options[#options+1] = {
							id = id,
							text = info.name,
						}
					end
				end

				element.options = options
				element.idChosen = "none"
			end,

			change = function(element)
				if element.idChosen == "none" then
					return
				end

				condition:AddUnderlyingCondition(element.idChosen)
				UploadCondition()
				conditionPanel:FireEventTree("refreshUnderlying")
			end,
		},
	}

	--list of modifiers that apply.
	children[#children+1] = gui.Panel{
		classes = {'modsPanel'},
		styles = {
			{
				halign = "left",
			},
			{
				classes = {'modsPanel'},
				width = 800,
				height = 600,
				halign = 'left',
			},
			{
				classes = {'namePanel'},
				collapsed = 1,
			},
			{
				classes = {'sourcePanel'},
				collapsed = 1,
			},
			{
				classes = {'descriptionPanel'},
				collapsed = 1,
			},
		},

		condition:EditorPanel{
			modifierRefreshed = function(element)
				dmhub.Debug("REFRESH:: MODIFIERS UPLOAD")
				UploadCondition()
			end,
		},
	}

	conditionPanel.children = children
end

function CharacterCondition.CreateEditor()
	local conditionPanel
	conditionPanel = gui.Panel{
		data = {
			SetData = function(tableName, condid)
				SetData(tableName, conditionPanel, condid)
			end,
			condid = "",
			conditionjson = "",
		},
		destroy = function(element)
			
			local dataTable = dmhub.GetTable(CharacterCondition.tableName) or {}

			--if the condition changed, then upload it.
			if element.data.condid ~= "" and dmhub.ToJson(dataTable[element.data.condid]) ~= element.data.conditionjson then
				UploadConditionWithId(element.data.condid)
			end
		end,
		vscroll = true,
		classes = 'class-panel',
		styles = {
			{
				halign = "left",
			},
			{
				classes = {'class-panel'},
				width = 1200,
				height = '90%',
				halign = 'left',
				flow = 'vertical',
				pad = 20,
			},
			{
				classes = {'label'},
				color = 'white',
				fontSize = 22,
				width = 'auto',
				height = 'auto',
			},
			{
				classes = {'input'},
				width = 200,
				height = 26,
				fontSize = 18,
				color = 'white',
			},
			{
				classes = {'formPanel'},
				flow = 'horizontal',
				width = 'auto',
				height = 'auto',
				halign = 'left',
				vmargin = 2,
			},

		},
	}

	return conditionPanel
end

dmhub.RegisterEventHandler("refreshTables", function()
	local dataTable = dmhub.GetTable(CharacterCondition.tableName)
	for k,v in pairs(dataTable) do
		CharacterCondition.conditionsByName[v.name] = v
	end
end)
