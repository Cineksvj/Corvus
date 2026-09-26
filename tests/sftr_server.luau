--!nocheck
-- "Steal From The Rich" world + simulated game server for the offline harness.
-- Mechanics follow the decompiled client scripts in the SFTR dump (see comments below).
-- Requires tests/mock_roblox.luau to be loaded first.

local fmt = string.format
local V = Vector3.new
local make = Sim.make

---------------------------------------------------------------------------
-- Game data (values copied from the SFTR dump's MODULE DATA section)
---------------------------------------------------------------------------
local AreaDataModule = {
	LEGACY_IDS = { Jeweller = "Jeweler", MeteoriteCollector = "DemonKing", Overlord = "Astronaut", Warlord = "GoldTycoon", Smuggler = "MuseumOwner", Tycoon = "PirateCaptain", Collector = "MafiaBoss", Banker = "Celebrity" },
	RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Godly", "Secret", "Divine", "Hacked", "OG", "Celestial" },
	Areas = {
		{ Id = "Grandpa", Order = 1, DisplayName = "Grandpa's House", NpcName = "Grandpa", RecommendedSpeed = 20, NpcSpeed = 20, NpcReturnSpeed = 75, NpcCatchup = 7, NpcHoldSeconds = 1.4, NpcCap = 15000, TrailMultiplier = 1, UnlockCost = 0, CrateModel = "CartonBox", AreaPart = "Area 1", Ambience = 9112777821, NpcPlain = true, CrateTiers = { "Common", "Rare", "Epic" }, Items = {} },
		{ Id = "Jeweler", Order = 2, DisplayName = "Jeweler's Shop", NpcName = "Jeweler", RecommendedSpeed = 900, NpcSpeed = 900, NpcReturnSpeed = 5100, NpcCatchup = 4, NpcHoldSeconds = 1.3, NpcCap = 85000, TrailMultiplier = 1.5, UnlockCost = 25000, CrateModel = "CartonBox", AreaPart = "Area 2", Ambience = 9112787259, CrateTiers = { "Rare", "Epic", "Legendary" }, Items = {} },
		{ Id = "Archeologist", Order = 3, DisplayName = "Dig Site", NpcName = "Archeologist", RecommendedSpeed = 10000, NpcSpeed = 10000, NpcReturnSpeed = 69000, NpcCatchup = 4, NpcHoldSeconds = 1.2, NpcCap = 2000000, TrailMultiplier = 2, UnlockCost = 250000, CrateModel = "CartonBox", AreaPart = "Area 3", Ambience = 130346403665301, CrateTiers = { "Epic", "Legendary", "Mythic" }, Items = {} },
		{ Id = "MafiaBoss", Order = 4, DisplayName = "Mafia Boss's Vault", NpcName = "Mafia Boss", RecommendedSpeed = 40000, NpcSpeed = 45000, NpcReturnSpeed = 378000, NpcCatchup = 7, NpcHoldSeconds = 1.06, NpcCloseUntil = 150000, NpcCap = 50000000, TrailMultiplier = 2.5, UnlockCost = 2500000, CrateModel = "CartonBox", AreaPart = "Area 4", Ambience = 1848109123, AmbienceVolume = 0.03, CrateTiers = { "Legendary", "Mythic", "Godly" }, Items = {} },
		{ Id = "Celebrity", Order = 5, DisplayName = "Celebrity's Mansion", NpcName = "Celebrity", RecommendedSpeed = 170000, NpcSpeed = 323000, NpcReturnSpeed = 1230000, NpcCatchup = 9.6, NpcHoldSeconds = 1, TrailMultiplier = 3, UnlockCost = 25000000, CrateModel = "CartonBox", AreaPart = "Area 5", Ambience = 105787210915440, AmbienceVolume = 0.03, CrateTiers = { "Mythic", "Godly", "Celestial" }, Items = {} },
		{ Id = "PirateCaptain", Order = 6, DisplayName = "Pirate Ship", NpcName = "Pirate Captain", RecommendedSpeed = 700000, NpcSpeed = 1750000, NpcReturnSpeed = 6900000, NpcCatchup = 7, NpcHoldSeconds = 0.79, TrailMultiplier = 3.5, UnlockCost = 250000000, CrateModel = "CartonBox", AreaPart = "Area 6", Ambience = 1837779005, AmbienceVolume = 0.03, CrateTiers = { "Godly", "Celestial", "Demon" }, Items = {} },
		{ Id = "MuseumOwner", Order = 7, DisplayName = "Museum", NpcName = "Museum Owner", RecommendedSpeed = 2500000, NpcSpeed = 7500000, NpcReturnSpeed = 26700000, NpcCatchup = 7, NpcHoldSeconds = 0.73, TrailMultiplier = 4, UnlockCost = 2500000000, CrateModel = "CartonBox", AreaPart = "Area 7", Ambience = 9045766377, AmbienceVolume = 0.03, CrateTiers = { "Celestial", "Demon", "Hacked" }, Items = {} },
		{ Id = "GoldTycoon", Order = 8, DisplayName = "Gold Tycoon's Fortress", NpcName = "Gold Tycoon", RecommendedSpeed = 18000000, NpcSpeed = 55000000, NpcReturnSpeed = 249000000, NpcReturnMult = 7, NpcCatchup = 5, NpcHoldSeconds = 0.64, TrailMultiplier = 7, UnlockCost = 25000000000, CrateModel = "CartonBox", AreaPart = "Area 8", CrateTiers = { "Demon", "Hacked", "Rainbow" }, Items = {} },
		{ Id = "Astronaut", Order = 9, DisplayName = "Space Station", NpcName = "Astronaut", RecommendedSpeed = 700000000, NpcSpeed = 2000000000, NpcReturnSpeed = 13200000000, NpcReturnMult = 5, NpcNearHold = 17, NpcCatchup = 5, NpcHoldSeconds = 0.52, TrailMultiplier = 3.5, UnlockCost = 250000000000, CrateModel = "CartonBox", AreaPart = "Area 9", Ambience = 9112795571, AmbienceVolume = 0.03, CrateTiers = { "Hacked", "Rainbow", "Secret" }, Items = {} },
		{ Id = "DemonKing", Order = 10, DisplayName = "Demon King's Lair", NpcName = "Demon King", RecommendedSpeed = 2500000000, NpcSpeed = 12500000000, NpcReturnSpeed = 75000000000, NpcCatchup = 4, NpcHoldSeconds = 0.64, TrailMultiplier = 14, UnlockCost = 2500000000000, CrateModel = "CartonBox", AreaPart = "Area 10", Ambience = 124004202059646, AmbienceVolume = 0.03, CrateTiers = { "Rainbow", "Secret", "Divine" }, Items = {} },
	},
}
function AreaDataModule:GetArea(id)
	for _, a in ipairs(self.Areas) do
		if a.Id == id or a.Id == self.LEGACY_IDS[id] then
			return a
		end
	end
	return nil
end
function AreaDataModule:GetAreas()
	return self.Areas
end
function AreaDataModule:GetCrateTiers(id)
	local a = self:GetArea(id)
	return a and a.CrateTiers
end
Sim.AreaData = AreaDataModule

local function trail(order, id, name, rarity, cost, mult, product)
	return { Order = order, Id = id, Name = name, Rarity = rarity, Cost = cost, Multiplier = mult, RobuxProductId = product }
end
local TrailDataModule = {
	Trails = {
		trail(1, "Grey", "Grey Trail", "Common", 100, 1.5, nil),
		trail(2, "Green", "Green Trail", "Uncommon", 5000, 2, 3712177824),
		trail(3, "Blue", "Blue Trail", "Rare", 75000, 2.5, 3712177884),
		trail(4, "Purple", "Purple Trail", "Epic", 1500000, 3, 3712177748),
		trail(5, "Golden", "Golden Trail", "Legendary", 30000000, 3.5, 3712177706),
		trail(6, "Red", "Red Trail", "Mythic", 750000000, 4, 3712177674),
		trail(7, "Galaxy", "Galaxy Trail", "Cosmic", 20000000000, 5, 3712177657),
		trail(8, "Secret", "Secret Trail", "Secret", 500000000000, 7, 3712177594),
		trail(9, "Eternal", "Eternal Trail", "Eternal", 12500000000000, 10, 3712177545),
		trail(10, "Divine", "Divine Trail", "Divine", 300000000000000, 14, 3712177514),
	},
}
function TrailDataModule:Get(id)
	for _, t in ipairs(self.Trails) do
		if t.Id == id then
			return t
		end
	end
	return nil
end
Sim.TrailData = TrailDataModule

local SpeedDataModule = {
	SPEED_SCALE = 20.8601,
	SPEED_KNEE = 1343,
	SPEED_POWER = 0.7914,
	BASE_SPEED = 16,
	MAX_WALK_SPEED = 120,
	LOBBY_SPEED = 16,
	Modifiers = { Carrying = 0.82, Stunned = 0, Normal = 1 },
	TreadmillTiers = {
		{ Name = "Treadmill", GainPerSecond = 5, Cost = 0 },
		{ Name = "Sci-Fi Treadmill", GainPerSecond = 10, Cost = 15000 },
		{ Name = "Flame Treadmill", GainPerSecond = 15, Cost = 250000 },
		{ Name = "Celebrity Treadmill", GainPerSecond = 30, Cost = 5000000 },
		{ Name = "Golden Treadmill", GainPerSecond = 80, Cost = 120000000 },
		{ Name = "The Freeze Treadmill", GainPerSecond = 100, Cost = 3000000000 },
		{ Name = "Lucky Block Treadmill", GainPerSecond = 200, Cost = 75000000000 },
		{ Name = "Hacker Treadmill", GainPerSecond = 500, Cost = 3000000000000 },
		{ Name = "Demonic Treadmill", GainPerSecond = 1000, Cost = 50000000000000 },
		{ Name = "Angelic Treadmill", GainPerSecond = 2000, Cost = 1000000000000000 },
	},
	MAX_TREADMILL_TIER = 10,
}
function SpeedDataModule:GetSpeedFromLevel(level)
	level = math.max(0, tonumber(level) or 0)
	return self.BASE_SPEED + self.SPEED_SCALE * math.log(1 + level / self.SPEED_KNEE) ^ self.SPEED_POWER
end
Sim.SpeedData = SpeedDataModule

-- ItemData.Tiers / ItemData.Sell from the dump. Crate names use these tier names.
local ItemDataModule = {
	Tiers = {
		{ Index = 1, Id = "COMMON", Name = "Common", RangeMin = 5, RangeMax = 260 },
		{ Index = 2, Id = "UNCOMMON", Name = "Uncommon", RangeMin = 21, RangeMax = 590 },
		{ Index = 3, Id = "RARE", Name = "Rare", RangeMin = 43, RangeMax = 700000 },
		{ Index = 4, Id = "EPIC", Name = "Epic", RangeMin = 180, RangeMax = 36000000 },
		{ Index = 5, Id = "LEGENDARY", Name = "Legendary", RangeMin = 1800, RangeMax = 48000000 },
		{ Index = 6, Id = "MYTHIC", Name = "Mythic", RangeMin = 16000, RangeMax = 63000000 },
		{ Index = 7, Id = "COSMIC", Name = "Cosmic", RangeMin = 220000, RangeMax = 110000000 },
		{ Index = 8, Id = "SECRET", Name = "Secret", RangeMin = 3500000, RangeMax = 145000000 },
		{ Index = 9, Id = "ETERNAL", Name = "Eternal", RangeMin = 65000000, RangeMax = 600000000 },
		{ Index = 10, Id = "DIVINE", Name = "Divine", RangeMin = 1000000000, RangeMax = 1800000000 },
	},
	Sell = { CrateBlindFactor = 0.35, ItemSeconds = 1200 },
}
Sim.ItemData = ItemDataModule

local BalanceModule = { Balance = { first = 0, second = 0 } }
BalanceModule.CoinsChanged = Sim.Signal.new("CoinsChanged")
Sim.BalanceModule = BalanceModule

local AreaById = {}
for _, a in ipairs(AreaDataModule.Areas) do
	AreaById[a.Id] = a
end
Sim.AreaById = AreaById

local SAFE_X = 2424 -- LBTHTutorialClient.inSafeZone / LBTHAreaTitleClient: X >= 2424 is the lobby
Sim.SAFE_X = SAFE_X
local TIER_VALUE = { Common = 150, Uncommon = 300, Rare = 700, Epic = 2000, Legendary = 6000, Mythic = 20000, Cosmic = 300000, Secret = 5000000, Eternal = 80000000, Divine = 1200000000 }
Sim.TIER_VALUE = TIER_VALUE

-- Crate nests. Positions marked (dump) are the prompt positions from the dump's
-- PROXIMITY PROMPTS section; the rest are placed inside the same zone. The name token
-- is the crate's ItemData tier (the dump shows Common/Rare/Epic in every zone).
local NESTS = {
	{ "Grandpa", 1, "Rare", 2383.2, 3.8, -988.4, "Cube", "3643" },
	{ "Grandpa", 2, "Epic", 2371.9, 3.8, -979.6, "Cube", "3643" },
	{ "Grandpa", 3, "Common", 2379.0, 3.8, -983.0, "Cube", "3643" }, -- dump
	{ "Grandpa", 4, "Common", 2385.1, 3.8, -972.0, "Cube", "3643" },
	{ "Grandpa", 5, "Common", 2377.4, 3.8, -975.5, "Cube", "3643", true }, -- dump (tutorial)
	{ "Jeweler", 1, "Common", 2248.3, 3.6, -976.2, "Cube" },
	{ "Jeweler", 2, "Rare", 2259.7, 3.6, -921.4, "Cube" },
	{ "Jeweler", 3, "Common", 2262.0, 3.6, -985.5, "Cube" },
	{ "Jeweler", 4, "Epic", 2244.5, 3.6, -914.8, "Cube" },
	{ "Archeologist", 1, "Epic", 1997.3, 3.9, -919.0, "Cube", "3720" },
	{ "Archeologist", 2, "Rare", 2001.8, 3.6, -983.0, "Cube", "3720" }, -- dump
	{ "Archeologist", 3, "Common", 2011.6, 3.9, -979.5, "Cube", "3711" }, -- dump
	{ "Archeologist", 4, "Common", 1988.1, 4.5, -991.0, "Cube", "3711" }, -- dump
	{ "Archeologist", 5, "Common", 1992.1, 4.3, -984.0, "Cube", "3711" }, -- dump
	{ "MafiaBoss", 1, "Rare", 1770.7, 3.9, -912.0, "Cube" }, -- dump
	{ "MafiaBoss", 2, "Common", 1782.4, 3.9, -905.3, "Cube" },
	{ "MafiaBoss", 3, "Epic", 1761.9, 3.9, -918.8, "Cube" },
	{ "Celebrity", 1, "Rare", 1443.6, 3.3, -979.3, "chest1.009" }, -- dump
	{ "Celebrity", 2, "Rare", 1453.3, 3.7, -987.3, "chest1.009" }, -- dump
	{ "Celebrity", 3, "Common", 1448.0, 3.5, -915.2, "chest1.009" },
	{ "PirateCaptain", 1, "Rare", 1109.3, 3.9, -924.9, "chest12" }, -- dump
	{ "PirateCaptain", 2, "Rare", 1110.5, 2.9, -914.3, "chest12" }, -- dump
	{ "PirateCaptain", 3, "Epic", 1103.7, 3.3, -920.6, "chest2.004" }, -- dump
	{ "MuseumOwner", 1, "Common", 752.4, 3.5, -915.0, "Cube" },
	{ "MuseumOwner", 2, "Rare", 766.1, 3.5, -968.2, "Cube" },
	{ "MuseumOwner", 3, "Common", 759.8, 3.5, -981.4, "Cube" },
	{ "GoldTycoon", 1, "Common", 280.2, 3.5, -912.7, "Cube" },
	{ "GoldTycoon", 2, "Epic", 292.6, 3.5, -975.1, "Cube" },
	{ "GoldTycoon", 3, "Rare", 286.9, 3.5, -988.3, "Cube" },
	{ "Astronaut", 1, "Epic", -370.9, 3.3, -981.7, "Cube" }, -- dump
	{ "Astronaut", 2, "Epic", -369.2, 3.5, -973.8, "Cube" }, -- dump
	{ "Astronaut", 3, "Common", -362.4, 3.5, -915.6, "Cube" },
	{ "DemonKing", 1, "Common", -842.0, 3.5, -918.1, "Cube" },
	{ "DemonKing", 2, "Rare", -829.5, 3.5, -975.3, "Cube" },
	{ "DemonKing", 3, "Common", -836.8, 3.5, -986.9, "Cube" },
}

local NETWORK_EVENTS = {
	"CoinsChanged", "PlotAdded", "bs_upgrade", "bs_updateClient", "FriendsUPD", "CheckFriend", "IndexUpdate", "LeaderboardUPD", "PlayMessage", "VFX_UPD",
	"TimedUpdate", "SPEED_UPDATE", "KickData", "RebirthUpdate", "RebirthRequest", "TutorialStep", "UpdateSpins", "SpinWheel", "RequestSpin", "open_random",
	"sl_upd", "Weight_Update", "NotificationUpdate", "Offline_Update", "Offline_Force", "myMarket_data", "lb_open", "SendGift", "GiftRequest", "RemovedWeather",
	"AddedWeather", "WeatherUpdate", "SPEED_UPGRADE", "S_Steal", "S_Interact", "B_Upgrade", "B_Collect", "LB_OpenRequest", "B_Sell", "WeightBonus",
	"GroupClaimResponse", "GroupClaim", "CheckFree", "ClaimFree", "Offline_Claim", "Shop_Buy", "BonusTap", "WeightEquip", "EquippedWeight", "TrainTick",
	"Collected", "KickEventEnded", "KickCollect", "KickEvent", "Reverted", "Transformed", "ARENA_RESET", "ARENA_TIMER", "StockShop_BoostState", "MineBlockState",
	"SPEED_GAIN", "TREADMILL_DISMOUNT", "CRATE_DROP", "STEAL_SUCCESS", "BAT_SWING", "IDLE_REJOIN_REQUEST", "BEAR_TRAP_PLACE", "BEAR_TRAP_SFX", "ARENA_BANNER",
	"ARENA_EVAC_FADE", "PURCHASE_THANKS", "SPECIAL_SPAWN", "STEAL_ESCAPED", "CRATES_HIDDEN", "TRAIL_BUY", "TRAIL_EQUIP", "TRAIL_STATE", "UPGRADE_FX",
	"CRATE_REVEAL_SFX", "CRATE_HIT_SFX", "CRATE_HIT_FX", "CRATE_REVEAL_FX", "FUSE_ITEMS", "FUSE_RESULT", "FUSE_FX", "INDEX_REWARD_FX", "INDEX_EQUIP_BAT",
	"INDEX_CLAIM_AREA", "INDEX_CLAIM_ALL", "INDEX_CLAIM", "INDEX_STATE", "DEV_SET_TRAIL", "DEV_SET_SPEED", "SET_SLOW_MODE", "THUNDER_REVEAL", "THUNDER_STATE",
	"STORMBORN_SPAWN", "STORM_RESULT", "STORM_COLLECT", "SellResult", "SellDialogOpen", "ChaseCaught", "FreeGiftState", "EventSync", "EnvironmentChanged",
	"ResetEnvironment", "ChangeEnvironment", "TeleportToPlot", "WaveDied", "OfflineClaimed", "ServerPlayerList", "RequestServerPlayers", "GiftTargetState",
	"DemonAngelBuy", "SetGiftTarget", "BoostPassState", "ItemVisibilitySet", "StormIntroSeen", "BagTutorialDone", "TutorialLuckyClaim", "PlotDailyIncomeUpdate",
	"SandSold", "SandChanged", "EconomySync", "KeyOpen", "KeyBuy", "PurchasePopup", "SlotUpgrade", "BagUpgrade", "EventStateChanged", "UpgradeCashMultiplier",
	"SlotUpgraded", "SquatRep", "RevertCharacter", "MorphToBrainrot", "StrengthUpdate", "ToggleFavorite", "LuckyOpenCollect", "LuckyOpenEventEnded", "LuckyOpenEvent",
}
local TOP_EVENTS = { "re_TREADMILL_UPGRADE", "re_CRATE_REVEAL", "re_PLACE_AT", "re_PLOT_UPGRADE", "re_TUTORIAL_DONE", "RAGDOLL_TUMBLE", "re_SELL_DO" }
local TOP_FUNCTIONS = { "rf_CRATE_TIMERS", "rf_ITEM_LOADOUT", "rf_TUTORIAL_STATE", "rf_THUNDER_MACHINE", "rf_SELL_QUOTE" }

---------------------------------------------------------------------------
-- Server state
---------------------------------------------------------------------------
local Server = {}
Sim.Server = Server
Server.moduleValues = setmetatable({}, { __mode = "k" })
Server.promptRole = setmetatable({}, { __mode = "k" })
Server.growing = {}
Server.uid = 0

Sim.stats = {
	steals = {}, banked = {}, caught = {}, snapTeleport = 0, snapSpeed = 0, snapList = {},
	placed = {}, placeRejected = {}, opened = {}, openRejected = {}, sold = {}, sellRejected = {},
	trailBuys = {}, trailEquips = {}, slotBuys = 0, plotUpgrades = 0, treadmillUpgrades = 0,
	upgradeRejected = {}, mounts = 0, dismounts = 0, indexClaims = 0, placeBest = 0, unhandled = {},
	promptRejected = {},
	orbs = {}, orbRejected = {}, charges = {}, chargeRejected = {}, fuses = {}, fuseRejected = {},
	offlineClaims = 0, freeGift = 0, freeGiftRejected = {}, batEquips = {}, wallHits = 0,
}
local stats = Sim.stats

Sim.defaults = {
	playerName = "RusinaLover08",
	userId = 11104009992,
	position = V(2440, 5, -935), -- lobby, just inside the safe zone
	money = 133264, -- ClientBalanceService.Balance = {first = 1.33264, second = 5}
	playerAttrs = {
		SpeedLevel = 55555, TrailMultiplier = 1, CarryingStolen = false, OnTreadmill = false, IncomePerSecond = 116,
		TreadmillTier = 2, TreadmillLevel = 2, UnlockedPlotSlots = 10, AddedSlots = 0, InSafeZone = true, RebirthLevel = 0,
		TutorialStep = 1, TutorialDone = true, SpeedGainMult = 1, CarryStat = 1, SlowMode = false, FriendBoostMult = 1,
	},
	appraiseTime = 20, -- seconds until an AppraisingCrate's "Open Crate" prompt is enabled
	arenaFirstReset = 226, -- workspace.NextArenaReset was ~226 s after the dump; crates respawn on resets
	arenaPeriod = 300,
	guardSlack = 10, -- guard takes the crate after distance/(RunSpeed*0.82) + guardSlack seconds
	carrySpeedTolerance = 1.2, -- server accepts up to RunSpeed*CarryStat*1.2 while carrying
	carryStat = 0.82, -- CarryStat attribute while carrying (SpeedData.Modifiers.Carrying); number or function(crateName)
	teleportLimit = 150, -- single-frame jump limit while carrying
	sellRange = 18, -- re_SELL_DO only works next to the sell NPC (LBTHSellDialogClient closes the dialog beyond 18 studs)
	equipSlots = 5, -- item stands placebest may fill (+ AddedSlots)
	crateTierAttr = false, -- the dump shows no tier attribute on workspace crates
	promptsNeverShow = false,
	fireproximityprompt = false,
	firetouchinterest = false,
	startOnTreadmill = false,
	noCrateTimers = false, -- remove rf_CRATE_TIMERS to exercise the walk-and-hold open fallback
	treadmillCooldown = 1.5,
	backpack = {}, -- { {kind = "crate", area =, token =} | {kind = "item", name =, value =} }
	floor = {}, -- { {kind = "stand"|"crate", x =, z = (floor local), value =, readyIn =} }
	slotCost = function(n)
		return 25000 * (n + 1)
	end,
	plotCost = function(level)
		return 50000 * 2 ^ level
	end,
}

local function cfg(k)
	local v = Sim.config[k]
	if v == nil then
		return Sim.defaults[k]
	end
	return v
end
Sim.cfg = cfg

local function nextUid(prefix)
	Server.uid += 1
	return fmt("%s-%04d", prefix, Server.uid)
end

local function slog(msg)
	Sim.log("SERVER", msg)
end
Server.log = slog

---------------------------------------------------------------------------
-- Money / speed
---------------------------------------------------------------------------
function Server.setMoney(v)
	Server.money = math.max(0, v)
	local b = BalanceModule.Balance
	if Server.money < 1 then
		b.first, b.second = Server.money, 0
	else
		local e = math.floor(math.log10(Server.money))
		b.first, b.second = Server.money / 10 ^ e, e
	end
	BalanceModule.CoinsChanged:Fire(Server.money)
end

function Server.updateRunSpeed()
	local p = Sim.player
	local level = tonumber(p:GetAttribute("SpeedLevel")) or 0
	local trailMult = tonumber(p:GetAttribute("TrailMultiplier")) or 1
	-- LBTHDevSpeedClient: "stat x trail = RunSpeed studs/s"
	p:SetAttribute("RunSpeed", SpeedDataModule:GetSpeedFromLevel(level) * trailMult)
	Server.updateWalkSpeed()
end

-- the server drives Humanoid.WalkSpeed: RunSpeed, times CarryStat while carrying
function Server.updateWalkSpeed()
	local p = Sim.player
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local run = tonumber(p:GetAttribute("RunSpeed")) or 16
		local mult = p:GetAttribute("CarryingStolen") == true and (tonumber(p:GetAttribute("CarryStat")) or 0.82) or 1
		hum.WalkSpeed = run * mult
	end
end

---------------------------------------------------------------------------
-- World construction
---------------------------------------------------------------------------
local function remote(name)
	return Server.remotes[name]
end
Server.remote = remote

local function fireClient(name, ...)
	local r = remote(name)
	if r then
		r:FireClient(Sim.player, ...)
	end
end
Server.fireClient = fireClient

local function spawnCrate(nest)
	local area, k, token, x, y, z, partName, sub, tutorial = table.unpack(nest.def)
	local pos = V(x, y, z)
	local model = make("Model", { Name = fmt("Crate_%s_%s_N%d%s", area, token, k, tutorial and " (tutorial)" or "") })
	model:SetAttribute("IsCrate", true)
	model:SetAttribute("AreaId", area)
	if tutorial then
		model:SetAttribute("TutorialCrate", true)
	end
	local realTier = token
	if cfg("crateTierAttr") then
		model:SetAttribute("CrateTier", realTier)
	end
	local body = make("MeshPart", { Name = partName, Size = V(3.6, 3.6, 3.6), CFrame = CFrame.new(pos) }, model)
	model.PrimaryPart = body
	local holder = body
	if sub then
		holder = make("Part", { Name = sub, Size = V(1, 1, 1), CFrame = CFrame.new(pos) }, body)
	end
	local prompt = make("ProximityPrompt", {
		ActionText = "Steal", ObjectText = "Crate", HoldDuration = 1, MaxActivationDistance = 12,
		Style = Enum.ProximityPromptStyle.Custom,
	}, holder)
	Server.promptRole[prompt] = { kind = "steal", nest = nest, model = model, tier = realTier }
	model.Parent = workspace.Crates
	nest.model = model
	return model
end

local function addAppraisingCrate(floor, pos, info, readyIn)
	local model = make("Model", { Name = "AppraisingCrate" })
	local cube = make("MeshPart", { Name = "Cube", Size = V(3.6, 3.6, 3.6), CFrame = CFrame.new(pos + V(0, 1.8, 0)) }, model)
	model.PrimaryPart = cube
	model:SetAttribute("CrateUid", info.uid or nextUid("crate"))
	model:SetAttribute("PlacementUid", nextUid("placement"))
	model:SetAttribute("CrateTier", info.tier or "Common")
	model:SetAttribute("CrateAreaId", info.area or "Grandpa")
	model:SetAttribute("OwnerUserId", floor:GetAttribute("OwnerUserId"))
	local prompt = make("ProximityPrompt", {
		ActionText = "Open Crate", ObjectText = "READY", HoldDuration = 0.3, MaxActivationDistance = 14, Enabled = false,
		Style = Enum.ProximityPromptStyle.Custom,
	}, cube)
	model.Parent = floor
	local entry = { model = model, prompt = prompt, floor = floor, readyAt = Sim.now + (readyIn or cfg("appraiseTime")), info = info, ready = false }
	table.insert(Server.growing, entry)
	Server.promptRole[prompt] = { kind = "open", entry = entry }
	return model
end
Server.addAppraisingCrate = addAppraisingCrate

local function addItemStand(floor, pos, item)
	local model = make("Model", { Name = "ItemStand" })
	local base = make("Part", { Name = "Base", Size = V(3, 1, 3), CFrame = CFrame.new(pos + V(0, 0.5, 0)) }, model)
	local art = make("Part", { Name = "ItemArt", Size = V(2, 2, 2), CFrame = CFrame.new(pos + V(0, 2.2, 0)) }, model)
	model.PrimaryPart = base
	model:SetAttribute("ItemUid", item.uid or nextUid("item"))
	model:SetAttribute("ItemValue", item.value or 0)
	local prompt = make("ProximityPrompt", {
		ActionText = "Pick Up", ObjectText = item.name or "Item", HoldDuration = 0.5, MaxActivationDistance = 10,
		Style = Enum.ProximityPromptStyle.Custom,
	}, art)
	Server.promptRole[prompt] = { kind = "stand", model = model, item = item }
	model.Parent = floor
	return model
end
Server.addItemStand = addItemStand

function Server.giveCrateTool(area, tier)
	local tool = make("Tool", { Name = tier .. " Crate", CanBeDropped = false })
	tool:SetAttribute("CrateUid", nextUid("crate"))
	tool:SetAttribute("CrateTier", tier)
	tool:SetAttribute("CrateAreaId", area)
	tool:SetAttribute("CrateKg", 1.5)
	tool:SetAttribute("CrateValue", TIER_VALUE[tier] or 500)
	make("Part", { Name = "Handle", Size = V(1, 1, 1) }, tool)
	tool.Parent = Sim.player.Backpack
	return tool
end

function Server.giveItemTool(item)
	local tool = make("Tool", { Name = item.name or "Item", CanBeDropped = false })
	tool:SetAttribute("ItemUid", item.uid or nextUid("item"))
	tool:SetAttribute("ItemTier", item.tier or "Common")
	tool:SetAttribute("ItemValue", item.value or 100)
	tool:SetAttribute("ItemIncome", math.max(1, math.floor((item.value or 100) / 50)))
	make("Part", { Name = "Handle", Size = V(1, 1, 1) }, tool)
	tool.Parent = Sim.player.Backpack
	return tool
end

local function buildPlot(n, pos, rotY, owner)
	local building = make("Model", { Name = "Plot Building " .. n }, workspace)
	local floor = make("Part", { Name = "floor", Size = V(36, 1, 36), CFrame = CFrame.new(pos) * CFrame.Angles(0, rotY, 0) }, building, { OwnerUserId = owner })
	building.PrimaryPart = floor
	local signs = make("Model", { Name = "Signs" }, building)
	make("Part", { Name = "UpgradeSignBoard", Size = V(6, 4, 0.5), CFrame = floor.CFrame * CFrame.new(-8, 5, 20) }, signs, { UpgradeProgress = 0 })
	make("Part", { Name = "UpgradePost", Size = V(0.5, 5, 0.5), CFrame = floor.CFrame * CFrame.new(-8, 2.5, 20) }, signs)
	make("Part", { Name = "TreadmillSignBoard", Size = V(6, 4, 0.5), CFrame = floor.CFrame * CFrame.new(8, 5, 20) }, signs, { UpgradeProgress = 0 })
	make("Part", { Name = "PlotHomeIcon", Size = V(1, 1, 1), CFrame = floor.CFrame * CFrame.new(0, 12, 0) }, floor)
	return floor, building
end

local function part(name, pos, size, parent, attrs)
	return make("Part", { Name = name, CFrame = CFrame.new(pos), Size = size or V(2, 2, 2) }, parent, attrs)
end

local function promptOn(parentPart, props, role)
	local prompt = make("ProximityPrompt", props, parentPart)
	Server.promptRole[prompt] = role
	return prompt
end

function Server.build(worldConfig)
	for k, v in pairs(worldConfig or {}) do
		Sim.config[k] = v
	end
	Sim.createDataModel()
	local RS = Sim.services.ReplicatedStorage

	-- ReplicatedStorage: Network remotes, data modules, top-level remotes
	Server.remotes = {}
	local shared = make("Folder", { Name = "Shared" }, RS)
	local packages = make("Folder", { Name = "Packages" }, shared)
	local network = make("ModuleScript", { Name = "Network" }, packages)
	for _, n in ipairs(NETWORK_EVENTS) do
		Server.remotes["rev_" .. n] = make("RemoteEvent", { Name = "rev_" .. n }, network)
	end
	for _, n in ipairs({ "B_Sell", "B_SellAll" }) do
		make("RemoteFunction", { Name = "ref_" .. n }, network)
	end
	local data = make("Folder", { Name = "Data" }, shared)
	Server.moduleValues[make("ModuleScript", { Name = "AreaData" }, data)] = AreaDataModule
	Server.moduleValues[make("ModuleScript", { Name = "TrailData" }, data)] = TrailDataModule
	Server.moduleValues[make("ModuleScript", { Name = "SpeedData" }, data)] = SpeedDataModule
	Server.moduleValues[make("ModuleScript", { Name = "ItemData" }, data)] = ItemDataModule
	make("Folder", { Name = "Utility" }, shared)
	local lbth = make("Folder", { Name = "LBTHClient" }, RS)
	local services = make("Folder", { Name = "Services" }, lbth)
	Server.moduleValues[make("ModuleScript", { Name = "ClientBalanceService" }, services)] = BalanceModule
	make("Folder", { Name = "Controllers" }, lbth)
	for _, n in ipairs(TOP_EVENTS) do
		Server.remotes[n] = make("RemoteEvent", { Name = n }, RS)
	end
	for _, n in ipairs(TOP_FUNCTIONS) do
		if not (n == "rf_CRATE_TIMERS" and cfg("noCrateTimers")) then
			Server.remotes[n] = make("RemoteFunction", { Name = n }, RS)
		end
	end

	-- Steal map
	-- walkable ground (top at Y = 1): raycasts from the script's ground-follow hit this
	make("Part", { Name = "Ground", CFrame = CFrame.new(800, 0, -940), Size = V(4200, 2, 500) }, make("Folder", { Name = "Terrainish" }, workspace))
	local stealMap = make("Folder", { Name = "Steal Map" }, workspace)
	local lobby = make("Folder", { Name = "Lobby" }, stealMap)
	Server.safeZone = part("safe zone", V(2435, -12.5, -940), V(22, 30, 180), lobby)
	Server.safeZone.CanCollide = false
	Server.safeZone.CanQuery = false
	local arena = make("Folder", { Name = "Arena" }, stealMap)
	for _, a in ipairs(AreaDataModule.Areas) do
		local xs = { Grandpa = 2379, Jeweler = 2254, Archeologist = 2064, MafiaBoss = 1833.9, Celebrity = 1550.4, PirateCaptain = 1187, MuseumOwner = 759, GoldTycoon = 286, Astronaut = -234, DemonKing = -836.1 }
		local zonePart = part(a.AreaPart, V(xs[a.Id], -12.5, -940), V(90, 30, 180), arena, { AreaId = a.Id })
		zonePart.CanCollide = false
		zonePart.CanQuery = false
	end

	-- Crates
	make("Folder", { Name = "Crates" }, workspace)
	Server.nests = {}
	for _, def in ipairs(NESTS) do
		local nest = { def = def, area = def[1] }
		table.insert(Server.nests, nest)
		spawnCrate(nest)
	end

	-- Vendors (dump prompt positions)
	local map = make("Folder", { Name = "Map" }, workspace)
	local vendors = make("Folder", { Name = "Vendors" }, map)
	local sellPlaces = make("Folder", { Name = "SellPlaces" }, vendors)
	local sell1 = make("Model", { Name = "Sell1" }, sellPlaces)
	local sellNpc = make("Model", { Name = "sellnpc NEW" }, sell1)
	Server.sellPart = part("ProximityPart", V(2437.8, 4.2, -864.1), V(2, 2, 2), sellNpc)
	promptOn(Server.sellPart, { Name = "TalkPrompt", ActionText = "Talk", ObjectText = "Sell Vendor", HoldDuration = 0, MaxActivationDistance = 12 }, { kind = "talk" })
	local trailshop = make("Model", { Name = "Trailshop" }, vendors)
	local trailnpc = make("Model", { Name = "trailnpc" }, trailshop)
	promptOn(part("ProximityPart", V(2435.6, 4.2, -996.7), V(2, 2, 2), trailnpc), { Name = "TrailShopPrompt", ActionText = "Trail Shop", ObjectText = "Trails", HoldDuration = 0, MaxActivationDistance = 10 }, { kind = "shop" })
	local thunder = make("Model", { Name = "Thunder Machine" }, workspace)
	promptOn(part("ThunderPromptAnchor", V(2470.3, 5.2, -937.2), V(1, 1, 1), thunder), { Name = "ThunderPrompt", ActionText = "Charge Crate", ObjectText = "Thunder Machine", HoldDuration = 0.5, MaxActivationDistance = 10 }, { kind = "thunder" })
	local fuse = make("Model", { Name = "Fuse Machine" }, workspace)
	promptOn(part("FusePromptAnchor", V(2438.9, 4.8, -845.8), V(1, 1, 1), fuse), { Name = "FusePrompt", ActionText = "Fuse Items", ObjectText = "Fuse Machine", HoldDuration = 0, MaxActivationDistance = 12 }, { kind = "fuse" })

	-- Plots: ours is rotated 90 degrees to exercise the CFrame math
	local userId = cfg("userId")
	local f1 = buildPlot(1, V(2457, 3.5, -1123), 0, 7770747208)
	Server.myFloor = buildPlot(2, V(2462, 3.5, -1060), math.pi / 2, userId)
	local f3 = buildPlot(3, V(2548, 3.5, -1110), 0, 2364225516)
	local f4 = buildPlot(4, V(2553, 3.5, -1042), 0, 3430110074)
	addAppraisingCrate(f3, V(2548.3, 4, -1108.9), { tier = "Rare" }, 1e9)
	addAppraisingCrate(f3, V(2548.3, 4, -1112.7), { tier = "Rare" }, 1e9)
	addAppraisingCrate(f1, V(2457.3, 4, -1123.3), { tier = "Rare" }, 1e9)
	addAppraisingCrate(f4, V(2553.0, 4, -1042.6), { tier = "Rare" }, 1e9)
	Server.plotLevel = 0

	-- Treadmills (other players' mount CFrames are in the dump: X 2439-2440, Z -945/-954)
	local treadmills = make("Folder", { Name = "Treadmills" }, workspace)
	local function treadmill(owner, pos)
		local m = make("Model", { Name = "PersonalTreadmill_" .. owner }, treadmills, { OwnerUserId = owner, MountYaw = 0 })
		local belt = make("Part", { Name = "Belt", Size = V(4, 1, 8), CFrame = CFrame.new(pos) }, m)
		m.PrimaryPart = belt
		return m, belt
	end
	treadmill(1111, V(2439.9, 4.2, -945.5))
	treadmill(2222, V(2439.2, 4.2, -953.9))
	Server.treadmill, Server.belt = treadmill(userId, V(2439.5, 4.2, -962.3))
	Server.mountCooldownUntil = 0

	-- Local player
	local attrs = table.clone(Sim.defaults.playerAttrs)
	for k, v in pairs(cfg("playerAttrs") or {}) do
		attrs[k] = v
	end
	for k, v in pairs(Sim.config.attrs or {}) do
		attrs[k] = v
	end
	local player = Sim.createLocalPlayer(cfg("playerName"), userId, cfg("position"), attrs)
	make("Folder", { Name = "leaderstats" }, player)
	local batTool = make("Tool", { Name = "Bat PVP" }, player.Backpack, { IsBatTool = true, BatId = "Default", BatName = "Wooden Bat" })
	make("Part", { Name = "Handle" }, batTool)
	make("Tool", { Name = "Bear Trap" }, player.Backpack, { TrapCount = 3, IsBearTrapTool = true })
	Server.updateRunSpeed()
	Server.setMoney(cfg("money"))
	Server.lastPos = Sim.rootPart().Position

	for _, entry in ipairs(cfg("backpack") or {}) do
		if entry.kind == "crate" then
			Server.giveCrateTool(entry.area or "Grandpa", entry.token or "Common")
		else
			Server.giveItemTool(entry)
		end
	end
	local floor = Server.myFloor
	local top = floor.Size.Y / 2
	for _, entry in ipairs(cfg("floor") or {}) do
		local pos = floor.CFrame:PointToWorldSpace(V(entry.x, top, entry.z))
		if entry.kind == "stand" then
			addItemStand(floor, pos, { name = entry.name or "Old Item", value = entry.value or 5000 })
		else
			addAppraisingCrate(floor, pos, { tier = entry.tier or "Rare" }, entry.readyIn)
		end
	end

	if cfg("startOnTreadmill") then
		Server.mount()
	end
	if cfg("fireproximityprompt") then
		Sim.installFireProximityPrompt()
	end
	if cfg("firetouchinterest") then
		firetouchinterest = function(a, b, state)
			Sim.count("firetouchinterest")
		end
	end
	Server.nextReset = Sim.T0 + cfg("arenaFirstReset")
	Server.buildExtras()
	Server.nextTick = Sim.now + 1
	Server.incomeAcc = 0
	Server.speedAcc = 0
	Server.updateSigns()
end

---------------------------------------------------------------------------
-- Storm orbs, Thunder Machine, Fuse Machine, offline cash, Free Gift
-- (behaviour taken from the decompiled client scripts; server checks the
-- dump cannot show are modelled conservatively: you must be near the thing)
---------------------------------------------------------------------------
local STORM = {
	ORB_COUNT = 300, MAGNET_RADIUS = 16, RESPAWN_SECONDS = 20, EDGE_MARGIN = 4, HOVER = 1.25,
	MIN_SPEND = 1000, MAX_CHARGE = 1500,
	ORB_SIZES = { { Id = "Small", Points = 1, Scale = 0.6, Weight = 50 }, { Id = "Medium", Points = 2, Scale = 1, Weight = 40 }, { Id = "Big", Points = 4, Scale = 1.6, Weight = 10 } },
}
-- StormConfig.computeLayout, ported line by line from the dump (line 49794)
function STORM.computeLayout(p8, p9, p10)
	local v11, v12 = {}, 0
	for _, descendant in ipairs(p8:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(v11, descendant)
		end
	end
	table.sort(v11, function(p13, p14)
		if p13.Position.X == p14.Position.X then
			return p13.Position.Z < p14.Position.Z
		end
		return p13.Position.X < p14.Position.X
	end)
	local v15 = {}
	for _, v in ipairs(v11) do
		local sx = math.max(0.1, v.Size.X - STORM.EDGE_MARGIN * 2)
		local sz = math.max(0.1, v.Size.Z - STORM.EDGE_MARGIN * 2)
		v12 += sx * sz
		table.insert(v15, { part = v, sx = sx, sz = sz, cum = v12 })
	end
	local v16 = {}
	if #v15 == 0 then
		return v16
	end
	local v18 = Random.new(math.floor(tonumber(p9) or 0))
	for i = 1, p10 or STORM.ORB_COUNT do
		local v19 = v18:NextNumber() * v12
		local v20 = v15[#v15]
		for _, v in ipairs(v15) do
			if v19 <= v.cum then
				v20 = v
				break
			end
		end
		local v21 = (v18:NextNumber() - 0.5) * v20.sx
		local v22 = (v18:NextNumber() - 0.5) * v20.sz
		v16[i] = v20.part.CFrame:PointToWorldSpace(V(v21, v20.part.Size.Y / 2 + STORM.HOVER, v22))
	end
	local v23, v24 = 0, {}
	for _, v in ipairs(STORM.ORB_SIZES) do
		v23 += v.Weight
	end
	local v26 = Random.new(math.floor(tonumber(p9) or 0) + 7919)
	for i = 1, #v16 do
		local v27 = v26:NextNumber() * v23
		local v28, v30 = #STORM.ORB_SIZES, 0
		for i2, v in ipairs(STORM.ORB_SIZES) do
			v30 += v.Weight
			if v27 <= v30 then
				v28 = i2
				break
			end
		end
		v24[i] = v28
		local v31 = math.max(0, STORM.ORB_SIZES[v28].Scale - 1) * 1.1
		if v31 > 0 then
			v16[i] = v16[i] + V(0, v31, 0)
		end
	end
	return v16, v24
end

local THUNDER_POS = V(2470.3, 5.2, -937.2)
local FUSE_POS = V(2438.9, 4.8, -845.8)
local GIFT_POS = V(2430.6, 10, -1019.1)
local FUSE_FEE_SECONDS = { Common = 10, Uncommon = 10, Rare = 30, Epic = 30, Legendary = 60, Mythic = 60, Cosmic = 120, Secret = 180, Eternal = 300, Divine = 300 }

function Server.buildExtras()
	local RS = Sim.services.ReplicatedStorage
	local WS = Sim.services.Workspace
	local player = Sim.player
	-- storm: regions live in ReplicatedStorage like the real game (not raycast)
	local admin = make("Folder", { Name = "AdminSystem" }, RS)
	local events = make("Folder", { Name = "Events" }, admin)
	local stormModule = make("ModuleScript", { Name = "Storm" }, events)
	local client = make("Folder", { Name = "Client" }, stormModule)
	local regions = make("Model", { Name = "ElectricOrbSpawnRegions" }, client)
	for _, r in ipairs(cfg("stormRegions") or { { pos = V(2470, 3, -960), size = V(60, 1, 80) }, { pos = V(2330, 3, -960), size = V(80, 1, 60) } }) do
		make("Part", { Name = "Part", Anchored = true, Size = r.size, CFrame = CFrame.new(r.pos) }, regions)
	end
	if not cfg("stormNoModule") then
		local shared = make("Folder", { Name = "Shared" }, stormModule)
		Server.moduleValues[make("ModuleScript", { Name = "StormConfig" }, shared)] = STORM
	end
	Server.orbTaken = {}
	Server.orbs, Server.orbSizes = STORM.computeLayout(regions, cfg("stormSeed") or 1790444418, STORM.ORB_COUNT)
	local storm = cfg("storm")
	WS:SetAttribute("StormSeed", cfg("stormSeed") or 1790444418)
	WS:SetAttribute("StormActive", storm == true)
	WS:SetAttribute("StormEndsAt", Sim.now + (cfg("stormSeconds") or 300))
	WS:SetAttribute("ArenaCycle", 5968151)
	WS:SetAttribute("NextArenaReset", Server.nextReset)
	player:SetAttribute("StormPoints", cfg("stormPoints") or 0)
	player:SetAttribute("StormLuckTier", 0)
	-- machines and the gift chest
	local thunder = make("Model", { Name = "Thunder Machine" }, WS)
	make("Part", { Name = "ThunderPromptAnchor", Anchored = true, Size = V(1, 1, 1), CFrame = CFrame.new(THUNDER_POS) }, thunder)
	local fuse = make("Model", { Name = "Fuse Machine" }, WS)
	make("Part", { Name = "FusePromptAnchor", Anchored = true, Size = V(1, 1, 1), CFrame = CFrame.new(FUSE_POS) }, fuse)
	local gift = make("Folder", { Name = "FREEGIFT" }, WS)
	local chest = make("Model", { Name = "FreeGiftChest" }, gift)
	make("Part", { Name = "Group Likeframe", Anchored = true, Size = V(6, 6, 6), CanCollide = false, CFrame = CFrame.new(GIFT_POS) }, chest)
	Server.charged = {}
	Server.giftState = {}
	if cfg("offlineCash") then
		Server.offlinePending = cfg("offlineCash")
		task.delay(cfg("offlineAt") or 1, function()
			fireClient("rev_Offline_Update", Server.offlinePending)
		end)
	end
	if cfg("indexBats") then
		task.delay(2, function()
			fireClient("rev_INDEX_STATE", { Discovered = {}, Claimed = {}, AreaClaimed = {}, Bats = cfg("indexBats") })
		end)
	end
end


---------------------------------------------------------------------------
-- require() of game modules
---------------------------------------------------------------------------
require = function(target)
	if Sim.isInstance(target) then
		if not target:IsA("ModuleScript") then
			error("Attempted to call require with invalid argument(s).", 2)
		end
		local v = Server.moduleValues[target]
		if v == nil then
			error("Requested module experienced an error while loading: " .. target:GetFullName(), 2)
		end
		Sim.count("require")
		return v
	end
	error("require: the harness only supports ModuleScript instances (got " .. typeof(target) .. ")", 2)
end

---------------------------------------------------------------------------
-- Treadmill
---------------------------------------------------------------------------
local function mountCF()
	local belt = Server.belt
	return belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 3, 0)
end
function Server.mount()
	local p = Sim.player
	p:SetAttribute("OnTreadmill", true)
	p:SetAttribute("TreadmillMountCF", mountCF())
	Server.treadmill:SetAttribute("RiderUserId", p.UserId)
	local root = Sim.rootPart()
	root.CFrame = mountCF()
	Server.lastPos = root.Position
	stats.mounts += 1
	slog("player mounted the treadmill")
end
function Server.dismount(reason)
	local p = Sim.player
	if p:GetAttribute("OnTreadmill") ~= true then
		return
	end
	p:SetAttribute("OnTreadmill", false)
	p:SetAttribute("TreadmillMountCF", nil)
	Server.treadmill:SetAttribute("RiderUserId", nil)
	local root = Sim.rootPart()
	local belt = Server.belt
	root.CFrame = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 3, -(belt.Size.Z / 2 + 3))
	Server.lastPos = root.Position
	Server.mountCooldownUntil = Sim.now + cfg("treadmillCooldown")
	stats.dismounts += 1
	slog("player got off the treadmill (" .. reason .. ")")
end

-- LBTHTreadmillLockClient: while OnTreadmill the client pins the root every frame
Sim.clientPin = function()
	local p = Sim.player
	if p and p.__attr.OnTreadmill == true then
		local cf = p.__attr.TreadmillMountCF
		local root = Sim.rootPart()
		if root and typeof(cf) == "CFrame" then
			root.__p.CFrame = cf
		end
	end
end

---------------------------------------------------------------------------
-- Upgrade signs
---------------------------------------------------------------------------
local function nextTreadmillCost()
	local tier = tonumber(Sim.player:GetAttribute("TreadmillTier")) or 1
	local nextTier = SpeedDataModule.TreadmillTiers[tier + 1]
	return nextTier and nextTier.Cost or math.huge
end
function Server.updateSigns()
	local building = Server.myFloor.Parent
	local up = building:FindFirstChild("UpgradeSignBoard", true)
	local tr = building:FindFirstChild("TreadmillSignBoard", true)
	up:SetAttribute("CanAfford", Server.money >= cfg("plotCost")(Server.plotLevel))
	tr:SetAttribute("CanAfford", Server.money >= nextTreadmillCost())
end

---------------------------------------------------------------------------
-- Per-frame server simulation
---------------------------------------------------------------------------
local function carrying()
	return Sim.player:GetAttribute("CarryingStolen") == true
end

local function snapBack(root, kind, dist, speed)
	local last = Server.lastPos
	root.CFrame = CFrame.new(last) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
	if kind == "teleport" then
		stats.snapTeleport += 1
	else
		stats.snapSpeed += 1
	end
	stats.snapKinds = stats.snapKinds or {}
	stats.snapKinds[kind] = (stats.snapKinds[kind] or 0) + 1
	table.insert(stats.snapList, { t = Sim.elapsed(), kind = kind, dist = dist, speed = speed })
	local n = stats.snapTeleport + stats.snapSpeed
	if n <= 12 or n % 50 == 0 then
		slog(fmt("SNAPBACK (%s) while carrying: moved %.1f studs in one frame (%.0f studs/s, limit %.1f) -> back to %s", kind, dist, speed, (Sim.player:GetAttribute("RunSpeed") or 16) * (Sim.player:GetAttribute("CarryStat") or 0.82) * cfg("carrySpeedTolerance"), Sim.describe(last)))
	end
end

function Server.bank(root)
	local c = Server.carry
	Sim.player:SetAttribute("CarryingStolen", false)
	Sim.player:SetAttribute("CarryStat", 1)
	Server.updateWalkSpeed()
	Server.carry = nil
	Server.giveCrateTool(c.area, c.tier)
	table.insert(stats.banked, { t = Sim.elapsed(), area = c.area, tier = c.tier, took = Sim.now - c.t })
	slog(fmt("crate banked in the safe zone: %s %s (carried %.1f s of %.1f s allowed)", c.area, c.tier, Sim.now - c.t, c.allowed))
	fireClient("rev_STEAL_ESCAPED", c.area)
end

function Sim.serverStep(dt)
	local player = Sim.player
	local root = Sim.rootPart()
	if not root then
		return
	end
	local pos = root.Position

	-- the lobby wall: between the lobby (X >= 2424) and the arena the only way is
	-- through the safe zone (live log: pinned 30 s at X=2424.5, Z=-1063 running
	-- from the plot straight at a crate)
	local prev = Server.wallLast
	if prev and (prev.X >= SAFE_X) ~= (pos.X >= SAFE_X) and pos.X ~= prev.X then
		local zone = Server.safeZone
		local zMin, zMax = zone.Position.Z - zone.Size.Z / 2, zone.Position.Z + zone.Size.Z / 2
		local t = (SAFE_X - prev.X) / (pos.X - prev.X)
		local z = prev.Z + (pos.Z - prev.Z) * t
		if z < zMin or z > zMax then
			pos = V(if prev.X >= SAFE_X then SAFE_X + 0.6 else SAFE_X - 0.6, pos.Y, pos.Z)
			root.CFrame = CFrame.new(pos) * root.CFrame.Rotation
			stats.wallHits += 1
		end
	end
	Server.wallLast = pos

	-- movement validation while carrying
	if carrying() then
		-- horizontal speed is checked against the carry speed (vertical moves are physics:
		-- falling / stepping onto things)
		local last = Server.lastPos
		local d = (pos - last).Magnitude
		local dx, dz, dy = pos.X - last.X, pos.Z - last.Z, pos.Y - last.Y
		local dh = math.sqrt(dx * dx + dz * dz)
		local run = tonumber(player:GetAttribute("RunSpeed")) or 16
		local mult = tonumber(player:GetAttribute("CarryStat")) or 0.82
		local maxStep = run * mult * cfg("carrySpeedTolerance") * dt + 0.05
		if d > cfg("teleportLimit") then
			snapBack(root, "teleport", d, d / dt)
			pos = last
		elseif dh > maxStep then
			snapBack(root, "speed", dh, dh / dt)
			pos = last
		else
			Server.lastPos = pos
		end
	else
		Server.lastPos = pos
	end
	player:SetAttribute("InSafeZone", pos.X >= SAFE_X)

	-- banking and guard
	if carrying() and Server.carry then
		if pos.X >= SAFE_X then
			Server.bank(root)
		elseif Sim.now - Server.carry.t > Server.carry.allowed then
			local c = Server.carry
			player:SetAttribute("CarryingStolen", false)
			player:SetAttribute("CarryStat", 1)
			Server.updateWalkSpeed()
			Server.carry = nil
			table.insert(stats.caught, { t = Sim.elapsed(), area = c.area, x = pos.X })
			slog(fmt("GUARD CAUGHT the player at X=%.0f carrying a %s crate for %.1f s (allowed %.1f s)", pos.X, c.area, Sim.now - c.t, c.allowed))
			fireClient("rev_ChaseCaught", c.area)
		end
	end

	-- treadmill: step on your own belt to mount, gain speed while on it
	if player:GetAttribute("OnTreadmill") == true then
		local tier = SpeedDataModule.TreadmillTiers[tonumber(player:GetAttribute("TreadmillTier")) or 1]
		Server.speedAcc += (tier and tier.GainPerSecond or 5) * (tonumber(player:GetAttribute("SpeedGainMult")) or 1) * dt
	elseif not carrying() and Sim.now >= Server.mountCooldownUntil then
		local belt = Server.belt
		local lp = belt.CFrame:PointToObjectSpace(pos)
		if math.abs(lp.X) <= belt.Size.X / 2 + 0.5 and math.abs(lp.Z) <= belt.Size.Z / 2 + 0.5 and lp.Y >= belt.Size.Y / 2 - 0.5 and lp.Y <= belt.Size.Y / 2 + 5 then
			Server.mount()
		end
	end

	-- appraisal timers
	for _, g in ipairs(Server.growing) do
		if not g.ready and not g.model.__destroyed and Sim.now >= g.readyAt then
			g.ready = true
			g.prompt.Enabled = true
			if g.floor == Server.myFloor then
				slog("crate on your plot is ready to open (" .. (g.info.tier or "?") .. ")")
			end
		end
	end

	-- arena reset: missing crates respawn
	if Sim.now >= Server.nextReset then
		Server.nextReset += cfg("arenaPeriod")
		local n = 0
		for _, nest in ipairs(Server.nests) do
			if not nest.model or nest.model.__destroyed then
				spawnCrate(nest)
				n += 1
			end
		end
		slog("ARENA RESET: " .. n .. " crates respawned")
		fireClient("rev_ARENA_RESET")
	end

	-- once a second: income, speed gain, signs
	if Sim.now >= Server.nextTick then
		Server.nextTick += 1
		Server.setMoney(Server.money + (tonumber(player:GetAttribute("IncomePerSecond")) or 0))
		if Server.speedAcc >= 1 then
			local gain = math.floor(Server.speedAcc)
			Server.speedAcc -= gain
			player:SetAttribute("SpeedLevel", (tonumber(player:GetAttribute("SpeedLevel")) or 0) + gain)
			Server.updateRunSpeed()
		end
		Server.updateSigns()
	end
end

function Server.openCrate(entry, how)
	entry.model:Destroy()
	local tier = entry.info.tier or "Common"
	Server.giveItemTool({ name = tier .. " Item", tier = tier, value = TIER_VALUE[tier] or 1000 })
	table.insert(stats.opened, { t = Sim.elapsed(), tier = tier, how = how })
	slog("crate OPENED on your plot via " .. how .. " -> item tool (" .. tier .. ")")
end

---------------------------------------------------------------------------
-- Prompt triggers (server side)
---------------------------------------------------------------------------
function Server.onPromptTriggered(prompt, how, rootPosAtTrigger)
	local role = Server.promptRole[prompt]
	local label = Sim.promptLabel(prompt)
	local function reject(why)
		table.insert(stats.promptRejected, { t = Sim.elapsed(), prompt = label, why = why })
		slog("prompt trigger REJECTED: " .. label .. " (" .. why .. ")")
	end
	if not role then
		return reject("no server handler")
	end
	if prompt.__destroyed or not prompt.__p.Enabled then
		return reject("prompt no longer enabled")
	end
	local root = Sim.rootPart()
	local ppos = Sim.promptWorldPos(prompt)
	if not (root and ppos) then
		return reject("no character")
	end
	local d = (ppos - root.Position).Magnitude
	if d > prompt.__p.MaxActivationDistance + 4 then
		return reject(fmt("too far: %.1f studs", d))
	end
	local player = Sim.player
	if role.kind == "steal" then
		if carrying() then
			return reject("already carrying a crate")
		end
		local nest = role.nest
		local area = AreaById[nest.area]
		local run = tonumber(player:GetAttribute("RunSpeed")) or 16
		local x = root.Position.X
		local cs = cfg("carryStat")
		if type(cs) == "function" then
			cs = cs(role.model.Name)
		end
		Server.carry = { t = Sim.now, area = nest.area, tier = role.tier, x = x, allowed = math.abs(x - SAFE_X) / (run * cs) + cfg("guardSlack") }
		player:SetAttribute("CarryStat", cs)
		player:SetAttribute("CarryingStolen", true)
		Server.updateWalkSpeed()
		Server.lastPos = root.Position
		prompt.Enabled = false
		table.insert(stats.steals, { t = Sim.elapsed(), area = nest.area, token = nest.def[3], name = role.model.Name, how = how })
		slog(fmt("STEAL: %s (%s) via %s; guard allows %.1f s", role.model.Name, role.tier, how, Server.carry.allowed))
		fireClient("rev_STEAL_SUCCESS", area.NpcName)
		local model = role.model
		task.delay(0.1, function()
			model:Destroy()
		end)
	elseif role.kind == "open" then
		local entry = role.entry
		if entry.floor ~= Server.myFloor then
			return reject("not your plot")
		end
		Server.openCrate(entry, how)
	elseif role.kind == "talk" then
		fireClient("rev_SellDialogOpen")
	elseif role.kind == "stand" then
		slog("item stand picked up")
		local item = role.item
		role.model:Destroy()
		Server.giveItemTool(item)
	end
end

---------------------------------------------------------------------------
-- Remotes (server side)
---------------------------------------------------------------------------
local function sellableItems()
	local out = {}
	for _, parent in ipairs({ Sim.player.Backpack, Sim.player.Character }) do
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("Tool") and c:GetAttribute("ItemUid") then
				table.insert(out, c)
			end
		end
	end
	return out
end
Server.sellableItems = sellableItems

local function equippedTool()
	return Sim.player.Character:FindFirstChildOfClass("Tool")
end

local function nearMyPlot(pos)
	local floor = Server.myFloor
	local o = floor.CFrame:PointToObjectSpace(pos)
	local ex = math.max(math.abs(o.X) - floor.Size.X / 2, 0)
	local ez = math.max(math.abs(o.Z) - floor.Size.Z / 2, 0)
	return ex * ex + ez * ez <= 900 and math.abs(o.Y) <= 60
end

local function placementProblem(pos)
	local floor = Server.myFloor
	local o = floor.CFrame:PointToObjectSpace(pos)
	if math.abs(o.X) > floor.Size.X / 2 - 2 or math.abs(o.Z) > floor.Size.Z / 2 - 2 then
		return "outside the plot floor"
	end
	if math.abs(pos.Y - (floor.Position.Y + floor.Size.Y / 2)) > 2.5 then
		return "not on the floor surface"
	end
	for _, c in ipairs(floor:GetChildren()) do
		if c.Name == "AppraisingCrate" or c.Name == "ItemStand" then
			local p = c:GetPivot().Position
			local dx, dz = p.X - pos.X, p.Z - pos.Z
			if dx * dx + dz * dz < 9 then
				return "too close to another placement"
			end
		end
	end
	return nil
end
Server.placementProblem = placementProblem

local function freeServerSpot()
	local floor = Server.myFloor
	local top = floor.Size.Y / 2
	local hx, hz = floor.Size.X / 2 - 3, floor.Size.Z / 2 - 3
	local x = hx
	while x >= -hx do
		local z = hz
		while z >= -hz do
			local pos = floor.CFrame:PointToWorldSpace(V(x, top, z))
			if not placementProblem(pos) then
				return pos
			end
			z -= 4
		end
		x -= 4
	end
	return nil
end

local handlers = {}
local invokers = {}
Server.handlers = handlers
Server.invokers = invokers

handlers.re_PLACE_AT = function(args, entry)
	local pos, yaw = args[1], args[2]
	local root = Sim.rootPart()
	local tool = equippedTool()
	local problem
	if typeof(pos) ~= "Vector3" then
		problem = "position is not a Vector3"
	elseif type(yaw) ~= "number" then
		problem = "yaw is not a number"
	elseif not (tool and (tool:GetAttribute("CrateUid") or tool:GetAttribute("ItemUid"))) then
		problem = "no crate/item tool equipped"
	elseif not nearMyPlot(root.Position) then
		problem = "player is not near their plot"
	else
		problem = placementProblem(pos)
	end
	if problem then
		table.insert(stats.placeRejected, { t = Sim.elapsed(), why = problem })
		entry.outcome = "rejected: " .. problem
		slog("PLACE_AT rejected: " .. problem)
		fireClient("rev_PlayMessage", "You can only place this on your plot.", "Error")
		return
	end
	if tool:GetAttribute("CrateUid") then
		addAppraisingCrate(Server.myFloor, pos, { tier = tool:GetAttribute("CrateTier"), area = tool:GetAttribute("CrateAreaId"), uid = tool:GetAttribute("CrateUid") })
		table.insert(stats.placed, { t = Sim.elapsed(), pos = pos })
		slog("PLACE_AT accepted: crate placed at " .. Sim.describe(pos))
	else
		addItemStand(Server.myFloor, pos, { name = tool.Name, value = tool:GetAttribute("ItemValue"), uid = tool:GetAttribute("ItemUid") })
		slog("PLACE_AT accepted: item stand placed")
	end
	entry.outcome = "accepted"
	tool:Destroy()
end

handlers.re_SELL_DO = function(args, entry)
	local mode = args[1]
	local root = Sim.rootPart()
	local d = (root.Position - Server.sellPart.Position).Magnitude
	local function reject(why, text)
		table.insert(stats.sellRejected, { t = Sim.elapsed(), why = why })
		entry.outcome = "rejected: " .. why
		slog("SELL_DO rejected: " .. why)
		fireClient("rev_SellResult", { Ok = false, Text = text or "Hmm, I can't trade right now." })
	end
	if d > cfg("sellRange") then
		return reject(fmt("player is %.0f studs from the seller", d))
	end
	local list
	if mode == "all" then
		list = sellableItems()
		-- Sell All also takes unopened crates at ItemData.Sell.CrateBlindFactor
		for _, parent in ipairs({ Sim.player.Backpack, Sim.player.Character }) do
			for _, c in ipairs(parent:GetChildren()) do
				if c:IsA("Tool") and c:GetAttribute("CrateUid") then
					table.insert(list, c)
				end
			end
		end
	elseif mode == "held" then
		local t = equippedTool()
		list = (t and t:GetAttribute("ItemUid")) and { t } or {}
	else
		return reject("unknown sell mode " .. Sim.describe(mode))
	end
	if #list == 0 then
		return reject("nothing to sell", "You don't have anything I want.")
	end
	local total, crates = 0, 0
	for _, t in ipairs(list) do
		if t:GetAttribute("CrateUid") then
			crates += 1
			total += math.floor((t:GetAttribute("CrateValue") or 0) * ItemDataModule.Sell.CrateBlindFactor)
		else
			total += t:GetAttribute("ItemValue") or 0
		end
		t:Destroy()
	end
	Server.setMoney(Server.money + total)
	table.insert(stats.sold, { t = Sim.elapsed(), count = #list, crates = crates, total = total, mode = mode })
	entry.outcome = "accepted"
	slog(fmt("SOLD %d item(s) (%d unopened crate(s)) for $%d (%s)", #list, crates, total, mode))
	fireClient("rev_SellResult", { Ok = true, Total = total, Count = #list, Text = "Sold! $" .. total })
end

handlers.re_PLOT_UPGRADE = function(args, entry)
	local floor, isSlot = args[1], args[2]
	local function reject(why)
		table.insert(stats.upgradeRejected, { t = Sim.elapsed(), what = isSlot and "slot" or "plot", why = why })
		entry.outcome = "rejected: " .. why
	end
	if floor ~= Server.myFloor then
		return reject("argument is not your plot floor (" .. Sim.describe(floor) .. ")")
	end
	local p = Sim.player
	if isSlot == true then
		local added = tonumber(p:GetAttribute("AddedSlots")) or 0
		local cost = cfg("slotCost")(added)
		if Server.money < cost then
			return reject("cannot afford slot ($" .. cost .. ")")
		end
		Server.setMoney(Server.money - cost)
		p:SetAttribute("AddedSlots", added + 1)
		stats.slotBuys += 1
		slog("bought +1 item slot for $" .. cost)
	elseif isSlot == nil then
		local cost = cfg("plotCost")(Server.plotLevel)
		if Server.money < cost then
			return reject("cannot afford plot upgrade ($" .. cost .. ")")
		end
		Server.setMoney(Server.money - cost)
		Server.plotLevel += 1
		stats.plotUpgrades += 1
		slog("plot upgraded to level " .. Server.plotLevel .. " for $" .. cost)
	else
		return reject("unexpected second argument " .. Sim.describe(isSlot))
	end
	entry.outcome = "accepted"
	Server.updateSigns()
end

handlers.re_TREADMILL_UPGRADE = function(args, entry)
	if args[1] ~= Server.myFloor then
		entry.outcome = "rejected: argument is not your plot floor"
		table.insert(stats.upgradeRejected, { t = Sim.elapsed(), what = "treadmill", why = entry.outcome })
		return
	end
	local p = Sim.player
	local tier = tonumber(p:GetAttribute("TreadmillTier")) or 1
	local cost = nextTreadmillCost()
	if Server.money < cost then
		entry.outcome = "rejected: cannot afford"
		table.insert(stats.upgradeRejected, { t = Sim.elapsed(), what = "treadmill", why = "cannot afford ($" .. cost .. ")" })
		return
	end
	Server.setMoney(Server.money - cost)
	p:SetAttribute("TreadmillTier", tier + 1)
	p:SetAttribute("TreadmillLevel", tier + 1)
	stats.treadmillUpgrades += 1
	entry.outcome = "accepted"
	slog("treadmill upgraded to tier " .. (tier + 1))
	Server.updateSigns()
end

handlers.rev_TREADMILL_DISMOUNT = function(args, entry)
	Server.dismount("TREADMILL_DISMOUNT")
end

handlers.rev_CRATE_DROP = function()
	if carrying() then
		Sim.player:SetAttribute("CarryingStolen", false)
		Sim.player:SetAttribute("CarryStat", 1)
		Server.updateWalkSpeed()
		Server.carry = nil
		stats.drops = (stats.drops or 0) + 1
		slog("crate dropped (CRATE_DROP)")
	end
end

Server.trails = { Owned = {}, Equipped = nil }
local function pushTrailState()
	fireClient("rev_TRAIL_STATE", { Owned = table.clone(Server.trails.Owned), Equipped = Server.trails.Equipped })
end
handlers.rev_TRAIL_STATE = function()
	pushTrailState()
end
handlers.rev_TRAIL_BUY = function(args, entry)
	local t = TrailDataModule:Get(args[1])
	if not t then
		entry.outcome = "rejected: unknown trail " .. Sim.describe(args[1])
	elseif Server.trails.Owned[t.Id] then
		entry.outcome = "rejected: already owned"
	elseif Server.money < t.Cost then
		entry.outcome = "rejected: cannot afford"
	else
		Server.setMoney(Server.money - t.Cost)
		Server.trails.Owned[t.Id] = true
		table.insert(stats.trailBuys, { t = Sim.elapsed(), id = t.Id })
		entry.outcome = "accepted"
		slog("trail bought: " .. t.Id)
	end
	pushTrailState()
end
handlers.rev_TRAIL_EQUIP = function(args, entry)
	local id = args[1]
	local p = Sim.player
	if id == nil then
		Server.trails.Equipped = nil
		p:SetAttribute("TrailMultiplier", 1)
	elseif not Server.trails.Owned[id] then
		entry.outcome = "rejected: trail not owned"
	else
		Server.trails.Equipped = id
		p:SetAttribute("TrailMultiplier", TrailDataModule:Get(id).Multiplier)
		table.insert(stats.trailEquips, { t = Sim.elapsed(), id = id })
		entry.outcome = "accepted"
		slog("trail equipped: " .. id)
	end
	Server.updateRunSpeed()
	pushTrailState()
end
handlers.rev_INDEX_CLAIM_ALL = function()
	stats.indexClaims += 1
end

invokers.rf_SELL_QUOTE = function(args)
	if Server.sellQuoteNil then
		return nil -- the live server answers nil (live logs)
	end
	local items = sellableItems()
	local total = 0
	for _, t in ipairs(items) do
		total += t:GetAttribute("ItemValue") or 0
	end
	local count = #items
	for _, parent in ipairs({ Sim.player.Backpack, Sim.player.Character }) do
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("Tool") and c:GetAttribute("CrateUid") then
				count += 1
				total += math.floor((c:GetAttribute("CrateValue") or 0) * ItemDataModule.Sell.CrateBlindFactor)
			end
		end
	end
	local held = equippedTool()
	local heldItem = held and held:GetAttribute("ItemUid") and held or nil
	return {
		HeldLabel = heldItem and heldItem.Name or nil,
		HeldPrice = heldItem and heldItem:GetAttribute("ItemValue") or nil,
		AllCount = count,
		AllTotal = total,
	}
end

invokers.rf_ITEM_LOADOUT = function(args)
	local action = args[1]
	if action == "placebest" then
		stats.placeBest += 1
		local floor = Server.myFloor
		local stands = 0
		for _, c in ipairs(floor:GetChildren()) do
			if c.Name == "ItemStand" then
				stands += 1
			end
		end
		local free = cfg("equipSlots") + (tonumber(Sim.player:GetAttribute("AddedSlots")) or 0) - stands
		local items = sellableItems()
		table.sort(items, function(a, b)
			return (a:GetAttribute("ItemValue") or 0) > (b:GetAttribute("ItemValue") or 0)
		end)
		local placed = 0
		for _, t in ipairs(items) do
			if placed >= free then
				break
			end
			local spot = freeServerSpot()
			if not spot then
				break
			end
			addItemStand(floor, spot, { name = t.Name, value = t:GetAttribute("ItemValue"), uid = t:GetAttribute("ItemUid") })
			t:Destroy()
			placed += 1
		end
		if placed > 0 then
			slog("placebest put " .. placed .. " item(s) on the plot")
		end
		return { ok = true, placed = placed }
	elseif action == "list" then
		local out = {}
		for _, t in ipairs(sellableItems()) do
			table.insert(out, { Uid = t:GetAttribute("ItemUid"), Name = t.Name, Value = t:GetAttribute("ItemValue") })
		end
		return out
	end
	return nil
end

-- LBTHCrateTimersClient: ("list") -> { {Uid, Ready, Remaining, Total, AreaId, CrateTier} }, ("open", Uid)
invokers.rf_CRATE_TIMERS = function(args, entry)
	local action = args[1]
	if action == "list" then
		local out = {}
		for _, g in ipairs(Server.growing) do
			if g.floor == Server.myFloor and not g.model.__destroyed then
				local total = cfg("appraiseTime")
				table.insert(out, {
					Uid = g.model:GetAttribute("CrateUid"),
					Ready = g.ready,
					Remaining = math.max(0, g.readyAt - Sim.now),
					Total = total,
					AreaId = g.info.area or "Grandpa",
					CrateTier = g.info.tier or "Common",
				})
			end
		end
		return out
	elseif action == "open" then
		local uid = args[2]
		for _, g in ipairs(Server.growing) do
			if g.floor == Server.myFloor and not g.model.__destroyed and g.model:GetAttribute("CrateUid") == uid then
				if not g.ready then
					entry.outcome = "rejected: crate not ready"
					return false
				end
				Server.openCrate(g, "rf_CRATE_TIMERS")
				return true
			end
		end
		entry.outcome = "rejected: unknown crate uid " .. Sim.describe(uid)
		table.insert(stats.openRejected, { t = Sim.elapsed(), why = entry.outcome })
		slog("CRATE_TIMERS open " .. entry.outcome)
		return false
	end
	return nil
end

local function rootPos()
	local root = Sim.rootPart()
	return root and root.Position
end

handlers.rev_STORM_COLLECT = function(args, entry)
	local index = tonumber(args[1])
	local orb = index and Server.orbs[index]
	local reason
	local pos = rootPos()
	if not orb then
		reason = "bad index"
	elseif Sim.services.Workspace:GetAttribute("StormActive") ~= true then
		reason = "no storm"
	elseif (Server.orbTaken[index] or 0) > Sim.now then
		reason = "taken"
	elseif not pos then
		reason = "no character"
	else
		local d = orb - pos
		if V(d.X, 0, d.Z).Magnitude > STORM.MAGNET_RADIUS + 2 or math.abs(d.Y) >= 20 then
			reason = fmt("far (%.0f studs)", V(d.X, 0, d.Z).Magnitude)
		end
	end
	if reason then
		entry.outcome = "rejected: " .. reason
		table.insert(stats.orbRejected, { t = Sim.elapsed(), index = index, why = reason })
		fireClient("rev_STORM_RESULT", index, false, if reason == "taken" then "taken" else reason)
		return
	end
	local points = STORM.ORB_SIZES[Server.orbSizes[index] or 2].Points
	Server.orbTaken[index] = Sim.now + STORM.RESPAWN_SECONDS
	Sim.player:SetAttribute("StormPoints", (tonumber(Sim.player:GetAttribute("StormPoints")) or 0) + points)
	table.insert(stats.orbs, { t = Sim.elapsed(), index = index, points = points })
	entry.outcome = "accepted"
	fireClient("rev_STORM_RESULT", index, true, points)
end

local function thunderCrates()
	local list = {}
	for _, parent in ipairs({ Sim.player.Backpack, Sim.player.Character }) do
		for _, c in ipairs(parent and parent:GetChildren() or {}) do
			if c:IsA("Tool") and c:GetAttribute("CrateUid") then
				local uid = c:GetAttribute("CrateUid")
				table.insert(list, { Uid = uid, Name = c.Name, AreaId = c:GetAttribute("CrateAreaId"), Tier = c:GetAttribute("CrateTier"), Charge = Server.charged[uid] })
			end
		end
	end
	return list
end

invokers.rf_THUNDER_MACHINE = function(args, entry)
	local action = args[1]
	local player = Sim.player
	local points = tonumber(player:GetAttribute("StormPoints")) or 0
	if action == "state" then
		return { ok = true, points = points, crates = thunderCrates() }
	elseif action == "mutate" then
		local uid, spend = args[2], tonumber(args[3]) or 0
		local pos = rootPos()
		local why
		if not pos or (pos - THUNDER_POS).Magnitude > 60 then
			why = "Get closer to the machine"
		elseif spend < STORM.MIN_SPEND or spend > math.min(points, STORM.MAX_CHARGE) then
			why = "Not enough storm points"
		else
			local found
			for _, c in ipairs(thunderCrates()) do
				if c.Uid == uid then
					found = c
				end
			end
			if not found then
				why = "Crate not found"
			elseif found.Charge then
				why = "Already charged"
			end
		end
		if why then
			entry.outcome = "rejected: " .. why
			table.insert(stats.chargeRejected, { t = Sim.elapsed(), why = why })
			return { ok = false, msg = why }
		end
		player:SetAttribute("StormPoints", points - spend)
		Server.charged[uid] = "Supercharged"
		table.insert(stats.charges, { t = Sim.elapsed(), uid = uid, spend = spend })
		entry.outcome = "accepted"
		return { ok = true, result = "Supercharged" }
	end
	return { ok = false, msg = "unknown action" }
end

handlers.rev_FUSE_ITEMS = function(args, entry)
	local uids = args[1]
	local why
	local tools = {}
	local pos = rootPos()
	if type(uids) ~= "table" or #uids ~= 3 then
		why = "needs 3 uids"
	elseif not pos or (pos - FUSE_POS).Magnitude > 25 then
		why = "not at the Fuse Machine"
	else
		for _, uid in ipairs(uids) do
			for _, parent in ipairs({ Sim.player.Backpack, Sim.player.Character }) do
				for _, c in ipairs(parent and parent:GetChildren() or {}) do
					if c:IsA("Tool") and c:GetAttribute("ItemUid") == uid and not table.find(tools, c) then
						table.insert(tools, c)
					end
				end
			end
		end
		if #tools ~= 3 then
			why = "items not found"
		elseif tools[1].Name ~= tools[2].Name or tools[1].Name ~= tools[3].Name then
			why = "not the same item"
		else
			for _, t in ipairs(tools) do
				if t:GetAttribute("ItemFused") then
					why = "already fused"
				end
			end
		end
	end
	local fee = 0
	if not why then
		local income = 0
		for _, t in ipairs(tools) do
			income = math.max(income, tonumber(t:GetAttribute("ItemIncome")) or 0)
		end
		fee = math.max(1, math.floor(income * (FUSE_FEE_SECONDS[tools[1]:GetAttribute("ItemTier")] or 60)))
		if Server.money < fee then
			why = "cannot afford $" .. fee
		end
	end
	if why then
		entry.outcome = "rejected: " .. why
		table.insert(stats.fuseRejected, { t = Sim.elapsed(), why = why })
		return
	end
	local name, tier, value = tools[1].Name, tools[1]:GetAttribute("ItemTier"), tools[1]:GetAttribute("ItemValue")
	for _, t in ipairs(tools) do
		t:Destroy()
	end
	Server.setMoney(Server.money - fee)
	local fused = Server.giveItemTool({ name = name, tier = tier, value = (value or 100) * 3 })
	fused:SetAttribute("ItemFused", true)
	table.insert(stats.fuses, { t = Sim.elapsed(), name = name, fee = fee })
	entry.outcome = "accepted"
	fireClient("rev_FUSE_RESULT", { Name = name })
end

handlers.rev_Offline_Claim = function(args, entry)
	if Server.offlinePending then
		Server.setMoney(Server.money + Server.offlinePending)
		Server.offlinePending = nil
		stats.offlineClaims += 1
		entry.outcome = "accepted"
	else
		entry.outcome = "nothing to claim"
	end
end

handlers.rev_FreeGiftState = function(args, entry)
	if type(args[3]) == "table" then
		Server.giftState = args[3]
	end
end

handlers.rev_GroupClaim = function(args, entry)
	local player = Sim.player
	local pos = rootPos()
	local why
	if player:GetAttribute("LBTHFreeGiftClaimed") == true then
		why = "already claimed"
	elseif not cfg("inGroup") then
		why = "not in the group"
	elseif not pos or (pos - GIFT_POS).Magnitude > 20 then
		why = "not at the chest"
	elseif not Server.giftState.Favorited then
		why = "not favorited"
	end
	if why then
		entry.outcome = "rejected: " .. why
		table.insert(stats.freeGiftRejected, why)
		fireClient("rev_GroupClaimResponse", false, nil, {})
		return
	end
	player:SetAttribute("LBTHFreeGiftClaimed", true)
	player:SetAttribute("SpeedLevel", (tonumber(player:GetAttribute("SpeedLevel")) or 0) + 10000)
	stats.freeGift += 1
	entry.outcome = "accepted"
	fireClient("rev_GroupClaimResponse", true, nil, { Claimed = true })
end

handlers.rev_INDEX_EQUIP_BAT = function(args, entry)
	local owned = cfg("indexBats") and cfg("indexBats").Owned or { Default = true }
	if owned[args[1]] then
		table.insert(stats.batEquips, args[1])
		entry.outcome = "accepted"
	else
		entry.outcome = "rejected: bat not owned"
	end
end

for _, n in ipairs({ "rev_ItemVisibilitySet" }) do
	handlers[n] = function(args, entry) end
end

function Server.onEvent(remoteInst, args, entry)
	local name = remoteInst.Name
	local h = handlers[name]
	if not h then
		stats.unhandled[name] = (stats.unhandled[name] or 0) + 1
		slog("no server handler for " .. name .. " (the real game may ignore or reject this)")
		return
	end
	h(args, entry)
	if entry.outcome and entry.outcome ~= "accepted" then
		slog(name .. " " .. entry.outcome)
	end
end

function Server.onInvoke(remoteInst, args, entry)
	local name = remoteInst.Name
	local h = invokers[name]
	if not h then
		stats.unhandled[name] = (stats.unhandled[name] or 0) + 1
		slog("no server handler for " .. name)
		return nil
	end
	return h(args, entry)
end
