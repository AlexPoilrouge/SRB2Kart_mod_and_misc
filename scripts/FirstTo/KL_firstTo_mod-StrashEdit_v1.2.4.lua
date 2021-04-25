
-- Integer that, if different than zero, signifies that a "First to N" round
-- has been started / is ongoing
-- Making it availabe globally so external scripts can check for its
-- presence/activation
rawset(_G, "firstTo", 0)

-- optimization much? I dunno it's what people says on the internet...
local TICRATE = TICRATE
local FRACUNIT = FRACUNIT

-- maximum timer for victory screen display, and notification display
local FT_SCORESCREEN_DURATION= 6*TICRATE
local FT_CALL_TIMER_DURATION= 8*TICRATE

-- the range in which a user can call a "First to N" round
local ft_round_limit= {min=1, max=7}

-- function that aborts the ongoing "FT N" round
local _ft_abort= function()
    firstTo= 0
        for player in players.iterate do
            player.ft_last_winner= nil
            player.ft_wins= nil
        end
    server.first_to= nil
end

local _t_partyJoinCheck= {}

-- a CNET var to activate/disactivate the usage of this mod via console
local _ft_enabled= CV_RegisterVar({name= "ft_enabled", defaultvalue= "On", flags= CV_NETVAR|CV_CALL, PossibleValue= CV_OnOff, func= function(var)
    if (not var.value) and (firstTo > 0) then
        _ft_abort()
        print("[FirstTo] mod disabled.")
    else
        print("[FirstTo] mod enabled.")
    end
end})

-- CNET var that, when activated (default), allows to only count for "absolute win", i.e: a contester needs to arrive first place
-- to have a win counted, as opposite to only needing to arrive first among all the contesters  participating in the
-- "FT N" round
local _ft_abs_win= CV_RegisterVar({name= "ft_absolute_win", defaultvalue= "Yes", flags= CV_NETVAR, PossibleValue= CV_YesNo})
-- CNET var that, if disactivated, allows to count ties as a win for each player instead of no win
local _ft_allow_ties= CV_RegisterVar({name= "ft_allow_ties", defaultvalue= "No", flags= CV_NETVAR, PossibleValue= CV_YesNo})
-- CNET var that, if activated, only admin can start a "FT N" round
local _ft_admin_calls_only= CV_RegisterVar({name= "ft_admin_calls_only", defaultvalue= "No", flags= CV_NETVAR, PossibleValue= CV_YesNo})
-- CNET var that, if activated (default), player can join an ongoing "FT N" round (via ft_join command), and if not, only admin can add players
local _ft_player_join= CV_RegisterVar({name= "ft_player_join", defaultvalue= "Yes", flags= CV_NETVAR, PossibleValue= CV_YesNo})
-- CNET var that, if activated, is used make so that only players contesting in the "FT N" round can see the result screen
local _ft_show_results_exclusive= CV_RegisterVar({name= "ft_show_results_exclusive", defaultvalue= "No", flags= CV_NETVAR, PossibleValue= CV_YesNo})

-- local var used as timer for the ingame notification
local _callTimer=0

-- local var used to inform the script if elimination mode is enabled in ongoing race
local elimIsPlayed= false
-- local var used to inform the script if combiring mode is enabled in ongoing race
local combiIsPlayed= false
-- [strashEdit] local var used to inform the script if friend mode is enabled in ongoing race
local friendIsPlayed= false
local _friendHUD= true

-- function used to start (as a given player) a "FT N" round (arg=N),
-- or stop the ongoing one (arg=0)
rawset(_G, "ft_first_to", function(player, arg)
    if not _ft_enabled.value then 
        CONS_Printf(player, "[FirstTo] Disabled")
        return
    end

    -- if 'arg' not passed, just inform via console
    if arg==nil then
        if (not firstTo) or firstTo==0 then
            CONS_Printf(player, "[FirstTo] No \"First to\" round is ongoing")
        else
            CONS_Printf(player, "[FirstTo] A \"First to "..firstTo.."\" round is ongoing")
        end
        return
    end

    -- check if user admin in case 'ft_admin_calls_only' enabled
    -- and if so, if user not admin don't allow to go any further
    local b_admin= ((player==server) or IsPlayerAdmin(player))
    if _ft_admin_calls_only.value and not b_admin then
        CONS_Printf(player, "[FirstTo] Command set to \"Admin only\" ...")
        return
    end

    -- check if the user allegedely tried to cancel the current "FT N" round
    local _arg= string.lower(arg)
    if (_arg=="0" or _arg=="stop" or _arg=="cancel" or _arg=="abort" or _arg=="no" or _arg=="off") then
        -- however, cancelling an ongoing round, is only the buisiness of admin
        if b_admin then
            _ft_abort()
            print("[FirstTo] \"First to "..((firstTo>0) and firstTo or "").."\" round aborted")
        else
            CONS_Printf(player,"[FirstTo] Only admin can abort ongoing \"First to\" round")
        end
        return
    end

    -- not clue about battle mode, so not supported ATM
    if not G_RaceGametype() then
        CONS_Printf(player, "[FirstTo] Only available in race mode")
        return
    end

    -- checking that 'arg' is actually a number
    local n= tonumber(arg)
    if not n then
        CONS_Printf(player, "[FirstTo] \"first_to\" takes a number as argument...")
        return
    end

    -- if no ongoing "FT N", start a new one
    if (not firstTo) or (firstTo==0) then
        -- if 'player' not admin, check that he's withing allowed range
        if (not b_admin) and ((n<ft_round_limit.min) or (n>ft_round_limit.max)) then
            chatprintf(player, "\131* only range allowed: min=\130"..ft_round_limit.min.."\131; max=\130"..ft_round_limit.max)
            return
        end
        firstTo= n
        -- print("[FirstTo] \"First to "..(firstTo).."\" round started!")
        chatprint("\135|!| \130\"First to "..n.."\"\128 started. Type \"\131j\128\" in chat to join.")
        _callTimer= FT_CALL_TIMER_DURATION
    --however, in a "FT N" was already ongoing, only the admin can change its length once started
    elseif b_admin then
        -- if firstTo > n then
        --     CONS_Printf(player, "[FirstTo] Can't set a round number lower to previous one...")
        -- elseif firstTo <= n then
            firstTo= n
            print("[FirstTo] Now set to a \"First To "..n.."\"")
        -- end
    else
        CONS_Printf(player,"[FirstTo] Only admin can change ongoing \"First to\" round")
    end

    -- 'player' is automatically added to "FT N"
    if not player.ft_wins then
        player.ft_wins= 0

        -- splitscreen party client experimental compatibily
        if not PartyChecker then
            CONS_Printf(player,"[FirstTo] Local multiplayer isn't supported on this install (missing \"PartyChecker\" util script).")
        else
            if not _t_partyJoinCheck then
                _t_partyJoinCheck= {player}
            else
                table.insert(_t_partyJoinCheck, player)
            end
        end
    end
end)
-- 'first_to' is the console command to start a "FT N" round
COM_AddCommand("first_to", ft_first_to)

-- console cancel command, basically juste "first_to 0" (but still admin only)
COM_AddCommand("ft_cancel", function(player) ft_first_to(0) end, 1)

-- console command to make a player join an ongoin "FT N"
-- programatically speaking, making a player join is just about to making
-- his victory count not 'nil' (so =0 to join): 'player.ft_wins=0'
-- The function associated with this command make all the verifications.
-- 'name' parameter can and should be omitted ('nil'), but if parameter is given (string)
-- then the function tries to make join the player that as given name (however, only admin
-- can make another player join)
COM_AddCommand("ft_join", function(player,name)
    if not _ft_enabled.value then return end
    -- if 'ft_player_join' is disabled, then regular user can't actually use this
    if (not _ft_player_join.value) and (not IsPlayerAdmin(player)) then
        CONS_Printf(player, "[FirstTo] Currently, only admin can use this command")
        return
    end

    -- if not "FT N" member is going on, just don't go further
    if (not firstTo) or (firstTo==0) then
        chatprintf(player, "\131* No \"first to X\" round has been launched")
        return
    end

    -- if a player name was given (parameter 'name') tries to find the matching player (admin only)
    -- otherwise, we just consider that the target player is the one who called the command, and move on
    local target= (not name) and player or nil
    if not target then
        if IsPlayerAdmin(player) then
            for p in players.iterate do
                if p.name==name then
                    target= p
                    break
                end
            end

            if not target then
                CONS_Printf(player, "[FirstTo] Couldn't find player \""..name.."\" to add to the round")
                return
            end
        else
            CONS_Printf(player, "[FirstTo] only admin can make another player join")
            return
        end
    end
    
    -- just adding the targeted player to ongoing "FT N"
    if target.ft_wins == nil then
        target.ft_wins= 0
        chatprint("\130"..target.name.." joined the \"First to "..firstTo.."\" round!")

        -- splitscreen party client experimental compatibily
        -- (only check for party co-players if player wasn't explicitely designed with
        --      parameter 'name')
        if not PartyChecker then
            CONS_Printf(player,"[FirstTo] Local multiplayer isn't supported on this install (missing \"PartyChecker\" util script).")
        elseif not name then
            if not _t_partyJoinCheck then
                _t_partyJoinCheck= {target}
            else
                table.insert(_t_partyJoinCheck, target)
            end
        end
    end
end)

-- admin only console command that changes the amount of a player's win given his name
COM_AddCommand("ft_player_wins", function(player, playername, arg)
    if (not firstTo) or (firstTo<=0) then
        CONS_Printf(player, "[FirstTo] No ongoing\"First to\" round")
        return
    end

    if (playername==nil) and (arg==nil) then
        CONS_Printf(player, "[FirstTo] usage: ft_player_wins \"player name\" number_of_win")
        return
    end

    -- trying to match 'playername' with a player
    local _p= nil
    for p in players.iterate do
        if (p.name==playername) then
            _p= p
            break
        end
    end

    -- player not found, bye bye
    if not _p then
        CONS_Printf(player, "player \""..(playername and playername or "nil").."\" not found")
        return
    end

    -- if 'arg' argument no provided, just informational message
    if not arg then
        if not _p.ft_wins then
            CONS_Printf(player, "player \""..playername.."\" isn't part of the \"First to "..firstTo.."\" round")
        else
            CONS_Printf(player, "player \""..playername.."\" has "..((_p.ft_wins==1) and "1 win" or (_p.ft_wins.."wins")))
        end
    -- admin wanted to remove player from "FT N"?
    elseif arg=='nil' or arg=='none' then
        _p.ft_wins= nil
        CONS_Printf(player, "player \""..playername.."\" no longer part of the \"First to "..firstTo.."\" round")
    -- change the number victories of found player (if 'arg' is a valid number)
    else
        local n= tonumber(arg)
        if not arg then
            CONS_Printf(player, "[FirstTo] Invalid number given \""..arg.."\"")
        else
            n= (n<0) and 0 or ( (n>firstTo) and firstTo or n )
            _p.ft_wins= n
            CONS_Printf(player, "player \""..playername.."\" now set to "..n.." wins")
        end
    end
end, 1)

-- admin only console command that changes the range of necessary victories a regular player can
-- call for a "FT N" (only can call for "FT N" where 'min' < N < 'max' )
COM_AddCommand("ft_round_minmax", function(player, min, max)
    if (not min) and (not max) then
        CONS_Printf(player, "[FirstTo] current range allowed: min="..ft_round_limit.min.."; max="..ft_round_limit.max)
        return
    end

    -- just try patching in case of weird or incomplete user parameter input
    local m= tonumber(min)
    local M= (not max) and ft_round_limit.max or tonumber(max)
    if (not m) or (not M) then
        CONS_Printf(player, "[FirstTo] command take only positive integer as arguments")
        return
    end
    if m>M then
        local _tmp= m
        m= M
        M= _tmp
    end

    ft_round_limit.min= m
    ft_round_limit.max= M
    CONS_Printf("[FirstTo] round limit set to ["..m..","..M.."]")
end, 1)


-- local function that uses an experimental utility script "PartyChecker.lua" (if available)
-- (check: https://github.com/AlexPoilrouge/SRB2Kart_mod_and_misc/tree/master/scripts/PartyChecker)
-- Since that, at the time this script is being written (SRB2Kart 1.3), there is no way for the server
-- to know for sure that several players have join through a local splitscreen party, it cannot flag
-- this player as joining the "FT N" when the party main player asks to join since it cannot know about
-- said party, and since the other party players don't have access to individual console, and therefore
-- the 'ft_join' command...
-- Anyways, using this script, this function looks for players waiting for a 'party checking'
-- (table '_t_partyJoinCheck') and, if they already have been checked for a party membership,
--  fetches their party mates, and add those to the "FT N" round.
local function _partyJoinCheck()
    if (not PartyChecker) or (PartyChecker.waitingPartyCheck)
        or (not _t_partyJoinCheck) or (#_t_partyJoinCheck<=0) 
    then return end
    
    local i= 1
    while i <= #_t_partyJoinCheck do
        local p= _t_partyJoinCheck[i]

        if p and (not PartyChecker.isWaitingPartyCheck(p)) then
            if PartyChecker.isInParty(p) then
                local friends= PartyChecker.getPartyPlayers(p)
                for j=1, #friends do
                    local friend= friends[j]
                    if friend.ft_wins==nil then
                        friend.ft_wins= 0
                        chatprint("\130"..friend.name.." joined the \"First to "..firstTo.."\" round!")
                    end
                end
            end
            table.remove(_t_partyJoinCheck, i)
        else
            i= $+1
        end
    end
end


--- using this boolean to make sure when to play sound and play it just once
local _playSfx= false

-- "ThinkFrame" hook: https://wiki.srb2.org/wiki/Lua/Hooks#ThinkFrame
-- do every in-race frame
addHook("ThinkFrame", do
    -- mod edisable, or not "FT N" ongoing, or not in race mode: nothing to do right?
    if (not _ft_enabled.value) or (firstTo <= 0) or (not G_RaceGametype()) then return end

    _partyJoinCheck()

    -- playing notification sound at a specific time
    if _callTimer>0 then
        if (_callTimer==FT_CALL_TIMER_DURATION-TICRATE)  then
            S_StartSound(nil, sfx_cdfm66)
        end
        _callTimer= $-1
    end
    
    -- counting stuff
    local everyonesDone, totalPlayers= 0, 0
    local contesters= 0
    -- okay, so i'm doing this to verify that this isn't a game abortion
    -- by checking if at least one player as not the PF_TIMEOVER flag
    -- doing this because, when 'karteliminatelast' is inactive, there appears
    -- to be no 'player.realtime' countdown (stuck at a certain value until round end...)
    -- *sigh* sure whatever
    local aborting= true;
    for p in players.iterate do
        if not (p.pflags & PF_TIMEOVER) then
            aborting= false
        end
    end
    -- loop counting num of players, num of "FT N" contesters, player who fnished race
    for p in players.iterate do
        -- except if game's aborted, trying to block the 'exitlevel' countdown
        -- eventhough, that's not always possible because sometimes,
        -- 'exitcountdown' just says "fuck you" apparently...
        if (not aborting) and (p.exiting) or (p.pflags & PF_TIMEOVER) then p.exiting = 99 end
        
        if not p.spectator then
            totalPlayers = $+1
        end
        if (p.ft_wins ~= nil) then
            contesters= $+1
        end
        -- detect players who are "finished"
        -- player with the minimum 'realtime' is the one who won the race
        -- thanks to Tyron on KartKrew's discord for his help
        
        if (p.exiting and p.exiting == 99) or (p.pflags & PF_TIMEOVER) then
        -- if (p.exiting) or (p.pflags & PF_TIMEOVER) then
            -- in elimination mode, spectator are also potential players so...
            if (not p.spectator) or elimIsPlayed then
                everyonesDone = $+1
            end
        end
    end

    -- if there are no contesters if the "FT N" round, might as well drop it
    if contesters==0 then
        print("[FirstTo"..firstTo.."] No contester left, aborting…")
        _ft_abort()
        return
    end

    -- if it has been established that nobody has finished the race, don't need to go further
    if (not everyonesDone) then return end

    if (not server.first_to) then server.first_to= {} end

    -- when everyone has finished the race, but it hasn't been established yet that the race is over
    if (everyonesDone >= totalPlayers or exitcountdown == 8) and (not server.first_to.finished) then
        server.first_to.finished= true;
        server.first_to.finishTimer= 0;

        -- let's check player times to determine who won
        local realtime_min= -1
        local constesters_rt_min= -1
        local winners= {}
        local _skip= false
        local fr_teamstied= false
        --- [strashEdit] handling friendMod
        local recalced, bluescore, orangescore, bossplayer, savedtheworld= nil, nil, nil, nil, nil
        if friendIsPlayed then
            -- [strashbot] FriendMod and FirstToMod cohabitation
            -- needs a modified version of friendsMod
            -- fetching useful info to determine round winners
            recalced, bluescore, orangescore, bossplayer, savedtheworld= FRIENDMOD_GetScores()
            
            fr_teamstied= (bossplayer and bluescore==1) or (bluescore==orangescore)
            -- [strashbot] if FriendMod + Elim there can't be a teams tie
            if elimIsPlayed and fr_teamstied then
                for p in players.iterate do
                    p.FRdata= FRIENDMOD_GetPlayersData(p)
                    if not p.spectator then
                        if(p.FRdata.FRteam==1) then
                            bluescore= 10
                            orangescore= 0
                        else
                            orangescore= 10
                            bluescore= 0
                        end
                        fr_teamstied= false
                        break
                    end
                end
            end
        end
        -- if more than 1 "FT N" contester was in race
        if contesters > 1 then
            -- we look the time of each player and put the best players in table 'winners'
            -- ( winners is in table in case of ties, and so can have multiple winners)
            for p in players.iterate do
                -- [strashEdit] friendMod played
                if friendIsPlayed then
                    -- [strashbot] FriendMod and FirstToMod cohabitation
                    -- needs a modified version of friendsMod
                    -- fetching needed players info to determine round winners
                    if (p.ft_wins == nil) then continue end

                    p.FRdata= FRIENDMOD_GetPlayersData(p)
                    
                    local teamwins= (
                        ( bossplayer and (bluescore==1 or
                                (p.FRdata.FRteam==1 and bluescore>0) or
                                (p.FRdata.FRteam==2 and bluescore==0)
                            )
                        ) or (
                            (p.FRdata.FRteam==1 and bluescore > orangescore) or
                            (p.FRdata.FRteam==2 and orangescore > bluescore)
                        )
                    )
                    if teamwins or fr_teamstied then
                        table.insert(winners, p)
                    end
                elseif (not p.spectator) and ((realtime_min<0) or (p.realtime<=realtime_min)) and not (p.pflags & PF_TIMEOVER) then
                    if (p.ft_wins ~= nil) then
                        -- in case two contesters make a tie
                        if p.realtime==realtime_min then
                            table.insert(winners, p)
                        else
                            winners= {p}
                        end
                        constesters_rt_min= p.realtime
                    end
                    realtime_min= p.realtime
                end
            end
            
            -- canceling winners in there is not absolute winners among contesters (while option 'ft_absolute_winner' is disabled)
            -- ([strashEdit] also accounting for friend mode)
            if (not friendIsPlayed) and ( (constesters_rt_min<0) or ((not combiIsPlayed) and _ft_abs_win.value and (constesters_rt_min>realtime_min)) ) then
                winners= {}
            end
        -- if there was only one contester in the race, we end the 'FT N' round (unless said constester, has no win yet)
        elseif contesters == 1 then
            local _p= nil
            for p in players.iterate do
                if (p.ft_wins~=nil) and (not p.spectator) and ((realtime_min<0) or (p.realtime<=realtime_min)) and not (p.pflags & PF_TIMEOVER) then
                    _p= p
                    break
                end
            end
            if _p then
                if _p.ft_wins>0 then
                    print("[FirstTo"..firstTo.."] Only one contester... ending \"First to "..firstTo.."\" prematurely")
                    _p.ft_last_winner= true
                    server.first_to.winner= {_p}
                    _skip= true
                else
                    print("[FirstTo"..firstTo.."] Only one contester... not counting any win")
                end
            end
        end

        server.first_to.contesters= contesters

        -- skiping winner establishing part, if only one contester
        if _skip then return end

        -- if there are several winners, and ties are not allowed
        -- (or ties not allowed with more than 2 winners in combiring),
        -- we skip don't do anything more: not counting any win
        -- ([strashEdit] + friendMod)
        if (#winners > 1) and (not _ft_allow_ties.value) and ((not combiIsPlayed) or (#winners>2)) and ((not friendIsPlayed) or fr_teamstied) then
            print("[FirstTo"..firstTo.."] Ties DON'T COUNT as several winners :/"..(fr_teamstied and " (fr_teamstied)" or "(nah)"))
        -- if there was an appropriate number of winner
        elseif #winners > 0 then
            -- we flag all the winners
            local n= (_ft_allow_ties.value) and (#winners) or
                (combiIsPlayed and 2 or
                    ((friendIsPlayed and (not fr_teamstied)) and (#winners) or
                        1
                    )
                )
            for i=1, n do
                if i>#winners then break end
                winners[i].ft_wins= $+1
                winners[i].ft_last_winner= true
                -- print("[FirstTo"..firstTo.."] +1 win for "..winners[i].name.." (total: "..winners[i].ft_wins..")")

                -- if the winners are definitive winners (i.e. won the "FT N" round),
                -- we put them is server's winners list
                if winners[i].ft_wins >= firstTo then
                    if server.first_to.winner then
                        table.insert(server.first_to.winner,winners[i])
                    else
                        server.first_to.winner= {winners[i]}
                    end
                end
            end
        end
    -- if it has been established previously that the race is finished
    -- (this is the time where normally, the winner screen is displayed)
    elseif server.first_to.finished then
        -- advancing 'finish_timer' every frame
        server.first_to.finishTimer= $+1


        -- play a sound when asked to
        if _playSfx then
            if server.first_to.winner and sfx_s3kac then
                S_StartSoundAtVolume(nil, sfx_s3kac, 96)
            elseif sfx_s1ce then
                S_StartSoundAtVolume(nil, sfx_s1ce, 96)
            end
            _playSfx= false
        end


        -- [strashbot] FriendMod and FirstToMod cohabitation
        -- needs a modified version of friendMod
        -- I prefer displaying the FTmod victory screen if the
        -- "First to X" matched is settled during a team race
        if friendIsPlayed and server.first_to.winner then
            _friendHUD= FRIENDMOD_ToggleHUDstuff(false)
        end
        -- at the end of the 'finish_timer'
        -- if (server.first_to.finishTimer > FT_SCORESCREEN_DURATION) or (exitcountdown==1) then
        --     -- checking if there is a round winner, if so, stopping round, cleaning up
        --     if server.first_to.winner then
        --         for p in players.iterate do
        --             p.ft_wins= nil
        --         end
        --         firstTo= 0
        --     end

        --     -- exiting level
        --     G_ExitLevel()
        -- end
        local manualexit= false;
        for p in players.iterate do
            if (not p.mo) or (p.spectator) then
                continue
            end
            if p.exiting==99 and not p.ft_stasis then
               p.ft_stasis = 5 * TICRATE - 2
            end
            if p.ft_stasis==nil then
                p.ft_stasis= FT_SCORESCREEN_DURATION
            else
                p.ft_stasis= $ - 1
                if p.ft_stasis>1 and not manualexit then
                    p.exiting= 2
                else
                    manualexit= true
                    p.pflags = $ & (~PF_TIMEOVER)
                    if server.first_to.winner then
                        p.ft_wins= nil
                    end
                end
            end
        end
        if manualexit then
            if server.first_to.winner then firstTo= 0 end
            -- COM_BufInsertText(server, "exitlevel")
            G_ExitLevel()
            if elimIsPlayed then
                COM_BufInsertText(server, "allowteamchange 1")
                if Elim_endWinRound then Elim_endWinRound() end
            end
        end 
    end
end)

-- classical helper function to draw a string in hud centered around given coordinates
-- (this versions, also returns the width of the drawn string, to reuse for placement purposes)
local function drawStringCenter(v, x, y, str, flags, tt)
	local w = v.stringWidth(str, flags, tt)
    v.drawString(x - (w / 2), y, str, flags, tt)
    return w
end

-- sprite collection for notification animation
local spr_twinkle={"SGNSA0","SGNSB0","SGNSC0","SGNSD0","SGNSE0","SGNSF0","SGNSG0","SGNSH0","SGNSI0",}
local a_spr_twinkle=nil


-- [strashbot] FriendMod and FirstToMod cohabitation function
-- needs an edited version of FriendMod
-- obviously this code is very similar to FriendMod's hud.add function
-- since I need to be able to draw some stuff while fatching the
-- friendMod's layout
local function friendModFriendlyHUD(v,p,dupadjust,duptweak,flags)
    if ((p.ft_wins==nil) and (_ft_show_results_exclusive.value)) then return end;

    -- [strashbot] FriendMod and FirstToMod cohabitation
    -- needs a modified version of FriendMod
    -- I need some infos from friendMod to properly display everything
    local recalc, bluescore, orangescore, bossplayer, savedtheworld= FRIENDMOD_GetScores()
    if ((not server.first_to) or (not server.first_to.finished)) then
        return
    end

    local _finished= function(player)
        if p.spectator or (not p.mo) then
            return true
        elseif p.pflags & PF_TIMEOVER then
            return true
        elseif p.exiting then
            return true
        end
        return false
    end

    local gfxMedal= v.cachePatch("GOTITA")
    local sortedplayers = {}
    local str1Len, str2Len, str= 0, 0, ""
    local leftoffset, rightoffset = 0, 0
    if not bossplayer then
        for q in players.iterate do
            if not q.FRdata then continue end
            if q.mo and (not q.spectator) and q.FRdata.FRready then
                table.insert(sortedplayers, q)
            end
        end
        table.sort(sortedplayers, function(a, b)
            if not (_finished(a) == _finished(b)) then
                return _finished(a)
            end
            return a.FRdata.personalscore > b.FRdata.personalscore
        end)
        for _, q in ipairs(sortedplayers)
            if q.ft_wins==nil then continue end

            local finishflag = V_ALLOWLOWERCASE
            if not _finished(q) then
                finishflag = $|V_GRAYMAP|V_50TRANS
            end
            local tempname = q.name
            if q == savedtheworld then
                finishflag = (leveltime % 2) and finishflag or V_ALLOWLOWERCASE|V_YELLOWMAP
                if leveltime % 50 >= 25 then
                    tempname = "CLUTCH!"
                end
            end

            local qwins= q.ft_wins - (
                (q.ft_last_winner and server.first_to.finishTimer<TICRATE) and
                    1
                or  0
            )
            if(server.first_to.finishTimer==TICRATE) _playSfx= true end
            if (not splitscreen and q.FRdata.FRteam == p.FRdata.FRteam) or (splitscreen and q.FRdata.FRteam == 1) or (p.spectator and q.FRdata.FRteam == 1) then
                str1Len= v.stringWidth(q.FRdata.teamPrefix..tempname.." - "..q.FRdata.personalscore, finishflag, "thin")
                str= " x "..qwins
                str2Len= v.stringWidth(str, finishflag, "thin")
                v.drawString(151-str1Len, 45+leftoffset, str, finishflag, "thin-right")
                v.drawScaled((142-str1Len-str2Len+duptweak.x)*FRACUNIT, (45+leftoffset+duptweak.y)*FRACUNIT, FRACUNIT/2, gfxMedal, flags)
                leftoffset = $ + 10
            else
                str1Len= v.stringWidth(q.FRdata.teamPrefix..q.FRdata.personalscore.." - "..tempname, finishflag, "thin")
                str= qwins.." x "
                str2Len= v.stringWidth(str, finishflag, "thin")
                v.drawString(169+str1Len, 45+rightoffset, str, finishflag, "thin")
                v.drawScaled((169+str1Len+str2Len+duptweak.x)*FRACUNIT, (45+rightoffset+duptweak.y)*FRACUNIT, FRACUNIT/2, gfxMedal, flags)
                rightoffset = $ + 10
            end
        end
    elseif not p.spectator then
        local sortedplayers = {}
        for q in players.iterate
            if q.mo and not q.spectator and q.FRdata.FRready then
                table.insert(sortedplayers, q)
            end
        end
        table.sort(sortedplayers, function(a, b)
            if(a.FRdata.FRteam~=b.FRdata.FRteam) then
                return a.FRdata.FRteam==1
            end
            return a.realtime < b.realtime
        end)
        for _, q in ipairs(sortedplayers)
            local qwins= q.ft_wins - (
                (q.ft_last_winner and server.first_to.finishTimer<TICRATE) and
                    1
                or  0
            )
            if(server.first_to.finishTimer==TICRATE) _playSfx= true end
            local finishflag = V_ALLOWLOWERCASE
            if not _finished(q) then
                finishflag = $|V_GRAYMAP|V_50TRANS
            end
            str1Len= v.stringWidth(q.FRdata.teamPrefix..q.name, finishflag, "thin")
            str= qwins.." x "
            str2Len= v.stringWidth(str, finishflag, "thin")
            v.drawString(151-str1Len, 45 + leftoffset, str, finishflag, "thin-right")
            v.drawScaled((142-str1Len-str2Len+duptweak.x)*FRACUNIT, (45+leftoffset+duptweak.y)*FRACUNIT, FRACUNIT/2, gfxMedal, finishflag)
            leftoffset = $ + 10
        end
    end
    if _ft_player_join.value then
        drawStringCenter(v,160,192,"-= type \"j\" in chat to joint FT "..firstTo.." =-", V_ALLOWLOWERCASE, "small")
    end
end

-- hud drawing function: https://wiki.srb2.org/wiki/Lua/Functions#hud.add
hud.add(function(v, p)
    -- not drawing on hub, if mod not enables or no round launched or not in race mode
    -- (also making sure drawn only once in case of splitscreen)
    if (displayplayers[0]~=p) or (not _ft_enabled.value) or (firstTo <= 0) or (not G_RaceGametype()) then return end

    -- computing margin in case of stupid resolution ratio
    local dupadjust = {x=(v.width()/v.dupx()), y=(v.height()/v.dupy())}
	local duptweak = {x=((dupadjust.x - 320)/2), y=((dupadjust.y - 200)/2)}
    local flags= V_SNAPTOLEFT|V_HUDTRANS|V_SNAPTOTOP

    if(friendIsPlayed and _friendHUD and (not elimIsPlayed) ) then
        friendModFriendlyHUD(v,p,dupadjust,duptweak,flags)
        return
    end

    -- loading sprites (once, if not done)
    if not a_spr_twinkle then
        a_spr_twinkle= {}
        for i=1, #spr_twinkle do
            table.insert(a_spr_twinkle,v.cachePatch(spr_twinkle[i]))
        end
    end

    -- block that draws the notification when needed
    if (not _ft_player_join.value and p.ft_wins~=nil) or _callTimer>0  or ((leveltime<(6*TICRATE)) and (leveltime>=0)) or p.spectator then
        local _str1= "First to "..firstTo.." !"
        local _str2= (p.ft_wins==nil) and "\"j\" in chat to join" or "Good luck!"
        local _timer= (p.spectator) and (TICRATE+1) or ((leveltime<(6*TICRATE)) and ((6*TICRATE)-leveltime) or _callTimer)
        local _M= (leveltime<(6*TICRATE)) and (6*TICRATE) or FT_CALL_TIMER_DURATION
        local _t= ( (_timer>(_M-TICRATE)) and ((_timer-_M+TICRATE)/2)
                or  (_timer<TICRATE) and ((TICRATE-_timer)/2)
                    or 0 )
        --fuck splitscreen, just gonna leave it as is
        -- if not splitscreen then
            -- if p.ft_wins==nil then
                local wm= drawStringCenter(v,160,1-_t-duptweak.y,_str1,V_6WIDTHSPACE|V_ALLOWLOWERCASE, "small")
                local tmp= drawStringCenter(v,160,8-_t-duptweak.y,_str2,V_6WIDTHSPACE|V_ALLOWLOWERCASE, "small")
                wm= (wm<tmp) and tmp or wm
                v.drawScaled((160-wm/2-8+duptweak.x)*FRACUNIT,(8-_t)*FRACUNIT, FRACUNIT/2,(a_spr_twinkle[((_timer/4)%9)+1]),flags)
                v.drawScaled((160+wm/2+8+duptweak.x)*FRACUNIT,(8-_t)*FRACUNIT, FRACUNIT/2,(a_spr_twinkle[((_timer/4)%9)+1]),flags)
            -- end
        -- end
    end

    -- block that draw, during the race (as long as race not finished), a recap of the contesting player's win track
    if ((not server.first_to) or (not server.first_to.finished)) then 
        if not splitscreen then
            if (p.ft_wins ~= nil) then
                v.drawString(310+duptweak.x, 1-duptweak.y, "First to "..firstTo.." : "..p.ft_wins..(p.ft_wins==1 and " win" or " wins"), V_6WIDTHSPACE|V_ALLOWLOWERCASE|V_50TRANS, "small-right")
            end
        elseif (_callTimer<=0) and (leveltime>=(6*TICRATE))
            local i=0
            for dp in displayplayers.iterate do
                if not (dp and (dp.ft_wins ~= nil)) then continue end

                -- heh.
                local x= (splitscreen > 1) and (((1+(i%2))*(160)+((i%2)*duptweak.x))-5) or (310+duptweak.x)
                local y= (splitscreen < 2) and (i*100+1-((i+1)%2)*duptweak.y) or ((i>>1)*100+1+(((i>>1)+1)%2)*(-duptweak.y))

                v.drawString(x, y, "FT"..firstTo.." : "..dp.ft_wins.." w", V_6WIDTHSPACE|V_ALLOWLOWERCASE|V_50TRANS, "small-right")
                i= $+1
            end
        end
        return
    end

    -- if 'ft_show_results_exclusive' enabled, don(t draw result screen for non-contesters
    if ((p.ft_wins==nil) and (_ft_show_results_exclusive.value)) then return end;


    -- following code  implements victory/result screen

    v.fadeScreen(65280, 16)	

	v.drawString(160, 12, "* FIRST TO "..(firstTo).." *", 0, "center")
    v.drawFill(1-duptweak.x, 26, dupadjust.x-2, 1, 0)

    -- a "FT N" winner as been dediced, draw victory screen
    if server.first_to.winner then
        -- for each winner (in case of tie), draw all "facewant" images aligned, centered in the middle of the screen
        -- and display appropriate text
        local n= #server.first_to.winner
        drawStringCenter(v,160,67,((n>1) and "Winners are" or "Winner is"),V_6WIDTHSPACE|V_ALLOWLOWERCASE,"thin")
        local _str= ""
        for i= 1, n do
            local skin= server.first_to.winner[i].mo.skin or "sonic"
            local facewant= skins[skin].facewant
            local skincolor= server.first_to.winner[i].mo.color
            local colormap= v.getColormap(skin, skincolor)
            local x= 160-((n%2)*16+(n>>1)*32)+(i-1)*32
            v.draw(x+duptweak.x, 92+duptweak.y, v.cachePatch(facewant), flags, colormap)


            _str= $..(server.first_to.winner[i].name)..((i<n) and " & " or "")
        end
        v.drawString(160,78,_str, V_6WIDTHSPACE|V_ALLOWLOWERCASE, "center")
        drawStringCenter(v,160,128,"CONGRATULATIONS!",0,"thin")

        -- don't forget to play little victory sound :)
        if server.first_to.finishTimer==(TICRATE/2) then
            _playSfx= true
        end

        -- everything is done
        return
    end
    
    local blueprefix, orangeprefix
    if(friendIsPlayed and FRIENDMOD_GetScores) then
        local a, b, c, d, e
        a, b, c, d ,e, blueprefix, orangeprefix = FRIENDMOD_GetScores()
    end
    -- following is about drawing the results screen
    local i=1
    for player in players.iterate do
        -- for every players that is a contester
        local wins= player.ft_wins
        if wins ~= nil then
            local name= player.name or "NULL"
            if(friendIsPlayed and ((player.FRdata.FRteam==1 and blueprefix) or (player.FRdata.FRteam==2 and orangeprefix))) then
                name= (player.FRdata.FRteam==1 and blueprefix or orangeprefix)..name.."\x80"
            end
            local y= 23+i*10

            -- draw their name of left side of the screen
            v.drawString(150, y, name, V_6WIDTHSPACE|V_ALLOWLOWERCASE, "thin-right")

            -- (if only one contester, display "NO CONTEST" as result :( )
            if server.first_to.contesters and server.first_to.contesters <= 1 then
                v.drawString(170, y, "NO CONTEST", V_6WIDTHSPACE|V_ALLOWLOWERCASE, "thin")
                return
            end

            -- and display the number of wins as an horizontal stack of medal
            local gfxMedal= v.cachePatch("GOTITA")
            if wins > 0 then
                if wins <= 5 then
                    if player.ft_last_winner then
                        -- actually, display one less medal...
                        for j=1, (wins-1) do
                            v.drawScaled((170+(j-1)*7+duptweak.x)*FRACUNIT, (y+2+duptweak.y)*FRACUNIT, FRACUNIT/2, gfxMedal, flags)
                        end
                        -- ... and wait a little bit to display the last medal
                        -- (don't forget the cool little sound)
                        if server.first_to.finishTimer==TICRATE then
                            _playSfx= true
                        end
                        if server.first_to.finishTimer>=TICRATE then
                            v.drawScaled((170+(wins-1)*7+duptweak.x)*FRACUNIT, (y+2+duptweak.y)*FRACUNIT, FRACUNIT/2, gfxMedal, flags)
                        end
                    else
                        for j=1, wins do
                            v.drawScaled((170+(j-1)*7+duptweak.x)*FRACUNIT, (y+2+duptweak.y)*FRACUNIT, FRACUNIT/2, gfxMedal, flags)
                        end
                    end
                -- if there are more than 5 win, display just one medal following by the number of win
                else
                    v.drawScaled((170+duptweak.x)*FRACUNIT, (y+2+duptweak.y)*FRACUNIT, FRACUNIT/2, gfxMedal, flags)
                    if player.ft_last_winner then
                        if server.first_to.finishTimer==TICRATE then
                            _playSfx= true
                        end
                        if server.first_to.finishTimer>=TICRATE then
                            v.drawString(178, y, ("x "..wins), V_6WIDTHSPACE|V_ALLOWLOWERCASE, "thin")
                        else
                            v.drawString(178, y, ("x "..(wins-1)), V_6WIDTHSPACE|V_ALLOWLOWERCASE, "thin")
                        end
                    else
                        v.drawString(178, y, "x "..wins, V_6WIDTHSPACE|V_ALLOWLOWERCASE, "thin")
                    end
                end
            end

            i= $+1
        end
    end
    -- don't forget to display this important notice!
    if _ft_player_join.value then
        drawStringCenter(v,160,192,"-= type \"j\" in chat to enter =-", V_ALLOWLOWERCASE, "small")
    end
end)


-- local boolean used to inform if the compatible mod check has been made
local _mod_check= false
-- if it exists, the "elimination" mode main variable
local _el_enabled= nil
-- if it exists, the "combiring" mode main variable
local _combi_enabled= nil

-- "MapLoad" hook: https://wiki.srb2.org/wiki/Lua/Hooks#MapLoad
-- stuff to do before new race
addHook("MapLoad", function(mapnum)
    _partyJoinCheck()

    -- check if we in race mode
    if not G_RaceGametype() then
        return
    end

    -- some clean up, of the stuff used to determine last results
    for player in players.iterate do
        player.ft_last_winner= nil
        if firstTo<=0 then
            player.ft_wins= nil
        end
        player.ft_stasis= nil
    end
    server.first_to= nil

    -- check if compatible mods are there, if it has never been done
    if not _mod_check then
        _el_enabled= CV_FindVar("elimination")
        _combi_enabled= CV_FindVar("combi_active")
        _mod_check= true
    end

    -- is this race gonna be in elimination mode?
    elimIsPlayed= (_el_enabled and _el_enabled.value and not (mapheaderinfo[mapnum].levelflags & LF_SECTIONRACE))
    -- is this race gonna be in combiring mode?
    combiIsPlayed= (_combi_enabled and _combi_enabled.value)
    -- [strashEdit] is this race gonna be in friend mode?
    friendIsPlayed= FRIENDMOD_CheckTeams and FRIENDMOD_CheckTeams()
    -- [strashbot] FriendMod and FirstToMod cohabitation
    -- needs an modified version of FriendMod
    -- this prevents FriendMod's hud stuff to be drawn
    -- when not in a team match
    _friendHUD= (friendIsPlayed and FRIENDMOD_ToggleHUDstuff(friendIsPlayed and (not elimIsPlayed)))
end)

-- "NetVars" hook: https://wiki.srb2.org/wiki/Lua/Hooks#MapLoad
addHook("NetVars", function(net)
    -- all this stuff needs to be the same for everyone, yeah
    if firstTo~=nil then firstTo= net($) end
    
    elimIsPlayed= net($)
    combiIsPlayed= net($)
    friendIsPlayed= net($)
end)

-- "PlayerMsg" hook: https://wiki.srb2.org/wiki/Lua/Hooks#PlayerMsg
-- syntax sugar via chat
addHook("PlayerMsg", function(source, msgtype, target, msg)
    if (not _ft_enabled.value) or (msgtype != 0) then return end

    -- if they are allowed to ('ft_player_join' disabled), user can join an ongoing "FT N" round by typing "j" in chat
    if (_ft_player_join.value) and (string.lower(msg) == "j") and (source.ft_wins == nil) and firstTo and (firstTo>0) then
        COM_BufInsertText(source, "ft_join")

        return
    end
    
    -- players can launch a "FT N" round (where N within authorized range, see "ft_round_minmax")
    -- by typing "first to N" in chat
    local n= tonumber( string.match(string.lower(msg),"^first[ _]?to[_ ]?([0-9]+)$") )
    if n and n>0 and n<=999 then
        ft_first_to(source, n)

        return
    end
end)
