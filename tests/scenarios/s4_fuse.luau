-- s4. Fuse Machine: 3x Old Lamp and 2x Gold Ring. Auto Fuse must fuse the three lamps once (at the
-- machine, paying the fee) and leave the rings alone.
Scenario {
	name = "s4_fuse",
	description = "Auto Fuse with 3x Old Lamp + 2x Gold Ring: one accepted FUSE_ITEMS for Old Lamp, rings kept.",
	duration = 40,
	world = {
		backpack = {
			{ kind = "item", name = "Old Lamp", value = 200 },
			{ kind = "item", name = "Old Lamp", value = 200 },
			{ kind = "item", name = "Old Lamp", value = 200 },
			{ kind = "item", name = "Gold Ring", value = 500 },
			{ kind = "item", name = "Gold Ring", value = 500 },
		},
	},
	options = function(Toggles, Options, Sim)
		Toggles.AutoFuse.Value = true
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(#st.fuses == 1 and st.fuses[1].name == "Old Lamp", "fused the 3 lamps once", Sim.describe(st.fuses))
		check(#st.fuseRejected == 0, "no rejected fuses", Sim.describe(st.fuseRejected))
		local rings, fused = 0, 0
		for _, t in ipairs(Sim.player.Backpack:GetChildren()) do
			if t.Name == "Gold Ring" then
				rings += 1
			end
			if t:GetAttribute("ItemFused") then
				fused += 1
			end
		end
		check(rings == 2, "both rings kept", rings)
		check(fused == 1, "one fused item in the backpack", fused)
	end,
}
