--[[______   __                _                 __
  / ____/ | / /___ _____ ___  (_)___ ___  ____ _/ /____  _____
 / / __/  |/ / __ `/ __ `__ \/ / __ `__ \/ __ `/ __/ _ \/ ___/
/ /_/ / /|  / /_/ / / / / / / / / / / / / /_/ / /_/  __(__  )
\____/_/ |_/\__,_/_/ /_/ /_/_/_/ /_/ /_/\__,_/\__/\___/____]]
local Parts = {
   root = models.RCcar,
   base = models.RCcar.Base,
   steer_wheels = {
      models.RCcar.FL,
      models.RCcar.FR,
   },
   engine_wheels = {
      models.RCcar.BL,
      models.RCcar.BR,
   }
}

local Input = {
   Start    = keybinds:newKeybind("Start RC Car","key.keyboard.grave.accent"),
   Forward  = keybinds:newKeybind("Throttle Forward","key.keyboard.w"),
   Backward = keybinds:newKeybind("Throttle Backward","key.keyboard.s"),
   Left     = keybinds:newKeybind("Steer Left","key.keyboard.a"),
   Right    = keybinds:newKeybind("Steer Right","key.keyboard.d"),
}

local Physics = {
   gravity = -0.05,
   margin = 0.001,
}
local RC = {
   -->==========[ Generic ]==========<--
   lpos = vectors.vec3(),
   pos = vectors.vec3(),
   
   lvel = vectors.vec3(),
   vel = vectors.vec3(),

   loc_vel = vectors.vec3(),
   loc_lvel = vectors.vec3(),
   
   lrot = 0,
   rot = 0,
   rvel = 0,
   
   -->==========[ Suspension ]==========<--
   ls = vectors.vec3(),   -- Last Tick Suspension
   s = vectors.vec3(),    -- Suspension
   sv = vectors.vec3(),   -- Suspension Velocity
   
   -->==========[ RC car specific ]==========<--
   engine = false,        -- Is Engine Running
   et = 0,                -- Engine Throttle
   lstr = 0,              -- Steer
   str = 0,               -- Steer
   ctrl = vectors.vec2(), -- Control Vec
   -->==========[ Attributes ]==========<--
   a_s = 0.1,            -- Speed
   a_f = 0.8,            -- Friction
   is_on_floor = false,
}

Parts.root:setParentType("World")

-->====================[ Input ]====================<--

Input.Start.press = function ()
   RC.engine = not RC.engine
   if RC.engine then
      host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Enabled","color":"green"}]')
   else
      host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Disabled","color":"red"}]')
   end
   return true
end

Input.Forward.press = function () RC.ctrl.y = RC.ctrl.y + 1 return RC.engine end
Input.Forward.release = function () RC.ctrl.y = RC.ctrl.y - 1 return RC.engine end

Input.Backward.press = function () RC.ctrl.y = RC.ctrl.y - 1 return RC.engine end
Input.Backward.release = function () RC.ctrl.y = RC.ctrl.y + 1 return RC.engine end

Input.Left.press = function () RC.ctrl.x = RC.ctrl.x + 1 return RC.engine end
Input.Left.release = function () RC.ctrl.x = RC.ctrl.x - 1 return RC.engine end

Input.Right.press = function () RC.ctrl.x = RC.ctrl.x - 1 return RC.engine end
Input.Right.release = function () RC.ctrl.x = RC.ctrl.x + 1 return RC.engine end



events.TICK:register(function ()
   if RC.engine then
      RC.lstr = RC.str
      RC.et = RC.et * 0.3 + RC.a_s * RC.ctrl.y
      RC.str = RC.ctrl.x * 45
   end
end)

-->====================[ Physics ]====================<--

events.ENTITY_INIT:register(function ()
   RC.pos = player:getPos():add(0,3,0)
   --RC.pos = vectors.vec3(-227.5,83,127.5)
end)

local function getStepHeight(pos)
   local spos = pos:copy()
   local step_height = 0
   for i = 1, 10, 1 do
      local block, brpos = world.getBlockState(spos), spos % 1
      local bpos = spos - brpos
      for key, AABB in pairs(block:getCollisionShape()) do
         if AABB[1].x <= brpos.x and AABB[1].y <= brpos.y and AABB[1].z <= brpos.z
         and AABB[2].x >= brpos.x and AABB[2].y >= brpos.y and AABB[2].z >= brpos.z then
            brpos.y = AABB[2].y + Physics.margin
            spos.y = bpos.y + AABB[2].y + Physics.margin
            step_height = spos.y-pos.y
         else
            break
         end
      end
   end
   return step_height
end

local function collision(pos,vel,axis)
   local block, brpos = world.getBlockState(pos), pos % 1
   local bpos = pos - brpos
   local collided = false
   for key, AABB in pairs(block:getCollisionShape()) do
      if AABB[1].x <= brpos.x and AABB[1].y <= brpos.y and AABB[1].z <= brpos.z
      and AABB[2].x >= brpos.x and AABB[2].y >= brpos.y and AABB[2].z >= brpos.z then
         collided = true
         if axis == 1 then
            if math.sign(vel) < 0 then
               brpos.x = AABB[2].x + Physics.margin else brpos.x = AABB[1].x - Physics.margin
            end
         elseif axis == 2 then
            if math.sign(vel) < 0 then
               brpos.y = AABB[2].y + Physics.margin else brpos.y = AABB[1].y - Physics.margin
            end
         elseif axis == 3 then
            if math.sign(vel) < 0 then
               brpos.z = AABB[2].z + Physics.margin else brpos.z = AABB[1].z - Physics.margin
            end
         end
      end
   end
   if collided then
      if axis == 1 then
         return bpos.x+brpos.x
  elseif axis == 2 then
         return bpos.y+brpos.y
  elseif axis == 3 then
         return bpos.z+brpos.z
      end
   end
end

events.TICK:register(function ()
   RC.lpos = RC.pos:copy()
   RC.lvel = RC.vel:copy()
   RC.lrot = RC.rot
   
   local r = math.rad(RC.rot)
   do
      if RC.is_on_floor then
         RC.vel.x = RC.vel.x * RC.a_f - math.sin(r) * RC.et
      end
      RC.pos.x = RC.pos.x + RC.vel.x
      local result = collision(RC.pos,RC.vel.x,1)
      if result then
         local step_height = getStepHeight(RC.pos)
         if step_height < 1  then
            RC.pos.y = RC.pos.y + step_height
         else
            RC.pos.x = result RC.vel:mul(0,RC.a_f,RC.a_f)
         end
         end
   end

   do
      RC.pos.y = RC.pos.y + RC.vel.y
      local result = collision(RC.pos,RC.vel.y,2)
      if result then RC.pos.y = result RC.vel:mul(RC.a_f,0,RC.a_f) RC.is_on_floor = true else RC.is_on_floor = false end
      RC.vel.y = RC.vel.y + Physics.gravity
   end
   
   do
      if RC.is_on_floor then
         RC.vel.z = RC.vel.z * RC.a_f - math.cos(r) * RC.et
      end
      RC.pos.z = RC.pos.z + RC.vel.z
      local result = collision(RC.pos,RC.vel.z,3)
      if result then
         local step_height = getStepHeight(RC.pos)
         if step_height < 1  then
            RC.pos.y = RC.pos.y + step_height
         else
            RC.pos.z = result RC.vel:mul(RC.a_f,RC.a_f,0)
         end
      end
   end

   RC.loc_lvel = RC.loc_vel:copy()
   RC.loc_vel = vectors.vec3(
      math.cos(-r) * RC.vel.x + math.sin(-r) * RC.vel.z,
      RC.vel.y,
      math.sin(r) * -RC.vel.x + math.cos(r) * -RC.vel.z)
   RC.ls = RC.s:copy()
   RC.s = RC.s + RC.sv
   RC.sv = RC.sv * 0.4 + vec(
      RC.loc_lvel.x - RC.loc_vel.x,
      RC.lvel.y - RC.vel.y,
      RC.loc_lvel.z - RC.loc_vel.z) * 2 - RC.s * 0.9
   RC.rot = RC.rot + RC.str * RC.loc_vel.z
end)

-->====================[ Rendering ]====================<--

events.WORLD_RENDER:register(function (dt)
   local true_pos = math.lerp(RC.lpos,RC.pos,dt)
   local true_sus = math.lerp(RC.ls,RC.s,dt)
   Parts.root:setPos(true_pos * 16):setRot(0,math.lerp(RC.lrot,RC.rot,dt),0)
   Parts.base:setPos(0,true_sus.y,0):setRot(0,0,math.deg(true_sus.x))
   for key, value in pairs(Parts.steer_wheels) do
      value:setRot(0,math.lerp(RC.lstr,RC.str,dt))
   end
end)

return RC