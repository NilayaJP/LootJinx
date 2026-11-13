-- Classifies the evidence already stored on each Need roll.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local E = {}
LJ.Evidence = E

local reasons = {
    ["chat-won"] = { "confirmed", "EVIDENCE_CHAT_WIN" },
    ["chat-other-won"] = { "confirmed", "EVIDENCE_CHAT_OTHER" },
    ["chat-all-passed"] = { "confirmed", "EVIDENCE_CHAT_PASSED" },
    ["chat-won-ambiguous"] = { "inferred", "EVIDENCE_AMBIGUOUS" },
    ["chat-other-won-ambiguous"] = { "inferred", "EVIDENCE_AMBIGUOUS" },
    ["chat-all-passed-ambiguous"] = { "inferred", "EVIDENCE_AMBIGUOUS" },
    ["bags"] = { "inferred", "EVIDENCE_BAGS" },
    ["repair"] = { "inferred", "EVIDENCE_REPAIR" },
    ["chat-loot-self"] = { "inferred", "EVIDENCE_LOOT_CHAT" },
    ["chat-loot-other"] = { "inferred", "EVIDENCE_LOOT_CHAT" },
    ["greed-guard"] = { "inferred", "EVIDENCE_GREED" },
    ["no-item"] = { "inferred", "EVIDENCE_NO_ITEM" },
}

function E:Classify(need, observedSelfWinner)
    if type(need) ~= "table" or need.result == nil then
        if observedSelfWinner then return "inferred", "EVIDENCE_DROP_WINNER" end
        return "unresolved", "EVIDENCE_PENDING"
    end
    local match = reasons[need.reason]
    if match then return match[1], match[2] end
    return "unknown", "EVIDENCE_OLD"
end

function E:ClassifyDrop(drop)
    if type(drop) ~= "table" then return "unresolved", "EVIDENCE_DROP_OBSERVED" end
    local sources = type(drop.sources) == "table" and drop.sources or {}
    local source = drop.source
    if drop.winner and drop.winnerSource == "encounter" then
        return "confirmed", "EVIDENCE_DROP_ENCOUNTER"
    end
    if drop.winner and drop.winnerSource == "lootHistory" then
        return "confirmed", "EVIDENCE_DROP_HISTORY"
    end
    if (drop.winner and drop.winnerSource == "chat")
        or (drop.passed and (sources.chat or source == "chat")) then
        return "confirmed", "EVIDENCE_DROP_CHAT"
    end
    if drop.winner then return "unknown", "EVIDENCE_OLD" end
    return "unresolved", "EVIDENCE_DROP_OBSERVED"
end

return E
