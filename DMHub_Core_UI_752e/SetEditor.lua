local mod = dmhub.GetModLoading()

--A set editor edits a set of string items, provided in a standard dropdown options list.
function gui.SetEditor(args)

    local value = DeepCopy(args.value or {})
    args.value = nil

    local addItemText = args.addItemText or "Add Item..."
    args.addItemText = nil

    local options = args.options or {}
    args.options = nil

    local resultPanel
    local params = {
        flow = "vertical",
        width = "auto",
        height = "auto",
		create = function(element)
            local children = element.children
            local dropdown = children[#children]

            children = {}

            for _,option in ipairs(options) do
                if value[option.id] ~= nil then
                    children[#children+1] = gui.Panel{
                        flow = "horizontal",
                        width = "auto",
                        height = "auto",
                        children = {
                            gui.Label{
                                text = option.text,
                                fontSize = 14,
                                width = 300,
                                height = "auto",
                            },
                            gui.DeleteItemButton{
                                click = function(element)
                                    value[option.id] = nil
                                    resultPanel:FireEventTree("refreshSet")
                                    resultPanel:FireEvent("change", value)
                                end,
                            },
                        },
                    }
                end
            end

            children[#children+1] = dropdown
            element.children = children
        end,

		refreshSet = function(element)
			element:FireEvent("create")
		end,

		gui.Dropdown{
			textOverride = addItemText,
			create = function(element)
				local dropdownOptions = {}
				for _,option in ipairs(options) do
					if value[option.id] == nil then
						dropdownOptions[#dropdownOptions+1] = {
							id = option.id,
							text = option.text,
						}
					end
				end

				element.options = dropdownOptions
			end,

			refreshSet = function(element)
				element:FireEvent("create")
			end,

			change = function(element)
                value[element.idChosen] = true
                resultPanel:FireEventTree("refreshSet")
                resultPanel:FireEvent("change", value)
			end,
		},
    }

    for k,v in pairs(args) do
        params[k] = v
    end

    resultPanel = gui.Panel(params)

    return resultPanel
end