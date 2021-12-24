require "/scripts/vec2.lua"

function init()
	local particles = {}
	for _,p in ipairs(config.getParameter("thrownParticles", {})) do
		particles[#particles+1] = {
			time = 0,
			["repeat"] = false,
			action = "particle",
			specification = p
		}
	end
	
	emitterParams = {
		periodicActions = particles,
		timeToLive = 0,
		speed = 0,
		onlyHitTerrain = true,
		damageType = "NoDamage",
		processing = "?multiply=0000",
		movementSettings = {collisionEnabled = false}
	}
	
	rotationSpeed = config.getParameter("rotationSpeed", 20)
end

function update(dt)
	if not stuck then
		local velocity = mcontroller.velocity()
		
		if mcontroller.isColliding() or mcontroller.isCollisionStuck() then
			stuck = true
			mcontroller.setRotation(vec2.angle(lastVelocity or velocity))
		else
			local dir = velocity[1] > 0 and 1 or -1
			local rotation = (vec2.mag(velocity) / 180 * math.pi) * -dir * dt * rotationSpeed
			mcontroller.setRotation(mcontroller.rotation() + rotation)
			
			world.spawnProjectile("invisibleprojectile", mcontroller.position(), 0, {0, 0}, false, emitterParams)
		end
		
		lastVelocity = velocity
	end
end
