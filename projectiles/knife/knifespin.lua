function init()
end

function update()
  local direction = (mcontroller.xVelocity() > 0 and 1 or -1)
  mcontroller.setRotation(mcontroller.rotation() + 1 * -direction)
end