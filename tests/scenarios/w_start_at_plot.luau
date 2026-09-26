-- w. Live log 5: the hub started on the plot (2458, 3, -1078), south of the safe zone. The lobby
-- and the arena are only connected through the safe zone; running straight at a crate pinned the
-- player against the wall at X=2424.5 for 30 s. The trip must go through the safe zone.
Scenario {
	name = "w_start_at_plot",
	description = "Auto Steal (Grandpa) starting on the plot: every trip into the arena goes through the safe zone, no wall hits.",
	duration = 60,
	world = { position = Vector3.new(2458.4, 3.0, -1078.7) },
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.banked >= 2, "banked at least 2 crates", #st.banked)
		check(st.wallHits == 0, "never ran into the lobby wall", st.wallHits)
		local first = st.steals[1]
		check(first and first.t < 20, "first steal within 20 s", first and string.format("%.1f s", first.t))
	end,
}
