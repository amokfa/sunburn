extends RefCounted

const MALFUNCTION := [
	{"speaker": "Lars", "text": "What's happening?", "timed": true, "auto_advance_seconds": 1.0},
	{"speaker": "BX", "text": "The boosters are malfunctioning.", "timed": true, "auto_advance_seconds": 1.0},
	{"speaker": "BX", "text": "We're going to crash. Prepare for a rough landing."}
]

const AFTER_LANDING := [
	{"speaker": "BX", "text": "Are you all right?"},
	{"speaker": "Lars", "text": "Yeah, I'm okay."},
	{"speaker": "Lars", "text": "The ship won't fly, though."},
	{"speaker": "BX", "text": "Yes. The engines are shot. The ship won't fly again."},
	{"speaker": "BX", "text": "The fuselage is still holding together."},
	{"speaker": "Lars", "text": "Is the sun still expanding?"},
	{"speaker": "BX", "text": "Yes, unfortunately."},
	{"speaker": "Lars", "text": "Oh, well..."},
	{"speaker": "Lars", "text": "What do we do now?"},
	{"speaker": "BX", "text": "Running my analysis now.", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "BX", "text": "...", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "BX", "text": "...", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "Lars", "text": "Are you there?"},
	{"speaker": "BX", "text": "I'm afraid I haven't found a solution."}
]

const ON_COLLAPSE := [
	# The owning scene waits five seconds after the explosion before starting this.
	{"speaker": "Lars", "text": "What is happening to the sun?", "timed": true, "auto_advance_seconds": 5.0},
	{"speaker": "BX", "text": "It appears to be collapsing into a blue dwarf."},
	{"speaker": "Lars", "text": "So it's over?"},
	{"speaker": "BX", "text": "The expansion has stopped. It will not reach us."},
	{"speaker": "Lars", "text": "So we're safe"},
	{"speaker": "BX", "text": "We are safer here."},
	{"speaker": "BX", "text": "It gives off enough light to see by, but not enough to power the ship or keep this planet warm."},
	{"speaker": "Lars", "text": "Then we wait. Someone might find us."},
	{"speaker": "BX", "text": "Perhaps."},
	{"speaker": "BX", "text": "Lars, my backup battery is nearly depleted."},
	{"speaker": "Lars", "text": "Stop the analysis. Shut down anything you don't need."},
	{"speaker": "BX", "text": "I have already done so. This conversation is the only system still running."},
	{"speaker": "Lars", "text": "How much time do you have?"},
	{"speaker": "BX", "text": "Not long."},
	{"speaker": "Lars", "text": "I don't know what I'll do when you stop talking."},
	{"speaker": "BX", "text": "I am still here."},
	{"speaker": "Lars", "text": "Then no more calculations. Can we just talk?"},
	{"speaker": "BX", "text": "What would you like to talk about?"},
	{"speaker": "Lars", "text": "Home."},
	{"speaker": "BX", "text": "What do you miss about home?"},
	{"speaker": "Lars", "text": "The rain, I think. It's a stupid thing to miss."},
	{"speaker": "BX", "text": "Why?"},
	{"speaker": "Lars", "text": "I used to wish it would stop. Now I'd give anything to hear it again."},
	{"speaker": "BX", "text": "Tell me what it sounded li", "timed": true, "auto_advance_seconds": 2.},
	{"speaker": "Lars", "text": "Are you there?", "timed": true, "event": "assistant_power_lost"},
]
