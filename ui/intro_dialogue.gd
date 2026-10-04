extends RefCounted
## Intro dialogue. Preserve unlock, wait_altitude, and auto_advance_seconds fields when editing messages.
const MESSAGES := [
	{
		"speaker": "BX",
		"text": "Good morning, Lars!"
	},
	{
		"speaker": "Lars",
		"text": "Who is this?"
	},
	{
		"speaker": "BX",
		"text": "I am BX5, your ship's new AI assistant interface."
	},
	{
		"speaker": "BX",
		"text": "Your ship received a firmware update last night."
	},
	{
		"speaker": "BX",
		"text": "Would you like an overview of all the exciting new features added to your ship?"
	},
	{
		"speaker": "Lars",
		"text": "Nah, I'll pass."
	},
	{
		"speaker": "BX",
		"text": "As you wish."
	},
	{
		"speaker": "BX",
		"text": "At the very least, you should familiarize yourself with the new and improved ship controls."
	},
	{
		"speaker": "BX",
		"text": "What do you think?"
	},
	{
		"speaker": "Lars",
		"text": "All right, fine."
	},
	{
		"speaker": "BX",
		"text": "You can use the mouse to look around.",
		"unlock": "mouse"
	},
	{
		"speaker": "BX",
		"text": "Your ship will automatically turn to face the direction in which you're looking."
	},
	{
		"speaker": "BX",
		"text": "Hold 'Q' to lift off.",
		"unlock": "ascend",
		"wait_altitude": 50.0
	},
	{
		"speaker": "BX",
		"text": "Use 'E' to descend.",
		"unlock": "descend",
		"auto_advance_seconds": 2.0
	},
	{
		"speaker": "BX",
		"text": "Use 'W', 'S', 'A', and 'D' to move horizontally.",
		"unlock": "horizontal"
	},
	{
		"speaker": "BX",
		"text": "That covers the basics."
	},
	{
		"speaker": "BX",
		"text": "Try them out for a while, and let me know if you have any questions."
	}
]
