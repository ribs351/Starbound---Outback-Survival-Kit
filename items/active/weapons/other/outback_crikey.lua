local oldupdate = update or function() end
function update(...)
	oldupdate(...)
	status.addEphemeralEffect("outback_crikey")
end
