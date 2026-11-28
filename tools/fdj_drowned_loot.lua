-- Returns the reviewed Drowned City loot block from ForeverDungeonJournal's Data/QuestUpdates.lua.
-- Older releases wrapped it in "-- BEGIN drownedloot" / "-- END drownedloot" comments.
-- Release 2.1.8 ships without comments, so the fallback finds the top-level
-- "do local d = FDJ.DB and FDJ.DB["The Drowned City"] ... end" block instead.
return function(text)
    local marked = text:match("%-%- BEGIN drownedloot(.-)%-%- END drownedloot")
    if marked then return marked end
    local normalized = text:gsub("\r\n", "\n")
    local start = normalized:find('\ndo\n[ \t]*local d = FDJ%.DB and FDJ%.DB%["The Drowned City"%]')
    assert(start, "Drowned City loot block missing from QuestUpdates.lua")
    -- The block is a top-level do/end; its closing "end" is the first one in column 0.
    local finish = normalized:find("\nend[ \t]*\n", start + 1)
    assert(finish, "Drowned City loot block is not closed in QuestUpdates.lua")
    local block = normalized:sub(start + 1, finish + 4)
    assert(block:find("local LOOT = {", 1, true), "Drowned City loot table missing from QuestUpdates.lua")
    return block
end
