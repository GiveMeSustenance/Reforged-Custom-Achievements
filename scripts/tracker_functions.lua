--local _G = GLOBAL

--Currently unused

local function IsNonSpectator(player)
    return player.prefab ~= "spectator"
end
local function VictoryOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker
    achievement_tracker:UpdateAchievementProgress(achievement_name, userid, lavaarenaevent.victory)
end

local function VictoryOnMatchCompleteRequirement(lavaarenaevent, userid, achievement_name)
    local achievement_tracker = _G.TheWorld.components.achievement_tracker
    achievement_tracker:UpdateAchievementProgress(achievement_name, userid, nil, nil, nil, not lavaarenaevent.victory)
end

local function NoDeathsOnMatchComplete(lavaarenaevent, userid, achievement_name)
    if lavaarenaevent.victory then
        local stat_tracker = _G.TheWorld.components.stat_tracker
        local deaths = stat_tracker:GetStatTotal("deaths", userid)
        if deaths <= 0 then
            local achievement_tracker = _G.TheWorld.components.achievement_tracker
            achievement_tracker:UpdateAchievementProgress(achievement_name, userid, true)
        end
    end
end

local function AllSameCharOnMatchComplete(lavaarenaevent, userid, achievement_name)

    local unique_characters = true
    local characters = {}

    for userid,player_info in pairs(_G.TheWorld.components.stat_tracker.stats) do

        local character = player_info.user_data.user.prefab

		characters[character] = (characters[character] or 0) + 1
        unique_characters = unique_characters and characters[character] <= 1

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

local function NoSpecialOnMatchComplete(lavaarenaevent, userid, achievement_name)
    local stat_tracker = _G.TheWorld.components.stat_tracker
    local total_alt_attacks = stat_tracker:GetStatTotal("altattacks")
    local total_spells = stat_tracker:GetStatTotal("spellscast")

    if lavaarenaevent.victory and total_alt_attacks <= 0 and total_spells <= 0 then
        local achievement_tracker = _G.TheWorld.components.achievement_tracker
        achievement_tracker:UpdateAchievementProgress(achievement_name, userid, true)
    end
end

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

local function table_contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

return {
    IsNonSpectator = IsNonSpectator,
    VictoryOnMatchComplete = VictoryOnMatchComplete,
    VictoryOnMatchCompleteRequirement = VictoryOnMatchCompleteRequirement,
    NoDeathsOnMatchComplete = NoDeathsOnMatchComplete,
    AllSameCharOnMatchComplete = AllSameCharOnMatchComplete,
    NoSpecialOnMatchComplete = NoSpecialOnMatchComplete,
    StarveRoachBeetlesCursedKing = StarveRoachBeetlesCursedKing,
    table_contains = table_contains,
}