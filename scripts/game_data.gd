extends RefCounted
class_name GameData

const CHARACTERS: Array[Dictionary] = [
	{"name": "Time Scientist", "accent": Color("#72d5ff"), "passive": "First combo hit gains bonus stun.", "signature": "Big Bang", "bonus_damage": 1, "bonus_stun": 5},
	{"name": "Gravity Scientist", "accent": Color("#c18cff"), "passive": "Pulls and heavy hits deal bonus damage.", "signature": "Black Hole", "bonus_damage": 3, "bonus_stun": 2},
	{"name": "Swordsman", "accent": Color("#ff9c87"), "passive": "Precise attacks deal extra damage.", "signature": "Final Cut", "bonus_damage": 3, "bonus_stun": 0},
	{"name": "Activist", "accent": Color("#88efbd"), "passive": "Blocking restores a small amount of MP.", "signature": "Mass Voice", "bonus_damage": 1, "bonus_stun": 2},
	{"name": "Navigator", "accent": Color("#8ec6ff"), "passive": "Dodge actions restore MP.", "signature": "True North", "bonus_damage": 1, "bonus_stun": 1},
	{"name": "Astronomer", "accent": Color("#f3a6d6"), "passive": "Ultimates gain a celestial damage bonus.", "signature": "Comet Fall", "bonus_damage": 2, "bonus_stun": 2},
	{"name": "Chemist", "accent": Color("#96f09e"), "passive": "Charging restores MP faster.", "signature": "Catalyst Burst", "bonus_damage": 1, "bonus_stun": 1},
	{"name": "Philosopher", "accent": Color("#f6d36c"), "passive": "Blocking reduces incoming stun.", "signature": "Final Thesis", "bonus_damage": 0, "bonus_stun": 1},
	{"name": "Engineer", "accent": Color("#ffc16c"), "passive": "Guard moves absorb more damage.", "signature": "Titan Frame", "bonus_damage": 1, "bonus_stun": 2},
	{"name": "Strategist", "accent": Color("#c7b8ff"), "passive": "Medium attacks build extra stun.", "signature": "Grand Gambit", "bonus_damage": 1, "bonus_stun": 4},
	{"name": "Oracle", "accent": Color("#f6a9e1"), "passive": "The first move of each match hits harder.", "signature": "Last Prophecy", "bonus_damage": 2, "bonus_stun": 2},
	{"name": "Captain", "accent": Color("#72e3e7"), "passive": "Aggressive attacks break through guard.", "signature": "Full Sail", "bonus_damage": 3, "bonus_stun": 1}
]

const STYLE_MOVES: Dictionary = {
	"Chess": [
		{"name": "Pawn Push", "kind": "attack", "tier": "Basic", "damage": 12, "stun": 10, "cost": 0, "cue": "♟"},
		{"name": "Rook Wall", "kind": "block", "guard": 8, "stun": 0, "cost": 0, "cue": "♜"},
		{"name": "Bishop Slip", "kind": "dodge", "stun": 0, "cost": 0, "cue": "♝"},
		{"name": "Knight Fork", "kind": "attack", "tier": "Medium", "damage": 24, "stun": 20, "cost": 2, "cue": "♞"},
		{"name": "Pin", "kind": "trap", "damage": 18, "stun": 24, "cost": 2, "cue": "PIN"},
		{"name": "Castle", "kind": "block", "guard": 18, "stun": 0, "cost": 2, "cue": "CASTLE"}
	],
	"Checkers": [
		{"name": "Step Strike", "kind": "attack", "tier": "Basic", "damage": 12, "stun": 10, "cost": 0, "cue": "STEP"},
		{"name": "Back Row", "kind": "block", "guard": 8, "stun": 0, "cost": 0, "cue": "ROW"},
		{"name": "Side Step", "kind": "dodge", "stun": 0, "cost": 0, "cue": "DODGE"},
		{"name": "Jump Chain", "kind": "attack", "tier": "Medium", "damage": 24, "stun": 20, "cost": 2, "cue": "JUMP"},
		{"name": "Forced Capture", "kind": "trap", "damage": 18, "stun": 24, "cost": 2, "cue": "CAPTURE"},
		{"name": "King Me", "kind": "block", "guard": 18, "stun": 0, "cost": 2, "cue": "CROWN"}
	],
	"Ludo": [
		{"name": "Roll 1-6", "kind": "attack", "tier": "Basic", "damage": 12, "stun": 10, "cost": 0, "cue": "DICE", "random_damage": true},
		{"name": "Safe Token", "kind": "block", "guard": 8, "stun": 0, "cost": 0, "cue": "SAFE"},
		{"name": "Lucky Roll", "kind": "dodge", "stun": 0, "cost": 0, "cue": "ROLL"},
		{"name": "Double Dice", "kind": "attack", "tier": "Medium", "damage": 28, "stun": 20, "cost": 2, "cue": "DOUBLE", "random_damage": true},
		{"name": "Home Stretch", "kind": "charge", "charge": 1, "stun": 0, "cost": 0, "cue": "HOME"},
		{"name": "Token Trap", "kind": "trap", "damage": 18, "stun": 24, "cost": 2, "cue": "TRAP"}
	],
	"Cards": [
		{"name": "King of Spades", "kind": "attack", "tier": "Basic", "damage": 12, "stun": 10, "cost": 0, "cue": "KING ♠"},
		{"name": "Heart Guard", "kind": "block", "guard": 8, "stun": 0, "cost": 0, "cue": "♥"},
		{"name": "Club Shuffle", "kind": "dodge", "stun": 0, "cost": 0, "cue": "♣"},
		{"name": "Diamond Pierce", "kind": "attack", "tier": "Medium", "damage": 24, "stun": 20, "cost": 2, "cue": "♦"},
		{"name": "Wild Joker", "kind": "trap", "damage": 18, "stun": 24, "cost": 2, "cue": "JOKER"},
		{"name": "Bluff", "kind": "block", "guard": 18, "stun": 0, "cost": 2, "cue": "BLUFF"}
	],
	"Scrabble": [
		{"name": "Word Break", "kind": "attack", "tier": "Basic", "damage": 12, "stun": 10, "cost": 0, "cue": "WORD"},
		{"name": "Tile Shield", "kind": "block", "guard": 8, "stun": 0, "cost": 0, "cue": "SHIELD"},
		{"name": "Letter Drift", "kind": "dodge", "stun": 0, "cost": 0, "cue": "DRIFT"},
		{"name": "Crossword Burst", "kind": "attack", "tier": "Medium", "damage": 24, "stun": 20, "cost": 2, "cue": "CROSSWORD"},
		{"name": "Word Trap", "kind": "trap", "damage": 18, "stun": 24, "cost": 2, "cue": "TRAP"},
		{"name": "Rack Reset", "kind": "charge", "charge": 2, "stun": 0, "cost": 0, "cue": "RACK"}
	]
}

# Draft matchup bonuses from style_matchups.xlsx. Weak matchups do not reduce damage.
const STYLE_ADVANTAGE: Dictionary = {
	"Chess": {"Cards": 1.15, "Scrabble": 1.15},
	"Checkers": {"Chess": 1.15, "Ludo": 1.15},
	"Ludo": {"Chess": 1.15, "Cards": 1.15},
	"Cards": {"Checkers": 1.15, "Scrabble": 1.15},
	"Scrabble": {"Checkers": 1.15, "Ludo": 1.15}
}

const ULTIMATE_NAMES: Dictionary = {
	"Chess": ["Checkmate", "Big Bang", "Black Hole", "Final Cut", "Grand Gambit", "Comet Fall"],
	"Checkers": ["Triple Jump", "Crown Storm", "Back Row Breaker", "King's Gambit", "Forced March", "Final Capture"],
	"Ludo": ["6-6 Rush", "Lucky Streak", "Home Stretch", "Double Trouble", "Token Storm", "Grand Roll"],
	"Cards": ["Royal Flush", "Big Bang", "Black Hole", "Final Cut", "Grand Gambit", "Heart of the Deck"],
	"Scrabble": ["Word Storm", "Final Thesis", "Power Word", "Crossword King", "QZX Strike", "Last Letter"]
}

const ULTIMATE_PUZZLES: Dictionary = {
	"Chess": [
		{"prompt": "A king is attacked and has no legal escape. What is this?", "answers": ["Checkmate", "Stalemate", "Castling"], "correct": "Checkmate"},
		{"prompt": "Which piece moves in an L shape?", "answers": ["Knight", "Rook", "Bishop"], "correct": "Knight"},
		{"prompt": "Which piece can jump over other pieces?", "answers": ["Knight", "Queen", "Rook"], "correct": "Knight"},
		{"prompt": "Which piece may promote after reaching the far rank?", "answers": ["Pawn", "King", "Bishop"], "correct": "Pawn"},
		{"prompt": "The king cannot move, but is not in check. What is this?", "answers": ["Stalemate", "Checkmate", "Fork"], "correct": "Stalemate"},
		{"prompt": "Which piece moves diagonally any number of squares?", "answers": ["Bishop", "Rook", "Knight"], "correct": "Bishop"}
	],
	"Checkers": [
		{"prompt": "How does a checker capture an opponent piece?", "answers": ["Jump over it", "Trade places", "Roll a die"], "correct": "Jump over it"},
		{"prompt": "What happens when a checker reaches the far row?", "answers": ["It becomes a king", "It is removed", "It skips a turn"], "correct": "It becomes a king"},
		{"prompt": "In standard English draughts, how does a regular piece move?", "answers": ["Diagonally forward", "Straight sideways", "Any direction"], "correct": "Diagonally forward"},
		{"prompt": "Can a king move backward diagonally?", "answers": ["Yes", "No", "Only after a capture"], "correct": "Yes"},
		{"prompt": "What is a forced capture?", "answers": ["A jump must be taken", "A king must move", "A turn is skipped"], "correct": "A jump must be taken"},
		{"prompt": "What usually wins a checkers game?", "answers": ["Capture or block all enemy pieces", "Reach the center", "Collect six kings"], "correct": "Capture or block all enemy pieces"}
	],
	"Ludo": [
		{"prompt": "What is the highest total from two standard dice?", "answers": ["12", "10", "6"], "correct": "12"},
		{"prompt": "What roll commonly lets a token leave its yard?", "answers": ["Six", "One", "Any even number"], "correct": "Six"},
		{"prompt": "What happens when your token lands on an unprotected enemy token?", "answers": ["It sends it home", "Both tokens score", "You lose your turn"], "correct": "It sends it home"},
		{"prompt": "How does a token reach the finish?", "answers": ["By an exact count", "With any roll", "By rolling doubles"], "correct": "By an exact count"},
		{"prompt": "What protects a token on a marked safe square?", "answers": ["It cannot be captured there", "It moves twice", "It rolls for free"], "correct": "It cannot be captured there"},
		{"prompt": "What is the goal of Ludo?", "answers": ["Bring all tokens home", "Capture every opponent", "Own the most safe squares"], "correct": "Bring all tokens home"}
	],
	"Cards": [
		{"prompt": "Which poker hand is ten through ace, all in one suit?", "answers": ["Royal flush", "Full house", "Straight"], "correct": "Royal flush"},
		{"prompt": "How many suits are in a standard deck?", "answers": ["Four", "Three", "Five"], "correct": "Four"},
		{"prompt": "Which two suits are red?", "answers": ["Hearts and diamonds", "Spades and clubs", "Hearts and clubs"], "correct": "Hearts and diamonds"},
		{"prompt": "Which hand has three of one rank and two of another?", "answers": ["Full house", "Flush", "Two pair"], "correct": "Full house"},
		{"prompt": "Which hand is five consecutive ranks?", "answers": ["Straight", "Pair", "Three of a kind"], "correct": "Straight"},
		{"prompt": "What is the top rank in a standard poker hand?", "answers": ["Ace", "King", "Joker"], "correct": "Ace"}
	],
	"Scrabble": [
		{"prompt": "Type this seven-letter word: letters arranged into a meaningful unit.", "answers": ["WORDING", "READING", "SPELLER"], "correct": "WORDING"},
		{"prompt": "Type the two-letter word meaning a question for a reason.", "answers": ["WHY", "WHO", "HOW"], "correct": "WHY"},
		{"prompt": "Type the word for a crossing of words on a board.", "answers": ["CROSSWORD", "LETTER", "RACK"], "correct": "CROSSWORD"},
		{"prompt": "Type the word for a wooden game piece marked with a letter.", "answers": ["TILE", "BOARD", "POINT"], "correct": "TILE"},
		{"prompt": "Type the word for a permitted play in a game.", "answers": ["VALID", "VIOLET", "VALUE"], "correct": "VALID"},
		{"prompt": "Type the word for the points earned by a play.", "answers": ["SCORE", "SPACE", "SPELL"], "correct": "SCORE"}
	]
}

const RANKS: Array[String] = ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]

static func moves_for_style(style: String, unlocked_ultimates: int = 0, signature: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for move in STYLE_MOVES.get(style, STYLE_MOVES["Chess"]):
		result.append(move.duplicate(true))
	var names: Array = ULTIMATE_NAMES.get(style, ULTIMATE_NAMES["Chess"])
	for index in range(names.size()):
		var name: String = names[index]
		var move_signature: bool = name == signature
		result.append({
			"name": name,
			"kind": "ultimate",
			"tier": "Ultimate",
			"damage": 45 + index * 4,
			"stun": 40,
			"cost": 4,
			"cue": name.to_upper(),
			"challenge": style,
			"signature": move_signature,
			"unlock_level": index * 5,
			"locked": index >= unlocked_ultimates
		})
	if not signature.is_empty() and not names.has(signature):
		result.append({
			"name": signature,
			"kind": "ultimate",
			"tier": "Signature",
			"damage": 45,
			"stun": 40,
			"cost": 4,
			"cue": signature.to_upper(),
			"challenge": style,
			"signature": true,
			"unlock_level": 0,
			"locked": false
		})
	return result

static func legends_arts(signature: String, unlocked_ultimates: int = 1, style: String = "Chess") -> Array[Dictionary]:
	var style_specials: Dictionary = {"Chess": "Knight's Gambit", "Checkers": "Crown Breaker", "Ludo": "Grand Roll", "Cards": "Ace Breaker", "Scrabble": "Power Word"}
	var move_name := signature if not signature.is_empty() else str(style_specials.get(style, "Knight's Gambit"))
	var style_special := str(style_specials.get(style, "Knight's Gambit"))
	var result: Array[Dictionary] = [
		{"name": "Strike Arts", "kind": "attack", "tier": "Strike Arts", "damage": 22, "stun": 18, "cost": 1, "animation": "special_move", "cue": "STRIKE ARTS"},
		{"name": "Ki Blast", "kind": "attack", "tier": "Blast Arts", "damage": 14, "stun": 8, "cost": 1, "animation": "hadoken", "projectile": true, "projectile_range": 9.0, "cue": "KI BLAST"},
		{"name": "Power Up", "kind": "buff", "tier": "Special Skill", "damage_boost": 1.25, "duration": 4.0, "cost": 1, "animation": "charge", "cue": "POWER UP"},
		{"name": style_special, "kind": "attack", "tier": "Special Move", "damage": 42, "stun": 30, "cost": 3, "animation": "beam", "projectile": true, "projectile_range": 11.0, "signature": true, "cue": style_special.to_upper()},
		{"name": move_name, "kind": "attack", "tier": "Special Move", "damage": 38, "stun": 26, "cost": 3, "animation": "beam", "projectile": true, "projectile_range": 11.0, "signature": true, "cue": move_name.to_upper()},
		{"name": "Vanish Step", "kind": "dodge", "tier": "Special Skill", "stun": 0, "cost": 0, "cue": "VANISH"}
	]
	var ultimate_names: Array = ULTIMATE_NAMES.get(style, ULTIMATE_NAMES["Chess"])
	for index in range(ultimate_names.size()):
		var ultimate_name: String = ultimate_names[index]
		result.append({
			"name": ultimate_name,
			"kind": "ultimate",
			"tier": "Ultimate Arts",
			"damage": 90 + index * 5,
			"stun": 40 + index * 2,
			"cost": 4,
			"animation": "beam",
			"projectile": true,
			"projectile_range": 12.0,
			"signature": true,
			"unlock_level": index * 5,
			"locked": index >= unlocked_ultimates,
			"cue": "ULTIMATE ARTS"
		})
	return result

static func ultimate_puzzle(style: String, index: int) -> Dictionary:
	var puzzles: Array = ULTIMATE_PUZZLES.get(style, ULTIMATE_PUZZLES["Chess"])
	return puzzles[posmod(index, puzzles.size())].duplicate(true)
