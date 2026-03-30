extends Node

var _ATTRIBUTES = {
    'Arachna': {
        'body': ['arachne', 'human spider hybrid', 'human torso attached to spider body', 'fused at the waist'],
        'skin': 'skin',
        'negative': ['spider-man', 'spiderman', 'human legs', 'thighs'],
        'personal_descriptor': '(spider $PERSON:1.5)',
    },
    'Avali': {
        'body': ['harpy', 'wings for arms', 'bird legs', 'feather mane'],
        'skin': 'skin',
        'negative': ['human arms'],
        'personal_descriptor': '(half bird $PERSON:1.5)',
    },
    'BeastkinBird': {
        'body': ['furry', 'bird head', 'wings for arms', 'bird legs'],
        'skin': 'feathers',
        'negative': ['human arms'],
        'personal_descriptor': '(anthro bird $PERSON:1.5)',
    },
    'BeastkinBunny': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro rabbit $PERSON:1.5)',
    },
    'BeastkinCat': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro cat $PERSON:1.5)',
    },
    'BeastkinFox': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro fox $PERSON:1.5)',
    },
    'BeastkinMouse': {
        'body': ['furry', 'shortstack'],
        'skin': 'fur',
        'negative': ['tall', 'long legs'],
        'personal_descriptor': '(anthro mouse $PERSON:1.5)',
    },
    'BeastkinOtter': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro otter $PERSON:1.5)',
    },
    'BeastkinSheep': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro sheep $PERSON:1.5)',
    },
    'BeastkinSquirrel': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro squirrel $PERSON:1.5)',
    },
    'BeastkinTanuki': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro raccoon $PERSON:1.5)',
    },
    'BeastkinWolf': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro wolf $PERSON:1.5)',
    },
    'Centaur': {
        'body': ['horse lower body'],
        'skin': 'skin',
        'negative': ['human legs', 'human thighs'],
        'personal_descriptor': '(centaur $PERSON:1.5)',
    },
    'DarkElf': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(dark elf $PERSON:1.5)',
    },
    'Demon': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(demon $PERSON:1.5)',
    },
    'Dragonkin': {
        'body': ['dragon scales on arms', 'dragon scales on legs', 'dragon horns'],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(half dragon $PERSON:1.5)',
    },
    'Dryad': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(plant $PERSON:1.5)',
    },
    'Dwarf': {
        'body': ['short', 'stout', 'small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs'],
        'personal_descriptor': '(dwarf $PERSON:1.5)',
    },
    'Elf': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(elf $PERSON:1.5)',
    },
    'Fairy': {
        'body': ['petite'],
        'skin': 'skin',
        'negative': ['feet on ground', 'standing', 'drop shadow'],
        'personal_descriptor': '(fairy $PERSON:1.5)',
    },
    'Giant': {
        'body': ['humanoid', 'strong'],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(giant $PERSON:1.5)',
    },
    'Gnoll': {
        'body': ['furry'],
        'skin': 'fur',
        'negative': [],
        'personal_descriptor': '(anthro hyena $PERSON:1.5)',
    },
    'Gnome': {
        'body': ['short', 'round nose', 'small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs'],
        'personal_descriptor': '(gnome $PERSON:1.5)',
    },
    'Goblin': {
        'body': ['short', 'small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs'],
        'personal_descriptor': '(goblin $PERSON:1.5)',
    },
    'HalfkinBird': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half bird $PERSON:1.5)',
    },
    'HalfkinBunny': {
        'body': [],
        'skin': 'skin',
        'negative': ['headband', 'human ears'],
        'personal_descriptor': '(half rabbit  $PERSON:1.5)',
    },
    'HalfkinCat': {
        'body': [],
        'skin': 'skin',
        'negative': ['cat ears'],
        'personal_descriptor': '(half cat $PERSON:1.5)',
    },
    'HalfkinFox': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half fox $PERSON:1.5)',
    },
    'HalfkinMouse': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half mouse $PERSON:1.5)',
    },
    'HalfkinOtter': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half otter $PERSON:1.5)',
    },
    'HalfkinSheep': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half sheep $PERSON:1.5)',
    },
    'HalfkinSquirrel': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half squirrel $PERSON:1.5)',
    },
    'HalfkinTanuki': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half tanuki $PERSON:1.5)',
    },
    'HalfkinWolf': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears'],
        'personal_descriptor': '(half wolf $PERSON:1.5)',
    },
    'Harpy': {
        'body': ['wings for arms', 'bird legs'],
        'skin': 'skin',
        'negative': ['human arms'],
        'personal_descriptor': '(harpy $PERSON:1.5)',
    },
    'Human': {
        'body': [],
        'skin': 'skin',
        'negative': []
    },
    'Kobold': {
        'body': ['anthro', 'short stature', 'shortstack'],
        'skin': 'scales',
        'negative': ['human skin', 'smooth skin', 'tall', 'long legs'],
        'personal_descriptor': '(kobold $PERSON:1.5)',
    },
    'Lamia': {
        'body': ['scales covering legs', 'legs fused together'],
        'skin': 'skin and scales',
        'negative': ['skin on legs', 'smooth skin on legs', 'legs apart', 'human legs'],
        'personal_descriptor': '(lamia $PERSON:1.5)',
    },
    'Lizardfolk': {
        'body': ['anthro'],
        'skin': 'scales',
        'negative': ['human skin', 'smooth skin'],
        'personal_descriptor': '(lizard $PERSON:1.5)',
    },
    'Minotaur': {
        'body': ['bull head', 'bull horns', 'human body'],
        'skin': 'fur and skin',
        'negative': [],
        'personal_descriptor': '(minotaur $PERSON:1.5)',
    },
    'Nereid': {
        'body': ['mermaid tail'],
        'skin': 'skin and scales',
        'negative': ['skin on legs', 'smooth skin on legs', 'legs apart', 'human legs'],
        'personal_descriptor': '(nereid $PERSON:1.5)',
    },
    'Ogre': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(oni $PERSON:1.5)',
    },
    'Orc': {
        'body': ['tusks'],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(orc $PERSON:1.5)',
    },
    'Ratkin': {
        'body': ['small stature', 'shortstack'],
        'skin': 'skin',
        'negative': ['tall', 'long legs'],
        'personal_descriptor': '(half rat $PERSON:1.5)',
    },
    'Satyr': {
        'body': ['human upper body', 'goat lower body', 'goat legs', 'ram horns'],
        'skin': 'skin and fur',
        'negative': [],
        'personal_descriptor': '(satyr $PERSON:1.5)',
    },
    'Scylla': {
        'body': ['human torso on octopus tentacles'],
        'skin': 'skin and tentacles',
        'negative': ['human legs', 'thighs'],
        'personal_descriptor': '(scylla $PERSON:1.5)',
    },
    'Seraph': {
        'body': [],
        'skin': 'skin',
        'negative': []
    },
    'Slime': {
        'body': ['translucent skin', 'slimy skin'],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(slime $PERSON:1.5)',
    },
    'Taurus': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(half cow $PERSON:1.5)',
    },
    'TribalElf': {
        'body': [],
        'skin': 'skin',
        'negative': [],
        'personal_descriptor': '(elf $PERSON:1.5)',
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
