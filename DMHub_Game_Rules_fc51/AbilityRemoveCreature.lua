local mod = dmhub.GetModLoading()

RegisterGameType("ActivatedAbilityRemoveCreatureBehavior", "ActivatedAbilityBehavior")

ActivatedAbility.RegisterType
{
	id = 'remove_creature',
	text = 'Remove Creature',
	createBehavior = function()
		return ActivatedAbilityRemoveCreatureBehavior.new{
		}
	end
}

ActivatedAbilityRemoveCreatureBehavior.summary = 'Remove Creatures'
ActivatedAbilityRemoveCreatureBehavior.dropsLoot = false

function ActivatedAbilityRemoveCreatureBehavior:SummarizeBehavior(ability, creatureLookup)
	return "Remove Creatures"
end

function ActivatedAbilityRemoveCreatureBehavior:DropLoot(token)
	local objects = assets:GetObjectsWithKeyword("corpse")

	if #objects == 0 then
		return
	end

	local inventory = DeepCopy(token.properties:try_get("inventory", {}))

	--drop the held items as well.
	local equip = token.properties:Equipment()
	local sharesSeen = {}
	for slotid,itemid in pairs(equip) do
		
		--make sure this isn't a shared slot.
		local metaslot = token.properties:EquipmentMetaSlot(slotid)
		local seen = false
		if metaslot.share ~= nil then
			if sharesSeen[metaslot.share] then
				seen = true
			else
				sharesSeen[metaslot.share] = true
			end
		end

		if not seen then
			local entry = inventory[itemid]
			if entry == nil then
				entry = {quantity = 0}
				inventory[itemid] = entry
			end

			entry.quantity = entry.quantity + 1
		end
	end

	local haveItems = false
	for _,itemid in pairs(inventory) do
		haveItems = true
		break
	end

	if haveItems == false then
		for k,v in pairs(token.properties:try_get("currency", {})) do
			if v ~= nil and v > 0 then
				haveItems = true
				break
			end
		end
	end

	if haveItems == false then
		return
	end



	local floor = game.GetFloor(token.floorid)

	local newObj = floor:CreateLocalObjectFromBlueprint{
		assetid = objects[1].id,
	}

	newObj.scale = newObj.scale * token.radiusInTiles
	newObj.x = token.pos.x
	newObj.y = token.pos.y

	local loot = {
		["@class"] = "ObjectComponentLoot",
		destroyOnEmpty = true,
		instantLoot = false,
		locked = false,
		properties = {
			__typeName = "loot",
			inventory = inventory,
			currency = DeepCopy(token.properties:try_get("currency", {}))
		}
	}

	newObj:AddComponentFromJson("LOOT", loot)

	newObj:Upload()
end

function ActivatedAbilityRemoveCreatureBehavior:Cast(ability, casterToken, targets, options)
    local charids = {}
    for i,target in ipairs(targets) do
		if self.dropsLoot then
			self:DropLoot(target.token)

		end

        charids[#charids+1] = target.token.charid
    end

    game.DeleteCharacters(charids)
	options.pay = true
end



function ActivatedAbilityRemoveCreatureBehavior:EditorItems(parentPanel)
	local result = {}
	self:ApplyToEditor(parentPanel, result)
	self:FilterEditor(parentPanel, result)

	result[#result+1] = gui.Check{
		text = "Drops Loot",
		value = self.dropsLoot,
		change = function(element)
			self.dropsLoot = element.value
		end,
	}

	return result
end
