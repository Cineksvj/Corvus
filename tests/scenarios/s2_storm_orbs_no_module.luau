-- s2. Same as s, but StormConfig cannot be required: the hub's own copy of computeLayout must
-- produce the same orb positions as the game's.
Scenario {
	name = "s2_storm_orbs_no_module",
	description = "Storm on, StormConfig module missing: the hub's fallback layout must match the server's orbs.",
	duration = 60,
	world = { storm = true, stormSeconds = 400, stormNoModule = true },
	options = function(Toggles, Options, Sim)
		Toggles.AutoOrbs.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.orbs >= 20, "collected at least 20 orbs", #st.orbs)
		local far = 0
		for _, r in ipairs(st.orbRejected) do
			if tostring(r.why):find("far") then
				far += 1
			end
		end
		check(far <= 2, "(almost) no out-of-range collects", far)
	end,
}
