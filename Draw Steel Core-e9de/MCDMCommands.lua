local mod = dmhub.GetModLoading()

--rename rollinitiative command to "Draw Steel!"
Commands.Register{
	name = "Draw Steel!",
    identifier = "rollinitiative",
	command = "rollinitiative",
	dmonly = true,
	icon = "panels/initiative/initiative-icon.png",
}