local mod = dmhub.GetModLoading()

local function createDrawSteelBanner(options)

    local m_document = mod:GetDocumentSnapshot("drawsteel")

    if options.controller then
        m_document:BeginChange()
        m_document.data.guid = dmhub.GenerateGuid()
        m_document.data.claims = {}
        m_document.data.finished = nil
        m_document:CompleteChange("Initialize initiative")
    end

    local m_heroesWin = nil

    local m_rollInfo = nil
    local m_rollConfirmedStarting = false
    local m_rollConfirmedFinishing = false
    local endAnimationDuration = 1
    local fadeoutDuration = 0.13

    --if we started rolling, this is the guid of the roll.
    local m_rollGuid = nil

    --the user who is currently rolling
    local m_claimUserId = nil
    local m_claim = nil

    --the current roll we are listening to along with the event source.
    local m_rollidListeningTo = nil
    local m_rollEvents = nil

    local scale = 1
    local standardAspect = 16/8
    local actualAspect = dmhub.screenDimensions.x/dmhub.screenDimensions.y
    if actualAspect < standardAspect then
        scale = actualAspect / standardAspect
    end
    print("ASPECT::", actualAspect, "from", dmhub.screenDimensions.x, dmhub.screenDimensions.y, "BECOME", scale)


    local BannerPanel

    BannerPanel = gui.Panel{
        scale = scale,

        flow = "horizontal",
        width = "auto",
        height = "auto",
        halign = "center",
        valign = "top",
        draggable = false,

        styles = {
            {
                selectors = {"canshine"},
                gradient = gui.Gradient{
                    point_a = {x = 0, y = 0.1},
                    point_b = {x = 1, y = 0},
                    stops = {
                        {
                            position = -0.2,
                            color = "white",
                        },
                        {
                            position = -0.1,
                            color = core.Color{h = 0, s = 0, v = 4},
                        },
                        {
                            position = 0,
                            color = "white",
                        },
                    },

                }
            },
            {
                selectors = {"canshine", "shine"},
                transitionTime = 1,

                gradient = gui.Gradient{
                    point_a = {x = 0, y = 0.1},
                    point_b = {x = 1, y = 0},
                    stops = {
                        {
                            position = 1.0,
                            color = "white",
                        },
                        {
                            position = 1.1,
                            color = core.Color{h = 0, s = 0, v = 4},
                        },
                        {
                            position = 1.2,
                            color = "white",
                        },
                    },
                }
            },
            {
                selectors = {"canshine", "shine", "fadeout"},
                transitionTime = 0.4,
                opacity = 0,
            }
        },

        --fired very shortly before dying.
        fadeout = function(self)
            self:SetClassTree("fadeout", true)
        end,

        thinkTime = 0.01,
        think = function(self)

            local doc = mod:GetDocumentSnapshot("drawsteel")
            if doc.data.finished then

                self.thinkTime = nil

                dmhub.Coroutine(function()
                    self:SetClassTree("shine", true)
                    local targetPanel = self:Get(cond(m_heroesWin, "heroesText", "monstersText"))
                    local start = self.aliveTime
                    local t = self.aliveTime - start

                    coroutine.yield(0.8)

                    BannerPanel:SetClassTree("finishing", true)
                    BannerPanel:FireEventTree("finishing")

                    coroutine.yield(1.0)

                    BannerPanel:FireEvent("fadeout")
                    targetPanel:SetClass("fadeout", true)

                    coroutine.yield(0.8)

                    --as the controller who called for this dialog,
                    --create initiative for everyone now.
                    if options.controller then
                        local info = GameHud.instance.initiativeInterface
                        info.initiativeQueue = InitiativeQueue.Create()
                        info.initiativeQueue.playersGoFirst = m_heroesWin
                        info.initiativeQueue.playersTurn = m_heroesWin
                        Commands.rollinitiative()
                    end

                    self:DestroySelf()
                end)

                return
            end

--        if m_rollInfo ~= nil then
--            print("DURATION::", m_rollInfo.timeRemaining)
--            if m_rollConfirmedStarting == false and m_rollInfo.timeRemaining > 0 then
--                m_rollConfirmedStarting = true
--            end

--            if m_rollConfirmedStarting and m_rollConfirmedFinishing == false and m_rollInfo.timeRemaining < endAnimationDuration then
--                m_rollConfirmedFinishing = true
--                BannerPanel:SetClassTree("finishing", true)
--                BannerPanel:FireEventTree("finishing")

--                --also schedule to fire a final fade out with 0.4 seconds left.
--                BannerPanel:ScheduleEvent("fadeout", endAnimationDuration - fadeoutDuration)
--            end
--        end


            if m_claim ~= nil and m_claim.rollid ~= m_rollidListeningTo then

                if m_rollEvents ~= nil then
                    --we were previously listening to this event source, stop listening to it.
                    m_rollEvents:Unlisten(self)
                    m_rollEvents = nil
                    m_rollidListeningTo = nil
                end

                if m_claim.rollid ~= nil then
                    local rollInfo = chat.GetRollInfo(m_claim.rollid)

                    if rollInfo ~= nil then
                        m_rollInfo = rollInfo

                        --there SHOULD only be one roll, but we'll just iterate them all and use
                        --the first we can find.
                        for i,roll in ipairs(rollInfo.rolls) do
                            --we've detected a roll so start listening to it.
                            m_rollEvents = chat.DiceEvents(roll.guid)
                            if m_rollEvents ~= nil then
                                m_rollidListeningTo = m_claim.rollid
                                m_rollEvents:Listen(self)
                                break
                            end
                        end
                    end
                end
            end
        end,

        diceface = function(self, diceguid, num)
            local heroesWin = (num >= 6)
            m_heroesWin = heroesWin
            BannerPanel:SetClassTree("rolling", true)
            BannerPanel:SetClassTree("heroes", heroesWin)
            BannerPanel:SetClassTree("monsters", not heroesWin)
        end,

		monitorGame = m_document.path,

        refreshGame = function(self)

            local bestid = nil
            local bestClaim = nil
            local doc = mod:GetDocumentSnapshot("drawsteel")
            for userid,claim in pairs(doc.data.claims or {}) do
                if bestClaim == nil or claim.priority > bestClaim.priority or (claim.priority == bestClaim.priority and claim.timestamp < bestClaim.timestamp) then
                    bestid = userid
                    bestClaim = claim
                end
            end

            if bestClaim ~= nil then
                if m_rollGuid ~= nil and m_rollGuid == dmhub.currentRollGuid and bestid ~= dmhub.loginUserid then
                    --we are trying to roll but someone else went first, so cancel our roll and cede to them.
                    dmhub.CancelCurrentRoll()
                    m_rollGuid = nil

                    m_document:BeginChange()
                    m_document.data.claims[dmhub.loginUserid] = nil
                    m_document:CompleteChange("Cancel initiative")
                end
            end

            if bestid ~= m_claimUserId then
                BannerPanel:FireEventTree("claim", bestid)
                m_claimUserId = bestid
                m_claim = bestClaim
            end
        end,

        create = function(self)
            if options.controller then
			    GameHud.PresentDialogToUsers(self,"DrawSteel",{})
            end
        end,

        gui.Panel{
            width = 300,
            height = 150,
            bgimage = "panels/initiative/drawsteel-sword.png",
            bgcolor = "white",
            valign = "center",
                
            halign = "right",

            styles = {

                {

                    selectors = {"create"},
                    x = 300,
                    transitionTime = 0.9,
                    easing = "easeInCubic",
                },
                {
                    selectors = {"finishing"},
                    x = 270,
                    transitionTime = endAnimationDuration,
                    easing = "easeInBack",
                },
                {
                    selectors = {"fadeout"},
                    opacity = 0,
                    transitionTime = fadeoutDuration,
                },
            },

        },

        gui.Panel{

            styles = {
                {
                    selectors = {"fadeout"},
                    opacity = 0,
                    transitionTime = fadeoutDuration,
                },
            },

            classes = {"hidden"},

            width = 512,
            height = 70,
            vmargin = 100,
            bgimage = "panels/initiative/drawsteel-text.png",
            bgcolor = "white",

            data = {
                distanceToWall = nil,
                finishTime = nil,
            },

            finishing = function(self)
                self.data.finishTime = self.aliveTime
            end,

            create = function(element)
                element:SetClass("hidden", false)
                element:FireEvent("think")
            end,

            thinkTime = 0.01,
            think = function(self)

                local distanceToWall = math.clamp01(1-(1 - self.aliveTime * 0.8)^3)
                if self.data.finishTime ~= nil then
                    local easeInBack = function(t)
                        local s = 1.70158  -- Default overshoot scale
                        return t * t * ((s + 1) * t - s)
                    end
                    --t will be 0 if we are just starting to finish and 1 if we have completed the finish animation.
                    local t = (self.aliveTime - self.data.finishTime)/(endAnimationDuration*1)
                    t = easeInBack(t)
                    distanceToWall = math.clamp01(1 - t)
                end


                distanceToWall = distanceToWall*0.6

                if distanceToWall ~= self.data.distanceToWall then
                    self.data.distanceToWall = distanceToWall
                    self.selfStyle.gradient = gui.Gradient{

                        point_a = {x = 0, y = 0},
                        point_b = {x = 1, y = 0},
                        stops = {
                            {
                                position = 0.5 - distanceToWall,
                
                                color = "#ffffff00",
                
                            },
                            {
                                position = math.min(0.5, 0.5 - distanceToWall + 0.1),
                
                                color = "#ffffffff",
                
                            },
                            {
                                position = 0.5,
                
                                color = "#ffffffff",
                
                            },
                            {
                                position = math.max(0.5, 0.5 + distanceToWall - 0.1),
                
                                color = "#ffffffff",
                
                            },
                            {
                                position = 0.5 + distanceToWall,
                    
                                color = "#ffffff00",
                    
                            },
                        },

                    }
                end
            end,
        },


        gui.Panel{

            width = 280,
            height = 140,
            bgimage = "panels/initiative/drawsteel-sword.png",
            bgcolor = "white",
            valign = "center",
                
            halign = "right",
            scale = {x = -1, y = 1},

            styles = {

                {

                    selectors = {"create"},
                    x = -300,
                    transitionTime = 0.9,
                    easing = "easeInCubic",

                },

                {
                    selectors = {"finishing"},
                    priority = 20,
                    x = -270,
                    transitionTime = endAnimationDuration,
                    easing = "easeInBack",
                },
                {
                    selectors = {"fadeout"},
                    opacity = 0,
                    transitionTime = fadeoutDuration,
                },

            },


        },

        --the heroes/monsters panel.
        gui.Panel{
            y = -40,
            floating = true,
            width = "auto",
            height = "auto",
            valign = "bottom",
            halign = "center",
            interactable = false,
            gui.Panel{
                id = "monstersText",
                classes = {"canshine"},
                floating = true,
                width = 250,
                height = 39,
                bgimage = "panels/initiative/monsters-text.png",
                halign = "center",
                valign = "bottom",
                interactable = false,
                bgcolor = "white",
                styles = {
                    {
                        opacity = 0,
                    },
                    {
                        selectors = {"monsters"},
                        transitionTime = 0.1,
                        opacity = 1,
                    },
                }
            },
            gui.Panel{
                id = "heroesText",
                classes = {"canshine"},
                floating = true,
                width = 179,
                height = 37,
                bgimage = "panels/initiative/heroes-text.png",
                halign = "center",
                valign = "bottom",
                interactable = false,
                bgcolor = "white",
                styles = {
                    {
                        opacity = 0,
                    },
                    {
                        selectors = {"heroes"},
                        transitionTime = 0.1,
                        opacity = 1,
                    },
                },
            },
        },

        --panel that contains dice along with surrounding initiative text.
        gui.Panel{

            floating = true,
            halign = "center",
            valign = "bottom",
            width = "auto",
            height = "auto",
            y = 110,

            styles = {
                {
                    selectors = {"rolling"},
                    hidden = 1,
                },
            },

            --the clickable dice icon.
            gui.Panel{

                
                bgimage = "panels/initiative/initiative-dice.png",
                bgcolor = "white",
                width = 128,
                height = 128,
                halign = "center",
                valign = "center",
                classes = "dice",

                claim = function(self, userid)
                    if userid == nil then
                        self.selfStyle.bgcolor = "white"
                        self:SetClass("claimed", false)
                        self:SetClass("dragging", false)
                    else
                        local sessionInfo = dmhub.GetSessionInfo(userid)
                        self.selfStyle.bgcolor = sessionInfo.displayColor
                        self:SetClass("claimed", true)
                        self:SetClass("dragging", userid == dmhub.loginUserid)
                    end
                end,

                thinkTime = 0.7,
                think = function(self)

                    if self:HasClass("pulse")
                    then

                        self:SetClass("pulse", false)
                    else
                        
                        self:SetClass("pulse", true)
                    end
                end,

                --we can drag to hurl the dice as long as the dice speed isn't set to instant.
                draggable = dmhub.GetSettingValue("dicespeed") ~= "veryfast",
                beginDrag = function(self)
                    self:FireEvent("click", true)

                end,

                click = function(self, isactuallydrag)
                    if self:HasClass("claimed") then
                        --this is already being dragged by someone else.
                        return
                    end

                    m_rollGuid = dmhub.GenerateGuid()

                    local doc = mod:GetDocumentSnapshot("drawsteel")
                    m_document:BeginChange()
                    m_document.data.claims[dmhub.loginUserid] = {
                        status = cond(isactuallydrag, "drag", "roll"),
                        priority = cond(isactuallydrag, 0, 1),
                        rollid = m_rollGuid,
                        timestamp = dmhub.serverTime,
                    }
                    m_document:CompleteChange("Initialize initiative")

                    dmhub.Roll{
                        roll = "1d10",
                        guid = m_rollGuid,
                        drag = isactuallydrag,
                        description = "Initiative",
                        begin = function(rollInfo)

                        end,

                        complete = function(rollInfo)
                            if m_claimUserId == dmhub.loginUserid then
                                --we completed the roll, so close down the dialog.
                                local doc = mod:GetDocumentSnapshot("drawsteel")
                                doc:BeginChange()
                                doc.data.finished = true
                                doc:CompleteChange("Initialize initiative")
                            end
                        end,

                        cancel = function()
                            --this happens if they stop dragging without hurling the dice.
                            --relinquish our claim to the dice.
                            local doc = mod:GetDocumentSnapshot("drawsteel")
                            doc:BeginChange()
                            if doc.data.claims ~= nil then
                                doc.data.claims[dmhub.loginUserid] = nil
                            end
                            doc:CompleteChange("Initialize initiative")
                        end,
                    }
                end,

                styles = {

                    {

                        selectors = {"pulse"},
                        uiscale = 1.05,
                        transitionTime = 0.7,
                        easing = "easeinOutSine",
                    },

                    {
    
                        selectors = {"hover", "dice"},
                        uiscale = 1.1,
                        transitionTime = 0.1,
                        
    
                    },
    
                    {
                        selectors = {"press"},
                        inversion = 1,

    
                    },

                    {
                        --someone else has 'claimed' the dice, don't allow others to interact.
                        selectors = {"claimed"},
                        transitionTime = 0.2,
                        opacity = 0.6,
                        uiscale = 1,
                        inversion = 0,
                    },

                    {
                        --we are dragging the dice, make them disappear.
                        selectors = {"dragging"},
                        opacity = 0,
                    },
    
                },



            },

            gui.Panel{

                width = 600,
                height = 300,
                bgimage = "panels/initiative/initiative-text.png",
                bgcolor = "white",
                halign = "center",
                valign = "center",
                y = -20,
                x = 8,
                interactable = false,

                styles = {

                    {

                        selectors = {"~parent:hover"},
                        opacity = 0,
                        transitionTime = 0.2,

                    },



                },

            



            }
    
    
    
        },

        

    

        close = function()

            BannerPanel:DestroySelf()


        end,

        rightClick = function(self)

            if dmhub.isDM then
                self.popup = gui.ContextMenu{
                    entries = {
                        {
                            text = "Close",
                            click = function()
                                BannerPanel:DestroySelf()
                                self.popup = nil
                            end,
                        }

                    }
                }
            end
        end


    }

    return BannerPanel
end

function showDrawSteelBanner()
    local banner = createDrawSteelBanner{ controller = true }
    GameHud.instance.parentPanel:AddChild(banner)
end

--- @class RollInitiativeChatMessage
--- @field winner "players"|"monsters"
--- @field playerTokenIds string[]
--- @field monsterTokenIds string[]
RollInitiativeChatMessage = RegisterGameType("RollInitiativeChatMessage")

RollInitiativeChatMessage.winner = "players"
RollInitiativeChatMessage.playerTokenIds = {}
RollInitiativeChatMessage.monsterTokenIds = {}

function RollInitiativeChatMessage.Render(selfInput, message)
    return gui.Panel{width = 0, height = 0}
end

--- @param initiativeQueue InitiativeQueue
--- @param tokens CharacterToken[]
--- @return RollInitiativeChatMessage
function RollInitiativeChatMessage.Create(initiativeQueue, tokens)
    local tokensByInitiative = {}
    for _,tok in ipairs(tokens) do
        local initiativeid = InitiativeQueue.GetInitiativeId(tok)
        if tokensByInitiative[initiativeid] == nil then
            tokensByInitiative[initiativeid] = tok
        else
            tokensByInitiative[initiativeid] = creature.GetSeniorToken{tokensByInitiative[initiativeid], tok}
        end
    end

    local playerTokens = {}
    local monsterTokens = {}

    for key,tok in pairs(tokensByInitiative) do
        if initiativeQueue:IsEntryPlayer(key) then
            playerTokens[#playerTokens+1] = tok.charid
        else
            monsterTokens[#monsterTokens+1] = tok.charid
        end
    end

    return RollInitiativeChatMessage.new{
        playerTokenIds = playerTokens,
        monsterTokenIds = monsterTokens,
        winner = initiativeQueue.playersGoFirst and "players" or "monsters",
    }
end

--- @return CharacterToken[]
function RollInitiativeChatMessage:GetPlayerTokens()
    local result = {}
    for _,charid in ipairs(self.playerTokenIds) do
        result[#result+1] = dmhub.GetCharacterById(charid)
    end
    return result
end

--- @return CharacterToken[]
function RollInitiativeChatMessage:GetMonsterTokens()
    local result = {}
    for _,charid in ipairs(self.monsterTokenIds) do
        result[#result+1] = dmhub.GetCharacterById(charid)
    end
    return result
end

Commands.rollinitiative = function(str)
    local tokens = dmhub.selectedTokens
    local info = GameHud.instance.initiativeInterface
    if info.initiativeQueue == nil or info.initiativeQueue.hidden then
        showDrawSteelBanner()
        return
    end

    if info.initiativeQueue == nil or info.initiativeQueue.hidden then
        info.initiativeQueue = InitiativeQueue.Create()
    end

    local message = RollInitiativeChatMessage.Create(info.initiativeQueue, tokens)
    chat.SendCustom(message)

    for _,tok in ipairs(tokens) do
        local initiativeId = InitiativeQueue.GetInitiativeId(tok)
        info.initiativeQueue:SetInitiative(initiativeId, 0, 0)

        tok.properties:DispatchEvent("rollinitiative", {})
        tok.properties:DispatchEvent("beginround")
    end

    info.UploadInitiative()
end

LaunchablePanel.Register{
	name = "DrawSteel",
	halign = "center",
	valign = "center",
    unframed = true,
    draggable = false,
	filtered = function()
        return true
	end,
	content = function(options)
		return createDrawSteelBanner(options)
	end,
}