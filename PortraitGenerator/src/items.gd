extends Node

var attribute_overrides = {
    # Daisy's lewd maid costume
    'daisy_dress_lewd': {
        'description': 'slutty maid costume, white crotchless panties, exposed genitals, exposed nipples, frills'
    }
}

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

func item_description(item):
    if item.code in attribute_overrides.keys() or item.itembase in attribute_overrides.keys():
        return attribute_overrides.get(item.code, attribute_overrides.get(item.itembase, {})).get('description', '')
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
