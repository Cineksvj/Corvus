-- b3. A carry trip longer than 45 s (SmartZones off, DemonKing selected by hand, SpeedLevel 55555,
-- ~56 s run home). The sim's guard allows the whole trip (distance / carry speed + 10 s), so the
-- crate can be banked if the script just keeps running.
Scenario {
	name = "b3_long_carry_drop",
	description = "Auto Steal, zone = DemonKing only, SmartZones OFF, SpeedLevel 55555: a ~56 s carry home that the guard in this "
		.. "sim allows (~63 s). The script must keep running and bank it, not abort the trip and drop the crate.",
	duration = 120,
	stallLimit = 90, -- one legitimate carry trip takes ~56 s (a single main-loop cycle)
	world = { attrs = { SpeedLevel = 55555 } },
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
		Sim.selectZones({ "DemonKing" })
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.steals >= 1, "stole a DemonKing crate", #st.steals)
		check((st.drops or 0) == 0, "never dropped a crate it could still bring home (CRATE_DROP)", st.drops or 0)
		check(#st.banked >= 1, "the crate was banked", #st.banked)
		local seen, s = Sim.statusSeen("Could not reach")
		check(not seen, "trip home not aborted", s and string.format("%s at t=%.1f", s.text, s.t))
	end,
}
