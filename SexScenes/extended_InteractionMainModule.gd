extends "res://gui_modules/Interaction/Scripts/InteractionMainModule.gd"

var util = modding_core.modules.mod_sex_scenes_util
var Participants = util.Participants
var mod_path = util.ModPath

# Extend rebuildparticipantslist instead of startsequence becuase tw_kennels
# changes the interface for startsequence.
func rebuildparticipantslist():
    .rebuildparticipantslist()

    var scene = choose_scene(participants)
    var bg = scene.images[randi() % scene.images.size()]
    get_node('Background').add_stylebox_override('panel', bg)

func choose_scene(participants):
    var best_scene = null
    var best_scene_placeholders = 999
    var scenes = modding_core.modules.mod_sex_scenes_user_scenes.Scenes
    for scene in scenes:
        var current_placeholders = 0
        var actor_types = extract_placeholders(scene)
        var remaining_participants = participants.duplicate()
        for name in actor_types.named:
            for participant in remaining_participants:
                if matches(participant, 'name', name):
                    remaining_participants.erase(participant)
                    continue
        for placeholder in actor_types.placeholder:
            for participant in remaining_participants:
                if matches(participant, 'placeholder', placeholder):
                    current_placeholders += 1
                    remaining_participants.erase(participant)
                    continue

        if remaining_participants.empty() and current_placeholders <= best_scene_placeholders:
            best_scene = scene
            best_scene_placeholders = current_placeholders

    if best_scene != null:
        return best_scene

    return DEFAULT_SCENE

func extract_placeholders(scene):
    var named_actors = []
    var placeholder_actors = []
    for name in scene.participants:
        if Participants.values().has(name):
            placeholder_actors.append(name)
        else:
            named_actors.append(name)
    return {
        'named': named_actors,
        'placeholder': placeholder_actors
    }

func matches(participant, match_type, value):
    match match_type:
        'placeholder':
            if [Participants.MaleMc, Participants.FemaleMc, Participants.FutaMc].has(value):
                if not participant.person.has_profession('master'):
                    return false
                var sex = participant.person.get_stat('sex')
                return (sex == 'male' and value == Participants.MaleMc) or\
                    (sex == 'female' and value == Participants.FemaleMc) or\
                    (sex == 'futa' and value == Participants.FutaMc)
            if [Participants.Dog, Participants.Horse].has(value):
                var unique = participant.person.get_stat('unique')
                return (unique == 'dog' and value == Participants.Dog) or\
                    (unique == 'horse' and value == Participants.Horse)
            if [Participants.AnyMale, Participants.AnyFemale, Participants.AnyFuta].has(value):
                # Don't allow animals
                var unique = participant.person.get_stat('unique')
                if (unique == 'dog' or unique == 'horse'):
                    return false
                var sex = participant.person.get_stat('sex')
                return (sex == 'male' and value == Participants.AnyMale) or\
                    (sex == 'female' and value == Participants.AnyFemale) or\
                    (sex == 'futa' and value == Participants.AnyFuta)
        'name':
            return participant.person.get_full_name() == value
    return false

func build_default_scene():
    var mansion_bg = images.backgrounds.mansion
    if mansion_bg is String:
        mansion_bg = input_handler.loadimage(mansion_bg)

    var stylebox = StyleBoxTexture.new()
    stylebox.texture = mansion_bg
    return {
        'images': [stylebox]
    }

func custom_bg(image_path):
    var stylebox = StyleBoxTexture.new()
    stylebox.texture = input_handler.loadimage(mod_path + '/bg/' + image_path)
    return stylebox

var DEFAULT_SCENE = build_default_scene()
