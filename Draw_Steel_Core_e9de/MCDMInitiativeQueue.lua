local mod = dmhub.GetModLoading()

-- The InitiativeQueue records the initiative of any tokens that have been given initiative. It is
-- stored in the Game Document and thus networked between systems. The initiative queue can be nil,
-- which means that there is currently no initiative and players move with free movement.
--
-- The core part of the InitiativeQueue is the entries, which are keyed by 'Initiative ID'.
-- Initiative ID is a string which can be either:
--   - a token id, in which case the initiative entry is for a single token, normally used for characters; or,
--   - a monster type name, with a MONSTER- prefix. In this case the initiative entry represents all monsters of that type.
--
-- The Initiative Queue also stores the current 'round', starting at 1. Generally when the initiative queue is created, it
-- will start at round 1, representing the first round of combat. Initiative entries store the round at which the associated tokens
-- get to move. The "current initiative entry" -- aka whose turn it is -- is the highest initiative that is eligible to move this round.
-- When a token ends their turn, their initiative entry has the current round incremented.

RegisterGameType("InitiativeQueue")
RegisterGameType("InitiativeQueueEntry")

dmhub.TokensAreFriendly = function(a,b)
	local initiative = dmhub.initiativeQueue
	if initiative == nil or initiative.hidden then
		return nil
	end

	local playera = initiative:IsEntryPlayer(InitiativeQueue.GetInitiativeId(a))
	local playerb = initiative:IsEntryPlayer(InitiativeQueue.GetInitiativeId(b))

	if playera == nil or playerb == nil then
		return nil
	end

	return playera == playerb
end

--just some default InitiativeQueueEntry values.
InitiativeQueueEntry.round = 0
InitiativeQueueEntry.turn = 0
InitiativeQueueEntry.initiative = 0
InitiativeQueueEntry.dexterity = 0
InitiativeQueueEntry.turnsPerRound = 1
InitiativeQueueEntry.turnsTaken = 0

--Create a new empty initiative queue. Called when the DM starts initiative.
function InitiativeQueue.Create()
	local playersGoFirst = math.random(1, 2) == 1
	return InitiativeQueue.new{
		guid = dmhub.GenerateGuid(),
        playersGoFirst = playersGoFirst,
		playersTurn = playersGoFirst,
		currentTurn = false,
		turn = 1,
		round = 1,
		hidden = false,
		entries = CreateTable(),
	}
end

function InitiativeQueue:ChoosingTurn()
	return self.currentTurn == false
end

function InitiativeQueue:EntriesUnmoved()
	local result = {}
	for k,entry in pairs(self.entries) do
		if entry.round <= self.round then
			result[k] = entry
		end
	end

	return result
end

function InitiativeQueue:EntryUnmoved(entry)
	return entry.round <= self.round
end

function InitiativeQueue:IsPlayersTurn()
	local hasPlayers = false
	local hasMonsters = false
	local entriesUnmoved = self:EntriesUnmoved()
	for k,entry in pairs(entriesUnmoved) do
		if self:IsEntryPlayer(k) then
			hasPlayers = true
		else
			hasMonsters = true
		end
	end

	if hasPlayers and not hasMonsters then
		return true
	end

	if hasMonsters and not hasPlayers then
		return false
	end

	return self.playersTurn
end

function InitiativeQueue:SelectTurn(initiativeid)
	local entry = self.entries[initiativeid]
	if entry == nil then
		print("Error: Initiativeid not found", initiativeid)
		return
	end

	entry.turn = self.turn
	self.turn = self.turn + 1

	self.currentTurn = initiativeid
end

--for a token give the initiative id. This is the token id if the token is a
--unique character, or the monster type if the token is a monster.
function InitiativeQueue.GetInitiativeId(token)
	local squadid = token.properties:MinionSquad()
	if squadid ~= nil then
		return 'MONSTER-' .. dmhub.SanitizeDatabaseKey(squadid)
	end

    if token.properties.initiativeGrouping then
        return token.properties.initiativeGrouping
    end

	return token.id
end

function InitiativeQueue:CancelTurn(initiativeid)
	local entry = self.entries[initiativeid]
	if entry ~= nil then
		entry.turn = self.turn + 1
	end

	self.turn = self.turn-1
	self.currentTurn = false
end

--End a token's turn and go to the next turn.
function InitiativeQueue.NextTurn(self, initiativeid)

	--find this entry and increment the round it moves at.
	local entry = self.entries[initiativeid]
	if entry ~= nil then
		entry.endTurnTimestamp = ServerTimestamp()
		if entry.turnsPerRound > 1 then
			if entry.round < self.round then
				entry.turnsTaken = 0
				entry.round = self.round
			end
			entry.turnsTaken = entry.turnsTaken + 1
			if entry.turnsTaken >= entry.turnsPerRound then
				entry.round = self.round+1
				entry.turnsTaken = 0
			end
		else
			entry.round = self.round+1
		end
	end

	self.currentTurn = false

	self.playersTurn = not self.playersTurn

	--are there any more tokens that are going to move this round?
	--if not then increment the current round.
	for k,v in pairs(self.entries) do
		if v.round <= self.round then
			return false
		end
	end

	self:NextRound()
	return true
end

function InitiativeQueue.NextRound(self)
	self.playersTurn = self.playersGoFirst
	self.round = self.round+1
	self.turn = 1
end

--does this initiative id have an entry?
function InitiativeQueue.HasInitiative(self, initiativeid)
	local entry = self.entries[initiativeid]
	return entry ~= nil
end

function InitiativeQueue:IsEntryPlayer(initiativeid)
	local entry = self.entries[initiativeid]
	if entry == nil then
		return nil
	end

	if entry:has_key("player") then
		return entry.player
	end

	if string.starts_with(entry.initiativeid, 'MONSTER-') then
		return false
	end

	local token = dmhub.GetCharacterById(entry.initiativeid)
	if token == nil then
        if string.starts_with(entry.initiativeid, 'PLAYERS-') then
            return true
        end
		return false
	end

	return token.playerControlled
end

function InitiativeQueue:DescribeEntry(initiativeid)
	local entry = self.entries[initiativeid]
	if entry == nil or entry:has_key("description") == false then
		if string.startswith(entry.initiativeid, 'MONSTER-') then
			return string.sub(entry.initiativeid, 9)
		else
			local token = dmhub.GetCharacterById(entry.initiativeid)
			if token ~= nil then
				return token.description
			end
		end
		return "Unknown, possibly deleted character"
	end

	return entry.description
end

--set the initiative for a given initiative id, creating an entry if necessary.
--also optionally set the token's dexterity, which is used for tie breakers.
function InitiativeQueue.SetInitiative(self, initiativeid, value, dexterity)
	local entry = self.entries[initiativeid]
	if entry == nil then
		entry = InitiativeQueueEntry.new{
			round = self.round,
			initiativeid = initiativeid,
			initiative = value,
			dexterity = dexterity or 0,
		}

		if GameHud.instance ~= nil and GameHud.instance:has_key("initiativeInterface") then
			local tokens = GameHud.instance:GetTokensForInitiativeId(GameHud.instance.initiativeInterface, initiativeid)
			if tokens ~= nil and #tokens > 0 then
				entry.description = tokens[1].description

				local turnsPerRound = tokens[1].properties:TurnsPerRound()
				if turnsPerRound ~= InitiativeQueueEntry.turnsPerRound then
					entry.turnsPerRound = turnsPerRound
				end
			end
		end
	else
		entry.initiative = value
		if dexterity ~= nil then
			entry.dexterity = value
		end
	end

	self.entries[initiativeid] = entry
end

--remove an initiative entry, if it exists.
function InitiativeQueue.RemoveInitiative(self, initiativeid)
	self.entries[initiativeid] = nil
end

--given an entry in the initiative queue, return 'ord', a number which is higher
--the closer to the front of the initiative queue the entry is.
function InitiativeQueue:GetEntryOrd(entry)
	local currentTurn = entry.initiativeid == self.currentTurn
	return cond(currentTurn, 10000000, 0) + -entry.round*1000 + self:GetEntryOrdAbsolute(entry)
end

function InitiativeQueue:GetEntryOrdAbsolute(entry)
	local currentTurn = entry.initiativeid == self.currentTurn
	return entry.round + cond(currentTurn, 0.001, 0) - entry.turn*0.0001
end

--get the entry for the first item in the initiative queue -- i.e. whose turn it currently is.
function InitiativeQueue:GetFirstInitiativeEntry()
	return self.entries[self.currentTurn]
end

function InitiativeQueue:HasHadTurn(initiativeid)
	local entry = self.entries[initiativeid]
	if entry == nil then
		return nil
	end

	return entry.round > self.round
end

function InitiativeQueue:CurrentInitiativeId()
	if self.hidden or self:ChoosingTurn() then
		return nil
	end

	local entry = self:GetFirstInitiativeEntry()
	if entry ~= nil then
		return entry.initiativeid
	end

	return nil
end

--get the tokenid of the character whose turn it is currently.
function InitiativeQueue:CurrentPlayer()
	if self.hidden then
		return nil
	end

	local entry = self:GetFirstInitiativeEntry()

	if entry == nil or string.startswith(entry.initiativeid, 'MONSTER-') then
		return nil
	end

	return entry.initiativeid
end

--gets a unique ID for the round of combat this token considers it to be.
--This controls when resources for the token are refreshed. In DS they refresh on a round
--basis so it's just the round ID.
function InitiativeQueue:GetRoundIdForToken(token)
	if self.hidden then
		return nil
	end

	return self:GetRoundId()
end

--gets a unique ID for this round in this combat.
function InitiativeQueue:GetRoundId()
	if self.hidden then
		return nil
	end

	return string.format('%s-%d', self.guid, self.round)
end

--gets a unique ID for this turn in this combat.
function InitiativeQueue:GetTurnId()
	if self.hidden then
		return nil
	end

	local entry = self:GetFirstInitiativeEntry()
	if entry == nil or entry.initiativeid == nil then
		return nil
	end

	return string.format("%s-%s", self:GetRoundId(), entry.initiativeid)
end

--called by DMHub to query the current combat round. zero-based result.
function GetCombatRound(initiativeQueue)
	if initiativeQueue == nil or initiativeQueue.hidden then
		return 0
	end

	return initiativeQueue.round - 1
end

