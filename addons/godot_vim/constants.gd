enum Mode { NORMAL, INSERT, VISUAL, VISUAL_LINE, COMMAND }

# Used for commands like "w" "b" and "e" respectively
enum WordEdgeMode { WORD, BEGINNING, END }

const SPACES: String = " \t"
const KEYWORDS: String = ".,\"'-=+!@#$%^&*()[]{}?~/\\<>:;"
const DIGITS: String = "0123456789"
