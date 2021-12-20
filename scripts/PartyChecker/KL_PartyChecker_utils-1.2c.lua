-- ------------------------------------------- --
-- "PARTYCHECKER"
-- original Utility Script by Dr_Nope
-- (contact me on Discord: Dr_Nope#0037)
-- last mod. 2020-11-23
--
-- You are free to use, repack, and modify it.
-- If you do modify it and publish your mods,
-- juste give me credit by keeping this little
-- frame included.
-- Thank you.
-- ------------------------------------------- --


if PartyChecker then
    return
end

-- Flags for PartyChecker
-- basically used to inform the progression of the "party check"
-- for each player
local PC_FLAGS= {
    PARTY_CHECKED= 65536,       --party check has been done
    SUBMIT_CMD_CALLED= 131072   --"submit command" call has been made
}

-- list of "hooks" that are called everytime a new party has been confrimed
local RegisteredPartyHooks= {}

-- The main object, allocated globally for external use
rawset(_G, "PartyChecker",
    {
        -- boolean to inform is a "party check" is going to be made when possible
        -- typically, true when new players join, false once check is done
        waitingPartyCheck= false,
        -- function that, for a given player, return his party bits
        -- (if player 1 is in party then 1st bit is 1, if p2's in bit n.2 is 1, etc.)
        getParty=
            function(player)
                return (player.valid and player.party_flags) and (player.party_flags & 65535) or 0
            end,
        -- function that, for a given player, returns a boolean wether or not this player is in a party
        -- WARNING: may not have been "party checked" yet, so don't forget to check 'isWaitingPartyCheck'
        isInParty=
            function(player)
                return (player.valid and player.party_flags~=nil) and ((player.party_flags & 65535)~=0) or false
            end,
        -- function that, for a given player, returns a boolean wether or not the "party check" has been made for this player
        isWaitingPartyCheck=
            function(player)
                return  (player.valid) and ((player.party_flags==nil) or ((player.party_flags & PC_FLAGS.PARTY_CHECKED)==0))
            end,
        -- function that, for a given player, returns a table containing all the players of his party (including himself)
        -- return empty table if not in a party
        -- WARNING: may not have been "party checked" yet, so don't forget to check 'isWaitingPartyCheck'
        getPartyPlayers=
            function(player)
                if not PartyChecker.isInParty(player) then return {} end
                local party={}
                for pnum=0, (#players-1) do
                    local p= players[pnum]
                    if player.party_flags & (1<<pnum) then
                        table.insert(party,p)
                    end
                end
                return party
            end,
        
        -- function that adds a "hook" function (parameter) to the list of "registeredParty" hooks.
        -- Once added, each time a new a party has been confirmed, this function will be called,
        -- with a table containing every player of this party, as argument.
        add_registeredPartyHook=
            function(func)
                table.insert(RegisteredPartyHooks, func)
            end
    }
)

-- calls every 'partyRegistered' hooks with the newly
-- registered party (table containing concerned players) as argument
local function call_partyHooks(t_party)
    for _,f in pairs(RegisteredPartyHooks) do
        f(t_party)
    end
end

-- COM_AddCommand : https://wiki.srb2.org/wiki/Lua/Functions#COM_AddCommand
-- Command that is used by the script to submit the "party bits" to the server (partyFlag)
-- Shouldn't be called via the console
-- As previously, "party bits" is an integer where, if player 1 is in party then 1 bit is one,
-- if p2 is in party the bit n.2 is 1, etc.
COM_AddCommand("_pc_partysumbit", function(player, partyFlag)
    -- if the party flag in not given, or 0, then it is considered that this means
    -- that the player has no party
    -- also if a player can call this command, this means he's either a party leader,
    -- either non in a party. Therefore if he calls the command with the no party flag,
    -- flag him as checked (this potentially counteracts fake inclusions from 
    -- '_pc_partysubmit' by other players call)
    if (partyFlag=="0") or (partyFlag==nil) then
        -- "party checking" has been done
        player.party_flags= PC_FLAGS.PARTY_CHECKED

        return
    end

    -- if the player is no longer in "party check" waiting state, do nothing
    if (not PartyChecker.isWaitingPartyCheck(player)) then return end

    local n_partyFlag= tonumber(partyFlag)
    if not n_partyFlag then return end

    -- counting how many members is supposed to be in this party
    local bytes= n_partyFlag
    for i=1, 16 do
        if (bytes%2==1) then
            break
        else
            bytes= bytes>>1
        end
    end
    -- if only one (or zero) members in party, then solo queue? therefor no party
    if bytes<=1 then
        -- "party checking" has been done
        player.party_flags= PC_FLAGS.PARTY_CHECKED

        -- we now can call the 'registeredParty' hooks, even if this
        -- is a lone player
        call_partyHooks({player})

        return
    end

    -- if we're here, than the partyFlag bits was valid
    -- therefor, for all the players that are pointed out, we give them the same
    -- party flag bits
    for pnum=0, (#players-1) do
        local p= players[pnum]
        if (not p) then continue end

        if n_partyFlag & (1<<pnum) then
            -- "party checking" has been done
            p.party_flags= (PC_FLAGS.PARTY_CHECKED | n_partyFlag)
        end
    end

    -- we now can call the 'registeredParty' hooks,
    -- with the newly confirmed party as argument
    call_partyHooks(PartyChecker.getPartyPlayers(player))    
end)

-- function used by splitscreen players on client side to determine and generate the
-- party bits (that will be submited to server) for a given player
local function generatePartyFlag(player)
    -- no split screen? abort!
    if (splitscreen<=0) then
        return 0
    end
    -- player not waiting for party check? abort
    if (not PartyChecker.isWaitingPartyCheck(player)) then
        return 0
    end

    -- for each player, we determine if he is a local splitscreen player
    -- if he is, we set his pointing bit (in the party bits) to 1 and return the result
    local dp_idx=1
    local pnum=1
    local party_flag= 0
    for pnum=0, (#players-1) do
        local p= players[pnum]
        if (not p) then continue end

        for dp in displayplayers.iterate do
            if  p==dp then
                party_flag= $ | (1<<pnum)
                break
            end
        end
    end

    return party_flag
end

-- this function is called to check if a "party check" needs to be done
-- if so, launches the "party checking" process
local function party_check()
    -- if nothing needs to be done, do nothing
    if not PartyChecker.waitingPartyCheck then return end

    -- for each available player,
    local b= false
    for p in players.iterate do
        -- (no party flag? -> 0 flag)
        p.party_flags= (p.party_flags) and p.party_flags or 0
        -- check if said player needs a party check
        if PartyChecker.isWaitingPartyCheck(p) then
            -- (as long as at least one play is mark as waiting, another "party check" will be performed next round)
            b= true
            -- every player can call the "submit" command once
            if not (p.party_flags & PC_FLAGS.SUBMIT_CMD_CALLED) then
                p.party_flags= p.party_flags | PC_FLAGS.SUBMIT_CMD_CALLED
                COM_BufInsertText(p,"_pc_partysumbit "..generatePartyFlag(p))
            end
        end
    end

    PartyChecker.waitingPartyCheck= b
end

-- "ThinkFrame" hook : https://wiki.srb2.org/wiki/Lua/Hooks#ThinkFrame
-- doing "party check" whenever it is possible
addHook("ThinkFrame", do
    party_check()
end)

-- "IntermissionThinker" hook : https://wiki.srb2.org/wiki/Lua/Kart/Hooks#IntermissionThinker
addHook("IntermissionThinker", do
    party_check()
end)

-- "VoteThinker" hook : https://wiki.srb2.org/wiki/Lua/Kart/Hooks#VoteThinker
addHook("VoteThinker", do
    party_check()
end)

-- "MapLoad" hook :
addHook("MapLoad", do
    party_check()
end) 

-- "PlayerJoin" hook : https://wiki.srb2.org/wiki/Lua/Hooks#PlayerJoin
-- if a player joins, then inform that a "party check" should be done ASAP
addHook("PlayerJoin", function(pnum)
    PartyChecker.waitingPartyCheck= true
end)

-- "PlayerQuit" hook : https://wiki.srb2.org/wiki/Lua/Hooks#PlayerQuit
-- if a player quits, destroy his party!
addHook("PlayerQuit",function(player, reason)
    for p in players.iterate do
        if p.party_flags and (p.party_flags==player.party_flags) then
            p.party_flags= (p.party_flags | PC_FLAGS.PARTY_CHECKED)
        end
    end
end)
