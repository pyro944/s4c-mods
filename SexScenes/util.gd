extends Node

var ModPath = get_script().get_path().get_base_dir()

func load_custom_bg(image_path):
    var stylebox = StyleBoxTexture.new()
    stylebox.texture = input_handler.loadimage(ModPath + '/bg/' + image_path)
    return stylebox

var Participants = {
    'MaleMc': 'MALE_MC',
    'FemaleMc': 'FEMALE_MC',
    'FutaMc': 'FUTA_MC',
    'AnyMale': 'ANY_MALE',
    'AnyFemale': 'ANY_FEMALE',
    'AnyFuta': 'ANY_FUTA',
    # For tw_kennels compatiblity, though integration doesn't actually exist yet
    'Dog': 'KENNELS_DOG',
    'Horse': 'KENNELS_HORSE'
}
