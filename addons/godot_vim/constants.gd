enum Mode {
	NORMAL = 0,
	INSERT,
	VISUAL,
	VISUAL_LINE,
	COMMAND
}

enum Language {
	GDSCRIPT,
	SHADER,
}

const KEYWORDS: String = ".,\"'-=+!@#$%^&*()[]{}?~/\\<>:;"
const DIGITS: String = "0123456789"
const SPACES: String = " \t"
