local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityInvokeAbilityBehavior", "ActivatedAbilityBehavior")

RegisterGameType("AbilityInvocation")

AbilityUtils = {
	--utility to scan an ability for e.g. <<range>> and extract all parameters.
	ExtractAbilityParameters = function(node, output)
		if type(node) ~= "table" then
			return
		end

		for k,v in pairs(node) do
			if type(v) == "string" then
				local s = v

				for count=1,8 do
					local match = regex.MatchGroups(s, "^.*?<<(?<name>[a-zA-Z_]+)>>(?<tail>.*)$")
					if match == nil then
						break
					end

					output[match.name] = true
					s = match.tail
				end

			elseif type(v) == "table" then
				AbilityUtils.ExtractAbilityParameters(v, output)
			end
		end
	end,

	DeepReplaceAbility = function(node, from, to)
		if type(node) ~= "table" then
			return
		end

		for k,v in pairs(node) do
			if v == from then
				node[k] = to
			elseif type(v) == "string" then
				node[k] = regex.ReplaceAll(v, from, to)
			else
				AbilityUtils.DeepReplaceAbility(v, from, to)
			end
		end
	end,

	--utility to scan for an <<expression>> in a string and evaluate it as goblin script.
	--Useful to evaluate in the context of the caster.
	SubstituteAbilityParameters = function(str, caster)
		local result = ""
		for i=1,8 do
			local match = regex.MatchGroups(str, "^(?<head>.*)?<<(?<expression>.*?)>>(?<tail>.*)$")
			if match == nil then
				result = result .. str
				break
			end

			result = result .. match.head

			result = result .. dmhub.EvalGoblinScript(match.expression, caster:LookupSymbol(), "Substitute parameter in invocation")

			str = match.tail
		end

		return result
	end,
}



ActivatedAbility.RegisterType
{
	id = 'invoke_ability',
	text = 'Invoke Ability',
	createBehavior = function()
		local customAbility = ActivatedAbility.Create()
		customAbility.name = "Invoked Ability"
		return ActivatedAbilityInvokeAbilityBehavior.new{
			customAbility = customAbility,
		}
	end,
}

ActivatedAbilityInvokeAbilityBehavior.summary = 'Invoke Ability'
ActivatedAbilityInvokeAbilityBehavior.promptText = ''

ActivatedAbilityInvokeAbilityBehavior.runOnController = false


function ActivatedAbilityInvokeAbilityBehavior:Cast(ability, casterToken, targets, options)
    for i,target in ipairs(targets) do
        if target.token ~= nil then

			local symbols = { upcast = options.symbols.upcast, charges = options.symbols.charges, cast = options.symbols.cast }

			if self.runOnController and target.token.activeControllerId ~= nil and self.abilityType ~= "custom" then

				--dispatch this to run on the controller.
				local invocation = AbilityInvocation.new{
					timestamp = ServerTimestamp(),
					userid = target.token.activeControllerId,
					abilityType = self.abilityType,
					namedAbility = self.namedAbility,
					standardAbility = self.standardAbility,
					targeting = self.targeting,
					invokerid = casterToken.id,
					casterid = target.token.id,
					symbols = symbols,
					abilityAttr = {
						promptOverride = cond(self.promptText ~= "", self.promptText),
					}
				}

				target.token:ModifyProperties{
					description = "Invoke Ability",
					undoable = false,
					execute = function()
						local invokes = target.token.properties:get_or_add("remoteInvokes", {})
						invokes[#invokes+1] = invocation
					end,
				}

			else

				local abilityTemplate = nil
				if self.abilityType == "named" then
					local abilities = target.token.properties:GetActivatedAbilities{allLoadouts = true, bindCaster = true}
					for _,ability in ipairs(abilities) do
						if string.lower(ability.name) == string.lower(self.namedAbility) then
							abilityTemplate = ability
							break
						end
					end
				elseif self.abilityType == "custom" then
					abilityTemplate = self.customAbility
				elseif self.abilityType == "standard" then
					local t = dmhub.GetTable("standardAbilities") or {}
					abilityTemplate = t[self.standardAbility]
				end

				if abilityTemplate ~= nil then
					local abilityClone = abilityTemplate:MakeTemporaryClone()

					if self.abilityType == "standard" then
						for k,v in pairs(self:try_get("standardAbilityParams", {})) do
							local str = AbilityUtils.SubstituteAbilityParameters(v, casterToken.properties)
							AbilityUtils.DeepReplaceAbility(abilityClone, "<<"..k..">>", str)
						end
					end

					abilityClone.invoker = ability:try_get("invoker") or casterToken.properties

					if self.inheritRange then
						abilityClone.range = ability.range
					end

					if self.promptText ~= "" then
						abilityClone.promptOverride = self.promptText
					end

					self.ExecuteInvoke(casterToken, abilityClone, target.token, self.targeting, symbols, options)
				end
			end

		end
	end
end

function ActivatedAbilityInvokeAbilityBehavior.ExecuteInvoke(invokerToken, abilityClone, casterToken, targeting, symbols, options)
	local casting = false


	symbols.invoker = symbols.invoker or GenerateSymbols(invokerToken.properties)

	abilityClone.invoker = invokerToken.properties

	abilityClone.OnBeginCast = function()
		casting = true
	end

	abilityClone.OnFinishCast = function()
		casting = false
		options.pay = true
	end

	if targeting == "prompt" then
		gamehud.actionBarPanel:FireEventTree("invokeAbility", casterToken, abilityClone, symbols)
	else
		local targets = { { token = casterToken } }
		abilityClone:Cast(casterToken, targets, {
			symbols = symbols,
		})
	end

	while casting or gamehud.actionBarPanel.data.IsCastingSpell() do
		coroutine.yield(0.1)
	end


end

ActivatedAbilityInvokeAbilityBehavior.abilityType = "custom"
ActivatedAbilityInvokeAbilityBehavior.namedAbility = ""
ActivatedAbilityInvokeAbilityBehavior.standardAbility = ""
ActivatedAbilityInvokeAbilityBehavior.targeting = "prompt"
ActivatedAbilityInvokeAbilityBehavior.inheritRange = false

function ActivatedAbilityInvokeAbilityBehavior:EditorItems(parentPanel)

	local result = {}
	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

	result[#result+1] = gui.Panel{
		classes = {"formPanel"},
		gui.Label{
			classes = {"formLabel"},
			text = "Prompt Text:",
		},
		gui.Input{
			classes = {"formInput"},
			text = self.promptText,
			change = function(element)
				self.promptText = element.text
			end,
		}
	}

	result[#result+1] = gui.Panel{
		classes = {"formPanel"},
		gui.Label{
			classes = {"formLabel"},
			text = "Type:",
		},
		gui.Dropdown{
			options = {
				{ text = "Custom Ability", id = "custom" },
				{ text = "Named Ability", id = "named" },
				cond(dmhub.GetTable("standardAbilities") ~= nil, { text = "Standard Ability", id = "standard" } ),
			},
			idChosen = self.abilityType,
			change = function(element)
				self.abilityType = element.idChosen
				parentPanel:FireEventTree("refreshInvoke")
			end,
		}
	}
	
	result[#result+1] = gui.Check{
		classes = {cond(self.abilityType == "custom", "collapsed-anim")},
		text = "Target Player Casts",
		value = self.runOnController,
		change = function(element)
			self.runOnController = element.value
		end,
		refreshInvoke = function(element)
			element:SetClass("collapsed-anim", self.abilityType == "custom")
		end,
	}

	result[#result+1] = gui.PrettyButton{
		width = 200,
		height = 50,
		text = "Edit Ability",
		create = function(element)
			element:SetClass("collapsed", self.abilityType ~= "custom")
		end,
		refreshInvoke = function(element)
			element:FireEventTree("create")
		end,
		click = function(element)
			element.root:AddChild(self.customAbility:ShowEditActivatedAbilityDialog())
		end,
	}

	result[#result+1] = gui.Panel{
		classes = {"formPanel"},
		create = function(element)
			element:SetClass("collapsed", self.abilityType ~= "named")
		end,
		refreshInvoke = function(element)
			element:FireEventTree("create")
		end,
		gui.Label{
			classes = {"formLabel"},
			text = "Ability Name:",
		},
		gui.Input{
			classes = {"formInput"},
			text = self.namedAbility,
			change = function(element)
				self.namedAbility = element.text
			end,
		},
	}

	local standardAbilities = {}
	for k,v in pairs(dmhub.GetTable("standardAbilities") or {}) do
		standardAbilities[#standardAbilities+1] = { text = v.name, id = k }
	end

	result[#result+1] = gui.Panel{
		classes = {"formPanel"},
		create = function(element)
			element:SetClass("collapsed", self.abilityType ~= "standard")
		end,
		refreshInvoke = function(element)
			element:FireEventTree("create")
		end,
		gui.Label{
			classes = {"formLabel"},
			text = "Ability:",
		},
		gui.Dropdown{
			sort = true,
			idChosen = self.standardAbility,
			options = standardAbilities,
			change = function(element)
				self.standardAbility = element.idChosen
				parentPanel:FireEventTree("refreshInvoke")
			end,
		},
	}

	result[#result+1] = gui.Panel{
		width = "100%",
		height = "auto",
		flow = "vertical",
		data = {
			abilityTypeCached = nil,
		},
		create = function(element)
			element:SetClass("collapsed", self.abilityType ~= "standard")

			if self.abilityType ~= "standard" or element.data.abilityTypeCached == self.standardAbility then
				element.children = {}
				return
			end

			element.data.abilityTypeCached = self.standardAbility

			local t = dmhub.GetTable("standardAbilities") or {}
			local abilityTemplate = t[self.standardAbility]

			if abilityTemplate == nil then
				print("Error: Could not find ability template:", self.standardAbility)
				return
			end

			local parameters = {}
			AbilityUtils.ExtractAbilityParameters(abilityTemplate, parameters)

			local children = {}

			for k,v in pairs(parameters) do
				children[#children+1] = gui.Panel{
					classes = {"formPanel"},
					gui.Label{
						classes = {"formLabel"},
						text = k,
					},
					gui.Input{
						classes = {"formInput"},
						text = self:try_get("standardAbilityParams", {})[k] or "",
						change = function(element)
							local t = self:get_or_add("standardAbilityParams", {})
							t[k] = element.text
						end,
					},
				}
			end

			element.children = children
		end,
		refreshInvoke = function(element)
			element:FireEventTree("create")
		end,
	}

	result[#result+1] = gui.Panel{
		classes = {"formPanel"},
		gui.Label{
			classes = {"formLabel"},
			text = "Targeting:",
		},
		gui.Dropdown{
			options = {
				{ text = "Prompt Player", id = "prompt" },
				{ text = "Self", id = "self" },
			},
			idChosen = self.targeting,
			change = function(element)
				self.targeting = element.idChosen
			end,
		}
	}

	result[#result+1] = gui.Check{
		text = "Inherit Range",
		value = self.inheritRange,
		change = function(element)
			self.inheritRange = element.value
		end,
	}

	return result

end

AbilityInvocation.timestamp = 0
AbilityInvocation.abilityType = "named"
AbilityInvocation.abilityid = "none"
AbilityInvocation.targeting = "prompt"
AbilityInvocation.invokerid = "none"
AbilityInvocation.casterid = "none"

--must be executed from within a co-routine.
function AbilityInvocation:Invoke()
	local invokerToken = dmhub.GetTokenById(self.invokerid)
	local casterToken = dmhub.GetTokenById(self.casterid)

	if invokerToken == nil or casterToken == nil then
		return false
	end

	local abilityTemplate = nil
	if self.abilityType == "named" then
		local abilities = casterToken.properties:GetActivatedAbilities{allLoadouts = true, bindCaster = true}
		for _,ability in ipairs(abilities) do
			if string.lower(ability.name) == string.lower(self.namedAbility) then
				abilityTemplate = ability
				break
			end
		end
	elseif self.abilityType == "standard" then
		local t = dmhub.GetTable("standardAbilities") or {}
		abilityTemplate = t[self.standardAbility]

	end

	if abilityTemplate == nil then
		return false
	end

	local abilityClone = abilityTemplate:MakeTemporaryClone()
	if self.abilityType == "standard" then
		for k,v in pairs(self:try_get("standardAbilityParams", {})) do
			local str = AbilityUtils.SubstituteAbilityParameters(v, invokerToken.properties)
			AbilityUtils.DeepReplaceAbility(abilityClone, "<<"..k..">>", src)
		end
	end

	for k,v in pairs(self:try_get("abilityAttr", {})) do
		abilityClone[k] = v
	end

	local options = {}
	print("RemoteInvoke: Execute")
	ActivatedAbilityInvokeAbilityBehavior.ExecuteInvoke(invokerToken, abilityClone, casterToken, self.targeting, self.symbols, options)
	return true
end