extends Node

var util
var Participants
var Scenes = []

func _ready():
    util = modding_core.modules.mod_sex_scenes_util
    Participants = util.Participants
    load_scenes()

func load_scenes():
    Scenes = [
        # Place your scenes here. Example:
        # {
        #     'participants': [Participants.MaleMc, 'Daisy'],
        #     'images': [
        #         util.load_custom_bg('mc-and-daisy.png')
        #     ]
        # }
        # You can load as many images per scene as you like.
        # One will be chosen at random as the scene begins.
        # Example with multiple images:
        # {
        #     'participants': ['Amelia', 'Cali'],
        #     'images': [
        #         util.load_custom_bg('amelia-and-cali-1.png'),
        #         util.load_custom_bg('amelia-and-cali-2.png'),
        #     ]
        # }
        # Characters are matched by *full name*, so if you're defining a
        # scene for a character named John Smith, you need to list
        # "John Smith" as a participant, not "John".
        #
        # You can use placeholders to include non-named characters.
        # Valid placeholders:
        # - Participants.MaleMc: Male main character
        # - Participants.FemaleMc: Female main character
        # - Participants.FutaMc: Futa main character
        # - Participants.AnyMale: Any male character
        # - Participants.AnyFemale: Any female character
        # - Participants.AnyFuta: Any futa character
        # - Participants.Dog: Any dog
        # - Participants.Horse: Any horse
        #
        # When starting the scene, the system will choose the most specific
        # scene available. For example, if you initiate a scene with
        # Amelia and Daisy and have defined these two scenes:
        # {
        #     'participants': ['Amelia', 'Daisy']
        # },
        # {
        #     'participants': [Participants.AnyFemale, Participants.AnyFemale]
        # }
        # The scene with the characters' names will always be chosen because it's
        # more specific.
]
