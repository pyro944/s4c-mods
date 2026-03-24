extends Node

var _alpha_regex = null

var CLOTHED_TAGS = ['fully clothed']

# Slot iteration order for equipment prompt generation.
# ass, crotch, underwear are at the end and conditionally skipped when legs are equipped.
var EQUIPMENT_SLOT_ORDER = ['chest', 'hands', 'head', 'neck', 'legs', 'rhand', 'lhand', 'tool', 'underwear', 'ass', 'crotch']
var LEGS_BLOCKED_SLOTS = ['ass', 'crotch', 'underwear']

var NUDE_TAGS = {
    'male': ['nude'],
    'female': ['nude', 'nipples'],
    'futa': ['nude', 'futanari', 'nipples']
}
var SEX_NEGATIVE_TAGS = {
    'male': ['girl', 'woman', 'breasts'],
    'female': ['man', 'boy', 'beard', 'mustache', 'penis'],
    'futa': ['man', 'boy', 'beard', 'mustache']
}
var SEX_NUDITY_NEGATIVE_TAGS = {
    'male': ['nude', 'naked', 'penis'],
    'female': ['nude', 'naked', 'nipples'],
    'futa': ['nude', 'naked', 'penis', 'nipples']
}
var FUTA_TESTICLES_NEGATIVE_OPTION = 'testicles, scrotum, ballsack'

var RACES = {
    'Arachna': {
        'body': ['arachne', 'human spider hybrid', 'human torso attached to spider body'],
        'skin': 'skin',
        'negative': ['spider-man', 'spiderman', 'human legs', 'thighs']
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

func build_prompts(character, positive_user_tags, clothing_user_tags, negative_user_tags):
    var sex = character.get_stat('sex')
    var race = character.get_stat('race')
    var age = character.get_stat('age')
    var skin_color = character.get_stat('body_color_skin')
    var skin_coverage = character.get_stat("skin_coverage")
    var eye_color = character.get_stat('eye_color')
    var eye_shape = character.get_stat('eye_shape')
    var hair_color = character.get_stat('hair_color')
    var hair_style = character.get_stat('hair_style')
    var hair_length = character.get_stat('hair_length')
    var beard = character.get_stat('beard')
    var facial_hair_color = character.get_stat('hair_facial_color')
    var height = character.get_stat('height')
    var breast_size = character.get_stat('tits_size')
    var ass_size = character.get_stat('ass_size')
    var penis_size = character.get_stat('penis_size')
    var wings = character.get_stat("wings")
    var wings_color = character.get_stat("body_color_wings")
    var tail = character.get_stat("tail")
    var tail_color = character.get_stat("body_color_tail")
    var horns = character.get_stat("horns")
    var horns_color = character.get_stat("body_color_horns")
    var ears = character.get_stat("ears")
    var penis_type = character.get_stat("penis_type")

    var nudity_tags = NUDE_TAGS.get(sex, [])
    var sex_negative_tags = SEX_NEGATIVE_TAGS.get(sex, [])
    var nudity_negative_tags = SEX_NUDITY_NEGATIVE_TAGS.get(sex, [])
    var race_attributes = RACES.get(race, {})
    var body_tags = race_attributes.get('body', [])
    var race_negative_tags = race_attributes.get('negative', [])
    var skin_type = race_attributes.get('skin', 'skin')

    var base_tags = subject_tags(sex) + \
        age_tags(age, sex) + \
        body_tags + \
        skin_tags(skin_color, skin_type, skin_coverage) + \
        eye_tags(eye_color, eye_shape) + \
        hair_tags(hair_color, hair_length, hair_style, beard, facial_hair_color) + \
        body_type_tags(height, ass_size, sex) + \
        breasts_tags(breast_size, sex) + \
        wings_tags(wings, wings_color) + \
        tail_tags(tail, tail_color) + \
        horns_tags(horns, horns_color) + \
        ears_tags(ears)

    var positive_tags = []
    if positive_user_tags:
        positive_tags.append(positive_user_tags)
    positive_tags += base_tags + CLOTHED_TAGS
    if clothing_user_tags:
        positive_tags.append(clothing_user_tags)
    var positive_prompt = ', '.join(positive_tags)

    var negative_tags = []
    if negative_user_tags:
        negative_tags.append(negative_user_tags)
    negative_tags += race_negative_tags + \
        sex_negative_tags + \
        nudity_negative_tags
    var negative_prompt = ', '.join(negative_tags)

    var nude_positive_tags = []
    if positive_user_tags:
        nude_positive_tags.append(positive_user_tags)
    nude_positive_tags += base_tags + \
        nudity_tags + \
        genitals_tags(penis_type, penis_size, skin_color)
    var nude_prompt = ', '.join(nude_positive_tags)

    var nude_negative_tags = []
    if negative_user_tags:
        nude_negative_tags.append(negative_user_tags)
    nude_negative_tags += race_negative_tags + \
        sex_negative_tags
    if sex == 'futa' and not futa_have_balls():
        nude_negative_tags.append(FUTA_TESTICLES_NEGATIVE_OPTION)
    var nude_negative_prompt = ', '.join(nude_negative_tags)

    return {
        'clothed_positive': positive_prompt,
        'clothed_negative': negative_prompt,
        'nude_positive': nude_prompt,
        'nude_negative': nude_negative_prompt
    }

func subject_tags(sex):
    sex = {
        'male': 'boy',
        'female': 'girl',
        'futa': 'futa'
    }.get(sex, sex)
    return ['1%s' % sex]

func age_tags(age, sex):
    sex = {
        'male': 'man',
        'female': 'woman',
        'futa': 'woman'
    }.get(sex, sex)
    return ['%s %s' % [age, sex]]

func skin_tags(skin_color, skin_type, skin_coverage):
    var skin = skin_color
    if skin_coverage:
        # Overwrite skin color with fur/scales color
        skin = skin_coverage_to_color(skin_color, skin_coverage)

    return ['%s %s' % [to_simple_color(skin), skin_type]]

func skin_coverage_to_color(skin_color, skin_coverage):
    var coverage_components = skin_coverage.split("_")
    if coverage_components.size() == 2:
        return coverage_components[1]
    elif coverage_components.size() > 2:
        return ' and '.join(coverage_components.slice(1, coverage_components.size() - 1))
    # The others (scales, kobold) don't actually affect skin color
    return to_alpha(skin_color)

func eye_tags(eye_color, eye_shape):
    var components = ['%s eyes' % eye_color]
    if eye_shape != 'normal':
        components.append('%s pupils' % eye_shape)
    return components

func hair_tags(hair_color, hair_length, hair_style, beard, facial_hair_color):
    hair_color = {
        'yellow': 'blonde'
    }.get(hair_color, hair_color)
    if hair_length == 'bald':
        return [hair_length]
    var hair_length_prompt = {
        'ear': 'very short hair',
        'neck': 'short hair',
        'shoulder': 'medium hair',
        'waist': 'long hair',
        'hips': 'extremely long hair'
    }.get(hair_length)
    var components = [
        '%s hair' % hair_color,
        hair_length_prompt,
        '%s hair' % hair_style
    ]

    if beard != 'no':
        components += facial_hair_tags(beard, to_simple_color(facial_hair_color))

    return components

func facial_hair_tags(beard, facial_hair_color):
    return [ {
        'style1': 'short %s beard and bare lip' % facial_hair_color,
        'style2': 'medium %s beard and bare lip' % facial_hair_color,
        'style3': 'bushy %s beard and bare lip' % facial_hair_color,
        'style4': 'long %s beard and bare lip' % facial_hair_color,
        'style5': '%s braided mustache' % facial_hair_color,
        'style6': '%s horseshoe mustache' % facial_hair_color,
        'style7': 'thick %s braided mustache' % facial_hair_color,
        'style8': '%s handlebar mustache' % facial_hair_color,
        'style9': 'short %s braided beard' % facial_hair_color,
        'style10': 'long %s beard and mustache' % facial_hair_color,
        'style11': 'bushy %s braided beard' % facial_hair_color,
        'style12': 'long %s beard and handlebar mustache' % facial_hair_color
    }.get(beard, '')]

func body_type_tags(height, ass_size, sex):
    var build_tags = ['average build']
    if sex in ['female', 'futa']:
        build_tags = {
            'flat': ['slender', 'very narrow hips'],
            'small': ['slender', 'narrow hips'],
            'big': ['wide hips'],
            'huge': ['thick thighs', 'extremely wide hips']
        }.get(ass_size, ['average build'])

    var height_prompt = 'average height'
    if height in ['tall', 'towering']:
        height_prompt = 'very tall'
    elif height in ['short', 'petite', 'tiny']:
        height_prompt = 'very short'

    return [height_prompt] + build_tags

func breasts_tags(breast_size, sex):
    if breast_size == 'masculine':
        return ['defined abs']
    if sex == 'male':
        return []
    if breast_size == 'flat':
        return ['flat chest']
    breast_size = {
        'average': 'medium',
        'average_high': 'medium perky',
        'average_narrow': 'medium narrow',
        'average_wide': 'medium wide',
        'big': 'large',
        'big_high': 'large perky',
        'big_narrow': 'large narrow',
        'huge_high': 'huge perky',
        'huge_narrow': 'huge narrow',
        'huge_wide': 'huge wide'
    }.get(breast_size, breast_size)
    return ['%s breasts' % breast_size]

func wings_tags(wings, wings_color):
    wings = {
        'seraph': 'angel'
    }.get(wings, wings)
    if not wings:
        return []
    return ['%s %s wings' % [to_simple_color(wings_color), to_alpha(wings)]]

func tail_tags(tail, tail_color):
    tail = {
        'avali': 'bird'
    }.get(tail, tail)
    if not tail:
        return []
    return ['%s %s tail' % [to_simple_color(tail_color), to_alpha(tail)]]

func horns_tags(horns, horns_color):
    if not horns or horns == 'none':
        return []
    return ['%s %s horns' % [to_simple_color(horns_color), to_alpha(horns)]]

func ears_tags(ears):
    ears = {
        'avali': 'feathered',
        'bunny_drooping': 'floppy bunny',
        'bunny_standing': 'upright bunny',
        'demon': 'pointed',
        'elven': 'elf',
        'fish': 'fin',
        'orcish': 'pointed'
    }.get(ears, ears)
    if ears == 'normal':
        return []
    return ['%s ears' % ears]

func genitals_tags(penis_type, penis_size, skin_color):
    if penis_size:
        if penis_type == 'human':
            penis_type = ''
        return ['%s %s %s penis' % [penis_size, to_simple_color(skin_color), penis_type]]
    return ['vulva']

func to_simple_color(skin_color):
    var translated_color = {
        'human1': 'fair',
        'human2': 'light',
        'human3': 'light brown',
        'human4': 'brown',
        'human5': 'dark brown',
        'dark1': 'dark grey',
        'dark2': 'very dark grey',
        'dark3': 'black',
        'dark_1': 'dark grey',
        'dark_2': 'very dark grey',
        'dark_3': 'black'
    }.get(skin_color, null)
    if translated_color:
        return translated_color

    return to_alpha(skin_color)
    
func to_alpha(value):
    if _alpha_regex == null:
        _alpha_regex = RegEx.new()
        _alpha_regex.compile('[\\d_]')
    return _alpha_regex.sub(value, '', true)

func build_equipment_prompt(character):
    var gear = character.equipment.gear
    var poss = 'his' if character.get_stat('sex') == 'male' else 'her'
    var has_legs = gear.legs != null
    var seen_item_ids = {}
    var phrases = []

    for slot in EQUIPMENT_SLOT_ORDER:
        var item_id = gear[slot]
        if item_id == null:
            continue
        if has_legs and slot in LEGS_BLOCKED_SLOTS:
            continue
        if seen_item_ids.has(item_id):
            continue
        seen_item_ids[item_id] = true

        var item = ResourceScripts.game_res.items[item_id]
        var desc = _equipment_item_desc(item)

        match slot:
            'head':
                phrases.append('wearing %s on %s head' % [desc, poss])
            'neck':
                phrases.append('wearing a %s around %s neck' % [desc, poss])
            'chest', 'legs', 'underwear', 'ass', 'crotch':
                phrases.append('wearing %s' % desc)
            'hands':
                phrases.append('wearing %s on %s hands' % [desc, poss])
            'rhand':
                phrases.append('holding a %s in %s right hand' % [desc, poss])
            'lhand':
                phrases.append('holding a %s in %s left hand' % [desc, poss])
            # 'tool':
            #     phrases.append('carrying a %s' % desc)

    return ', '.join(phrases)

var PART_LABELS = {
    'WeaponHandle': 'handle',
    'ToolHandle': 'handle',
    'ToolBlade': 'blade',
    'ToolClothwork': 'cloth',
    'ArmorTrim': 'trim',
    'BowTrim': 'trim',
    'ArmorEnc': 'accent',
    'WeaponEnc': 'accent',
    'ArmorCloth': 'cloth lining',
    'JewelryGem': 'gem',
}

func _equipment_item_desc(item):
    var desc = item.name.to_lower()
    if item.parts.empty():
        return desc
    var primary_part = Items.itemlist[item.itembase].get('partmaterialname', '')
    var suffixes = []
    for part_key in item.parts:
        if part_key == primary_part:
            continue
        if not PART_LABELS.has(part_key):
            continue
        var mat_code = item.parts[part_key]
        if not Items.materiallist.has(mat_code):
            continue
        var mat = Items.materiallist[mat_code]
        if not mat.has('adjective') or mat.adjective == '':
            continue
        suffixes.append('%s %s' % [mat.adjective.to_lower(), PART_LABELS[part_key]])
    if not suffixes.empty():
        desc += ' with ' + ' and '.join(suffixes)
    return desc

# Pulled out down here because `input_handler` isn't defined and it brings syntax checking to a halt
func futa_have_balls():
    return input_handler.globalsettings.futa_balls
