extends Resource
class_name FighterSelectionData
## Serializable roster entry for menus, save data, and match setup.

@export var character_id: StringName = &""
@export var display_name: String = "Fighter"
@export var archetype: StringName = &""
@export var accent: Color = Color.WHITE
@export_multiline var passive_description: String = ""
@export var signature_move: String = ""
@export var signature_damage_multiplier: float = 1.0
@export var bonus_damage: int = 0
@export var bonus_stun: int = 0
@export var fighter_scene: PackedScene


func to_character_dictionary() -> Dictionary:
	return {
		"id": character_id,
		"name": display_name,
		"archetype": archetype,
		"accent": accent,
		"passive": passive_description,
		"signature": signature_move,
		"signature_damage_multiplier": signature_damage_multiplier,
		"bonus_damage": bonus_damage,
		"bonus_stun": bonus_stun,
	}
