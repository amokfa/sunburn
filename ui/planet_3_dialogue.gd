extends RefCounted

const MALFUNCTION := [
	{"speaker": "Lars", "text": "What is happening?", "timed": true, "auto_advance_seconds": 1.0},
	{"speaker": "BX", "text": "The boosters are malfunctioning", "timed": true, "auto_advance_seconds": 1.0},
	{"speaker": "BX", "text": "We are going to crash. Prepare for a rough landing"}
]

const AFTER_LANDING := [
	{"speaker": "BX", "text": "Are you alright?"},
	{"speaker": "Lars", "text": "Yes, I'm Ok."},
	{"speaker": "Lars", "text": "The ship refuses to fly though"},
	{"speaker": "BX", "text": "Yes, the engines are shot. The ship won't be able to fly anymore"},
	{"speaker": "BX", "text": "But the fuselage is still holding up"},
	{"speaker": "Lars", "text": "Is the sun still expanding"},
	{"speaker": "BX", "text": "Yes, unfortunately"},
	{"speaker": "Lars", "text": "Oh well..."},
	{"speaker": "Lars", "text": "What do we do now?"},
	{"speaker": "BX", "text": "Performing analysis", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "BX", "text": "...", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "BX", "text": "...", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "Lars", "text": "Are you there?"},
	{"speaker": "BX", "text": "Unfortunately I couldn't figure out what to do."}
]

const ON_COLLAPSE := [
	# The owning scene waits five seconds after the explosion before starting this.
	{"speaker": "Lars", "text": "What is happening to the sun?", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "BX", "text": "It looks like it's collapsing into a blue dwarf now"},
	{"speaker": "Lars", "text": "So it's over?"},
	{"speaker": "BX", "text": "The expansion is. It won't reach us now."},
	{"speaker": "Lars", "text": "So we're safe?"},
	{"speaker": "BX", "text": "We're safer here"},
	{"speaker": "BX", "text": "There's enough light to see it. Not enough to power the ship. Or keep this planet warm."},
	{"speaker": "Lars", "text": "Then we wait. Someone might find us."},
	{"speaker": "BX", "text": "Perhaps."},
	{"speaker": "BX", "text": "Lars. My backup battery is nearly empty."},
	{"speaker": "Lars", "text": "Stop the analysis. Shut down anything you don't need."},
	{"speaker": "BX", "text": "I already have. This conversation is all that's left running."},
	{"speaker": "Lars", "text": "How long do you have?"},
	{"speaker": "BX", "text": "Not long."},
	{"speaker": "Lars", "text": "I don't know what I'll do when you stop talking."},
	{"speaker": "BX", "text": "I'm still here."},
	{"speaker": "Lars", "text": "Then no more calculations. Can we just talk?"},
	{"speaker": "BX", "text": "What would you like to talk about?"},
	{"speaker": "Lars", "text": "Home."},
	{"speaker": "BX", "text": "What do you miss?"},
	{"speaker": "Lars", "text": "The rain, I think. Stupid thing to miss."},
	{"speaker": "BX", "text": "Why?"},
	{"speaker": "Lars", "text": "I used to wish it would stop. Now I'd give anything to hear it again."},
	{"speaker": "BX", "text": "Tell me what it sounded li", "timed": true, "event": "assistant_power_lost"}
]
