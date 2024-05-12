# TWLC2 v1.1.0.7
_!!! Remove `-master` when extracting into your `interface/addons` folder !!!_<BR><BR>
Addon to help with Turtle WoW Loot Council Raids<BR><BR>

<hr>
If you like my work consider buying me a coffee !<br> 
https://ko-fi.com/xerron <br>
https://paypal.me/xerroner <br>
<hr>

## v1.1.0.7
Naxxramas tokens added.

## v1.1.0.6
Consumables how show in player details.<br>
Consumables score now shows up as `Buffs` in voting panel.<br>
Raid leader can now set need options (bis/ms/os/xmog).<br>

## v1.1.0.5
New color theme, blue.<br>
Added token rewards for AQ items.<br>
Fix for can't vote issue.<br>
Window will stay closed if closed from X button if others are voting.<br>

## v1.1.0.4
Voting window, for officers, will pop up only after everyone in the raid has picked (or the pick time ended).<Br>
The disenchant button has a new icon, and tooltip.<Br>
CL tooltips have class colors.<Br>
New display of which officers voted instead of number.<Br>
Removed all time factors, time to pick is now fixed based on nr of itmes, 25, 30, 35, 45, 60.<Br>
Time to vote is also fixed based on the number of items, 45/60/80/100/120.

## v1.1.0.3
Added option to auto ML Hourglass Sand to a raid member.<br>
Use `/twlc set sandcollector [name]` to set a collector and <Br>
`/twlc set sand on/off` to toggle auto ML.<br> 
Added option to ML an item to a disenchanter.<br>
Use `/twlc set disenchanter/enchanter [name]`.<Br>
`/twlc search [query]` now works for items too. Example: <br>
`/twlc search nefarian` will output people who got items with text 'nefarian' in item name (ex: Head of Nefarian)

## v1.1.0.2
Fixes not being able to vote if not everyone in raid had the TWLC2c addon 

## v1.1.0.1 - Horde Sattelite
Added option to set a horde sattelite player that can ML and broadcast horde loot<br>
Use `/twlc set sattelite [name]` to set it<br>
Added icons with name tooltips for which CL voted<br>
Added attendance data, disable for now. 

## v1.1.0.0 - First Major Update
Changed comm channel to `TWLC2`<br>
Items for LC get sent via `preloadInVoteFrame=` in Prepare Broadcast (first step of Broadcast Loot)
<hr>

## v1.0.2.3
`/twlc autoassist` - Toggle autoassit for CL/Officers on or off<Br>
Infinite loop fix for autoassist

## v1.0.2.2
`/twlc scale [0.5-2]` - Sets main frame scale from 0.5x to 2x<Br>
`/twlc alpha [0.2-1]` - Sets main frame opacity from 0.5 to 1<br>
* **Done Voting** button for when you're done voting current item, or just don't wanna vote for current item<Br>
* Ability to resize the main window from 5 to 15 visible players<br> 


When enabled (from the minimap button, disabled by default), and the **Raid Leader** opens boss loot frame, the addon frame will pop up
allowing him to `broadcast` the loot to the raid.<BR>
![broadcast button](https://imgur.com/kxV59t1.png)

Raiders will get item frames and options to pick for each item: BIS/MS/OS/pass<BR>
***Note:** Raiders require https://github.com/CosminPOP/TWLC2c addon for pick frames*<Br>
![loot frame](https://i.imgur.com/FS2NMC5.png)

After the picking time (number of items * 30s) has passed, officers will get a voting time
(number of items * 60s). Officers will also see the current raider's items.<BR>

![voting time](https://imgur.com/oRrwY4E.png)

Clicking a player in the player list will show that player's loot history<Br>

![loot history](https://imgur.com/PZymm6u.png)

After the voting time has passed, the Raid Leader can distribute loot based on votes, if there are no vote ties.<BR>

Loot can also be distributed if you right-click on a raider frame.<Br>

![distribute loot via raider list click](https://imgur.com/4ywEWTr.png)

In case there is a vote tie a `ROLL VOTE TIE` button will pop up. Pressing it will ask tie raiders to roll.<BR>

![rollframe](https://imgur.com/cqaJlbf.png)

Rolls are recorded and shown to officers. ML can distribute the item based on the roll winner<Br>

![rollwinner](https://imgur.com/886zw8y.png)

##Slashcommands[RL]:<br>
`/twlc add [name]` - Adds `name` to the loot council member list<br>
`/twlc rem [name]` - Removes `name` from the loot council member list<br>
`/twlc list` - Lists the loot council member list <Br>
`/twlc who` - Lists people with the addon <Br>
`/twlc set ttnfactor [sec]` - Sets the time available to players to pick for each item (final duration is number of items * this factor, in seconds)<Br>
`/twlc set ttvfactor [sec]` - Sets the time available to council members to vote for each item (final duration is number of items * this factor, in seconds)<Br>
`/twlc set ttr [sec]` - Sets the time available to players to roll in a vote tie case<Br>
`/twlc synchistory` - Syncs loot history with other people with the addon.<Br>
`/twlc debug` - Toggle debugging on or off<Br>
<Br>



Known bugs:
* Icons of Items you haven't seen don't show up in the `replaces` fields or show up as `?` icon.
