-- Created by Circlemaniac

local RC = require("RCcar.RCmain")
events.TICK:register(function ()
   if world.getTimeOfDay() - math.floor(world.getTimeOfDay()/24000)*24000 > 12500 or not world.isOpenSky(RC:getPos()) then
      models.RCcar.model.root.Base.HLights:setPrimaryRenderType("EMISSIVE_SOLID")
   else
      models.RCcar.model.root.Base.HLights:setPrimaryRenderType("CUTOUT_CULL")
   end
   if RC:getEngineSpeed() <= 0.05 then
      models.RCcar.model.root.Base.RLights:setPrimaryRenderType("EMISSIVE_SOLID")
   else
      models.RCcar.model.root.Base.RLights:setPrimaryRenderType("CUTOUT_CULL")
   end
end)