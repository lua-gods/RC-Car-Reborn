if not host:isHost() then return end
local RC = require("RCcar.RCmain")

events.WORLD_RENDER:register(function (delta)
   local d = RC:getEngineThrottleData()
   local s = math.floor(d.z*30)
   local kmph = math.floor(math.abs(RC:getLocalVel(delta).z) * 72)
   if RC:isActive() then
      host:setActionbar('[{"color":"red","text":"' .. ('|'):rep(s) .. '"},{"text":"' .. ('|'):rep(30-s) .. '","color":"black"},{"text":" ' .. (kmph) .. ' km/h","color":"white"}]')
   end
end)