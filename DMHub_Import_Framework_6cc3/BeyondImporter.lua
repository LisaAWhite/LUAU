local mod = dmhub.GetModLoading()

--@usage readModifier(x.definition)
--problem to solve: infer from feature how a modifier should be read; many of them are obvious, but many are also arcane.  
local function readFeature(feature, source)
    source = source or ""
    -- first we need to create a feature
    local r = CharacterFeature.Create{
        name = feature.name,
        description = feature.snippet ~= "" and feature.snippet or feature.description:gsub("%b<>", ""),
    }

    -- and then that feature can be assigned modifiers based on information inferenced from the snippet/description/etc
    local m = r.modifiers

    local infer = r.description:lower() -- The string to infer modifiers from.

    for attr, val in infer:gmatch("your (%a+) score increases by (%d+)") do
        m[#m+1] = CharacterModifier.new{
            behavior = "attribute",
            attribute = attr:sub(1,3),
            name = "Attribute Score Increase",
            source = source,
            value = tonumber(val)
        } 
        import:Log(string.format("Assigned %s to %d", m[#m].name, #m))
    end

    for skill in infer:gmatch("you have proficiency in the (%a+) skill.") do
        local rm = CharacterModifier.new{
            behavior = "proficiency",
            proficiency = "proficient",
            skills = {},
            name = string.format("%s proficiency", skill),
            source = source,
            subtype = "skill",
        }
        rm.skills[skill] = true
        m[#m+1] = rm
        import:Log(string.format("Assigned %s to %d", m[#m].name, #m))
    end

    return r
end

local function newBackground(bid, backgroundInfo)
    local backgroundTable, bginfo = dmhub.GetTable(Background.tableName)
    local background = bid

    if backgroundInfo.hasCustomBackground then
        bginfo =  backgroundInfo.customBackground
    else
        bginfo = backgroundInfo.definition
    end

    background.name = bginfo.name
    background.description = bginfo.description:gsub("%b<>", "")

    local bgm = background:GetClassLevel()
    
    if bginfo.skillProficienciesDescription ~= "" then
        local n = #bgm.features+1
        bgm.features[n] = CharacterFeature.Create{
            name = "Skill Proficiencies",
        }
        bgm.features[n].modifiers[1] = CharacterModifier.new{
            behavior = "proficiency",
            proficiency = "proficient",
            skills = bginfo.skillProficienciesDescription:split(", "),
            name = "Proficiencies",
            source = background.name,
            subtype = "skill",
        }
    end

    if bginfo.languagesDescription ~= "" then 
        local n = #bgm.features+1
        local num = bginfo.languagesDescription:lower():match("^(%a+)")
        bgm.features[n] = CharacterFeatureChoice.new{
            guid = dmhub.GenerateGuid(),
            allowDuplicateChoices = false,
            numChoices = num,
            options = {},
            name = "Languages"
        }

        -- come back and tighten this up later
        -- small bug: a guid sneaks into there by way of the table. 
        for lang, _ in pairs(dmhub.GetTable(Language.tableName)) do
            local o = CharacterFeature.Create{
                modifiers = {
                    CharacterModifier.new{
                        behavior = "proficiency",
                        guid = dmhub.GenerateGuid,
                        name = lang,
                        proficiency = "proficient",
                        skills = {},
                        description = "",
                        subtype = "language",
                        source = background.name.." feature",
                    }

                },
                description = "",
                name = lang,
                source = background.name.." feature",
                canHavePrerequisites = true,
            }            
            o.modifiers[1].skills[lang] = true
            table.insert(bgm.features[n].options, o)
        end
    end

    if bginfo.toolProficienciesDescription ~= "" then
        bgm.features[#bgm.features+1] = CharacterFeature.Create{
            name = "Tool Proficiencies"
        }
    end

    if bginfo.featureName ~= "" then
        bgm.features[#bgm.features+1] = CharacterFeature.Create{
            name = bginfo.featureName,
            description = bginfo.featureDescription:gsub("%b<>", "")
        }
    end
    -- pull profs from bginfo.skillProficienciesDescription, ..toolProficienciesDescription, and ..languagesDescription

    dmhub.SetAndUploadTableItem("backgrounds", background)
end


local function newClass(cid, classInfo)
    local classTable = dmhub.GetTable(Class.tableName)
    local class = cid
    local cinfo = classInfo

    local spa = {"str", "dex", "con", "int", "wis", "cha"}

    class.name = cinfo.name
    class.description = cinfo.description:gsub("%b<>", "")
    class.hit_die = cinfo.hitDice

    if cinfo.wealthDice then
        class.startingCurrency = cinfo.wealthDice.diceString..cinfo.wealthDice.diceMultiplier
    end

    if cinfo.canCastSpells then
        class.spellcastingAttr = spa[cinfo.spellCastingAbilityId]
    end

    class.levels = class:FillLevelsUpTo(20, false, {})
    -- pull class feature info from cinfo.classFeatures, churn through them and return them in format for class.levels = {...}, use CharacterFeature.Create etc
    for _, feature in ipairs(cinfo.classFeatures) do
        local level = feature.requiredLevel
        local cl = class:GetLevel(level)
        cl.features[#cl.features + 1] = readFeature(feature)
    end
--[[
    if cinfo.subclassDefinition then
        c2 = Class.CreateNew()
        c2.isSubclass = true
        newClass(c2, cinfo.subclassDefinition)
    end
--]]
    dmhub.SetAndUploadTableItem(cid.isSubclass and "subclasses" or "classes", class)
end

local function newRace(rid, raceInfo)
    local race = rid


    race.name = raceInfo.baseRaceName
    -- TODO grab portrait by URL reference once implemented
    race.description = raceInfo.description:gsub("%b<>", "")

    race.moveSpeeds = raceInfo.weightSpeeds.normal

    -- loop through features and grab; attempt to implement if we understand implementation pattern, otherwise tag as unimplemented
    for _, v in ipairs(raceInfo.racialTraits) do
        local info = v.definition
        local modifiers = race:GetClassLevel()
        modifiers.features[#modifiers.features+1] = readFeature(info)
    end --]]

    dmhub.SetAndUploadTableItem("races", race)
end

local function newSubrace(subrace, raceInfo, raceid)
    subrace.subrace = true
    subrace.name = raceInfo.subRaceShortName.." "..raceInfo.baseName
    subrace.parentRace = raceid

    dmhub.SetAndUploadTableItem("subraces", subrace)
end

import.Register{
    id = "beyond",
    description = "Beyond Characters",
    input = "url",
    priority = 10,
    urlText = "Enter Beyond Character URL...",

    translateerror = function(error)
        if string.find(error, " 403") then
            error = "The character is private. You must make it public to import it."
        end

        return error
    end,

    translateurl = function(url)
        local _,_,num = string.find(url, "(%d+)")
        if num == nil or #tostring(num) < 4 then
            return nil
        end

        return "https://character-service.dndbeyond.com/character/v5/character/" .. tostring(num)
    end,

    json = function(importer, doc, filename)
        printf("Beyond:: Importing...")

        if doc.success ~= true or doc.data == nil then
            import:Log("Could not read Beyond data from URL")
            return
        end

        doc = doc.data

        --import:Log(string.format("Importing %s as a Beyond character.", filename))

        local bookmark = import:BookmarkLog()

        local charid = nil

        local token = import:CreateCharacter()
        token.properties = character.CreateNew{}

        token.partyId = GetDefaultPartyID()

        token.name = doc.name

        import:ImportImageFromURL(doc.avatarUrl,
            function(path)
                if charid ~= nil then
                    local avatarid
                    avatarid = assets:UploadImageAsset{
                        path = path,
                        imageType = "Avatar",
                        error = function(text)
                        end,
                        upload = function(imageid)
                            dmhub.AddAndUploadImageToLibrary("Avatar", imageid)
                            token.portrait = avatarid
                        end,
                    }
                end

            end,
            function(error_msg)
            end
        )

        local c = token.properties

        local alignments = {"lawful good", "neutral good", "chaotic good", "lawful neutral", "true neutral", "chaotic neutral", "lawful evil", "neutral evil", "chaotic evil"}

        if type(doc.alignmentId) == "number" and alignments[doc.alignmentId] ~= nil then
            c.alignment = alignments[doc.alignmentId]
        else
            import:Log(string.format("Could not recognize alignment '%s'", json(doc.alignmentId)))
        end

        local statIds = {"str", "dex", "con", "int", "wis", "cha"}
        for _,stat in ipairs(doc.stats or {}) do
            local statId = statIds[stat.id]
            if statId ~= nil then
                c:GetBaseAttribute(statId).baseValue = stat.value
            end
        end

        for _,stat in ipairs(doc.bonusStats or {}) do
            local statId = statIds[stat.id]
            if statId ~= nil and stat.value ~= nil then
                c:get_or_add("attributesBonusAdd", {})[statId] = stat.value
            end
        end

        for _,stat in ipairs(doc.overrideStats or {}) do
            local statId = statIds[stat.id]
            if statId ~= nil and stat.value ~= nil then
                c:get_or_add("attributesOverride", {})[statId] = stat.value
            end
        end

        local notes = {}

        for _,noteKey in ipairs({"notes", "traits"}) do
            local notesDict = doc[noteKey] or {}

            for key,note in pairs(notesDict) do
                if type(note) == "string" then
                    local noteName = string.upper(string.sub(key, 1, 1))
                    for i=2,#key do
                        local char = string.sub(key, i, i)
                        if char ~= string.lower(char) then
                            --upper case, start of a new word.
                            noteName = noteName .. " "
                        end

                        noteName = noteName .. char
                    end

                    notes[#notes+1] = {
                        title = noteName,
                        text = note,
                    }
                end
            end
        end

        c.notes = notes

        local racesTable = dmhub.GetTable(Race.tableName)
        local subracesTable = dmhub.GetTable('subraces')

        local raceid = nil
        local subraceid = nil
        local raceInfo = doc.race
        if raceInfo ~= nil then
            for id,race in pairs(racesTable) do

                if not race:try_get("hidden", false) then

                    if (not race.subrace) and string.lower(raceInfo.baseRaceName) == string.lower(race.name) then
                        raceid = id
                    end

                    if race.subrace and raceInfo.isSubRace then
                        if string.find(string.lower(raceInfo.fullName), string.lower(race.name)) then
                            subraceid = id
                        end
                    end
                end

            end

            for id,race in pairs(subracesTable) do
                if (not race:try_get("hidden", false)) and raceInfo.isSubRace then

                    if string.find(string.lower(raceInfo.fullName), string.lower(race.name)) then
                        subraceid = id
                        if racesTable[race:try_get("parentRace", "none")] ~= nil then
                            raceid = id
                        end
                    end
                end
            end

            if raceid == nil then
                import:Log(string.format("Unknown race '%s'", raceInfo.baseRaceName))
                local rid = Race.CreateNew()
                newRace(rid, raceInfo)
                raceid = rid.id
            end
            c.raceid = raceid

            if raceInfo.isSubRace and subraceid == nil then
                import:Log(string.format("Unknown subrace '%s'", raceInfo.fullName))
                local srid = Race.new()
                newSubrace(srid, raceInfo, raceid)
                subraceid = srid.id
            end
            c.subraceid = subraceid
            
        end


	    local classesTable = dmhub.GetTable(Class.tableName)
        for _,classInfo in ipairs(doc.classes or {}) do
            local level = classInfo.level
            local classdef = classInfo.definition

            local classid = nil
            for k,v in pairs(classesTable) do
                if (not v:try_get("hidden")) and string.lower(v.name) == string.lower(classdef.name) then
                    classid = k
                    break
                end
            end

            if classid == nil then
                import:Log(string.format("Unknown class '%s'", classdef.name))
                local cid = Class.CreateNew()
                newClass(cid, classInfo.definition)
                classid = cid.id
            end

            local classes = c:get_or_add("classes", {})
            classes[#classes+1] = {
                classid = classid,
                level = classInfo.level,
            }

            local subclassDef = classInfo.subclassDefinition

            if subclassDef ~= nil then
                local subclassFound = false
                local subclassesTable = dmhub.GetTable("subclasses") or {}
                for subclassid,subclassInfo in pairs(subclassesTable) do
                    -- this is heavily integrated and needs to be considered heavily to give ourselves time to create a fake subclass 
                    if (not subclassInfo:try_get("hidden", false)) and string.lower(subclassInfo.name) == string.lower(subclassDef.name) then
                        subclassFound = true

                        local foundSubclassChoice = false
                        --now try to find a matching subclass choice in this class's leveling.
                        local classInfo = classesTable[classid]
                        for _,levelInfo in pairs(classInfo.levels) do
                            for _,featureInfo in ipairs(levelInfo.features) do
                                if featureInfo.typeName == "CharacterSubclassChoice" then
                                    --add a level choice for this feature to set to the subclassid.
                                    c:GetLevelChoices()[featureInfo.guid] = {subclassid}
                                    foundSubclassChoice = true
                                end
                            end
                        end

                        if not foundSubclassChoice then
                            import:Log(string.format("Could not find subclass choice %s", subclassInfo.name))
                        end
                    end
                end

                if not subclassFound then
                    import:Log(string.format("Could not find subclass %s", subclassDef.name))
                end
            end

        end

        local bgid = nil
        local backgroundsTable = dmhub.GetTable(Background.tableName)
        if doc.background ~= nil then
            local bginfo = doc.background.definition or doc.background.customBackground
            for backgroundid,background in pairs(backgroundsTable) do
                if (not background:try_get("hidden", false)) and string.lower(bginfo.name) == string.lower(background.name) then
                    bgid = backgroundid
                end
            end

            if bgid == nil then
                import:Log(string.format("Unknown background '%s'", bginfo.name))
                local bid = Background.CreateNew()
                newBackground(bid, doc.background)
                bgid = bid
            end
            c.backgroundid = bgid
            
        end

        if doc.currencies ~= nil then
            local currencyMap = {cp = "copper", sp = "silver", gp = "gold", ep = "electrum", pp = "platinum"}
            local currencyTable = dmhub.GetTable(Currency.tableName) or {}
            for currencyid,quantity in pairs(doc.currencies) do
                if quantity > 0 then
                    local idfound = nil
                    for id,currency in pairs(currencyTable) do
                        if string.lower(currency.name) == currencyMap[currencyid] then
                            idfound = id

                        end
                    end

                    if idfound == nil then
                        import:Log(string.format("Unknown currency '%s'. Could not import %d%s of currency.", currencyid, quantity, currencyid))
                    else
                        c:SetCurrency(idfound, quantity, "Import from Beyond")
                    end
                end

            end
        end

        local itemsTable = dmhub.GetTable("tbl_Gear")

        local nameToItem = {}
        for itemid,itemEntry in pairs(itemsTable) do
            local name = trim(string.lower(string.gsub(itemEntry.name, " ", "")))
            nameToItem[name] = itemid
        end

        for _,inventoryEntry in ipairs(doc.inventory or {}) do
            local def = inventoryEntry.definition
            local name = trim(string.lower(string.gsub(def.name, " ", "")))
            if nameToItem[name] == nil then
                local candidateAlternative = nil
                for ourname,_ in pairs(nameToItem) do
                    if string.find(ourname, name) ~= nil or string.find(name, ourname) ~= nil and ourname ~= "" and (candidateAlternative == nil or string.len(ourname) > string.len(candidateAlternative)) then
                        candidateAlternative = ourname
                        break
                    end
                end

                if candidateAlternative ~= nil then
                    local ourname = candidateAlternative
                    import:Log(string.format("Cannot find exact match for item %s. Matching as %s.", def.name, itemsTable[nameToItem[ourname]].name))
                    name = ourname
                end

                if nameToItem[name] == nil then
                    import:Log(string.format("Unknown item: %s", def.name))
                end
            end


            if nameToItem[name] ~= nil then
                c:GiveItem(nameToItem[name], inventoryEntry.quantity)
            end
        end

        import:StoreLogFromBookmark(bookmark, token)
        charid = import:ImportCharacter(token)

        printf("Beyond:: Done import!")

    end,
}