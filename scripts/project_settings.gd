extends Node

func _ready():
	print("--- Modified Project Settings ---")
	
	# Fetch all available properties inside ProjectSettings
	var properties = ProjectSettings.get_property_list()
	
	for prop in properties:
		var property_name = prop["name"]
		
		# Filter out internal properties that aren't configuration settings
		if prop["type"] == TYPE_NIL or property_name.begins_with("internal/"):
			continue
			
		# Check if the setting is different from the factory default
		if ProjectSettings.has_setting(property_name):
			var current_value = ProjectSettings.get_setting(property_name)
			
			# If the setting has been changed from Godot's built-in default
			if ProjectSettings.property_can_revert(property_name):
				var default_value = ProjectSettings.property_get_revert(property_name)
				
				if str(current_value) != str(default_value):
					print("%s: %s (Default: %s)" % [property_name, current_value, default_value])
