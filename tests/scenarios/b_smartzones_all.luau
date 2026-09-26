-- b. All zones selected, "Only Zones I Can Escape" on, SpeedLevel 55555 (the dump's player).
-- Allowed zones: RecommendedSpeed <= 55555 -> Grandpa, Jeweler, Archeologist, MafiaBoss.
Scenario {
	name = "b_smartzones_all",
	description = "Auto Steal, ALL zones, SmartZones ON, SpeedLevel 55555. Expect the highest allowed zone (MafiaBoss) first, "
		.. "carried home at run speed without server snap-backs, crates banked, no deadlock.",
	duration = 240,
	world = { attrs = { SpeedLevel = 55555 } },
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
		Toggles.SmartZones.Value = true
		local all = {}
		for _, label in ipairs(Options.StealZones.Values) do
			all[label] = true
		end
		Options.StealZones.Value = all
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		local level = 55555
		check(#st.steals >= 3, "at least 3 crates stolen", #st.steals)
		check(st.steals[1] and st.steals[1].area == "MafiaBoss", "first steal is from the highest allowed zone (MafiaBoss)", st.steals[1] and st.steals[1].area)
		local tooHigh = {}
		for _, s in ipairs(st.steals) do
			if Sim.AreaById[s.area].RecommendedSpeed > level then
				table.insert(tooHigh, s.area)
			end
		end
		check(#tooHigh == 0, "never steals from a zone above the speed level", table.concat(tooHigh, ","))
		check(#st.banked >= 3, "at least 3 crates banked", #st.banked)
		check(#st.caught == 0, "the guard never caught the player", #st.caught)
		check(st.snapTeleport + st.snapSpeed == 0, "no server snap-backs while carrying", st.snapTeleport + st.snapSpeed)
		local seen, s = Sim.statusSeen("Could not")
		check(not seen, "no 'Could not ...' status (no aborted trips)", s and s.text)
		check(Sim.mainLoopCycles > 50, "main loop keeps cycling", Sim.mainLoopCycles)
		-- MafiaBoss has 3 nests; after they are gone it must move on to the next zone
		local later = false
		for i, s in ipairs(st.steals) do
			if i > 3 and s.area ~= "MafiaBoss" then
				later = true
			end
		end
		check(#st.steals <= 3 or later, "moves on to the next zone once MafiaBoss is empty", Sim.areaCounts(st.steals))
	end,
}
