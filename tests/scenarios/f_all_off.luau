-- f. Every toggle off. The player owns trails (not the best one equipped) and has crates/items,
-- so any automation that still ran would show up as a remote call or movement.
local START = Vector3.new(2440, 5, -935)
Scenario {
	name = "f_all_off",
	description = "All toggles OFF for 60 s: only harmless state requests (rev_TRAIL_STATE) may be sent, the player must not move, status stays Idle.",
	duration = 60,
	world = {
		position = START,
		backpack = { { kind = "crate", area = "Grandpa", token = "Rare" }, { kind = "item", name = "Old Lamp", value = 200 } },
		floor = { { kind = "crate", x = 12, z = 12, tier = "Epic", readyIn = 0 } },
	},
	setup = function(Sim)
		Sim.Server.trails.Owned = { Grey = true, Green = true }
		Sim.Server.trails.Equipped = "Grey"
	end,
	options = function(Toggles, Options, Sim)
		for _, t in pairs(Toggles) do
			t.Value = false
		end
	end,
	checks = function(Sim, check)
		local harmless = { rev_TRAIL_STATE = true }
		local other = {}
		for _, e in ipairs(Sim.remoteLog) do
			if not harmless[e.name] then
				table.insert(other, string.format("%s(%s)@%.1fs", e.name, e.text, e.t))
			end
		end
		check(#other == 0, "no remotes other than state requests", table.concat(other, ", "))
		check(Sim.status == "Idle", "final status is Idle", Sim.status)
		local moved = (Sim.rootPart().Position - START).Magnitude
		check(moved < 0.01, "the player never moved", string.format("%.2f studs", moved))
		check(Sim.countTools("CrateUid") == 1 and Sim.countTools("ItemUid") == 1, "inventory untouched")
	end,
}
