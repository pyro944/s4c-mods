extends Popup

# FilterableDropdown: A searchable dropdown popup backed by an ItemList.
#
# Setup (by the parent script):
#   dropdown.setup(mod_path)
#   dropdown.set_items(["lora_a", "lora_b", ...])
#   dropdown.connect("item_selected", self, "_on_lora_selected")
#
# Usage:
#   dropdown.filter("query")      # filter and show
#   dropdown.show_below(control)  # position below a control and show
#   dropdown.selected_item        # the last selected item name, or ""

signal item_selected(item_name)

var selected_item = ""

var _items = []
var _item_list = null
var _max_visible = 50

func setup(mod_path):
    _item_list = $PanelContainer/ItemList
    _item_list.connect("item_selected", self , "_on_item_selected")
    var panel_bg = load(mod_path + "/resources/styles/panel_bg.tres")
    if panel_bg:
        $PanelContainer.add_stylebox_override("panel", panel_bg)

func set_items(items):
    _items = items
    _items.sort_custom(self , "_sort_by_lowercase")
    selected_item = ""

func filter(query, anchor_control = null):
    _item_list.clear()
    var q = query.to_lower()
    var count = 0
    for i in range(_items.size()):
        var item_name = _items[i]
        if q == "" or item_name.to_lower().find(q) != -1:
            if count < _max_visible:
                _item_list.add_item(item_name)
                _item_list.set_item_metadata(count, i)
            count += 1
    if count == 0:
        _item_list.add_item("(no matches)")
        _item_list.set_item_disabled(0, true)
        _item_list.set_item_selectable(0, false)
    elif count > _max_visible:
        var hint_idx = _item_list.get_item_count()
        _item_list.add_item("(" + str(count - _max_visible) + " more \u2014 type to narrow...)")
        _item_list.set_item_disabled(hint_idx, true)
        _item_list.set_item_selectable(hint_idx, false)
    if anchor_control != null:
        show_below(anchor_control)

func show_below(control):
    if _item_list.get_item_count() == 0:
        return
    var rect = control.get_global_rect()
    var popup_size = Vector2(rect.size.x, min(_item_list.get_item_count() * 28, 200))
    popup(Rect2(Vector2(rect.position.x, rect.position.y + rect.size.y), popup_size))

func _on_item_selected(index):
    var item_idx = _item_list.get_item_metadata(index)
    if item_idx == null:
        return
    selected_item = _items[item_idx]
    # Defer hide so the click finishes processing before the popup disappears,
    # preventing click-through to controls behind it.
    call_deferred("_deferred_close")

func _deferred_close():
    hide()
    emit_signal("item_selected", selected_item)

func _sort_by_lowercase(a, b):
    return a.to_lower() < b.to_lower()
