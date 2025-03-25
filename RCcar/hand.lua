local RC = require("RCcar.RCmain")
events.RENDER:register(function (delta, context)
   local hide = (context ~= "FIRST_PERSON" or not RC:getCarProperties().engine)
   vanilla_model.RIGHT_ARM:setVisible(hide)
   vanilla_model.RIGHT_ITEM:setVisible(hide)
   vanilla_model.RIGHT_SLEEVE:setVisible(hide)
   vanilla_model.LEFT_ARM:setVisible(hide)
   vanilla_model.LEFT_ITEM:setVisible(hide)
   vanilla_model.LEFT_SLEEVE:setVisible(hide)
end)
