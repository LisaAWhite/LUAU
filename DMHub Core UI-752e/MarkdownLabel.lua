local mod = dmhub.GetModLoading()


function gui.MarkdownLabel(args)
    local options = {
        markdown = true,
    }

    for k,v in pairs(args) do
        options[k] = v
    end

    return gui.Label(options)

end