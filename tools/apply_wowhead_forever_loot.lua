-- Apply a reviewed Wowhead Forever guide snapshot to ForeverDungeonJournal data.
-- Existing Journal sources win; a conflicting Wowhead attribution is reported.
return function(source)
    local file = assert(io.open("tools/wowhead_forever_loot.tsv", "r"))
    local added, conflicts, seen = 0, {}, 0
    for line in file:lines() do
        if line:sub(1, 1) ~= "#" and line ~= "" then
            local dungeonName, bossName, idText, url = line:match("^([^\t]+)\t([^\t]+)\t(%d+)\t(https://www%.wowhead%.com/forever/[^\t]+)$")
            assert(dungeonName and bossName and idText and url, "invalid Wowhead snapshot row: " .. line)
            local dungeon = assert(source.DB[dungeonName], "unknown Wowhead dungeon: " .. dungeonName)
            local target, other = nil, nil
            local id = tonumber(idText)
            for _, boss in ipairs(dungeon.bosses or {}) do
                if boss.name == bossName then target = boss end
                for _, item in ipairs(boss.loot or {}) do
                    if tonumber(item[1]) == id then other = boss.name end
                end
            end
            assert(target, "unknown Wowhead boss: " .. dungeonName .. " / " .. bossName)
            local has = false
            for _, item in ipairs(target.loot or {}) do
                if tonumber(item[1]) == id then has = true end
            end
            if not has then
                -- A shared Journal drop is already represented by its own map.
                for _, boss in ipairs(dungeon.bosses or {}) do
                    for _, item in ipairs(source.GetBossSharedLoot and source.GetBossSharedLoot(dungeonName, boss) or {}) do
                        if tonumber(item[1]) == id then other = other or "shared" end
                    end
                end
                if other then
                    conflicts[#conflicts + 1] = dungeonName .. " / " .. bossName .. " / " .. id .. " (Journal: " .. other .. ")"
                else
                    target.loot = target.loot or {}
                    target.loot[#target.loot + 1] = { id, "Wowhead Forever", "", 0 }
                    added = added + 1
                end
            end
            seen = seen + 1
        end
    end
    file:close()
    return added, conflicts, seen
end
