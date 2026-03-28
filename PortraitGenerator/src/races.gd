extends Node

var _ATTRIBUTES = {
    'Arachna': {
        'body': ['arachne', 'human spider hybrid', 'human torso attached to spider body'],
        'skin': 'skin',
        'negative': ['spider-man', 'spiderman', 'human legs', 'thighs'],
        'personal_descriptor': 'spider $PERSON',
    },
    'Avali': {
        'body': ['harpy', 'wings for arms', 'bird legs', 'feather mane'],
        'skin': 'skin',
        'negative': ['human arms'],
        'personal_descriptor': 'bird $PERSON',
    },
    'BeastkinBird': {
        'body': ['anthro', 'furry', 'bird', 'wings for arms', 'bird legs'],
        'skin': 'feathers',
        'negative': ['human arms']
    },
    'BeastkinBunny': {
        'body': ['anthro', 'furry', 'rabbit'],
        'skin': 'fur',
        'negative': []
    },
    'BeastkinCat': {
        'body': ['anthro', 'furry', 'cat'],
        'skin': 'fur',
        'negative': []
    },
    'BeastkinFox': {
        'body': ['anthro', 'furry', 'fox'],
        'skin': 'fur',
        'negative': []
    },
    'BeastkinMouse': {
        'body': ['anthro', 'furry', 'mouse', 'shortstack'],
        'skin': 'fur',
        'negative': ['tall', 'long legs']
    },
    'BeastkinOtter': {
        'body': ['anthro', 'furry', 'otter'],
        'skin': 'fur',
        'negative': []
    },
    'BeastkinSheep': {
        'body': ['anthro', 'furry', 'sheep'],
        'skin': 'fur',
        'negative': []
    },
    'BeastkinSquirrel': {
        'body': ['anthro', 'furry', 'squirrel'],
        'skin': 'fur',
        'negative': []
    },
    'BeastkinTanuki': {
        'body': ['anthro', 'furry', 'tanuki'],
        'skin': 'fur',
        'negative': []
    },
    'BeastkinWolf': {
        'body': ['anthro', 'furry', 'wolf'],
        'skin': 'fur',
        'negative': []
    },
    'Centaur': {
        'body': ['centaur', 'horse lower body'],
        'skin': 'skin',
        'negative': ['human legs', 'human thighs']
    },
    'DarkElf': {
        'body': ['elf'],
        'skin': 'skin',
        'negative': []
    },
    'Demon': {
        'body': ['demon'],
        'skin': 'skin',
        'negative': []
    },
    'Dragonkin': {
        'body': ['dragon scales on arms', 'dragon scales on legs', 'dragon horns'],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': 'dragon $PERSON',
    },
    'Dryad': {
        'body': [],
        'skin': 'skin',
        'negative': []
    },
    'Dwarf': {
        'body': ['dwarf', 'short', 'stout', 'small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs']
    },
    'Elf': {
        'body': ['elf'],
        'skin': 'skin',
        'negative': []
    },
    'Fairy': {
        'body': ['fairy', 'petite'],
        'skin': 'skin',
        'negative': ['feet on ground', 'standing', 'drop shadow']
    },
    'Giant': {
        'body': ['giant', 'humanoid', 'strong'],
        'skin': 'skin',
        'negative': []
    },
    'Gnoll': {
        'body': ['anthro', 'furry', 'hyena'],
        'skin': 'fur',
        'negative': []
    },
    'Gnome': {
        'body': ['short', 'round nose', 'small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs']
    },
    'Goblin': {
        'body': ['goblin', 'short', 'small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs']
    },
    'HalfkinBird': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'bird $PERSON',
    },
    'HalfkinBunny': {
        'body': [],
        'skin': 'skin',
        'negative': ['headband', 'human ears'],
        'personal_descriptor': 'bunny $PERSON',
    },
    'HalfkinCat': {
        'body': [],
        'skin': 'skin',
        'negative': ['cat ears'],
        'personal_descriptor': 'cat $PERSON',
    },
    'HalfkinFox': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'fox $PERSON',
    },
    'HalfkinMouse': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'mouse $PERSON',
    },
    'HalfkinOtter': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'otter $PERSON',
    },
    'HalfkinSheep': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'sheep $PERSON',
    },
    'HalfkinSquirrel': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'squirrel $PERSON',
    },
    'HalfkinTanuki': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'tanuki $PERSON',
    },
    'HalfkinWolf': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': 'wolf $PERSON',
    },
    'Harpy': {
        'body': ['harpy', 'wings for arms', 'bird legs'],
        'skin': 'skin',
        'negative': ['human arms']
    },
    'Human': {
        'body': [],
        'skin': 'skin',
        'negative': []
    },
    'Kobold': {
        'body': ['anthro', 'lizard', 'kobold', 'short stature', 'shortstack'],
        'skin': 'scales',
        'negative': ['human skin', 'smooth skin', 'tall', 'long legs']
    },
    'Lamia': {
        'body': ['lamia', 'scales covering legs', 'legs fused together'],
        'skin': 'skin and scales',
        'negative': ['skin on legs', 'smooth skin on legs', 'legs apart', 'human legs'],
        'personal_descriptor': 'snake $PERSON',
    },
    'Lizardfolk': {
        'body': ['anthro', 'lizard'],
        'skin': 'scales',
        'negative': ['human skin', 'smooth skin']
    },
    'Minotaur': {
        'body': ['minotaur', 'bull head', 'bull horns', 'human body'],
        'skin': 'fur and skin',
        'negative': []
    },
    'Nereid': {
        'body': ['mermaid tail'],
        'skin': 'skin and scales',
        'negative': ['skin on legs', 'smooth skin on legs', 'legs apart', 'human legs']
    },
    'Ogre': {
        'body': ['ogre'],
        'skin': 'skin',
        'negative': []
    },
    'Orc': {
        'body': ['orc', 'wide nose', 'wide mouth', 'tusks'],
        'skin': 'skin',
        'negative': []
    },
    'Ratkin': {
        'body': ['small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs'],
        'personal_descriptor': 'rat $PERSON',
    },
    'Satyr': {
        'body': ['satyr', 'human upper body', 'goat lower body', 'goat legs', 'ram horns'],
        'skin': 'skin and fur',
        'negative': []
    },
    'Scylla': {
        'body': ['scylla', 'human torso on octopus tentacles'],
        'skin': 'skin and tentacles',
        'negative': ['human legs', 'thighs'],
        'personal_descriptor': 'squid $PERSON',
    },
    'Seraph': {
        'body': [],
        'skin': 'skin',
        'negative': []
    },
    'Slime': {
        'body': ['shiny skin', 'slimy skin'],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': 'slime $PERSON',
    },
    'Taurus': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': 'cow $PERSON',
    },
    'TribalElf': {
        'body': ['elf'],
        'skin': 'skin',
        'negative': []
    },
}

func get_personal_descriptor(character, race):
    var attributes = _ATTRIBUTES.get(race, {})
    var sex = character.get_stat('sex')
    var descriptor_template = attributes.get('personal_descriptor')
    if descriptor_template == null:
        return null
    return descriptor_template.replace('$PERSON', 'boy' if sex == 'male' else 'girl')

func get_body_tags(race):
    return _ATTRIBUTES.get(race, {}).get('body', [])

func get_skin_type(race):
    return _ATTRIBUTES.get(race, {}).get('skin', 'skin')

func get_negative_tags(race):
    return _ATTRIBUTES.get(race, {}).get('negative', [])
