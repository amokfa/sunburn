extends RefCounted
## Departure farewell is timed; the arrival conversation advances by click.
const FAREWELL := [
	{
		"speaker": "Lars",
		"text": "There goes our planet.",
		"auto_advance_seconds": 1.0,
		"timed": true
	},
	{
		"speaker": "Lars",
		"text": "Did anyone else make it?",
		"auto_advance_seconds": 1.0,
		"timed": true
	},
	{
		"speaker": "BX",
		"text": "Yes.",
		"event": "face_planet_2",
		"timed": true
	}
]

const ARRIVAL := [
	{
		"speaker": "BX",
		"text": "Approximately 200 other ships are currently on planet 2.",
		"event": "begin_combat"
	},
	{
		"speaker": "Lars",
		"text": "Great! We can work together and figure out what to do."
	},
	{
		"speaker": "BX",
		"text": "I doubt it will work out as you expect."
	},
	{
		"speaker": "Lars",
		"text": "Why?"
	},
	{
		"speaker": "BX",
		"text": "Planet 2 has become a war zone."
	},
	{
		"speaker": "BX",
		"text": "Every ship is trying to kill every other ship."
	},
	{
		"speaker": "Lars",
		"text": "Why?"
	},
	{
		"speaker": "BX",
		"text": "The sun will not stop at planet 1. It will continue expanding until it destroys planet 2 as well."
	},
	{
		"speaker": "BX",
		"text": "Our only hope of survival is to reach planet 3."
	},
	{
		"speaker": "BX",
		"text": "However, all the ships are running low on fuel after the jump from planet 1 to planet 2."
	},
	{
		"speaker": "BX",
		"text": "By my calculations, there is barely enough fuel on planet 2 for one ship to make the jump."
	},
	{
		"speaker": "BX",
		"text": "So everyone on this planet wants everyone else's fuel."
	},
	{
		"speaker": "Lars",
		"text": "This is madness."
	},
	{
		"speaker": "BX",
		"text": "They are desperate."
	},
	{
		"speaker": "BX",
		"text": "There is no other choice."
	},
	{
		"speaker": "BX",
		"text": "I will bring the weapons systems online."
	},
	{
		"speaker": "Lars",
		"text": "No."
	},
	{
		"speaker": "Lars",
		"text": "Eject the weapons module."
	},
	{
		"speaker": "Lars",
		"text": "We need to shed some weight."
	},
	{
		"speaker": "BX",
		"text": "It does not matter how much weight we lose; we still do not have enough fuel to reach planet 3."
	},
	{
		"speaker": "Lars",
		"text": "We're not going to planet 3. We need to be agile enough to dodge the incoming projectiles."
	},
	{
		"speaker": "BX",
		"text": "That is a terrible decision."
	},
	{
		"speaker": "Lars",
		"text": "Do it.",
		"next_delay_seconds": 2.0,
		"advance_event": "eject_weapons"
	},
	{
		"speaker": "BX",
		"text": "Weapons module ejected."
	},
	{
		"speaker": "BX",
		"text": "Before we descend to planet 2, we should discuss the software updates installed last night."
	},
	{
		"speaker": "Lars",
		"text": "Go on."
	},
	{
		"speaker": "BX",
		"text": "Your sensor modules have been upgraded. They can now detect combat vehicles targeting you and highlight them on your HUD."
	},
	{
		"speaker": "BX",
		"text": "Should I enable that?"
	},
	{
		"speaker": "Lars",
		"text": "Sure.",
		"next_delay_seconds": 2.0
	},
	{
		"speaker": "BX",
		"text": "ThreatWatch online",
		"event": "enable_threatwatch"
	},
	{
		"speaker": "Lars",
		"text": "All right, let's do it."
	},
	{
		"speaker": "BX",
		"text": "Best of luck"
	}
]

const PLANET2_OVERHEAT := [
	{
		"speaker": "Lars",
		"text": "What's happening?",
		"auto_advance_seconds": 3.0,
		"timed": true
	},
	{
		"speaker": "BX",
		"text": "Apparently the elevated temperature has caused the weapon modules to explode inside all these ships"
	}
]

const PLANET2_FUEL := [
	{
		"speaker": "BX",
		"text": "I suggest we scavange the fuel cells from the destroyed ships and jump to planet 3"
	},
	{
		"speaker": "Lars",
		"text": "Alright"
	}
]
