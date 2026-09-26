-- r. Free rewards with the default toggles: offline cash popup, the Free Gift (player is in the
-- group) and the best bat from the index state.
Scenario {
	name = "r_rewards",
	description = "Defaults + offline cash 5000, in the group, bats Default/Grandpa/Jeweler owned: claim offline, claim the Free Gift, equip Jeweler.",
	duration = 40,
	world = {
		offlineCash = 5000,
		offlineAt = 1,
		inGroup = true,
		indexBats = { Owned = { Default = true, Grandpa = true, Jeweler = true }, Equipped = "Default" },
	},
	checks = function(Sim, check)
		local st = Sim.stats
		check(st.offlineClaims == 1, "offline cash claimed once", st.offlineClaims)
		check(st.freeGift == 1, "Free Gift claimed", st.freeGift .. " " .. Sim.describe(st.freeGiftRejected))
		check(Sim.player:GetAttribute("LBTHFreeGiftClaimed") == true, "LBTHFreeGiftClaimed set")
		check(#st.batEquips >= 1 and st.batEquips[#st.batEquips] == "Jeweler", "equipped the best owned bat (Jeweler)", Sim.describe(st.batEquips))
	end,
}
