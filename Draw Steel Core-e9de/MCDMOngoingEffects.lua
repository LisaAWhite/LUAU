local mod = dmhub.GetModLoading()


CharacterOngoingEffect.durationOptions = {
	{
		id = 'turn',
		text = 'Until End of Turn',
	},
    {
        id = 'end_of_next_turn',
        text = "Until End of Target's Next Turn",
    },
	{
		id = 'rounds',
		text = 'Rounds (From Start of Turn)',
	},
	{
		id = 'rounds_end_turn',
		text = 'Rounds (From End of Turn)',
	},
	{
		id = 'until_rest',
		text = 'Until Short or Long Rest',
	},
	{
		id = 'until_long_rest',
		text = 'Until Long Rest',
	},
	{
		id = 'indefinite',
		text = 'Indefinitely',
	},
}