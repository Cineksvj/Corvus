-- a. Auto Steal with the default zone filter (Grandpa only) and default options.
Scenario {
	name = "a_autosteal_grandpa",
	description = "Auto Steal, zone filter = Grandpa only (default), all other options default. Expect >= 3 crates stolen and banked within 120 s.",
	duration = 120,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.steals >= 3, "at least 3 crates stolen", #st.steals)
		check(#st.banked >= 3, "at least 3 crates banked in the safe zone", #st.banked)
		check(Sim.countTools("CrateUid") >= 3, "banked crates are Tools with CrateUid in the backpack", Sim.countTools("CrateUid"))
		local onlyGrandpa = true
		for _, s in ipairs(st.steals) do
			onlyGrandpa = onlyGrandpa and s.area == "Grandpa"
		end
		check(onlyGrandpa, "only Grandpa crates stolen", Sim.areaCounts(st.steals))
		check(#st.caught == 0, "the guard never caught the player", #st.caught)
		check(st.snapTeleport + st.snapSpeed == 0, "no server snap-backs while carrying", st.snapTeleport + st.snapSpeed)
		check(not Sim.statusSeen("Could not"), "no 'Could not ...' status", select(2, Sim.statusSeen("Could not")) and select(2, Sim.statusSeen("Could not")).text)
	end,
}
