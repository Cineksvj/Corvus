-- h. The guard is faster than the player in every zone (guard allowance 2 s shorter than the run home),
-- so every steal is taken back. The script must back off caught zones (rev_ChaseCaught(areaId))
-- instead of looping, and never go back into a zone within 90 s of being caught there.
Scenario {
	name = "h_guard_backoff",
	description = "Guard always wins (guardSlack = -2 s). Expect rev_ChaseCaught -> zone back-off, no tight steal/caught loop, "
		.. "no errors or deadlock.",
	duration = 200,
	world = { guardSlack = -2 },
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
		Sim.selectZones({ "Jeweler", "Archeologist", "MafiaBoss" })
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.caught >= 1, "the guard caught the player (setup sanity)", #st.caught)
		local lastCaught, violations = {}, {}
		for _, s in ipairs(st.steals) do
			local c = lastCaught[s.area]
			if c and s.t - c < 89 then
				table.insert(violations, string.format("%s again %.0fs after being caught", s.area, s.t - c))
			end
			for _, cc in ipairs(st.caught) do
				if cc.area == s.area and cc.t >= s.t then
					lastCaught[s.area] = cc.t
					break
				end
			end
		end
		check(#violations == 0, "no zone re-entered within 90 s of the guard catching you there", table.concat(violations, "; "))
		check(#st.steals <= 8, "no tight steal/caught loop", #st.steals)
		check(Sim.statusSeen("guard took the crate back"), "status explains the guard took the crate")
	end,
}
