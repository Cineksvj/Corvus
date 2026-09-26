-- d2. Sell Mode = Held: every item is equipped and sold on its own; crates are never sold.
Scenario {
	name = "d2_sell_held",
	description = "Auto Sell with Sell Mode = Held, 3 items + 1 unopened crate: expect 3 accepted re_SELL_DO('held'), the crate kept.",
	duration = 40,
	world = {
		backpack = {
			{ kind = "item", name = "Old Lamp", value = 200 },
			{ kind = "item", name = "Silver Cup", value = 300 },
			{ kind = "item", name = "Gold Ring", value = 500 },
			{ kind = "crate", area = "Grandpa", token = "Rare" },
		},
		equipSlots = 0,
	},
	options = function(Toggles, Options, Sim)
		Toggles.AutoSell.Value = true
		Options.SellMode.Value = "Held"
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		local held = 0
		for _, e in ipairs(Sim.remotes("re_SELL_DO")) do
			if e.args[1] == "held" and e.outcome == "accepted" then
				held += 1
			end
		end
		check(held == 3, "3 accepted re_SELL_DO('held')", held)
		check(#st.sellRejected == 0, "no rejected sales", Sim.describe(st.sellRejected))
		check(Sim.countTools("CrateUid") == 1, "the unopened crate is kept", Sim.countTools("CrateUid"))
		check(Sim.countTools("ItemUid") == 0, "all items sold", Sim.countTools("ItemUid"))
	end,
}
