local attachment = ui.find("Visuals", "Players", "Self", "Chams", "Weapon")
	
events.render:set(function(  )
	
	local lp = entity.get_local_player()
	
	if not lp or not lp:is_alive() then return end 
	
	local enable = common.is_in_thirdperson()
	
	attachment:override(enable)

end)
	
events.shutdown:set(function()

	attachment:override()

end)
