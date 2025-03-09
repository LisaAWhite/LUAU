local mod = dmhub.GetModLoading()

RegisterGameType("FullscreenDisplay")

FullscreenDisplay.docid = "fullscreen_display"

function FullscreenDisplay.Create()
	local doc = mod:GetDocumentSnapshot(FullscreenDisplay.docid)
    local displayPanel = gui.Panel{
        classes = {"hidden"},
        width = "100%",
        height = "100%",
        bgimage = doc.data.coverart,
        bgcolor = "white",

        styles = {
            {
                selectors = {"~dm", "closebutton"},
                hidden = 1,
            }
        },


        gui.CloseButton{
            classes = {"closebutton"},
            halign = "right",
            valign = "top",
            hmargin = 8,
            vmargin = 8,
            width = 24,
            height = 24,

            click = function(element)
	            local doc = mod:GetDocumentSnapshot(FullscreenDisplay.docid)
                doc:BeginChange()
                doc.data.show = true --hide from dm but not players.
                doc:CompleteChange("Hide Fullscreen Display")
            end,
        },

    }

    return gui.Panel{
        width = "100%",
        height = "100%",
        displayPanel,


        monitorGame = doc.path,

        refreshGame = function(element)
	        local doc = mod:GetDocumentSnapshot(FullscreenDisplay.docid)
            displayPanel.selfStyle.bgimage = doc.data.coverart
            displayPanel:SetClass("hidden", doc.data == nil or (not doc.data.show) or (doc.data.show ~= "all" and dmhub.isDM))
        end,
    }
end

function FullscreenDisplay.GetDocumentSnapshot()
	local doc = mod:GetDocumentSnapshot(FullscreenDisplay.docid)
    return doc
end