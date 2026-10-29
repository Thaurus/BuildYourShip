--!strict
-- Every sound in the game. Values starting with "rbxasset://" are sounds that
-- ship with the Roblox client. Empty strings are optional slots: paste a
-- Creator Store audio id ("rbxassetid://123456") to enable them.
--
-- "EXPLOSION" means: use Roblox's built-in Explosion sound (an invisible,
-- harmless Explosion instance is spawned on the client).

return {
	-- Combat
	CannonFire = "EXPLOSION",
	Explosion = "EXPLOSION",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Impact = "rbxasset://sounds/action_jump_land.mp3",
	Crash = "rbxasset://sounds/action_jump_land.mp3",
	Thunder = "EXPLOSION",

	-- World and ship
	OceanLoop = "", -- looping waves ambience
	WindLoop = "", -- looping wind for storms
	Rowing = "rbxasset://sounds/action_swim.mp3",
	Harvest = "rbxasset://sounds/clickfast.wav",
	CratePickup = "rbxasset://sounds/action_get_up.mp3",

	-- Music (looping); one per zone, plus the drydock
	MusicBay = "",
	MusicOpenSea = "",
	MusicFarReaches = "",
	MusicDrydock = "",

	-- UI
	Pop = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/clickfast.wav",
}
