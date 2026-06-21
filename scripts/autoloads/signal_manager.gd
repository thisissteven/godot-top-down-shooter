extends Node


signal time_changed(hour : int, minute : int)

signal release_lighting_sprite(light_sprite_id : int)
signal toggle_light(light_on : bool, light_sprite_id : int)
signal update_light_hue(light_sprite_id : int, light_hue : Color)
signal update_light_energy(light_sprite_id : int, light_energy : float)
signal update_light_diameter(light_sprite_id : int, light_diameter : float)
