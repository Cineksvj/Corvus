-- g. Rarity filter. Crate names carry ItemData tiers (Crate_<Area>_<Tier>_N<k>); with only "Rare"
-- selected in Grandpa + Jeweler, only Rare crates may be stolen.
Scenario {
	name = "g_rarity_filter",
	description = "Auto Steal, zones Grandpa + Jeweler (SpeedLevel 55555), rarity filter = {Rare}. Only Rare crates may be stolen.",
	duration = 90,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
		Sim.selectZones({ "Grandpa", "Jeweler" })
		Sim.selectRarities({ "Rare" })
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		local wrong = {}
		for _, s in ipairs(st.steals) do
			if s.token ~= "Rare" then
				table.insert(wrong, s.name)
			end
		end
		check(#st.steals >= 2, "Rare crates stolen", #st.steals)
		check(#wrong == 0, "only Rare crates stolen", table.concat(wrong, ", "))
		check(#st.banked == #st.steals, "every stolen crate banked", #st.banked .. "/" .. #st.steals)
	end,
}
