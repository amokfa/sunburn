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
	{"speaker": "BX", "text": "Unfortunately there isn't much we can do"}
]
