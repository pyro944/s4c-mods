extends Node

var _ATTRIBUTE_OVERRIDES = {
    'leather_collar': {
        'description': 'leather slave collar'
    },
    'steel_collar': {
        'description': 'steel slave collar'
    },
    'elegant_choker': {
        'description': 'black choker with a silver heart in the center'
    },
    'amulet_of_recognition': {
        'description': 'gold necklace with a large green gem'
    },
    'animal_ears': {
        'description': 'fake animal ears headband'
    },
    'tail_plug': {
        'description': 'butt plug with an animal tail'
    },
    'animal_gloves': {
        'description': 'cosplay furry animal gloves'
    },
        # maybe make a animal randomizer for all the pieces so they match?
    'pet_suit': {
        'description': 'a slutty and revealing cat cosplay with matching tail ears and furry cat gloves'
    },
    'worker_outfit': {
        'description': 'slutty peaseants wear, covered chest, covered genitals'
    },
    'craftsman_suit': {
        'description': 'normal clothes with a leather work apron, craftsman, covered chest, covered genitals'
    },
    'seethrough_underwear': {
        'description': 'slutty lace lingerie, (nipples visible through lingerie, genitals visible through lingerie:1.3)'
    },
    # maybe something that checks if futa/male to add 'buldge' to this and remove penis/pussy/nipples from negative
    'service_suit': {
        'description': 'black leotard, long gloves, fishnet stockings, bunny tail, white bunny ear headband'
    },
    'handcuffs': {
        'description': 'leather wrist restraints'
    },
    'strapon': {
        'description': 'giant purple strapon'
    },
    'chastity_belt': {
        'description': 'chastity belt, <lora:chastity:0.6>'
    },
    # gonna add a few loras for those who will use the tag loader, if not they're pretty harmless here
    'stimulative_underwear': {
        'description': 'tentacle panties, (tentacle panties, living clothing:1.4),  <lora:tentacle_clothes:1>'
    },
    'tentacle_suit': {
        'description': 'tentacle outfit, (slutty tentacle suit, living clothing:1.4),  <lora:tentacle_clothes:1>'
    },
    'anal_beads': {
        'description': 'anal beads in ass, exposed anus, anal object insertion'
    },
    'anal_plug': {
        'description': 'anal plug in ass, exposed anus, anal object insertion'
    },
    'mask': {
        'description': 'white ceramic full face doll mask'
    },
    #stopped testing here
    'anastasia_bracelet': {
        'description': 'a large silver braclet with blue gems'
    },
    'anastasia_broken_bracelet': {
        'description': 'a large silver bracelet with red gems with a slight red glow'
    },
    'daisy_dress': {
        'description': 'an exquisite maid dress'
    },
    'daisy_dress_lewd': {
        'description': 'black lace crotchless panties, (black and white cloth revealing maid cosplay:1.3), frills, open front skirt, exposed shoulders, (exposed genitals, exposed breasts, exposed midriff:1.5),  breast support, (black sheer stockings and long gloves), NSFW'
    },
    'aire_bow': {
        'description': 'a powerfully enchanted elven bow'
    },
    'cali_collar': {
        'description': 'a leather slave collar with a tag that says cali'
    },
    'cali_exquisite_collar': {
        'description': 'a beautiful leather slave collar with a tag that says cali'
    },
    'cali_collar_enchanted': {
        'description': 'a purple glowing leather slave collar with a tag that says cali'
    },
    'cali_collar_enchanted_2': {
        'description': 'a red glowing leather slave collar with a tag that says cali'
    },
    'enslaving_collar': {
        'description': 'a leather and metal spiked collar'
    },
    'ramont_axe': {
        'description': 'a gigantic double sided battleaxe'
    },
    'erlen_sword': {
        'description': 'an elven sword'
    },
    'garb_of_forest': {
        'description': 'an enchanted armour made of leaves and bark'
    },
}

var _PART_LABELS = {
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

func item_description(item):
    if item.code in _ATTRIBUTE_OVERRIDES.keys() or item.itembase in _ATTRIBUTE_OVERRIDES.keys():
        return _ATTRIBUTE_OVERRIDES.get(item.code, _ATTRIBUTE_OVERRIDES.get(item.itembase, {})).get('description', '')
    return _generic_item_desc(item)

func _generic_item_desc(item):
    var desc = item.name.to_lower()
    if item.parts.empty():
        return desc
    var primary_part = Items.itemlist[item.itembase].get('partmaterialname', '')
    var suffixes = []
    for part_key in item.parts:
        if part_key == primary_part:
            continue
        if not _PART_LABELS.has(part_key):
            continue
        var mat_code = item.parts[part_key]
        if not Items.materiallist.has(mat_code):
            continue
        var mat = Items.materiallist[mat_code]
        if not mat.has('adjective') or mat.adjective == '':
            continue
        suffixes.append('%s %s' % [mat.adjective.to_lower(), _PART_LABELS[part_key]])
    if not suffixes.empty():
        desc += ' with ' + ' and '.join(suffixes)
    return desc
