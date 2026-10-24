local function remove_backer(entity)
	if entity and entity.valid and entity.supports_backer_name() then
		entity.backer_name = ""
	end
end

local function clear_backer_names()
	for _, surface in pairs(game.surfaces) do
		for _, ent in pairs(surface.find_entities_filtered { type = { "roboport", "radar", "lab", "train-stop", "locomotive" } }) do
			remove_backer(ent)
		end
	end
end

-- Upon loading into the game, search every entity for Labs, Roboports, Radars, Train stops, and Locomotives, and remove their backer name.
script.on_init(clear_backer_names)
script.on_configuration_changed(clear_backer_names)
script.on_event(defines.events.on_cutscene_cancelled, clear_backer_names)

local function on_built_entity(event)
	remove_backer(event.entity)
end

-- When an entity is built, remove its backer name.
script.on_event({
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.on_space_platform_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
}, on_built_entity)
