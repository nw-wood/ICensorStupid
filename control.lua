local default_backers = require("backers")
local runtime_backers_loaded = false

local function is_backer_name(name)
	if not name or name == "" then
		return true
	end
	if default_backers[name] then
		return true
	end
	if not runtime_backers_loaded and game and game.backer_names then
		for _, backer in pairs(game.backer_names) do
			default_backers[backer] = true
		end
		runtime_backers_loaded = true
	end
	return default_backers[name] == true
end

local function remove_backer(entity)
	if not (entity and entity.valid and entity.supports_backer_name()) then
		return
	end
	local entity_type = entity.type == "entity-ghost" and entity.ghost_type or entity.type
	if entity_type == "train-stop" then
		if is_backer_name(entity.backer_name) then
			entity.backer_name = "Train stop"
		end
	else
		entity.backer_name = ""
	end
end

local function sanitize_space_platform(platform)
	if platform and platform.valid and is_backer_name(platform.name) then
		platform.name = "Space station"
	end
end

local function clear_space_platform_names()
	for _, force in pairs(game.forces) do
		for _, platform in pairs(force.platforms) do
			sanitize_space_platform(platform)
		end
	end
end

local function clear_backer_names()
	for _, surface in pairs(game.surfaces) do
		for _, ent in pairs(surface.find_entities_filtered { type = { "roboport", "radar", "lab", "train-stop", "locomotive", "entity-ghost" } }) do
			remove_backer(ent)
		end
	end
	clear_space_platform_names()
end

-- Upon loading into the game, search every entity and space platform across all surfaces/forces and replace backer names.
script.on_init(clear_backer_names)
script.on_configuration_changed(clear_backer_names)
script.on_event(defines.events.on_cutscene_cancelled, clear_backer_names)

local function on_built_entity(event)
	remove_backer(event.entity)
end

-- When an entity is built, remove its backer name (or set Train stop to "Train stop").
script.on_event({
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.on_space_platform_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
}, on_built_entity)

-- When a space platform is created or changes state, replace any backer name with "Space station".
script.on_event(defines.events.on_space_platform_changed_state, function(event)
	sanitize_space_platform(event.platform)
end)

script.on_event(defines.events.on_surface_created, function(event)
	local surface = game.surfaces[event.surface_index]
	if surface and surface.valid and surface.platform then
		sanitize_space_platform(surface.platform)
	end
end)

-- Catch newly added space platforms immediately while still in waiting_for_starter_pack state (before surface creation).
script.on_nth_tick(1, clear_space_platform_names)
