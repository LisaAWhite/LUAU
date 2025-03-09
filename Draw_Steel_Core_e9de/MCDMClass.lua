local mod = dmhub.GetModLoading()

Class.hitpointsCalculation = ""

Class.baseCharacteristics = {
    agl = 2,
    rea = 2,
    arrays = {
        {2,-1,-1},
        {1,1,-1},
        {1,0,0},
    }
}

Class.numKits = 1

Class.heroicResourceName = "Heroic Resource"

--calculate the base attributes of the class.
function Class:CalculateBaseAttributes(targetCreature)
    local attributeBuild = targetCreature:try_get("attributeBuild")
    for _,attrid in ipairs(creature.attributeIds) do
        local baseValue = self.baseCharacteristics[attrid]
        if baseValue == nil and attributeBuild[attrid] ~= nil and attributeBuild.array ~= nil and self.baseCharacteristics.arrays[attributeBuild.array] ~= nil then
            local array = self.baseCharacteristics.arrays[attributeBuild.array]
            baseValue = array[attributeBuild[attrid]]
        end
        
        targetCreature:GetBaseAttribute(attrid).baseValue = baseValue or 0
    end
end

function Class:CustomEditor(UploadFn, children)

    if self.isSubclass then
        return nil
    end

    children[#children+1] = gui.Panel{
        width = "auto",
        height = "auto",
        flow = "horizontal",
        gui.Label{
            fontSize = 22,
            text = "Heroic Resource:",
            minWidth = 240,
        },

        gui.Input{
            fontSize = 18,
            width = 180,
            height = 22,
            characterLimit = 32,
            text = self.heroicResourceName,
            change = function(element)
                self.heroicResourceName = element.text
                UploadFn()
            end,
        },
    }

    for _,attrid in ipairs(creature.attributeIds) do
        children[#children+1] = gui.Panel{
            width = "auto",
            height = "auto",
            flow = "horizontal",
            gui.Label{
                fontSize = 22,
                text = creature.attributesInfo[attrid].description .. ":",
                minWidth = 240,
            },

            gui.Input{
                fontSize = 18,
                width = 180,
                height = 22,
                text = self.baseCharacteristics[attrid] or "",
                change = function(element)
                    self.baseCharacteristics = DeepCopy(self.baseCharacteristics)
                    self.baseCharacteristics[attrid] = tonumber(element.text)
                    element.text = self.baseCharacteristics[attrid] or ""
                    UploadFn()
                end,
            },
        }
    end

    children[#children+1] = gui.Panel{
        width = "auto",
        height = "auto",
        flow = "horizontal",
        vmargin = 8,
        gui.Label{
            fontSize = 22,
            text = "Base Stamina:",
            minWidth = 240,
        },

        gui.GoblinScriptInput{
            fontSize = 18,
            width = 240,
            value = self.hitpointsCalculation,
            placeholderText = "Base Stamina Calculation...",
            change = function(element)
                self.hitpointsCalculation = element.value
                UploadFn()
            end,

            documentation = {
                help = "This GoblinScript is used to determine the base stamina for characters of this class.",
                output = "number",

                examples = {
                    {
                        script = "28",
                        text = "Characters of this class will have a stamina of 28.",
                    },
                    {
                        script = "12 + (level-1)*8",
                        text = "Characters of this class will have 12 stamina at 1st level and 8 stamina for each level beyond first.",
                    },
                },
                subject = creature.helpSymbols,
                subjectDescription = "The character whose stamina we are calculating.",
            }
        },
    }

    children[#children+1] = gui.Check{
        text = "Has Two Kits",
        value = self.numKits > 1,
        change = function(element)
            if element.value then
                self.numKits = 2
            else
                self.numKits = 1
            end
            UploadFn()
        end,
    }
end

function Class:Render(args, options)
	args = args or {}

    local panelParams = {
        styles = {
            Styles.Default,
            {
                selectors = {"label"},
                color = "white",
            },
        },
        width = 500,
        height = "auto",
        flow = "vertical",

        gui.Label{
            uppercase = true,
            bold = true,
            fontSize = 28,
            text = self.name,
            width = "auto",
            height = "auto",
        }
    }

	for k,v in pairs(args or {}) do
		panelParams[k] = v
	end

    return gui.Panel(panelParams)
end