local RC = require("RCcar.RCmain")
events.RENDER:register(function (delta, context)
   local hide = (context ~= "FIRST_PERSON" or not RC:getCarProperties().engine)
   renderer.renderHUD = hide
end)
