local mod = dmhub.GetModLoading()

local CreateHeightmapEditor

local g_heightSetting = setting{
    id = "heightmap:height",
    description = "Height",
    editor = "slider",
    format = "F1",
    min = -5,
    max = 5,
    default = 0,
    storage = "transient",
}

local g_gradientSetting = setting{
    id = "heightmap:gradient",
    description = "Gradient",
    editor = "dropdown",
    storage = "transient",
    default = "flat",
    enum = {
        {
            value = "flat",
            text = "Flat",
        },
        {
            value = "slope",
            text = "Slope",
        },
    },

    monitorVisible = {"heightmaptool"},
    visible = function()
        local tool = dmhub.GetSettingValue("heightmaptool")
        return tool == "rectangle" or tool == "oval" or tool == "shape"
    end,
}

local g_blendSetting = setting{
    id = "heightmap:blend",
    description = "BlendDistance",
    editor = "slider",
    format = "F1",
    min = 0,
    max = 1,
    default = 0,
    storage = "transient",
    monitorVisible = {"heightmaptool"},
    visible = function()
        local tool = dmhub.GetSettingValue("heightmaptool")
        return tool == "rectangle" or tool == "oval" or tool == "shape"
    end,
}

local g_opacitySetting = setting{
    id = "heightmap:opacity",
    description = "Strength",
    editor = "slider",
    format = "F1",
    min = 0,
    max = 1,
    default = 1,
    storage = "transient",
    monitorVisible = {"heightmaptool"},
    visible = function()
        local tool = dmhub.GetSettingValue("heightmaptool")
        return tool == "rectangle" or tool == "oval" or tool == "shape"
    end,
}

local g_shadingSetting = setting{
    id = "heightmap:shading",
    description = "Use Shadows",
    editor = "check",
    default = true,
    storage = "transient",
}

local g_overlayOpacitySetting = setting{
    id = "heightmap:opacitysetting",
    description = "Overlay Opacity",
    editor = "slider",
    default = 0.5,
    min = 0,
    max = 1,
    storage = "preference",
}

local g_overlayTypeSetting = setting{
    id = "heightmap:overlaytype",
    description = "Overlay",
    editor = "dropdown",
    default = "overlay",
    storage = "preference",
    enum = {
        {
            value = "none",
            text = "None",
        },
        {
            value = "overlay",
            text = "Overlay",
        },
        {
            value = "labels",
            text = "Labeled Overlay",
        },
    },
}

if dmhub.patronTier > 0 then
    DockablePanel.Register{
        name = "Elevation Editor",
        icon = "panels/hud/elevation-icon.png",
        vscroll = true,
        dmonly = true,
        minHeight = 200,
        folder = "Map Editing",
        stickyFocus = true,
        content = function()
            return CreateHeightmapEditor()
        end,
    }
end

local g_heightmapEditor = nil

CreateHeightmapEditor = function()
    local resultPanel

    resultPanel = gui.Panel{
        flow = "vertical",
        height = "auto",
        width = "100%",

        styles = Styles.formPanel,

        showpanel = function(element)
            if not gui.ChildHasFocus(element) then
                gui.SetFocus(element)
            end
        end,

        hidepanel = function(element)
            if gui.ChildHasFocus(element) then
                gui.SetFocus(nil)
            end
        end,
        
        childfocus = function(element)
            element:FindParentWithClass("dockablePanel"):SetClass("highlightPanel", true)
        end,

        childdefocus = function(element)
            element:FindParentWithClass("dockablePanel"):SetClass("highlightPanel", false)
        end,

        CreateSettingsEditor("heightmaptool"),

        --brush editor.
        gui.Panel{
            classes = {cond(dmhub.GetSettingValue("heightmaptool") ~= 'brush', 'collapsed')},
            width = "auto",
            height = "auto",
            monitor = "heightmaptool",
            events = {
                monitor = function(element)
                    element:SetClass("collapsed", dmhub.GetSettingValue("heightmaptool") ~= 'brush')
                end,
            },
            mod.shared.BrushEditorPanel("heightmapbrush"),
        },

        CreateSettingsEditor("heightmap:height"),
        CreateSettingsEditor("heightmap:blend"),
        CreateSettingsEditor("heightmap:opacity"),
        CreateSettingsEditor("heightmap:gradient"),
        CreateSettingsEditor("heightmap:overlaytype"),
        CreateSettingsEditor("heightmap:opacitysetting"),

    }

    g_heightmapEditor = resultPanel

    return resultPanel
end


dmhub.GetHeightEditingInfo = function()
    if g_heightmapEditor == nil or (not g_heightmapEditor.valid) or (not gui.ChildHasFocus(g_heightmapEditor)) then
        return nil
    end
    
    return {
        height = g_heightSetting:Get(),
        directional = g_gradientSetting:Get() == "slope",
        opacity = g_opacitySetting:Get(),
        blend = g_blendSetting:Get(),
    }
end

dmhub.SelectHeight = function(height)
    dmhub.SetSettingValue("heightmap:height", height)
end