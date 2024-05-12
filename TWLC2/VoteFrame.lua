local addonVer = "1.1.0.7" --don't use letters or numbers > 10
local me = UnitName('player')
local TWLC2_CHANNEL = 'TWLC2'
local TWLC2c_CHANNEL = 'TWLCNF'

--todo : tie consumable check / attendace to bigwigs boss pull

function twprint(a)
    if a == nil then
        DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[TWLC2Error]|cff0070de:' .. time() .. '|cffffffff attempt to print a nil value.')
        return false
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[TWLC2] |cffffffff" .. a)
end

function twerror(a)
    DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[TWLC2Error]|cff0070de:' .. time() .. '|cffffffff[' .. a .. ']')
end

function twdebug(a)
    if not TWLC_DEBUG then
        return
    end
    if type(a) == 'boolean' then
        if a then
            twprint('|cff0070de[DEBUG:' .. time() .. ']|cffffffff[true]')
        else
            twprint('|cff0070de[DEBUG:' .. time() .. ']|cffffffff[false]')
        end
        return true
    end
    twprint('|cff0070de[DEBUG:' .. time() .. ']|cffffffff[' .. a .. ']')
end

local RLWindowFrame = CreateFrame("Frame")
RLWindowFrame.assistFrames = {}
RLWindowFrame.currentTab = 1

local LCVoteFrame = CreateFrame("Frame", "LCVoteFrame")

LCVoteFrame:RegisterEvent("ADDON_LOADED")
LCVoteFrame:RegisterEvent("LOOT_OPENED")
LCVoteFrame:RegisterEvent("LOOT_SLOT_CLEARED")
LCVoteFrame:RegisterEvent("LOOT_CLOSED")
LCVoteFrame:RegisterEvent("RAID_ROSTER_UPDATE")
LCVoteFrame:RegisterEvent("CHAT_MSG_SYSTEM")
LCVoteFrame:RegisterEvent("PLAYER_TARGET_CHANGED") --for bosses
LCVoteFrame.VotedItemsFrames = {}
LCVoteFrame.CurrentVotedItem = nil --slotIndex
LCVoteFrame.currentPlayersList = {} --all
LCVoteFrame.playersPerPage = 10
LCVoteFrame.itemVotes = {}
LCVoteFrame.LCVoters = 0
LCVoteFrame.playersWhoWantItems = {}
LCVoteFrame.voteTiePlayers = ''
LCVoteFrame.currentItemWinner = ''
LCVoteFrame.currentItemMaxVotes = 0
LCVoteFrame.currentRollWinner = ''
LCVoteFrame.currentMaxRoll = {}

LCVoteFrame.numPlayersThatWant = 0
LCVoteFrame.namePlayersThatWants = 0

LCVoteFrame.waitResponses = {}
LCVoteFrame.receivedResponses = 0
LCVoteFrame.pickResponses = {}

LCVoteFrame.lootHistoryMinRarity = 3
LCVoteFrame.selectedPlayer = {}

LCVoteFrame.lootHistoryFrames = {}
LCVoteFrame.consumablesListFrames = {}
LCVoteFrame.peopleWithAddon = ''

LCVoteFrame.doneVoting = {} --self / item
LCVoteFrame.clDoneVotingItem = {}

LCVoteFrame.itemsToPreSend = {}
LCVoteFrame.sentReset = false

LCVoteFrame.debugText = ''
LCVoteFrame.numItems = 0

LCVoteFrame.LOOT_OPENED = false
LCVoteFrame.hordeLoot = {}

LCVoteFrame.CLVotedFrames = {}
LCVoteFrame.RaidBuffs = {}

--r, g, b, hex = GetItemQualityColor(quality)
local classColors = {
    ["warrior"] = { r = 0.78, g = 0.61, b = 0.43, c = "|cffc79c6e" },
    ["mage"] = { r = 0.41, g = 0.8, b = 0.94, c = "|cff69ccf0" },
    ["rogue"] = { r = 1, g = 0.96, b = 0.41, c = "|cfffff569" },
    ["druid"] = { r = 1, g = 0.49, b = 0.04, c = "|cffff7d0a" },
    ["hunter"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffabd473" },
    ["shaman"] = { r = 0.14, g = 0.35, b = 1.0, c = "|cff0070de" },
    ["priest"] = { r = 1, g = 1, b = 1, c = "|cffffffff" },
    ["warlock"] = { r = 0.58, g = 0.51, b = 0.79, c = "|cff9482c9" },
    ["paladin"] = { r = 0.96, g = 0.55, b = 0.73, c = "|cfff58cba" },
}

local needs = {
    ["bis"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffa335ee", text = 'BIS' },
    ["ms"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cff0070dd", text = 'MS Upgrade' },
    ["os"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffe79e08", text = 'Offspec' },
    ["xmog"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffb518ff", text = 'Transmog' },
    ["pass"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cff696969", text = 'pass' },
    ["autopass"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cff696969", text = 'auto pass' },
    ["wait"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cff999999", text = 'Waiting pick...' },
}

local itemTypes = {
    [0] = 'Consumable',
    [1] = 'Container',
    [2] = 'Weapon',
    [3] = 'Gem',
    [4] = 'Armor',
    [5] = 'Reagent',
    [6] = 'Projectile',
    [7] = 'Tradeskill',
    [8] = 'Item Enhancement',
    [9] = 'Recipe',
    [10] = 'Money(OBSOLETE)',
    [11] = 'Quiver	Obsolete',
    [12] = 'Quest',
    [13] = 'Key	Obsolete',
    [14] = 'Permanent(OBSOLETE)',
    [15] = 'Miscellaneous'
}

local equipSlots = {
    ["INVTYPE_AMMO"] = 'Ammo', --	0', --
    ["INVTYPE_HEAD"] = 'Head', --	1',
    ["INVTYPE_NECK"] = 'Neck', --	2',
    ["INVTYPE_SHOULDER"] = 'Shoulder', --	3',
    ["INVTYPE_BODY"] = 'Shirt', --	4',
    ["INVTYPE_CHEST"] = 'Chest', --	5',
    ["INVTYPE_ROBE"] = 'Chest', --	5',
    ["INVTYPE_WAIST"] = 'Waist', --	6',
    ["INVTYPE_LEGS"] = 'Legs', --	7',
    ["INVTYPE_FEET"] = 'Feet', --	8',
    ["INVTYPE_WRIST"] = 'Wrist', --	9',
    ["INVTYPE_HAND"] = 'Hands', --	10',
    ["INVTYPE_FINGER"] = 'Ring', --	11,12',
    ["INVTYPE_TRINKET"] = 'Trinket', --	13,14',
    ["INVTYPE_CLOAK"] = 'Cloak', --	15',
    ["INVTYPE_WEAPON"] = 'One-Hand', --	16,17',
    ["INVTYPE_SHIELD"] = 'Shield', --	17',
    ["INVTYPE_2HWEAPON"] = 'Two-Handed', --	16',
    ["INVTYPE_WEAPONMAINHAND"] = 'Main-Hand Weapon', --	16',
    ["INVTYPE_WEAPONOFFHAND"] = 'Off-Hand Weapon', --	17',
    ["INVTYPE_HOLDABLE"] = 'Held In Off-Hand', --	17',
    ["INVTYPE_RANGED"] = 'Bow', --	18',
    ["INVTYPE_THROWN"] = 'Ranged', --	18',
    ["INVTYPE_RANGEDRIGHT"] = 'Wands, Guns, and Crossbows', --	18',
    ["INVTYPE_RELIC"] = 'Relic', --	18',
    ["INVTYPE_TABARD"] = 'Tabard', --	19',
    ["INVTYPE_BAG"] = 'Container', --	20,21,22,23',
    ["INVTYPE_QUIVER"] = 'Quiver', --	20,21,22,23',
}

local attendanceTargets = {
    ["Blackwing Lair"] = {
        ["Grethok the Controller"] = "Razorgore the Untamed",
        ["Razorgore the Untamed"] = "Razorgore the Untamed",
        ["Vaelastrasz the Corrupt"] = "Vaelastrasz the Corrupt",
        ["Broodlord Lashlayer"] = "Broodlord Lashlayer",
        ["Firemaw"] = "Firemaw",
        ["Ebonroc"] = "Ebonroc",
        ["Flamegor"] = "Flamegor",
        ["Chromaggus"] = "Chromaggus",
        ["Lord Victor Nefarius"] = "Lord Victor Nefarius",
        ["Nefarian"] = "Nefarian",
    },
    ["Ahn'Qiraj"] = {
        ["The Prophet Skeram"] = "The Prophet Skeram",
        ["Vem"] = "Bug Trio",
        ["Princess Yauj"] = "Bug Trio",
        ["Lord Kri"] = "Bug Trio",
        ["Battleguard Sartura"] = "Battleguard Sartura",
        ["Fankriss the Unyielding"] = "Fankriss the Unyielding",
        ["Viscidus"] = "Viscidus",
        ["Princess Huhuran"] = "Princess Huhuran",
        ["Emperor Vek'lor"] = "Twin Emperors",
        ["Emperor Vek'nilash"] = "Twin Emperors",
        ["Ouro"] = "Ouro",
        ["Kurinnaxx"] = "Kurinnaxx",
    },
    ["Naxxramas"] = {
        ['Anub\'Rekhan'] = 'Anub\'Rekhan',
        ['Grand Widow Faerlina'] = 'Grand Widow Faerlina',
        ['Maexxna'] = 'Maexxna',
        ['Noth the Plaguebringer'] = 'Noth the Plaguebringer',
        ['Heigan the Unclean'] = 'Heigan the Unclean',
        ['Loatheb'] = 'Loatheb',
        ['Instructor Razuvious'] = 'Instructor Razuvious',
        ['Gothik the Harvester'] = 'Gothik the Harvester',
        ['Highlord Mograine'] = 'The Four Horsemen',
        ['Thane Korth\'azz'] = 'The Four Horsemen',
        ['Lady Blaumeux'] = 'The Four Horsemen',
        ['Sir Zeliek'] = 'The Four Horsemen',
        ['Patchwerk'] = 'Patchwerk',
        ['Grobbulus'] = 'Grobbulus',
        ['Gluth'] = 'Gluth',
        ['Thaddius'] = 'Thaddius',
        ['Sapphiron'] = 'Sapphiron',
        ['Kel\'Thuzad'] = 'Kel\'Thuzad',
    }
}

function TWLC2MainWindow_Resizing()
    getglobal('LootLCVoteFrameWindow'):SetAlpha(0.5)
end

function TWLC2MainWindow_Resized()
    local MW = getglobal('LootLCVoteFrameWindow');
    local MWH = MW:GetHeight()

    LCVoteFrame.playersPerPage = math.floor((MWH - 120) / 22)
    TWLC_PPP = LCVoteFrame.playersPerPage
    MW:SetHeight(120 + LCVoteFrame.playersPerPage * 22 + 5)
    getglobal('ContestantScrollListFrame'):SetHeight(LCVoteFrame.playersPerPage * 22)
    getglobal('ContestantScrollListBackground'):SetHeight(LCVoteFrame.playersPerPage * 22 + 3)

    MW:SetAlpha(TWLC_ALPHA)

    VoteFrameListScroll_Update()
end

local LCVoteFrameComms = CreateFrame("Frame")
LCVoteFrameComms:RegisterEvent("CHAT_MSG_ADDON")

local LCVoteSyncFrame = CreateFrame("Frame")
LCVoteSyncFrame.NEW_ROSTER = {}

local ContestantDropdownMenu = CreateFrame('Frame', 'ContestantDropdownMenu', UIParent, 'UIDropDownMenuTemplate')
ContestantDropdownMenu.currentContestantId = 0

local VoteCountdown = CreateFrame("Frame")

local TWLCCountDownFRAME = CreateFrame("Frame")
TWLCCountDownFRAME:Hide()
TWLCCountDownFRAME.currentTime = 1
TWLCCountDownFRAME:SetScript("OnShow", function()
    this.startTime = GetTime();
end)

TWLCCountDownFRAME:SetScript("OnUpdate", function()
    local plus = 0.03
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        if TWLCCountDownFRAME.currentTime ~= TWLCCountDownFRAME.countDownFrom + plus then
            --tick

            if LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem] then
                if LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].pickedByEveryone then
                    getglobal('LootLCVoteFrameWindowTimeLeftBar'):Hide()
                else
                    getglobal('LootLCVoteFrameWindowTimeLeftBar'):Show()
                end
            end

            local tlx = 15 + ((TWLCCountDownFRAME.countDownFrom - TWLCCountDownFRAME.currentTime + plus) * 500 / TWLCCountDownFRAME.countDownFrom)
            if tlx > 470 then
                tlx = 470
            end
            if tlx <= 250 then
                tlx = 250
            end
            if math.floor(TWLCCountDownFRAME.countDownFrom - TWLCCountDownFRAME.currentTime) > 55 then
                --                getglobal('LootLCVoteFrameWindowTimeLeft'):Hide()
                getglobal('LootLCVoteFrameWindowTimeLeft'):Show()
            end
            if math.floor(TWLCCountDownFRAME.countDownFrom - TWLCCountDownFRAME.currentTime) <= 55 then
                getglobal('LootLCVoteFrameWindowTimeLeft'):Show()
            end
            if math.floor(TWLCCountDownFRAME.countDownFrom - TWLCCountDownFRAME.currentTime) < 1 then
                getglobal('LootLCVoteFrameWindowTimeLeft'):Hide()
            end

            local secondsLeft = math.floor(TWLCCountDownFRAME.countDownFrom - TWLCCountDownFRAME.currentTime) -- .. 's'

            getglobal('LootLCVoteFrameWindowTimeLeft'):SetText(SecondsToClock(secondsLeft))
            getglobal('LootLCVoteFrameWindowTimeLeft'):SetPoint("BOTTOMLEFT", 280, 10)

            getglobal('LootLCVoteFrameWindowTimeLeftBar'):SetWidth((TWLCCountDownFRAME.countDownFrom - TWLCCountDownFRAME.currentTime + plus) * 592 / TWLCCountDownFRAME.countDownFrom)
        end
        TWLCCountDownFRAME:Hide()
        if (TWLCCountDownFRAME.currentTime < TWLCCountDownFRAME.countDownFrom + plus) then
            --still tick
            TWLCCountDownFRAME.currentTime = TWLCCountDownFRAME.currentTime + plus
            TWLCCountDownFRAME:Show()
        elseif (TWLCCountDownFRAME.currentTime > TWLCCountDownFRAME.countDownFrom + plus) then

            --end
            TWLCCountDownFRAME:Hide()
            TWLCCountDownFRAME.currentTime = 1

            getglobal('MLToWinner'):Enable()

            --set all to auto pass - disabled for when wait= is not there
            --            for index, votedItem in next, LCVoteFrame.VotedItemsFrames do
            --                for i = 1, tableSize(LCVoteFrame.playersWhoWantItems) do
            --                    if LCVoteFrame.playersWhoWantItems[i]['itemIndex'] == index then
            --                        if LCVoteFrame.playersWhoWantItems[i]['need'] == 'wait' then
            --                            --changePlayerPickTo(LCVoteFrame.playersWhoWantItems[i]['name'], 'autopass', index)
            --                            if not changePlayerPickTo_OnlyLocal(LCVoteFrame.playersWhoWantItems[i]['name'], 'autopass', index) then
            --                                twerror('could not change pick to autopass for item ' .. index .. ' for player ' .. LCVoteFrame.playersWhoWantItems[i]['name'])
            --                            end
            --                            if (LCVoteFrame.pickResponses[index]) then
            --                                if LCVoteFrame.pickResponses[index] < LCVoteFrame.waitResponses[index] then
            --                                    LCVoteFrame.pickResponses[index] = LCVoteFrame.pickResponses[index] + 1
            --                                end
            --                            end
            --                        end
            --                    end
            --                end
            --            end

            --setall autopass v2 (no wait=)
            local onlineRaiders = GetNumOnlineRaidMembers()
            for raidi = 0, GetNumRaidMembers() do
                if GetRaidRosterInfo(raidi) then
                    local n, _, _, _, _, _, z = GetRaidRosterInfo(raidi);
                    if z ~= 'Offline' then

                        for index, votedItem in next, LCVoteFrame.VotedItemsFrames do
                            local picked = false
                            for i = 1, tableSize(LCVoteFrame.playersWhoWantItems) do
                                if LCVoteFrame.playersWhoWantItems[i]['itemIndex'] == index and LCVoteFrame.playersWhoWantItems[i]['name'] == n then
                                    picked = true
                                    break
                                end
                            end
                            if not picked then
                                --add player to playersWhoWant with autopass
                                --can be disabled to hide autopasses
                                table.insert(LCVoteFrame.playersWhoWantItems, {
                                    ['itemIndex'] = index,
                                    ['name'] = n,
                                    ['need'] = 'autopass',
                                    ['ci1'] = '0',
                                    ['ci2'] = '0',
                                    ['ci3'] = '0',
                                    ['votes'] = 0,
                                    ['roll'] = 0
                                })

                                --increment pick responses, even for autopass
                                if (LCVoteFrame.pickResponses[index]) then
                                    if LCVoteFrame.pickResponses[index] < onlineRaiders then
                                        LCVoteFrame.pickResponses[index] = LCVoteFrame.pickResponses[index] + 1
                                    end
                                else
                                    LCVoteFrame.pickResponses[index] = 1
                                end
                            end
                        end
                    end
                end
            end

            VoteCountdown.votingOpen = true
            LCVoteFrame.showWindow() -- moved from VoteFrameListScroll_Update()

            VoteFrameListScroll_Update()

            VoteCountdown:Show()

        else
            --
        end
    else
        --
    end
end)

VoteCountdown:Hide()
VoteCountdown.currentTime = 1
VoteCountdown.votingOpen = false
VoteCountdown:SetScript("OnShow", function()
    this.startTime = GetTime();
end)

VoteCountdown:SetScript("OnUpdate", function()
    local plus = 0.03
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        if (VoteCountdown.currentTime ~= VoteCountdown.countDownFrom + plus) then
            --tick
            if (VoteCountdown.countDownFrom - VoteCountdown.currentTime) >= 0 then
                getglobal('LootLCVoteFrameWindowTimeLeft'):Show()
                local secondsLeftToVote = math.floor((VoteCountdown.countDownFrom - VoteCountdown.currentTime)) --.. 's left ! '
                getglobal('LootLCVoteFrameWindowTimeLeft'):SetPoint("BOTTOMLEFT", 240, 10)
                if LCVoteFrame.doneVoting[LCVoteFrame.CurrentVotedItem] == true then
                    getglobal('LootLCVoteFrameWindowTimeLeft'):SetText('')
                else
                    getglobal('LootLCVoteFrameWindowTimeLeft'):SetText('Please VOTE ! ' .. SecondsToClock(secondsLeftToVote))
                end

                local w = math.floor(((VoteCountdown.countDownFrom - VoteCountdown.currentTime) / VoteCountdown.countDownFrom) * 1000)
                w = w / 1000

                if (w > 0 and w <= 1) then
                    getglobal('LootLCVoteFrameWindowTimeLeftBar'):Show()
                    getglobal('LootLCVoteFrameWindowTimeLeftBar'):SetWidth(592 * w)
                else
                    getglobal('LootLCVoteFrameWindowTimeLeftBar'):Hide()
                end
            end

            VoteCountdown:Hide()
            if (VoteCountdown.currentTime < VoteCountdown.countDownFrom + plus) then
                --still tick
                VoteCountdown.currentTime = VoteCountdown.currentTime + plus
                VoteCountdown:Show()
            elseif (VoteCountdown.currentTime > VoteCountdown.countDownFrom + plus) then

                --end
                VoteCountdown:Hide()
                VoteCountdown.currentTime = 1
                --                VoteCountdown.votingOpen = false

                getglobal('LootLCVoteFrameWindowTimeLeft'):Show()
                getglobal('LootLCVoteFrameWindowTimeLeft'):SetText('')
                getglobal("MLToWinner"):Enable()
            end
        else
            --
        end
    else
        --
    end
end)

SLASH_TWLC1 = "/twlc"
SlashCmdList["TWLC"] = function(cmd)
    if cmd then
        --        if string.sub(cmd, 1, 10) == 'attendance' then
        --            TWLC_CONFIG['attendance'] = not TWLC_CONFIG['attendance']
        --            if TWLC_CONFIG['attendance'] then
        --                twprint('Attendance on')
        --            else
        --                twprint('Attendance off')
        --            end
        --        end
        if string.sub(cmd, 1, 3) == 'add' then
            local setEx = string.split(cmd, ' ')
            if setEx[2] then
                addToRoster(setEx[2])
            else
                twprint('Adds LC member')
                twprint('sintax: /twlc add <name>')
            end
        end
        if string.sub(cmd, 1, 3) == 'rem' then
            local setEx = string.split(cmd, ' ')
            if setEx[2] then
                remFromRoster(setEx[2])
            else
                twprint('Removes LC member')
                twprint('sintax: /twlc rem <name>')
            end
        end
        if string.sub(cmd, 1, 3) == 'set' then
            local setEx = string.split(cmd, ' ')
            if setEx[2] and setEx[3] then
                if twlc2isRL(me) then
                    if setEx[2] == 'sandcollector' then
                        if setEx[3] == '' or tonumber(setEx[3]) then
                            twprint('Incorrect syntax. Use /twlc set sandcollector [name]')
                            return false
                        end
                        TWLC_SAND_COLLECTOR = setEx[3]
                        local sandCollectorClassColor = classColors[getPlayerClass(TWLC_SAND_COLLECTOR)].c
                        twprint('TWLC_SAND_COLLECTOR - set to ' .. sandCollectorClassColor .. TWLC_SAND_COLLECTOR)
                        if TWLC_AUTO_ML_SAND then
                            twprint('Auto ML Sand is |cff69ccf0ON')
                        else
                            twprint('Auto ML Sand is |cff69ccf0OFF')
                        end
                    end
                    if setEx[2] == 'sand' then

                        if setEx[3] == '' or tonumber(setEx[3]) then
                            twprint('Incorrect syntax. Use /twlc set sand on/off')
                            return false
                        end

                        if TWLC_SAND_COLLECTOR == '' then
                            twprint('Sand Collector not set. Use /twlc set sandcollector [name] first')
                        else
                            if setEx[3] == 'on' then
                                TWLC_AUTO_ML_SAND = true
                                twprint('Auto ML Sand is |cff69ccf0ON')
                            else
                                TWLC_AUTO_ML_SAND = false
                                twprint('Auto ML Sand is |cff69ccf0OFF')
                            end
                        end
                    end
                    if setEx[2] == 'disenchanter' or setEx[2] == 'enchanter' then
                        if setEx[3] == '' or tonumber(setEx[3]) then
                            twprint('Incorrect syntax. Use /twlc set disenchanter/enchanter [name]')
                            return false
                        end
                        TWLC_DESENCHANTER = setEx[3]
                        local deClassColor = classColors[getPlayerClass(TWLC_DESENCHANTER)].c
                        twprint('TWLC_DESENCHANTER - set to ' .. deClassColor .. TWLC_DESENCHANTER)
                        getglobal('MLToEnchanter'):Show()
                        local DEButton = getglobal("MLToEnchanter")

                        DEButton:SetScript("OnEnter", function(self)
                            LCTooltipVoteFrame:SetOwner(this, "ANCHOR_BOTTOMRIGHT", -100, 0);
                            if TWLC_DESENCHANTER == '' then
                                LCTooltipVoteFrame:AddLine("Enchanter not set. Type /twlc set enchanter [name]")
                            else
                                LCTooltipVoteFrame:AddLine("ML to " .. TWLC_DESENCHANTER .. " to disenchant.")
                            end
                            LCTooltipVoteFrame:Show();
                        end)

                        DEButton:SetScript("OnLeave", function(self)
                            LCTooltipVoteFrame:Hide();
                        end)
                    end
                    if setEx[2] == 'sattelite' then
                        if setEx[3] == '' or tonumber(setEx[3]) then
                            twprint('Incorrect syntax. Use /twlc set sattelite [name]')
                            return false
                        end
                        TWLC_HORDE_SATTELITE = setEx[3]
                        local sateliteClassColor = classColors[getPlayerClass(TWLC_HORDE_SATTELITE)].c
                        getglobal("ScanHordeLoot"):SetText('Get Horde Loot (' .. sateliteClassColor .. TWLC_HORDE_SATTELITE .. FONT_COLOR_CODE_CLOSE .. ')')
                        twprint('TWLC_HORDE_SATTELITE - set to ' .. sateliteClassColor .. TWLC_HORDE_SATTELITE)
                    end
                    if setEx[2] == 'ttr' then
                        if setEx[3] == '' or not tonumber(setEx[3]) then
                            twprint('Incorrect syntax. Use /twlc set ttr [time in seconds]')
                            return false
                        end
                        TIME_TO_ROLL = tonumber(setEx[3])
                        twprint('TIME_TO_ROLL - set to ' .. TIME_TO_ROLL .. 's')
                        SendAddonMessage(TWLC2_CHANNEL, 'ttr=' .. TIME_TO_ROLL, "RAID")
                    end
                else
                    twprint('You are not the raid leader.')
                end
            else
                twprint('SET Options')
                twprint('/twlc set ttr <time> - sets TIME_TO_ROLL (current value: ' .. TIME_TO_ROLL .. 's)')
                twprint('/twlc set sattelite <name> - sets TWLC_HORDE_SATTELITE (current value: ' .. TWLC_HORDE_SATTELITE .. ')')
                twprint('/twlc set enchanter/disenchanter <name> - sets TWLC_DESENCHANTER (current value: ' .. TWLC_DESENCHANTER .. ')')
            end
        end
        if cmd == 'list' then
            listRoster()
        end
        if cmd == 'debug' then
            TWLC_DEBUG = not TWLC_DEBUG
            if TWLC_DEBUG then
                twprint('|cff69ccf0[TWLCc] |cffffffffDebug ENABLED')
            else
                twprint('|cff69ccf0[TWLC2c] |cffffffffDebug DISABLED')
            end
        end
        if cmd == 'autoassist' then
            TWLC_AUTO_ASSIST = not TWLC_AUTO_ASSIST
            if TWLC_DEBUG then
                twprint('|cff69ccf0[TWLCc] |cffffffffAutoAssist ENABLED')
                LCVoteFrame.assistTriggers = 0
            else
                twprint('|cff69ccf0[TWLC2c] |cffffffffAutoAssist DISABLED')
            end
        end
        if cmd == 'who' then
            RefreshWho_OnClick()
        end
        if cmd == 'synchistory' then
            if not twlc2isRL(me) then
                return
            end
            syncLootHistory_OnClick()
        end
        if cmd == 'clearhistory' then
            TWLC_LOOT_HISTORY = {}
            twprint('Loot History cleared.')
        end
        if string.sub(cmd, 1, 6) == 'search' then
            local cmdEx = string.split(cmd, ' ')

            if cmdEx[2] then

                local numItems = 0
                for _, item in pairsByKeysReverse(TWLC_LOOT_HISTORY) do
                    if string.lower(cmdEx[2]) == string.lower(item['player']) then
                        numItems = numItems + 1
                    end
                end

                if numItems > 0 then
                    twprint('Listing ' .. cmdEx[2] .. '\'s loot history:')
                    for lootTime, item in pairsByKeysReverse(TWLC_LOOT_HISTORY) do
                        if string.lower(cmdEx[2]) == string.lower(item['player']) then
                            twprint(item['item'] .. ' - ' .. date("%d/%m", lootTime))
                        end
                    end
                else
                    twprint('- no recorded items -')
                end

                for lootTime, item in pairsByKeysReverse(TWLC_LOOT_HISTORY) do
                    if string.find(string.lower(item['item']), string.lower(cmdEx[2])) then
                        twprint(item['player'] .. " - " .. item['item'] .. " " .. date("%d/%m", lootTime))
                    end
                end

            else
                twprint('Search syntax: /twlc search [Playername]')
            end
        end
        if string.sub(cmd, 1, 5) == 'scale' then
            local scaleEx = string.split(cmd, ' ')
            if not scaleEx[1] or not scaleEx[2] or not tonumber(scaleEx[2]) then
                twprint('Set scale syntax: |cfffff569/twlc scale [scale from 0.5 to 2]')
                return false
            end

            if tonumber(scaleEx[2]) >= 0.5 and tonumber(scaleEx[2]) <= 2 then
                getglobal('LootLCVoteFrameWindow'):SetScale(tonumber(scaleEx[2]))
                getglobal('LootLCVoteFrameWindow'):ClearAllPoints();
                getglobal('LootLCVoteFrameWindow'):SetPoint("CENTER", UIParent);
                TWLC_SCALE = tonumber(scaleEx[2])
                twprint('Scale set to |cfffff569x' .. TWLC_SCALE)
            else
                twprint('Set scale syntax: |cfffff569/twlc scale [scale from 0.5 to 2]')
            end
        end
        if string.sub(cmd, 1, 5) == 'alpha' then
            local alphaEx = string.split(cmd, ' ')
            if not alphaEx[1] or not alphaEx[2] or not tonumber(alphaEx[2]) then
                twprint('Set alpha syntax: |cfffff569/twlc alpha [0.2-1]')
                return false
            end

            if tonumber(alphaEx[2]) >= 0.2 and tonumber(alphaEx[2]) <= 1 then
                TWLC_ALPHA = tonumber(alphaEx[2])
                getglobal('LootLCVoteFrameWindow'):SetAlpha(TWLC_ALPHA)
                twprint('Alpha set to |cfffff569' .. TWLC_ALPHA)
            else
                twprint('Set alpha syntax: |cfffff569/twlc alpha [0.2-1]')
            end
        end
    end
end

function RefreshWho_OnClick()
    if not UnitInRaid('player') then
        twprint('You are not in a raid.')
        return false
    end
    getglobal('VoteFrameWho'):Show()
    LCVoteFrame.peopleWithAddon = ''
    getglobal('VoteFrameWhoText'):SetText('Loading...')
    SendAddonMessage(TWLC2c_CHANNEL, "voteframe=whoVF=" .. addonVer, "RAID")
end

function syncLootHistory_OnClick()
    local totalItems = 0

    getglobal('RLWindowFrameSyncLootHistory'):Disable()

    for lootTime, item in next, TWLC_LOOT_HISTORY do
        totalItems = totalItems + 1
    end

    twprint('Starting History Sync, ' .. totalItems .. ' entries...')
    ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "loot_history_sync;start", "RAID")
    for lootTime, item in next, TWLC_LOOT_HISTORY do
        ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "loot_history_sync;" .. lootTime .. ";" .. item['player'] .. ";" .. item['item'], "RAID")
    end
    ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "loot_history_sync;end", "RAID")
    twprint('History Sync finished. Sent ' .. totalItems .. ' entries.')
end

function toggleMainWindow()

    if getglobal('LootLCVoteFrameWindow'):IsVisible() then
        getglobal('LootLCVoteFrameWindow'):Hide()
    else
        if not canVote(me) and not twlc2isRL(me) then
            return false
        end
        getglobal('LootLCVoteFrameWindow'):Show()
    end
end

function addToRoster(newName)
    if not twlc2isRL(me) then
        twprint('You are not the raid leader.')
        return
    end
    for name, v in next, TWLC_ROSTER do
        if (name == newName) then
            twprint(newName .. ' already exists.')
            return false
        end
    end
    TWLC_ROSTER[newName] = false
    twprint(newName .. ' added to TWLC Roster')
    PromoteToAssistant(newName)
    syncRoster()
end

function remFromRoster(newName)
    if (not twlc2isRL(me)) then
        twprint('You are not the raid leader.')
        return
    end
    for name, v in next, TWLC_ROSTER do
        if (name == newName) then
            TWLC_ROSTER[newName] = nil
            twprint(newName .. ' removed from TWLC Roster')
            syncRoster()
            return true
        end
    end
    twprint(newName .. ' does not exist in the roster.')
end

function listRoster()
    local roster = ''
    for name, v in next, TWLC_ROSTER do
        roster = roster .. name .. ' '
    end
    twprint('Listing TWLC Roster')
    twprint(roster)
end

function syncRoster()
    local index = 0
    for i = 1, tableSize(RLWindowFrame.assistFrames) do
        getglobal('AssistFrame' .. i .. 'AssistCheck'):Disable()
        getglobal('AssistFrame' .. i .. 'CLCheck'):Disable()
    end
    ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "syncRoster=start", "RAID")
    for name, v in next, TWLC_ROSTER do
        index = index + 1
        ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "syncRoster=" .. name, "RAID")
    end
    ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "syncRoster=end", "RAID")

    getglobal('RLWindowFrameOfficer'):SetText('Officer(' .. index .. ')')

    if (twlc2isRL(me)) then
        checkAssists()
    end
end

function getEquipSlot(j)
    for k, v in next, equipSlots do
        if (k == tostring(j)) then
            return v
        end
    end
    return ''
end

function GetPlayer(index)
    return LCVoteFrame.playersWhoWantItems[index]
end

LCVoteFrame.assistTriggers = 0

LCVoteFrame:SetScript("OnEvent", function()
    if event then
        if event == "RAID_ROSTER_UPDATE" then
            if twlc2isRL(me) then
                twdebug('RAID_ROSTER_UPDATE');
                getglobal('RSWindow'):Show()
                if TWLC_AUTO_ASSIST then
                    for i = 0, GetNumRaidMembers() do
                        if (GetRaidRosterInfo(i)) then
                            local n, r = GetRaidRosterInfo(i);
                            if twlc2isCL(n) and r == 0 and n ~= me then
                                twdebug('PROMOTE TRIGGER');
                                LCVoteFrame.assistTriggers = LCVoteFrame.assistTriggers + 1
                                PromoteToAssistant(n)
                                twprint(n .. ' |cff69ccf0autopromoted|cffffffff(' .. LCVoteFrame.assistTriggers .. '/100). Type |cff69ccf0/twlc autoassist |cffffffffto disable this feature.')

                                if LCVoteFrame.assistTriggers > 100 then
                                    twerror('Autoassist trigger error (>100). Autoassist disabled.')
                                    TWLC_AUTO_ASSIST = false
                                end

                                return false
                            end
                        end
                    end
                end
                twdebug('RAID_ROSTER_UPDATE CONTINUE');
                getglobal('RLOptionsButton'):Show()
                getglobal('RLExtraFrame'):Show()
                getglobal('MLToWinner'):Show()
                getglobal('ResetClose'):Show()
                checkAssists()
            else
                getglobal('MLToWinner'):Hide()
                getglobal('RLExtraFrame'):Hide()
                getglobal('RLOptionsButton'):Hide()
                getglobal('RLWindowFrame'):Hide()
                getglobal('ResetClose'):Hide()
            end
            if not canVote(me) then
                getglobal('LootLCVoteFrameWindow'):Hide()
            end
        end
        if event == "CHAT_MSG_SYSTEM" then
            if (string.find(arg1, "The following players are AFK", 1, true) or
                    string.find(arg1, "No players are AFK", 1, true)
            ) and twlc2isRL(me) then
                SendChatMessage(arg1, "RAID")
            end
            if ((string.find(arg1, "rolls", 1, true) or string.find(arg1, "würfelt. Ergebnis", 1, true)) and string.find(arg1, "(1-100)", 1, true)) then
                --vote tie rolls
                --en--Er rolls 47 (1-100)
                --de--Er würfelt. Ergebnis: 47 (1-100)
                local r = string.split(arg1, " ")

                if not r[2] or not r[3] then
                    twerror('bad roll syntax')
                    twerror(arg1)
                    return false
                end

                local name = r[1]
                local roll = tonumber(r[3])

                if string.find(arg1, "würfelt. Ergebnis", 1, true) then
                    if not r[4] then
                        twerror('bad german roll syntax')
                        twerror(arg1)
                        return false
                    end
                    roll = tonumber(r[4])
                end

                --check if name is in playersWhoWantItems with vote == -2
                for pwIndex, pwPlayer in next, LCVoteFrame.playersWhoWantItems do
                    if (pwPlayer['name'] == name and pwPlayer['roll'] == -2) then
                        LCVoteFrame.playersWhoWantItems[pwIndex]['roll'] = roll
                        SendAddonMessage(TWLC2_CHANNEL, "playerRoll:" .. pwIndex .. ":" .. roll .. ":" .. LCVoteFrame.CurrentVotedItem, "RAID")
                        VoteFrameListScroll_Update()
                        break
                    end
                end
            end
        end
        if event == "ADDON_LOADED" and arg1 == 'TWLC2' then

            if not TWLC_CONFIG then
                TWLC_CONFIG = {
                    ['attendance'] = false,
                    ['AutoML'] = false,
                    ['AutoMLItems'] = {},
                    ['NeedButtons'] = {
                        ['BIS'] = false,
                        ['MS'] = true,
                        ['OS'] = true,
                        ['XMOG'] = true
                    }
                }
            end

            if not TIME_TO_NEED then
                TIME_TO_NEED = 30
            end
            if not TIME_TO_VOTE then
                TIME_TO_VOTE = 30
            end
            if not TIME_TO_ROLL then
                TIME_TO_ROLL = 30
            end
            if not TWLC_ROSTER then
                TWLC_ROSTER = {}
            end
            if not TWLC_LOOT_HISTORY then
                TWLC_LOOT_HISTORY = {}
            end
            if not TWLC_ENABLED then
                TWLC_ENABLED = false
            end
            if not TWLC_LOOT_HISTORY then
                TWLC_LOOT_HISTORY = {}
            end
            if TWLC_DEBUG == nil then
                TWLC_DEBUG = false
            end
            if not TWLC_SCALE then
                TWLC_SCALE = 1
            end
            if not TWLC_PPP then
                TWLC_PPP = 10
            end
            if not TWLC_ALPHA then
                TWLC_ALPHA = 1
            end
            if TWLC_AUTO_ASSIST == nil then
                TWLC_AUTO_ASSIST = true
            end
            if not TWLC_ATTENDANCE then
                TWLC_ATTENDANCE = {}
            end
            if not TWLC_HORDE_SATTELITE then
                TWLC_HORDE_SATTELITE = ''
            end
            if not TWLC_DESENCHANTER then
                TWLC_DESENCHANTER = ''
            end
            if not TWLC_SAND_COLLECTOR then
                TWLC_SAND_COLLECTOR = ''
            end
            if TWLC_AUTO_ML_SAND == nil then
                TWLC_AUTO_ML_SAND = false
            end

            if TWLC_HORDE_SATTELITE ~= '' then
                local sateliteClassColor = classColors[getPlayerClass(TWLC_HORDE_SATTELITE)].c
                getglobal("ScanHordeLoot"):SetText('Get Horde Loot (' .. sateliteClassColor .. TWLC_HORDE_SATTELITE .. FONT_COLOR_CODE_CLOSE .. ')')
            else
                getglobal("ScanHordeLoot"):SetText('- horde sattelite not set-')
            end

            if TWLC_CONFIG['attendance'] then
                getglobal('LootLCVoteFrameWindowNameLabel'):SetText('Name/Attendance')
            else
                getglobal('LootLCVoteFrameWindowNameLabel'):SetText('Name')
            end

            LCVoteFrame.playersPerPage = TWLC_PPP
            getglobal('LootLCVoteFrameWindow'):SetWidth(600)
            getglobal('LootLCVoteFrameWindow'):SetHeight(120 + LCVoteFrame.playersPerPage * 22 + 5)
            getglobal('LootLCVoteFrameWindow'):SetScale(TWLC_SCALE)
            TWLC2MainWindow_Resized()

            TWLCCountDownFRAME.countDownFrom = TIME_TO_NEED
            VoteCountdown.countDownFrom = TIME_TO_VOTE

            getglobal('LootLCVoteFrameWindowTitle'):SetText('Turtle WoW Loot Council2 v' .. addonVer)

            getglobal('BroadcastLoot'):Disable()
            getglobal('LootLCVoteFrameWindowDoneVoting'):Disable();

            if twlc2isRL(me) then
                getglobal('RLOptionsButton'):Show()
                getglobal('ResetClose'):Show()
                getglobal('RLExtraFrame'):Show()
                local DEButton = getglobal("MLToEnchanter")

                DEButton:SetScript("OnEnter", function(self)
                    LCTooltipVoteFrame:SetOwner(this, "ANCHOR_BOTTOMRIGHT", -100, 0);
                    if TWLC_DESENCHANTER == '' then
                        LCTooltipVoteFrame:AddLine("Enchanter not set. Type /twlc set enchanter [name]")
                    else
                        LCTooltipVoteFrame:AddLine("ML to " .. TWLC_DESENCHANTER .. " to disenchant.")
                    end
                    LCTooltipVoteFrame:Show();
                end)

                DEButton:SetScript("OnLeave", function(self)
                    LCTooltipVoteFrame:Hide();
                end)
            else
                getglobal('RLOptionsButton'):Hide()
                getglobal('ResetClose'):Hide()
                getglobal('RLExtraFrame'):Hide()
            end

            local backdrop = {
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
                tile = false,
                tileSize = 0,
                edgeSize = 1
            };
            --            getglobal('LootLCVoteFrameWindow'):SetBackdrop(backdrop);
            --            getglobal('LootLCVoteFrameWindow'):SetBackdropColor(0, 0, 0, .7);
            --            getglobal('LootLCVoteFrameWindow'):SetBackdropBorderColor(0, 0, 0, 1);

            --load consumables tooltips
            for i, consumable in pairsByKeys(LCVoteFrame.consumables) do
                if consumable.itemLink ~= '' then
                    local _, _, itemLink = string.find(consumable.itemLink, "(item:%d+:%d+:%d+:%d+)");
                    GameTooltip:SetHyperlink(itemLink)
                    GameTooltip:Hide()
                end
            end
        end
        if event == "LOOT_OPENED" then
            LCVoteFrame.LOOT_OPENED = true
            if not TWLC_ENABLED then
                return
            end
            if twlc2isRL(me) then

                local lootmethod = GetLootMethod()
                if lootmethod == 'master' then

                    local blueOrEpic = false

                    TIME_TO_NEED = SetDynTTN(GetNumLootItems())

                    for id = 0, GetNumLootItems() do
                        if GetLootSlotInfo(id) and GetLootSlotLink(id) then
                            local _, lootName = GetLootSlotInfo(id)

                            local _, _, itemLink = string.find(GetLootSlotLink(id), "(item:%d+:%d+:%d+:%d+)");
                            local _, _, quality = GetItemInfo(itemLink)
                            if quality >= 3 and lootName ~= 'Elementium Ore' and lootName ~= 'Nexus Crystal' then

                                if lootName ~= 'Alabaster Idol' and
                                        lootName ~= 'Amber Idol' and
                                        lootName ~= 'Azure Idol' and
                                        lootName ~= 'Jasper Idol' and
                                        lootName ~= 'Lambent Idol' and
                                        lootName ~= 'Obsidian Idol' and
                                        lootName ~= 'Onyx Idol' and
                                        lootName ~= 'Vermillion Idol' and
                                        -- aq40 idols
                                        lootName ~= 'Idol of Death' and
                                        lootName ~= 'Idol of Life' and
                                        lootName ~= 'Idol of Night' and
                                        lootName ~= 'Idol of Rebirth' and
                                        lootName ~= 'Idol of Strife' and
                                        lootName ~= 'Idol of War' and
                                        lootName ~= 'Idol of the Sun' and
                                        lootName ~= 'Idol of the Sage' and
                                        -- naxx wartorn pieces
                                        lootName ~= 'Wartorn Cloth Scrap' and
                                        lootName ~= 'Wartorn Leather Scrap' and
                                        lootName ~= 'Wartorn Chain Scrap' and
                                        lootName ~= 'Wartorn Plate Scrap' and
                                        -- words
                                        lootName ~= 'Word of Thawing' then

                                    blueOrEpic = true

                                end
                            end
                            --auto ML sand
                            if lootName == 'Hourglass Sand' and TWLC_AUTO_ML_SAND and TWLC_SAND_COLLECTOR ~= '' then
                                local collectorIndex = -1
                                for j = 1, 40 do
                                    if GetMasterLootCandidate(j) == TWLC_SAND_COLLECTOR then
                                        twdebug('found: sand candidate' .. GetMasterLootCandidate(j) .. ' ==  ' .. TWLC_SAND_COLLECTOR)
                                        collectorIndex = j
                                        break
                                    end
                                end
                                if collectorIndex ~= -1 then
                                    GiveMasterLoot(id, collectorIndex)
                                else
                                    twprint('Sand collector ' .. TWLC_SAND_COLLECTOR .. ' not in raid and auto ml sand is ON. Ignoring.')
                                end
                            end
                            local scarabCollector = 'Er' --fixed for now, will only work if I(Er) am leader
                            if me == scarabCollector then
                                if
                                -- keys
                                lootName == 'Greater Scarab Coffer Key' or
                                        lootName == 'Scarab Coffer Key' or
                                        -- scarabs
                                        lootName == 'Bone Scarab' or
                                        lootName == 'Bronze Scarab' or
                                        lootName == 'Clay Scarab' or
                                        lootName == 'Crystal Scarab' or
                                        lootName == 'Gold Scarab' or
                                        lootName == 'Ivory Scarab' or
                                        lootName == 'Silver Scarab' or
                                        lootName == 'Stone Scarab' or
                                        -- aq20 idols
                                        lootName == 'Alabaster Idol' or
                                        lootName == 'Amber Idol' or
                                        lootName == 'Azure Idol' or
                                        lootName == 'Jasper Idol' or
                                        lootName == 'Lambent Idol' or
                                        lootName == 'Obsidian Idol' or
                                        lootName == 'Onyx Idol' or
                                        lootName == 'Vermillion Idol' or
                                        -- aq40 idols
                                        lootName == 'Idol of Death' or
                                        lootName == 'Idol of Life' or
                                        lootName == 'Idol of Night' or
                                        lootName == 'Idol of Rebirth' or
                                        lootName == 'Idol of Strife' or
                                        lootName == 'Idol of War' or
                                        lootName == 'Idol of the Sun' or
                                        lootName == 'Idol of the Sage' or
                                        -- naxx wartorn pieces
                                        lootName == 'Wartorn Cloth Scrap' or
                                        lootName == 'Wartorn Leather Scrap' or
                                        lootName == 'Wartorn Chain Scrap' or
                                        lootName == 'Wartorn Plate Scrap' or
                                        -- words
                                        lootName == 'Word of Thawing' then

                                    local collectorIndex = -1
                                    for j = 1, 40 do
                                        if GetMasterLootCandidate(j) == scarabCollector then
                                            collectorIndex = j
                                            break
                                        end
                                    end
                                    if collectorIndex ~= -1 then
                                        GiveMasterLoot(id, collectorIndex)
                                    end
                                end
                            end
                        end
                    end

                    if not blueOrEpic then
                        return false
                    end

                    getglobal('BroadcastLoot'):Enable()
                    getglobal('BroadcastLoot'):SetText('Prepare Broadcast')
                    LCVoteFrame.sentReset = false
                    if me ~= 'Er' then
                        -- dont show for me, ill show it from erui addon
                        getglobal('LootLCVoteFrameWindow'):Show()
                    end

                    --pre send items for never seen
                    for id = 0, GetNumLootItems() do
                        if GetLootSlotInfo(id) and GetLootSlotLink(id) then
                            local lootIcon, lootName, _, _, q = GetLootSlotInfo(id)

                            local _, _, itemLink = string.find(GetLootSlotLink(id), "(item:%d+:%d+:%d+:%d+)");
                            local itemID, _, quality = GetItemInfo(itemLink)
                            if (quality >= 3) then

                                if not LCVoteFrame.itemsToPreSend[itemID] then
                                    LCVoteFrame.itemsToPreSend[itemID] = true

                                    --send to all
                                    SendAddonMessage(TWLC2c_CHANNEL, "preSend=" .. id .. "=" .. lootIcon .. "=" .. lootName .. "=" .. GetLootSlotLink(id), "RAID")
                                end
                            end
                        end
                    end

                else
                    --twprint('Looting method is not master looter. (' .. lootmethod .. ')')
                    getglobal('BroadcastLoot'):Disable()
                end
            end
        end
        if (event == "LOOT_SLOT_CLEARED") then
        end
        if (event == "LOOT_CLOSED") then
            LCVoteFrame.LOOT_OPENED = false
            getglobal('BroadcastLoot'):Disable()
        end
        if event == "PLAYER_TARGET_CHANGED" and TWLC_CONFIG['attendance'] then
            if not UnitName('target') or UnitIsPlayer('target') or not twlc2isRL(me) then
                return false
            end
            checkTargetForAttendance(UnitName('target'))
        end
    end
end)

function setCLFromUI(id, to)

    if (to) then
        addToRoster(RLWindowFrame.assistFrames[id].name)
    else
        remFromRoster(RLWindowFrame.assistFrames[id].name)
    end
end

function setAssistFromUI(id, to)
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, r = GetRaidRosterInfo(i);
            if (n == RLWindowFrame.assistFrames[id].name) then
                if (to) then
                    twdebug('promote ')
                    PromoteToAssistant(n)
                else
                    twdebug('demote ')
                    DemoteAssistant(n)
                end
                return true
            end
        end
    end
    return false
end

function toggleRLOptionsFrame()
    if getglobal('RLWindowFrame'):IsVisible() then
        getglobal('RLWindowFrame'):Hide()
    else
        if getglobal('TWLCRaiderDetailsFrame'):IsVisible() then
            RaiderDetailsClose()
        end

        local totalItems = 0

        for lootTime, item in next, TWLC_LOOT_HISTORY do
            totalItems = totalItems + 1
        end

        getglobal('RLWindowFrameSyncLootHistory'):SetText('Sync Loot History (' .. totalItems .. ' entries)')

        getglobal('RLWindowFrame'):Show()

        RLOptions_ChangeTab(1)
    end
end

function checkAssists()


    local assistsAndCL = {}
    --get assists
    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local n, r = GetRaidRosterInfo(i);
            if (r == 2 or r == 1) then
                assistsAndCL[n] = false
            end
        end
    end
    --getcls
    if TWLC_ROSTER then
        for clName in next, TWLC_ROSTER do
            assistsAndCL[clName] = false
        end
    end

    for i = 1, tableSize(RLWindowFrame.assistFrames), 1 do
        RLWindowFrame.assistFrames[i]:Hide()
    end

    local people = {}

    i = 0
    for name, cl in next, assistsAndCL do
        i = i + 1

        people[i] = {
            y = -60 - 25 * i - 10,
            color = classColors[getPlayerClass(name)].c,
            name = name,
            assist = twlc2isRLorAssist(name),
            cl = TWLC_ROSTER[name] ~= nil
        }
    end

    getglobal('RLWindowFrame'):SetHeight(110 + tableSize(people) * 25)

    for i, d in next, people do
        if not RLWindowFrame.assistFrames[i] then
            RLWindowFrame.assistFrames[i] = CreateFrame('Frame', 'AssistFrame' .. i, getglobal("RLWindowFrame"), 'CLListFrameTemplate')
        end

        RLWindowFrame.assistFrames[i]:SetPoint("TOPLEFT", getglobal("RLWindowFrame"), "TOPLEFT", 4, d.y)
        RLWindowFrame.assistFrames[i]:Show()
        RLWindowFrame.assistFrames[i].name = d.name

        getglobal('AssistFrame' .. i .. 'AName'):SetText(d.color .. d.name)
        getglobal('AssistFrame' .. i .. 'CLCheck'):Enable()
        getglobal('AssistFrame' .. i .. 'AssistCheck'):Enable()

        getglobal('AssistFrame' .. i .. 'StatusIconOnline'):Hide()
        getglobal('AssistFrame' .. i .. 'StatusIconOffline'):Show()
        getglobal('AssistFrame' .. i .. 'AssistCheck'):Disable()
        if onlineInRaid(d.name) then
            getglobal('AssistFrame' .. i .. 'StatusIconOnline'):Show()
            getglobal('AssistFrame' .. i .. 'StatusIconOffline'):Hide()
            getglobal('AssistFrame' .. i .. 'AssistCheck'):Enable()
        end

        getglobal('AssistFrame' .. i .. 'CLCheck'):SetID(i)
        getglobal('AssistFrame' .. i .. 'AssistCheck'):SetID(i)

        getglobal('AssistFrame' .. i .. 'AssistCheck'):SetChecked(d.assist)
        getglobal('AssistFrame' .. i .. 'CLCheck'):SetChecked(d.cl)

        if (d.name == me) then
            if getglobal('AssistFrame' .. i .. 'CLCheck'):GetChecked() then
                getglobal('AssistFrame' .. i .. 'CLCheck'):Disable()
            end
            getglobal('AssistFrame' .. i .. 'AssistCheck'):Disable()
        end
    end

    getglobal('RLWindowFrameBISButton'):SetChecked(TWLC_CONFIG['NeedButtons']['BIS']);
    getglobal('RLWindowFrameMSButton'):SetChecked(TWLC_CONFIG['NeedButtons']['MS']);
    getglobal('RLWindowFrameOSButton'):SetChecked(TWLC_CONFIG['NeedButtons']['OS']);
    getglobal('RLWindowFrameXMOGButton'):SetChecked(TWLC_CONFIG['NeedButtons']['XMOG']);
end

function saveNeedButton(button, value)
    TWLC_CONFIG['NeedButtons'][button] = value;
end

function sendReset()
    SendAddonMessage(TWLC2_CHANNEL, "voteframe=reset", "RAID")
    SendAddonMessage(TWLC2c_CHANNEL, "needframe=reset", "RAID")
    SendAddonMessage(TWLC2c_CHANNEL, "rollframe=reset", "RAID")
end

function sendCloseWindow()
    SendAddonMessage(TWLC2_CHANNEL, "voteframe=close", "RAID")
end

function LCVoteFrame.closeWindow()
    getglobal('LootLCVoteFrameWindow'):Hide()
    getglobal('TWLCRaiderDetailsFrame'):Hide()
end

function LCVoteFrame.showWindow()
    if not getglobal('LootLCVoteFrameWindow'):IsVisible() then
        getglobal('LootLCVoteFrameWindow'):Show()
    end
end

function ResetClose_OnClick()
    sendReset()
    sendCloseWindow()
    LCVoteFrame.sentReset = false
    if TWLC_HORDE_SATTELITE ~= '' then
        local sateliteClassColor = classColors[getPlayerClass(TWLC_HORDE_SATTELITE)].c
        getglobal("ScanHordeLoot"):SetText('Get Horde Loot (' .. sateliteClassColor .. TWLC_HORDE_SATTELITE .. FONT_COLOR_CODE_CLOSE .. ')')
    else
        getglobal("ScanHordeLoot"):SetText('- horde sattelite not set-')
    end
    getglobal('ScanHordeLoot'):Enable()
    SetLootMethod("master", me)
end

function DebugWindow_OnClick()
    if getglobal('TWLC2_DebugWindow'):IsVisible() then

        getglobal('TWLC2_DebugWindow'):Hide()
    else
        getglobal('TWLC2_DebugWindow'):Show()
    end
end

function BroadcastLoot_OnClick()

    LCVoteFrame.hordeLoot = {}

    local lootmethod = GetLootMethod()
    if lootmethod ~= 'master' then
        twprint('Looting method is not master looter. (' .. lootmethod .. ')')
        return false
    end

    local target = UnitName('target')
    if UnitIsPlayer('target') or not UnitExists('target') then
        target = 'Chest'
    end
    SendAddonMessage(TWLC2_CHANNEL, 'boss&' .. target, "RAID")

    if GetNumLootItems() == 0 then
        twprint('There are no items in the loot frame.')
        return
    end

    if not LCVoteFrame.sentReset then
        -- disable broadcast until roster is synced
        getglobal('BroadcastLoot'):Disable()
        getglobal('ScanHordeLoot'):Disable()

        SetDynTTN(GetNumLootItems(), false)
        TWLCCountDownFRAME.countDownFrom = TIME_TO_NEED
        SendAddonMessage(TWLC2_CHANNEL, 'ttn=' .. TIME_TO_NEED, "RAID")
        SetDynTTV(GetNumLootItems())
        SendAddonMessage(TWLC2_CHANNEL, 'ttv=' .. TIME_TO_VOTE, "RAID")
        SendAddonMessage(TWLC2_CHANNEL, 'ttr=' .. TIME_TO_ROLL, "RAID")

        -- send button configuration to CLs
        local buttons = ''
        if TWLC_CONFIG['NeedButtons']['BIS'] then
            buttons = buttons .. 'b'
        end
        if TWLC_CONFIG['NeedButtons']['MS'] then
            buttons = buttons .. 'm'
        end
        if TWLC_CONFIG['NeedButtons']['OS'] then
            buttons = buttons .. 'o'
        end
        if TWLC_CONFIG['NeedButtons']['XMOG'] then
            buttons = buttons .. 'x'
        end

        SendAddonMessage(TWLC2_CHANNEL, 'NeedButtons=' .. buttons, "RAID")

        sendReset()

        for id = 0, GetNumLootItems() do
            if GetLootSlotInfo(id) and GetLootSlotLink(id) then
                local lootIcon, lootName, _, _, q = GetLootSlotInfo(id)

                local _, _, itemLink = string.find(GetLootSlotLink(id), "(item:%d+:%d+:%d+:%d+)");
                local _, _, quality = GetItemInfo(itemLink)
                if (quality >= 0) then
                    --send to officers
                    ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "preloadInVoteFrame=" .. id .. "=" .. lootIcon .. "=" .. lootName .. "=" .. GetLootSlotLink(id), "RAID")
                end
            end
        end

        syncRoster()
        LCVoteFrame.sentReset = true

        getglobal('BroadcastLoot'):SetText('Broadcast Loot (' .. TIME_TO_NEED .. ')')

        return false
    end

    getglobal('BroadcastLoot'):Disable()

    -- dont show window til everyone picked
    --    SendAddonMessage(TWLC2_CHANNEL, "voteframe=show", "RAID")

    TWLCCountDownFRAME:Show()
    SendAddonMessage(TWLC2_CHANNEL, 'countdownframe=show', "RAID")

    local numLootItems = 0
    for id = 0, GetNumLootItems() do
        if GetLootSlotInfo(id) and GetLootSlotLink(id) then
            local lootIcon, lootName, _, _, q = GetLootSlotInfo(id)

            local _, _, itemLink = string.find(GetLootSlotLink(id), "(item:%d+:%d+:%d+:%d+)");
            local _, _, quality = GetItemInfo(itemLink)
            if quality >= 0 then
                local buttons = ''
                if TWLC_CONFIG['NeedButtons']['BIS'] then
                    buttons = buttons .. 'b'
                end
                if TWLC_CONFIG['NeedButtons']['MS'] then
                    buttons = buttons .. 'm'
                end
                if TWLC_CONFIG['NeedButtons']['OS'] then
                    buttons = buttons .. 'o'
                end
                if TWLC_CONFIG['NeedButtons']['XMOG'] then
                    buttons = buttons .. 'x'
                end
                --send to twneed
                ChatThrottleLib:SendAddonMessage("ALERT", TWLC2c_CHANNEL, "loot=" .. id .. "=" .. lootIcon .. "=" .. lootName .. "=" .. GetLootSlotLink(id) .. "=" .. TWLCCountDownFRAME.countDownFrom .. "=" .. buttons, "RAID")
                numLootItems = numLootItems + 1
            end
        end
    end
    ChatThrottleLib:SendAddonMessage("ALERT", TWLC2c_CHANNEL, "doneSending=" .. numLootItems .. "=items", "RAID")
    getglobal("MLToWinner"):Disable();
end

function addVotedItem(index, texture, name, link)

    LCVoteFrame.itemVotes[index] = {}

    LCVoteFrame.doneVoting[index] = false

    LCVoteFrame.selectedPlayer[index] = ''

    if (not LCVoteFrame.VotedItemsFrames[index]) then
        LCVoteFrame.VotedItemsFrames[index] = CreateFrame("Frame", "VotedItem" .. index,
                getglobal("VotedItemsFrame"), "VotedItemsFrameTemplate")
    end

    getglobal("VotedItemsFrame"):SetHeight(40 * index + 35)

    LCVoteFrame.VotedItemsFrames[index]:SetPoint("TOPLEFT", getglobal("VotedItemsFrame"), "TOPLEFT", 8, 30 - (40 * index))

    LCVoteFrame.VotedItemsFrames[index]:Show()
    LCVoteFrame.VotedItemsFrames[index].link = link
    LCVoteFrame.VotedItemsFrames[index].texture = texture
    LCVoteFrame.VotedItemsFrames[index].awardedTo = ''
    LCVoteFrame.VotedItemsFrames[index].rolled = false
    LCVoteFrame.VotedItemsFrames[index].pickedByEveryone = false

    addButtonOnEnterTooltip(getglobal('VotedItem' .. index .. 'VotedItemButton'), link)

    --    getglobal('VotedItem' .. index .. 'VotedItemButton'):Show()
    getglobal('VotedItem' .. index .. 'VotedItemButton'):SetID(index)
    getglobal('VotedItem' .. index .. 'VotedItemButton'):SetNormalTexture(texture)
    getglobal('VotedItem' .. index .. 'VotedItemButton'):SetPushedTexture(texture)
    getglobal('VotedItem' .. index .. 'VotedItemButton'):SetHighlightTexture(texture)

    getglobal('VotedItem' .. index .. 'VotedItemButtonCheck'):Hide()
    getglobal('VotedItem' .. index .. 'VotedItemButton'):SetHighlightTexture(texture)

    if (index ~= 1) then
        SetDesaturation(getglobal('VotedItem' .. index .. 'VotedItemButton'):GetNormalTexture(), 1)
    end

    if (not LCVoteFrame.CurrentVotedItem) then
        VotedItemButton_OnClick(index)
    end
end

function VotedItemButton_OnClick(id)

    getglobal('MLToWinner'):Hide()
    if (twlc2isRL(me)) then
        getglobal('MLToWinner'):Show()
    end
    if (canVote(me) and not twlc2isRL(me)) then
        getglobal('WinnerStatus'):Show()
    end

    SetDesaturation(getglobal('VotedItem' .. id .. 'VotedItemButton'):GetNormalTexture(), 0)
    for index, v in next, LCVoteFrame.VotedItemsFrames do
        if (index ~= id) then
            SetDesaturation(getglobal('VotedItem' .. index .. 'VotedItemButton'):GetNormalTexture(), 1)
        end
    end
    setCurrentVotedItem(id)
end

function DoneVoting_OnClick()
    LCVoteFrame.doneVoting[LCVoteFrame.CurrentVotedItem] = true
    getglobal('LootLCVoteFrameWindowDoneVoting'):Disable();
    getglobal('LootLCVoteFrameWindowDoneVotingCheck'):Show();
    SendAddonMessage(TWLC2_CHANNEL, "doneVoting;" .. LCVoteFrame.CurrentVotedItem, "RAID")
    VoteFrameListScroll_Update()
end

function setCurrentVotedItem(id)
    LCVoteFrame.CurrentVotedItem = id

    getglobal('LootLCVoteFrameWindowCurrentVotedItemIcon'):Show()
    getglobal('LootLCVoteFrameWindowVotedItemName'):Show()
    getglobal('LootLCVoteFrameWindowVotedItemType'):Show()

    getglobal('LootLCVoteFrameWindowCurrentVotedItemIcon'):SetNormalTexture(LCVoteFrame.VotedItemsFrames[id].texture)
    getglobal('LootLCVoteFrameWindowCurrentVotedItemIcon'):SetPushedTexture(LCVoteFrame.VotedItemsFrames[id].texture)

    local link = LCVoteFrame.VotedItemsFrames[id].link
    getglobal('LootLCVoteFrameWindowVotedItemName'):SetText(link)
    addButtonOnEnterTooltip(getglobal('LootLCVoteFrameWindowCurrentVotedItemIcon'), link)

    local _, _, itemLink = string.find(link, "(item:%d+:%d+:%d+:%d+)");
    local name, link, quality, reqlvl, t1, t2, a7, equip_slot, tex = GetItemInfo(itemLink)
    local votedItemType = ''
    --    if (t1) then votedItemType = t1 end
    if t2 then
        if not string.find(string.lower(t2), 'misc', 1, true)
                and not string.find(string.lower(t2), 'shields', 1, true) then
            votedItemType = votedItemType .. t2 .. ' '
        end
    end
    if equip_slot then
        votedItemType = votedItemType .. getEquipSlot(equip_slot)
    end

    if votedItemType == 'Cloth Cloak' then
        votedItemType = 'Cloak'
    end
    if string.find(votedItemType, 'Quest', 1, true) then
        votedItemType = trim(votedItemType) .. ' rewards:'
    end

    getglobal('CurrentVotedItemQuestReward1'):Hide()
    getglobal('CurrentVotedItemQuestReward2'):Hide()
    getglobal('CurrentVotedItemQuestReward3'):Hide()
    getglobal('CurrentVotedItemQuestReward4'):Hide()
    getglobal('CurrentVotedItemQuestReward5'):Hide()
    getglobal('CurrentVotedItemQuestReward6'):Hide()
    getglobal('CurrentVotedItemQuestReward7'):Hide()
    getglobal('CurrentVotedItemQuestReward8'):Hide()
    getglobal('CurrentVotedItemQuestReward9'):Hide()
    getglobal('CurrentVotedItemQuestReward10'):Hide()

    local reward1 = ''
    local reward2 = ''
    local reward3 = ''
    local reward4 = ''
    local reward5 = ''
    local reward6 = ''
    local reward7 = ''
    local reward8 = ''
    local reward9 = ''
    local reward10 = ''

    local showDe = true

    if votedItemType == 'Junk ' and string.find(name, 'Desecrated', 1, true) then
        votedItemType = 'Quest rewards: '
    end

    if votedItemType == 'Junk ' and string.find(name, 'Splinter', 1, true) then
        votedItemType = 'Orange'
        showDe = false
    end


    if name == 'Head of Onyxia' then
        reward1 = "\124cffa335ee\124Hitem:18406:0:0:0:0:0:0:0:0\124h[Onyxia Blood Talisman]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:18403:0:0:0:0:0:0:0:0\124h[Dragonslayer's Signet]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:18404:0:0:0:0:0:0:0:0\124h[Onyxia Tooth Pendant]\124h\124r"
        showDe = false
    end

    if name == 'Head of Nefarian' then
        reward1 = "\124cffa335ee\124Hitem:19383:0:0:0:0:0:0:0:0\124h[Master Dragonslayer\'s Medallion]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:19366:0:0:0:0:0:0:0:0\124h[Master Dragonslayer's Orb]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:19384:0:0:0:0:0:0:0:0\124h[Master Dragonslayer's Ring]\124h\124r"
        showDe = false
    end

    if name == 'Head of Ossirian the Unscarred' then
        reward1 = "\124cffa335ee\124Hitem:21504:0:0:0:0:0:0:0:0\124h[Charm of the Shifting Sands]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21507:0:0:0:0:0:0:0:0\124h[Amulet of the Shifting Sands]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21505:0:0:0:0:0:0:0:0\124h[Choker of the Shifting Sands]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21506:0:0:0:0:0:0:0:0\124h[Pendant of the Shifting Sands]\124h\124r"
        showDe = false
    end

    --AQ20 blue tokens
    if name == 'Qiraji Martial Drape' then
        -- Warrior, Rogue, Priest, Mage
        reward1 = '\124cff0070dd\124Hitem:21406:0:0:0:0:0:0:0:0\124h[Cloak of Veiled Shadows]\124h\124r'
        reward2 = '\124cff0070dd\124Hitem:21394:0:0:0:0:0:0:0:0\124h[Drape of Unyielding Strength]\124h\124r'
        reward3 = '\124cff0070dd\124Hitem:21415:0:0:0:0:0:0:0:0\124h[Drape of Vaulted Secrets]\124h\124r'
        reward4 = '\124cff0070dd\124Hitem:21412:0:0:0:0:0:0:0:0\124h[Shroud of Infinite Wisdom]\124h\124r'
        showDe = false
    end
    if name == 'Qiraji Regal Drape' then
        -- Paladin, Hunter, Shaman, Warlock, Druid
        reward1 = '\124cff0070dd\124Hitem:21397:0:0:0:0:0:0:0:0\124h[Cape of Eternal Justice]\124h\124r'
        reward2 = '\124cff0070dd\124Hitem:21409:0:0:0:0:0:0:0:0\124h[Cloak of Unending Life]\124h\124r'
        reward3 = '\124cff0070dd\124Hitem:21400:0:0:0:0:0:0:0:0\124h[Cloak of the Gathering Storm]\124h\124r'
        reward4 = '\124cff0070dd\124Hitem:21403:0:0:0:0:0:0:0:0\124h[Cloak of the Unseen Path]\124h\124r'
        reward5 = '\124cff0070dd\124Hitem:21418:0:0:0:0:0:0:0:0\124h[Shroud of Unspoken Names]\124h\124r'
        showDe = false
    end

    if name == 'Qiraji Ceremonial Ring' then
        --Hunter, Rogue, Priest, Warlock
        reward1 = '\124cff0070dd\124Hitem:21405:0:0:0:0:0:0:0:0\124h[Band of Veiled Shadows]\124h\124r'
        reward2 = '\124cff0070dd\124Hitem:21411:0:0:0:0:0:0:0:0\124h[Ring of Infinite Wisdom]\124h\124r'
        reward3 = '\124cff0070dd\124Hitem:21417:0:0:0:0:0:0:0:0\124h[Ring of Unspoken Names]\124h\124r'
        reward4 = '\124cff0070dd\124Hitem:21402:0:0:0:0:0:0:0:0\124h[Signet of the Unseen Path]\124h\124r'
        showDe = false
    end

    if name == 'Qiraji Magisterial Ring' then
        --Warrior, Paladin, Shaman, Mage, Druid
        reward1 = '\124cff0070dd\124Hitem:21408:0:0:0:0:0:0:0:0\124h[Band of Unending Life]\124h\124r'
        reward2 = '\124cff0070dd\124Hitem:21414:0:0:0:0:0:0:0:0\124h[Band of Vaulted Secrets]\124h\124r'
        reward3 = '\124cff0070dd\124Hitem:21396:0:0:0:0:0:0:0:0\124h[Ring of Eternal Justice]\124h\124r'
        reward4 = '\124cff0070dd\124Hitem:21399:0:0:0:0:0:0:0:0\124h[Ring of the Gathering Storm]\124h\124r'
        reward5 = '\124cff0070dd\124Hitem:21393:0:0:0:0:0:0:0:0\124h[Signet of Unyielding Strength]\124h\124r'
        showDe = false
    end

    -- AQ20 Epic Tokens
    if name == 'Qiraji Ornate Hilt' then
        --Priest, Mage, Warlock, Druid
        reward1 = '\124cffa335ee\124Hitem:21413:0:0:0:0:0:0:0:0\124h[Blade of Vaulted Secrets]\124h\124r'
        reward2 = '\124cffa335ee\124Hitem:21410:0:0:0:0:0:0:0:0\124h[Gavel of Infinite Wisdom]\124h\124r'
        reward3 = '\124cffa335ee\124Hitem:21416:0:0:0:0:0:0:0:0\124h[Kris of Unspoken Names]\124h\124r'
        reward4 = '\124cffa335ee\124Hitem:21407:0:0:0:0:0:0:0:0\124h[Mace of Unending Life]\124h\124r'
        showDe = false
    end

    if name == 'Qiraji Spiked Hilt' then
        --Warrior, Paladin, Hunter, Rogue, Shaman
        reward1 = '\124cffa335ee\124Hitem:21395:0:0:0:0:0:0:0:0\124h[Blade of Eternal Justice]\124h\124r'
        reward2 = '\124cffa335ee\124Hitem:21404:0:0:0:0:0:0:0:0\124h[Dagger of Veiled Shadows]\124h\124r'
        reward3 = '\124cffa335ee\124Hitem:21398:0:0:0:0:0:0:0:0\124h[Hammer of the Gathering Storm]\124h\124r'
        reward4 = '\124cffa335ee\124Hitem:21401:0:0:0:0:0:0:0:0\124h[Scythe of the Unseen Path]\124h\124r'
        reward5 = '\124cffa335ee\124Hitem:21392:0:0:0:0:0:0:0:0\124h[Sickle of Unyielding Strength]\124h\124r'
        showDe = false
    end

    -- AQ40 epic tokens
    if name == 'Imperial Qiraji Regalia' then
        reward1 = '\124cffa335ee\124Hitem:21273:0:0:0:0:0:0:0:0\124h[Blessed Qiraji Acolyte Staff]\124h\124r'
        reward2 = '\124cffa335ee\124Hitem:21275:0:0:0:0:0:0:0:0\124h[Blessed Qiraji Augur Staff]\124h\124r'
        reward3 = '\124cffa335ee\124Hitem:21268:0:0:0:0:0:0:0:0\124h[Blessed Qiraji War Hammer]\124h\124r'
        showDe = false
    end

    if name == 'Imperial Qiraji Armaments' then
        reward1 = '\124cffa335ee\124Hitem:21242:0:0:0:0:0:0:0:0\124h[Blessed Qiraji War Axe]\124h\124r'
        reward2 = '\124cffa335ee\124Hitem:21272:0:0:0:0:0:0:0:0\124h[Blessed Qiraji Musket]\124h\124r'
        reward3 = '\124cffa335ee\124Hitem:21244:0:0:0:0:0:0:0:0\124h[Blessed Qiraji Pugio]\124h\124r'
        reward4 = '\124cffa335ee\124Hitem:21269:0:0:0:0:0:0:0:0\124h[Blessed Qiraji Bulwark]\124h\124r'
        showDe = false
    end

    -- TIER 2.5
    if name == 'Qiraji Bindings of Command' then
        --Warrior, Hunter, Rogue, Priest
        reward1 = "\124cffa335ee\124Hitem:21333:0:0:0:0:0:0:0:0\124h[Conqueror's Greaves]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21330:0:0:0:0:0:0:0:0\124h[Conqueror's Spaulders]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21359:0:0:0:0:0:0:0:0\124h[Deathdealer's Boots]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21361:0:0:0:0:0:0:0:0\124h[Deathdealer's Spaulders]\124h\124r"
        reward5 = "\124cffa335ee\124Hitem:21349:0:0:0:0:0:0:0:0\124h[Footwraps of the Oracle]\124h\124r"
        reward6 = "\124cffa335ee\124Hitem:21350:0:0:0:0:0:0:0:0\124h[Mantle of the Oracle]\124h\124r"
        reward7 = "\124cffa335ee\124Hitem:21365:0:0:0:0:0:0:0:0\124h[Striker's Footguards]\124h\124r"
        reward8 = "\124cffa335ee\124Hitem:21367:0:0:0:0:0:0:0:0\124h[Striker's Pauldrons]\124h\124r"
        showDe = false
    end

    if name == 'Qiraji Bindings of Dominance' then
        --Paladin, Shaman, Mage, Warlock, Druid
        reward1 = "\124cffa335ee\124Hitem:21388:0:0:0:0:0:0:0:0\124h[Avenger's Greaves]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21391:0:0:0:0:0:0:0:0\124h[Avenger's Pauldrons]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21338:0:0:0:0:0:0:0:0\124h[Doomcaller's Footwraps]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21335:0:0:0:0:0:0:0:0\124h[Doomcaller's Mantle]\124h\124r"
        reward5 = "\124cffa335ee\124Hitem:21344:0:0:0:0:0:0:0:0\124h[Enigma Boots]\124h\124r"
        reward6 = "\124cffa335ee\124Hitem:21345:0:0:0:0:0:0:0:0\124h[Enigma Shoulderpads]\124h\124r"
        reward7 = "\124cffa335ee\124Hitem:21355:0:0:0:0:0:0:0:0\124h[Genesis Boots]\124h\124r"
        reward8 = "\124cffa335ee\124Hitem:21354:0:0:0:0:0:0:0:0\124h[Genesis Shoulderpads]\124h\124r"
        reward9 = "\124cffa335ee\124Hitem:21373:0:0:0:0:0:0:0:0\124h[Stormcaller's Footguards]\124h\124r"
        reward10 = "\124cffa335ee\124Hitem:21376:0:0:0:0:0:0:0:0\124h[Stormcaller's Pauldrons]\124h\124r"
        showDe = false
    end

    if name == "Vek'lor's Diadem" then
        --Paladin, Hunter, Rogue, Shaman, Druid
        reward1 = "\124cffa335ee\124Hitem:21387:0:0:0:0:0:0:0:0\124h[Avenger's Crown]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21360:0:0:0:0:0:0:0:0\124h[Deathdealer's Helm]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21353:0:0:0:0:0:0:0:0\124h[Genesis Helm]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21372:0:0:0:0:0:0:0:0\124h[Stormcaller's Diadem]\124h\124r"
        reward5 = "\124cffa335ee\124Hitem:21366:0:0:0:0:0:0:0:0\124h[Striker's Diadem]\124h\124r"
        showDe = false
    end

    if name == "Vek'nilash's Circlet" then
        --Warrior, Priest, Mage, Warlock
        reward1 = "\124cffa335ee\124Hitem:21329:0:0:0:0:0:0:0:0\124h[Conqueror's Crown]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21337:0:0:0:0:0:0:0:0\124h[Doomcaller's Circlet]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21347:0:0:0:0:0:0:0:0\124h[Enigma Circlet]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21348:0:0:0:0:0:0:0:0\124h[Tiara of the Oracle]\124h\124r"
        showDe = false
    end

    if name == "Ouro's Intact Hide" then
        --Warrior, Rogue, Priest, Mage
        reward1 = "\124cffa335ee\124Hitem:21332:0:0:0:0:0:0:0:0\124h[Conqueror's Legguards]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21362:0:0:0:0:0:0:0:0\124h[Deathdealer's Leggings]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21346:0:0:0:0:0:0:0:0\124h[Enigma Leggings]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21352:0:0:0:0:0:0:0:0\124h[Trousers of the Oracle]\124h\124r"
        showDe = false
    end

    if name == "Skin of the Great Sandworm" then
        --Paladin, Hunter, Shaman, Warlock, Druid
        reward1 = "\124cffa335ee\124Hitem:21390:0:0:0:0:0:0:0:0\124h[Avenger's Legguards]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21336:0:0:0:0:0:0:0:0\124h[Doomcaller's Trousers]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21356:0:0:0:0:0:0:0:0\124h[Genesis Trousers]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21375:0:0:0:0:0:0:0:0\124h[Stormcaller's Leggings]\124h\124r"
        reward5 = "\124cffa335ee\124Hitem:21368:0:0:0:0:0:0:0:0\124h[Striker's Leggings]\124h\124r"
        showDe = false
    end

    if name == "Carapace of the Old God" then
        --Warrior, Paladin, Hunter, Rogue, Shaman
        reward1 = "\124cffa335ee\124Hitem:21389:0:0:0:0:0:0:0:0\124h[Avenger's Breastplate]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21331:0:0:0:0:0:0:0:0\124h[Conqueror's Breastplate]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21364:0:0:0:0:0:0:0:0\124h[Deathdealer's Vest]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21374:0:0:0:0:0:0:0:0\124h[Stormcaller's Hauberk]\124h\124r"
        reward5 = "\124cffa335ee\124Hitem:21370:0:0:0:0:0:0:0:0\124h[Striker's Hauberk]\124h\124r"
        showDe = false
    end

    if name == "Husk of the Old God" then
        --Priest, Mage, Warlock, Druid
        reward1 = "\124cffa335ee\124Hitem:21334:0:0:0:0:0:0:0:0\124h[Doomcaller's Robes]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21343:0:0:0:0:0:0:0:0\124h[Enigma Robes]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21357:0:0:0:0:0:0:0:0\124h[Genesis Vest]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:21351:0:0:0:0:0:0:0:0\124h[Vestments of the Oracle]\124h\124r"
        showDe = false
    end

    if name == "Eye of C'Thun" then
        reward1 = "\124cffa335ee\124Hitem:21712:0:0:0:0:0:0:0:0\124h[Amulet of the Fallen God]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:21710:0:0:0:0:0:0:0:0\124h[Cloak of the Fallen God]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:21709:0:0:0:0:0:0:0:0\124h[Ring of the Fallen God]\124h\124r"
        showDe = false
    end

    --naxx tier tokens

    if name == "Desecrated Bindings" then
        reward1 = "\124cffa335ee\124Hitem:22519:0:0:0:0:0:0:0:0\124h[Bindings of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22503:0:0:0:0:0:0:0:0\124h[Frostfire Bindings]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22511:0:0:0:0:0:0:0:0\124h[Plagueheart Bindings]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Wristguards" then
        reward1 = "\124cffa335ee\124Hitem:22424:0:0:0:0:0:0:0:0\124h[Redemption Wristguards]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22443:0:0:0:0:0:0:0:0\124h[Cryptstalker Wristguards]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22471:0:0:0:0:0:0:0:0\124h[Earthshatter Wristguards]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22495:0:0:0:0:0:0:0:0\124h[Dreamwalker Wristguards]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Bracers" then
        reward1 = "\124cffa335ee\124Hitem:22423:0:0:0:0:0:0:0:0\124h[Dreadnaught Bracers]\124h\124r";
        reward2 = "\124cffa335ee\124Hitem:22483:0:0:0:0:0:0:0:0\124h[Bonescythe Bracers]\124h\124r";
        showDe = false
    end

    --belt
    if name == "Desecrated Belt" then
        reward1 = "\124cffa335ee\124Hitem:22518:0:0:0:0:0:0:0:0\124h[Belt of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22502:0:0:0:0:0:0:0:0\124h[Frostfire Belt]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22510:0:0:0:0:0:0:0:0\124h[Plagueheart Belt]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Girdle" then
        reward1 = "\124cffa335ee\124Hitem:22431:0:0:0:0:0:0:0:0\124h[Redemption Girdle]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22442:0:0:0:0:0:0:0:0\124h[Cryptstalker Girdle]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22470:0:0:0:0:0:0:0:0\124h[Earthshatter Girdle]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22494:0:0:0:0:0:0:0:0\124h[Dreamwalker Girdle]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Waistguard" then
        reward1 = "\124cffa335ee\124Hitem:22422:0:0:0:0:0:0:0:0\124h[Dreadnaught Waistguard]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22482:0:0:0:0:0:0:0:0\124h[Bonescythe Waistguard]\124h\124r"
        showDe = false
    end

    --boots
    if name == "Desecrated Sandals" then
        reward1 = "\124cffa335ee\124Hitem:22516:0:0:0:0:0:0:0:0\124h[Sandals of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22500:0:0:0:0:0:0:0:0\124h[Frostfire Sandals]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22508:0:0:0:0:0:0:0:0\124h[Plagueheart Sandals]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Boots" then
        reward1 = "\124cffa335ee\124Hitem:22430:0:0:0:0:0:0:0:0\124h[Redemption Boots]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22440:0:0:0:0:0:0:0:0\124h[Cryptstalker Boots]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22468:0:0:0:0:0:0:0:0\124h[Earthshatter Boots]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22492:0:0:0:0:0:0:0:0\124h[Dreamwalker Boots]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Sabatons" then
        reward1 = "\124cffa335ee\124Hitem:22420:0:0:0:0:0:0:0:0\124h[Dreadnaught Sabatons]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22480:0:0:0:0:0:0:0:0\124h[Bonescythe Sabatons]\124h\124r"
        showDe = false
    end

    --gloves
    if name == "Desecrated Gloves" then
        reward1 = "\124cffa335ee\124Hitem:22517:0:0:0:0:0:0:0:0\124h[Gloves of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22501:0:0:0:0:0:0:0:0\124h[Frostfire Gloves]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22509:0:0:0:0:0:0:0:0\124h[Plagueheart Gloves]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Handguards" then
        reward1 = "\124cffa335ee\124Hitem:22426:0:0:0:0:0:0:0:0\124h[Redemption Handguards]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22441:0:0:0:0:0:0:0:0\124h[Cryptstalker Handguards]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22469:0:0:0:0:0:0:0:0\124h[Earthshatter Handguards]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22493:0:0:0:0:0:0:0:0\124h[Dreamwalker Handguards]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Gauntlets" then
        reward1 = "\124cffa335ee\124Hitem:22421:0:0:0:0:0:0:0:0\124h[Dreadnaught Gauntlets]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22481:0:0:0:0:0:0:0:0\124h[Bonescythe Gauntlets]\124h\124r"
        showDe = false
    end

    --pants
    if name == "Desecrated Leggings" then
        reward1 = "\124cffa335ee\124Hitem:22513:0:0:0:0:0:0:0:0\124h[Leggings of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22497:0:0:0:0:0:0:0:0\124h[Frostfire Leggings]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22505:0:0:0:0:0:0:0:0\124h[Plagueheart Leggings]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Legguards" then
        reward1 = "\124cffa335ee\124Hitem:22427:0:0:0:0:0:0:0:0\124h[Redemption Legguards]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22437:0:0:0:0:0:0:0:0\124h[Cryptstalker Legguards]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22465:0:0:0:0:0:0:0:0\124h[Earthshatter Legguards]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22489:0:0:0:0:0:0:0:0\124h[Dreamwalker Legguards]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Legplates" then
        reward1 = "\124cffa335ee\124Hitem:22417:0:0:0:0:0:0:0:0\124h[Dreadnaught Legplates]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22477:0:0:0:0:0:0:0:0\124h[Bonescythe Legplates]\124h\124r"
        showDe = false
    end

    --head
    if name == "Desecrated Circlet" then
        reward1 = "\124cffa335ee\124Hitem:22514:0:0:0:0:0:0:0:0\124h[Circlet of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22498:0:0:0:0:0:0:0:0\124h[Frostfire Circlet]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22506:0:0:0:0:0:0:0:0\124h[Plagueheart Circlet]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Headpiece" then
        reward1 = "\124cffa335ee\124Hitem:22428:0:0:0:0:0:0:0:0\124h[Redemption Headpiece]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22438:0:0:0:0:0:0:0:0\124h[Cryptstalker Headpiece]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22466:0:0:0:0:0:0:0:0\124h[Earthshatter Headpiece]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22490:0:0:0:0:0:0:0:0\124h[Dreamwalker Headpiece]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Helmet" then
        reward1 = "\124cffa335ee\124Hitem:22418:0:0:0:0:0:0:0:0\124h[Dreadnaught Helmet]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22478:0:0:0:0:0:0:0:0\124h[Bonescythe Helmet]\124h\124r"
        showDe = false
    end

    --shoulder
    if name == "Desecrated Shoulderpads" then
        reward1 = "\124cffa335ee\124Hitem:22515:0:0:0:0:0:0:0:0\124h[Shoulderpads of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22499:0:0:0:0:0:0:0:0\124h[Frostfire Shoulderpads]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22507:0:0:0:0:0:0:0:0\124h[Plagueheart Shoulderpads]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Spaulders" then
        reward1 = "\124cffa335ee\124Hitem:22429:0:0:0:0:0:0:0:0\124h[Redemption Spaulders]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22439:0:0:0:0:0:0:0:0\124h[Cryptstalker Spaulders]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22467:0:0:0:0:0:0:0:0\124h[Earthshatter Spaulders]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22491:0:0:0:0:0:0:0:0\124h[Dreamwalker Spaulders]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Pauldrons" then
        reward1 = "\124cffa335ee\124Hitem:22419:0:0:0:0:0:0:0:0\124h[Dreadnaught Pauldrons]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22479:0:0:0:0:0:0:0:0\124h[Bonescythe Pauldrons]\124h\124r"
        showDe = false
    end

    --chest
    if name == "Desecrated Robe" then
        reward1 = "\124cffa335ee\124Hitem:22512:0:0:0:0:0:0:0:0\124h[Robe of Faith]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22496:0:0:0:0:0:0:0:0\124h[Frostfire Robe]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22504:0:0:0:0:0:0:0:0\124h[Plagueheart Robe]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Tunic" then
        reward1 = "\124cffa335ee\124Hitem:22425:0:0:0:0:0:0:0:0\124h[Redemption Tunic]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22436:0:0:0:0:0:0:0:0\124h[Cryptstalker Tunic]\124h\124r"
        reward3 = "\124cffa335ee\124Hitem:22464:0:0:0:0:0:0:0:0\124h[Earthshatter Tunic]\124h\124r"
        reward4 = "\124cffa335ee\124Hitem:22488:0:0:0:0:0:0:0:0\124h[Dreamwalker Tunic]\124h\124r"
        showDe = false
    end
    if name == "Desecrated Breastplate" then
        reward1 = "\124cffa335ee\124Hitem:22476:0:0:0:0:0:0:0:0\124h[Bonescythe Breastplate]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:22416:0:0:0:0:0:0:0:0\124h[Dreadnaught Breastplate]\124h\124r"
        showDe = false
    end
    --end naxx tier tokens

    --kt item
    if name == "The Phylactery of Kel'Thuzad" then
        reward1 = "\124cffa335ee\124Hitem:23206:0:0:0:0:0:0:0:0\124h[Mark of the Champion]\124h\124r"
        reward2 = "\124cffa335ee\124Hitem:23207:0:0:0:0:0:0:0:0\124h[Mark of the Champion]\124h\124r"
    end
    --end kt item

    if reward1 ~= '' then
        SetTokenRewardLink(reward1, 1)
    end
    if reward2 ~= '' then
        SetTokenRewardLink(reward2, 2)
    end
    if reward3 ~= '' then
        SetTokenRewardLink(reward3, 3)
    end
    if reward4 ~= '' then
        SetTokenRewardLink(reward4, 4)
    end
    if reward5 ~= '' then
        SetTokenRewardLink(reward5, 5)
    end
    if reward6 ~= '' then
        SetTokenRewardLink(reward6, 6)
    end
    if reward7 ~= '' then
        SetTokenRewardLink(reward7, 7)
    end
    if reward8 ~= '' then
        SetTokenRewardLink(reward8, 8)
    end
    if reward9 ~= '' then
        SetTokenRewardLink(reward9, 9)
    end
    if reward10 ~= '' then
        SetTokenRewardLink(reward10, 10)
    end

    getglobal('LootLCVoteFrameWindowVotedItemType'):SetText(votedItemType)

    if showDe then
        getglobal('MLToEnchanter'):Show()
    else
        getglobal('MLToEnchanter'):Hide()
    end

    VoteFrameListScroll_Update()
end

function getPlayerInfo(playerIndexOrName)
    --returns itemIndex, name, need, votes, ci1, ci2, ci3, roll, k
    if (type(playerIndexOrName) == 'string') then
        for k, player in next, LCVoteFrame.currentPlayersList do
            if player['name'] == playerIndexOrName then
                return player['itemIndex'], player['name'], player['need'], player['votes'], player['ci1'], player['ci2'], player['ci3'], player['roll'], k
            end
        end
    end
    local player = LCVoteFrame.currentPlayersList[playerIndexOrName]
    if player then
        return player['itemIndex'], player['name'], player['need'], player['votes'], player['ci1'], player['ci2'], player['ci3'], player['roll'], playerIndexOrName
    else
        return false
    end
end

function getPlayerClass(name)
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n = GetRaidRosterInfo(i);
            if (name == n) then
                local _, unitClass = UnitClass('raid' .. i) --standard
                return string.lower(unitClass)
            end
        end
    end
    return 'priest'
end

function buildContestantMenu()
    local id = ContestantDropdownMenu.currentContestantId
    local separator = {};
    separator.text = ""
    separator.disabled = true

    local title = {};
    title.text = getglobal("ContestantFrame" .. id).name .. ' ' ..
            getglobal("ContestantFrame" .. id .. "Need"):GetText()
    title.disabled = false
    title.notCheckable = true
    title.isTitle = true
    UIDropDownMenu_AddButton(title);
    UIDropDownMenu_AddButton(separator);

    local award = {};
    award.text = "Award " .. getglobal('LootLCVoteFrameWindowVotedItemName'):GetText()
    award.disabled = LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].awardedTo ~= ''
    award.isTitle = false
    award.notCheckable = true
    award.tooltipTitle = 'Award Raider'
    award.tooltipText = 'Give him them loots'
    award.justifyH = 'LEFT'
    award.func = function()
        --        awardWithConfirmation(getglobal("ContestantFrame" .. id).name)
        awardPlayer(getglobal("ContestantFrame" .. id).name, tableSize(LCVoteFrame.hordeLoot) > 0, LCVoteFrame.CurrentVotedItem)
    end
    UIDropDownMenu_AddButton(award);
    UIDropDownMenu_AddButton(separator);

    local changeToBIS = {}
    changeToBIS.text = "Change to " .. needs['bis'].c .. needs['bis'].text
    changeToBIS.disabled = getglobal("ContestantFrame" .. id).need == 'bis'
    changeToBIS.isTitle = false
    changeToBIS.notCheckable = true
    changeToBIS.tooltipTitle = 'Change choice'
    changeToBIS.tooltipText = 'Change contestant\'s choice to ' .. needs['bis'].c .. needs['bis'].text
    changeToBIS.justifyH = 'LEFT'
    changeToBIS.func = function()
        changePlayerPickTo(getglobal("ContestantFrame" .. id).name, 'bis', LCVoteFrame.CurrentVotedItem)
    end
    UIDropDownMenu_AddButton(changeToBIS);

    local changeToMS = {}
    changeToMS.text = "Change to " .. needs['ms'].c .. needs['ms'].text
    changeToMS.disabled = getglobal("ContestantFrame" .. id).need == 'ms'
    changeToMS.isTitle = false
    changeToMS.notCheckable = true
    changeToMS.tooltipTitle = 'Change choice'
    changeToMS.tooltipText = 'Change contestant\'s choice to ' .. needs['ms'].c .. needs['ms'].text
    changeToMS.justifyH = 'LEFT'
    changeToMS.func = function()
        changePlayerPickTo(getglobal("ContestantFrame" .. id).name, 'ms', LCVoteFrame.CurrentVotedItem)
    end
    UIDropDownMenu_AddButton(changeToMS);

    local changeToOS = {}
    changeToOS.text = "Change to " .. needs['os'].c .. needs['os'].text
    changeToOS.disabled = getglobal("ContestantFrame" .. id).need == 'os'
    changeToOS.isTitle = false
    changeToOS.notCheckable = true
    changeToOS.tooltipTitle = 'Change choice'
    changeToOS.tooltipText = 'Change contestant\'s choice to ' .. needs['os'].c .. needs['os'].text
    changeToOS.justifyH = 'LEFT'
    changeToOS.func = function()
        changePlayerPickTo(getglobal("ContestantFrame" .. id).name, 'os', LCVoteFrame.CurrentVotedItem)
    end
    UIDropDownMenu_AddButton(changeToOS);

    local changeToXMOG = {}
    changeToXMOG.text = "Change to " .. needs['xmog'].c .. needs['xmog'].text
    changeToXMOG.disabled = getglobal("ContestantFrame" .. id).need == 'xmog'
    changeToXMOG.isTitle = false
    changeToXMOG.notCheckable = true
    changeToXMOG.tooltipTitle = 'Change choice'
    changeToXMOG.tooltipText = 'Change contestant\'s choice to ' .. needs['xmog'].c .. needs['xmog'].text
    changeToXMOG.justifyH = 'LEFT'
    changeToXMOG.func = function()
        changePlayerPickTo(getglobal("ContestantFrame" .. id).name, 'xmog', LCVoteFrame.CurrentVotedItem)
    end
    UIDropDownMenu_AddButton(changeToXMOG);

    UIDropDownMenu_AddButton(separator);

    local close = {};
    close.text = "Close"
    close.disabled = false
    close.notCheckable = true
    close.isTitle = false
    close.func = function()
        --
    end
    UIDropDownMenu_AddButton(close);
end

function changePlayerPickTo(playerName, newPick, itemIndex)
    for pIndex, data in next, LCVoteFrame.playersWhoWantItems do
        if data['itemIndex'] == itemIndex and data['name'] == playerName then
            LCVoteFrame.playersWhoWantItems[pIndex]['need'] = newPick
            break
        end
    end
    if twlc2isRL(me) then
        SendAddonMessage(TWLC2_CHANNEL, "changePickTo@" .. playerName .. "@" .. newPick .. "@" .. itemIndex, "RAID")
    end

    VoteFrameListScroll_Update()
end

function changePlayerPickTo_OnlyLocal(playerName, newPick, itemIndex)
    for pIndex, data in next, LCVoteFrame.playersWhoWantItems do
        if data['itemIndex'] == itemIndex and data['name'] == playerName then
            LCVoteFrame.playersWhoWantItems[pIndex]['need'] = newPick
            return true
        end
    end
    return false
end

LCVoteFrame.HistoryId = 0
function ContestantClick(id)

    local playerOffset = FauxScrollFrame_GetOffset(getglobal("ContestantScrollListFrame"));
    id = id - playerOffset

    if (arg1 == 'RightButton') then
        ShowContenstantDropdownMenu(id)
        return true
    end

    if (getglobal('TWLCRaiderDetailsFrame'):IsVisible() and LCVoteFrame.selectedPlayer[LCVoteFrame.CurrentVotedItem] == getglobal("ContestantFrame" .. id).name) then
        RaiderDetailsClose()
    else
        LCVoteFrame.HistoryId = id
        local historyPlayerName = getglobal("ContestantFrame" .. id).name
        local totalItems = 0
        for lootTime, item in next, TWLC_LOOT_HISTORY do
            if historyPlayerName == item['player'] then
                totalItems = totalItems + 1
            end
        end
        getglobal('TWLCLootHistoryTitle'):SetText(totalItems .. " items looted")
        getglobal('TWLCRaiderDetailsFrameTitle'):SetText(classColors[getPlayerClass(historyPlayerName)].c .. historyPlayerName .. classColors['priest'].c .. "'s Details")
        getglobal('TWLCConsumablesTitle'):SetText('Score ' .. getConsumablesScore(historyPlayerName, true))
        RaiderDetails_ChangeTab(1);
    end
end

function LootHistory_Update()
    local itemOffset = FauxScrollFrame_GetOffset(getglobal("TWLCLootHistoryFrameScrollFrame"));

    local id = LCVoteFrame.HistoryId

    LCVoteFrame.selectedPlayer[LCVoteFrame.CurrentVotedItem] = getglobal("ContestantFrame" .. id).name

    local totalItems = 0

    local historyPlayerName = getglobal("ContestantFrame" .. id).name
    for lootTime, item in next, TWLC_LOOT_HISTORY do
        if historyPlayerName == item['player'] then
            totalItems = totalItems + 1
        end
    end

    for index in next, LCVoteFrame.lootHistoryFrames do
        LCVoteFrame.lootHistoryFrames[index]:Hide()
    end

    if totalItems > 0 then

        local index = 0
        for lootTime, item in pairsByKeysReverse(TWLC_LOOT_HISTORY) do
            if (historyPlayerName == item['player']) then

                index = index + 1

                if index > itemOffset and index <= itemOffset + 11 then

                    if not LCVoteFrame.lootHistoryFrames[index] then
                        LCVoteFrame.lootHistoryFrames[index] = CreateFrame('Frame', 'HistoryItem' .. index, getglobal("TWLCRaiderDetailsFrame"), 'HistoryItemTemplate')
                    end

                    LCVoteFrame.lootHistoryFrames[index]:SetPoint("TOPLEFT", getglobal("TWLCRaiderDetailsFrame"), "TOPLEFT", 10, -8 - 22 * (index - itemOffset) - 50)
                    LCVoteFrame.lootHistoryFrames[index]:Show()

                    local today = ''
                    if date("%d/%m") == date("%d/%m", lootTime) then
                        today = classColors['mage'].c
                    end

                    local _, _, itemLink = string.find(item['item'], "(item:%d+:%d+:%d+:%d+)");
                    local name, il, quality, _, _, _, _, _, tex = GetItemInfo(itemLink)

                    getglobal("HistoryItem" .. index .. 'Date'):SetText(classColors['rogue'].c .. today .. date("%d/%m", lootTime))
                    getglobal("HistoryItem" .. index .. 'Item'):SetNormalTexture(tex)
                    getglobal("HistoryItem" .. index .. 'Item'):SetPushedTexture(tex)
                    addButtonOnEnterTooltip(getglobal("HistoryItem" .. index .. "Item"), item['item'])
                    getglobal("HistoryItem" .. index .. 'ItemName'):SetText(item['item'])
                end
            end
        end
    end

    getglobal('TWLCRaiderDetailsFrame'):Show()

    -- ScrollFrame update
    FauxScrollFrame_Update(getglobal("TWLCLootHistoryFrameScrollFrame"), totalItems, 11, 22);
end

function ConsumablesList_Update()
    local itemOffset = FauxScrollFrame_GetOffset(getglobal("TWLCConsumablesListScrollFrame"));

    local id = LCVoteFrame.HistoryId

    LCVoteFrame.selectedPlayer[LCVoteFrame.CurrentVotedItem] = getglobal("ContestantFrame" .. id).name

    local totalItems = tableSize(LCVoteFrame.consumables)

    local consumabePlayerName = getglobal("ContestantFrame" .. id).name

    for index in next, LCVoteFrame.consumablesListFrames do
        LCVoteFrame.consumablesListFrames[index]:Hide()
    end

    local index = 0
    for i, consumable in pairsByKeys(LCVoteFrame.consumables) do

        index = index + 1

        if index > itemOffset and index <= itemOffset + 11 then

            if not LCVoteFrame.consumablesListFrames[index] then
                LCVoteFrame.consumablesListFrames[index] = CreateFrame('Frame', 'Consumable' .. index, getglobal("TWLCRaiderDetailsFrame"), 'ConsumableItemTemplate')
            end

            LCVoteFrame.consumablesListFrames[index]:SetPoint("TOPLEFT", getglobal("TWLCRaiderDetailsFrame"), "TOPLEFT", 10, -8 - 22 * (index - itemOffset) - 50)
            LCVoteFrame.consumablesListFrames[index]:Show()

            if consumable.itemLink ~= '' then

                local _, _, itemLink = string.find(consumable.itemLink, "(item:%d+:%d+:%d+:%d+)");
                local name, il, quality, _, _, _, _, _, tex = GetItemInfo(itemLink)

                local has = '|cff696969'
                for plIndex, buffs in next, LCVoteFrame.RaidBuffs do
                    if buffs.name == consumabePlayerName then
                        for j, buff in next, buffs.buffs do
                            if buff.itemName == name then
                                has = '|cffabd473'
                            end
                        end
                    end
                end

                getglobal("Consumable" .. index .. 'Score'):SetText(has .. consumable.score)
                getglobal("Consumable" .. index .. 'Item'):SetNormalTexture(tex)
                getglobal("Consumable" .. index .. 'Item'):SetPushedTexture(tex)
                if has == '|cff696969' then
                    SetDesaturation(getglobal("Consumable" .. index .. 'Item'):GetNormalTexture(), 1)
                else
                    SetDesaturation(getglobal("Consumable" .. index .. 'Item'):GetNormalTexture(), 0)
                end
                addButtonOnEnterTooltip(getglobal("Consumable" .. index .. "Item"), consumable.itemLink)
                getglobal("Consumable" .. index .. 'ItemName'):SetText(has .. name)
            else
                local has = '|cff696969'
                local tex = 'Interface\\Icons\\INV_Misc_QuestionMark'
                for plIndex, buffs in next, LCVoteFrame.RaidBuffs do
                    if buffs.name == consumabePlayerName then
                        for j, buff in next, buffs.buffs do
                            if buff.buffName == consumable.name then
                                tex = buff.buffTexture
                                has = '|cffabd473'
                            end
                        end
                    end
                end
                getglobal("Consumable" .. index .. 'Score'):SetText(has .. consumable.score)
                getglobal("Consumable" .. index .. 'Item'):SetNormalTexture(tex)
                getglobal("Consumable" .. index .. 'Item'):SetPushedTexture(tex)
                if has == '|cff696969' then
                    SetDesaturation(getglobal("Consumable" .. index .. 'Item'):GetNormalTexture(), 1)
                else
                    SetDesaturation(getglobal("Consumable" .. index .. 'Item'):GetNormalTexture(), 0)
                end

                getglobal("Consumable" .. index .. 'ItemName'):SetText(has .. consumable.name)
            end
        end
    end

    getglobal('TWLCRaiderDetailsFrame'):Show()

    -- ScrollFrame update
    FauxScrollFrame_Update(getglobal("TWLCConsumablesListScrollFrame"), totalItems, 11, 22);
end

function RaiderDetailsClose()
    if LCVoteFrame.selectedPlayer[LCVoteFrame.CurrentVotedItem] then
        LCVoteFrame.selectedPlayer[LCVoteFrame.CurrentVotedItem] = ''
    end
    getglobal('TWLCRaiderDetailsFrame'):Hide()
    VoteFrameListScroll_Update()
end

function ShowContenstantDropdownMenu(id)

    if not twlc2isRL(me) then
        return
    end

    ContestantDropdownMenu.currentContestantId = id

    UIDropDownMenu_Initialize(ContestantDropdownMenu, buildContestantMenu, "MENU");
    ToggleDropDownMenu(1, nil, ContestantDropdownMenu, "cursor", 2, 3);
end

function buildMinimapMenu()
    local separator = {};
    separator.text = ""
    separator.disabled = true

    local title = {};
    title.text = "TWLC2"
    title.disabled = false
    title.isTitle = true
    title.func = function()
        --
    end
    UIDropDownMenu_AddButton(title);
    UIDropDownMenu_AddButton(separator);

    local menu_enabled = {};
    menu_enabled.text = "Enabled"
    menu_enabled.disabled = false
    menu_enabled.isTitle = false
    menu_enabled.tooltipTitle = 'Enabled'
    menu_enabled.tooltipText = 'Use TWLC2 when you are the raid leader.'
    menu_enabled.checked = TWLC_ENABLED
    menu_enabled.justifyH = 'LEFT'
    menu_enabled.func = function()
        TWLC_ENABLED = not TWLC_ENABLED
        if (TWLC_ENABLED) then
            twprint('Addon enabled.')
        else
            twprint('Addon disabled.')
        end
    end
    UIDropDownMenu_AddButton(menu_enabled);
    UIDropDownMenu_AddButton(separator);

    local close = {};
    close.text = "Close"
    close.disabled = false
    close.isTitle = false
    close.func = function()
        --
    end
    UIDropDownMenu_AddButton(close);
end

function ShowTWLCMinimapDropdown()
    local TWLC2MinimapMenuFrame = CreateFrame('Frame', 'TWLC2MinimapMenuFrame', UIParent, 'UIDropDownMenuTemplate')
    UIDropDownMenu_Initialize(TWLC2MinimapMenuFrame, buildMinimapMenu, "MENU");
    ToggleDropDownMenu(1, nil, TWLC2MinimapMenuFrame, "cursor", 2, 3);
end

function VoteFrameListScroll_Update()

    if not LCVoteFrame.CurrentVotedItem then
        return false
    end

    refreshList()
    calculateVotes()
    updateLCVoters()
    calculateWinner()

    if (not LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem]) then
        LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem] = 0
    end
    if (not LCVoteFrame.waitResponses[LCVoteFrame.CurrentVotedItem]) then
        LCVoteFrame.waitResponses[LCVoteFrame.CurrentVotedItem] = 0
    end

    if LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem] == GetNumOnlineRaidMembers() then

        local bis, ms, os, pass, xmog = 0, 0, 0, 0, 0
        for _, pwwi in next, LCVoteFrame.playersWhoWantItems do
            if pwwi['itemIndex'] == LCVoteFrame.CurrentVotedItem then
                if pwwi['need'] == 'bis' then
                    bis = bis + 1
                end
                if pwwi['need'] == 'ms' then
                    ms = ms + 1
                end
                if pwwi['need'] == 'os' then
                    os = os + 1
                end
                if pwwi['need'] == 'xmog' then
                    xmog = xmog + 1
                end
                if pwwi['need'] == 'pass' or pwwi['need'] == 'autopass' then
                    pass = pass + 1
                end
            end
        end

        getglobal('LootLCVoteFrameWindowContestantCount'):SetText('|cff1fba1fEveryone(' .. LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem]
                .. ') has picked(' .. pass .. ' passes).')
        LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].pickedByEveryone = true
        getglobal('LootLCVoteFrameWindowTimeLeftBar'):Hide()
        -- show window when everyone picked
        --LCVoteFrame.showWindow() --moved to TWLCCountDownFRAME OnUpdate, Momo request.
    else
        getglobal('LootLCVoteFrameWindowContestantCount'):SetText('Waiting picks ' ..
                LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem] .. '/' ..
                --                LCVoteFrame.receivedResponses)
                GetNumOnlineRaidMembers())
        LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].pickedByEveryone = false
        getglobal('LootLCVoteFrameWindowTimeLeftBar'):Show()
    end

    local itemIndex, name, need, votes, ci1, ci2, ci3, roll
    local playerIndex

    -- Scrollbar stuff
    local showScrollBar = false;
    if tableSize(LCVoteFrame.currentPlayersList) > LCVoteFrame.playersPerPage then
        showScrollBar = true;
    end

    local playerOffset = FauxScrollFrame_GetOffset(getglobal("ContestantScrollListFrame"));

    --hide all 15 contestant frames
    for i = 1, 15 do
        getglobal("ContestantFrame" .. i):Hide();
    end

    for i = 1, LCVoteFrame.playersPerPage, 1 do
        playerIndex = playerOffset + i;

        if (getPlayerInfo(playerIndex)) then

            getglobal("ContestantFrame" .. i):SetID(playerIndex)
            getglobal("ContestantFrame" .. i).playerIndex = playerIndex;
            itemIndex, name, need, votes, ci1, ci2, ci3, roll = getPlayerInfo(playerIndex);
            getglobal("ContestantFrame" .. i).name = name;
            getglobal("ContestantFrame" .. i).need = need;

            local class = getPlayerClass(name)
            local color = classColors[class]
            --'enabled' --enabled, disabled, voted
            local canVote = true
            local voted = false

            getglobal("ContestantFrame" .. i .. "Name"):SetText(color.c .. name .. ' ' .. GetPlayerAttendance(name));
            getglobal("ContestantFrame" .. i .. "BS"):SetText(getConsumablesScore(name, true)); -- buffscore
            getglobal("ContestantFrame" .. i .. "Need"):SetText(needs[need].c .. needs[need].text);
            if (roll > 0) then
                getglobal("ContestantFrame" .. i .. "Roll"):SetText(roll);
            else
                getglobal("ContestantFrame" .. i .. "Roll"):SetText();
            end
            getglobal("ContestantFrame" .. i .. "RollPass"):Hide();
            if (roll == -1) then
                getglobal("ContestantFrame" .. i .. "RollPass"):Show();
                getglobal("ContestantFrame" .. i .. "Roll"):SetText(' -');
            end
            if (roll == -2) then
                getglobal("ContestantFrame" .. i .. "Roll"):SetText('...');
            end

            getglobal("ContestantFrame" .. i .. "RightClickMenuButton1"):SetID(playerIndex);
            getglobal("ContestantFrame" .. i .. "RightClickMenuButton2"):SetID(playerIndex);
            getglobal("ContestantFrame" .. i .. "RightClickMenuButton3"):SetID(playerIndex);

            getglobal("ContestantFrame" .. i .. "Votes"):SetText(votes);
            if (votes == LCVoteFrame.currentItemMaxVotes and LCVoteFrame.currentItemMaxVotes > 0) then
                getglobal("ContestantFrame" .. i .. "Votes"):SetText('|cff1fba1f' .. votes);
            end


            --enable voting if all players picked
            --            if LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem] == GetNumOnlineRaidMembers() then
            --                VoteCountdown.votingOpen = true
            --            end

            --                    not LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].pickedByEveryone or
            --                    not VoteCountdown.votingOpen or
            if LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].awardedTo ~= '' or --not awarded
                    LCVoteFrame.numPlayersThatWant == 1 or --only one player wants
                    LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].rolled or --item being rolled
                    roll ~= 0 or --waiting rolls
                    LCVoteFrame.doneVoting[LCVoteFrame.CurrentVotedItem] == true then
                --doneVoting is pressed
                canVote = false
            end

            if not VoteCountdown.votingOpen then
                canVote = false
            end

            getglobal("ContestantFrame" .. i .. "VoteButton"):SetText('VOTE')
            getglobal("ContestantFrame" .. i .. "VoteButtonCheck"):Hide()
            if LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name] then
                if LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name][me] then
                    if LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name][me] == '+' then
                        voted = true
                    end
                end
            end

            if canVote then
                getglobal("ContestantFrame" .. i .. "VoteButton"):Enable()
            else
                getglobal("ContestantFrame" .. i .. "VoteButton"):Disable()
            end
            if voted then
                getglobal("ContestantFrame" .. i .. "VoteButtonCheck"):Show()
                getglobal("ContestantFrame" .. i .. "VoteButton"):SetText('')
            else
                getglobal("ContestantFrame" .. i .. "VoteButtonCheck"):Hide()
                getglobal("ContestantFrame" .. i .. "VoteButton"):SetText('VOTE')
            end

            local lastItem = ''
            for lootTime, item in pairsByKeysReverse(TWLC_LOOT_HISTORY) do
                if item['player'] == name then
                    lastItem = item['item'] .. '(' .. date("%d/%m", lootTime) .. ')'
                    break ;
                end
            end

            if TWLC_CONFIG['attendance'] then
                local attendanceTooltipButton = getglobal("ContestantFrame" .. i .. "RightClickMenuButton1")

                attendanceTooltipButton:SetScript("OnEnter", function(self)

                    local _, vName = getPlayerInfo(this:GetID())
                    local vClass = getPlayerClass(vName)
                    local vColor = classColors[vClass].c

                    local r, g, b, a = getglobal('ContestantFrame' .. this:GetID()):GetBackdropColor()
                    getglobal('ContestantFrame' .. this:GetID()):SetBackdropColor(r, g, b, 1)

                    LCTooltipVoteFrame:SetOwner(this, "ANCHOR_BOTTOMRIGHT", -100, 0);
                    LCTooltipVoteFrame:AddLine(vColor .. vName .. FONT_COLOR_CODE_CLOSE .. "'s attendance: " .. GetPlayerAttendance(vName))
                    LCTooltipVoteFrame:AddLine('-----------------------')
                    LCTooltipVoteFrame:AddLine(GetPlayerAttendanceText(vName))
                    LCTooltipVoteFrame:AddLine('-----------------------')
                    LCTooltipVoteFrame:AddLine('Last item: ' .. lastItem)
                    LCTooltipVoteFrame:Show();
                end)

                attendanceTooltipButton:SetScript("OnLeave", function(self)
                    LCTooltipVoteFrame:Hide();
                    local r, g, b, a = getglobal('ContestantFrame' .. this:GetID()):GetBackdropColor()
                    getglobal('ContestantFrame' .. this:GetID()):SetBackdropColor(r, g, b, 0.5)
                end)
            end

            getglobal("ContestantFrame" .. i .. "RollWinner"):Hide();
            if (LCVoteFrame.currentMaxRoll[LCVoteFrame.CurrentVotedItem] == roll and roll > 0) then
                getglobal("ContestantFrame" .. i .. "RollWinner"):Show();
            end
            getglobal("ContestantFrame" .. i .. "WinnerIcon"):Hide();
            if (LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].awardedTo == name) then
                getglobal("ContestantFrame" .. i .. "WinnerIcon"):Show();
            end

            --disable for now, uses $parentCLVote1
            --            getglobal("ContestantFrame" .. i .. "CLVote"):Hide();
            --            if LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name] then
            --                for voter, vote in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name] do
            --                    if vote == '+' and class == getPlayerClass(voter) then
            --                        getglobal("ContestantFrame" .. i .. "CLVote"):Show();
            --                    end
            --                end
            --            end

            --hide all CL icons / tooltip buttons
            for w = 1, 10 do
                getglobal("ContestantFrame" .. i .. "CLVote" .. w):Hide()
                getglobal("ContestantFrame" .. i .. "CLVote" .. w .. "Tooltip"):Hide()
            end
            if LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name] then
                local w = 0;
                for voter, vote in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name] do
                    if vote == '+' then
                        w = w + 1
                        local voterClass = getPlayerClass(voter)
                        local texture = "Interface\\AddOns\\TWLC2\\classes\\" .. voterClass

                        local frameW = 0

                        if not getglobal("ContestantFrame" .. i .. "CLVote" .. w):IsVisible() then
                            getglobal("ContestantFrame" .. i .. "CLVote" .. w):SetTexture(texture)
                            getglobal("ContestantFrame" .. i .. "CLVote" .. w):Show()
                            frameW = w
                        end

                        -- add tooltips
                        local tooltipNames = {}
                        if frameW ~= 0 then
                            tooltipNames[frameW] = voter;
                            getglobal("ContestantFrame" .. i .. "CLVote" .. frameW .. "Tooltip"):Show()
                            getglobal("ContestantFrame" .. i .. "CLVote" .. frameW .. "Tooltip"):SetID(frameW)
                            local CLIconButton = getglobal("ContestantFrame" .. i .. "CLVote" .. frameW .. "Tooltip")

                            CLIconButton:SetScript("OnEnter", function(self)
                                LCTooltipVoteFrame:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4), -(this:GetHeight() / 4));
                                LCTooltipVoteFrame:AddLine(classColors[getPlayerClass(tooltipNames[this:GetID()])].c .. tooltipNames[this:GetID()])
                                LCTooltipVoteFrame:Show();
                            end)

                            CLIconButton:SetScript("OnLeave", function(self)
                                LCTooltipVoteFrame:Hide();
                            end)
                        end
                    end
                end
            end

            getglobal("ContestantFrame" .. i .. "VoteButton"):SetID(playerIndex);

            getglobal('ContestantFrame' .. i):SetBackdropColor(color.r, color.g, color.b, 0.5);
            getglobal('ContestantFrame' .. i .. 'ClassIcon'):SetTexture('Interface\\AddOns\\TWLC2\\classes\\' .. class);

            getglobal("ContestantFrame" .. i .. "VoteButton"):Show();
            if (need == 'pass' or need == 'autopass' or need == 'wait') then
                getglobal("ContestantFrame" .. i .. "VoteButton"):Hide();
            end

            if (ci1 ~= "0") then
                local _, _, itemLink = string.find(ci1, "(item:%d+:%d+:%d+:%d+)");
                local n1, link, quality, reqlvl, t1, t2, a7, equip_slot, tex = GetItemInfo(itemLink)

                if not tex then
                    tex = 'Interface\\Icons\\INV_Misc_QuestionMark'
                end

                getglobal("ContestantFrame" .. i .. "ReplacesItem1"):SetNormalTexture(tex)
                getglobal("ContestantFrame" .. i .. "ReplacesItem1"):SetPushedTexture(tex)
                addButtonOnEnterTooltip(getglobal("ContestantFrame" .. i .. "ReplacesItem1"), itemLink)
                getglobal("ContestantFrame" .. i .. "ReplacesItem1"):Show()
            else
                getglobal("ContestantFrame" .. i .. "ReplacesItem1"):Hide()
            end
            if (ci2 ~= "0") then
                local _, _, itemLink = string.find(ci2, "(item:%d+:%d+:%d+:%d+)");
                local n1, link, quality, reqlvl, t1, t2, a7, equip_slot, tex = GetItemInfo(itemLink)

                if not tex then
                    tex = 'Interface\\Icons\\INV_Misc_QuestionMark'
                end

                getglobal("ContestantFrame" .. i .. "ReplacesItem2"):SetNormalTexture(tex)
                getglobal("ContestantFrame" .. i .. "ReplacesItem2"):SetPushedTexture(tex)
                addButtonOnEnterTooltip(getglobal("ContestantFrame" .. i .. "ReplacesItem2"), itemLink)
                getglobal("ContestantFrame" .. i .. "ReplacesItem2"):Show()
            else
                getglobal("ContestantFrame" .. i .. "ReplacesItem2"):Hide()
            end
            if (ci3 ~= "0") then
                local _, _, itemLink = string.find(ci3, "(item:%d+:%d+:%d+:%d+)");
                local n1, link, quality, reqlvl, t1, t2, a7, equip_slot, tex = GetItemInfo(itemLink)

                if not tex then
                    tex = 'Interface\\Icons\\INV_Misc_QuestionMark'
                end

                getglobal("ContestantFrame" .. i .. "ReplacesItem3"):SetNormalTexture(tex)
                getglobal("ContestantFrame" .. i .. "ReplacesItem3"):SetPushedTexture(tex)
                addButtonOnEnterTooltip(getglobal("ContestantFrame" .. i .. "ReplacesItem3"), itemLink)
                getglobal("ContestantFrame" .. i .. "ReplacesItem3"):Show()
            else
                getglobal("ContestantFrame" .. i .. "ReplacesItem3"):Hide()
            end

            if (playerIndex > tableSize(LCVoteFrame.currentPlayersList)) then
                getglobal("ContestantFrame" .. i):Hide();
            else
                getglobal("ContestantFrame" .. i):Show();
            end
        end
    end

    if LCVoteFrame.doneVoting[LCVoteFrame.CurrentVotedItem] then
        getglobal('LootLCVoteFrameWindowDoneVoting'):Disable()
        getglobal('LootLCVoteFrameWindowDoneVotingCheck'):Show()
    else
        if LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem] then
            if LCVoteFrame.pickResponses[LCVoteFrame.CurrentVotedItem] > 1 then
                getglobal('LootLCVoteFrameWindowDoneVoting'):Enable()
                getglobal('LootLCVoteFrameWindowDoneVotingCheck'):Hide()
            else
                getglobal('LootLCVoteFrameWindowDoneVoting'):Disable()
                getglobal('LootLCVoteFrameWindowDoneVotingCheck'):Hide()
            end
        else
            getglobal('LootLCVoteFrameWindowDoneVoting'):Disable()
            getglobal('LootLCVoteFrameWindowDoneVotingCheck'):Hide()
        end
    end

    UpdateCLVotedButtons()

    -- ScrollFrame update
    FauxScrollFrame_Update(getglobal("ContestantScrollListFrame"), tableSize(LCVoteFrame.currentPlayersList), LCVoteFrame.playersPerPage, 20);
end

function addButtonOnEnterTooltip(frame, itemLink)

    if (string.find(itemLink, "|", 1, true)) then
        local ex = string.split(itemLink, "|")

        if not ex[2] or not ex[3] then
            twerror('bad addButtonOnEnterTooltip itemLink syntadx')
            twerror(itemLink)
            return false
        end

        frame:SetScript("OnEnter", function(self)
            LCTooltipVoteFrame:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4), -(this:GetHeight() / 4));
            LCTooltipVoteFrame:SetHyperlink(string.sub(ex[3], 2, string.len(ex[3])));
            LCTooltipVoteFrame:Show();
        end)
    else
        frame:SetScript("OnEnter", function(self)
            LCTooltipVoteFrame:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4), -(this:GetHeight() / 4));
            LCTooltipVoteFrame:SetHyperlink(itemLink);
            LCTooltipVoteFrame:Show();
        end)
    end
    frame:SetScript("OnLeave", function(self)
        LCTooltipVoteFrame:Hide();
    end)
end

function LCVoteFrame.updateVotedItemsFrames()
    for index, v in next, LCVoteFrame.VotedItemsFrames do
        getglobal('VotedItem' .. index .. 'VotedItemButtonCheck'):Hide()
        if (LCVoteFrame.VotedItemsFrames[index].awardedTo ~= '') then
            getglobal('VotedItem' .. index .. 'VotedItemButtonCheck'):Show()
        end
    end

    VoteFrameListScroll_Update()
end

function LCVoteFrame.ResetVars(show)

    TWLCCountDownFRAME:Hide()
    VoteCountdown:Hide()

    LCVoteFrame.CurrentVotedItem = nil
    LCVoteFrame.currentPlayersList = {}
    LCVoteFrame.playersWhoWantItems = {}

    LCVoteFrame.waitResponses = {}
    LCVoteFrame.pickResponses = {}
    LCVoteFrame.receivedResponses = 0

    LCVoteFrame.itemVotes = {}

    LCVoteFrame.myVotes = {}
    LCVoteFrame.LCVoters = 0

    LCVoteFrame.selectedPlayer = {}

    getglobal('LootLCVoteFrameWindowTitle'):SetText('Turtle WoW Loot Council2 v' .. addonVer)
    getglobal('LootLCVoteFrameWindowVotesLabel'):SetText('Votes');
    getglobal('LootLCVoteFrameWindowContestantCount'):SetText()

    --    getglobal('BroadcastLoot'):Disable()
    getglobal("WinnerStatus"):Hide()
    getglobal("MLToWinner"):Hide()
    getglobal("MLToWinner"):Disable()
    getglobal("MLToWinnerNrOfVotes"):SetText()
    getglobal("WinnerStatusNrOfVotes"):SetText()

    for index, frame in next, LCVoteFrame.VotedItemsFrames do
        getglobal('VotedItem' .. index):Hide()
    end

    for i = 1, LCVoteFrame.playersPerPage, 1 do
        getglobal("ContestantFrame" .. i):Hide()
    end

    TWLCCountDownFRAME.currentTime = 1
    VoteCountdown.currentTime = 1
    VoteCountdown.votingOpen = false

    getglobal('LootLCVoteFrameWindowTimeLeftBar'):SetWidth(592)

    getglobal('LootLCVoteFrameWindowCurrentVotedItemIcon'):Hide()
    getglobal('LootLCVoteFrameWindowVotedItemName'):Hide()
    getglobal('LootLCVoteFrameWindowVotedItemType'):Hide()
    getglobal('CurrentVotedItemQuestReward1'):Hide()
    getglobal('CurrentVotedItemQuestReward2'):Hide()
    getglobal('CurrentVotedItemQuestReward3'):Hide()
    getglobal('CurrentVotedItemQuestReward4'):Hide()
    getglobal('CurrentVotedItemQuestReward5'):Hide()
    getglobal('CurrentVotedItemQuestReward6'):Hide()
    getglobal('CurrentVotedItemQuestReward7'):Hide()
    getglobal('CurrentVotedItemQuestReward8'):Hide()
    getglobal('CurrentVotedItemQuestReward9'):Hide()
    getglobal('CurrentVotedItemQuestReward10'):Hide()

    getglobal('LootLCVoteFrameWindowVotedItemType'):Hide()

    LCVoteFrame.doneVoting = {}
    LCVoteFrame.clDoneVotingItem = {}
    getglobal('LootLCVoteFrameWindowDoneVoting'):Disable();
    getglobal('LootLCVoteFrameWindowDoneVotingCheck'):Hide();
    getglobal('ContestantScrollListFrame'):Hide()

    LCVoteFrame.itemsToPreSend = {}

    LCVoteFrame.debugText = ''
    getglobal('TWLC2_DebugWindowText'):SetText('')

    LCVoteFrame.numItems = 0

    getglobal('MLToEnchanter'):Hide()
end

-- comms
LCVoteFrameComms:SetScript("OnEvent", function()
    if event then
        if event == 'CHAT_MSG_ADDON' and (arg1 == TWLC2_CHANNEL or arg1 == TWLC2c_CHANNEL) then
            LCVoteFrameComms:handleSync(arg1, arg2, arg3, arg4)
        end
    end
end)

function LCVoteFrameComms:handleSync(pre, t, ch, sender)
    twdebug(sender .. ' says: ' .. t)
    if string.find(t, 'scanConsumables=now') then
        if not canVote(me) then
            return false
        end
        if not twlc2isRL(sender) then
            return false
        end
        collectRaidBuffs()
    end
    if string.find(t, 'NeedButtons=', 1, true) then
        if not canVote(me) then
            return false
        end
        if not twlc2isRL(sender) then
            return false
        end

        local buttons = string.split(t, '=')
        if not buttons[2] then
            return false
        end

        TWLC_CONFIG['NeedButtons']['BIS'] = string.find(buttons[2], 'b', 1, true) ~= nil
        TWLC_CONFIG['NeedButtons']['MS'] = string.find(buttons[2], 'm', 1, true) ~= nil
        TWLC_CONFIG['NeedButtons']['OS'] = string.find(buttons[2], 'o', 1, true) ~= nil
        TWLC_CONFIG['NeedButtons']['XMOG'] = string.find(buttons[2], 'x', 1, true) ~= nil
    end
    if string.find(t, 'boss&', 1, true) then
        if not canVote(me) then
            return false
        end
        if not twlc2isRL(sender) then
            return false
        end

        local bossName = string.split(t, '&')
        if not bossName[2] then
            return false
        end
        --
        getglobal('LootLCVoteFrameWindowTitle'):SetText('Turtle WoW Loot Council2 v' .. addonVer .. ' - ' .. bossName[2])
    end
    if string.find(t, 'giveml=', 1, true) then
        if not canVote(me) then
            return false
        end
        if not twlc2isRL(sender) then
            return false
        end

        if sender == me then
            return false
        end

        local ml = string.split(t, '=')
        if not ml[2] or not ml[3] then
            twerror('wrong giveml syntax')
            twerror(t)
            return false
        end

        awardPlayer(ml[3], false, tonumber(ml[2]))
    end
    if string.find(t, 'FromSattelite=', 1, true) then
        if not canVote(sender) then
            return false
        end
        if not twlc2isRL(me) then
            return false
        end

        local fromSattelite = string.split(t, '=')
        if not fromSattelite[2] then
            twerror('wrong FromSattelite syntax')
            twerror(t)
            return false
        end
        if fromSattelite[2] == '0' then
            --probably never the case
            twprint('No loot on Horde side')
            return false
        end

        if fromSattelite[2] == 'start' then

            LCVoteFrame.hordeLoot = {}
            SetLootMethod("master", TWLC_HORDE_SATTELITE);

        elseif fromSattelite[2] == 'end' then

            SetDynTTN(tableSize(LCVoteFrame.hordeLoot), true)
            TWLCCountDownFRAME.countDownFrom = TIME_TO_NEED
            SendAddonMessage(TWLC2_CHANNEL, 'ttn=' .. TIME_TO_NEED, "RAID")

            SetDynTTV(tableSize(LCVoteFrame.hordeLoot))
            SendAddonMessage(TWLC2_CHANNEL, 'ttv=' .. TIME_TO_VOTE, "RAID")
            SendAddonMessage(TWLC2_CHANNEL, 'ttr=' .. TIME_TO_ROLL, "RAID")

            sendReset()

            for item, data in next, LCVoteFrame.hordeLoot do
                ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "preloadInVoteFrame=" .. data['itemIndex']
                        .. "=" .. data['lootIcon'] .. "=" .. data['lootName'] .. "=" .. data['slotLink'], "RAID")
            end

            syncRoster()
            LCVoteFrame.sentReset = true
            getglobal('BroadcastLoot'):Disable()
            getglobal('ScanHordeLoot'):SetText('Broadcast H Loot (' .. TIME_TO_VOTE .. 's)')

        else
            --items
            table.insert(LCVoteFrame.hordeLoot, {
                ['itemIndex'] = tonumber(fromSattelite[2]),
                ['lootIcon'] = fromSattelite[3],
                ['lootName'] = fromSattelite[4],
                ['slotLink'] = fromSattelite[5]
            })
        end
    end
    if string.find(t, 'whatsForHorde=', 1, true) then

        if not canVote(me) then
            return false
        end

        local wfh = string.split(t, '=')
        if not wfh[2] then
            twerror('wrong whatsForHorde syntax')
            twerror(t)
            return false
        end

        if wfh[2] == 'lootWindowNotOpen' and twlc2isRL(me) then
            local sateliteClassColor = classColors[getPlayerClass(TWLC_HORDE_SATTELITE)].c
            twprint(sateliteClassColor .. TWLC_HORDE_SATTELITE .. FONT_COLOR_CODE_CLOSE .. " does not have the Loot Window Open.")
            return false
        end

        if not twlc2isRL(sender) then
            return false
        end

        if wfh[2] == me then
            if not LCVoteFrame.LOOT_OPENED then
                local leaderColor = classColors[getPlayerClass(sender)].c
                twprint('Raid leader ' .. leaderColor .. sender .. FONT_COLOR_CODE_CLOSE .. ' is requesting Horde Loot. Please open the loot window.')
                SendAddonMessage(TWLC2_CHANNEL, "whatsForHorde=lootWindowNotOpen", "RAID")
                return false
            end

            if GetNumLootItems() == 0 then
                --probably never the case
                SendAddonMessage(TWLC2_CHANNEL, 'FromSattelite=0', "RAID")
                return false
            else
                ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, 'FromSattelite=start', "RAID")
                for id = 0, GetNumLootItems() do
                    if GetLootSlotInfo(id) and GetLootSlotLink(id) then
                        local lootIcon, lootName, _, _, q = GetLootSlotInfo(id)

                        local _, _, itemLink = string.find(GetLootSlotLink(id), "(item:%d+:%d+:%d+:%d+)");
                        local _, _, quality = GetItemInfo(itemLink)
                        if (quality >= 0) then
                            --send to RL
                            ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, "FromSattelite=" .. id .. "=" .. lootIcon .. "=" .. lootName .. "=" .. GetLootSlotLink(id), "RAID")
                        end
                    end
                end
                ChatThrottleLib:SendAddonMessage("BULK", TWLC2_CHANNEL, 'FromSattelite=end', "RAID")
            end
        end
    end
    if string.find(t, 'SaveAttendance=', 1, true) and TWLC_CONFIG['attendance'] then
        if not twlc2isRL(sender) then
            return false
        end

        local att = string.split(t, '=')
        if not att[2] or not att[3] or not att[4] or not att[5] then
            twerror('wrong saveAttendance syntax')
            twerror(t)
            return false
        end
        SaveAttendanceBoss(att[2], att[3], att[4], att[5])
    end
    if string.find(t, 'doneSending=', 1, true) and canVote(me) then
        if not twlc2isRL(sender) then
            return false
        end
        local nrItems = string.split(t, '=')
        if not nrItems[2] or not nrItems[3] then
            twerror('wrong doneSending syntax')
            twerror(t)
            return false
        end
        getglobal('LootLCVoteFrameWindowContestantCount'):SetText('|cff1fba1fLoot sent. Waiting picks...')
        SendAddonMessage(TWLC2_CHANNEL, "CLreceived=" .. LCVoteFrame.numItems .. "=items", "RAID")
    end
    if string.sub(t, 1, 11) == 'CLreceived=' then
        if not twlc2isRL(me) then
            return
        end

        local nrItems = string.split(t, '=')
        if not nrItems[2] or not nrItems[3] then
            twerror('wrong CLreceived syntax')
            twerror(t)
            return false
        end

        local coloredSender = classColors[getPlayerClass(sender)].c .. sender .. classColors['priest'].c

        LCVoteFrame.debugText = LCVoteFrame.debugText .. classColors['priest'].c .. 'Officer ' .. coloredSender .. ' got ' .. nrItems[2] .. '/' .. LCVoteFrame.numItems .. ' items\n'
        getglobal('TWLC2_DebugWindowText'):SetText(LCVoteFrame.debugText)

        if tonumber(nrItems[2]) ~= LCVoteFrame.numItems then
            twerror('Officer ' .. sender .. ' got ' .. nrItems[2] .. '/' .. LCVoteFrame.numItems .. ' items.')
        end
    end
    if string.sub(t, 1, 9) == 'received=' then
        if not canVote(me) then
            return
        end

        local nrItems = string.split(t, '=')
        if not nrItems[2] or not nrItems[3] then
            twerror('wrong received syntax')
            twerror(t)
            return false
        end

        local coloredSender = classColors[getPlayerClass(sender)].c .. sender .. classColors['priest'].c

        LCVoteFrame.debugText = LCVoteFrame.debugText .. classColors['priest'].c .. 'Player ' .. coloredSender .. ' got ' .. nrItems[2] .. '/' .. LCVoteFrame.numItems .. ' items\n'
        getglobal('TWLC2_DebugWindowText'):SetText(LCVoteFrame.debugText)
        if tonumber(nrItems[2]) ~= LCVoteFrame.numItems then
            twerror('Player ' .. sender .. ' got ' .. nrItems[2] .. '/' .. LCVoteFrame.numItems .. ' items.')
        else
            LCVoteFrame.receivedResponses = LCVoteFrame.receivedResponses + 1
        end
    end
    if string.find(t, 'playerRoll:', 1, true) then

        if not twlc2isRL(sender) or sender == me then
            return
        end
        if not canVote(me) then
            return
        end

        local indexEx = string.split(t, ':')

        if not indexEx[2] or not indexEx[3] then
            twerror('bad playerRoll syntax')
            twerror(t)
            return false
        end
        if not tonumber(indexEx[3]) then
            return false
        end

        LCVoteFrame.playersWhoWantItems[tonumber(indexEx[2])]['roll'] = tonumber(indexEx[3])
        LCVoteFrame.VotedItemsFrames[tonumber(indexEx[4])].rolled = true
        VoteFrameListScroll_Update()
    end
    if string.find(t, 'changePickTo@', 1, true) then

        if not twlc2isRL(sender) or sender == me then
            return
        end
        if not canVote(me) then
            return
        end

        local pickEx = string.split(t, '@')
        if not pickEx[2] or not pickEx[3] or not pickEx[4] then
            twerror('bad changePick syntax')
            twerror(t)
            return false
        end

        if not tonumber(pickEx[4]) then
            twerror('bad changePick itemIndex')
            twerror(t)
            return false
        end

        changePlayerPickTo(pickEx[2], pickEx[3], tonumber(pickEx[4]))
    end

    if string.find(t, 'rollChoice=', 1, true) then

        if not canVote(me) then
            return
        end

        local r = string.split(t, '=')
        --r[2] = voteditem id
        --r[3] = roll
        if not r[2] or not r[3] then
            twdebug('bad rollChoice syntax')
            twdebug(t)
            return false
        end

        if (tonumber(r[3]) == -1) then

            local name = sender
            local roll = tonumber(r[3]) -- -1

            --check if name is in playersWhoWantItems with vote == -2
            for pwIndex, pwPlayer in next, LCVoteFrame.playersWhoWantItems do
                if (pwPlayer['name'] == name and pwPlayer['roll'] == -2) then
                    LCVoteFrame.playersWhoWantItems[pwIndex]['roll'] = roll
                    VoteFrameListScroll_Update()
                    break
                end
            end
        else
            twdebug('ROLLCATCHER ' .. sender .. ' rolled for ' .. r[2])
        end
    end
    if string.find(t, 'itemVote:', 1, true) then

        if not canVote(sender) or sender == me then
            return
        end
        if not canVote(me) then
            return
        end

        local itemVoteEx = string.split(t, ':')

        if not itemVoteEx[2] or not itemVoteEx[3] or not itemVoteEx[4] then
            twerror('bad itemVote syntax')
            twerror(t)
            return false
        end

        local votedItem = tonumber(itemVoteEx[2])
        local votedPlayer = itemVoteEx[3]
        local vote = itemVoteEx[4]
        if (not LCVoteFrame.itemVotes[votedItem][votedPlayer]) then
            LCVoteFrame.itemVotes[votedItem][votedPlayer] = {}
        end
        LCVoteFrame.itemVotes[votedItem][votedPlayer][sender] = vote
        VoteFrameListScroll_Update()
    end
    if string.find(t, 'doneVoting;', 1, true) then
        if not canVote(sender) or not canVote(me) then
            return
        end

        local itemEx = string.split(t, ';')
        if not itemEx[2] then
            twerror('bad doneVoting syntax')
            twerror(t)
            return false
        end

        if not tonumber(itemEx[2]) then
        end

        if not LCVoteFrame.clDoneVotingItem[sender] then
            LCVoteFrame.clDoneVotingItem[sender] = {}
        end
        LCVoteFrame.clDoneVotingItem[sender][tonumber(itemEx[2])] = true

        VoteFrameListScroll_Update()
    end
    if string.find(t, 'voteframe=', 1, true) then
        local command = string.split(t, '=')

        if not command[2] then
            twerror('bad voteframe syntax')
            twerror(t)
            return false
        end

        if (command[2] == "whoVF") then
            ChatThrottleLib:SendAddonMessage("NORMAL", TWLC2_CHANNEL, "withAddonVF=" .. sender .. "=" .. me .. "=" .. addonVer, "RAID")
            return
        end

        if not twlc2isRL(sender) then
            return
        end
        if not canVote(me) then
            return
        end

        if (command[2] == "reset") then
            LCVoteFrame.ResetVars()
        end
        if (command[2] == "close") then
            LCVoteFrame.closeWindow()
        end
        if (command[2] == "show") then
            LCVoteFrame.showWindow()
        end
    end
    if string.find(t, 'preloadInVoteFrame=', 1, true) then

        if not twlc2isRL(sender) then
            return
        end

        local item = string.split(t, "=")

        if not item[2] or not item[3] or not item[4] or not item[5] then
            twerror('bad loot syntax')
            twerror(t)
            return false
        end

        if not tonumber(item[2]) then
            twerror('bad loot index')
            twerror(t)
            return false
        end

        LCVoteFrame.numItems = LCVoteFrame.numItems + 1

        local index = tonumber(item[2])
        local texture = item[3]
        local name = item[4]
        local link = item[5]
        addVotedItem(index, texture, name, link)

        -- don't show window until everyone picked
        --        if not getglobal('LootLCVoteFrameWindow'):IsVisible() and canVote(me) then
        --            getglobal('LootLCVoteFrameWindow'):Show()
        --        end
    end
    --    if string.find(t, 'loot=', 1, true) then
    --
    --        if not twlc2isRL(sender) then return end
    --
    --        local item = string.split(t, "=")
    --
    --        if not item[2] or not item[3] or not item[4] or not item[5] then
    --            twerror('bad loot syntax')
    --            twerror(t)
    --            return false
    --        end
    --
    --        if not tonumber(item[2]) then
    --            twerror('bad loot index')
    --            twerror(t)
    --            return false
    --        end
    --
    --        LCVoteFrame.numItems = LCVoteFrame.numItems + 1
    --
    --        local index = tonumber(item[2])
    --        local texture = item[3]
    --        local name = item[4]
    --        local link = item[5]
    --        addVotedItem(index, texture, name, link)
    --    end
    if string.find(t, 'countdownframe=', 1, true) then

        if not twlc2isRL(sender) then
            return
        end
        if not canVote(me) then
            return
        end

        local action = string.split(t, "=")

        if not action[2] then
            twerror('bad countdownframe syntax')
            twerror(t)
            return false
        end

        if (action[2] == 'show') then
            TWLCCountDownFRAME:Show()
        end
    end
    if string.find(t, 'wait=', 1, true) then
        if true then
            return false
        end --ignore wait commands for now
        if not canVote(me) then
            return
        end

        local startWork = GetTime()
        local needEx = string.split(t, '=')

        -- 3rd current item
        if not needEx[5] then
            needEx[5] = '0'
        end

        if not needEx[2] or not needEx[3] or not needEx[4] then
            --add or not needEx[5] after everyone updates
            twerror('bad wait syntax')
            twerror(t)
            return false
        end

        if not tonumber(needEx[2]) then
            twerror('bad wait itemIndex')
            twerror(t)
            return false
        end

        if (tableSize(LCVoteFrame.playersWhoWantItems) ~= 0) then
            for i = 1, tableSize(LCVoteFrame.playersWhoWantItems) do
                if LCVoteFrame.playersWhoWantItems[i]['itemIndex'] == tonumber(needEx[2]) and
                        LCVoteFrame.playersWhoWantItems[i]['name'] == sender then
                    return false --exists already
                end
            end
        end

        if (LCVoteFrame.waitResponses[tonumber(needEx[2])]) then
            LCVoteFrame.waitResponses[tonumber(needEx[2])] = LCVoteFrame.waitResponses[tonumber(needEx[2])] + 1
        else
            LCVoteFrame.waitResponses[tonumber(needEx[2])] = 1
        end

        table.insert(LCVoteFrame.playersWhoWantItems, {
            ['itemIndex'] = tonumber(needEx[2]),
            ['name'] = sender,
            ['need'] = 'wait',
            ['ci1'] = needEx[3],
            ['ci2'] = needEx[4],
            ['ci3'] = needEx[5],
            ['votes'] = 0,
            ['roll'] = 0
        })

        LCVoteFrame.itemVotes[tonumber(needEx[2])] = {}
        LCVoteFrame.itemVotes[tonumber(needEx[2])][sender] = {}

        VoteFrameListScroll_Update()
    end
    --ms=1=item:123=item:323
    if string.sub(t, 1, 4) == 'bis='
            or string.sub(t, 1, 3) == 'ms='
            or string.sub(t, 1, 3) == 'os='
            or string.sub(t, 1, 5) == 'xmog='
            or string.sub(t, 1, 5) == 'pass='
            or string.sub(t, 1, 9) == 'autopass=' then

        if canVote(me) then

            local needEx = string.split(t, '=')

            if not needEx[5] then
                needEx[5] = '0'
            end

            if not needEx[2] or not needEx[3] or not needEx[4] then
                --add or not needEx[5] in the future
                twerror('bad need syntax')
                twerror(t)
                return false
            end

            if string.sub(t, 1, 9) == 'autopass=' then
                return false
            end

            --stuff for without wait=
            if (tableSize(LCVoteFrame.playersWhoWantItems) ~= 0) then
                for i = 1, tableSize(LCVoteFrame.playersWhoWantItems) do
                    if LCVoteFrame.playersWhoWantItems[i]['itemIndex'] == tonumber(needEx[2]) and
                            LCVoteFrame.playersWhoWantItems[i]['name'] == sender then
                        return false --exists already
                    end
                end
            end

            if (LCVoteFrame.waitResponses[tonumber(needEx[2])]) then
                LCVoteFrame.waitResponses[tonumber(needEx[2])] = LCVoteFrame.waitResponses[tonumber(needEx[2])] + 1
            else
                LCVoteFrame.waitResponses[tonumber(needEx[2])] = 1
            end

            table.insert(LCVoteFrame.playersWhoWantItems, {
                ['itemIndex'] = tonumber(needEx[2]),
                ['name'] = sender,
                ['need'] = 'wait',
                ['ci1'] = needEx[3],
                ['ci2'] = needEx[4],
                ['ci3'] = needEx[5],
                ['votes'] = 0,
                ['roll'] = 0
            })

            LCVoteFrame.itemVotes[tonumber(needEx[2])] = {}
            LCVoteFrame.itemVotes[tonumber(needEx[2])][sender] = {}
            --stuff for without wait= end

            if (LCVoteFrame.pickResponses[tonumber(needEx[2])]) then
                if LCVoteFrame.pickResponses[tonumber(needEx[2])] < LCVoteFrame.waitResponses[tonumber(needEx[2])] then
                    LCVoteFrame.pickResponses[tonumber(needEx[2])] = LCVoteFrame.pickResponses[tonumber(needEx[2])] + 1
                end
            else
                LCVoteFrame.pickResponses[tonumber(needEx[2])] = 1
            end

            for index, player in next, LCVoteFrame.playersWhoWantItems do
                if (player['name'] == sender and player['itemIndex'] == tonumber(needEx[2])) then
                    -- found the wait=
                    LCVoteFrame.playersWhoWantItems[index]['need'] = needEx[1]
                    LCVoteFrame.playersWhoWantItems[index]['ci1'] = needEx[3]
                    LCVoteFrame.playersWhoWantItems[index]['ci2'] = needEx[4]
                    LCVoteFrame.playersWhoWantItems[index]['ci3'] = needEx[5]
                    break
                end
            end

            -- don't show window till everyone picked
            --            getglobal('LootLCVoteFrameWindow'):Show()
            VoteFrameListScroll_Update()
        else
            getglobal('LootLCVoteFrameWindow'):Hide()
        end
    end
    -- roster sync
    if (string.find(t, 'syncRoster=', 1, true)) then
        if not twlc2isRL(sender) then
            return
        end
        if sender == me and t == 'syncRoster=end' then
            getglobal('BroadcastLoot'):Enable()
            return
        end
        if sender == me then
            return
        end

        local command = string.split(t, '=')

        if not command[2] then
            twerror('bad syncRoster syntax')
            twerror(t)
            return false
        end

        if (command[2] == "start") then
            LCVoteSyncFrame.NEW_ROSTER = {}
        elseif (command[2] == "end") then
            TWLC_ROSTER = LCVoteSyncFrame.NEW_ROSTER
            twdebug('Roster updated.')
        else
            LCVoteSyncFrame.NEW_ROSTER[command[2]] = false
        end
    end
    --code still here, but disabled in awardplayer
    if string.find(t, 'youWon=', 1, true) then
        if (not twlc2isRL(sender)) then
            return
        end
        local wonData = string.split(t, "=")
        if wonData[4] then
            LCVoteFrame.VotedItemsFrames[tonumber(wonData[4])].awardedTo = wonData[2]
            LCVoteFrame.updateVotedItemsFrames()
        end
    end
    --using playerWon instead, to let other CL know who got loot
    if string.find(t, 'playerWon#', 1, true) then
        if not canVote(sender) then
            return
        end
        local wonData = string.split(t, "#") --playerWon#unitName#link#votedItem

        if not wonData[2] or not wonData[3] or not wonData[4] then
            twerror('bad playerWon syntax')
            twerror(t)
            return false
        end

        LCVoteFrame.VotedItemsFrames[tonumber(wonData[4])].awardedTo = wonData[2]
        LCVoteFrame.updateVotedItemsFrames()
        --save loot in history
        TWLC_LOOT_HISTORY[time()] = {
            ['player'] = wonData[2],
            ['item'] = LCVoteFrame.VotedItemsFrames[tonumber(wonData[4])].link
        }
    end
    if string.sub(t, 1, 4) == 'ttn=' then
        if (not twlc2isRL(sender)) then
            return
        end

        local ttn = string.split(t, "=")

        if not ttn[2] then
            twerror('bad ttn syntax')
            twerror(t)
            return false
        end

        TIME_TO_NEED = tonumber(ttn[2]) --might be useless ?
        --        SetDynTTN(GetNumLootItems(), true)
        TWLCCountDownFRAME.countDownFrom = TIME_TO_NEED
    end
    if string.sub(t, 1, 4) == 'ttv=' then
        if (not twlc2isRL(sender)) then
            return
        end

        local ttv = string.split(t, "=")

        if not ttv[2] then
            twerror('bad ttv syntax')
            twerror(t)
            return false
        end

        TIME_TO_VOTE = tonumber(ttv[2])
        VoteCountdown.countDownFrom = TIME_TO_VOTE
    end
    if string.sub(t, 1, 4) == 'ttr=' then
        if not twlc2isRL(sender) then
            return
        end

        local ttr = string.split(t, "=")

        if not ttr[2] then
            twerror('bat ttr syntax')
            twerror(t)
            return false
        end

        TIME_TO_ROLL = tonumber(ttr[2])
    end
    if string.find(t, 'withAddonVF=', 1, true) then
        local i = string.split(t, "=")

        if not i[2] or not i[3] or not i[4] then
            twerror('bad withAddonVF syntax')
            twerror(t)
            return false
        end

        if (i[2] == me) then
            --i[2] = who requested the who
            local verColor = ""
            if (twlc_ver(i[4]) == twlc_ver(addonVer)) then
                verColor = classColors['hunter'].c
            end
            if (twlc_ver(i[4]) < twlc_ver(addonVer)) then
                verColor = '|cffff222a'
            end
            local star = ' '
            if string.len(i[4]) < 7 then
                i[4] = '0.' .. i[4]
            end
            if twlc2isRLorAssist(sender) then
                star = '*'
            end
            LCVoteFrame.peopleWithAddon = LCVoteFrame.peopleWithAddon .. star ..
                    classColors[getPlayerClass(sender)].c ..
                    sender .. ' ' .. verColor .. i[4] .. '\n'
            getglobal('VoteFrameWhoTitle'):SetText('TWLC2 With Addon')
            getglobal('VoteFrameWhoText'):SetText(LCVoteFrame.peopleWithAddon)
        end
    end
    if string.find(t, 'loot_history_sync;', 1, true) then

        if twlc2isRL(sender) and sender == me and t == 'loot_history_sync;end' then
            twprint('History Sync complete.')
            getglobal('RLWindowFrameSyncLootHistory'):Enable()
        end

        if not twlc2isRL(sender) or sender == me then
            return
        end
        local lh = string.split(t, ";")

        if not lh[2] or not lh[3] or not lh[4] then
            if t ~= 'loot_history_sync;start' and t ~= 'loot_history_sync;end' then
                twerror('bad loot_history_sync syntax')
                twerror(t)
                return false
            end
        end

        if lh[2] == 'start' then
            --TWLC_LOOT_HISTORY = {}
        elseif lh[2] == 'end' then
            twdebug('loot history synced.')
        else
            TWLC_LOOT_HISTORY[tonumber(lh[2])] = {
                ["player"] = lh[3],
                ["item"] = lh[4],
            }
        end
    end
end

function refreshList()
    --getto ordering
    local tempTable = LCVoteFrame.playersWhoWantItems
    LCVoteFrame.playersWhoWantItems = {}
    local j = 0
    for index, d in next, tempTable do
        if d['need'] == 'bis' then
            j = j + 1
            LCVoteFrame.playersWhoWantItems[j] = d
        end
    end
    for index, d in next, tempTable do
        if d['need'] == 'ms' then
            j = j + 1
            LCVoteFrame.playersWhoWantItems[j] = d
        end
    end
    for index, d in next, tempTable do
        if d['need'] == 'os' then
            j = j + 1
            LCVoteFrame.playersWhoWantItems[j] = d
        end
    end
    for index, d in next, tempTable do
        if d['need'] == 'xmog' then
            j = j + 1
            LCVoteFrame.playersWhoWantItems[j] = d
        end
    end
    for index, d in next, tempTable do
        if d['need'] == 'pass' then
            j = j + 1
            LCVoteFrame.playersWhoWantItems[j] = d
        end
    end
    for index, d in next, tempTable do
        if d['need'] == 'autopass' then
            j = j + 1
            LCVoteFrame.playersWhoWantItems[j] = d
        end
    end
    for index, d in next, tempTable do
        if d['need'] == 'wait' then
            j = j + 1
            LCVoteFrame.playersWhoWantItems[j] = d
        end
    end
    -- sort
    LCVoteFrame.currentPlayersList = {}
    for i = 1, LCVoteFrame.playersPerPage, 1 do
        getglobal('ContestantFrame' .. i):Hide();
    end
    for pIndex, data in next, LCVoteFrame.playersWhoWantItems do
        if data['itemIndex'] == LCVoteFrame.CurrentVotedItem then
            table.insert(LCVoteFrame.currentPlayersList, LCVoteFrame.playersWhoWantItems[pIndex])
            --            LCVoteFrame.currentPlayersList[table.getn(LCVoteFrame.currentPlayersList) + 1] = LCVoteFrame.playersWhoWantItems[pIndex]
        end
    end
end

function VoteButton_OnClick(id)
    local itemIndex, name = getPlayerInfo(id)

    if not LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name] then
        LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name] = {
            [me] = '+'
        }
        SendAddonMessage(TWLC2_CHANNEL, "itemVote:" .. LCVoteFrame.CurrentVotedItem .. ":" .. name .. ":+", "RAID")
    else
        if LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name][me] == '+' then
            LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name][me] = '-'
            SendAddonMessage(TWLC2_CHANNEL, "itemVote:" .. LCVoteFrame.CurrentVotedItem .. ":" .. name .. ":-", "RAID")
        else
            LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][name][me] = '+'
            SendAddonMessage(TWLC2_CHANNEL, "itemVote:" .. LCVoteFrame.CurrentVotedItem .. ":" .. name .. ":+", "RAID")
        end
    end

    VoteFrameListScroll_Update()
end

function calculateVotes()

    --init votes to 0
    for pIndex in next, LCVoteFrame.currentPlayersList do
        LCVoteFrame.currentPlayersList[pIndex].votes = 0
    end

    if LCVoteFrame.CurrentVotedItem ~= nil then
        for n, d in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem] do

            if getPlayerInfo(n) then
                local _, _, _, _, _, _, _, _, pIndex = getPlayerInfo(n)
                for voter, vote in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][n] do
                    if vote == '+' then
                        LCVoteFrame.currentPlayersList[pIndex].votes = LCVoteFrame.currentPlayersList[pIndex].votes + 1
                    end
                end
            else
                twerror('getPlayerInfo(' .. n .. ') Not Found. Please report this.')
            end
        end
    end
end

function calculateWinner()

    if not LCVoteFrame.CurrentVotedItem then
        return false
    end

    -- calc roll winner(s)
    LCVoteFrame.currentRollWinner = ''
    LCVoteFrame.currentMaxRoll[LCVoteFrame.CurrentVotedItem] = 0
    --    twdebug('calculare maxroll')
    for i, d in next, LCVoteFrame.currentPlayersList do
        if d['itemIndex'] == LCVoteFrame.CurrentVotedItem and d['roll'] > 0 and d['roll'] > LCVoteFrame.currentMaxRoll[LCVoteFrame.CurrentVotedItem] then
            LCVoteFrame.currentMaxRoll[LCVoteFrame.CurrentVotedItem] = d['roll']
            LCVoteFrame.currentRollWinner = d['name']
        end
    end
    --    twdebug('maxroll = ' .. LCVoteFrame.currentMaxRoll[LCVoteFrame.CurrentVotedItem])

    if (LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].awardedTo ~= '') then
        getglobal("MLToWinner"):Disable();
        local color = classColors[getPlayerClass(LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].awardedTo)]
        getglobal("MLToWinner"):SetText('Awarded to ' .. color.c .. LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].awardedTo);
        getglobal("WinnerStatus"):SetText('Awarded to ' .. color.c .. LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].awardedTo);
        return
    end

    -- roll tie detection
    local rollTie = 0
    for i, d in next, LCVoteFrame.currentPlayersList do
        if d['itemIndex'] == LCVoteFrame.CurrentVotedItem and d['roll'] > 0 and d['roll'] == LCVoteFrame.currentMaxRoll[LCVoteFrame.CurrentVotedItem] then
            rollTie = rollTie + 1
        end
    end

    if (rollTie ~= 0) then
        if (rollTie == 1) then
            getglobal("MLToWinner"):Enable();
            local color = classColors[getPlayerClass(LCVoteFrame.currentRollWinner)]
            getglobal("MLToWinner"):SetText('Award ' .. color.c .. LCVoteFrame.currentRollWinner);
            getglobal("WinnerStatus"):SetText('Winner: ' .. color.c .. LCVoteFrame.currentRollWinner);
            --            twdebug('set text to award x')
            LCVoteFrame.currentItemWinner = LCVoteFrame.currentRollWinner
            LCVoteFrame.voteTiePlayers = ''
        else
            getglobal("MLToWinner"):Enable();
            getglobal("MLToWinner"):SetText('ROLL VOTE TIE'); -- .. voteTies
            getglobal("WinnerStatus"):SetText('VOTE TIE'); -- .. voteTies
        end
        return
    else

        -- calc vote winner
        LCVoteFrame.currentItemWinner = ''
        LCVoteFrame.currentItemMaxVotes = 0
        LCVoteFrame.voteTiePlayers = '';
        LCVoteFrame.numPlayersThatWant = 0
        LCVoteFrame.namePlayersThatWants = ''
        for i, d in next, LCVoteFrame.currentPlayersList do
            if d['itemIndex'] == LCVoteFrame.CurrentVotedItem then

                -- calc winner if only one exists with bis, ms, os, xmog
                if d['need'] == 'bis' or d['need'] == 'ms' or d['need'] == 'os' or d['need'] == 'xmog' then
                    LCVoteFrame.numPlayersThatWant = LCVoteFrame.numPlayersThatWant + 1
                    LCVoteFrame.namePlayersThatWants = d['name']
                end

                if (d['votes'] > 0 and d['votes'] > LCVoteFrame.currentItemMaxVotes) then
                    LCVoteFrame.currentItemMaxVotes = d['votes']
                    LCVoteFrame.currentItemWinner = d['name']
                end
            end
        end

        if (LCVoteFrame.numPlayersThatWant == 1) then
            LCVoteFrame.currentItemWinner = LCVoteFrame.namePlayersThatWants
            getglobal("MLToWinner"):Enable();
            local color = classColors[getPlayerClass(LCVoteFrame.currentItemWinner)]
            getglobal("MLToWinner"):SetText('Award single picker ' .. color.c .. LCVoteFrame.currentItemWinner);
            getglobal("WinnerStatus"):SetText('Single picker ' .. color.c .. LCVoteFrame.currentItemWinner);
            return
        end

        --    twdebug('maxVotes = ' .. maxVotes)
        --tie check
        local ties = 0
        for i, d in next, LCVoteFrame.currentPlayersList do
            if d['itemIndex'] == LCVoteFrame.CurrentVotedItem then
                if (d['votes'] == LCVoteFrame.currentItemMaxVotes and LCVoteFrame.currentItemMaxVotes > 0) then
                    LCVoteFrame.voteTiePlayers = LCVoteFrame.voteTiePlayers .. d['name'] .. ' '
                    ties = ties + 1
                end
            end
        end
        LCVoteFrame.voteTiePlayers = trim(LCVoteFrame.voteTiePlayers)

        if (ties > 1) then
            getglobal("MLToWinner"):Enable();
            getglobal("MLToWinner"):SetText('ROLL VOTE TIE'); -- .. voteTies
            getglobal("WinnerStatus"):SetText('VOTE TIE'); -- .. voteTies
        else
            --no tie
            LCVoteFrame.voteTiePlayers = ''
            if (LCVoteFrame.currentItemWinner ~= '') then
                --                if not VoteCountdown.votingOpen then
                getglobal("MLToWinner"):Enable();
                --                end
                local color = classColors[getPlayerClass(LCVoteFrame.currentItemWinner)]
                getglobal("MLToWinner"):SetText('Award ' .. color.c .. LCVoteFrame.currentItemWinner);
                getglobal("WinnerStatus"):SetText('Winner: ' .. color.c .. LCVoteFrame.currentItemWinner);
            else
                getglobal("MLToWinner"):Disable()
                getglobal("MLToWinner"):SetText('Waiting votes...')
                getglobal("WinnerStatus"):SetText('Waiting votes...')
            end
        end
    end
end

function updateLCVoters()

    if not LCVoteFrame.CurrentVotedItem then
        return false
    end

    local nr = 0
    -- reset OV
    for officer, voted in next, TWLC_ROSTER do
        TWLC_ROSTER[officer] = false
    end
    for n, d in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem] do
        for voter, vote in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][n] do
            for officer, voted in next, TWLC_ROSTER do
                if voter == officer and vote == '+' then
                    TWLC_ROSTER[officer] = true
                    --                    UpdateCLVotedButtons(officer, '+')
                end
            end
        end
    end
    for o, v in next, TWLC_ROSTER do
        if v then
            nr = nr + 1
        end
    end

    for officer, voted in next, TWLC_ROSTER do
        if not voted then
            --check if he clicked done voting for this itme
            if LCVoteFrame.clDoneVotingItem[officer] then
                for itemIndex, doneVoting in next, LCVoteFrame.clDoneVotingItem[officer] do
                    if itemIndex == LCVoteFrame.CurrentVotedItem and doneVoting then
                        nr = nr + 1
                    end
                end
            end
        end
    end

    local numOfficersInRaid = 0
    for o, v in next, TWLC_ROSTER do
        if onlineInRaid(o) then
            numOfficersInRaid = numOfficersInRaid + 1
        end
    end

    if nr == numOfficersInRaid then
        getglobal('MLToWinnerNrOfVotes'):SetText('|cff1fba1fEveryone voted!')
        getglobal('WinnerStatusNrOfVotes'):SetText('|cff1fba1fEveryone voted!')
        getglobal('MLToWinner'):Enable()
        getglobal('LootLCVoteFrameWindowVotesLabel'):SetText('Votes |cff1fba1f' .. nr .. '/' .. numOfficersInRaid);
    elseif nr >= math.floor(numOfficersInRaid / 2) then
        getglobal('LootLCVoteFrameWindowVotesLabel'):SetText('Votes |cfffff569' .. nr .. '/' .. numOfficersInRaid);
    else
        getglobal('MLToWinnerNrOfVotes'):SetText('|cffa53737' .. nr .. '/' .. numOfficersInRaid .. ' votes')
        getglobal('WinnerStatusNrOfVotes'):SetText('|cffa53737' .. nr .. '/' .. numOfficersInRaid .. ' votes')
        getglobal('LootLCVoteFrameWindowVotesLabel'):SetText('Votes |cffa53737' .. nr .. '/' .. numOfficersInRaid);
    end
end

function MLToWinner_OnClick()
    --    twdebug(LCVoteFrame.voteTiePlayers)
    if (LCVoteFrame.voteTiePlayers ~= '') then
        LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].rolled = true
        local players = string.split(LCVoteFrame.voteTiePlayers, ' ')
        for i, d in next, LCVoteFrame.currentPlayersList do
            for pIndex, tieName in next, players do
                if d['itemIndex'] == LCVoteFrame.CurrentVotedItem and d['name'] == tieName then

                    local linkString = LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].link
                    local _, _, itemLink = string.find(linkString, "(item:%d+:%d+:%d+:%d+)");
                    local name, il, quality, _, _, _, _, _, tex = GetItemInfo(itemLink)

                    local roll = math.random(1, 100)
                    for pwIndex, pwPlayer in next, LCVoteFrame.playersWhoWantItems do
                        if (pwPlayer['name'] == tieName and pwPlayer['itemIndex'] == LCVoteFrame.CurrentVotedItem) then
                            -- found the wait=
                            LCVoteFrame.playersWhoWantItems[pwIndex]['roll'] = -2 --roll
                            --send to officers
                            SendAddonMessage(TWLC2_CHANNEL, "playerRoll:" .. pwIndex .. ":-2:" .. LCVoteFrame.CurrentVotedItem, "RAID")
                            --send to raiders
                            SendAddonMessage(TWLC2c_CHANNEL, 'rollFor=' .. LCVoteFrame.CurrentVotedItem .. '=' .. tex .. '=' .. name .. '=' .. linkString .. '=' .. TIME_TO_ROLL .. '=' .. tieName, "RAID")
                            break
                        end
                    end
                end
            end
        end
        getglobal("MLToWinner"):Disable();
        VoteFrameListScroll_Update()
    else
        awardPlayer(LCVoteFrame.currentItemWinner, tableSize(LCVoteFrame.hordeLoot) > 0, LCVoteFrame.CurrentVotedItem)
    end
end

function MLToDesenchanter()
    if TWLC_DESENCHANTER == '' then
        twprint('Desenchanter not set. Uset /twlc set enchanter/disenchanter [name] to set it.')
        return false;
    end

    local foundInRaid = false

    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local n, _, _, _, _, _, z = GetRaidRosterInfo(i);
            if n == TWLC_DESENCHANTER then
                foundInRaid = true
            end
        end
    end
    if not foundInRaid then
        twprint('Desenchanter ' .. TWLC_DESENCHANTER .. ' is not in raid. Use /twlc set enchanter/disenchanter [name] to set a different one.')
        return false;
    end
    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local n, _, _, _, _, _, z = GetRaidRosterInfo(i);
            if n == TWLC_DESENCHANTER and z == 'Offline' then
                twprint('Desenchanter ' .. TWLC_DESENCHANTER .. ' is offline. Use /twlc set enchanter/disenchanter [name] to set a different one.')
                return false;
            end
        end
    end
    awardPlayer(TWLC_DESENCHANTER, tableSize(LCVoteFrame.hordeLoot) > 0, LCVoteFrame.CurrentVotedItem, true)
end

function Contestant_OnEnter(id)
    local playerOffset = FauxScrollFrame_GetOffset(getglobal("ContestantScrollListFrame"));
    id = id - playerOffset
    local r, g, b, a = getglobal('ContestantFrame' .. id):GetBackdropColor()
    getglobal('ContestantFrame' .. id):SetBackdropColor(r, g, b, 1)
end

function Contestant_OnLeave()
    for i = 1, LCVoteFrame.playersPerPage do
        local r, g, b, a = getglobal('ContestantFrame' .. i):GetBackdropColor()
        if (LCVoteFrame.selectedPlayer[LCVoteFrame.CurrentVotedItem] ~= getglobal('ContestantFrame' .. i).name) then
            getglobal('ContestantFrame' .. i):SetBackdropColor(r, g, b, 0.5)
        end
    end
end

function twlc2isCL(name)
    return TWLC_ROSTER[name] ~= nil
end

function twlc2isRL(name)
    if not UnitInRaid('player') then
        return false
    end
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, r = GetRaidRosterInfo(i);
            if n == name and r == 2 then
                return true
            end
        end
    end
    return false
end

function GetNumOnlineRaidMembers()
    local num = 0
    if not UnitInRaid('player') then
        return num
    end
    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local _, _, _, _, _, _, z = GetRaidRosterInfo(i);
            if z ~= 'Offline' then
                num = num + 1
            end
        end
    end
    return num
end

function twlc2isAssist(name)
    if not UnitInRaid('player') then
        return false
    end
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, r = GetRaidRosterInfo(i);
            if (n == name and r == 1) then
                return true
            end
        end
    end
    return false
end

function twlc2isRLorAssist(name)
    return twlc2isAssist(name) or twlc2isRL(name)
end

function canVote(name)
    --assist and in CL/LC
    if (not twlc2isRLorAssist(name)) then
        return false
    end
    if (not twlc2isCL(name)) then
        return false
    end
    return true
end

function onlineInRaid(name)
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, _, _, _, _, _, z = GetRaidRosterInfo(i);
            if n == name and z ~= 'Offline' then
                return true
            end
        end
    end
    return false
end

function trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end

function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, function(a, b)
        return a < b
    end)
    local i = 0 -- iterator variable
    local iter = function()
        -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

function pairsByKeysReverse(t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, function(a, b)
        return a > b
    end)
    local i = 0 -- iterator variable
    local iter = function()
        -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

function awardWithConfirmation(playerName)

    local color = classColors[getPlayerClass(playerName)]

    local dialog = StaticPopup_Show("TWLC_CONFIRM_LOOT_DISTRIBUTION",
            LCVoteFrame.VotedItemsFrames[LCVoteFrame.CurrentVotedItem].link,
            color.c .. playerName .. FONT_COLOR_CODE_CLOSE)
    if (dialog) then
        dialog.data = playerName
    end
end

function awardPlayer(playerName, sendToSattelite, cvi, disenchant)

    if not playerName or playerName == '' then
        twerror('AwardPlayer: playerName is nil.')
        return false
    end

    if sendToSattelite then
        SendAddonMessage(TWLC2c_CHANNEL, 'giveml=' .. cvi .. '=' .. playerName, "RAID")
        return true
    end

    local unitIndex = 0

    for i = 1, 40 do
        if GetMasterLootCandidate(i) == playerName then
            twdebug('found: loot candidate' .. GetMasterLootCandidate(i) .. ' ==  arg1:' .. playerName)
            unitIndex = i
            break
        end
    end

    if (unitIndex == 0) then
        twprint("Something went wrong, " .. playerName .. " is not on loot list.")
    else
        local link = LCVoteFrame.VotedItemsFrames[cvi].link
        local itemIndex = cvi

        twdebug('ML item should be ' .. link)
        local foundItemIndexInLootFrame = false
        for id = 0, GetNumLootItems() do
            if GetLootSlotInfo(id) and GetLootSlotLink(id) then
                if link == GetLootSlotLink(id) then
                    foundItemIndexInLootFrame = true
                    itemIndex = id
                end
            end
        end

        if foundItemIndexInLootFrame then

            local itemIndex, name, need, votes, ci1, ci2, ci3, roll = getPlayerInfo(GetMasterLootCandidate(unitIndex));

            SendAddonMessage(TWLC2_CHANNEL, "playerWon#" .. GetMasterLootCandidate(unitIndex) .. "#" .. link .. "#" .. cvi .. "#" .. need, "RAID")

            GiveMasterLoot(itemIndex, unitIndex);

            Screenshot()

            if disenchant then
                SendChatMessage(GetMasterLootCandidate(unitIndex) .. ' was awarded with ' .. link .. ' for Dissenchant!', "RAID")
            else
                SendChatMessage(GetMasterLootCandidate(unitIndex) .. ' was awarded with ' .. link .. ' for ' .. needs[need].text .. '!', "RAID")
            end

            LCVoteFrame.VotedItemsFrames[cvi].awardedTo = playerName
            LCVoteFrame.updateVotedItemsFrames()

        else
            twerror('Item not found. Is the loot window opened ?')
        end
    end
end

--horde loot
function ScanHordeLoot_OnClick()

    if TWLC_HORDE_SATTELITE == '' then
        twprint('Horde Sattelite not set. Use /twlc set sattelite [name]');
        return false
    end

    local satteliteInRaid = false

    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, _, _, _, _, _, z = GetRaidRosterInfo(i);
            if n == TWLC_HORDE_SATTELITE and z == 'Offline' then
                twprint('Horde Sattelite ' .. TWLC_HORDE_SATTELITE .. ' is offline. Use /twlc set sattelite [name] to change it.');
                return false
            end
            if n == TWLC_HORDE_SATTELITE then
                satteliteInRaid = true
            end
        end
    end

    if not satteliteInRaid then
        twprint('Horde Sattelite ' .. TWLC_HORDE_SATTELITE .. ' is not in raid. Use /twlc set sattelite [name] to change it.');
        return false
    end

    getglobal('BroadcastLoot'):Disable()
    if not LCVoteFrame.sentReset then
        twdebug('sent reset = false')
        SendAddonMessage(TWLC2_CHANNEL, 'whatsForHorde=' .. TWLC_HORDE_SATTELITE, "RAID")
    else

        -- dont show window til everyone picked
        --        SendAddonMessage(TWLC2_CHANNEL, "voteframe=show", "RAID")

        TWLCCountDownFRAME:Show()
        SendAddonMessage(TWLC2_CHANNEL, 'countdownframe=show', "RAID")

        local numLootItems = 0
        for item, data in next, LCVoteFrame.hordeLoot do
            ChatThrottleLib:SendAddonMessage("ALERT", TWLC2c_CHANNEL, "loot=" .. data['itemIndex']
                    .. "=" .. data['lootIcon'] .. "=" .. data['lootName']
                    .. "=" .. data['slotLink'] .. "=" .. TWLCCountDownFRAME.countDownFrom, "RAID")
            numLootItems = numLootItems + 1
        end
        ChatThrottleLib:SendAddonMessage("ALERT", TWLC2c_CHANNEL, "doneSending=" .. numLootItems .. "=items", "RAID")
        getglobal("MLToWinner"):Disable()
    end
end

--horde loot

function closeAttendanceSaveWindow()
    getglobal('SaveAttendanceDialog'):Hide()
end

function openAttendanceSaveWindow()
    getglobal('SaveAttendanceDialog'):Show()
end

function checkTargetForAttendance(tar)
    for z, bosses in next, attendanceTargets do
        if GetZoneText() == z then
            for bkey, boss in next, bosses do
                if tar == bkey then

                    local lastSave = '-not available-'
                    if TWLC_ATTENDANCE[z] then
                        for raidDate, raidBosses in pairsByKeysReverse(TWLC_ATTENDANCE[z]) do
                            for raidBoss, hours in pairsByKeysReverse(raidBosses) do
                                if raidBoss == boss then
                                    for hour in pairsByKeysReverse(hours) do
                                        lastSave = raidDate .. ' ' .. hour
                                        break
                                    end
                                    break
                                end
                            end
                            break
                        end
                    end

                    getglobal('SaveAttendanceDialogBoss'):SetText(boss)
                    getglobal('SaveAttendanceDialogLastSave'):SetText('Last Save: ' .. lastSave)
                    openAttendanceSaveWindow()
                    return true
                end
            end
        end
    end
end

function SaveAttendance_OnClick()

    if not UnitName('target') or UnitIsPlayer('target') then
        twprint('Please target the boss.')
        return false
    end

    local target = ''
    local raidDate = date("%d/%m")
    local zone = GetZoneText()
    local raidTime = date("%H:%M")

    for z, bosses in next, attendanceTargets do
        if GetZoneText() == z then
            for bkey, boss in next, bosses do
                if UnitName('target') == bkey then
                    target = boss
                    break
                end
            end
        end
        if target ~= '' then
            break
        end
    end

    SendAddonMessage(TWLC2_CHANNEL, "SaveAttendance=" .. target .. '=' .. raidDate .. '=' .. zone .. '=' .. raidTime, "RAID")
end

function SaveAttendanceBoss(boss, raidDate, zone, raidTime)

    if not TWLC_ATTENDANCE[zone] then
        TWLC_ATTENDANCE[zone] = {}
    end
    if not TWLC_ATTENDANCE[zone][raidDate] then
        TWLC_ATTENDANCE[zone][raidDate] = {}
    end
    if not TWLC_ATTENDANCE[zone][raidDate][boss] then
        TWLC_ATTENDANCE[zone][raidDate][boss] = {}
    end
    if not TWLC_ATTENDANCE[zone][raidDate][boss][raidTime] then
        TWLC_ATTENDANCE[zone][raidDate][boss][raidTime] = {}
    end

    local numRosterOnline = 0

    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, _, _, _, _, _, z = GetRaidRosterInfo(i);
            if z ~= 'Offline' then
                table.insert(TWLC_ATTENDANCE[zone][raidDate][boss][raidTime], n)
                numRosterOnline = numRosterOnline + 1
                --            twdebug('saved ' .. n .. ' for ' .. boss .. ' @ '..raidTime..' in ' .. zone .. ' ' .. raidDate)
            end
        end
    end
    closeAttendanceSaveWindow()
    twprint('Attendance saved for |cffff0505' .. boss .. classColors['priest'].c .. ' for ' .. numRosterOnline .. ' online players.')
end

function GetPlayerAttendance(name)
    if not TWLC_CONFIG['attendance'] then
        return ''
    end
    local totalRaids = 0
    local attendedRaids = 0
    --zone check
    if not TWLC_ATTENDANCE[GetZoneText()] then
        return ''
    end

    for date, bosses in next, TWLC_ATTENDANCE[GetZoneText()] do
        for boss, attempts in next, bosses do
            for attemptTime, playerList in next, attempts do
                totalRaids = totalRaids + 1
                for _, player in next, playerList do
                    if player == name then
                        attendedRaids = attendedRaids + 1
                        break
                    end
                end
            end
        end
    end

    if totalRaids == 0 or attendedRaids == 0 then
        return '|cffc805000%'
    end

    local attendance = math.floor(attendedRaids * 100 / totalRaids)
    local color = '|cff0be700'
    if attendance < 70 and attendance >= 40 then
        color = '|cffffb400'
    end
    if attendance < 40 then
        color = '|cffc80500'
    end
    return color .. attendance .. '%'
end

function UpdateCLVotedButtons(cl, voteStatus)
    local index = 0
    --hide all
    for i = 0, 15 do
        if getglobal('CLVotedButton' .. i) then
            getglobal('CLVotedButton' .. i):Hide()
        end
    end
    index = 0
    for name, voted in next, TWLC_ROSTER do
        index = index + 1
        local class = getPlayerClass(name)
        if not LCVoteFrame.CLVotedFrames[index] then
            LCVoteFrame.CLVotedFrames[index] = CreateFrame('Button', 'CLVotedButton' .. index, getglobal('CLThatVotedList'), 'CLVotedButton')
        end
        LCVoteFrame.CLVotedFrames[index]:SetPoint("TOPLEFT", getglobal("CLThatVotedList"), "TOPLEFT", index * 21 - 20, 0)
        LCVoteFrame.CLVotedFrames[index]:Show()
        LCVoteFrame.CLVotedFrames[index].name = name
        getglobal('CLVotedButton' .. index):SetNormalTexture("Interface\\AddOns\\TWLC2\\classes\\" .. class)
        getglobal('CLVotedButton' .. index):SetPushedTexture("Interface\\AddOns\\TWLC2\\classes\\" .. class)
        getglobal('CLVotedButton' .. index):SetHighlightTexture("Interface\\AddOns\\TWLC2\\classes\\" .. class)

        local CLButton = getglobal('CLVotedButton' .. index)

        CLButton:SetScript("OnEnter", function(self)
            LCTooltipVoteFrame:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4), -(this:GetHeight() / 4));
            LCTooltipVoteFrame:AddLine(this.name)
            LCTooltipVoteFrame:Show();
        end)

        CLButton:SetScript("OnLeave", function(self)
            LCTooltipVoteFrame:Hide();
        end)

        getglobal('CLVotedButton' .. index):SetAlpha(0.3)

        --normal votes
        for n, d in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem] do
            for voter, vote in next, LCVoteFrame.itemVotes[LCVoteFrame.CurrentVotedItem][n] do
                if voter == name and vote == '+' then
                    getglobal('CLVotedButton' .. index):SetAlpha(1)
                end
            end
        end

        --done voting
        if not voted then
            --check if he clicked done voting for this itme
            if LCVoteFrame.clDoneVotingItem[name] then
                for itemIndex, doneVoting in next, LCVoteFrame.clDoneVotingItem[name] do
                    if itemIndex == LCVoteFrame.CurrentVotedItem and doneVoting then
                        getglobal('CLVotedButton' .. index):SetAlpha(1)
                    end
                end
            end
        end

        --        if cl and voteStatus then
        --            if cl == name then
        --                if voteStatus == '+' then
        --                    getglobal('CLVotedButton' .. index):SetAlpha(1)
        --                else
        --                    getglobal('CLVotedButton' .. index):SetAlpha(0.3)
        --                end
        --            end
        --        else
        --            getglobal('CLVotedButton' .. index):SetAlpha(0.3)
        --        end
    end
    getglobal('MLToWinnerNrOfVotes'):Hide()
    getglobal('WinnerStatusNrOfVotes'):Hide()
end

function SetDynTTN(numItems, updateButton)
    local t = 25
    if numItems == 2 then
        t = 30
    end
    if numItems == 3 then
        t = 35
    end
    if numItems == 4 then
        t = 45
    end
    if numItems >= 5 then
        t = 60
    end
    if updateButton then
        getglobal('BroadcastLoot'):SetText('Broadcast Loot (' .. t .. 's)')
    end
    TIME_TO_NEED = t
end

function SetDynTTV(numItems)
    local t = 45
    if numItems == 2 then
        t = 60
    end
    if numItems == 3 then
        t = 80
    end
    if numItems == 4 then
        t = 100
    end
    if numItems >= 5 then
        t = 120
    end
    TIME_TO_VOTE = t
end

function GetPlayerAttendanceText(name)
    if not TWLC_CONFIG['attendance'] then
        return ''
    end
    if not TWLC_ATTENDANCE[GetZoneText()] then
        return ''
    end
    local attendanceText = ''
    local attBosses = {}
    for date, bosses in next, TWLC_ATTENDANCE[GetZoneText()] do
        for boss, attempts in next, bosses do
            if not attBosses[boss] then
                attBosses[boss] = { [1] = 0, [2] = 0 }
            end

            for attemptTime, playerList in next, attempts do
                attBosses[boss][1] = attBosses[boss][1] + 1
                for _, player in next, playerList do
                    if player == name then
                        attBosses[boss][2] = attBosses[boss][2] + 1
                        break
                    end
                end
            end
            local attendance = math.floor(attBosses[boss][2] * 100 / attBosses[boss][1])
            local color = '|cff0be700'
            if attendance < 70 and attendance >= 40 then
                local color = '|cffffb400'
            end
            if attendance < 40 then
                local color = '|cffc80500'
            end
            attendanceText = attendanceText .. FONT_COLOR_CODE_CLOSE .. boss .. ': ' .. attBosses[boss][2] .. '/' .. attBosses[boss][1] .. ' ' .. color .. attendance .. '%\n'
        end
    end
    return attendanceText
end

function twlc_ver(ver)
    if string.sub(ver, 7, 7) == '' then
        ver = '0.' .. ver
    end

    return tonumber(string.sub(ver, 1, 1)) * 1000 +
            tonumber(string.sub(ver, 3, 3)) * 100 +
            tonumber(string.sub(ver, 5, 5)) * 10 +
            tonumber(string.sub(ver, 7, 7)) * 1
end

function closeWhoWindow()
    getglobal('VoteFrameWho'):Hide()
end

function SecondsToClock(seconds)
    seconds = tonumber(seconds)

    if seconds <= 0 then
        return "00:00";
    else
        hours = string.format("%02.f", math.floor(seconds / 3600));
        mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)));
        secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60));
        return mins .. ":" .. secs
    end
end

function tableSize(table)
    if type(table) ~= 'table' then
        twerror('attempt to get table size of a non table (' .. type(table) .. ')')
        twerror('not table = ' .. table)
        return 0
    end
    local len = 0
    for _ in next, table do
        len = len + 1
    end
    return len
end

StaticPopupDialogs["TWLC_CONFIRM_LOOT_DISTRIBUTION"] = {
    text = "TWLC You wish to assign %s to %s.  Is this correct?",
    button1 = "yes",
    button2 = "no",
    timeout = 0,
    hideOnEscape = 1,
};

StaticPopupDialogs["TWLC_CONFIRM_LOOT_DISTRIBUTION"].OnAccept = function(data)
    --    twdebug('popul confirm loot data : ' .. data)
    if not LCVoteFrame.CurrentVotedItem then
        --        twdebug('popul confirm loot LCVoteFrame.CurrentVotedItem : nil ')
    else
        --        twdebug('popul confirm loot LCVoteFrame.CurrentVotedItem : ' .. LCVoteFrame.CurrentVotedItem)
    end
    --    awardPlayer()
    --    twdebug('GiveMasterLoot(' .. LCVoteFrame.CurrentVotedItem .. ', ' .. data .. ');')
end

function RaiderDetails_ChangeTab(tab)
    if tab == 1 then
        getglobal('TWLCRaiderDetailsFrameTab1'):SetText(FONT_COLOR_CODE_CLOSE .. 'Consumables')
        getglobal('TWLCRaiderDetailsFrameTab2'):SetText('|cff696969Loot History')

        getglobal('TWLCLootHistoryFrameScrollFrame'):Hide()
        getglobal('TWLCConsumablesListScrollFrame'):Show()

        for index in next, LCVoteFrame.lootHistoryFrames do
            LCVoteFrame.lootHistoryFrames[index]:Hide()
        end

        for index in next, LCVoteFrame.consumablesListFrames do
            LCVoteFrame.consumablesListFrames[index]:Hide()
        end

        getglobal('TWLCConsumablesTitle'):Show()
        getglobal('TWLCLootHistoryTitle'):Hide()

        ConsumablesList_Update()
    end
    if tab == 2 then
        getglobal('TWLCRaiderDetailsFrameTab1'):SetText('|cff696969Consumables')
        getglobal('TWLCRaiderDetailsFrameTab2'):SetText(FONT_COLOR_CODE_CLOSE .. 'Loot History')

        getglobal('TWLCLootHistoryFrameScrollFrame'):Show()
        getglobal('TWLCConsumablesListScrollFrame'):Hide()

        getglobal('TWLCConsumablesTitle'):Hide()
        getglobal('TWLCLootHistoryTitle'):Show()

        if getglobal('RLWindowFrame'):IsVisible() then
            getglobal('RLWindowFrame'):Hide()
        end

        for index in next, LCVoteFrame.lootHistoryFrames do
            LCVoteFrame.lootHistoryFrames[index]:Hide()
        end

        for index in next, LCVoteFrame.consumablesListFrames do
            LCVoteFrame.consumablesListFrames[index]:Hide()
        end

        LootHistory_Update()
    end

    getglobal('TWLCRaiderDetailsFrame'):Show()
end

function RLOptions_ChangeTab(tab)

    if tab == 1 then
        getglobal('RLWindowFrameTab1'):SetText(FONT_COLOR_CODE_CLOSE .. 'Officers')
        getglobal('RLWindowFrameTab2'):SetText('|cff696969Need Buttons')
        getglobal('RLWindowFrameTab3'):SetText('|cff696969Loot History')

        getglobal('RLWindowFrameBISButton'):Hide()
        getglobal('RLWindowFrameMSButton'):Hide()
        getglobal('RLWindowFrameOSButton'):Hide()
        getglobal('RLWindowFrameXMOGButton'):Hide()
        getglobal('TWLCRaiderDetailsFrame'):Hide()
        getglobal('RLWindowFrameSyncLootHistory'):Hide()
        getglobal('RLWindowFrameNeedButtonsDesc'):Hide()
        getglobal('RLWindowFrameNameTitle'):Show()
        getglobal('RLWindowFrameAssist'):Show()
        getglobal('RLWindowFrameOfficer'):Show()
        for i = 1, tableSize(RLWindowFrame.assistFrames), 1 do
            RLWindowFrame.assistFrames[i]:Hide()
        end
        checkAssists()
    end
    if tab == 2 then
        getglobal('RLWindowFrameTab1'):SetText('|cff696969Officers')
        getglobal('RLWindowFrameTab2'):SetText(FONT_COLOR_CODE_CLOSE .. 'Need Buttons')
        getglobal('RLWindowFrameTab3'):SetText('|cff696969Loot History')

        getglobal('RLWindowFrameBISButton'):Show()
        getglobal('RLWindowFrameMSButton'):Show()
        getglobal('RLWindowFrameOSButton'):Show()
        getglobal('RLWindowFrameXMOGButton'):Show()
        getglobal('TWLCRaiderDetailsFrame'):Hide()
        getglobal('RLWindowFrameSyncLootHistory'):Hide()
        getglobal('RLWindowFrameNeedButtonsDesc'):Show()
        getglobal('RLWindowFrameNameTitle'):Hide()
        getglobal('RLWindowFrameAssist'):Hide()
        getglobal('RLWindowFrameOfficer'):Hide()
        for i = 1, tableSize(RLWindowFrame.assistFrames), 1 do
            RLWindowFrame.assistFrames[i]:Hide()
        end
    end
    if tab == 3 then
        getglobal('RLWindowFrameTab1'):SetText('|cff696969Officers')
        getglobal('RLWindowFrameTab2'):SetText('|cff696969Need Buttons')
        getglobal('RLWindowFrameTab3'):SetText(FONT_COLOR_CODE_CLOSE .. 'Loot History')

        getglobal('RLWindowFrameBISButton'):Hide()
        getglobal('RLWindowFrameMSButton'):Hide()
        getglobal('RLWindowFrameOSButton'):Hide()
        getglobal('RLWindowFrameXMOGButton'):Hide()
        getglobal('TWLCRaiderDetailsFrame'):Hide()
        getglobal('RLWindowFrameSyncLootHistory'):Show()
        getglobal('RLWindowFrameNeedButtonsDesc'):Hide()
        getglobal('RLWindowFrameNameTitle'):Hide()
        getglobal('RLWindowFrameAssist'):Hide()
        getglobal('RLWindowFrameOfficer'):Hide()
        for i = 1, tableSize(RLWindowFrame.assistFrames), 1 do
            RLWindowFrame.assistFrames[i]:Hide()
        end
    end
end

StaticPopupDialogs["EXAMPLE_HELLOWORLD"] = {
    text = "Do you want to greet the world today?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        GreetTheWorld()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 3,
}

function TestNeedButton_OnClick()

    collectRaidBuffs() --dev todo remove

    local testItem1 = "\124cffa335ee\124Hitem:19003:0:0:0:0:0:0:0:0\124h[Head of Nefarian]\124h\124r";
    --local testItem2 = "\124cff0070dd\124Hitem:15138:0:0:0:0:0:0:0:0\124h[Onyxia Scale Cloak]\124h\124r";
    local testItem2 = "\124cffa335ee\124Hitem:20932:0:0:0:0:0:0:0:0\124h[Qiraji Bindings of Dominance]\124h\124r"

    --    local testItem3 = "\124cffa335ee\124Hitem:16533:0:0:0:0:0:0:0:0\124h[Warlord's Silk Cowl]\124h\124r";

    local _, _, itemLink1 = string.find(testItem1, "(item:%d+:%d+:%d+:%d+)");
    local lootName1, Link1, quality1, _, _, _, _, _, lootIcon1 = GetItemInfo(itemLink1)

    local _, _, itemLink2 = string.find(testItem2, "(item:%d+:%d+:%d+:%d+)");
    local lootName2, Link2, quality2, _, _, _, _, _, lootIcon2 = GetItemInfo(itemLink2)

    if quality1 and lootIcon1 and quality2 and lootIcon2 then

        --SendChatMessage('This is a test, click whatever you want!', "RAID_WARNING")
        getglobal('BroadcastLoot'):Disable()

        SetDynTTN(2)
        TWLCCountDownFRAME.countDownFrom = TIME_TO_NEED
        SendAddonMessage(TWLC2_CHANNEL, 'ttn=' .. TIME_TO_NEED, "RAID")
        SetDynTTV(2)
        SendAddonMessage(TWLC2_CHANNEL, 'ttv=' .. TIME_TO_VOTE, "RAID")
        SendAddonMessage(TWLC2_CHANNEL, 'ttr=' .. TIME_TO_ROLL, "RAID")

        sendReset()

        -- dont show window til everyone picked
        -- SendAddonMessage(TWLC2_CHANNEL, "voteframe=show", "RAID")

        TWLCCountDownFRAME:Show()
        SendAddonMessage(TWLC2_CHANNEL, 'countdownframe=show', "RAID")

        ChatThrottleLib:SendAddonMessage("ALERT", TWLC2_CHANNEL, "preloadInVoteFrame=1=" .. lootIcon1 .. "=" .. lootName1 .. "=" .. testItem1, "RAID")
        ChatThrottleLib:SendAddonMessage("ALERT", TWLC2_CHANNEL, "preloadInVoteFrame=2=" .. lootIcon2 .. "=" .. lootName2 .. "=" .. testItem2, "RAID")

        local buttons = ''
        if TWLC_CONFIG['NeedButtons']['BIS'] then
            buttons = buttons .. 'b'
        end
        if TWLC_CONFIG['NeedButtons']['MS'] then
            buttons = buttons .. 'm'
        end
        if TWLC_CONFIG['NeedButtons']['OS'] then
            buttons = buttons .. 'o'
        end
        if TWLC_CONFIG['NeedButtons']['XMOG'] then
            buttons = buttons .. 'x'
        end

        ChatThrottleLib:SendAddonMessage("ALERT", TWLC2c_CHANNEL, "loot=1=" .. lootIcon1 .. "=" .. lootName1 .. "=" .. testItem1 .. "=" .. TWLCCountDownFRAME.countDownFrom .. "=" .. buttons, "RAID")
        ChatThrottleLib:SendAddonMessage("ALERT", TWLC2c_CHANNEL, "loot=2=" .. lootIcon2 .. "=" .. lootName2 .. "=" .. testItem2 .. "=" .. TWLCCountDownFRAME.countDownFrom .. "=" .. buttons, "RAID")

        ChatThrottleLib:SendAddonMessage("ALERT", TWLC2c_CHANNEL, "doneSending=2=items", "RAID")

        getglobal("MLToWinner"):Disable();
    else

        local _, _, itemLink1 = string.find(testItem1, "(item:%d+:%d+:%d+:%d+)");
        GameTooltip:SetHyperlink(itemLink1)
        GameTooltip:Hide()

        local _, _, itemLink2 = string.find(testItem2, "(item:%d+:%d+:%d+:%d+)");
        GameTooltip:SetHyperlink(itemLink2)
        GameTooltip:Hide()

        twerror(testItem1 .. ' or ' .. testItem2 .. ' was not seen before, try again...')
    end
end

function SetTokenRewardLink(reward, index)

    local _, _, itemLink = string.find(reward, "(item:%d+:%d+:%d+:%d+)");
    local _, link, _, _, _, _, _, _, tex = GetItemInfo(itemLink)
    if link then
        addButtonOnEnterTooltip(getglobal('CurrentVotedItemQuestReward' .. index), link)
        getglobal('CurrentVotedItemQuestReward' .. index):SetNormalTexture(tex)
        getglobal('CurrentVotedItemQuestReward' .. index):SetPushedTexture(tex)
        getglobal('CurrentVotedItemQuestReward' .. index):Show()
    else
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Hide()
    end
end

function getUnitBuff(unit, i)

    LCTooltipVoteFrame:SetOwner(LCTooltipVoteFrame, "ANCHOR_NONE");
    NeedFrameTooltipTextLeft1:SetText("");
    LCTooltipVoteFrame:SetUnitBuff(unit, i);

    if LCTooltipVoteFrameTextLeft1:GetText() then
        return trim(LCTooltipVoteFrameTextLeft1:GetText()), UnitBuff(unit, i)
    else
        return false, ''
    end
end

function ScanConsumables_OnClick()
    SendAddonMessage(TWLC2_CHANNEL, 'scanConsumables=now', "RAID")
end

function collectRaidBuffs()
    LCVoteFrame.RaidBuffs = {}
    local buffNr = 0
    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local n, _, _, _, _, _, z = GetRaidRosterInfo(i);
            local score = 0
            local consumables = {}
            if z ~= 'Offline' then
                for j = 0, 32 do
                    local buffName, buffTexture = getUnitBuff('raid' .. i, j)
                    if buffName then
                        local itemName
                        --                        twdebug('found - ' .. buffName)
                        --                        twdebug('found - ' .. buffTexture)
                        for index, cons in next, LCVoteFrame.consumables do
                            if buffName == cons.name then
                                score = score + cons.score
                                if cons.itemLink ~= '' then
                                    local _, _, itemLink = string.find(cons.itemLink, "(item:%d+:%d+:%d+:%d+)");
                                    itemName = GetItemInfo(itemLink)
                                else
                                    itemName = buffName
                                end
                                buffNr = buffNr + 1
                            end
                        end
                        table.insert(consumables, {
                            buffName = buffName,
                            buffTexture = buffTexture,
                            itemName = itemName
                        })
                    end
                end

                table.insert(LCVoteFrame.RaidBuffs, {
                    name = n,
                    score = score,
                    buffs = consumables
                })
            end
        end
    end
    twprint('Scanned |cff69ccf0' .. tableSize(LCVoteFrame.RaidBuffs) .. ' |cffffffffplayers. Found |cff69ccf0' .. buffNr .. ' |cffffffffconsumable buffs.')
end

function getConsumablesScore(name, colored)
    local color = ''
    local maxScore = 0
    if colored then
        for index, consumes in next, LCVoteFrame.RaidBuffs do
            if consumes.score > maxScore then
                maxScore = consumes.score
            end
        end
    end
    if name then
        for index, consumes in next, LCVoteFrame.RaidBuffs do
            if consumes.name == name then
                if colored then
                    color = '|cff0be700'
                    local perc = math.floor(consumes.score * 100 / maxScore)
                    if perc < 70 and perc >= 40 then
                        color = '|cffffb400'
                    end
                    if perc < 40 then
                        color = '|cffc80500'
                    end
                end
                return color .. consumes.score
            end
        end
    end
    return 0
end

LCVoteFrame.consumables = {
    { name = 'Flask of the Titans', score = 3, itemLink = '\124cffffffff\124Hitem:13510:0:0:0:0:0:0:0:0\124h[Flask of the Titans]\124h\124r' },
    { name = 'Distilled Wisdom', score = 3, itemLink = '\124cffffffff\124Hitem:13511:0:0:0:0:0:0:0:0\124h[Flask of Distilled Wisdom]\124h\124r' },
    { name = 'Supreme Power', score = 3, itemLink = '\124cffffffff\124Hitem:13512:0:0:0:0:0:0:0:0\124h[Flask of Supreme Power]\124h\124r' },
    { name = 'Chromatic Resistance', score = 3, itemLink = '\124cffffffff\124Hitem:13513:0:0:0:0:0:0:0:0\124h[Flask of Chromatic Resistance]\124h\124r' },

    { name = 'Spirit of Zanza', score = 1.5, itemLink = '\124cff1eff00\124Hitem:20079:0:0:0:0:0:0:0:0\124h[Spirit of Zanza]\124h\124r' },
    { name = 'Swiftness of Zanza', score = 1.5, itemLink = '\124cff1eff00\124Hitem:20081:0:0:0:0:0:0:0:0\124h[Swiftness of Zanza]\124h\124r' },

    { name = 'Strike of the Scorpok', score = 1.5, itemLink = "\124cffffffff\124Hitem:8412:0:0:0:0:0:0:0:0\124h[Ground Scorpok Assay]\124h\124r" },
    { name = 'Infallible Mind', score = 1.5, itemLink = "\124cffffffff\124Hitem:8423:0:0:0:0:0:0:0:0\124h[Cerebral Cortex Compound]\124h\124r" },
    { name = 'Spiritual Domination', score = 1.5, itemLink = "\124cffffffff\124Hitem:8424:0:0:0:0:0:0:0:0\124h[Gizzard Gum]\124h\124r" },
    { name = 'Spirit of Boar', score = 1.5, itemLink = "\124cffffffff\124Hitem:8411:0:0:0:0:0:0:0:0\124h[Lung Juice Cocktail]\124h\124r" },

    { name = 'Elixir of the Mongoose', score = 1.5, itemLink = "\124cffffffff\124Hitem:13452:0:0:0:0:0:0:0:0\124h[Elixir of the Mongoose]\124h\124r" },
    { name = 'Greater Agility', score = 1, itemLink = "\124cffffffff\124Hitem:9187:0:0:0:0:0:0:0:0\124h[Elixir of Greater Agility]\124h\124r" },

    { name = 'Mana Regeneration', score = 1.5, itemLink = "\124cffffffff\124Hitem:20007:0:0:0:0:0:0:0:0\124h[Mageblood Potion]\124h\124r" },
    { name = 'Health II', score = 0.5, itemLink = "\124cffffffff\124Hitem:3825:0:0:0:0:0:0:0:0\124h[Elixir of Fortitude]\124h\124r" }, --elixir of fort

    { name = 'Armor', score = 0.5, itemLink = "\124cffffffff\124Hitem:8951:0:0:0:0:0:0:0:0\124h[Elixir of Greater Defense]\124h\124r" }, --Elixir of Greater Defense
    { name = 'Greater Armor', score = 0.5, itemLink = "\124cffffffff\124Hitem:13445:0:0:0:0:0:0:0:0\124h[Elixir of Superior Defense]\124h\124r" }, --Elixir of Superior Defense

    { name = 'Regeneration', score = 0.5, itemLink = "\124cffffffff\124Hitem:20004:0:0:0:0:0:0:0:0\124h[Major Troll's Blood Potion]\124h\124r" },
    { name = 'Gift of Arthas', score = 0.5, itemLink = "\124cffffffff\124Hitem:9088:0:0:0:0:0:0:0:0\124h[Gift of Arthas]\124h\124r" },

    { name = 'Juju Power', score = 1.5, itemLink = "\124cffffffff\124Hitem:12451:0:0:0:0:0:0:0:0\124h[Juju Power]\124h\124r" },
    { name = 'Elixir of Giants', score = 1, itemLink = "\124cffffffff\124Hitem:9206:0:0:0:0:0:0:0:0\124h[Elixir of Giants]\124h\124r" },

    { name = 'Juju Might', score = 1.5, itemLink = "\124cffffffff\124Hitem:12460:0:0:0:0:0:0:0:0\124h[Juju Might]\124h\124r" },
    { name = 'Winterfall Firewater', score = 1, itemLink = "\124cffffffff\124Hitem:12820:0:0:0:0:0:0:0:0\124h[Winterfall Firewater]\124h\124r" },

    { name = 'Greater Arcane Elixir', score = 1, itemLink = "\124cffffffff\124Hitem:13454:0:0:0:0:0:0:0:0\124h[Greater Arcane Elixir]\124h\124r" },
    { name = 'Shadow Power', score = 1.5, itemLink = "\124cffffffff\124Hitem:9264:0:0:0:0:0:0:0:0\124h[Elixir of Shadow Power]\124h\124r" }, --Elixir of Shadow Power
    { name = 'Greater Firepower', score = 1.5, itemLink = "\124cffffffff\124Hitem:21546:0:0:0:0:0:0:0:0\124h[Elixir of Greater Firepower]\124h\124r" },
    { name = 'Frost Power', score = 1.5, itemLink = "\124cffffffff\124Hitem:17708:0:0:0:0:0:0:0:0\124h[Elixir of Frost Power]\124h\124r" },

    { name = 'Juju Ember', score = 0.5, itemLink = "\124cffffffff\124Hitem:12455:0:0:0:0:0:0:0:0\124h[Juju Ember]\124h\124r" },
    { name = 'Juju Chill', score = 0.5, itemLink = "\124cffffffff\124Hitem:12457:0:0:0:0:0:0:0:0\124h[Juju Chill]\124h\124r" },

    { name = 'Crystal Ward', score = 0.5, itemLink = "\124cffffffff\124Hitem:11564:0:0:0:0:0:0:0:0\124h[Crystal Ward]\124h\124r" },
    { name = 'Crystal Spire', score = 0.5, itemLink = "\124cffffffff\124Hitem:11567:0:0:0:0:0:0:0:0\124h[Crystal Spire]\124h\124r" },

    { name = 'Arcane Protection', score = 1.5, itemLink = "\124cffffffff\124Hitem:13461:0:0:0:0:0:0:0:0\124h[Greater Arcane Protection Potion]\124h\124r" }, --Greater
    { name = 'Fire Protection', score = 1.5, itemLink = "\124cffffffff\124Hitem:13457:0:0:0:0:0:0:0:0\124h[Greater Fire Protection Potion]\124h\124r" }, --Greater
    { name = 'Frost Protection', score = 1.5, itemLink = "\124cffffffff\124Hitem:13456:0:0:0:0:0:0:0:0\124h[Greater Frost Protection Potion]\124h\124r" }, --Greater
    { name = 'Nature Protection', score = 1.5, itemLink = "\124cffffffff\124Hitem:13458:0:0:0:0:0:0:0:0\124h[Greater Nature Protection Potion]\124h\124r" }, --Greater
    { name = 'Shadow Protection', score = 1.5, itemLink = "\124cffffffff\124Hitem:13459:0:0:0:0:0:0:0:0\124h[Greater Shadow Protection Potion]\124h\124r" }, --Greater

    { name = 'Increased Agility', score = 1, itemLink = "\124cffffffff\124Hitem:13928:0:0:0:0:0:0:0:0\124h[Grilled Squid]\124h\124r" }, --Grilled Squid
    { name = 'Well Fed', score = 1, itemLink = "\124cffffffff\124Hitem:20452:0:0:0:0:0:0:0:0\124h[Smoked Desert Dumplings]\124h\124r" }, -- ???
    { name = 'Mana Regeneration', score = 1, itemLink = "\124cffffffff\124Hitem:13931:0:0:0:0:0:0:0:0\124h[Nightfin Soup]\124h\124r" }, -- conflict with mageblood
    { name = 'Increased Intellect', score = 1, itemLink = "\124cffffffff\124Hitem:18254:0:0:0:0:0:0:0:0\124h[Runn Tum Tuber Surprise]\124h\124r" },
    { name = 'Increased Stamina', score = 1, itemLink = "\124cffffffff\124Hitem:21023:0:0:0:0:0:0:0:0\124h[Dirge's Kickin' Chimaerok Chops]\124h\124r" },
    { name = 'Blessed Sunfruit Juice', score = 1, itemLink = "\124cffffffff\124Hitem:13813:0:0:0:0:0:0:0:0\124h[Blessed Sunfruit Juice]\124h\124r" },

    { name = 'Rumsey Rum Black Label', score = 0.5, itemLink = "\124cffffffff\124Hitem:21151:0:0:0:0:0:0:0:0\124h[Rumsey Rum Black Label]\124h\124r" },
    { name = 'Gordok Green Grog', score = 0.5, itemLink = "\124cff1eff00\124Hitem:18269:0:0:0:0:0:0:0:0\124h[Gordok Green Grog]\124h\124r" },

    { name = 'Sayge\'s Dark Fortune of Damage', score = 1.5, itemLink = '' },
    { name = 'Sayge\'s Dark Fortune of Agility', score = 1.5, itemLink = '' },
    { name = 'Sayge\'s Dark Fortune of Intelligence', score = 1.5, itemLink = '' },
    { name = 'Sayge\'s Dark Fortune of Spirit', score = 1.5, itemLink = '' },
    { name = 'Sayge\'s Dark Fortune of Stamina', score = 1.5, itemLink = '' },

    { name = 'Mol\'dar\'s Moxie', score = 1.5, itemLink = '' },
    { name = 'Slip\'kik\'s Savvy', score = 1.5, itemLink = '' },
    { name = 'Fengus\' Ferocity', score = 1.5, itemLink = '' },


    { name = 'Songflower Serenade', score = 1.5, itemLink = '' },
    { name = 'Traces of Silithyst', score = 1.5, itemLink = '' },
    { name = 'Blessing of Blackfathom', score = 0.5, itemLink = '' },
    --Toasted Smorc
}
