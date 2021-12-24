function init()
	max = effect.getParameter("maxPowerMultiplier", 3)
	groupId = effect.addStatModifierGroup({})
end

function update(dt)
	local health = status.resourcePercentage("health")
	local mul = max + (1 - max) * health
  effect.setStatModifierGroup(groupId, {{stat = "powerMultiplier", effectiveMultiplier = mul}})
end
