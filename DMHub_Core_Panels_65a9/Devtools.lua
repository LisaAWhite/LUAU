local mod = dmhub.GetModLoading()

local function MultiplyTest(x, y, z)
    return x*y*z
end

DockablePanel.Register{
    name = "Dev Info",

	icon = mod.images.effectsIcon,
    devonly = true,
	folder = "Development Tools",

	content = function()
        return gui.Panel{
            width = "100%",
            height = "auto",
            flow = "vertical",
            gui.Label{
                fontSize = 12,
                width = "auto",
                height = "auto",
                create = function(element)
                    element:FireEvent("think")
                end,
                thinkTime = 0.01,
                think = function(element)
                    --local mem = collectgarbage("count")
                    local mem = 0
                    element.text = string.format("Time: %d\nLua Memory: %dMB\n%s", math.floor(dmhub.serverTime), math.floor(mem/1024), dmhub.debugPropertyOutput)
                end,
            },

            gui.Button{
                halign = "right",
                valign = "bottom",
                fontSize = 16,
                width = 80,
                height = 24,
                text = "Run GC",
                click = function(element)
                    collectgarbage("collect")
                    --collectgarbage("stop")
                end,
            },

            gui.Button{
                halign = "right",
                valign = "bottom",
                fontSize = 16,
                width = 80,
                height = 24,
                text = "Report",
                click = function(element)
                    dmhub:DebugUserDataReport()
                end,
            },
        }
	end,
}

DockablePanel.Register{
    name = "Brightness Test",

	icon = mod.images.effectsIcon,
    devonly = true,
	minHeight = 200,
	folder = "Development Tools",

	content = function()
        return gui.Panel{
            width = "100%",
            height = "auto",
            wrap = true,
            flow = "horizontal",
            create = function(element)
                local children = {}

                for i = 1,10 do
                children[#children+1] = gui.Panel{
                        width = 32,
                        height = 32,
                        hmargin = 16,
                        vmargin = 16,
                        bgimage = "panels/square.png",
                        bgcolor =  "srgb:#C09571", -- "white",
                        brightness = i,
                    }
                end


                element.children = children
            end,

        }
	end,
}

DockablePanel.Register{
    name = "Network Debugger",

	icon = mod.images.effectsIcon,
    devonly = true,
    vscroll = false,
	folder = "Development Tools",
    content = function()
        local filter = {}
        local resultPanel
        local scrollPanel
        local dataError = function(message)
            print("NETWORK ERROR:", message)
            scrollPanel:FireEvent("error", message)
        end
        local dataStreamed = function(method, path, data)
            scrollPanel:FireEvent("record", "stream", method, path, data)
        end
        local dataTransmitted = function(method, path, data)
            scrollPanel:FireEvent("record", "transmit", method, path, data)
        end
        scrollPanel = gui.Panel{
            width = "100%",
            height = "100%-32",
            flow = "vertical",
            vscroll = true,

            styles = {
                {
                    selectors = {"recordPanel"},
                    width = "100%",
                    height = "auto",
                    flow = "vertical",
                    bgimage = "panels/square.png",
                    pad = 4,
                    bgcolor = "black",
                    borderWidth = 1,
                    cornerRadius = 6,
                },
                {
                    selectors = {"recordPanel", "hover"},
                    brightness = 1.5,
                },
                {
                    selectors = {"recordPanel", "error"},
                    bgcolor = "#ffbbbb",
                },
                {
                    selectors = {"recordPanel", "stream"},
                    bgcolor = "#bbffbb",
                },
                {
                    selectors = {"recordPanel", "transmit"},
                    bgcolor = "#bbbbff",
                },
                {
                    selectors = {"recordLabel"},
                    color = "black",
                    fontSize = 14,
                    maxWidth = 300,
                    width = "auto",
                    height = "auto",
                },

            },

            clear = function(element)
                element.children = {}
            end,

            create = function(element)
                dmhub.DataStreamed = dataStreamed
                dmhub.DataTransmitted = dataTransmitted
                dmhub.DataError = dataError
            end,

            destroy = function(element)
                if dmhub.DataStreamed == dataStreamed then
                    dmhub.DataStreamed = nil
                end
                if dmhub.DataTransmitted == dataTransmitted then
                    dmhub.DataTransmitted = nil
                end
                if dmhub.DataError == dataError then
                    dmhub.DataError = nil
                end
            end,

            error = function(element, message)
                local panel = gui.Panel{
                    classes = {"recordPanel", "error"},
                    gui.Label{
                        classes = {"recordLabel"},
                        bold = true,
                        text = message,
                    },

                    filter = function(element)
                        if #filter == 0 then
                            element:SetClass("collapsed", false)
                        else
                            for _,f in ipairs(filter) do
                                local match = false
                                if string.find(message, f) then
                                    match = true
                                end

                                if match == false then
                                    element:SetClass("collapsed", true)
                                    return
                                end
                            end

                            element:SetClass("collapsed", false)
                        end
                    end,
                }

                element:AddChild(panel)
            end,

            record = function(element, recordType, method, path, data)
                local panel = gui.Panel{
                    press = function(element)
                        element:FireEventTree("expand")
                    end,

                    classes = { "recordPanel", recordType },

                    create = function(element)
                        element:FireEvent("filter")
                    end,

                    filter = function(element)
                        if #filter == 0 then
                            element:SetClass("collapsed", false)
                        else
                            for _,str in ipairs(filter) do
                                local negation = false
                                local f = str
                                if string.starts_with(f, "~") then
                                    negation = true
                                    f = string.sub(f, 2)
                                end

                                local match = false
                                if (not negation) and (string.find(recordType, f) or string.find(method, f) or string.find(path, f) or string.find(data, f)) then
                                    match = true
                                end

                                if negation and (not string.find(recordType, f)) and (not string.find(method, f)) and (not string.find(path, f)) and (not string.find(data, f)) then
                                    match = true
                                end

                                if match == false then
                                    element:SetClass("collapsed", true)
                                    return
                                end
                            end

                            element:SetClass("collapsed", false)
                        end
                    end,

                    gui.Label{
                        classes = {"recordLabel"},
                        bold = true,
                        text = path,
                    },
                    gui.Label{
                        classes = {"recordLabel"},
                        text = string.format("%s - %s - %d bytes - %.2fs", recordType, method, string.len(data), dmhub.Time()),
                    },
                    gui.Label{
                        classes = {"recordLabel", "collapsed", "uninit"},
                        width = "100%",
                        text = "",
                        expand = function(element)
                            element:SetClass("collapsed", not element:HasClass("collapsed"))
                            if element:HasClass("uninit") then
                                element:SetClass("uninit", false)
                                element.text = data
                            end
                        end,
                    }
                }

                element:AddChild(panel)

            end,

        }

        resultPanel = gui.Panel{
            width = "100%",
            height = "100%",
            flow = "vertical",
            gui.Panel{
                flow = "horizontal",
                width = "100%",
                height = "auto",
                gui.Input{
                    width = "70%",
                    halign = "left",
                    height = 16,
                    fontSize = 12,
                    placeholderText = "Filter...",
                    editlag = 0.3,
                    edit = function(element)
                        filter = string.split(element.text)
                        scrollPanel:FireEventTree("filter")
                    end,
                },
                gui.Button{
                    width = "15%",
                    height = 16,
                    fontSize = 10,
                    text = "Clear",
                    click = function(element)
                        resultPanel:FireEventTree("clear")
                    end,
                }
            },
            scrollPanel,
        }

        return resultPanel
    end,

}

DockablePanel.Register{
    name = "Sheet Perf",

	icon = mod.images.effectsIcon,
    devonly = true,
	minHeight = 200,
	folder = "Development Tools",
	content = function()
        local resultPanel
        resultPanel = gui.Panel{
            width = "100%",
            height = "100%",
            flow = "vertical",
            gui.Panel{
                width = "100%",
                height = "100%-60",
                vscroll = true,
                flow = "vertical",
                debugLogging = true,
                test = function(element)
                    local timer = dmhub.Stopwatch()
                    local timer2 = dmhub.Stopwatch()
                    local items = {}
                    for i = 1,1000 do
                        items[i] = gui.Panel{
                            width = 100,
                            height = 10,
                            vmargin = 4,
                            bgimage = "panels/square.png",
                            bgcolor = "red",
                        }
                    end

                    timer2:Stop()

                    element.children = items

                    timer:Stop()

                    resultPanel:FireEventTree("results", string.format("%d/%dms", timer2.milliseconds, timer.milliseconds))


                end,
            },

            gui.Button{
                width = 40,
                height = 20,
                fontSize = 14,
                text = "Click",
                click = function(element)
                    resultPanel:FireEventTree("test")
                end,
            },

            gui.Label{
                width = "100%",
                height = "auto",
                fontSize = 14,
                results = function(element, text)
                    element.text = text
                end,
            }
        }

        return resultPanel
    end,
}

DockablePanel.Register{
    name = "Texture Load",

	icon = mod.images.effectsIcon,
    devonly = true,
	minHeight = 200,
	folder = "Development Tools",
	content = function()
        local resultPanel = gui.Panel{
            width = "100%",
            height = "100%",
            flow = "vertical",
            vscroll = true,

            styles = {
                {
                    classes = {"label"},
                    fontSize = 12,
                    width = "auto",
                    height = "auto",
                    maxWidth = 100,
                }

            },

            texture = function(element, info)
                dmhub.Debug(string.format("TEXTURE:: %s", json(info)))
                local panel = gui.Panel{
                    width = "95%",
                    height = "auto",
                    halign = "left",
                    flow = "horizontal",
                    vmargin = 4,

                    gui.Panel{
                        width = 196,
                        height = 196,
                        gui.Panel{
                            bgimage = info.imageid,
                            bgcolor = "white",
                            autosizeimage = true,
                            width = "auto",
                            height = "auto",
                            maxWidth = 196,
                            maxHeight = 196,
                        }
                    },

                    gui.Panel{
                        width = 128,
                        height = "auto",
                        hmargin = 4,
                        flow = "vertical",
                        gui.Label{
                            text = cond(info.desc ~= nil, info.desc, info.imageid),
                        },
                        gui.Label{
                            text = string.format("%dx%d", info.width, info.height)
                        },
                        gui.Label{
                            text = string.format("%dms", info.time)
                        },
                        gui.Label{
                            text = string.format("%s", info.format)
                        },
                    }

                }

                element:AddChild(panel)
            end,

        }

        dmhub.GetTextureLoadEvent():Listen(resultPanel)

        return resultPanel
	end,
}