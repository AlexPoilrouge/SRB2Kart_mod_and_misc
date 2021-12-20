# PartyChecker


#### Distribution

I allow to this work to be modified for anyone's need or purpous.
However, if said modification is to be published, I ask to be credited for my original work.

Thank you.



#### About

As of version 1.3, SRB2kart does not provide a ways for a lua script to detect in players joined the server individually, or in a splitscreen party. This script is a workaround using not so elegant tricks to be able to detect such scenario.



#### How to use

##### Activate

*PartyChecker.lua* is a "utility script". Just load it like any other lua script for you server at the same time as your other scripts so that these other scripts might use the tools provided by *PartyChecker*.


##### Tools

When *PartyChecker.lua* is loaded, it allocates a global object `PartyChecker`. Other scripts can verify this tool is available by testing the existence of this object.

###### Attribute

- `PartyChecker.waitingPartyCheck` : this boolean is set to `true` whenever the process of grouping players in parties, wether they are playing locally together or not, has to be done. Due to the functionnalites available to lua script in SRB2Kart, this verification can't be done at all time. So, if players join in a time where verification is not possible, this boolean is set to `true`, and will be set to `false` once *PartyChecker* has establish wether they are in splitscreen party or not.

###### Functions

- `PartyChecker.getParty(player)` : takes a player (`player_t`) as argument. Returns an integer that is equal to 0 if player not in a party, otherwise the integer is formated as such: if *player* is in the same party as the player number 1 (player at index 1 in *players*), then first bit is 1, 0 otherwise; if *player* is in the same party as the player number 2, the second bit of the integer is 1, 0 otherwise; etc. up to player/bit number 16. This includes himself, meaning that if said player is player number *k*, then the k-th bit will be set to 1 (except if player not in a party to begin with, ofc).

- `PartyChecker.isInParty(player)` : takes a player (`player_t`) as argument. Returns a boolean wether or not this player is in a party.

- `PartyChecker.isWaitingPartyCheck(player)` : takes a player (`player_t`) as argument. Returns a boolean not this player has been "party checker" (i.e.: already verified that he is the member of a splitscreen party or not)

- `PartyChecker.getPartyPlayers(player)` : takes a player (`player_t`) as argument. Returns a table that contains all the players that are in the same splitscreen party has this player (including himself). If said player is not in a party, it will return an empty table

###### Hook

- `PartyChecker.add_registeredPartyHook(function)` : adds a “ *registeredParty* ” hook. Such hook (given as argument) is a function (no returns) that parameter should be expected to be a table containing a list of players that forms a party. This function well then be called each time a party is confirmed. If a player is confirmed not to be in a party, then the argument passed to the function will still be a table containing just this player.

