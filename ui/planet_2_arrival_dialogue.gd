extends RefCounted
## Departure farewell is timed; the arrival conversation advances by click.
const FAREWELL := [
    {
        "speaker": "Lars",
        "text": "Here goes our planet",
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
        "text": "Yes",
        "event": "face_planet_2",
        "timed": true
    }
]

const ARRIVAL := [
    {
        "speaker": "BX",
        "text": "There are around 200 other ships on planet 2 right now",
        "event": "begin_combat"
    },
    {
        "speaker": "Lars",
        "text": "Great! We can work together to figure out what to do now."
    },
    {
        "speaker": "BX",
        "text": "I doubt that's going to happen as you expect"
    },
    {
        "speaker": "Lars",
        "text": "Why?"
    },
    {
        "speaker": "BX",
        "text": "Planet 2 has turned into a warzone"
    },
    {
        "speaker": "BX",
        "text": "Everyone is trying to kill everyone else"
    },
    {
        "speaker": "Lars",
        "text": "Why?"
    },
    {
        "speaker": "BX",
        "text": "The sun won't stop at planet 1. It'll keep expanding until planet 2 is destroyed as well"
    },
    {
        "speaker": "BX",
        "text": "The only hope of survival is jumping to planet 3"
    },
    {
        "speaker": "BX",
        "text": "However, all of the ships are very low on fuel after their jump from planet 1 to planet 2"
    },
    {
        "speaker": "BX",
        "text": "By my calculations, there's barely enough fuel on planet 2 for one ship to make the jump"
    },
    {
        "speaker": "BX",
        "text": "So the entire planet has turned into a battle royale"
    },
    {
        "speaker": "Lars",
        "text": "This is madness"
    },
    {
        "speaker": "BX",
        "text": "They are desperate"
    },
    {
        "speaker": "BX",
        "text": "There is no other choice"
    },
    {
        "speaker": "BX",
        "text": "I'll bring the weapon systems online"
    },
    {
        "speaker": "Lars",
        "text": "No"
    },
    {
        "speaker": "Lars",
        "text": "Eject the weapons module"
    },
    {
        "speaker": "Lars",
        "text": "We need to lose weight"
    },
    {
        "speaker": "BX",
        "text": "It doesn't matter how much weight we lose, we do not have enough fuel to reach planet 3"
    },
    {
        "speaker": "Lars",
        "text": "We aren't going to planet 3. We need to be agile to dodge the projectiles coming towards us."
    },
    {
        "speaker": "BX",
        "text": "That is a terrible decision."
    },
    {
        "speaker": "Lars",
        "text": "Do it",
        "next_delay_seconds": 2.0,
        "advance_event": "eject_weapons"
    },
    {
        "speaker": "BX",
        "text": "Weapons module ejected"
    },
    {
        "speaker": "BX",
        "text": "Before we descend on planet 2, I think we should talk about the software updates that were installed last night"
    },
    {
        "speaker": "Lars",
        "text": "Tell me"
    },
    {
        "speaker": "BX",
        "text": "Your sensor modules have been upgraded. Now they are capable of detecting combat vehicles that are trying to target you and highlight them on your HUD."
    },
    {
        "speaker": "BX",
        "text": "Should I enable that?"
    },
    {
        "speaker": "Lars",
        "text": "Sure",
        "next_delay_seconds": 2.0
    },
    {
        "speaker": "BX",
        "text": "ThreatWatch online",
        "event": "enable_threatwatch"
    },
    {
        "speaker": "Lars",
        "text": "Alright let's do it"
    },
    {
        "speaker": "BX",
        "text": "Best of luck"
    }
]

const PLANET2_OVERHEAT := [
	{
		"speaker": "Lars",
		"text": "What is happening?",
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
