extends Control

signal closed

const DARK := Color("#14201e")
const PANEL := Color("#20322d")
const ACCENT := Color("#e5c879")
const LIGHT_SQUARE := Color("#d9c99f")
const DARK_SQUARE := Color("#537359")
const COLORS: Array[Color] = [
	Color("#d95c59"), Color("#e8bd50"), Color("#4b9b71"), Color("#5685d6")
]
const COLOR_NAMES: Array[String] = ["Red", "Yellow", "Green", "Blue"]
const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]
const TILE_VALUES := {
	"A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2,
	"H": 4, "I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1,
	"O": 1, "P": 3, "Q": 10, "R": 1, "S": 1, "T": 1, "U": 1,
	"V": 4, "W": 4, "X": 8, "Y": 4, "Z": 10, "?": 0
}
const SCRABBLE_WORDS := {
	"A": "A I AN AM AS AT BE BY DO GO HE HI IF IN IS IT ME MY NO OF OH ON OR OX SO TO UP US WE",
	"B": "BAD BAG BAN BAR BAT BAY BED BEE BEG BET BIG BIN BIT BOW BOX BOY BUG BUS BUT BUY BYE",
	"C": "CAB CAN CAP CAR CAT COP COT COW CUB CUP CUT",
	"D": "DAD DAM DAY DEN DID DIE DIG DIM DIP DOG DOT DRY DUE DUG",
	"E": "EAR EAT EGG EGO ELF ELM END ERA",
	"F": "FAB FAN FAR FAT FED FEE FEW FIG FIN FIT FIX FLY FOG FOR FOX FUN",
	"G": "GAP GAS GAY GET GIG GIN GOD GOT GUM GUN GUT GUY",
	"H": "HAD HAM HAS HAT HAY HEN HER HID HIM HIP HIS HIT HOG HOT HOW HUG",
	"I": "ICE ICK",
	"J": "JAB JAG JAM JAR JAW JAY JET JIG JOB JOG JOT JOY JUG",
	"K": "KEG KEY KID KIN KIT",
	"L": "LAB LAG LAP LAW LAY LED LEG LET LID LIE LIP LIT LOG LOT LOW",
	"M": "MAD MAN MAP MAT MAY MEN MET MID MIX MOB MOP MUD MUG",
	"N": "NAG NAP NET NEW NOD NOR NOT NOW NUN NUT",
	"O": "OAK OAR OAT ODD ODE OFF OIL OLD ONE OUR OUT OWE OWN",
	"P": "PAD PAL PAN PAR PAT PAW PAY PEA PEE PEN PER PET PIE PIG PIN PIT POD POT PRO PUB PUG",
	"Q": "QAT QIS",
	"R": "RAG RAN RAP RAT RAW RAY RED RIB RID RIG RIP ROB ROD ROT ROW RUB RUG RUN RUT",
	"S": "SAD SAG SAP SAT SAW SAY SEA SEE SET SEW SHE SHY SIR SIT SIX SKI SKY SLY SOB SOD SON SUN",
	"T": "TAB TAG TAN TAP TAR TAX TEA TEN THE TIE TIN TIP TOE TON TOO TOP TOY TRY TUB TWO",
	"U": "USE",
	"V": "VAN VAT VET VIA VIE VOW",
	"W": "WAD WAG WAR WAS WAY WEB WED WET WHO WHY WIG WIN WIT WOK WON WOO WOW",
	"X": "XIS",
	"Y": "YAK YAM YAP YAW YEA YEN YES YET YEW YIN YIP YOU YUP",
	"Z": "ZAG ZAP ZED ZEE ZIG ZIP ZIT ZOO",
	"LONG": "ABLE ABOUT ABOVE ACT ADD AFTER AGAIN AGE AGO AID AIM AIR ALL ALSO ALT AMONG AND ANT ANY ARE ARM ART ASK ATE AWAY BACK BAKE BALL BAND BANK BASE BATH BEAN BEAR BEAT BEEN BELL BELT BEST BIRD BLOW BLUE BOAT BODY BOOK BOOT BOTH BOWL BULK BURN BUSY CALL CALM CAME CAMP CARD CARE CASE CASH CAST CELL CENT CHAT CHEAP CHECK CHEST CHIEF CHILD CHIP CITY CLAY CLUB COAL COAT COLD COME COOK COOL COPY COST COULD COUNT COWS CREW CROP DARK DATA DATE DAWN DEAL DEAR DEBT DECK DEEP DESK DIAL DICE DIET DIRT DISH DOCK DOES DONE DOOR DOWN DRAW DROP DRUG DUAL DUCK DULL DUST EACH EARN EASE EAST EASY EDGE ELSE EVEN EVER EVIL EXAM FACE FACT FAIL FAIR FALL FARM FAST FEAR FEED FEEL FILE FILL FILM FIND FINE FIRE FIRM FISH FIVE FLAT FLOW FOOD FOOT FORM FORT FOUR FREE FROM FUEL FULL FUND GAME GATE GAVE GEAR GIFT GIRL GIVE GLAD GOAL GOAT GOES GOLD GONE GOOD GRAB GRAY GREW GRIP GROW HAIR HALF HAND HANG HARD HARM HATE HAVE HEAD HEAR HEAT HELD HELP HERB HERE HERO HIDE HIGH HILL HINT HIRE HOLD HOLE HOME HOPE HOST HOUR HUGE HUNG HUNT IDEA INTO IRON ITEM JOIN JOKE JUMP JURY JUST KEEP KEPT KICK KIND KING KNEW KNOW LACK LADY LAID LAKE LAND LANE LAST LATE LEAD LEAF LEAN LEFT LESS LIFT LIKE LINE LINK LIST LIVE LOAD LOAN LOCK LONG LOOK LORD LOSE LOST LOVE MADE MAIL MAIN MAKE MALE MANY MARK MASS MATE MEAL MEAN MEAT MEET MENU MILE MILK MIND MINE MISS MODE MOOD MOON MORE MOST MOVE MUCH MUST NAME NEAR NECK NEED NEWS NEXT NICE NINE NODE NONE NOSE NOTE ONCE ONLY OPEN OVER PACK PAGE PAID PAIN PAIR PALE PALM PARK PART PASS PAST PATH PEAK PICK PILE PINK PIPE PLAN PLAY PLOT PLUS POEM POET POLE POLL POOL POOR PORT POST PULL PURE PUSH PUTS RACE RACK RAIL RAIN RANK RATE READ REAL REAR REED REST RICE RICH RIDE RING RISE ROAD ROCK ROLE ROLL ROOF ROOM ROOT ROSE RULE SAFE SAGE SAID SAIL SALE SAME SAND SAVE SEAT SEED SEEK SEEM SEEN SELF SELL SEND SENT SHIP SHOP SHOW SHUT SICK SIDE SIGN SILK SING SINK SITE SIZE SKIN SLIP SLOW SNOW SOFT SOIL SOLD SOME SONG SOON SORT SOUL SPIN SPOT STAR STAY STEP STOP SUCH SUIT SURE TAKE TALE TALK TALL TANK TAPE TASK TEAM TEAR TELL TEND TERM TEST TEXT THAN THAT THEM THEN THEY THIN THIS THUS TIDE TIED TIER TILL TIME TINY TOLD TONE TOOL TOUR TOWN TREE TRIP TRUE TUBE TUNE TURN TWIN TYPE UNIT UPON USED USER VARY VAST VERY VIEW VISA VOID VOICE WAIT WAKE WALK WALL WANT WARM WASH WAVE WAYS WEAR WEEK WELL WENT WEST WHAT WHEN WIDE WIFE WILD WILL WIND WINE WING WIRE WISE WISH WITH WORD WORK YARD YEAR YOUR ZERO ZONE"
}

var rng := RandomNumberGenerator.new()
var shell: VBoxContainer
var board_area: Control
var status_label: Label
var title_label: Label
var action_row: HBoxContainer
var game_name := ""
var game_state: Dictionary = {}
var selected_square := -1
var selected_tile := -1
var selected_blank_letter := "E"
var pending_tiles: Dictionary = {}
var scrabble_passes := 0
var scrabble_word_set: Dictionary = {}
var scrabble_words: Array[String] = []

func _ready() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_show_menu()

func _build_shell() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.055, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)
	shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	margin.add_child(shell)
	var header := HBoxContainer.new()
	shell.add_child(header)
	title_label = Label.new()
	title_label.text = "BOARD GAMES"
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.add_theme_color_override("font_color", ACCENT)
	header.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var back := Button.new()
	back.text = "BACK TO FIGHT"
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)
	status_label = Label.new()
	status_label.text = "Choose a game to play against the AI."
	status_label.add_theme_font_size_override("font_size", 15)
	shell.add_child(status_label)
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	shell.add_child(action_row)
	board_area = Control.new()
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(board_area)

func _clear_area(area: Node) -> void:
	for child in area.get_children():
		child.queue_free()

func _show_menu() -> void:
	game_name = ""
	title_label.text = "BOARD GAMES"
	status_label.text = "Choose a complete game. You play the light side against the AI."
	_clear_area(action_row)
	_clear_area(board_area)
	var choices := [
		["Chess", "CHESS", "Standard chess · check, castling, promotion"],
		["Checkers", "CHECKERS", "Forced captures · multi-jumps · kings"],
		["Ludo", "LUDO", "Four colors · dice · capture · race home"],
		["Cards", "CRAZY EIGHTS", "Classic shedding game · choose suits"],
		["Scrabble", "SCRABBLE", "Place words · premium squares · score"]
	]
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	column.anchor_left = 0.18
	column.anchor_right = 0.82
	column.anchor_top = 0.2
	column.anchor_bottom = 0.8
	board_area.add_child(column)
	for choice in choices:
		var button := Button.new()
		button.text = "%s     ·     %s" % [choice[1], choice[2]]
		button.custom_minimum_size.y = 66
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_start_game.bind(choice[0]))
		column.add_child(button)

func _start_game(name: String) -> void:
	_play_sfx("ui_confirm", -12.0)
	game_name = name
	selected_square = -1
	selected_tile = -1
	pending_tiles.clear()
	scrabble_passes = 0
	title_label.text = name.to_upper() if name != "Cards" else "CRAZY EIGHTS"
	_clear_area(action_row)
	if name == "Chess":
		_start_chess()
	elif name == "Checkers":
		_start_checkers()
	elif name == "Ludo":
		_start_ludo()
	elif name == "Cards":
		_start_cards()
	elif name == "Scrabble":
		_start_scrabble()

func _action(text: String, callback: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(func() -> void:
		_play_sfx("ui_click", -16.0)
		callback.call()
	)
	action_row.add_child(button)
	return button

func _play_sfx(sound_name: String, volume_db := -8.0, pitch_variation := 0.0) -> void:
	get_node("/root/GameAudio").call("play_sfx", sound_name, volume_db, pitch_variation)

func _board_grid(columns: int) -> GridContainer:
	_clear_area(board_area)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_area.add_child(grid)
	return grid

func _position_to_xy(square: int, width: int) -> Vector2i:
	return Vector2i(square % width, square / width)

func _xy_to_position(x: int, y: int, width: int) -> int:
	return y * width + x

func _chess_piece(side: int, kind: String) -> String:
	return kind if side == 1 else kind.to_lower()

func _start_chess() -> void:
	var cells: Array[String] = []
	cells.resize(64)
	cells.fill("")
	var back_row := ["R", "N", "B", "Q", "K", "B", "N", "R"]
	for x in range(8):
		cells[x] = _chess_piece(-1, back_row[x])
		cells[8 + x] = "p"
		cells[48 + x] = "P"
		cells[56 + x] = back_row[x]
	game_state = {
		"board": cells, "turn": 1, "castle": {"K": true, "Q": true, "k": true, "q": true},
		"ep": -1, "over": false, "ply": 0
	}
	status_label.text = "Your move · White"
	_render_chess()

func _render_chess() -> void:
	_clear_area(board_area)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 8
	center.add_child(grid)
	var legal_targets: Array[int] = []
	if selected_square >= 0:
		for move in _chess_moves_from(selected_square, 1, game_state.board):
			legal_targets.append(move.to)
	for index in range(64):
		var x := index % 8
		var y := index / 8
		var button := Button.new()
		button.custom_minimum_size = Vector2(64, 56)
		var piece: String = game_state.board[index]
		button.text = _chess_glyph(piece)
		if index in legal_targets:
			button.text = "•\n" + button.text
		var shade := LIGHT_SQUARE if (x + y) % 2 == 0 else DARK_SQUARE
		if index == selected_square:
			shade = ACCENT
		button.add_theme_color_override("font_color", Color("#111915") if piece.to_lower() == piece and not piece.is_empty() else Color("#f8f3df"))
		button.add_theme_font_size_override("font_size", 32)
		button.add_theme_stylebox_override("normal", _square_style(shade))
		button.add_theme_stylebox_override("hover", _square_style(shade.lightened(0.12)))
		button.pressed.connect(_on_chess_square.bind(index))
		grid.add_child(button)
	_action("GAME MENU", _show_menu)
	_action("NEW GAME", _start_chess)
	_action("RULES", _show_rules.bind("Chess"))

func _square_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_border_width_all(1)
	style.border_color = Color(0.08, 0.12, 0.1, 0.65)
	return style

func _chess_glyph(piece: String) -> String:
	if piece.is_empty():
		return ""
	var glyphs := {"K": "♔", "Q": "♕", "R": "♖", "B": "♗", "N": "♘", "P": "♙",
		"k": "♚", "q": "♛", "r": "♜", "b": "♝", "n": "♞", "p": "♟"}
	return glyphs.get(piece, piece)

func _on_chess_square(index: int) -> void:
	if game_state.over or game_state.turn != 1:
		return
	var piece: String = game_state.board[index]
	if selected_square >= 0:
		for move in _chess_moves_from(selected_square, 1, game_state.board):
			if move.to == index:
				_play_sfx("board_capture" if not piece.is_empty() else "board_move", -12.0, 0.04)
				_play_chess_move(move)
				selected_square = -1
				_render_chess()
				if not game_state.over:
					_ai_chess_turn()
				return
	if not piece.is_empty() and piece == piece.to_upper():
		selected_square = index
	else:
		selected_square = -1
	_render_chess()

func _chess_side(piece: String) -> int:
	if piece.is_empty():
		return 0
	return 1 if piece == piece.to_upper() else -1

func _chess_attacked(square: int, by_side: int, board: Array) -> bool:
	var pos := _position_to_xy(square, 8)
	var pawn_source_y: int = pos.y + 1 if by_side == 1 else pos.y - 1
	for dx in [-1, 1]:
		var px: int = pos.x + dx
		if px >= 0 and px < 8 and pawn_source_y >= 0 and pawn_source_y < 8:
			var pawn: String = board[_xy_to_position(px, pawn_source_y, 8)]
			if pawn == _chess_piece(by_side, "P"):
				return true
	var knight_steps := [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
		Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
	for step in knight_steps:
		var x: int = pos.x + step.x
		var y: int = pos.y + step.y
		if x >= 0 and x < 8 and y >= 0 and y < 8 and board[_xy_to_position(x, y, 8)] == _chess_piece(by_side, "N"):
			return true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var x: int = pos.x + dx
			var y: int = pos.y + dy
			if x >= 0 and x < 8 and y >= 0 and y < 8:
				var adjacent: String = board[_xy_to_position(x, y, 8)]
				if adjacent == _chess_piece(by_side, "K"):
					return true
	var directions := [
		[Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)],
		[Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	]
	for group in range(2):
		for direction in directions[group]:
			var x: int = pos.x + direction.x
			var y: int = pos.y + direction.y
			var first := true
			while x >= 0 and x < 8 and y >= 0 and y < 8:
				var target: String = board[_xy_to_position(x, y, 8)]
				if not target.is_empty():
					if _chess_side(target) == by_side:
						var kind := target.to_upper()
						if kind == "Q" or (group == 0 and kind == "R") or (group == 1 and kind == "B") or (first and kind == "K"):
							return true
					break
				first = false
				x += direction.x
				y += direction.y
	return false

func _chess_in_check(side: int, board: Array) -> bool:
	var king_square := -1
	for index in range(64):
		if board[index] == _chess_piece(side, "K"):
			king_square = index
			break
	if king_square < 0:
		return true
	return _chess_attacked(king_square, -side, board)

func _chess_moves_from(square: int, side: int, board: Array, test_king := true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var piece: String = board[square]
	if piece.is_empty() or _chess_side(piece) != side:
		return result
	var origin := _position_to_xy(square, 8)
	var kind := piece.to_upper()
	var candidates: Array[Dictionary] = []
	if kind == "P":
		var step := -1 if side == 1 else 1
		var next_y := origin.y + step
		if next_y >= 0 and next_y < 8:
			var forward := _xy_to_position(origin.x, next_y, 8)
			if board[forward].is_empty():
				candidates.append({"from": square, "to": forward})
				var start_y := 6 if side == 1 else 1
				var double_y := origin.y + step * 2
				if origin.y == start_y and board[_xy_to_position(origin.x, double_y, 8)].is_empty():
					candidates.append({"from": square, "to": _xy_to_position(origin.x, double_y, 8), "double": true})
			for dx in [-1, 1]:
				var x: int = origin.x + dx
				if x < 0 or x >= 8:
					continue
				var target := _xy_to_position(x, next_y, 8)
				if not board[target].is_empty() and _chess_side(board[target]) == -side and board[target].to_upper() != "K":
					candidates.append({"from": square, "to": target})
				elif target == int(game_state.get("ep", -1)):
					candidates.append({"from": square, "to": target, "en_passant": true})
	elif kind == "N":
		for step in [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
			Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]:
			_add_chess_candidate(candidates, board, origin.x + step.x, origin.y + step.y, square, side)
	elif kind == "K":
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx != 0 or dy != 0:
					_add_chess_candidate(candidates, board, origin.x + dx, origin.y + dy, square, side)
		var rights: Dictionary = game_state.get("castle", {})
		var home_y := 7 if side == 1 else 0
		var king_right := "K" if side == 1 else "k"
		var queen_right := "Q" if side == 1 else "q"
		if origin == Vector2i(4, home_y) and not _chess_in_check(side, board):
			if rights.get(king_right, false) and board[_xy_to_position(5, home_y, 8)].is_empty() and board[_xy_to_position(6, home_y, 8)].is_empty() and not _chess_attacked(_xy_to_position(5, home_y, 8), -side, board) and not _chess_attacked(_xy_to_position(6, home_y, 8), -side, board):
				candidates.append({"from": square, "to": _xy_to_position(6, home_y, 8), "castle": "king"})
			if rights.get(queen_right, false) and board[_xy_to_position(1, home_y, 8)].is_empty() and board[_xy_to_position(2, home_y, 8)].is_empty() and board[_xy_to_position(3, home_y, 8)].is_empty() and not _chess_attacked(_xy_to_position(3, home_y, 8), -side, board) and not _chess_attacked(_xy_to_position(2, home_y, 8), -side, board):
				candidates.append({"from": square, "to": _xy_to_position(2, home_y, 8), "castle": "queen"})
	else:
		var dirs: Array[Vector2i] = []
		if kind in ["R", "Q"]:
			dirs.append_array([Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN])
		if kind in ["B", "Q"]:
			dirs.append_array([Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])
		for direction in dirs:
			var x := origin.x + direction.x
			var y := origin.y + direction.y
			while x >= 0 and x < 8 and y >= 0 and y < 8:
				var target_square := _xy_to_position(x, y, 8)
				var target: String = board[target_square]
				if target.is_empty():
					candidates.append({"from": square, "to": target_square})
				else:
					if _chess_side(target) == -side and target.to_upper() != "K":
						candidates.append({"from": square, "to": target_square})
					break
				x += direction.x
				y += direction.y
	for move in candidates:
		var copy: Array = board.duplicate()
		_apply_chess_board_move(copy, move, side)
		if not test_king or not _chess_in_check(side, copy):
			result.append(move)
	return result

func _add_chess_candidate(candidates: Array[Dictionary], board: Array, x: int, y: int, from: int, side: int) -> void:
	if x < 0 or x >= 8 or y < 0 or y >= 8:
		return
	var target := _xy_to_position(x, y, 8)
	if board[target].is_empty() or (_chess_side(board[target]) == -side and board[target].to_upper() != "K"):
		candidates.append({"from": from, "to": target})

func _play_chess_move(move: Dictionary) -> void:
	_update_chess_rights(move, 1)
	_apply_chess_board_move(game_state.board, move, 1)
	game_state.ep = -1
	if move.get("double", false):
		game_state.ep = int((move.from + move.to) / 2)
	game_state.turn = -1
	game_state.ply += 1
	_update_chess_status("AI to move · Black")

func _update_chess_rights(move: Dictionary, side: int) -> void:
	var piece: String = game_state.board[move.from]
	var captured: String = game_state.board[move.to]
	var rook_home := {"K": 63, "Q": 56, "k": 7, "q": 0}
	if piece.to_upper() == "K":
		if side == 1:
			game_state.castle.K = false
			game_state.castle.Q = false
		else:
			game_state.castle.k = false
			game_state.castle.q = false
	for right in rook_home:
		if (piece.to_upper() == "R" and move.from == rook_home[right]) or (captured.to_upper() == "R" and move.to == rook_home[right]):
			game_state.castle[right] = false

func _apply_chess_board_move(board: Array, move: Dictionary, side: int) -> void:
	var piece: String = board[move.from]
	board[move.from] = ""
	if move.get("en_passant", false):
		var captured_square: int = move.to + (8 if side == 1 else -8)
		board[captured_square] = ""
	if move.has("castle"):
		var row := 7 if side == 1 else 0
		if move.castle == "king":
			board[_xy_to_position(5, row, 8)] = board[_xy_to_position(7, row, 8)]
			board[_xy_to_position(7, row, 8)] = ""
		else:
			board[_xy_to_position(3, row, 8)] = board[_xy_to_position(0, row, 8)]
			board[_xy_to_position(0, row, 8)] = ""
	var destination := _position_to_xy(move.to, 8)
	if piece.to_upper() == "P" and destination.y in [0, 7]:
		piece = _chess_piece(side, "Q")
	board[move.to] = piece

func _all_chess_moves(side: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(64):
		result.append_array(_chess_moves_from(index, side, game_state.board))
	return result

func _update_chess_status(prefix: String) -> void:
	var moves := _all_chess_moves(int(game_state.turn))
	if moves.is_empty():
		game_state.over = true
		if _chess_in_check(int(game_state.turn), game_state.board):
			status_label.text = "Checkmate · " + ("You win!" if game_state.turn == -1 else "AI wins.")
		else:
			status_label.text = "Draw · stalemate."
	elif _chess_in_check(int(game_state.turn), game_state.board):
		status_label.text = prefix + " · Check!"
	else:
		status_label.text = prefix

func _ai_chess_turn() -> void:
	if game_state.over:
		return
	var moves := _all_chess_moves(-1)
	if moves.is_empty():
		_update_chess_status("AI to move")
		_render_chess()
		return
	var scored: Array[Dictionary] = []
	for move in moves:
		var target: String = game_state.board[move.to]
		var score := rng.randf()
		if not target.is_empty():
			score += 8.0 + float({"Q": 9, "R": 5, "B": 3, "N": 3, "P": 1}.get(target.to_upper(), 0))
		if move.get("castle", "") != "":
			score += 2.0
		scored.append({"move": move, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	var chosen: Dictionary = scored[0].move
	_update_chess_rights(chosen, -1)
	_apply_chess_board_move(game_state.board, chosen, -1)
	game_state.ep = -1
	if chosen.get("double", false):
		game_state.ep = int((chosen.from + chosen.to) / 2)
	game_state.turn = 1
	game_state.ply += 1
	_update_chess_status("Your move · White")
	_render_chess()

func _start_checkers() -> void:
	var cells: Array[int] = []
	cells.resize(64)
	cells.fill(0)
	for y in range(3):
		for x in range(8):
			if (x + y) % 2 == 1:
				cells[_xy_to_position(x, y, 8)] = -1
	for y in range(5, 8):
		for x in range(8):
			if (x + y) % 2 == 1:
				cells[_xy_to_position(x, y, 8)] = 1
	game_state = {"board": cells, "turn": 1, "over": false, "forced": -1}
	status_label.text = "Your move · Red. Captures are mandatory."
	_render_checkers()

func _render_checkers() -> void:
	_clear_area(board_area)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 8
	center.add_child(grid)
	var legal_targets: Array[int] = []
	if selected_square >= 0:
		for move in _checkers_legal_moves_from(selected_square, 1):
			legal_targets.append(move.to)
	for index in range(64):
		var x := index % 8
		var y := index / 8
		var piece := int(game_state.board[index])
		var button := Button.new()
		button.custom_minimum_size = Vector2(62, 54)
		button.text = "●" if abs(piece) == 1 else ("♛" if abs(piece) == 2 else "")
		if index in legal_targets:
			button.text = "•\n" + button.text
		var shade := DARK_SQUARE if (x + y) % 2 == 1 else LIGHT_SQUARE
		if index == selected_square:
			shade = ACCENT
		button.add_theme_color_override("font_color", COLORS[0] if piece > 0 and abs(piece) == 1 else (Color("#ffaaa1") if piece > 0 else (Color("#171b1b") if abs(piece) == 1 else Color("#f4f0d9"))))
		button.add_theme_font_size_override("font_size", 27)
		button.add_theme_stylebox_override("normal", _square_style(shade))
		button.add_theme_stylebox_override("hover", _square_style(shade.lightened(0.12)))
		button.pressed.connect(_on_checkers_square.bind(index))
		grid.add_child(button)
	_action("GAME MENU", _show_menu)
	_action("NEW GAME", _start_checkers)
	_action("RULES", _show_rules.bind("Checkers"))

func _on_checkers_square(index: int) -> void:
	if game_state.over or game_state.turn != 1:
		return
	if selected_square >= 0:
		for move in _checkers_legal_moves_from(selected_square, 1):
			if move.to == index:
				_play_sfx("board_capture" if int(move.capture) >= 0 else "board_move", -12.0, 0.04)
				_apply_checkers_move(move)
				if not _checkers_moves_from(int(game_state.forced), 1).is_empty():
					selected_square = int(game_state.forced)
					status_label.text = "Continue the jump with the same piece."
					_render_checkers()
					return
				game_state.forced = -1
				selected_square = -1
				game_state.turn = -1
				_render_checkers()
				_ai_checkers_turn()
				return
	var piece := int(game_state.board[index])
	if piece > 0 and (game_state.forced < 0 or game_state.forced == index) and not _checkers_legal_moves_from(index, 1).is_empty():
		selected_square = index
	else:
		selected_square = -1
	_render_checkers()

func _checkers_moves_from(square: int, side: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if square < 0 or square >= 64 or int(game_state.board[square]) * side <= 0:
		return result
	var piece := int(game_state.board[square])
	var x := square % 8
	var y := square / 8
	var directions: Array[int] = []
	if abs(piece) == 2 or side == 1:
		directions.append(-1)
	if abs(piece) == 2 or side == -1:
		directions.append(1)
	for dy in directions:
		for dx in [-1, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or nx >= 8 or ny < 0 or ny >= 8:
				continue
			var near := _xy_to_position(nx, ny, 8)
			if int(game_state.board[near]) * side < 0:
				var jx: int = nx + dx
				var jy: int = ny + dy
				if jx >= 0 and jx < 8 and jy >= 0 and jy < 8:
					var landing := _xy_to_position(jx, jy, 8)
					if int(game_state.board[landing]) == 0:
						result.append({"from": square, "to": landing, "capture": near})
			elif int(game_state.board[near]) == 0 and game_state.forced != square:
				result.append({"from": square, "to": near, "capture": -1})
	return result

func _checkers_all_moves(side: int) -> Array[Dictionary]:
	var captures: Array[Dictionary] = []
	var steps: Array[Dictionary] = []
	for index in range(64):
		if int(game_state.board[index]) * side > 0:
			for move in _checkers_moves_from(index, side):
				if int(move.capture) >= 0:
					captures.append(move)
				else:
					steps.append(move)
	if game_state.forced >= 0 and side == 1:
		return _checkers_moves_from(int(game_state.forced), side)
	return captures if not captures.is_empty() else steps

func _checkers_legal_moves_from(square: int, side: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for move in _checkers_all_moves(side):
		if int(move.from) == square:
			moves.append(move)
	return moves

func _apply_checkers_move(move: Dictionary) -> void:
	var piece := int(game_state.board[move.from])
	game_state.board[move.from] = 0
	if int(move.capture) >= 0:
		game_state.board[move.capture] = 0
	game_state.board[move.to] = 2 if piece == 1 and move.to / 8 == 0 else (-2 if piece == -1 and move.to / 8 == 7 else piece)
	game_state.forced = int(move.to) if int(move.capture) >= 0 else -1

func _ai_checkers_turn() -> void:
	if game_state.over:
		return
	var moves := _checkers_all_moves(-1)
	if moves.is_empty():
		game_state.over = true
		status_label.text = "You win · AI has no legal moves."
		return
	var move: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
	_apply_checkers_move(move)
	while int(game_state.forced) >= 0:
		var continuations := _checkers_moves_from(int(game_state.forced), -1)
		if continuations.is_empty():
			game_state.forced = -1
			break
		move = continuations[rng.randi_range(0, continuations.size() - 1)]
		_apply_checkers_move(move)
	game_state.forced = -1
	game_state.turn = 1
	if _checkers_all_moves(1).is_empty():
		game_state.over = true
		status_label.text = "AI wins · You have no legal moves."
	else:
		status_label.text = "Your move · Red. Captures are mandatory."
	_render_checkers()

func _show_rules(game: String) -> void:
	var rules := {
		"Chess": "Move your pieces to capture the opposing king by checkmate. Pawns promote to queens; castling and en passant are supported.",
		"Checkers": "Move diagonally toward the far row. Captures are compulsory; chain jumps in one turn. Reach the last row to become a king.",
		"Ludo": "Roll six to enter a token. Move around the track, capture on unsafe squares and reach home with an exact roll.",
		"Cards": "Play a matching rank or suit. Eights are wild; choose the next suit. First to empty their hand wins.",
		"Scrabble": "Place a connected word through the center on your first turn. Score letter/word premiums; pass or exchange tiles."
	}
	status_label.text = rules.get(game, "")

func _start_ludo() -> void:
	var tokens: Array = []
	for player in range(4):
		tokens.append([-1, -1, -1, -1])
	game_state = {
		"tokens": tokens, "turn": 0, "dice": 0, "roll_pending": true,
		"over": false, "winner": -1, "scores": [0, 0, 0, 0]
	}
	_render_ludo()
	_ludo_run_ai_turns()

func _ludo_track_index(player: int, progress: int) -> int:
	return (player * 13 + progress) % 52

func _ludo_safe(index: int) -> bool:
	return index in [0, 8, 13, 21, 26, 34, 39, 47]

func _ludo_blockade_at(track_index: int, moving_player: int, moving_token: int) -> bool:
	var count := 0
	for player in range(4):
		for token_index in range(4):
			if player == moving_player and token_index == moving_token:
				continue
			var progress := int(game_state.tokens[player][token_index])
			if progress >= 0 and progress < 52 and _ludo_track_index(player, progress) == track_index:
				count += 1
	return count >= 2

func _render_ludo() -> void:
	_clear_area(action_row)
	_action("GAME MENU", _show_menu)
	_action("ROLL DICE", _ludo_roll, game_state.turn == 0 and game_state.roll_pending and not game_state.over)
	_action("NEW GAME", _start_ludo)
	_action("RULES", _show_rules.bind("Ludo"))
	_clear_area(board_area)
	var whole := HBoxContainer.new()
	whole.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.add_child(whole)
	var track := GridContainer.new()
	track.columns = 13
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	whole.add_child(track)
	for index in range(52):
		var occupants: Array[String] = []
		for player in range(4):
			for token in game_state.tokens[player]:
				if token >= 0 and token < 52 and _ludo_track_index(player, token) == index:
					occupants.append(COLOR_NAMES[player][0])
		var button := Button.new()
		button.text = str(index) + ("\n" + "".join(occupants) if not occupants.is_empty() else "")
		button.custom_minimum_size = Vector2(38, 38)
		var shade := Color("#d9c99f") if index % 2 == 0 else Color("#829782")
		if _ludo_safe(index):
			shade = ACCENT
		button.add_theme_stylebox_override("normal", _square_style(shade))
		button.disabled = true
		track.add_child(button)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 235
	whole.add_child(side)
	var die := Label.new()
	die.text = "DIE: %s" % ("—" if game_state.roll_pending else str(game_state.dice))
	die.add_theme_font_size_override("font_size", 25)
	side.add_child(die)
	for player in range(4):
		var player_box := VBoxContainer.new()
		player_box.add_theme_constant_override("separation", 2)
		side.add_child(player_box)
		var label := Label.new()
		label.text = "%s%s" % [COLOR_NAMES[player], " · YOUR TURN" if player == 0 else (" · THINKING" if game_state.turn == player else "")]
		label.add_theme_color_override("font_color", COLORS[player])
		player_box.add_child(label)
		var row := HBoxContainer.new()
		player_box.add_child(row)
		for token_index in range(4):
			var progress := int(game_state.tokens[player][token_index])
			var token_button := Button.new()
			token_button.text = "HOME" if progress == 57 else ("YARD" if progress < 0 else str(progress))
			token_button.custom_minimum_size = Vector2(50, 34)
			token_button.add_theme_color_override("font_color", COLORS[player])
			var can_move: bool = player == 0 and game_state.turn == 0 and not game_state.roll_pending and _ludo_can_move(0, token_index, int(game_state.dice))
			token_button.disabled = not can_move
			if can_move:
				token_button.pressed.connect(_ludo_move_token.bind(token_index))
			row.add_child(token_button)
	if game_state.over:
		status_label.text = "%s wins Ludo!" % COLOR_NAMES[int(game_state.winner)]
	elif game_state.turn == 0:
		if game_state.roll_pending:
			status_label.text = "Your turn · Roll the die."
		else:
			status_label.text = "You rolled a %d · Choose a token." % int(game_state.dice)
	else:
		status_label.text = "%s AI turn." % COLOR_NAMES[int(game_state.turn)]

func _ludo_can_move(player: int, token_index: int, roll: int) -> bool:
	var progress := int(game_state.tokens[player][token_index])
	if progress < 0:
		if roll != 6:
			return false
		progress = -1
	elif progress + roll > 57:
		return false
	var destination := 0 if progress < 0 else progress + roll
	for step in range(progress + 1, min(destination, 51) + 1):
		if _ludo_blockade_at(_ludo_track_index(player, step), player, token_index):
			return false
	return true

func _ludo_roll() -> void:
	if game_state.over or game_state.turn != 0 or not game_state.roll_pending:
		return
	_play_sfx("ui_confirm", -12.0)
	game_state.dice = rng.randi_range(1, 6)
	game_state.roll_pending = false
	var possible := false
	for token_index in range(4):
		if _ludo_can_move(0, token_index, int(game_state.dice)):
			possible = true
	if not possible:
		game_state.turn = 1
		game_state.roll_pending = true
	_render_ludo()
	_ludo_run_ai_turns()

func _ludo_move_token(token_index: int) -> void:
	if game_state.turn != 0 or game_state.roll_pending or not _ludo_can_move(0, token_index, int(game_state.dice)):
		return
	_play_sfx("board_move", -13.0, 0.04)
	_ludo_apply_move(0, token_index, int(game_state.dice))
	_render_ludo()
	_ludo_run_ai_turns()

func _ludo_apply_move(player: int, token_index: int, roll: int) -> void:
	var tokens: Array = game_state.tokens
	var progress := int(tokens[player][token_index])
	progress = 0 if progress < 0 else progress + roll
	tokens[player][token_index] = progress
	if progress >= 0 and progress < 52:
		var landing := _ludo_track_index(player, progress)
		if not _ludo_safe(landing):
			for rival in range(4):
				if rival == player:
					continue
				for rival_token in range(4):
					var rival_progress := int(tokens[rival][rival_token])
					if rival_progress >= 0 and rival_progress < 52 and _ludo_track_index(rival, rival_progress) == landing:
						tokens[rival][rival_token] = -1
	game_state.tokens = tokens
	if int(tokens[player][token_index]) == 57:
		game_state.scores[player] = int(game_state.scores[player]) + 1
	if int(game_state.scores[player]) >= 4:
		game_state.over = true
		game_state.winner = player
		return
	game_state.turn = player if roll == 6 else (player + 1) % 4
	game_state.roll_pending = true

func _ludo_run_ai_turns() -> void:
	while not game_state.over and int(game_state.turn) != 0:
		var player := int(game_state.turn)
		var roll := rng.randi_range(1, 6)
		var valid: Array[int] = []
		for token_index in range(4):
			if _ludo_can_move(player, token_index, roll):
				valid.append(token_index)
		if valid.is_empty():
			game_state.turn = (player + 1) % 4
			game_state.roll_pending = true
			continue
		var chosen := valid[rng.randi_range(0, valid.size() - 1)]
		_ludo_apply_move(player, chosen, roll)
	_render_ludo()

func _start_cards() -> void:
	var deck: Array[Dictionary] = []
	for suit in SUITS:
		for rank in range(1, 14):
			deck.append({"suit": suit, "rank": rank})
	deck.shuffle()
	var hands: Array = [[], []]
	for _card in range(7):
		hands[0].append(deck.pop_back())
		hands[1].append(deck.pop_back())
	game_state = {
		"deck": deck, "hands": hands, "discard": [deck.pop_back()],
		"suit": "", "turn": 0, "over": false, "waiting_suit": false, "winner": -1
	}
	_render_cards()

func _card_name(card: Dictionary) -> String:
	var rank := int(card.rank)
	var rank_name: String = str(rank) if rank <= 10 else ["", "", "", "", "", "", "", "", "", "", "10", "J", "Q", "K"][rank]
	return rank_name + str(card.suit)

func _card_playable(card: Dictionary) -> bool:
	var top: Dictionary = game_state.discard.back()
	return int(card.rank) == 8 or int(card.rank) == int(top.rank) or str(card.suit) == str(game_state.get("suit", top.suit))

func _render_cards() -> void:
	_clear_area(action_row)
	_action("GAME MENU", _show_menu)
	_action("DRAW CARD", _cards_draw, game_state.turn == 0 and not game_state.over and not game_state.waiting_suit)
	_action("NEW GAME", _start_cards)
	_action("RULES", _show_rules.bind("Cards"))
	_clear_area(board_area)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.add_child(content)
	var top: Dictionary = game_state.discard.back()
	var info := Label.new()
	info.text = "AI: %d cards     ·     Deck: %d     ·     Current suit: %s" % [game_state.hands[1].size(), game_state.deck.size(), game_state.get("suit", top.suit)]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(info)
	var discard := Label.new()
	discard.text = "TOP CARD     " + _card_name(top)
	discard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard.add_theme_font_size_override("font_size", 38)
	content.add_child(discard)
	if game_state.waiting_suit:
		var suits := HBoxContainer.new()
		suits.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(suits)
		for suit in SUITS:
			var button := Button.new()
			button.text = "CHOOSE " + suit
			button.custom_minimum_size = Vector2(85, 48)
			button.pressed.connect(_cards_choose_suit.bind(suit))
			suits.add_child(button)
	var hand := HFlowContainer.new()
	hand.alignment = FlowContainer.ALIGNMENT_CENTER
	content.add_child(hand)
	for index in range(game_state.hands[0].size()):
		var card: Dictionary = game_state.hands[0][index]
		var button := Button.new()
		button.text = _card_name(card)
		button.custom_minimum_size = Vector2(74, 104)
		button.add_theme_font_size_override("font_size", 18)
		var red: bool = card.suit in ["♥", "♦"]
		button.add_theme_color_override("font_color", Color("#b83836") if red else Color("#161b1a"))
		button.disabled = game_state.turn != 0 or game_state.waiting_suit or game_state.over or not _card_playable(card)
		button.pressed.connect(_cards_play.bind(index))
		hand.add_child(button)
	status_label.text = "Your turn · Play a matching card or draw." if game_state.turn == 0 else "AI is playing..."
	if game_state.over:
		status_label.text = "You win Crazy Eights!" if game_state.winner == 0 else ("AI wins Crazy Eights." if game_state.winner == 1 else "Crazy Eights is a draw.")

func _cards_finish_blocked() -> void:
	game_state.over = true
	var human_count: int = game_state.hands[0].size()
	var ai_count: int = game_state.hands[1].size()
	game_state.winner = 0 if human_count < ai_count else (1 if ai_count < human_count else -1)
	game_state.turn = 0

func _cards_draw() -> void:
	if game_state.turn != 0 or game_state.over or game_state.waiting_suit:
		return
	_play_sfx("tile_drop", -14.0, 0.04)
	if game_state.deck.is_empty():
		var top: Dictionary = game_state.discard.pop_back()
		game_state.deck = game_state.discard.duplicate()
		game_state.deck.shuffle()
		game_state.discard = [top]
		if game_state.deck.is_empty():
			_cards_finish_blocked()
			_render_cards()
			return
	game_state.hands[0].append(game_state.deck.pop_back())
	var new_index: int = game_state.hands[0].size() - 1
	game_state.turn = 1 if not _card_playable(game_state.hands[0][new_index]) else 0
	_render_cards()
	if game_state.turn == 1:
		_cards_ai_turn()

func _cards_play(index: int) -> void:
	if game_state.turn != 0 or game_state.over or index < 0 or index >= game_state.hands[0].size():
		return
	var card: Dictionary = game_state.hands[0][index]
	if not _card_playable(card):
		return
	_play_sfx("tile_drop", -14.0, 0.04)
	game_state.discard.append(card)
	game_state.hands[0].remove_at(index)
	game_state.turn = 1
	game_state.waiting_suit = int(card.rank) == 8
	game_state.suit = str(card.suit)
	if game_state.hands[0].is_empty() and not game_state.waiting_suit:
		game_state.over = true
		game_state.turn = 0
		game_state.winner = 0
	_render_cards()
	if not game_state.waiting_suit and not game_state.over:
		_cards_ai_turn()

func _cards_choose_suit(suit: String) -> void:
	if not game_state.waiting_suit:
		return
	game_state.suit = suit
	game_state.waiting_suit = false
	if game_state.hands[0].is_empty():
		game_state.over = true
		game_state.turn = 0
		game_state.winner = 0
	_render_cards()
	if not game_state.over:
		_cards_ai_turn()

func _cards_ai_turn() -> void:
	if game_state.over:
		return
	var hand: Array = game_state.hands[1]
	var playable: Array[int] = []
	for index in range(hand.size()):
		if _card_playable(hand[index]):
			playable.append(index)
	if playable.is_empty():
		if game_state.deck.is_empty():
			var top: Dictionary = game_state.discard.pop_back()
			game_state.deck = game_state.discard.duplicate()
			game_state.deck.shuffle()
			game_state.discard = [top]
		if game_state.deck.is_empty():
			_cards_finish_blocked()
			_render_cards()
			return
		hand.append(game_state.deck.pop_back())
		if not _card_playable(hand.back()):
			game_state.turn = 0
			_render_cards()
			return
		playable.append(hand.size() - 1)
	var selected := playable[rng.randi_range(0, playable.size() - 1)]
	var card: Dictionary = hand[selected]
	game_state.discard.append(card)
	hand.remove_at(selected)
	game_state.waiting_suit = int(card.rank) == 8
	game_state.suit = str(card.suit)
	if game_state.waiting_suit:
		var suit_counts := {"♠": 0, "♥": 0, "♦": 0, "♣": 0}
		for held in hand:
			suit_counts[held.suit] = int(suit_counts[held.suit]) + 1
		var chosen_suit := str(SUITS[0])
		for suit in SUITS:
			if int(suit_counts[suit]) > int(suit_counts[chosen_suit]):
				chosen_suit = suit
		game_state.suit = chosen_suit
		game_state.waiting_suit = false
	if hand.is_empty():
		game_state.over = true
		game_state.turn = 1
		game_state.winner = 1
	else:
		game_state.turn = 0
	_render_cards()

func _start_scrabble() -> void:
	scrabble_word_set.clear()
	scrabble_words.clear()
	for key in SCRABBLE_WORDS:
		for word in str(SCRABBLE_WORDS[key]).split(" ", false):
			if word.length() >= 2 and not scrabble_word_set.has(word):
				scrabble_word_set[word] = true
				scrabble_words.append(word)
	scrabble_word_set["A"] = true
	scrabble_word_set["I"] = true
	scrabble_words.append("A")
	scrabble_words.append("I")
	scrabble_words.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var distribution := {
		"A": 9, "B": 2, "C": 2, "D": 4, "E": 12, "F": 2, "G": 3, "H": 2,
		"I": 9, "J": 1, "K": 1, "L": 4, "M": 2, "N": 6, "O": 8, "P": 2,
		"Q": 1, "R": 6, "S": 4, "T": 6, "U": 4, "V": 2, "W": 2, "X": 1,
		"Y": 2, "Z": 1, "?": 2
	}
	var bag: Array[String] = []
	for letter in distribution:
		for _count in range(distribution[letter]):
			bag.append(letter)
	bag.shuffle()
	var board: Array[String] = []
	board.resize(225)
	board.fill("")
	var racks: Array = [[], []]
	for _tile in range(7):
		racks[0].append(bag.pop_back())
		racks[1].append(bag.pop_back())
	game_state = {
		"board": board, "racks": racks, "bag": bag, "scores": [0, 0],
		"turn": 0, "over": false, "last_score": 0
	}
	pending_tiles.clear()
	scrabble_passes = 0
	_render_scrabble()

func _scrabble_premium(square: int) -> String:
	var x := square % 15
	var y := square / 15
	if (x in [0, 7, 14] and y in [0, 7, 14] and not (x == 7 and y == 7)) or Vector2i(x, y) in [
		Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4),
		Vector2i(10, 4), Vector2i(11, 3), Vector2i(12, 2), Vector2i(13, 1),
		Vector2i(1, 13), Vector2i(2, 12), Vector2i(3, 11), Vector2i(4, 10),
		Vector2i(10, 10), Vector2i(11, 11), Vector2i(12, 12), Vector2i(13, 13)
	]:
		return "TW"
	if (x in [0, 14] and y in [3, 11]) or (y in [0, 14] and x in [3, 11]) or Vector2i(x, y) in [
		Vector2i(2, 6), Vector2i(6, 2), Vector2i(8, 2), Vector2i(12, 6),
		Vector2i(2, 8), Vector2i(6, 12), Vector2i(8, 12), Vector2i(12, 8)
	]:
		return "DW"
	if Vector2i(x, y) in [
		Vector2i(5, 1), Vector2i(9, 1), Vector2i(1, 5), Vector2i(5, 5),
		Vector2i(9, 5), Vector2i(13, 5), Vector2i(1, 9), Vector2i(5, 9),
		Vector2i(9, 9), Vector2i(13, 9), Vector2i(5, 13), Vector2i(9, 13)
	]:
		return "TL"
	if Vector2i(x, y) in [
		Vector2i(3, 0), Vector2i(11, 0), Vector2i(6, 2), Vector2i(8, 2),
		Vector2i(0, 3), Vector2i(7, 3), Vector2i(14, 3), Vector2i(2, 6),
		Vector2i(6, 6), Vector2i(8, 6), Vector2i(12, 6), Vector2i(3, 7),
		Vector2i(11, 7), Vector2i(2, 8), Vector2i(6, 8), Vector2i(8, 8),
		Vector2i(12, 8), Vector2i(0, 11), Vector2i(7, 11), Vector2i(14, 11),
		Vector2i(6, 12), Vector2i(8, 12), Vector2i(3, 14), Vector2i(11, 14)
	]:
		return "DL"
	return ""

func _render_scrabble() -> void:
	_clear_area(action_row)
	_action("GAME MENU", _show_menu)
	var has_pending := not pending_tiles.is_empty()
	_action("PLAY WORD", _scrabble_play, game_state.turn == 0 and has_pending and not game_state.over)
	_action("UNDO TILES", _scrabble_undo, game_state.turn == 0 and has_pending)
	_action("PASS TURN", _scrabble_pass, game_state.turn == 0 and not game_state.over)
	_action("NEW GAME", _start_scrabble)
	_action("RULES", _show_rules.bind("Scrabble"))
	if selected_tile >= 0 and selected_tile < game_state.racks[0].size() and str(game_state.racks[0][selected_tile]) == "?":
		var blank_choice := OptionButton.new()
		blank_choice.add_item("BLANK AS " + selected_blank_letter)
		for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
			blank_choice.add_item("AS " + letter)
		blank_choice.item_selected.connect(func(index: int) -> void:
			if index > 0:
				selected_blank_letter = char(64 + index)
		)
		action_row.add_child(blank_choice)
	_clear_area(board_area)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	board_area.add_child(content)
	var scores := Label.new()
	scores.text = "YOU  %d        AI  %d        BAG  %d" % [game_state.scores[0], game_state.scores[1], game_state.bag.size()]
	scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores.add_theme_font_size_override("font_size", 19)
	content.add_child(scores)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 15
	center.add_child(grid)
	for index in range(225):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(31, 28)
		var letter: String = pending_tiles[index].tile if pending_tiles.has(index) else str(game_state.board[index])
		if letter.is_empty():
			letter = _scrabble_premium(index)
		cell.text = letter
		cell.add_theme_font_size_override("font_size", 9 if letter.length() > 1 else 13)
		var premium := _scrabble_premium(index)
		var color := Color("#e9dfbf")
		if premium == "TW":
			color = Color("#bd7169")
		elif premium == "DW":
			color = Color("#dfa878")
		elif premium == "TL":
			color = Color("#648dad")
		elif premium == "DL":
			color = Color("#82abbd")
		if index == 112:
			color = Color("#f0ce77")
		if pending_tiles.has(index):
			color = Color("#fff0a8")
		cell.add_theme_stylebox_override("normal", _square_style(color))
		cell.add_theme_stylebox_override("hover", _square_style(color.lightened(0.15)))
		cell.pressed.connect(_scrabble_cell.bind(index))
		grid.add_child(cell)
	var rack := HFlowContainer.new()
	rack.alignment = FlowContainer.ALIGNMENT_CENTER
	content.add_child(rack)
	var human_rack: Array = game_state.racks[0]
	for index in range(human_rack.size()):
		var tile := str(human_rack[index])
		var button := Button.new()
		button.text = tile + "\n" + str(TILE_VALUES.get(tile, 0))
		button.custom_minimum_size = Vector2(48, 54)
		button.disabled = game_state.turn != 0 or game_state.over or _scrabble_pending_has_rack(index)
		if index == selected_tile:
			button.modulate = Color("#ffe88f")
		button.pressed.connect(_scrabble_select_tile.bind(index))
		rack.add_child(button)
	if game_state.over:
		status_label.text = "Scrabble game over · " + ("You win!" if game_state.scores[0] > game_state.scores[1] else ("AI wins." if game_state.scores[1] > game_state.scores[0] else "Draw."))
	else:
		status_label.text = "Your turn · Select a rack tile, then an empty board square. " + ("%d pending" % pending_tiles.size() if has_pending else "")

func _scrabble_pending_has_rack(rack_index: int) -> bool:
	for square in pending_tiles:
		if int(pending_tiles[square].rack_index) == rack_index:
			return true
	return false

func _scrabble_select_tile(index: int) -> void:
	if game_state.turn != 0 or game_state.over or _scrabble_pending_has_rack(index):
		return
	selected_tile = index
	if str(game_state.racks[0][index]) == "?":
		selected_blank_letter = "E"
	_render_scrabble()

func _scrabble_cell(square: int) -> void:
	if game_state.turn != 0 or game_state.over:
		return
	if pending_tiles.has(square):
		pending_tiles.erase(square)
		selected_tile = -1
		_render_scrabble()
		return
	if not str(game_state.board[square]).is_empty() or selected_tile < 0 or selected_tile >= game_state.racks[0].size():
		return
	var tile := str(game_state.racks[0][selected_tile])
	var blank := tile == "?"
	if blank:
		tile = selected_blank_letter
	pending_tiles[square] = {"tile": tile, "rack_index": selected_tile, "blank": blank}
	_play_sfx("tile_drop", -14.0, 0.04)
	selected_tile = -1
	_render_scrabble()

func _scrabble_undo() -> void:
	pending_tiles.clear()
	selected_tile = -1
	_render_scrabble()

func _scrabble_value(letter: String) -> int:
	return int(TILE_VALUES.get(letter, 0))

func _scrabble_letter_at(square: int) -> String:
	if pending_tiles.has(square):
		return str(pending_tiles[square].tile)
	return str(game_state.board[square])

func _scrabble_word_at(square: int, dx: int, dy: int) -> Dictionary:
	var x := square % 15
	var y := square / 15
	while x - dx >= 0 and x - dx < 15 and y - dy >= 0 and y - dy < 15 and not _scrabble_letter_at(_xy_to_position(x - dx, y - dy, 15)).is_empty():
		x -= dx
		y -= dy
	var letters := ""
	var cells: Array[int] = []
	while x >= 0 and x < 15 and y >= 0 and y < 15:
		var position := _xy_to_position(x, y, 15)
		var letter := _scrabble_letter_at(position)
		if letter.is_empty():
			break
		letters += letter
		cells.append(position)
		x += dx
		y += dy
	return {"word": letters, "cells": cells}

func _scrabble_validate_pending() -> Dictionary:
	if pending_tiles.is_empty():
		return {"ok": false, "message": "Place at least one tile."}
	var positions: Array[int] = []
	var xs: Array[int] = []
	var ys: Array[int] = []
	for square in pending_tiles:
		positions.append(int(square))
		xs.append(int(square) % 15)
		ys.append(int(square) / 15)
	if xs.min() != xs.max() and ys.min() != ys.max():
		return {"ok": false, "message": "New tiles must be in one row or column."}
	var horizontal: bool = ys.min() == ys.max()
	var dx := 1 if horizontal else 0
	var dy := 0 if horizontal else 1
	var first := int(positions[0])
	var min_axis: int = int(xs.min()) if horizontal else int(ys.min())
	var max_axis: int = int(xs.max()) if horizontal else int(ys.max())
	var row_or_col: int = int(ys[0]) if horizontal else int(xs[0])
	for axis in range(min_axis, max_axis + 1):
		var square := _xy_to_position(axis, row_or_col, 15) if horizontal else _xy_to_position(row_or_col, axis, 15)
		if _scrabble_letter_at(square).is_empty():
			return {"ok": false, "message": "The word cannot have gaps."}
	var touches_board := false
	for square in pending_tiles:
		if int(square) == 112:
			touches_board = true
		var x := int(square) % 15
		var y := int(square) / 15
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nx: int = x + offset.x
			var ny: int = y + offset.y
			if nx >= 0 and nx < 15 and ny >= 0 and ny < 15:
				var neighbor := _xy_to_position(nx, ny, 15)
				if not str(game_state.board[neighbor]).is_empty():
					touches_board = true
	if game_state.scores[0] == 0 and game_state.scores[1] == 0 and game_state.bag.size() == 86 and not pending_tiles.has(112):
		return {"ok": false, "message": "Your opening word must cover the center star."}
	if game_state.scores[0] > 0 or game_state.scores[1] > 0:
		if not touches_board:
			return {"ok": false, "message": "Your word must connect to the existing tiles."}
	var main_word := _scrabble_word_at(first, dx, dy)
	var words: Array[Dictionary] = [main_word]
	var cross_dx := 0 if horizontal else 1
	var cross_dy := 1 if horizontal else 0
	for square in pending_tiles:
		var cross := _scrabble_word_at(int(square), cross_dx, cross_dy)
		if str(cross.word).length() > 1:
			words.append(cross)
	for word in words:
		if not scrabble_word_set.has(str(word.word)):
			return {"ok": false, "message": "“%s” is not in the Scrabble word list." % word.word}
	var score := _scrabble_score(words)
	return {"ok": true, "message": "Valid play · %d points." % score, "score": score, "words": words}

func _scrabble_score(words: Array[Dictionary]) -> int:
	var total := 0
	for word in words:
		var subtotal := 0
		var word_multiplier := 1
		for square in word.cells:
			var letter := _scrabble_letter_at(int(square))
			var letter_value := _scrabble_value(letter)
			if pending_tiles.has(square):
				var premium := _scrabble_premium(int(square))
				var placement: Dictionary = pending_tiles[int(square)] if pending_tiles.has(square) else {}
				if bool(placement.get("blank", false)):
					letter_value = 0
				if premium == "DL":
					letter_value *= 2
				elif premium == "TL":
					letter_value *= 3
				elif premium == "DW":
					word_multiplier *= 2
				elif premium == "TW":
					word_multiplier *= 3
			subtotal += letter_value
		total += subtotal * word_multiplier
	if pending_tiles.size() == 7:
		total += 50
	return total

func _scrabble_play() -> void:
	var result := _scrabble_validate_pending()
	if not result.ok:
		_play_sfx("ui_error", -14.0)
		status_label.text = str(result.message)
		return
	_play_sfx("ui_confirm", -12.0)
	game_state.scores[0] = int(game_state.scores[0]) + int(result.score)
	var remove_indices: Array[int] = []
	for square in pending_tiles:
		var placement: Dictionary = pending_tiles[square]
		game_state.board[int(square)] = str(placement.tile)
		remove_indices.append(int(placement.rack_index))
	remove_indices.sort()
	remove_indices.reverse()
	for rack_index in remove_indices:
		game_state.racks[0].remove_at(rack_index)
	_scrabble_draw_tiles(0)
	pending_tiles.clear()
	selected_tile = -1
	scrabble_passes = 0
	game_state.last_score = int(result.score)
	game_state.turn = 1
	if _scrabble_finish_if_needed():
		_render_scrabble()
		return
	_render_scrabble()
	_scrabble_ai_turn()

func _scrabble_draw_tiles(player: int) -> void:
	while game_state.racks[player].size() < 7 and not game_state.bag.is_empty():
		game_state.racks[player].append(game_state.bag.pop_back())

func _scrabble_pass() -> void:
	if game_state.turn != 0 or game_state.over:
		return
	_scrabble_undo()
	scrabble_passes += 1
	game_state.turn = 1
	if _scrabble_finish_if_needed():
		_render_scrabble()
	else:
		_render_scrabble()
		_scrabble_ai_turn()

func _scrabble_ai_turn() -> void:
	if game_state.over:
		return
	var best_pending: Dictionary = {}
	var best_score := -1
	var rack: Array = game_state.racks[1]
	var empty_board := true
	for letter in game_state.board:
		if not str(letter).is_empty():
			empty_board = false
			break
	for word in scrabble_words:
		if word.length() > 7:
			continue
		for horizontal in [true, false]:
			for row in range(15):
				for start in range(15 - word.length() + 1):
					if horizontal and row == -1:
						continue
					if empty_board:
						var covers_center := false
						for offset in range(word.length()):
							var cx := start + offset if horizontal else row
							var cy := row if horizontal else start + offset
							if cx == 7 and cy == 7:
								covers_center = true
						if not covers_center:
							continue
					var available: Array = rack.duplicate()
					var available_indices: Array[int] = []
					for rack_index in range(rack.size()):
						available_indices.append(rack_index)
					var candidate: Dictionary = {}
					var touches := false
					var fits := true
					for offset in range(word.length()):
						var x := start + offset if horizontal else row
						var y := row if horizontal else start + offset
						var square := _xy_to_position(x, y, 15)
						var existing := str(game_state.board[square])
						if not existing.is_empty():
							if existing != word.substr(offset, 1):
								fits = false
								break
							touches = true
						else:
							var letter := word.substr(offset, 1)
							var rack_slot: int = available.find(letter)
							var blank_used := false
							if rack_slot < 0:
								rack_slot = available.find("?")
								blank_used = rack_slot >= 0
							if rack_slot < 0:
								fits = false
								break
							var original_rack_index: int = available_indices[rack_slot]
							available.remove_at(rack_slot)
							available_indices.remove_at(rack_slot)
							candidate[square] = {"tile": letter, "rack_index": original_rack_index, "blank": blank_used}
							if _scrabble_adjacent_to_board(square):
								touches = true
					if not fits or candidate.is_empty() or (not empty_board and not touches):
						continue
					pending_tiles = candidate
					var result := _scrabble_validate_pending()
					if bool(result.ok) and int(result.score) > best_score:
						best_score = int(result.score)
						best_pending = candidate.duplicate(true)
					pending_tiles.clear()
	pending_tiles = best_pending
	if pending_tiles.is_empty():
		scrabble_passes += 1
		game_state.turn = 0
		_scrabble_finish_if_needed()
		_render_scrabble()
		return
	var result := _scrabble_validate_pending()
	game_state.scores[1] = int(game_state.scores[1]) + int(result.score)
	var remove_indices: Array[int] = []
	for square in pending_tiles:
		var placement: Dictionary = pending_tiles[square]
		game_state.board[int(square)] = str(placement.tile)
		remove_indices.append(int(placement.rack_index))
	remove_indices.sort()
	remove_indices.reverse()
	for rack_index in remove_indices:
		game_state.racks[1].remove_at(rack_index)
	_scrabble_draw_tiles(1)
	pending_tiles.clear()
	scrabble_passes = 0
	game_state.turn = 0
	if _scrabble_finish_if_needed():
		_render_scrabble()
		return
	_render_scrabble()

func _scrabble_adjacent_to_board(square: int) -> bool:
	var x := square % 15
	var y := square / 15
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if nx >= 0 and nx < 15 and ny >= 0 and ny < 15 and not str(game_state.board[_xy_to_position(nx, ny, 15)]).is_empty():
			return true
	return false

func _scrabble_finish_if_needed() -> bool:
	if game_state.bag.is_empty() and (game_state.racks[0].is_empty() or game_state.racks[1].is_empty()):
		var emptied_player := 0 if game_state.racks[0].is_empty() else 1
		var remaining_player := 1 - emptied_player
		var remaining_points := 0
		for tile in game_state.racks[remaining_player]:
			remaining_points += _scrabble_value(str(tile))
		game_state.scores[emptied_player] += remaining_points
		game_state.scores[remaining_player] -= remaining_points
		game_state.over = true
		return true
	if scrabble_passes >= 6:
		for player in range(2):
			var remaining_points := 0
			for tile in game_state.racks[player]:
				remaining_points += _scrabble_value(str(tile))
			game_state.scores[player] -= remaining_points
		game_state.over = true
		return true
	return false
