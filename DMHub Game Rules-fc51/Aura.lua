local mod = dmhub.GetModLoading()


--objectid: string of the object that will be placed representing this aura.
RegisterGameType("Aura", "CharacterFeature")

Aura.TriggerConditions = {
	{
		id = "none",
		text = "Add a trigger...",
	},
	{
		id = "onenter",
		text = "When entering the aura",
	},
}

Aura.ApplyOptions = {
	{
		id = "all",
		text = "All Creatures",
	},
	{
		id = "allother",
		text = "All Other Creatures",
	},
	{
		id = "selfandfriends",
		text = "Friends, Including Self",
	},
	{
		id = "friends",
		text = "Friends, Excluding Self",
	},
	{
		id = "enemies",
		text = "Enemies",
	},
}

Aura.TriggerIdToCondition = {}
for i,cond in ipairs(Aura.TriggerConditions) do
	Aura.TriggerIdToCondition[cond.id] = cond
end

Aura.objectid = "none"
Aura.iconid = "ui-icons/skills/1.png"
Aura.canrelocate = false
Aura.relocateResource = "standardAction"
Aura.relocateRange = 30
Aura.triggers = {}
Aura.name = "Aura"
Aura.source = "Aura"
Aura.description = ""
Aura.applyto = "all"

function Aura.OnDeserialize(self)
	--we had to change id -> guid to match CharacterFeature.
	if self:has_key("guid") == false then
		self.guid = self:try_get("id")
	end

	self:get_or_add("display", { hueshift = 0, saturation = 1, brightness = 1, bgcolor = "#ffffffff" })
end

function Aura.Create(options)
	local args = {
		guid = dmhub.GenerateGuid(),
		modifiers = {},
		display = {
			hueshift = 0,
			saturation = 1,
			brightness = 1,
			bgcolor = "#ffffffff",
		},
	}

	for k,v in pairs(options or {}) do
		args[k] = v
	end

	local result = Aura.new(args)

	return result
end

--area: the area of the aura, a Shape type object.
RegisterGameType("AuraInstance")

function Aura:GenerateEditor(options)
	options = options or {}

	local resultPanel

	local objectChoices = {
		{
			id = "none",
			text = "Choose Object...",
		}
	}

	local objectAuraFolder = assets:GetObjectNode("auras");
	for i,auraObject in ipairs(objectAuraFolder.children) do
		if not auraObject.isfolder then
			objectChoices[#objectChoices+1] = {
				id = auraObject.id,
				text = auraObject.description,
			}
		end
	end

	local abilitiesPanel = gui.Panel{
		width = "100%",
		height = "auto",
		flow = "vertical",

		refreshAura = function(element)
			local abilityChildren = {}
			for i,trigger in ipairs(self.triggers) do
				abilityChildren[#abilityChildren+1] = gui.Panel{
					width = "100%",
					height = "auto",
					flow = "vertical",

					gui.Panel{
						height = 20,
						width = "100%",
						flow = "horizontal",
						halign = "left",
						gui.Label{
							halign = "left",
							text = Aura.TriggerIdToCondition[trigger.trigger].text,
							fontSize = 18,
							bold = true,
							width = "auto",
							height = "auto",
						},
						gui.DeleteItemButton{
							width = 16,
							height = 16,
							hmargin = 20,
							halign = "left",
							valign = "center",
							click = function(element)
								table.remove(self.triggers, i)
								resultPanel:FireEventTree("refreshAura")
							end,
						},
					},

					trigger.ability:GenerateEditor{
						--the triggers don't have a trigger condition set because that is implied
						--by the way the creature interacts with the aura. They don't have activation
						--saving throws either, since that is for 'good' triggers to see if they are activated.
						--The normal saving throws are controlled by the behavior which will be added to the trigger.
						excludeTriggerCondition = true,
						excludeActivationSavingThrows = true,
						excludeAppearance = true,
					}
				}
				
			end

			abilityChildren[#abilityChildren+1] = gui.Dropdown{
				classes = "formDropdown",
				idChosen = "none",
				options = Aura.TriggerConditions,
				halign = "left",
				valign = "top",
				change = function(element)
					if #self.triggers == 0 then
						--make sure we have unique triggers.
						self.triggers = {}
					end

					self.triggers[#self.triggers+1] = {
						trigger = element.idChosen,
						ability = TriggeredAbility.Create{
							name = "Aura Trigger",
							targetType = 'self',
							range = 5,
							radius = 0,
							silent = true,
						},
					}
					resultPanel:FireEventTree("refreshAura")
				end,
			}

			element.children = abilityChildren
		end,

	}

	resultPanel = gui.Panel{
		classes = "abilityEditor",
		styles = {
			Styles.Form,

			{
				classes = {"formPanel"},
				halign = "left",
				width = 340,
			},
			{
				classes = {"formLabel"},
				halign = "left",
			},
			{
				classes = {"abilityEditor"},
				width = '100%',
				height = 'auto',
				flow = "horizontal",
				valign = "top",
			},
			{
				classes = "mainPanel",
				width = "90%",
				height = "auto",
				flow = "vertical",
				valign = "top",
			},

		},

		gui.Panel{
			id = "leftPanel",
			classes = "mainPanel",

			ActivatedAbility.IconEditorPanel(self),

			gui.Panel{
				classes = "formPanel",
				gui.Label{
					classes = "formLabel",
					text = "Object:",
				},
				gui.Dropdown{
					classes = "formDropdown",
					options = objectChoices,
					idChosen = self.objectid,
					change = function(element)
						self.objectid = element.idChosen
					end,
				},
			},

			gui.Panel{
				classes = "formPanel",
				gui.Label{
					classes = "formLabel",
					text = "Apply To:",
				},
				gui.Dropdown{
					classes = "formDropdown",
					options = Aura.ApplyOptions,
					idChosen = self.applyto,
					change = function(element)
						self.applyto = element.idChosen
					end,
				},
			},

			gui.Check{
				halign = "left",
				text = "Makes Terrain Difficult",
				value = self:try_get("difficult_terrain", false),
				change = function(element)
					self.difficult_terrain = element.value
					resultPanel:FireEventTree("refreshAura")
				end,
			},

			CharacterFeature.EditorPanel(self, {
				halign = "left",
				noscroll = true,
				height = "auto",
			}),

			gui.Check{
				classes = {cond(options.norelocate, 'collapsed')},
				text = "Can relocate",
				value = self.canrelocate,
				change = function(element)
					self.canrelocate = element.value
					resultPanel:FireEventTree("refreshAura")
				end,
			},

			gui.Panel{
				classes = {"formPanel", cond(self.canrelocate, nil, 'hidden'), cond(options.norelocate, 'collapsed')},
				refreshAura = function(element)
					element:SetClass("hidden", not self.canrelocate)
				end,
				gui.Label{
					classes = "formLabel",
					text = "Relocate Action:",
				},
				gui.Dropdown{
					classes = "formDropdown",
					options = CharacterResource.GetActionOptions(),
					idChosen = self.relocateResource,
					change = function(element)
						self.relocateResource = element.idChosen
					end,
				},
			},

			gui.Panel{
				classes = {"formPanel", cond(self.canrelocate, nil, 'hidden'), cond(options.norelocate, 'collapsed')},
				refreshAura = function(element)
					element:SetClass("hidden", not self.canrelocate)
				end,
				gui.Label{
					classes = "formLabel",
					text = "Relocate Range:",
				},
				gui.Input{
					classes = "formInput",
					text = tostring(self.relocateRange or 0),
					change = function(element)
						self.relocateRange = tonumber(element.text) or self.relocateRange
					end,
				},
			},

			abilitiesPanel,
		},


	}

	resultPanel:FireEventTree("refreshAura")

	return resultPanel
	
end

function Aura:ShowEditDialog(options)
	options = options or {}
	local aura = self

	local dialogWidth = 1200
	local dialogHeight = 980

	local resultPanel = nil

	local mainFormPanel = gui.Panel{
		style = {
			bgcolor = 'white',
			pad = 0,
			margin = 0,
			width = 1060,
			height = 840,
		},
		vscroll = true,
	}

	local newItem = nil

	local closePanel = 
		gui.Panel{
			style = {
				valign = 'bottom',
				flow = 'horizontal',
				height = 60,
				width = '100%',
				fontSize = '60%',
				vmargin = 0,
			},

			children = {
				gui.PrettyButton{
					text = 'Close',
					style = {
						height = 60,
						width = 160,
						fontSize = 44,
						bgcolor = 'white',
					},
					events = {
						click = function(element)
							resultPanel.data.close()
						end,
					},
				},
			},
		}

	local titleLabel = gui.Label{
		text = "Edit Aura",
		valign = 'top',
		halign = 'center',
		width = 'auto',
		height = 'auto',
		color = 'white',
		fontSize = 28,
	}

	resultPanel = gui.Panel{
		style = {
			bgcolor = 'white',
			width = dialogWidth,
			height = dialogHeight,
			halign = 'center',
			valign = 'center',
		},

		classes = {"framedPanel"},
		styles = Styles.Panel,

		floating = true,

		captureEscape = true,
		escapePriority = EscapePriority.EXIT_MODAL_DIALOG,
		escape = function(element)
			element.data.close()
		end,

		data = {
			show = function(editItem)
				newItem = nil

				mainFormPanel.children = {
					editItem:GenerateEditor(options),
				}

			end,
			close = function()
				resultPanel:DestroySelf()
			end,
		},

		children = {

			gui.Panel{
				id = 'content',
				style = {
					halign = 'center',
					valign = 'center',
					width = '94%',
					height = '94%',
					flow = 'vertical',
				},
				children = {
					titleLabel,
					mainFormPanel,
					closePanel,

				},
			},
		},
	}

	resultPanel.data.show(aura)

	return resultPanel
end

AuraInstance.lookupSymbols = {
	datatype = function(c)
		return "aura"
	end,
	debuginfo = function(c)
		return "aura"
	end,
	caster = function(c)
		local token = dmhub.GetTokenById(c.casterid)
		if token == nil then
			return nil
		end

		return token.properties
	end,
}

AuraInstance.helpSymbols = {
	__name = "aura",
	__sampleFields = {"caster"},
	caster = {
		name = "Caster",
		type = "creature",
		desc = "The creature that controls this aura.",
		seealso = {},
	},
}


--get symbols for a triggered event. Includes this aura as the 'aura' key.
function AuraInstance:GetSymbolsForTrigger(targetCreature)
	local result = dmhub.DeepCopy(self.symbols or {})
	result.aura = GenerateSymbols(self)

	if targetCreature ~= nil then
		result.target = GenerateSymbols(targetCreature)
	end
	return result
end

function AuraInstance:FireTriggeredAbility(ability, castingCreature, targetToken)
	ability = self:PopulateTriggeredAbility(ability)
	local temporaryModifier = self:CreateTemporaryModifier(castingCreature)
	local symbols = self:GetSymbolsForTrigger(castingCreature)

	printf("ZZZ: FireTriggeredAbility: %s", json(ability:try_get("spellcastingFeature")))

	ability:Trigger(temporaryModifier, castingCreature, symbols, targetToken)
end

--creates a temporary triggered ability copy and populates it with our spellcasting feature making it ready to use.
function AuraInstance:PopulateTriggeredAbility(triggeredAbility)
	triggeredAbility = DeepCopy(triggeredAbility)

	if self:has_key("spellcastingFeature") then
		triggeredAbility.spellcastingFeature = self.spellcastingFeature
	end

	return triggeredAbility
end

--create a character modifier from this aura instance, used for triggers.
function AuraInstance:CreateTemporaryModifier(creature)
	return CharacterModifier.new{
		guid = dmhub.GenerateGuid(),
		behavior = "none",
		name = self.name,
		source = self.name,
		description = "",
	}
end

function AuraInstance:DestroyAura(creature)
	if self:has_key("object") then
		local objectInstance = game.LookupObject(self.object.floorid, self.object.objid)
		if objectInstance ~= nil then
			objectInstance:Destroy()
		end
	end
end

function AuraInstance:HasExpired()
	return self:has_key("duration") and self.time:RoundsSince() >= self.duration
end

--this is called by DMHub to get the locs an aura fills.
function AuraInstance:GetArea()
	return self:try_get("area")
end

function AuraInstance:GetApplyTo()
	return self.aura.applyto
end

function AuraInstance:GetDifficultTerrain()
	return self.aura:try_get("difficult_terrain", false)
end

function AuraInstance:FillActivatedAbilities(creature, resultAbilities)
	if self.aura.canrelocate and self:GetArea() ~= nil then
		local area = self:GetArea()

		printf("MoveAura: Create: %s", json(self:try_get("object")))

		resultAbilities[#resultAbilities+1] = ActivatedAbility.Create{
			name = string.format("Move %s", self.name),
			auraid = self.guid,
			iconid = self.iconid,
			casterLocOverride = self.area.origin,
			display = self.display,
			targetType = area.shape,
			range = self.aura.relocateRange,
			radius = area.radius,
			actionResourceId = self.aura.relocateResource,
			behaviors = {
				ActivatedAbilityMoveAuraBehavior.new{
					object = self:try_get("object")
				},
			},
		}

	end
end

function AuraInstance:GetModifiers()
	if self:try_get("_tmp_refresh") ~= dmhub.ngameupdate then
		self._tmp_refresh = dmhub.ngameupdate
		local caster = nil
		local tok = dmhub.GetTokenById(self.casterid)
		if tok ~= nil then
			caster = tok.properties
		end
		for _,mod in ipairs(self.aura.modifiers) do
			mod:SetSymbols{
				aura = self,
				caster = caster,
			}
		end
	end

	return self.aura.modifiers
end

--the object attached to an aura component object.
RegisterGameType("AuraComponent")

function AuraComponent:Destroy()
	local tok = dmhub.GetTokenById(self.casterid)
	if tok ~= nil and tok.properties ~= nil then
		tok:ModifyProperties{
			description = "Remove Aura",
			execute = function()
				tok.properties:RemoveAura(self.auraid)
			end,
		}
	end
end

function AuraComponent.CreatePropertiesEditor(component)
	local self = component.properties
	if self:has_key("aura") == false then
		return nil
	end
	return gui.Panel{
		width = "auto",
		height = "auto",
		flow = "vertical",

		gui.CreateTokenImage(dmhub.GetTokenById(self.aura:try_get("casterid")), {
			styles = {
				{
					flow = "none",
				}
			},
			width = 64,
			height = 64,
			halign = "left",
			valign = "top",
		}),

		gui.Panel{
			classes = {"field-editor-panel"},
			gui.Label{
				text = "Radius:",
				valign = "center",
				classes = {"field-description-label"},
				hmargin = 4,
			},

			gui.Input{
				width = 40,
				characterLimit = 4,
				halign = "right",
				valign = "center",
				text = tostring(self.aura.area.radius),
				thinkTime = 0.2,
				think = function(element)
					if element.hasInputFocus then
						return
					end

					local text = tostring(self.aura.area.radius)
					if text ~= element.text then
						element.text = text
					end
				end,
				change = function(element)
					component:BeginChanges()
					self.aura.area.radius = tonumber(element.text)
					element.text = tostring(self.aura.area.radius)
					component:CompleteChanges("Change radius")
				end,
			},
		},

		gui.Button{
			width = 100,
			height = 24,
			fontSize = 16,
			text = "Edit Aura",
			click = function(element)
				element.root:AddChild(self.aura.aura:ShowEditDialog{})
			end,
		}
	}
end

function ActivatedAbilityAuraBehavior:Cast(ability, casterToken, targets, options)
	if options.targetArea ~= nil then
		local symbols = dmhub.DeepCopy(options.symbols or {})
		local targetLoc = options.targetArea.origin
		local targetFloor = game.currentMap:GetFloorFromLoc(targetLoc)
		if targetFloor ~= nil then
			local guid = dmhub.GenerateGuid()
			printf("ZZZ: CAST AURA: %s", json(ability:try_get("spellcastingFeature")))
			local auraInstance = AuraInstance.new{
				guid = guid,
				spellcastingFeature = ability:try_get("spellcastingFeature"),
				casterid = casterToken.id,
				iconid = ability.iconid,
				name = ability.name,
				display = ability.display,
				area = options.targetArea,
				time = TimePoint.Create(),
				duration = ability:GetDurationInRounds(),
				symbols = options.symbols,
				aura = dmhub.DeepCopy(self.aura),
			}

			local obj = nil
			if self.aura.objectid ~= nil then
				obj = targetFloor:SpawnObjectLocal(self.aura.objectid)
				if obj ~= nil then

					auraInstance.object = {
						floorid = obj.floorid,
						objid = obj.objid,
					}
					obj:AddComponentFromJson("AURA", {
						["@class"] = "ObjectComponentAura",
						properties = AuraComponent.new{
							casterid = casterToken.id,
							auraid = guid,
							aura = auraInstance,
						},
					})
					obj.x = options.targetArea.xpos
					obj.y = options.targetArea.ypos
					--obj.x = targetLoc.x-0.5
					--obj.y = targetLoc.y-0.5
					obj:Upload()
				end
			end


			if ability:RequiresConcentration() and casterToken.properties:HasConcentration() and obj ~= nil then
				casterToken:ModifyProperties{
					description = "Add Aura",
					execute = function()
						local concentration = casterToken.properties:MostRecentConcentration()
						local objects = concentration:get_or_add("objects", {})
						objects[#objects+1] = {
							floorid = obj.floorid,
							objid = obj.objid,
						}
					end
				}
			end

			options.pay = true
		end
	end
end

function creature:AddAura(auraInstance)
	local auras = self:get_or_add("auras", {})
	auras[#auras+1] = auraInstance
end

function creature:RemoveAura(auraid)
	local auras = self:try_get("auras", {})
	for i,aura in ipairs(auras) do
		if aura.guid == auraid then
			aura:DestroyAura(self)
			table.remove(auras, i)
			return
		end
	end
end

function creature:GetAura(auraid)
	local auras = self:try_get("auras", {})
	for i,aura in ipairs(auras) do
		if aura.guid == auraid then
			return aura
		end
	end
end

function ActivatedAbilityMoveAuraBehavior:Cast(ability, casterToken, targets, options)
	printf("MoveAura: casting...")
	if options.targetArea == nil or self:try_get("object") == nil then
		printf("MoveAura: abort")
		return
	end

	local obj = game.LookupObject(self.object.floorid, self.object.objid)
	if obj == nil then
		printf("MoveAura: abort no obj")
		return
	end

	local targetLoc = options.targetArea.origin

	dmhub.BeginTransaction()

	local destx = targetLoc.x - 0.5
	local desty = targetLoc.y - 0.5

	local objAura = obj:GetComponent("Aura")
	if objAura ~= nil then
		objAura:SetAndUploadProperties{
			moveTimestamp = dmhub.serverTime,
			movex = destx - obj.x,
			movey = desty - obj.y,
		}
	end

	obj:SetAndUploadPos(targetLoc.x - 0.5, targetLoc.y - 0.5)
		printf("MoveAura: set pos: %s %s", json(targetLoc.x), json(targetLoc.y))

	dmhub.EndTransaction()

	ability:ConsumeResources(casterToken, {
		costOverride = options.costOverride,
	})
end

function CreateAuraTooltip(auraInstance)
	local aura = auraInstance.aura

	return gui.Panel{
		styles = SpellRenderStyles,

		pad = 12,
		bgimage = "panels/square.png",
		bgcolor = "black",
		borderWidth = 2,
		borderColor = "white",
		width = 400,


		id = "spellInfo",
		gui.Label{
			id = "spellName",
			text = aura.name,
		},

		gui.Panel{
			classes = "divider",
		},

		gui.Panel{
			bgimage = aura.iconid,
			classes = "icon",
			selfStyle = aura.display,
		},

		gui.Label{
			text = aura.description,
			classes = "description",
		},
	}
end
