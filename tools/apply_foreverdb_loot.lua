-- Apply reviewed ForeverDB.net observations to ForeverDungeonJournal data.
-- Existing Journal sources win; a conflicting ForeverDB attribution is reported.
-- Credit: Data from ForeverDB.net — https://foreverdb.net
return function(source)
    local file = assert(io.open("tools/foreverdb_loot_reviewed.tsv", "r"))
    local added, present, conflicts, seen = 0, 0, {}, 0
    for line in file:lines() do
        if line:sub(1, 1) ~= "#" and line ~= "" then
            local dungeonName, sourceName, idText, itemName, url =
                line:match("^([^\t]+)\t([^\t]+)\t(%d+)\t([^\t]+)\t%d*\t%d*\t(https://foreverdb%.net/[^\t]+)$")
            assert(dungeonName and sourceName and idText and itemName and url,
                "invalid ForeverDB review row: " .. line)
            local dungeon = assert(source.DB[dungeonName], "unknown ForeverDB dungeon: " .. dungeonName)
            local id = tonumber(idText)
            local target, other, presentAtTarget = nil, nil, false
            for _, boss in ipairs(dungeon.bosses or {}) do
                if boss.name == sourceName then target = boss end
                local shared = source.GetBossSharedLoot and source.GetBossSharedLoot(dungeonName, boss)
                for _, items in ipairs({ boss.loot or {}, shared or {} }) do
                    for _, item in ipairs(items) do
                        if tonumber(item[1]) == id then
                            if target == boss then
                                presentAtTarget = true
                            else
                                other = boss.trash and "trash" or boss.name
                            end
                            break
                        end
                    end
                end
            end
            assert(target, "unknown ForeverDB source: " .. dungeonName .. " / " .. sourceName)
            if presentAtTarget then
                present = present + 1
            elseif other then
                conflicts[#conflicts + 1] = dungeonName .. " / " .. sourceName .. " / " .. id ..
                    " " .. itemName .. " (Journal: " .. other .. ")"
            else
                target.loot = target.loot or {}
                target.loot[#target.loot + 1] = { id, "ForeverDB.net", "", 0 }
                added = added + 1
            end
            seen = seen + 1
        end
    end
    file:close()
    return added, present, conflicts, seen
end
