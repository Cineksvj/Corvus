-- e. Every automation on at once for 300 s. The player starts on the treadmill (like in the dump),
-- with one banked crate and two items, and a crate on the plot that is ready to open.
local FEATURES = {
	"AutoSteal", "SmartZones", "AutoSell", "AutoPlace", "AutoOpen", "AutoEquipBest", "AutoBuySlot",
	"AutoUpgradePlot", "AutoTreadmill", "AutoUpgradeTreadmill", "AutoIndex", "AutoTrails", "AutoEquipTrail",
}
Scenario {
	name = "e_everything",
	description = "All toggles on (steal, place, open, sell, equip best, buy slot, upgrade plot, treadmill, upgrade treadmill, "
		.. "index, trails) for 300 s, starting on the treadmill. Expect no Lua errors, no deadlock, the main loop keeps "
		.. "switching between jobs and every remote gets sane arguments.",
	duration = 300,
	stallLimit = 45,
	world = {
		startOnTreadmill = true,
		appraiseTime = 25,
		backpack = {
			{ kind = "crate", area = "Grandpa", token = "Rare" },
			{ kind = "item", name = "Old Lamp", value = 200 },
			{ kind = "item", name = "Silver Cup", value = 300 },
		},
		floor = { { kind = "crate", x = 12, z = 12, tier = "Epic", readyIn = 0 } },
	},
	options = function(Toggles, Options, Sim)
		for _, name in ipairs(FEATURES) do
			assert(Toggles[name], "missing toggle " .. name)
			Toggles[name].Value = true
		end
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		local floor = Sim.Server.myFloor
		check(Sim.mainLoopCycles >= 200, "main loop keeps cycling", Sim.mainLoopCycles)
		for _, pattern in ipairs({ "^Stealing", "^Bringing the crate home", "^Crate brought home", "^Placing crates", "^Selling", "treadmill" }) do
			check(Sim.statusSeen(pattern), "status reached: " .. pattern)
		end
		check(#st.banked >= 3, "crates stolen and banked", #st.banked)
		check(#st.caught == 0, "the guard never caught the player", #st.caught)
		check(st.snapTeleport + st.snapSpeed == 0, "no server snap-backs", st.snapTeleport + st.snapSpeed)
		check(#st.placed >= 3, "crates placed", #st.placed)
		check(#st.placeRejected == 0, "no placement rejected", Sim.describe(st.placeRejected))
		check(#st.opened >= 2, "crates opened", #st.opened)
		check(#st.sold >= 1, "items sold", #st.sold)
		check(#st.sellRejected == 0, "no sale rejected", Sim.describe(st.sellRejected))
		check(#st.trailBuys >= 1 and #st.trailEquips >= 1, "trails bought and the best one equipped", #st.trailBuys .. " buys, " .. #st.trailEquips .. " equips")
		check(st.indexClaims >= 20, "index claimed every ~10 s", st.indexClaims)
		check(st.mounts >= 2, "went back on the treadmill when idle", st.mounts)

		-- remote argument sanity
		local bad = {}
		local function bad_(e, why)
			table.insert(bad, string.format("%s(%s) @%.1fs: %s", e.name, e.text, e.t, why))
		end
		local trailIds = {}
		for _, t in ipairs(Sim.TrailData.Trails) do
			trailIds[t.Id] = true
		end
		for _, e in ipairs(Sim.remoteLog) do
			local a = e.args
			if e.name == "re_PLACE_AT" then
				if typeof(a[1]) ~= "Vector3" or type(a[2]) ~= "number" then bad_(e, "expected (Vector3, number)") end
			elseif e.name == "re_PLOT_UPGRADE" then
				if a[1] ~= floor or not (a[2] == nil or a[2] == true) then bad_(e, "expected (myFloor[, true])") end
			elseif e.name == "re_TREADMILL_UPGRADE" then
				if a[1] ~= floor then bad_(e, "expected (myFloor)") end
				if e.outcome ~= "accepted" then bad_(e, "fired while the sign said it cannot be afforded: " .. tostring(e.outcome)) end
			elseif e.name == "re_SELL_DO" then
				if a[1] ~= "all" and a[1] ~= "held" then bad_(e, "bad sell mode") end
			elseif e.name == "rev_TRAIL_BUY" or e.name == "rev_TRAIL_EQUIP" then
				if not trailIds[a[1]] then bad_(e, "unknown trail id") end
				if e.outcome ~= "accepted" then bad_(e, tostring(e.outcome)) end
			elseif e.name == "rf_CRATE_TIMERS" then
				if not (a[1] == "list" or (a[1] == "open" and type(a[2]) == "string")) then bad_(e, "bad crate timers call") end
			elseif e.name == "rf_ITEM_LOADOUT" then
				if a[1] ~= "placebest" then bad_(e, "unexpected loadout action") end
			end
		end
		check(#bad == 0, "every remote got sane arguments", table.concat(bad, " | "))
		local plotUps = 0
		for _, e in ipairs(Sim.remotes("re_PLOT_UPGRADE")) do
			if e.args[2] == nil and e.outcome ~= "accepted" then
				plotUps += 1
			end
		end
		check(plotUps == 0, "plot upgrades only fired when the sign said CanAfford", plotUps)
		local slotRejected = 0
		for _, r in ipairs(st.upgradeRejected) do
			if r.what == "slot" then
				slotRejected += 1
			end
		end
		Sim.log("INFO", "AutoBuySlot: " .. st.slotBuys .. " bought, " .. slotRejected .. " requests refused (cannot afford)")
	end,
}
