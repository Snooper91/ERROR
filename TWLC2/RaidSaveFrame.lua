function RSLoad_OnClick(w)

    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local n, _, group = GetRaidRosterInfo(i)

            for groupNr, data in next, TWLC_RAID[w] do
                for _, name in next, data do
                    if name == n then
                        if groupNr ~= group then
                            SetRaidSubgroup(i, groupNr);
                        end
                    end
                end
            end
        end
    end

    twprint(w ..' Setup Loaded.')

end

function RSSave_OnClick(w)

    local groups = {
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {},
        [5] = {},
        [6] = {},
        [7] = {},
        [8] = {},
    }

    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local name, _, group = GetRaidRosterInfo(i)
            table.insert(groups[group], name)
        end
    end

    TWLC_RAID[w] = groups

    twprint(w .. ' Setup Saved.')

end
