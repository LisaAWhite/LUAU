local mod = dmhub.GetModLoading()

	

function TriggeredAbility:GenerateEditor(options)
	options = options or {}

	local leftPanel = gui.Panel{
		id = "leftPanel",
		halign = "left",
		width = "55%",
		classes = "mainPanel",
	}

	local Refresh
	Refresh = function()
		local children = {}

		children[#children+1] = gui.Panel{
			classes = {"abilityInfo", 'formPanel'},
			children = {
				gui.Label{
					text = "Name:",
					classes = {"formLabel"},
				},
				gui.Input{
					classes = "formInput",
					placeholderText = "Enter Trigger Name...",
					text = self.name,
					change = function(element)
						self.name = element.text
					end,
				},

			},
		}

		if not options.excludeTriggerCondition then

            children[#children+1] = gui.Panel{
                classes = {"abilityInfo", 'formPanel'},
                children = {
                    gui.Label{
                        text = "Subject:",
                        classes = {"formLabel"},
                    },
                    gui.Dropdown{
						selfStyle = {
							height = 30,
							width = 260,
							fontSize = 16,
						},
                        options = {
                            {id = "self", text = "Self"},
                            {id = "any", text = "Self or Other Creatures"},
                            {id = "selfandheroes", text = "Self or Other Heroes"},
                            {id = "otherheroes", text = "Other Heroes"},
                            {id = "selfandallies", text = "Self or Allies"},
                            {id = "allies", text = "Allies"},
                            {id = "enemy", text = "Enemy"},
                            {id = "other", text = "Other Creatures"},
                        },
                        idChosen = self:try_get("subject", "self"),
                        change = function(element)
                            self.subject = element.idChosen
                            Refresh()
                        end,
                    },
                },
            }

            children[#children+1] = gui.Panel{
                classes = {"abilityInfo", 'formPanel'},
                children = {
                    gui.Label{
                        text = "When:",
                        classes = {"formLabel"},
                    },
                    gui.Dropdown{
						selfStyle = {
							height = 30,
							width = 260,
							fontSize = 16,
						},
                        options = {
                            {id = "always", text = "Always"},
                            {id = "combat", text = "In Combat"},
                        },
                        idChosen = self:try_get("whenActive", "always"),
                        change = function(element)
                            self.whenActive = element.idChosen
                            Refresh()
                        end,
                    },
                },
            }

            local conditionOptions = {
                {id = "none", text = "None"},
            }
            CharacterCondition.FillDropdownOptions(conditionOptions)
            children[#children+1] = gui.Panel{
                classes = {"abilityInfo", 'formPanel'},
                children = {
                    gui.Label{
                        text = "Has Condition:",
                        classes = {"formLabel"},
                    },
                    gui.Dropdown{
						selfStyle = {
							height = 30,
							width = 260,
							fontSize = 16,
						},
                        options = conditionOptions,
                        idChosen = self:try_get("characterConditionRequired", "none"),
                        change = function(element)
                            if element.idChosen == "none" then
                                self.characterConditionRequired = nil
                            else
                                self.characterConditionRequired = element.idChosen
                            end
                            Refresh()
                        end,
                    },
                },
            }

            if self:try_get("characterConditionRequired", "none") ~= "none" then
                children[#children+1] = gui.Check{
                    classes = {"abilityInfo"},
                    text = "Condition must be inflicted by you",
                    value = self:try_get("characterConditionInflictedBySelf", false),
                    change = function(element)
                        self.characterConditionInflictedBySelf = element.value
                        Refresh()
                    end,
                }
            end

    		children[#children+1] = gui.Check{
    			classes = {"abilityInfo"},
		    	text = "Choose whether to trigger this ability",
		    	value = not self.mandatory,
		    	change = function(element)
		    		self.mandatory = not element.value
		    	end,
		    }


            if self:try_get("subject", "self") ~= "self" then
                children[#children+1] = gui.Panel{
                    classes = {"abilityInfo", 'formPanel'},
                    children = {
                        gui.Label{
                            text = "Range:",
                            classes = {"formLabel"},
                        },
                        gui.Input{
                            classes = "formInput",
                            placeholderText = "Enter Range...",
                            characterLimit = 4,
                            text = self:try_get("subjectRange", ""),
                            change = function(element)
                                self.subjectRange = element.text
                            end,
                        }
                    }
                }
            end

			--the condition that starts the trigger.
			children[#children+1] = gui.Panel{
				classes = {"abilityInfo", 'formPanel'},
				children = {
					gui.Label{
						text = 'Trigger:',
						classes = {'formLabel'},
					},
					gui.Dropdown{
						selfStyle = {
							height = 30,
							width = 260,
							fontSize = 16,
						},

						options = TriggeredAbility.GetTriggerDropdownOptions(),
						idChosen = self.trigger,
                        hasSearch = true,

						events = {
							change = function(element)
								self.trigger = element.idChosen
								Refresh()
							end,
						},
					},
				}
			}
		end

		local actionOptions = CharacterResource.GetActionOptions()
		actionOptions[#actionOptions+1] = {
			id = "none",
			text = "None",
		}
		printf("RESOURCE: %s", json(self:ActionResource()))
		children[#children+1] = gui.Panel{
			classes = {"abilityInfo", "formPanel"},
			gui.Label{
				classes = "formLabel",
				text = "Action:",
			},
			gui.Dropdown{
				classes = "formDropdown",
				idChosen = self:ActionResource() or "none",
				options = actionOptions,
				change = function(element)
					if element.idChosen == "none" then
						self.actionResourceId = nil
					else
						self.actionResourceId = element.idChosen
					end
				end,
			},
		}

		local helpSymbols = {
			caster = {
				name = "Caster",
				type = "creature",
				desc = "The creature that controls the aura triggering this ability.\n\n<color=#ffaaaa><i>This field is only available for triggered abilities that are triggered by an aura.</i></color>",
			},
            subject = {
                name = "Subject",
                type = "creature",
                desc = "The creature that the event occurred on. This will be the same as Self for triggered abilities that only affect self.",
            },
		}

		local examples = {
			{
				script = "hitpoints < 5",
				text = "The triggered ability only activates when hitpoints are below 5.",
			},
		}

        local triggerInfo = TriggeredAbility.GetTriggerById(self.trigger)
        if triggerInfo ~= nil then
            for k,v in pairs(triggerInfo.symbols or {}) do
                helpSymbols[k] = v
            end

            for _,example in ipairs(triggerInfo.examples or {}) do
                examples[#examples+1] = example
            end
        end

		children[#children+1] = gui.Panel{
			classes = {'abilityInfo', 'formPanel'},
			gui.Label{
				classes = {'formLabel'},
				text = 'Condition:',
			},
			gui.GoblinScriptInput{
				value = self.conditionFormula,
				change = function(element)
					self.conditionFormula = element.value
				end,

				documentation = {
					help = string.format("This GoblinScript is used to determine whether the triggered ability activates."),
					output = "boolean",
					examples = examples,
					subject = creature.helpSymbols,
					subjectDescription = "The creature the ability will trigger on",
					symbols = helpSymbols,
				},

			},
		}

		children[#children+1] = gui.Check{
			classes = {"abilityInfo"},
			text = "Choose whether to trigger this ability",
			value = not self.mandatory,
			change = function(element)
				self.mandatory = not element.value
			end,
		}

		if not options.excludeActivationSavingThrows then

			if self.trigger == "zerohitpoints" then
				examples = {
					{
						script = "5 + Damage",
						text = "This ability will only trigger if the creature can make a saving throw with DC equal to 5 + the damage taken.",
					},
				}
			else

				examples = {
					{
						script = "Hitpoints = Maximum Hitpoints",
						text = "This ability will only trigger if the creature is at maximum health.",
					},
				}
			end

			--a saving throw that allows the trigger to activate if passed. This is for e.g. Zombies who
			--make a saving throw to see if they can activate their withstand death.

			local savingThrowValuePanel = gui.Panel{
				classes = {'formPanel', cond(self.save == 'none', 'collapsed-anim')},
				refresh = function(element)
					element:SetClass("collapsed-anim", self.save == 'none')
				end,
				gui.Label{
					classes = {'formLabel'},
					text = 'DC:',
				},
				gui.GoblinScriptInput{
					width = 300,
					height = 20,
					fontSize = 14,
					value = self.savedc,
					change = function(element)
						self.savedc = element.value
					end,

					documentation = {
						help = string.format("This GoblinScript is used to determine the DC for the saving throw to determine if the ability activates."),
						output = "boolean",
						examples = examples,
						subject = creature.helpSymbols,
						subjectDescription = "The creature the ability will trigger on",
						symbols = helpSymbols,
					},
				},
			}

			local savingThrowOptions = {
				{
					id = 'none',
					text = 'None',
				},
			}

			for i,attr in ipairs(creature.savingThrowIds) do
				savingThrowOptions[#savingThrowOptions+1] = {
					id = attr,
					text = creature.savingThrowInfo[attr].description,
				}
			end
			children[#children+1] = gui.Panel{
				classes = {'formPanel'},
				children = {
					gui.Label{
						text = 'Saving Throw:',
						classes = {'formLabel'},
					},
					gui.Dropdown{
						selfStyle = {
							height = 30,
							width = 260,
							fontSize = 16,
						},

						options = savingThrowOptions,
						idChosen = self.save,

						events = {
							change = function(element)
								self.save = element.idChosen
								savingThrowValuePanel:FireEvent("refresh")
							end,
						},
					},
				}
			}
			children[#children+1] = savingThrowValuePanel
		end

		children[#children+1] = self:BehaviorEditor()

		leftPanel.children = children
	end

	Refresh()

	local rightPanel = nil

	if not options.excludeAppearance then
		rightPanel = gui.Panel{
			id = "rightPanel",
			classes = "mainPanel",

			self:IconEditorPanel(),

			gui.Input{
				classes = "formInput",
				placeholderText = "Enter Ability Details...",
				multiline = true,
				width = "80%",
				height = "auto",
				halign = "center",
				margin = 8,
				minHeight = 100,
				textAlignment = "topleft",
				text = self.description,
				change = function(element)
					self.description = element.text
				end,
			},
		}
	end

	local resultPanel = gui.Panel{
		styles = {
			Styles.Form,
			{
				classes = {"formPanel"},
				width = 340,
			},
			{
				classes = {"formLabel"},
				halign = "left",
				valign = "center",
			},
			{
				classes = "mainPanel",
				width = "40%",
				height = "auto",
				flow = "vertical",
				valign = "top",
			},
		},
		
		height = "auto",
		width = "100%",
		valign = "top",
		flow = "horizontal",

		leftPanel,

		rightPanel,

	}
	return resultPanel
	
end

