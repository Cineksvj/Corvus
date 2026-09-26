-- t. Auto Go On Treadmill only: walk onto the own belt, get mounted by the server, stay there.
Scenario {
	name = "t_treadmill",
	description = "Auto Treadmill only for 60 s from the lobby: mount once, keep training, SpeedLevel grows, no dismount flapping.",
	duration = 60,
	options = function(Toggles, Options, Sim)
		Toggles.AutoTreadmill.Value = true
		Sim.levelAtStart = Sim.player:GetAttribute("SpeedLevel")
	end,
	checks = function(Sim, check)
		local st = Sim.stats
		check(st.mounts == 1, "mounted exactly once", st.mounts)
		check(st.dismounts == 0, "never dismounted", st.dismounts)
		check(Sim.player:GetAttribute("OnTreadmill") == true, "still on the treadmill at the end")
		check(Sim.player:GetAttribute("SpeedLevel") > Sim.levelAtStart, "speed level grew", Sim.player:GetAttribute("SpeedLevel") - Sim.levelAtStart)
		check(Sim.status == "Training on the treadmill", "status says training", Sim.status)
	end,
}
