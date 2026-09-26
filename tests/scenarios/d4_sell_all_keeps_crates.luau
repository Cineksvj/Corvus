-- d4. Sell Mode = All with unopened crates in the backpack and Sell Unopened Crates off:
-- "all" would sell the crates at 35%, so the items are sold one by one and the crates kept.
-- rf_SELL_QUOTE answers nil like the live server.
Scenario {
	name = "d4_sell_all_keeps_crates",
	description = "Auto Sell (All), quote nil, 2 items + 2 crates, Sell Unopened Crates off: expect 2 accepted re_SELL_DO('held'), no 'all', crates kept.",
	duration = 40,
	world = {
		backpack = {
			{ kind = "item", name = "Old Lamp", value = 200 },
			{ kind = "item", name = "Gold Ring", value = 500 },
			{ kind = "crate", area = "Grandpa", token = "Rare" },
			{ kind = "crate", area = "Grandpa", token = "Common" },
		},
		equipSlots = 0,
	},
	setup = function(Sim)
		Sim.Server.sellQuoteNil = true
	end,
	options = function(Toggles, Options, Sim)
		Toggles.AutoSell.Value = true
	end,
	checks = function(Sim, check)
		local held, all = 0, 0
		for _, e in ipairs(Sim.remotes("re_SELL_DO")) do
			if e.args[1] == "held" and e.outcome == "accepted" then
				held += 1
			elseif e.args[1] == "all" then
				all += 1
			end
		end
		check(all == 0, "never fired re_SELL_DO('all') while carrying crates", all)
		check(held == 2, "2 accepted re_SELL_DO('held')", held)
		check(Sim.countTools("CrateUid") == 2, "both unopened crates kept", Sim.countTools("CrateUid"))
		check(Sim.countTools("ItemUid") == 0, "all items sold", Sim.countTools("ItemUid"))
	end,
}
