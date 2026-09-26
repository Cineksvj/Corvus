-- c3. The executor provides fireproximityprompt and the engine never shows the prompt (e.g. the
-- game's custom prompt UI is suppressed). The script must fall back to fireproximityprompt.
Scenario {
	name = "c3_fireproximityprompt",
	description = "Auto Steal (Grandpa) with fireproximityprompt available and ProximityPromptService never showing prompts: "
		.. "the fallback path must still steal and bank crates.",
	duration = 120,
	world = { fireproximityprompt = true, promptsNeverShow = true },
	options = function(Toggles, Options, Sim)
		Toggles.AutoSteal.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check((Sim.counters.fireproximityprompt or 0) > 0, "fireproximityprompt was used", Sim.counters.fireproximityprompt or 0)
		check(#st.steals >= 2, "at least 2 crates stolen through the fallback", #st.steals)
		check(#st.banked >= 2, "at least 2 crates banked", #st.banked)
		check(#st.caught == 0, "the guard never caught the player", #st.caught)
	end,
}
