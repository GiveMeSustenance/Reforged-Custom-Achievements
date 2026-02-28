-- local _G = GLOBAL

-- function c_CheckAchievementSatisfied(achievement_name)
--     print("[RCA] ACHIEVEMENT CHECK - "..tostring(_G.TheWorld.components.achievement_tracker:CheckRequirementsForAchievement(achievement_name, _G.ThePlayer)))
    
--     local victory_condition = _G.REFORGED_DATA.achievements[achievement_name].on_match_complete_fn
--     local lavaarenaevent = _G.TheWorld.components.lavaarenaevent
--     local userid = TheNet:GetUserID()
--     print("[RCA] VICTORY CHECK - "..tostring(victory_condition).." - "..tostring(victory_condition(lavaarenaevent, userid, achievement_name)))
-- end

--player death check
--c_announce(_G.TheWorld.components.stat_tracker:GetStatTotal("deaths", TheNet:GetUserID()))

-- achievement check
--c_announce("[RCA] ACHIEVEMENT CHECK - "..tostring(_G.TheWorld.components.achievement_tracker:CheckRequirementsForAchievement("friendly_fire", _G.ThePlayer)))
--"friendly_fire"

--c_announce("[RCA] VICTORY DUPE CHECK - "..tostring(NoFriendlyFireOnMatchComplete(nil, nil, "test_achieve_dt_again")))
--VictoryOnMatchComplete
--VictoryOnDupeMatchComplete
--NoFriendlyFireOnMatchComplete
