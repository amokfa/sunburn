extends RefCounted
## Intro dialogue. Preserve unlock, wait_altitude, and auto_advance_seconds fields when editing messages.
const MESSAGES := [
	{
		"speaker": "BX",
		"text": "Good morning Lars!"
	},
	{
		"speaker": "Lars",
		"text": "Who is this?"
	},
	{
		"speaker": "BX",
		"text": "I'm BX5, the new AI assistant interface for your ship!"
	},
	{
		"speaker": "BX",
		"text": "Your ship received a firmware update last night"
	},
	{
		"speaker": "BX",
		"text": "Would you like me to walk you through all the exciting new features that were added to your ship?"
	},
	{
		"speaker": "Lars",
		"text": "Nah, I'll pass."
	},
	{
		"speaker": "BX",
		"text": "As you wish!"
	},
	{
		"speaker": "BX",
		"text": "At the very least you should familiarize yourself with the new and improved ship controls."
	},
	{
		"speaker": "BX",
		"text": "What do you think?"
	},
	{
		"speaker": "Lars",
		"text": "Alright, fine!"
	},
	{
		"speaker": "BX",
		"text": "You can use the mouse to look around.",
		"unlock": "mouse"
	},
	{
		"speaker": "BX",
		"text": "Your ship will automatically turn to face the direction you're looking at."
	},
	{
		"speaker": "BX",
		"text": "Hold 'Q' to liftoff",
		"unlock": "ascend",
		"wait_altitude": 50.0
	},
	{
		"speaker": "BX",
		"text": "and 'E' to come back down",
		"unlock": "descend",
		"auto_advance_seconds": 2.0
	},
	{
		"speaker": "BX",
		"text": "Use 'W', 'S', 'A', and 'D' to move the ship horizontally.",
		"unlock": "horizontal"
	},
	{
		"speaker": "BX",
		"text": "And that's about it!"
	},
	{
		"speaker": "BX",
		"text": "Play with it for a while and let me know if you have any questions."
	}
]
