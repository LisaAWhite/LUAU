local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityRelocateCreatureBehavior", "ActivatedAbilityBehavior")


ActivatedAbility.RegisterType
{
	id = 'relocate_creature',
	text = 'Relocate Creature',
	createBehavior = function()
		return ActivatedAbilityRelocateCreatureBehavior.new{
		}
	end
}

ActivatedAbilityRelocateCreatureBehavior.summary = 'Relocate Creatures'
ActivatedAbilityRelocateCreatureBehavior.swapCreatures = false
ActivatedAbilityRelocateCreatureBehavior.movementType = "teleport"

function ActivatedAbilityRelocateCreatureBehavior:Cast(ability, casterToken, targets, options)
    if #targets > 0 then

		local swapTokens = nil
		if self.swapCreatures then
			swapTokens = game.GetTokensAtLoc(targets[1].loc)
			if swapTokens ~= nil and ability.targetType == 'emptyspacefriend' and (not casterToken:IsFriend(swapTokens[1])) then
				--can only swap with friends.
				swapTokens = nil
			end
		end

		if swapTokens ~= nil then
			casterToken:SwapPositions(swapTokens[1])
		elseif self.movementType == "teleport" then
        	casterToken:Teleport(targets[1].loc)
		else
			local collisionInfo = nil
			if ability.targeting == "straightline" then
				local movementInfo = casterToken:MarkMovementArrow(targets[1].loc, {straightline = true})
				if movementInfo ~= nil then

					local loc = targets[1].loc

					local path = movementInfo.path
					local abilityDist = ability:GetRange(casterToken.properties)/dmhub.unitsPerSquare
					local requestDist = math.min(loc:DistanceInTiles(path.origin), abilityDist)
					local pathDist = path.destination:DistanceInTiles(path.origin)

					if pathDist < requestDist then
						local overshoot = abilityDist - pathDist

						collisionInfo = {
							speed = overshoot,
							collideWith = movementInfo.collideWith,
						}
					end

				end

				casterToken:ClearMovementArrow()
			end

            if ability.targeting == "straightline" and self.movementType == "move" then
                casterToken.properties:DispatchEvent("forcemove")
            elseif self.movementType == "teleport" then
                casterToken.properties:DispatchEvent("teleport")
            end

			local path = casterToken:Move(targets[1].loc, { straightline = (ability.targeting == "straightline" or ability.targeting == "straightpath"), moveThroughFriends = (ability.targeting ~= "straightline"), maxCost = 30000, movementType = self.movementType })

			if path ~= nil then
				options.symbols.cast.spacesMoved = options.symbols.cast.spacesMoved + path.numSteps
			end

			if collisionInfo ~= nil then
				casterToken.properties:TriggerEvent("collide", {
					speed = collisionInfo.speed,
				})

				for _,tok in ipairs(collisionInfo.collideWith, {}) do
					tok.properties:TriggerEvent("collide", {
						speed = collisionInfo.speed,
					})
				end
			end
		end

        options.pay = true
    end
end

function ActivatedAbilityRelocateCreatureBehavior:EditorItems(parentPanel)
	local result = {}
	--self:ApplyToEditor(parentPanel, result)
	--self:FilterEditor(parentPanel, result)

	result[#result+1] = gui.Panel{
		classes = {"formPanel"},
		gui.Label{
			classes = "formLabel",
			text = "Movement:",
		},

		gui.Dropdown{
			classes = "formDropdown",
			options = {
				{id = "teleport", text = "Teleport"},
				{id = "move", text = "Move"},
				{id = "shift", text = "Shift"},
			},
			idChosen = self.movementType,
			change = function(element)
				self.movementType = element.idChosen
			end,
		},
	}

	result[#result+1] = gui.Check{
		text = "Swap Creatures",
		value = self.swapCreatures,
		change = function(element)
			self.swapCreatures = element.value
		end,
	}

	return result
end
