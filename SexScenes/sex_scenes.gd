extends Node

var path = get_script().get_path().get_base_dir()

func _init():
	pass

func extend_nodes():
	var sex_node = modding_core.get_spec_node(input_handler.NODE_SEX)
	modding_core.extend_node(sex_node, path + '/extended_InteractionMainModule.gd')
