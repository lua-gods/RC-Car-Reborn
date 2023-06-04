local RC = require("RCcar.RCmain")
events.TICK:register(function ()
   if world.getLightLevel(RC:getPos()) < 7 then
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