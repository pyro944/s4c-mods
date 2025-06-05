extends Node

var util
var Participants
var Scenes = []

func _ready():
    util = modding_core.modules.mod_sex_scenes_util
    Participants = util.Participants
    load_scenes()

func load_scenes():
    var files = dir_contents(util.ModPath + '/bg')
    var combined_scenes = {}
    for file in files:
        var scene = to_bg_scene(file)
        var key = scene.participants.hash()
        if not combined_scenes.has(key):
            combined_scenes[key] = []
        combined_scenes[key].append(scene)

    for key in combined_scenes.keys():
        var participants = []
        var images = []
        for scene in combined_scenes[key]:
            participants = scene.participants
            images.append(scene.image)
        Scenes.append({'participants': participants, 'images': images})

func dir_contents(path):
    var files = []
    var dir = Directory.new()
    if dir.open(path) == OK:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir():
                files.append(file_name)
            file_name = dir.get_next()
    else:
        print("An error occurred when trying to access the background images path. Background images will not be displayed.")
    return files

func to_bg_scene(file_name):
    # Grab the text between [ and ]
    var start_index = file_name.find('[')
    var end_index = file_name.find(']')
    var raw_tags = file_name.substr(start_index + 1, end_index - start_index - 1)

    var participants = []
    for raw_name in raw_tags.split(','):
        participants.append(to_participant(raw_name.strip_edges()))

    participants.sort()
    return {
        'participants': participants,
        'image': util.load_custom_bg(file_name)
    }

func to_participant(name):
    for participant in Participants.values():
        if participant == name:
            return participant
    return name
