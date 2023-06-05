events.ENTITY_INIT:register(function ()
   local name = player:getName()
   nameplate.ALL:setText(":racecar:"..name)
end)