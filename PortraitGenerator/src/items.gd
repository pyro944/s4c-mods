extends Node

var _ATTRIBUTE_OVERRIDES = {
    # Daisy's lewd maid costume
    'daisy_dress_lewd': {
        'description': 'slutty maid costume, white crotchless panties, exposed genitals, exposed nipples, frills'
    }
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
