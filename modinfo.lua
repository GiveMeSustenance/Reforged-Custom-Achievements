name ="Reforged Custom Achievements"
version = "1.3.4"
description = "Adds new achievements for the Reforged mod and its companion mods \n \nArt by HaoDZ \n \nVersion: "..version
author = "Sustenance"
api_version_dst = 10
priority = -9999999999999999999999999999999999999

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
all_clients_require_mod = true
client_only_mod = false

forge_compatible = true

folder_name = folder_name or "workshop-"
if not folder_name:find("workshop-") then
    name = name.." - Beta Ver."
end

local no_yes_options = {
	{ description =  "No", data = false },
	{ description = "Yes", data =  true }
}

local function LinearOptions(min, max, step, desc)
	desc = desc or ""
    local options = {}
	local index = 1
    for dat = min, max, step do
		options[index] = { description = dat .. desc, data = dat }
		index = index + 1
    end
    return options
end

server_filter_tags = {"rca", "reforge custom achievements"}

configuration_options = 
{

}

mod_dependencies = {

}