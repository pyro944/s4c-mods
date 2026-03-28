extends Node

var attributes = {
    'Arachna': {
        'body': ['arachne', 'human spider hybrid', 'human torso attached to spider body'],
        'skin': 'skin',
        'negative': ['spider-man', 'spiderman', 'human legs', 'thighs'],
    },
    'Avali': {
        'body': ['harpy', 'wings for arms', 'bird legs', 'feather mane'],
        'skin': 'skin',
        'negative': ['human arms']
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
        'negative': []
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
        'negative': ['human ears']
    },
    'HalfkinBunny': {
        'body': [],
        'skin': 'skin',
        'negative': ['headband', 'human ears']
    },
    'HalfkinCat': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
    },
    'HalfkinFox': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
    },
    'HalfkinMouse': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
    },
    'HalfkinOtter': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
    },
    'HalfkinSheep': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
    },
    'HalfkinSquirrel': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
    },
    'HalfkinTanuki': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
    },
    'HalfkinWolf': {
        'body': [],
        'skin': 'skin',
        'negative': ['human ears']
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
        'body': ['snake person', 'lamia', 'scales covering legs', 'legs fused together'],
        'skin': 'skin and scales',
        'negative': ['skin on legs', 'smooth skin on legs', 'legs apart', 'human legs']
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
        'negative': ['tall', 'long legs']
    },
    'Satyr': {
        'body': ['satyr', 'human upper body', 'goat lower body', 'goat legs', 'ram horns'],
        'skin': 'skin and fur',
        'negative': []
    },
    'Scylla': {
        'body': ['squid person', 'scylla', 'human torso on octopus tentacles'],
        'skin': 'skin and tentacles',
        'negative': ['human legs', 'thighs']
    },
    'Seraph': {
        'body': [],
        'skin': 'skin',
        'negative': []
    },
    'Slime': {
        'body': ['slime person', 'shiny skin', 'slimy skin'],
        'skin': 'skin',
        'negative': []
    },
    'Taurus': {
        'body': [],
        'skin': 'skin',
        'negative': []
    },
    'TribalElf': {
        'body': ['elf'],
        'skin': 'skin',
        'negative': []
    },
}
