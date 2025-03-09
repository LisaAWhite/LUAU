local mod = dmhub.GetModLoading()

DockablePanel.Register{
	name = "Dice",
	icon = mod.images.diceIcon,
	notitle = true,
	vscroll = false,
    dmonly = false,
	minHeight = 68,
	maxHeight = 68,
	content = function()
		return nil
	end,
}
