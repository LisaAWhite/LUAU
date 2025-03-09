local mod = dmhub.GetModLoading()

--functions called by dmhud to indicate that a token is moving or has finished moving.
function GameHud.TokenMoving(self, token, path)
	
	local diagonals = dmhub.GetSettingValue("truediagonals") and math.floor(path.numDiagonals/2) or 0

	local distance = path.numSteps + diagonals
	distance = distance * dmhub.FeetPerTile

    local forcedText = ""

    if path.forced then
        forcedText = "Forced "
    end

	local text = string.format('%sMovement: %s %s', forcedText, MeasurementSystem.NativeToDisplayString(distance), string.lower(MeasurementSystem.UnitName()))

    local altitudeDelta = path.destination.altitude - path.origin.altitude
    if altitudeDelta < 0 then
        text = string.format("%s (%d elevation)", text, round(altitudeDelta))
    elseif altitudeDelta > 0 then
        text = string.format("%s (+%d elevation)", text, round(altitudeDelta))
    end

    if path.forced then
        if path.collisionSpeed > 0 then
            text = string.format("%s\n<color=#ff0000>Pushing %d tiles, inflicting %d damage.</color>", text, path.forcedMovementTotalDistance, path.collisionSpeed)
        end

        if token.properties:ForcedMoveResistance() > 0 then
            text = string.format("%s\nNote: This creature has <b>%d stability</b>", text, token.properties:ForcedMoveResistance())
        end
    end

	local walkAndSwim = false

	if token.properties ~= nil then
		if path.mount then
			text = string.format("%s\nMounting or dismounting takes half of movement for the round.", text)
		end

		local moveType = token.properties:CurrentMoveType()
		if moveType == "walk" or moveType == "swim" then

			local waterSteps = math.floor(path.waterSteps) * dmhub.FeetPerTile
			if waterSteps > 0 and waterSteps < distance then
				text = string.format("%s; swim %s %s", text, MeasurementSystem.NativeToDisplayString(waterSteps), string.lower(MeasurementSystem.UnitName()))
				walkAndSwim = true
			end

			local difficultDistance = math.floor(path.difficultSteps) * dmhub.FeetPerTile
			if difficultDistance == distance and distance > 0 then
				text = string.format("%s; all in difficult terrain", text)
			elseif difficultDistance > 0 then
				text = string.format("%s; %s %s in difficult terrain", text, MeasurementSystem.NativeToDisplayString(difficultDistance), string.lower(MeasurementSystem.UnitName()))
			end

			local squeezeDistance = math.floor(path.squeezeSteps) * dmhub.FeetPerTile
			if squeezeDistance == distance and distance > 0 then
				text = string.format("%s; squeezing through a tight space", text)
			elseif squeezeDistance > 0 then
				text = string.format("%s; %s %s squeezing through tight spaces", text, MeasurementSystem.NativeToDisplayString(squeezeDistance), string.lower(MeasurementSystem.UnitName()))
			end
		end
	end

	if path.teleport then
        local distance = path.origin:DistanceInTiles(path.destination)
		text = string.format('Teleport: %d %s', distance, string.lower(MeasurementSystem.UnitName()))
	end

	local floorDelta = nil

	if path.destination.floor ~= token.loc.floor then
		local diff = token.loc:FloorDifference(path.destination)
		floorDelta = diff
		if diff == 1 then
			text = text .. ' (+1 Floor)'
		elseif diff == -1 then
			text = text .. ' (-1 Floor)'
		else
			local prefix = '+'
			if diff < 0 then
				prefix = '-'
				diff = -diff
			end

			text = text .. ' (' .. prefix .. tostring(diff) .. ' Floors)'
		end
	end

	local creature = token.properties
	if creature ~= nil and (not path.teleport) and (not path.forced) then
		text = string.format('%s\n%s %s %s %s per round', text, creature.GetTokenDescription(token), string.lower(creature:CurrentMoveTypeInfo().tense), MeasurementSystem.NativeToDisplayString(creature:GetEffectiveSpeed(creature:CurrentMoveType())), string.lower(MeasurementSystem.UnitName()))

		if walkAndSwim then
			local otherMode = "walk"
			if creature:CurrentMoveType() == "walk" then
				otherMode = "swim"
			end

			text = string.format("%s\n%s %s %s %s per round", text, creature.GetTokenDescription(token), string.lower(creature.movementTypeById[otherMode].tense), MeasurementSystem.NativeToDisplayString(creature:GetEffectiveSpeed(otherMode)), string.lower(MeasurementSystem.UnitName()))
		end

		local distMoved = creature:DistanceMovedThisTurn()
		if distMoved > 0 then
			text = string.format("%s\nAlready moved %s %s this turn.", text, MeasurementSystem.NativeToDisplayString(distMoved*dmhub.FeetPerTile), string.lower(MeasurementSystem.UnitName()))
		end
	end

    local hazards = path:CalculateHazards(token)
    if hazards ~= nil then
        local damageHazards = {}
        for _,hazard in ipairs(hazards) do
            if hazard.type == "damage" then
                local found = false

                for _,existing in ipairs(damageHazards) do
                    if existing.type == hazard.damageType and existing.name == hazard.aura.name then
                        existing.damage = existing.damage + hazard.damageAmount
                        found = true
                        break
                    end
                end

                if not found then
                    damageHazards[#damageHazards+1] = {damage = hazard.damageAmount, type = hazard.damageType, name = hazard.aura.name}
                end
            end
        end

        for _,hazard in ipairs(damageHazards) do
            if hazard.type == "normal" then
                text = string.format("%s\n<color=#ff6666>%d damage from %s</color>", text, hazard.damage, hazard.name)
            else
                text = string.format("%s\n<color=#ff6666>%d %s damage from %s</color>", text, hazard.damage, hazard.type, hazard.name)
            end
        end
    end

	if (not path.valid) and (not path.teleport) and (not path.forced) and dmhub.isDM then
		text = string.format('%s\nNo path found, move through walls or hold shift to teleport.', text)
	end

	--calculate how it should be aligned, trying to avoid the tooltip going over the arrow or the creature.
	local halign = 'center'
	local valign = 'center'


	local dest = path.destination

	if dest.x > path.origin.x then
		valign = 'top'
	end

	if dest.x < path.origin.x then
		valign = 'top'
	end

	if dest.y > path.origin.y then
		valign = 'top'
	end

	if dest.y < path.origin.y then
		valign = 'bottom'
	end

	--for large tokens make sure the tooltip appears well off the creature.
	local locsOccupied = token:LocsOccupyingWhenAt(dest)
	if locsOccupied ~= nil and #locsOccupied > 1 then
		for _,loc in ipairs(locsOccupied) do
			if valign == "top" and loc.y > dest.y then
				dest = loc
			end

			if valign == "bottom" and loc.y < dest.y then
				dest = loc
			end
		end
		
	end

	self.dialog.sheet:FireEvent("tiletooltip", {
		loc = dest,
		text = text,
		halign = halign,
		valign = valign,
		floorDelta = floorDelta,
	})
end