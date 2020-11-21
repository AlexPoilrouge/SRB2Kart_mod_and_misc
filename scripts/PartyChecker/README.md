#PartyChecker



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

- `PartyChecker.getParty(player)` : takes a player (`player_t`) has argument. Returns an integer that is equal to 0 if player not in a party, otherwise the integer is formated as such: if *player* is in the same party as the player number 1 (player at index 1 in *players*), then first bit is 1, 0 otherwise; if *player* is in the same party as the player number 2, the second bit of the integer is 1, 0 otherwise; etc. up to player/bit number 16.

- `PartyChecker.isInParty(player)` : takes a player (`player_t`) has argument. Returns wether or not this player is in a party.

- `PartyChecker.isWaitingPartyCheck(player)`:

