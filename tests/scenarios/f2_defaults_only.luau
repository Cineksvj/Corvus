-- f2. Nothing changed after loading (default toggles, which include Auto Equip Best Trail = ON).
-- The only thing the hub may do is equip the best owned trail.
Scenario {
	name = "f2_defaults_only",
	description = "Default options for 30 s, owned trails Grey+Green with Grey equipped: the default-on Auto Equip Best Trail "
		.. "may equip Green; nothing else may happen.",
	duration = 30,
	setup = function(Sim)
		Sim.Server.trails.Owned = { Grey = true, Green = true }
		Sim.Server.trails.Equipped = "Grey"
	end,
	checks = function(Sim, check)
		local other = {}
		for _, e in ipairs(Sim.remoteLog) do
			if e.name ~= "rev_TRAIL_STATE" and e.name ~= "rev_TRAIL_EQUIP" then
				table.insert(other, e.name)
			end
		end
		check(#other == 0, "no remotes besides trail state/equip", table.concat(other, ", "))
		local equips = Sim.remotes("rev_TRAIL_EQUIP")
		check(#equips <= 1 and (#equips == 0 or equips[1].args[1] == "Green"), "at most one TRAIL_EQUIP, for the best owned trail", #equips > 0 and equips[1].text or "none")
		check(Sim.status == "Idle", "final status is Idle", Sim.status)
	end,
}
