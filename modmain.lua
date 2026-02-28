local _G = GLOBAL
local LEVEL_XP = 20000
local function SetLevelXP(xp)
    return math.floor(LEVEL_XP*(xp or 1))
end

_G.TUNING.FORGE = require("forge_tuning")

local require = _G.require
require("commands")

Assets = require("RCA_assets")

local debug_prints = false

--------------------------------------------------------------------------
-- Check Conditions
--------------------------------------------------------------------------
local victory_id      = "victory"
local rlgl_id         = "rlgl"
local mutator_id      = "mutator"
local damage_id       = "damage"
local survive_id      = "survive"
local player_count_id = "player_count"
local speed_run_id    = "speed_run"
local mob_id          = "mob"
local player_id       = "player"
local equipment_id    = "equipment"

local gimmick_id      = "gimmick"

modimport("scripts/achievement_strings.lua")
modimport("scripts/RCA_tuning.lua")
local rca_common = require("tracker_functions")

local function IsNonSpectator(player)
    return player.prefab ~= "spectator"
end

local function VictoryOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker
    achievement_tracker:UpdateAchievementProgress(achievement_name, userid, lavaarenaevent.victory)
end

-- Allows duplicator achievements to be gotten with either the waveset (from pugnax) or duplicator.
local function VictoryOnDupeMatchComplete(lavaarenaevent, userid, achievement_name)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker

    local match_settings = _G.REFORGED_SETTINGS.gameplay
    local match_waveset = match_settings.waveset
    local match_duplicator = match_settings.mutators.mob_duplicator or 0

    local achievement_data = _G.REFORGED_DATA.achievements[achievement_name]
    local achievement_waveset = achievement_data.requirements.wavesets
    local achievement_duplicator = achievement_data.requirements.mutators.mob_duplicator or 0

    local waveset_to_dupe = {
        ["doubletrouble"] = 2,
        ["triplethreat"] = 3,
        ["quintuplestruggle"] = 5,
        ["tenfoldterror"] = 10,
    }

    for key, value in pairs(achievement_waveset) do
        if waveset_to_dupe[value] and achievement_duplicator == 0 then
            achievement_duplicator = waveset_to_dupe[value]
            break
        end
    end
    
    -- match is a dupe waveset and that dupe waveset is in the achievement requirements
    -- OR
    -- any included waveset and appropriate dupe mutator
    if
        waveset_to_dupe[match_waveset] and table.contains(achievement_waveset, match_waveset)
        or table.contains(achievement_waveset, match_waveset) and (match_duplicator >= achievement_duplicator)
    then
        achievement_tracker:UpdateAchievementProgress(achievement_name, userid, lavaarenaevent.victory)
    end
end

local function HasRequirement(requirements, val)

    if debug_prints then print("checking req...") end

    for _,req in pairs(requirements) do

        if debug_prints then
            print("- req: " .. tostring(req))
            print("- val: " .. tostring(val))
        end

        if req == val then

            if debug_prints then
                print("- success")
            end

            return true
        end
    end

    if debug_prints then
        print("- failed")
    end

    return false
end

-- overwrite reforged achievement detection to allow for achievements to use mutators less than their default value
AddComponentPostInit("achievement_tracker", function(self)

    if not _G.TheWorld or not _G.TheWorld.ismastersim then return end

    local old_CheckRequirementsForAchievement = self.CheckRequirementsForAchievement

    self.CheckRequirementsForAchievement = function(self, name, player)
        --local AchievementTracker = _G.TheWorld.components.achievement_tracker
        local REFORGED_DATA = _G.REFORGED_DATA
        local REFORGED_SETTINGS = _G.REFORGED_SETTINGS

        local settings_key = {difficulty = "difficulties", gametype = "gametypes", map = "maps", mode = "modes", mutators = "mutators", preset = "presets", waveset = "wavesets"}

        if debug_prints then
            print("Checking Requirements for " .. tostring(name))
        end

        local requirements = REFORGED_DATA.achievements[name].requirements
        if requirements.player_count and requirements.player_count < _G.TheWorld.components.stat_tracker:GetTotalActivePlayerCount() or #requirements.presets > 0 and not HasRequirement(requirements.presets, REFORGED_SETTINGS.gameplay.preset) or #requirements.characters > 0 and not HasRequirement(requirements.characters, player.prefab) then
            return false
        -- Check settings if no preset is required.
        elseif #requirements.presets <= 0 then

            if debug_prints then
                print("Checking Gameplay Settings...")
            end

            for setting,val in pairs(REFORGED_SETTINGS.gameplay) do
                if setting == "mutators" then
                    local ignore_mutators = type(requirements.mutators) ~= "table" and requirements.mutators ~= nil -- Setting the mutator requirements to anything but a table of mutators will set it to ignore all mutator values.
                    if not ignore_mutators then
                        for mutator,value in pairs(val) do

                            if debug_prints then
                                print("- mutator: " .. tostring(mutator))
                                print("- req: " .. tostring(requirements.mutators[mutator]))
                                print("- val: " .. tostring(value))
                            end

                            local values_match = requirements.mutators[mutator] and requirements.mutators[mutator] == value or nil

                            -- ff = default 0, requires 1
                            -- Pass on [values match requirements] OR [values are higher than requirements]
                            -- SO
                            -- fail on [values do not match requirements] AND [values are lower than requirements]
                            
                            if requirements.mutators[mutator] ~= nil and not values_match then -- [values do not match requirements]
                                -- different boolean mutators is an auto fail. Its impossible to know if it makes the mode easier or not.
                                if type(requirements.mutators[mutator]) == "boolean" or (value ~= nil and requirements.mutators[mutator] > value) then --[values are lower than requirements]
                                    
                                    if debug_prints then    
                                        print("- requirement failed")
                                        print("- - " .. tostring(mutator) .. ": " .. tostring(value).." should be "..tostring(requirements.mutators[mutator]).." default is "..tostring(REFORGED_DATA.mutators[mutator].default_value))
                                    end
                                    return false
                                end
                            end
                        end
                    end
                elseif requirements[settings_key[setting]] and #requirements[settings_key[setting]] > 0 and not HasRequirement(requirements[settings_key[setting]], val) then

                    if debug_prints then
                        print("- requirement failed")
                        print("- - " .. tostring(setting) .. ": " .. tostring(val).." should be "..tostring(requirements[settings_key[setting]]))
                    end
                    return false
                end
            end
        end
        return true
    end
end)

--------------------------------------------------------------------------
-- Achievements -- Function and Formatting
--------------------------------------------------------------------------
--[[ Achievement Requirements
local req = {
        player_count = nil,
        characters   = {},
        difficulties = {},
        gametypes    = {},
        maps         = {},
        modes        = {},
        mutators     = {},
        presets      = {},
        wavesets     = {},
    }
]]

--[[ Add Achievement Function
_G.AddAchievement(
"test",                     --is_valid_fn
IsNonSpectator,             --track_fn
nil,                        --track_fn
VictoryOnMatchComplete,     --on_match_complete_fn
nil,                        --max_progress
achievement_req,            --req
SetLevelXP(100),            --exp or 1000
5,                          --tier
achievement_icon,           --icon or {atlas = "images/reforged.xml", tex = "p_unknown.tex"}
victory_id,                 --id
"RCA"                       --mod
)
]]

local server_mods = nil

if _G and _G.TheNet then
    server_mods = _G.TheNet:GetServerModNames()
end

--------------------------------------------------------------------------
-- Reforged
--------------------------------------------------------------------------

--[[--------Presets--------

    forge_season_1          - -     "Forge S01",
    forge_season_2          - -     "Forge S02",
    half_the_wrath          - -     "Half The Wrath",
    double_trouble          - -     "Double Trouble",
    triple_threat           - -     "Triple Threat",
    quintuple_struggle      - -     "Quintuple Struggle",
    tenfold_terror          - -     "Tenfold Terror",
    fast_but_weak           - -     "Fast/Weak",
    x2                      - -     "x2",
    x3                      - -     "x3",
    half                    - -     "1/2",
    mutated                 - -     "Mutated",
    double_doom             - -     "Double Doom",
    chaotic                 - -     "Chaotic",
    coffee                  - -     "Coffee'd",
    double_half             - -     "Double 1/2",
    half_double             - -     "Half x2",
    attack_of_titans        - -     "Attack of Titans",
    insanity                - -     "Insanity",
    custom                  - -     "Custom",
]]

--[[--------Wavesets--------

    classic                 - -
    boarilla                - -
    boarillas               - -
    rhinocebros             - -
    swineclops              - -
    default                 - -         <-- unused
    double_trouble_classic  - -       <-- no swine
    doubletrouble           - -      <-- unused
    half_the_wrath          - -
    sandbox                 - -
    randomized              - -
]]

--[[--------Difficulties--------

    normal                  - -
    hard                    - -
]]

--[[--------Gametypes--------

    forge                   - -
    classic_rlgl            - -
    rlgl                    - -    (rlglblol)
]]

--[[--------Modes--------

    forge                   - -     <-- unused
    forge_s01               - -
    forge_s02               - -
    reforged                - -
    forged_forge            - -
]]

--[[--------Mutators--------

    mob_damage_dealt            - -
    mob_damage_received         - -
    mob_health                  - -
    mob_speed                   - -
    mob_attack_rate             - -
    mob_size                    - -
    battlestandard_efficiency   - -
    no_sleep                    - -
    no_revives                  - -
    no_hud                      - -
    friendly_fire               - -
    unbreakable_shields         - -     <-- unused
    endless                     - -     
    mob_duplicator              - -
]]

--[[--------Maps--------
    lavaarena                   - -
    reforged_tiles_arena        - -
]]

--------------------------------------------------------------------------------------------------------------------------------

--------------------------
-- The Three Musketeers --
--------------------------

local hard_3p_req = {
    player_count    = 3,
    difficulties    = {"hard"},
    gametypes       = {"forge"},
    wavesets        = {"swineclops"},
}
local hard_3p_icon = {atlas = "images/hard_3p.xml", tex = "hard_3p.tex"}
_G.AddAchievement("hard_3p", IsNonSpectator, nil, VictoryOnMatchComplete, nil, hard_3p_req, SetLevelXP(15), 4, hard_3p_icon, player_count_id, "RCA")

---------------------
-- Disco for Three --
---------------------

local lights_3p_req = {
    player_count    = 3,
    gametypes       = {"rlgl"},
    wavesets        = {"swineclops"},
}
local lights_3p_icon = {atlas = "images/lights_3p.xml", tex = "lights_3p.tex"}
_G.AddAchievement("lights_3p", IsNonSpectator, nil, VictoryOnMatchComplete, nil, lights_3p_req, SetLevelXP(20), 5, lights_3p_icon, player_count_id, "RCA")

---------------
-- Got Lucky --
---------------

local randomized_req = {
    player_count    = 12,
    gametypes       = {"forge"},
    wavesets        = {"randomized"},
}
local randomized_icon = {atlas = "images/randomized.xml", tex = "randomized.tex"}
_G.AddAchievement("randomized", IsNonSpectator, nil, VictoryOnMatchComplete, nil, randomized_req, SetLevelXP(3), 2, randomized_icon, victory_id, "RCA")

-------------------
-- Hardly Random --
-------------------

local randomized_hard_req = {
    player_count    = 12,
    difficulties    = {"hard"},
    gametypes       = {"forge"},
    wavesets        = {"randomized"},
}
local randomized_hard_icon = {atlas = "images/randomized_hard.xml", tex = "randomized_hard.tex"}
_G.AddAchievement("randomized_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, randomized_hard_req, SetLevelXP(6), 3, randomized_hard_icon, victory_id, "RCA")

---------------------
-- Go for the Neck --
---------------------

local AOT_hard_req = {
    player_count    = 6,
    difficulties    = {"hard"},
    gametypes       = {"forge"},
    --presets         = {"attack_of_titans"},
    mutators        = {
        mob_damage_dealt = 2,
        mob_size = 1.5,
        mob_health = 1.5,
    },
}
local AOT_hard_icon = {atlas = "images/aot.xml", tex = "aot.tex"}
_G.AddAchievement("AOT_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, AOT_hard_req, SetLevelXP(20), 4, AOT_hard_icon, victory_id, "RCA")

---------------------
-- Just Hold F 2.0 --
---------------------

local function NoSpecialOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local total_alt_attacks = stat_tracker:GetStatTotal("altattacks")
    local total_spells = stat_tracker:GetStatTotal("spellscast")

    if lavaarenaevent.victory and total_alt_attacks <= 0 and total_spells <= 0 then
        local achievement_tracker = _G.TheWorld.components.achievement_tracker
        achievement_tracker:UpdateAchievementProgress(achievement_name, userid, true)
    end
end

local no_special_req = {
    player_count = 6,
    gametypes    = {"forge"},
    wavesets     = {"swineclops"},
}
local no_special_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("no_special", IsNonSpectator, nil, NoSpecialOnMatchComplete, nil, no_special_req, SetLevelXP(12.5), 4, no_special_icon, victory_id, "RCA")

--------------------------------------------------------------
-- Invincible Fearless Sensual Mysterious Enchanting Vigor… --
--------------------------------------------------------------

local wes_req = {
    characters   = {"wes"},
    gametypes    = {"forge"},
    wavesets     = {"swineclops"},
}
local wes_icon = {atlas = "images/wes.xml", tex = "wes.tex"}
_G.AddAchievement("wes", IsNonSpectator, nil, VictoryOnMatchComplete, nil, wes_req, SetLevelXP(0.00285), 1, wes_icon, victory_id, "RCA")

----------------
-- Clone Army --
----------------

local function AllSameCharOnMatchComplete(lavaarenaevent, userid, achievement_name)

    local characters = {}

    for userid,player_info in pairs(_G.TheWorld.components.stat_tracker.stats) do
        local character = player_info.user_data.user.prefab
		characters[character] = (characters[character] or 0) + 1
    end

    local unique_character_count = 0
    for character,count in pairs(characters) do
        unique_character_count = unique_character_count + 1
	end

    if lavaarenaevent.victory and unique_character_count <= 1 then
        local achievement_tracker = _G.TheWorld.components.achievement_tracker
        achievement_tracker:UpdateAchievementProgress(achievement_name, userid, true)
    end
end

local all_same_char_req = {
    player_count = 6,
    gametypes    = {"forge"},
    wavesets     = {"swineclops"},
}
local all_same_char_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("all_same_char", IsNonSpectator, nil, AllSameCharOnMatchComplete, nil, all_same_char_req, SetLevelXP(3), 3, all_same_char_icon, victory_id, "RCA")

-----------------------
-- I'll Do It Myself --
-----------------------

local solo_swine_req = {
    player_count = 1,
    gametypes    = {"forge"},
    wavesets     = {"swineclops"},
}
local solo_swine_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("solo_swine", IsNonSpectator, nil, AllSameCharOnMatchComplete, nil, solo_swine_req, SetLevelXP(50), 5, solo_swine_icon, victory_id, "RCA")

--------------------------
-- Lower Your Standards --
--------------------------

local function StandardsMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local standards = stat_tracker:GetStatTotal("standards", userid)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker
    achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, standards)
end
local standards_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("standards", IsNonSpectator, nil, StandardsMatchComplete, 150, nil, SetLevelXP(2), 2, standards_icon, player_id, "RCA")

---------------------
-- High Pet Deaths --
---------------------

local function HighPetDeathsOnMatchComplete(lavaarenaevent, userid, achievement_name)
    if lavaarenaevent.victory then
        local stat_tracker = _G.TheWorld.components.stat_tracker
        local petdeaths = stat_tracker:GetStatTotal("petdeaths", userid)
        if petdeaths >= 50 then
            local achievement_tracker = _G.TheWorld.components.achievement_tracker
            achievement_tracker:UpdateAchievementProgress(achievement_name, userid, true)
        end
    end
end
local high_pet_deaths_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("high_pet_deaths", IsNonSpectator, nil, HighPetDeathsOnMatchComplete, nil, nil, SetLevelXP(0.75), 2, high_pet_deaths_icon, player_id, "RCA")

---------------
-- Blowdarts --
---------------

local function BlowdartsMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local blowdarts = stat_tracker:GetStatTotal("blowdarts", userid)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker
    achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, blowdarts)
end

local blowdarts_progress_icon = {atlas = "images/dart_progress.xml", tex = "dart_progress.tex"}
_G.AddAchievement("blowdarts_progress", IsNonSpectator, nil, BlowdartsMatchComplete, 100000, nil, SetLevelXP(1.5), 2, blowdarts_progress_icon, player_id, "RCA")

------------------------
-- Jack of all Trades --
------------------------

local function UniqueCharacterOnMatchComplete_progress(lavaarenaevent, userid, achievement_name, max_player_count)

    local stat_tracker = _G.TheWorld.components.stat_tracker
    local player_count = stat_tracker:GetTotalActivePlayerCount()

    for setting,val in pairs(_G.REFORGED_SETTINGS.gameplay) do
        --TODO
    end

    -- must win
    if not lavaarenaevent.victory or (max_player_count and player_count > max_player_count) then return end

    --TheSim:SetPersistentString("reforged_achievements_server", json.encode(achievements), false, function() Debug:Print("Achievements Progress Saved", "log") end)
    --TheSim:SetPersistentString(filename, data, false, callback)

    --TheSim:GetPersistentString(filename, onreadtimefile)

    _G.TheSim:GetPersistentString(achievement_name, function(load_success, data)

        local characters = {}
        if load_success and data ~= nil then
            local status, prev_characters = _G.pcall( function() return _G.json.decode(data) end )
            if status and prev_characters then
                characters = prev_characters
            end
        end

        local curr_character = nil
        for id, player_info in pairs(_G.TheWorld.components.stat_tracker.stats) do
            if id == userid then
                curr_character = player_info.user_data.user.prefab
            end
        end

        if not characters[userid] then
            characters[userid] = {}
        end

        if curr_character == nil then
            print("[RCA] Achievement: "..tostring(achievement_name).." - Cannot find the player's character")
        end

        if curr_character and not table.contains(characters[userid], curr_character) then
            table.insert(characters[userid], curr_character)
            local achievement_tracker = _G.TheWorld.components.achievement_tracker
            achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, 1)
        else
            print("[RCA] Achievement: "..tostring(achievement_name).." - Character already counted or not found")
        end

        --_G.TheSim:SetPersistentString(achievement_name, _G.json.encode(characters), false, function() print("[RCA] Achievement: "..tostring(achievement_name).." - Progress updated successfully") end)

        if not _G.TheNet:IsDedicated() then
            _G.TheSim:SetPersistentString(tostring(achievement_name).."_client", _G.json.encode(characters), false, function() print("[RCA] Achievement: "..tostring(achievement_name).." - Progress updated successfully") end)
        end

        _G.TheSim:SetPersistentString(achievement_name, _G.json.encode(characters), false, function() print("[RCA] Achievement: "..tostring(achievement_name).." - Progress updated successfully") end)

    end, false)
end

local function UniqueCharacterOnMatchComplete_progress_6p(lavaarenaevent, userid, achievement_name)
    UniqueCharacterOnMatchComplete_progress(lavaarenaevent, userid, achievement_name)
end

local diff_characters_swine_progress_req = {
    player_count = 6,
    gametypes    = {"forge"},
    wavesets     = {"swineclops"},
}
local diff_characters_swine_progress_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
--_G.AddAchievement("diff_characters_swine_progress", IsNonSpectator, nil, UniqueCharacterOnMatchComplete_progress_6p, 12, diff_characters_swine_progress_req, SetLevelXP(6), 2, diff_characters_swine_progress_icon, player_id, "RCA")

-------------------
-- Master of All --
-------------------

local function UniqueCharacterOnMatchComplete_progress_2p(lavaarenaevent, userid, achievement_name)
    UniqueCharacterOnMatchComplete_progress(lavaarenaevent, userid, achievement_name, 2)
end

local diff_characters_swine_progress_2p_req = {
    player_count = 2,
    gametypes    = {"forge"},
    wavesets     = {"swineclops"},
}
local diff_characters_swine_progress_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
--_G.AddAchievement("diff_characters_swine_progress_2p", IsNonSpectator, nil, UniqueCharacterOnMatchComplete_progress_2p, 6, diff_characters_swine_progress_2p_req, SetLevelXP(30), 5, diff_characters_swine_progress_icon, player_id, "RCA")

----------------------
-- Immovable Object --
----------------------

local highest_max_hp = {}
local function PlayerMaxHealth(inst, data)
    local user_id = _G.TheNet:GetUserID()
    if user_id == nil then return end

    --print(inst:GetDisplayName()..": My stats changed! ("..tostring(data)..")")
    local max_hp = nil
    if inst and inst.components and inst.components.health then
        max_hp = inst.components.health:GetMaxWithPenalty()
    end
    if highest_max_hp[user_id] == nil and max_hp ~= nil then
        highest_max_hp[user_id] = max_hp
    end

    --print("Prev Highest HP: "..tostring(highest_max_hp[user_id]))
    --print("Curr Max HP: "..tostring(inst.components.health:GetMaxWithPenalty()))

	if max_hp ~= nil and max_hp > highest_max_hp[user_id] then
        --print("Higher Max HP Detected - "..tostring(max_hp))
        highest_max_hp[user_id] = max_hp
	end
end

--self.inst:PushEvent("healthdelta", { oldpercent = old_percent, newpercent = self:GetPercent(), overtime = overtime, cause = cause, afflicter = afflicter, amount = amount })
AddPlayerPostInit(function(inst)
    inst:ListenForEvent("healthdelta", PlayerMaxHealth, inst)
end)

local function MaxHPMatchComplete(lavaarenaevent, userid, achievement_name, target_max_hp)
    local max_hp = highest_max_hp[userid]
    local achievement_tracker = _G.TheWorld.components.achievement_tracker

    if max_hp and target_max_hp and max_hp >= target_max_hp then
        achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, true)
    end
end

local function MaxHPMatchComplete_500(lavaarenaevent, userid, achievement_name)
    MaxHPMatchComplete(lavaarenaevent, userid, achievement_name, 500)
end

local hp_500_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("hp_500", IsNonSpectator, nil, MaxHPMatchComplete_500, nil, nil, SetLevelXP(0.25), 2, hp_500_icon, player_id, "RCA")

------------------------------------
-- And The Audience Goes Mild!!!! --
------------------------------------

local function GetPlayersClientTable() -- from reforged
    local clients = _G.TheNet:GetClientTable() or {}
    if not _G.TheNet:GetServerIsClientHosted() then
        for i, v in ipairs(clients) do
            if v.performance ~= nil then
                table.remove(clients, i) -- remove "host" object
                break
            end
        end
    end
    return clients
end

local function NumSpiesOnMatchComplete(lavaarenaevent, userid, achievement_name, num_req_spies)
    local num_spies = 0
    local achievement_tracker = _G.TheWorld.components.achievement_tracker
    local all_players = GetPlayersClientTable()

    for i, player in pairs(all_players) do
        if player.prefab == "spectator" then
            num_spies = num_spies + 1
        end
    end

    if num_spies >= num_req_spies then
        achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, lavaarenaevent.victory)
    end
end

local function NumSpiesOnMatchComplete_3(lavaarenaevent, userid, achievement_name)
    NumSpiesOnMatchComplete(lavaarenaevent, userid, achievement_name, 3)
end

local spies_3_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("spies_3", IsNonSpectator, nil, NumSpiesOnMatchComplete_3, nil, nil, SetLevelXP(0.01), 1, spies_3_icon, player_id, "RCA")

-----------------------
-- Are We There Yet? --
-----------------------

local function TimeOnMatchComplete(lavaarenaevent, userid, achievement_name, time_in_seconds)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local match_time = lavaarenaevent.duration -- in seconds

    if match_time >= time_in_seconds then
        local achievement_tracker = _G.TheWorld.components.achievement_tracker
        achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, lavaarenaevent.victory)
    end
end

local function TimeOnMatchComplete_1hr(lavaarenaevent, userid, achievement_name, time_in_seconds)
    TimeOnMatchComplete(lavaarenaevent, userid, achievement_name, 3600)
end

local game_length_1_hr_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
_G.AddAchievement("game_length_1_hr", IsNonSpectator, nil, TimeOnMatchComplete_1hr, nil, nil, SetLevelXP(0.01), 1, game_length_1_hr_icon, player_id, "RCA")

-------------------------------------
-- All Amped Up With Nowhere To Go --
-------------------------------------

-- local function MobHealthDelta(inst, data) -- <-- from reforged
-- 	local stat_tracker = TheWorld.components.stat_tracker
-- 	if stat_tracker and data.oldpercent > 0 and data.afflicter ~= nil then
-- 		local is_pet = data.afflicter.components.follower ~= nil or data.afflicter.owner ~= nil
-- 		local player = GetPlayer(data.afflicter)
-- 		if player ~= nil then
-- 			-- Pet Damage
-- 			if is_pet then
-- 				stat_tracker:AdjustStat("pet_damagedealt", player, math.abs(data.amount))
-- 			-- Player Damage
-- 			else
-- 				stat_tracker:AdjustStat("player_damagedealt", player, math.abs(data.amount))
-- 			end
-- 			stat_tracker:AdjustStat("total_damagedealt", player, math.abs(data.amount))
-- 		end
-- 	end
-- end

local function NoPetDamageOnMatchComplete(lavaarenaevent, userid, achievement_name)

end

local amped_golem_no_dmg_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
--_G.AddAchievement("amped_golem_no_dmg", IsNonSpectator, nil, NoPetDamageOnMatchComplete, nil, nil, SetLevelXP(0.01), 1, game_length_1_hr_icon, player_id, "RCA")

--------------------------------------------------------------------------
-- Pugnax
--------------------------------------------------------------------------

--[[--------Wavesets--------
    advanced            - -
    steadfast           - -
    unusual             - -
    randomset           - -
    swapped             - -
    reverse             - -
    reinforced          - -
    buttermuesli        - -     "Epicurean"
    pong                - -
    boarillas27         - -
    relentless          - -
    singleplayer        - -
    doubletrouble       - -
    triplethreat        - -
    x4
]]

--[[--------Difficulties--------
    mild                - -
    extrahard           - -
]]

--[[--------Gametypes--------
    noeyeddeer          - -
    doublerlgl          - -
    rlglrave            - -
    rlgl_ff             - -
    lightsswitch        - -
    switch_orange       - -
    switch_blue         - -
    switch_green        - -
    switch_red          - -
]]

--[[--------Maps--------
    fission             - -
    sharedhealth        - -
    hallowified         - -
    reincarnation       - -
    swapped             - -
]]

if rca_common.table_contains(server_mods, "workshop-2038128735") then

    --------------------
    -- Share the Pain --
    --------------------

    local lights_shared_health_req = {
        gametypes       = {"rlgl"},
        wavesets        = {"swineclops"},
        mutators = {
            sharedhealth = true,
        },
    }
    local lights_shared_health_icon = {atlas = "images/shared_hp_lights.xml", tex = "shared_hp_lights.tex"}
    _G.AddAchievement("lights_shared_health", IsNonSpectator, nil, VictoryOnMatchComplete, nil, lights_shared_health_req, SetLevelXP(40), 5, lights_shared_health_icon, rlgl_id, "RCA")

    -----------------
    -- Medium Rare --
    -----------------

    local epicurean_req = {
        player_count    = 6,
        gametypes       = {"forge"},
        wavesets        = {"buttermuesli"},
    }
    local epicurean_icon = {atlas = "images/epicurean.xml", tex = "epicurean.tex"}
    _G.AddAchievement("epicurean", IsNonSpectator, nil, VictoryOnMatchComplete, nil, epicurean_req, SetLevelXP(6), 3, epicurean_icon, victory_id, "RCA")

    ----------------
    -- Well Done! --
    ----------------

    local epicurean_hard_req = {
        player_count    = 12,
        difficulties    = {"hard"},
        gametypes       = {"forge"},
        wavesets        = {"buttermuesli"},
    }
    local epicurean_hard_icon = {atlas = "images/epicurean_hard.xml", tex = "epicurean_hard.tex"}
    _G.AddAchievement("epicurean_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, epicurean_hard_req, SetLevelXP(8), 4, epicurean_hard_icon, victory_id, "RCA")

    -------------------
    -- Now Backwards --
    -------------------

    local reverse_req = {
        player_count    = 6,
        gametypes       = {"forge"},
        wavesets        = {"reverse"},
    }
    local reverse_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("reverse", IsNonSpectator, nil, VictoryOnMatchComplete, nil, reverse_req, SetLevelXP(3), 2, reverse_icon, victory_id, "RCA")

    ------------------
    -- Take It Back --
    ------------------

    local reverse_hard_req = {
        player_count    = 12,
        difficulties    = {"hard"},
        gametypes       = {"forge"},
        wavesets        = {"reverse"},
    }
    local reverse_hard_icon = {atlas = "images/hard_reverse.xml", tex = "hard_reverse.tex"}
    _G.AddAchievement("reverse_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, reverse_hard_req, SetLevelXP(12), 4, reverse_hard_icon, victory_id, "RCA")

    --------------------
    -- Advanced Class --
    --------------------

    local advanced_hard_req = {
        player_count    = 12,
        difficulties    = {"hard"},
        gametypes       = {"forge"},
        wavesets        = {"advanced"},
    }
    local advanced_hard_icon = {atlas = "images/advanced_hard.xml", tex = "advanced_hard.tex"}
    _G.AddAchievement("advanced_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, advanced_hard_req, SetLevelXP(5), 3, advanced_hard_icon, victory_id, "RCA")

    ----------------
    -- Wrong Game --
    ----------------

    local pong_req = {
        player_count    = 6,
        gametypes       = {"forge"},
        wavesets        = {"pong"},
    }
    local pong_icon = {atlas = "images/pong.xml", tex = "pong.tex"}
    _G.AddAchievement("pong", IsNonSpectator, nil, VictoryOnMatchComplete, nil, pong_req, SetLevelXP(5), 3, pong_icon, victory_id, "RCA")

    --------------
    -- Pong Pro --
    --------------

    local pong_hard_req = {
        player_count    = 12,
        difficulties    = {"hard"},
        gametypes       = {"forge"},
        wavesets        = {"pong"},
    }
    local pong_hard_icon = {atlas = "images/pong_hard.xml", tex = "pong_hard.tex"}
    _G.AddAchievement("pong_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, pong_hard_req, SetLevelXP(6), 3, pong_hard_icon, victory_id, "RCA")

    ---------------
    -- Ping Pong --
    ---------------

    local pong_3xdmg_req = {
        player_count    = 12,
        gametypes       = {"forge"},
        wavesets        = {"pong"},
        mutators = {
            mob_damage_dealt = 3,
        },
    }
    local pong_3xdmg_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("pong_3xdmg", IsNonSpectator, nil, VictoryOnMatchComplete, nil, pong_3xdmg_req, SetLevelXP(8), 3, pong_3xdmg_icon, victory_id, "RCA")

    ----------------------
    -- Turn Up The Heat --
    ----------------------

    local extra_hard_req = {
        player_count    = 12,
        difficulties    = {"extrahard"},
        gametypes       = {"forge"},
        wavesets        = {"swineclops"},
    }
    local extra_hard_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("extra_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, extra_hard_req, SetLevelXP(6), 3, extra_hard_icon, victory_id, "RCA")

    ---------------------
    -- Extra Trouble 2 --
    ---------------------

    local dt_extra_hard_12_req = {
        player_count    = 12,
        difficulties    = {"extrahard"},
        gametypes       = {"forge"},
        wavesets        = {"doubletrouble"},
    }
    local dt_extra_hard_12_icon = {atlas = "images/ehard_dt_12p.xml", tex = "ehard_dt_12p.tex"}
    _G.AddAchievement("dt_extra_hard_12", IsNonSpectator, nil, VictoryOnDupeMatchComplete, nil, dt_extra_hard_12_req, SetLevelXP(15), 4, dt_extra_hard_12_icon, victory_id, "RCA")

    -------------------
    -- Extra Trouble --
    -------------------

    local dt_extra_hard_req = {
        player_count    = 6,
        difficulties    = {"extrahard"},
        gametypes       = {"forge"},
        wavesets        = {"doubletrouble"},
    }
    local dt_extra_hard_icon = {atlas = "images/ehard_dt_6p.xml", tex = "ehard_dt_6p.tex"}
    _G.AddAchievement("dt_extra_hard", IsNonSpectator, nil, VictoryOnDupeMatchComplete, nil, dt_extra_hard_req, SetLevelXP(30), 5, dt_extra_hard_icon, victory_id, "RCA")

    ------------------------
    -- Not Enough Monkeys --
    ------------------------

    local boarilla_27_req = {
        player_count    = 12,
        gametypes       = {"forge"},
        wavesets        = {"boarillas27"},
    }
    local boarilla_27_icon = {atlas = "images/27_boarillas.xml", tex = "27_boarillas.tex"}
    _G.AddAchievement("boarilla_27", IsNonSpectator, nil, VictoryOnMatchComplete, nil, boarilla_27_req, SetLevelXP(1.35), 2, boarilla_27_icon, victory_id, "RCA")

    ----------------------
    -- Too Many Monkeys --
    ----------------------

    -- can't use VictoryOnDupeMatchComplete bc it has a required waveset
    local boarilla_27_10x_req = {
        gametypes       = {"forge"},
        wavesets        = {"boarillas27"},
        mutators = {
            mob_duplicator = 10,
            mob_size = 0.5,
        },
    }
    local boarilla_27_10x_icon = {atlas = "images/27_boarillas_10x.xml", tex = "27_boarillas_10x.tex"}
    _G.AddAchievement("boarilla_27_10x", IsNonSpectator, nil, VictoryOnMatchComplete, nil, boarilla_27_10x_req, SetLevelXP(13.5), 4, boarilla_27_10x_icon, victory_id, "RCA")

    ------------------------------
    -- Light Up The Dance Floor --
    ------------------------------

    local lights_rave_req = {
        gametypes       = {"rlglrave"},
        wavesets        = {"swineclops"},
    }
    local lights_rave_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("lights_rave", IsNonSpectator, nil, VictoryOnMatchComplete, nil, lights_rave_req, SetLevelXP(8), 4, lights_rave_icon, rlgl_id, "RCA")

    -----------------
    -- Not A Fluke --
    -----------------

    local function RandomSetMatchComplete(lavaarenaevent, userid, achievement_name)
        if lavaarenaevent.victory then
            local achievement_tracker = _G.TheWorld.components.achievement_tracker
            achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, 1)
        end
    end

    local randomset_6_times_req = {
        player_count    = 6,
        gametypes       = {"forge"},
        wavesets        = {"randomset"},
    }
    local randomset_6_times_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("randomset_6_times", IsNonSpectator, nil, RandomSetMatchComplete, 6, randomset_6_times_req, SetLevelXP(3), 2, randomset_6_times_icon, player_id, "RCA")

end

--------------------------------------------------------------------------
-- Hallowed Forge
--------------------------------------------------------------------------

--[[--------Maps--------
    hf_eye_arena    - -     
]]

--[[--------Wavesets--------
    tomb_raid       - -     
]]

if rca_common.table_contains(server_mods, "workshop-2633870801") then

    ------------------
    -- Necro Dancer --
    ------------------

    local tomb_raid_lights_req = {
        player_count    = 6,
        gametypes       = {"rlgl"},
        maps            = {"hf_eye_arena"},
        wavesets        = {"tomb_raid"},
    }
    local tomb_raid_lights_icon = {atlas = "images/croc_rave.xml", tex = "croc_rave.tex"}
    _G.AddAchievement("tomb_raid_lights", IsNonSpectator, nil, VictoryOnMatchComplete, nil, tomb_raid_lights_req, SetLevelXP(12.5), 4, tomb_raid_lights_icon, rlgl_id, "RCA")

end

--------------------------------------------------------------------------
-- Hallowed Forge + Pugnax
--------------------------------------------------------------------------

--[[--------Wavesets--------
    hallowedswineclops      - -     
    halloweddoubletrouble   - -     
    hallowedreverse         - -     
    hallowedcursedking      - -     
    hallowedcultists        - -     
    hallowedsingleplayer    - -     
]]

if rca_common.table_contains(server_mods, "workshop-2633870801") and rca_common.table_contains(server_mods, "workshop-2038128735") then

    -------------------
    -- Grave Diggers --
    -------------------

    -- can't use VictoryOnDupeMatchComplete bc it has a required waveset
    local hf_dt_req = {
        player_count    = 6,
        --maps            = {"hf_eye_arena"},
        wavesets        = {"halloweddoubletrouble"},
    }
    local hf_dt_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("hf_dt", IsNonSpectator, nil, VictoryOnMatchComplete, nil, hf_dt_req, SetLevelXP(6), 3, hf_dt_icon, victory_id, "RCA")

    --------------------
    -- Crypt Smashers --
    --------------------

    -- can't use VictoryOnDupeMatchComplete bc it has a required waveset
    local hf_dt_hard_req = {
        player_count    = 6,
        difficulties    = {"hard"},
        --maps            = {"hf_eye_arena"},
        wavesets        = {"halloweddoubletrouble"},
    }
    local hf_dt_hard_icon = {atlas = "images/hf_dt_hard.xml", tex = "hf_dt_hard.tex"}
    _G.AddAchievement("hf_dt_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, hf_dt_hard_req, SetLevelXP(12), 4, hf_dt_hard_icon, victory_id, "RCA")

    ------------------
    -- Practice Run --
    ------------------

    local cursed_king_hard_req = {
        player_count    = 6,
        difficulties    = {"hard"},
        gametypes       = {"forge"},
        wavesets        = {"hallowedcursedking"},
    }
    local cursed_king_hard_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("cursed_king_hard", IsNonSpectator, nil, VictoryOnMatchComplete, nil, cursed_king_hard_req, SetLevelXP(4), 3, cursed_king_hard_icon, victory_id, "RCA")

    ---------------
    -- Pesticide --
    ---------------

    local function StarveRoachBeetlesCursedKing(achievement_tracker, player, achievement_name, server_progress, client_progress)
        achievement_tracker:UpdateAchievementProgress(achievement_name, player.userid, true)
        local is_starved = true
        local function TrackRoachBeetles(world, data)
            local mob = data.mob
            if mob.prefab == "roach_beetle" then
                local function OnPickup()
                    if is_starved then
                        achievement_tracker:UpdateAchievementProgress(achievement_name, player.userid, nil, nil, nil, true)
                        is_starved = false
                        mob:RemoveEventCallback("onpickup", OnPickup)
                        _G.TheWorld:RemoveEventCallback("on_spawned_mob", TrackRoachBeetles)
                    end
                end
                mob:ListenForEvent("onpickup", OnPickup)
            end
        end
        _G.TheWorld:ListenForEvent("on_spawned_mob", TrackRoachBeetles)
    end

    local starve_roach_beetles_cursed_king_req = {
        player_count = 6,
        gametypes    = {"forge"},
        difficulties = {"hard"},
        wavesets     = {"hallowedcursedking"},
    }
    local starve_roach_beetles_cursed_king_icon = {atlas = "images/hallowedforge_achievements.xml", tex = "ach_roach_beetle_dead.tex"}
    _G.AddAchievement("starve_roach_beetles_cursed_king", IsNonSpectator, StarveRoachBeetlesCursedKing, VictoryOnMatchComplete, nil, starve_roach_beetles_cursed_king_req, SetLevelXP(6), 3, starve_roach_beetles_cursed_king_icon, victory_id, "RCA")

end

--------------------------------------------------------------------------
-- Infernal Forge
--------------------------------------------------------------------------

--[[--------Wavesets--------
    Reflection      - -     
]]

--[[--------Gametypes--------
    golemdefense    - -     
    mathtest        - -     
    blossoms        - -     
    discolights     - -     
    discolightsrave - -     
]]

if rca_common.table_contains(server_mods, "workshop-2961923603") then

    ----------------------
    -- Back to the '80s --
    ----------------------

    local disco_lights_6p_req = {
        player_count    = 6,
        gametypes       = {"discolights"},
        wavesets        = {"swineclops"},
    }
    local disco_lights_6p_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("disco_lights_6p", IsNonSpectator, nil, VictoryOnMatchComplete, nil, disco_lights_6p_req, SetLevelXP(4), 2, disco_lights_6p_icon, rlgl_id, "RCA")

    -----------------------------
    -- Dance 'Till You're Dead --
    -----------------------------

    local disco_lights_rave_req = {
        gametypes       = {"discolightsrave"},
        wavesets        = {"swineclops"},
    }
    local disco_lights_rave_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("disco_lights_rave", IsNonSpectator, nil, VictoryOnMatchComplete, nil, disco_lights_rave_req, SetLevelXP(16), 4, disco_lights_rave_icon, rlgl_id, "RCA")

    ---------------
    -- Math Test --
    ---------------

    local mathtest_req = {
        player_count    = 6,
        gametypes       = {"mathtest"},
        wavesets        = {"swineclops"},
    }
    local mathtest_icon = {atlas = "images/mathtest.xml", tex = "mathtest.tex"}
    _G.AddAchievement("mathtest", IsNonSpectator, nil, VictoryOnMatchComplete, nil, mathtest_req, SetLevelXP(3), 2, mathtest_icon, victory_id, "RCA")

end

--------------------------------------------------------------------------
-- Infernal Forge + Pugnax
--------------------------------------------------------------------------
if rca_common.table_contains(server_mods, "workshop-2961923603") and rca_common.table_contains(server_mods, "workshop-2038128735") then

    ---------------------
    -- Magmatic Petals --
    ---------------------

    local extra_hard_blooming_days_req = {
        player_count    = 12,
        difficulties    = {"extrahard"},
        gametypes       = {"blossoms"},
        wavesets        = {"swineclops"},
    }
    local extra_hard_blooming_days_icon = {atlas = "images/magmatic_petals.xml", tex = "magmatic_petals.tex"}
    _G.AddAchievement("extra_hard_blooming_days", IsNonSpectator, nil, VictoryOnMatchComplete, nil, extra_hard_blooming_days_req, SetLevelXP(7.5), 3, extra_hard_blooming_days_icon, victory_id, "RCA")

end

--------------------------------------------------------------------------
-- Unbearable Forge
--------------------------------------------------------------------------

--[[--------Presets--------

]]

--[[--------Wavesets--------
    ub_tactical     - -     "Tactical"
    timber          - -     "Timber"
    ub_quickswine   - -     "5-1 Swineclops"
    dungeon         - -     "Dungeon"
    ub_bossraid     - -     "UB Boss Raid"
]]

--[[--------Difficulties--------
    challenger      - -     "Challenger"
    grizzly         - -     "Grizzly"
    mayhem          - -     "Mayhem"
]]

--[[--------Gametypes--------

]]

--[[--------Modes--------

]]

--[[--------Mutators--------
    no_control      - -     "No Control"
    fast_combat     - -     "Fast Combat"
    no_heal         - -     "No Heal"
    disease         - -     "Disease"
    one_hit         - -     "One Hit"
    shared_passive  - -     "Shared Passive"
    no_restriction  - -     "No Restriction"
    lava_storm      - -     "Fire Storm"
    lightning_storm - -     "Lightning Storm"
    ice_storm       - -     "Blizzard"
    no_recharge     - -     "No Recharge"
    transmute       - -     "Transmutation"
]]

--[[--------Maps--------

]]

if rca_common.table_contains(server_mods, "workshop-3355978394") then

    ------------------------
    -- Someone Heard That --
    ------------------------

    local hard_timber_req = {
        player_count    = 6,
        difficulties    = {"hard"},
        wavesets        = {"timber"},
    }
    local hard_timber_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("hard_timber", IsNonSpectator, nil, VictoryOnMatchComplete, nil, hard_timber_req, SetLevelXP(6), 3, hard_timber_icon, victory_id, "RCA")

end

--------------------------------------------------------------------------
-- Unbearable Forge + Pugnax
--------------------------------------------------------------------------

if rca_common.table_contains(server_mods, "workshop-3355978394") and rca_common.table_contains(server_mods, "workshop-2038128735")then

    ------------------
    -- World Champs --
    ------------------

    local pong_shared_health_req = {
        wavesets        = {"pong"},
        gametypes       = {"forge"},
        mutators = {
            sharedhealth = true,
        },
    }
    local pong_shared_health_icon = {atlas = "images/RCA_placeholder.xml", tex = "RCA_placeholder.tex"}
    _G.AddAchievement("pong_shared_health", IsNonSpectator, nil, VictoryOnMatchComplete, nil, pong_shared_health_req, SetLevelXP(2), 2, pong_shared_health_icon, victory_id, "RCA")

end

--------------------------------------------------------------------------
-- Testing
--------------------------------------------------------------------------

-- local test_achieve_dt_again_req = {
--     --difficulties    = {"mild"},
--     gametypes       = {"forge"},
--     wavesets        = {"doubletrouble", "swineclops"}, --"singleplayer" , "swineclops"
--     mutators        = {
--         -- mob_damage_dealt = 0.5,
--         -- mob_damage_received = 0.5,
--         -- mob_health = 0.5,
--         -- mob_speed = 0.5,
--         -- battlestandard_efficiency = 0.5,
--         -- mob_duplicator = 2
--     },
-- }
-- local test_achieve_dt_again_icon = {atlas = "images/hard_3p.xml", tex = "hard_3p.tex"}
-- _G.AddAchievement("test_achieve_dt_again", IsNonSpectator, nil, VictoryOnDupeMatchComplete, nil, test_achieve_dt_again_req, SetLevelXP(0), 5, test_achieve_dt_again_icon, player_count_id, "RCA")

local function VictoryOnDupeMatchComplete_testing(lavaarenaevent, userid, achievement_name)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker

    local match_settings = _G.REFORGED_SETTINGS.gameplay
    local match_waveset = match_settings.waveset
    local match_duplicator = match_settings.mutators.mob_duplicator or 0

    local achievement_data = _G.REFORGED_DATA.achievements[achievement_name]
    if not achievement_data then return false end
    local achievement_waveset = achievement_data.requirements.wavesets
    local achievement_duplicator = achievement_data.requirements.mutators.mob_duplicator or 0

    local waveset_to_dupe = {
        ["doubletrouble"] = 2,
        ["triplethreat"] = 3,
        ["quintuplestruggle"] = 5,
        ["tenfoldterror"] = 10,
    }

    for key, value in pairs(achievement_waveset) do
        if waveset_to_dupe[value] and achievement_duplicator == 0 then
            achievement_duplicator = waveset_to_dupe[value]
            break
        end
    end

    if
        waveset_to_dupe[match_waveset] and table.contains(achievement_waveset, match_waveset)
        or table.contains(achievement_waveset, match_waveset) and (match_duplicator >= achievement_duplicator)
    then
        return true
    end
    return false
end

local function NoSpecialOnMatchComplete_testing(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local total_alt_attacks = stat_tracker:GetStatTotal("altattacks")
    local total_spells = stat_tracker:GetStatTotal("spellscast")

    if total_alt_attacks <= 0 and total_spells <= 0 then
        return true
    end
    return false
end

local function AllSameCharOnMatchComplete_testing(lavaarenaevent, userid, achievement_name)

    local characters = {}

    for userid,player_info in pairs(_G.TheWorld.components.stat_tracker.stats) do
        local character = player_info.user_data.user.prefab
		characters[character] = (characters[character] or 0) + 1
    end

    local unique_character_count = 0
    for character,count in pairs(characters) do
        unique_character_count = unique_character_count + 1
	end

    if unique_character_count <= 1 then
        return true
    end
    return false
end

local function HighPetDeathsOnMatchComplete_testing(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local petdeaths = stat_tracker:GetStatTotal("petdeaths", userid)
    if petdeaths >= 50 then
        return true
    end
    return false
end

local function EndlessOnMatchComplete(lavaarenaevent, userid, achievement_name)
    if lavaarenaevent.total_rounds_completed >= 21 then
        return true
    end
    return false
end

local function NoFriendlyFireOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local friendly_fire_damage = stat_tracker:GetStatTotal("total_friendly_fire_damage_dealt")
    if friendly_fire_damage <= 0 then
        return true
    end
    return false
end

local function NoDeathsOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local deaths = stat_tracker:GetStatTotal("deaths", userid)
    if deaths <= 0 then
        return true
    end
    return false
end

local function NoDamageOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local damage_taken = stat_tracker:GetStatTotal("player_damagetaken", userid)
    if damage_taken <= 0 then
        return true
    end
    return false
end

local function LowTeamDamageOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local team_low_damage = true
    for id,_ in pairs(stat_tracker.stats) do
        local damage_taken = stat_tracker:GetStatTotal("player_damagetaken", id)
        if damage_taken > 200 then
            team_low_damage = false
            break
        end
    end
    if team_low_damage then
        return true
    end
    return false
end

local function NoTeamDeathsOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local total_deaths = stat_tracker:GetStatTotal("deaths")
    if total_deaths <= 0 then
        return true
    end
end

local function NoDeathsSwineclopsOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local total_deaths = stat_tracker:GetStatTotal("deaths", userid)
    if total_deaths <= 0 then
        return true
    end
    return false
end

local function IsAllRandomTeam(player)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    for userid,_ in pairs(stat_tracker.stats) do
        if not stat_tracker.random_characters[userid] then
            return false
        end
    end
    return true
end

local function NoTeamDeathsAllRandomOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local total_deaths = stat_tracker:GetStatTotal("deaths")
    if total_deaths <= 0 and IsAllRandomTeam() then
        return true
    end
    return false
end

local function SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, time)
    if lavaarenaevent.duration and time and lavaarenaevent.duration <= time then
        return true
    end
    return false
end

local function BronzeSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 1500) -- 25 minutes
end

local function SilverSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 1200) -- 20 minutes
end

local function GoldSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 900) -- 15 minutes
end

local function PlatSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 600) -- 10 minutes
end

local function DoubleBronzeSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 2100) -- 35 minutes
end

local function DoubleSilverSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 1800) -- 30 minutes
end

local function DoubleGoldSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 1500) -- 25 minutes
end

local function DoublePlatSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name)
    SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name, 1200) -- 20 minutes
end

local function CCBreakerMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local cc_broken = stat_tracker:GetStatTotal("ccbroken", userid)
    if cc_broken >= 100 then
        return true
    end
    return false
end

local function KillsMatchComplete(lavaarenaevent, userid, achievement_name, total_revives) --progression
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local kills = stat_tracker:GetStatTotal("kills", userid)
	local achievement_tracker = _G.TheWorld.components.achievement_tracker
	return true
end

local function ReviveMatchComplete(lavaarenaevent, userid, achievement_name, total_revives)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local revives = stat_tracker:GetStatTotal("corpsesrevived", userid)
    if revives and total_revives and revives >= total_revives then
        return true
    end
    return false
end

local function ReviveBronzeMatchComplete(lavaarenaevent, userid, achievement_name)
    ReviveMatchComplete(lavaarenaevent, userid, achievement_name, 1)
end

local function ReviveSilverMatchComplete(lavaarenaevent, userid, achievement_name)
    ReviveMatchComplete(lavaarenaevent, userid, achievement_name, 10)
end

local function ReviveGoldMatchComplete(lavaarenaevent, userid, achievement_name)
    ReviveMatchComplete(lavaarenaevent, userid, achievement_name, 20)
end

local function TeleportTrack(achievement_tracker, player, achievement_name, server_progress, client_progress)
    local function UpdateTeleportCount(inst, data)
        if data.weapon and data.weapon.prefab == "" then
            achievement_tracker:UpdateAchievementProgress(achievement_name, player.userid, nil, 1)
            if achievement_tracker:IsAchievementUnlocked(achievement_name, player.userid, true) and achievement_tracker:IsAchievementUnlocked(achievement_name, player.userid) then
                player:RemoveEventCallback("spell_complete", UpdateTeleportCount)
            end
        end
    end
    player:ListenForEvent("spell_complete", UpdateTeleportCount)
end

local function TeleportOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker
    return true
end

local function WilsonHealerMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local healing_dealt = stat_tracker:GetStatTotal("healingdone", userid)
    if healing_dealt and healing_dealt >= 20000 then
        return true
    end
    return false
end

-- Checks all achievements and if their requirements are satisfied by the current game's settings
GLOBAL.TheInput:AddKeyDownHandler(45, function() --minus key

    if not debug_prints then return end

    if not (_G and _G.TheWorld and _G.TheWorld.components and _G.TheWorld.components.lavaarenaevent and _G.TheWorld.components.achievement_tracker and _G.TheNet and _G.REFORGED_DATA and _G.REFORGED_DATA.achievements and _G.ThePlayer) then print("[RCA] Can't print debug results - A needed component is nil") return end

    local achievements = _G.REFORGED_DATA.achievements

    for name, data in pairs(achievements) do
        print("[RCA] Requirements Met - "..name.." - "..tostring(_G.TheWorld.components.achievement_tracker:CheckRequirementsForAchievement(name, _G.ThePlayer)))

        local lavaarenaevent = _G.TheWorld.components.lavaarenaevent
        local userid = _G.TheNet:GetUserID()
        local achievement_name = name
        local func_to_testing = {
            [VictoryOnMatchComplete] = true, --assuming we win the game for testing

            [VictoryOnDupeMatchComplete] = VictoryOnDupeMatchComplete_testing(lavaarenaevent, userid, achievement_name),
            [NoSpecialOnMatchComplete] = NoSpecialOnMatchComplete_testing(lavaarenaevent, userid, achievement_name),
            [AllSameCharOnMatchComplete] = AllSameCharOnMatchComplete_testing(lavaarenaevent, userid, achievement_name),
            [StandardsMatchComplete] = true, -- progression
            [HighPetDeathsOnMatchComplete] = HighPetDeathsOnMatchComplete_testing(lavaarenaevent, userid, achievement_name),
            [RandomSetMatchComplete] = true, -- progression

            [NoDeathsOnMatchComplete] = NoDeathsOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [EndlessOnMatchComplete] = EndlessOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [NoFriendlyFireOnMatchComplete] = NoFriendlyFireOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [NoDamageOnMatchComplete] = NoDamageOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [LowTeamDamageOnMatchComplete] = LowTeamDamageOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [NoTeamDeathsOnMatchComplete] = NoTeamDeathsOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [NoDeathsSwineclopsOnMatchComplete] = NoDeathsSwineclopsOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [NoTeamDeathsAllRandomOnMatchComplete] = NoTeamDeathsAllRandomOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [SpeedRunOnMatchComplete] = SpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [BronzeSpeedRunOnMatchComplete] = BronzeSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [SilverSpeedRunOnMatchComplete] = SilverSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [GoldSpeedRunOnMatchComplete] = GoldSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [PlatSpeedRunOnMatchComplete] = PlatSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [DoubleBronzeSpeedRunOnMatchComplete] = DoubleBronzeSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [DoubleSilverSpeedRunOnMatchComplete] = DoubleSilverSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [DoubleGoldSpeedRunOnMatchComplete] = DoubleGoldSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [DoublePlatSpeedRunOnMatchComplete] = DoublePlatSpeedRunOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [CCBreakerMatchComplete] = CCBreakerMatchComplete(lavaarenaevent, userid, achievement_name),
            [KillsMatchComplete] = true, -- progression
            [ReviveMatchComplete] = ReviveMatchComplete(lavaarenaevent, userid, achievement_name),
            [ReviveBronzeMatchComplete] = ReviveBronzeMatchComplete(lavaarenaevent, userid, achievement_name),
            [ReviveSilverMatchComplete] = ReviveSilverMatchComplete(lavaarenaevent, userid, achievement_name),
            [ReviveGoldMatchComplete] = ReviveGoldMatchComplete(lavaarenaevent, userid, achievement_name),
            --[TeleportTrack] = TeleportTrack(lavaarenaevent, userid, achievement_name), -- unused in actual achievements
            --[TeleportOnMatchComplete] = TeleportOnMatchComplete(lavaarenaevent, userid, achievement_name),
            [WilsonHealerMatchComplete] = WilsonHealerMatchComplete(lavaarenaevent, userid, achievement_name),
            
        }

        if func_to_testing[data.on_match_complete_fn] then -- ~= nil
            print("[RCA] Victory Condition Met - "..tostring(func_to_testing[data.on_match_complete_fn]))
        end
    end

end)

GLOBAL.TheInput:AddKeyDownHandler(302, function() --SCROLLOCK

    if not debug_prints then return end

    local lavaarenaevent = _G.TheWorld.components.lavaarenaevent
    --lavaarenaevent.victory = true
    lavaarenaevent:End(true)

    --SendCommand("TheWorld.components.lavaarenaevent:End(true)")
end)

-- local prev_teams = {};
-- for k,v in pairs(AllPlayers) do
--     if v.prefab ~= "spectator" then
--         local team = math.random(1,2);
--         v.components.health:SetMaxHealth(150);
--         if IsNumberEven(count) then
--             v.AnimState:SetAddColour(1, 0, 0, 1);
--         else
--             v.AnimState:SetAddColour(0, 1, 1, 1);
--         end
--     end
-- end

-- count = 0;
-- for k,v in pairs(AllPlayers) do
--     if IsNumberEven(count) then
--         v.AnimState:SetAddColour(1, 0, 0, 1);
--     else
--         v.AnimState:SetAddColour(0, 1, 1, 1);
--     end
--     count = count + 1;
-- end