-- To use: add the "flipx" parameter to stances using this script, and set it to either true or false.  
-- Note that this will also flip any animations and damage areas associated with the stance

-- Melee primary ability
MeleeCombo = WeaponAbility:new()

function MeleeCombo:init()
  self.comboStep = 1

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns()

  self:setState(self.unsheathe)

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.animKeyPrefix = self.animKeyPrefix or ""

  self.weapon.onLeaveAbility = function()
	animator.setFlipped(false)
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function MeleeCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end

  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

-- State: windup
function MeleeCombo:windup()
  local stance = self.stances["windup"..self.comboStep]

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0
  
  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function MeleeCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]

  self.weapon:setStance(stance)
  
  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)

  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function MeleeCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function MeleeCombo:fire()
  local stance = self.stances["fire"..self.comboStep]

  self.weapon:setStance(stance)
  
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  local damageArea = partDamageArea("swoosh")
  if self.canCut then
    self:damageTiles(damageArea)
  end
  
  util.wait(stance.duration, function()
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
  end)

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

--Hi is me the nebby boi - Nebulox if you're dumb
function MeleeCombo:damageTiles(area)
  local miningPositions = self:nebFindAllPointsInPolygon(area)
  --Calculate tile damage per frame
  local levelMultiplier = 1
  if self.considerLevel then 
    levelMultiplier = config.getParameter("level", 1)
  end
  local tileDamage = levelMultiplier * self.tileDamagePerSwing
  
  --Reset damageTiles at the start of every frame
  self.damagingTiles = false
  
  --Optionally damage foreground tiles
  if self.damageForeground and tileDamage > 0 and self.tileDamagePerSwing > 0 then
	if world.damageTiles(miningPositions, "foreground", mcontroller.position(), self.tileDamageType, tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
  
  --Optionally damage background tiles
  if self.damageBackground and tileDamage > 0 and self.tileDamagePerSwing > 0 then
	if world.damageTiles(miningPositions, "background", mcontroller.position(), self.tileDamageType, tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
end

function MeleeCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function MeleeCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function MeleeCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), self.stepDamageConfig[i])
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
end

--Helper functions and hooks
local oldSetStance = self.weapon.setStance
function self.weapon:setStance(stance)
  oldSetStance(self, stance)
  
  animator.setFlipped(stance.flipx == true)

  local velocity = (not mcontroller.groundMovement()) and stance.airVelocity or stance.velocity
  if velocity then
	local v = copy(velocity)
		
	v[1] = v[1] * mcontroller.facingDirection()
	if not stance.resetVelocity then
	  v = vec2.add(v, mcontroller.velocity())
	end	
	mcontroller.setVelocity(v)
  end
end

function MeleeCombo:unsheathe()
  if not self.stances.unsheathe then return end

  self.weapon:setStance(self.stances.unsheathe)
  util.wait(self.stances.unsheathe.duration)
  return true
end

function MeleeCombo:nebFindAllPointsInPolygon(poly)
  local first = poly[1]
  if not first then return {} end
  local contains = world.polyContains
  local minX, maxX = first[1], first[1]
  local minY, maxY = first[2], first[2]
  for i = 1, #poly do
    local point = poly[i]
    local x, y = point[1], point[2]
    if     minX > x then minX = x
    elseif maxX < x then maxX = x end
    if     minY > y then minY = y
    elseif maxY < y then maxY = y end
  end
  local t = {}
  local tI = 0
  for x = math.ceil(minX - 0.5), math.floor(maxX - 0.5) do
      for y = math.ceil(minY - 0.5), math.floor(maxY - 0.5) do
        if contains(poly, {x + 0.5, y + 0.5}) then
          tI = tI + 1
          t[tI] = vec2.add(mcontroller.position(), {x, y})
        end
      end
  end
  return t
end

function MeleeCombo:uninit()
  self.weapon:setDamage()
end
