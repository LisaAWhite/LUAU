--- @class LuaPath 
--- @field forced boolean 
--- @field forcedDest nil|Loc 
--- @field forcedMovementTotalDistance number 
--- @field collisionSpeed number 
--- @field mount any 
--- @field waterSteps any 
--- @field difficultSteps any 
--- @field squeezeSteps any 
--- @field numDiagonals any 
--- @field cost any 
--- @field numSteps any 
--- @field destinationPosition any 
--- @field destination any 
--- @field origin any 
--- @field steps Loc[] 
LuaPath = {}

--- CalculateHazards
--- @param tok CharacterToken
--- @return nil|{type: 'damage', damageAmount: number, damageType: string, aura: AuraInstance}[]
function LuaPath:CalculateHazards(tok)
	-- dummy implementation for documentation purposes only
end
