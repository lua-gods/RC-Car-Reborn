local RC = require("RCcar.RCmain")

local age = 0

events.ENTITY_INIT:register(function ()
   local slim_jim = player:getModelType() =="SLIM"
   models.RCcar.model.root.Base.Doll.B.LA.LASlim:setVisible(slim_jim)
   models.RCcar.model.root.Base.Doll.B.RA.RASlim:setVisible(slim_jim)
   models.RCcar.model.root.Base.Doll.B.LA.LANormal:setVisible(not slim_jim)
   models.RCcar.model.root.Base.Doll.B.RA.RANormal:setVisible(not slim_jim)
end)

events.TICK:register(function ()
   models.RCcar.model.root.Base.Doll:setPrimaryTexture("SKIN")
   if age > 30 then
      events.TICK:remove("skin_applier")
   end
   age = age + 1
end,"skin_applier")

events.WORLD_RENDER:register(function (delta)
   local true_steer = RC:getSteer(delta)
   models.RCcar.model.root.Base.Doll.B.LA:setRot(60-true_steer,-(true_steer*true_steer)*0.01-5,0)
   models.RCcar.model.root.Base.Doll.B.RA:setRot(60+true_steer,5+(true_steer*true_steer)*0.01,0)
   models.RCcar.model.root.Base.SteeringWheel.Hinge:setRot(0,true_steer,0)
   models.RCcar.model.root.Base.Doll.B:setRot(0,0,true_steer*0.1)
   models.RCcar.model.root.Base.Doll.B.H:setVisible(RC:getCameraTransition() < 0.90 or not renderer:isFirstPerson())
end)