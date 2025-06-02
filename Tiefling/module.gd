extends Node

var path = get_script().get_path().get_base_dir()

func _init():
	pass

func _ready():
	pass

func extend_nodes():
	pass

func load_translations(activetranslation):
    modding_core.load_translation(tr_table, activetranslation)

func load_tables():
    races.racelist.Tiefling = TIEFLING_RACE;
    races.short_race_names.Tiefling = ['tiefling', 'planetouched']

const TIEFLING_RACE = {
    code = "Tiefling",
    name = '',
    descript = '',
    adjective = '',
    icon = "res://assets/images/iconsraces/demon.png",
    basestats = {
        food_consumption = [2,4],
        physics_factor = [2,5],
        magic_factor = [2,5],
        tame_factor = [1,2],
        authority_factor = [2,5],
        sexuals_factor = [4,5],
        charm_factor = [1,4],
        wits_factor = [2,5],
    },
    race_bonus = {resist_fire = 20, mastery_fire = 1, price = 120},
    personality = {kind = 0.2, bold = 1, shy = 0.3, serious = 1},
    diet_love = {vege = 0.5, meat = 2, fish = 1, grain = 1},
    diet_hate = {vege = 20, meat = 5, fish = 10, grain = 15},
    tags = [],
    race_tags = ['uncommon'],
    bodyparts = {
        eye_color = ['yellow','red','black', 'green', 'cyan', 'pink', 'grey'],
        skin = ['grey', 'purple', 'teal', 'blue', 'red', 'pink'],
        body_color_skin = ['blue2', 'blue3', 'blue4', 'blue5', 'grey3', 'pink4', 'pink5', 'purple4', 'purple5', 'red4', 'red5'],
        body_color_lips = ['blue', 'cyan', 'pink', 'purple', 'red', 'black', 'blue', 'purple', 'pink'],
        body_color_horns = ['blue1', 'dark2', 'cyan2', 'pink2', 'purple1', 'red4'],
        hair_color = ['blond','red','auburn','brown','black'],
        hair_base_color_1 = ['yellow_1','red_1', 'red_2', 'red_3','brown_1','brown_2', 'brown_3', 'dark_1', 'dark_2', 'dark_3', 'blue_1', 'blue_2', 'blue_3', 'cyan_1', 'cyan_2', 'cyan_3', 'pink_1', 'pink_2', 'pink_3', 'purple_1', 'purple_2', 'purple_3'],
        ears = ['elven'],
        horns = ['short', 'curved', 'straight', 'spiral', 'spiral_2'],
        tail = ['demon'],
        penis_type = ['human'],
        },
    global_weight = 5,
    training_disposition = {
        humiliation = [['resist', 10],['neutral', 10],['weak',1],['kink',1]],
        physical = [['resist', 5],['neutral', 5],['weak',5],['kink',3]],
        sexual = [['resist', 7],['neutral', 5],['weak',2],['kink',5]],
        social = [['resist', 7],['neutral', 8]],
        positive = [['resist', 5],['neutral', 5],['weak',1],['kink',3]],
        magic = [['resist', 5],['neutral', 3],['weak',5],['kink',2]],
    }
}

var tr_table = {
    RACETIEFLING = 'Tiefling',
    RACETIEFLINGADJ = 'Tiefling',
    RACETIEFLINGDESCRIPT = 'Tieflings are a humanoid race descended from devils and mortals. They resemble demons but do not inherit demonic personalities. Tieflings are naturally resistant to fire.'
}
