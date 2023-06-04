--[[______   __                _                 __
  / ____/ | / /___ _____ ___  (_)___ ___  ____ _/ /____  _____
 / / __/  |/ / __ `/ __ `__ \/ / __ `__ \/ __ `/ __/ _ \/ ___/
/ /_/ / /|  / /_/ / / / / / / / / / / / / /_/ / /_/  __(__  )
\____/_/ |_/\__,_/_/ /_/ /_/_/_/ /_/ /_/\__,_/\__/\___/____]]

H = host:isHost()
local Parts = {
   root = models.RCcar.model.root,
   base = models.RCcar.model.root.Base,
   steer_wheels = {
      {4,models.RCcar.model.root.Wheel.FL},
      {4,models.RCcar.model.root.Wheel.FR},
   },
   engine_wheels = {
      {5,models.RCcar.model.root.Wheel.BL},
      {5,models.RCcar.model.root.Wheel.BR},
   },
}

-->====================[ Input Map ]====================<--
local Input = {
   Start    = keybinds:newKeybind("Start RC Car","key.keyboard.grave.accent"),
   Honk    = keybinds:newKeybind("Car Horn","key.keyboard.f"),
   Jump    = keybinds:newKeybind("Jump","key.keyboard.space"),
   Forward  = keybinds:newKeybind("Throttle Forward","key.keyboard.w"),
   Backward = keybinds:newKeybind("Throttle Backward","key.keyboard.s"),
   Left     = keybinds:newKeybind("Steer Left","key.keyboard.a"),
   Right    = keybinds:newKeybind("Steer Right","key.keyboard.d"),
}

local Physics = {
   margin = 0.001,
}
local RC = {
   -->==========[ Generic ]==========<--
   lpos = vectors.vec3(),    -- Last Tick Position
   pos = vectors.vec3(),     -- Position
   
   lvel = vectors.vec3(),    -- Last Tick Velocity
   vel = vectors.vec3(),     -- Velocity

   loc_lvel = vectors.vec3(),-- Last Tick Local Velocity
   loc_vel = vectors.vec3(), -- Local Velocity
   
   lrot = 0,                 -- Last Tick Rotation
   rot = 0,                  -- Rotation
   rvel = 0,                 -- Angular Velocity
   
   -->==========[ Suspension ]==========<--
   ls = vectors.vec3(),      -- Last Tick Suspension
   s = vectors.vec3(),       -- Suspension
   sv = vectors.vec3(),      -- Suspension Velocity
   
   -->==========[ RC car specific ]==========<--
   engine = false,           -- Is Engine Running
   et = 0,                   -- Engine Throttle
   lstr = 0,                 -- Last Tick Steer
   str = 0,                  -- Steer
   ctrl = vectors.vec2(),    -- Control Vec
   -->==========[ Attributes ]==========<--
   mat = matrices.mat4(),
   a_s = 0.4,                -- Speed
   a_sf = 2,                 -- Faster Speed
   a_sfw = 5*10,             -- Faster Speed Wait
   a_f = 0.8,                -- Friction
   jump_height = 0.3,        -- jump height
   g = -0.07,      -- gravity used by the car
   ng = -0.07,               -- normal gravity
   jg = -0.03,               -- jump gravity
   -->==========[ States ]==========<--
   is_on_floor = false,      -- is on the floor
   floor_block = nil,        -- the block the car is on, nil if air or transparent
   -->==========[ Statistics ]==========<--
   ltr = 0,                  -- last throttle distance
   tr = 0,                   -- throttle distance
   ldistance_traveled = 0,   -- last distance traveled
   distance_traveled = 0,    -- distance traveled
}
-->====================[ Camera Properties ]====================<--
local Camera = {
   ldir = vectors.vec2(),
   dir = vectors.vec2(),
   mode = false,
   transition = 0,
   dist = 3,
   rot_offset = 0,

   transition_duration = 1,

   lcam_dist = 0,
   cam_dist = 0,
   doppler = 1,
}
-->==========[ Bake/Init ]==========<--
for _, value in pairs(Parts.engine_wheels) do
   value[1] = 16/value[1]
end
for _, value in pairs(Parts.steer_wheels) do
   value[1] = 16/value[1]
end
Parts.root:setParentType("World")
local jump_power = 0
Camera.transition_duration = Camera.transition_duration / 10


-->====================[ Input ]====================<--

Input.Start.press = function ()
   RC.engine = not RC.engine
   Camera.mode = RC.engine
   if RC.engine then
      pings.syncControlSteer(0)
      pings.syncControlThrottle(0)
      if player:isLoaded() then
         Camera.dir = RC.mat.c3.xz
      end
      host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Enabled","color":"green"}]')
   else
      host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Disabled","color":"red"}]')
   end
   return true
end

local honk_cooldown = 0
Input.Honk.press = function ()
   if honk_cooldown <= 0 and RC.engine then
      honk_cooldown = 10
      pings.honk()
   end
end

Input.Jump.press = function () if RC.engine and RC.is_on_floor then pings.GNRCCARjump() end return RC.engine end
Input.Jump.release = function () if RC.engine then pings.GNRCCARunjump() end end
Input.Forward.press = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y + 1) end return RC.engine end
Input.Forward.release = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y - 1) end return RC.engine end

Input.Backward.press = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y - 1) end return RC.engine end
Input.Backward.release = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y + 1) end return RC.engine end

Input.Left.press = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x + 1) end return RC.engine end
Input.Left.release = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x - 1) end return RC.engine end

Input.Right.press = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x - 1) end return RC.engine end
Input.Right.release = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x + 1) end return RC.engine end


events.ENTITY_INIT:register(function ()
   RC.pos = player:getPos():add(0,1,0)
end)

local th_pow = 0
events.TICK:register(function ()
   RC.lstr = RC.str
   RC.et = RC.et * 0.7 + math.lerp(RC.a_s,RC.a_sf,th_pow/RC.a_sfw) * RC.ctrl.y * 0.4
   if RC.is_on_floor and RC.ctrl.x == 0 then
      if RC.ctrl.y ~= 0 then
         th_pow = math.min(th_pow + 1/(th_pow+1),RC.a_sfw)
      else
         th_pow = math.max(th_pow - 1,0)
      end
   else
      th_pow = math.max(th_pow - 0.1,0)
   end
   RC.str = math.lerp(RC.str,RC.ctrl.x * -25,0.4) / math.clamp(math.abs(RC.et)+0.4,0.9,10)

   if honk_cooldown > 0 then
      honk_cooldown = honk_cooldown - 1
   end
end)

-->====================[ API ]====================<--
local API = {}

---Returns the keybind inputs of the car
---@return table
function API:getKeybinds()
   return Input
end

---Returns the table containing all the RC car's data
---@return table
function API:getCarProperties()
   return RC
end

function API:getSteer(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.lstr,RC.str,delta)
end

function API:getPos(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.lpos,RC.pos,delta)
end

function API:getRot(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.lrot,RC.rot,delta)
end

function API:getVel(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.lvel,RC.vel,delta)
end

function API:getSteer(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.lstr,RC.str,delta)
end

function API:getLocalVel(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.loc_lvel,RC.loc_vel,delta)
end

function API:getThrottleDistance(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.ltr,RC.tr,delta)
end

function API:isActive()
   return RC.engine
end

function API:getEngineSpeed()
   return RC.et
end

function API:getSuspension(delta)
   if not delta then delta = 0 end
   return math.lerp(RC.ls,RC.s,delta)
end

function API:getCameraDir(delta)
   if not delta then delta = 0 end
   return math.lerp(Camera.ldir,Camera.dir,delta)
end

function API:isOnGround()
   return RC.is_on_floor
end

function API:getCameraTransition()
   return Camera.transition
end

-->====================[ Physics ]====================<--



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
--local engine_sound = sounds:playSound("engine",RC.pos,1,0,true):play()
events.TICK:register(function ()
   --Camera.lcam_dist = Camera.cam_dist
   --local cdist = (RC.pos-client:getCameraPos()):length()
   --Camera.cam_dist = cdist
   --Camera.doppler = math.clamp(Camera.lcam_dist-Camera.cam_dist,-0.9,0.9) * 0.3 +1
   --local e = math.abs(RC.et)
   --print(Camera.doppler)
   --engine_sound:setPos(RC.pos):setPitch((e*0.8+0.8) * Camera.doppler):setVolume(math.clamp((math.clamp(e*8,0.0,1)/cdist^2)*5,0,0.1))
   RC.lpos = RC.pos:copy()
   RC.lvel = RC.vel:copy()
   RC.lrot = RC.rot
   RC.ltr = RC.tr

   do
      RC.pos.y = RC.pos.y + RC.vel.y
      local result = collision(RC.pos,RC.vel.y,2)
      local block = world.getBlockState(RC.pos:add(0,-0.01,0))
      if block:hasCollision() then
         RC.floor_block = block
         RC.a_f = block:getFriction()
      else
         RC.floor_block = nil
      end
      if result and block:hasCollision() then RC.pos.y = result RC.vel:mul(RC.a_f,0,RC.a_f) RC.is_on_floor = true else RC.is_on_floor = false end
      RC.vel.y = RC.vel.y + RC.g
      RC.pos:add(0,0.01,0)
   end

   do
      if RC.is_on_floor then
         RC.vel.x = RC.vel.x * RC.a_f - RC.mat.c3.x * RC.et * (1-RC.a_f)
      end
      RC.pos.x = RC.pos.x + RC.vel.x
      local result = collision(RC.pos,RC.vel.x,1)
      if result then
         local step_height = getStepHeight(RC.pos)
         if step_height <= 1.1 then
            RC.pos.y = RC.pos.y + step_height
         else
            RC.pos.x = result RC.vel:mul(0,RC.a_f,RC.a_f)
         end
      end
   end
   
   do
      if RC.is_on_floor then
         RC.vel.z = RC.vel.z * RC.a_f - RC.mat.c3.z * RC.et * (1-RC.a_f)
      end
      RC.pos.z = RC.pos.z + RC.vel.z
      local result = collision(RC.pos,RC.vel.z,3)
      if result then
         local step_height = getStepHeight(RC.pos)
         if step_height <= 1 then
            RC.pos.y = RC.pos.y + step_height
         else
            RC.pos.z = result RC.vel:mul(RC.a_f,RC.a_f,0)
         end
      end
   end

   local block = world.getBlockState(RC.pos)
   if block.id == "minecraft:water" then
      RC.vel = RC.vel * 0.8
      RC.vel.y = RC.vel.y + 0.04
   end

   RC.tr = RC.tr + RC.et * 4
   RC.loc_lvel = RC.loc_vel
   local locMat =  matrices.mat4():rotateY(RC.rot)
   RC.loc_vel = (RC.vel:copy():mul(-1,1,1):augmented() * locMat).xyz
   --print(RC.loc_vel.z,locMat.c3.xz)
   RC.mat = locMat
   RC.ls = RC.s:copy()
   RC.s = RC.s + RC.sv
   RC.sv = RC.sv * 0.4 + vec(
      RC.loc_vel.x-RC.loc_lvel.x,
      RC.lvel.y - RC.vel.y,
      RC.loc_vel.z-RC.loc_lvel.z) * 2 - RC.s * 0.9
   RC.rot = RC.rot + RC.str * RC.loc_vel.z
   RC.ldistance_traveled = RC.distance_traveled
   RC.distance_traveled = RC.distance_traveled + RC.loc_vel.z

   if math.abs(RC.loc_vel.z) > 0.1 then
      if RC.floor_block then
         sounds:playSound(RC.floor_block:getSounds().step,RC.pos,0.3)
      end
   end

   if not H then return end
   Camera.ldir = Camera.dir:copy()
   Camera.dir = (Camera.dir - (RC.pos - RC.lpos).xz / Camera.dist):normalized()
end)

-->====================[ Networking ]====================<--

local sync_timer = 0

local function snap(number,step)
   return math.floor(number * step + 0.5) / step
end

events.TICK:register(function ()
   if not H then return end
   sync_timer = sync_timer - 1
   if sync_timer < 0 then
      sync_timer = 20
      pings.syncState(snap(RC.pos.x,10),snap(RC.pos.y,10),snap(RC.pos.z,100),snap(RC.rot,10))
   end
end)

function pings.syncControlThrottle(X)
   RC.ctrl.y = X
end

function pings.syncControlSteer(Y)
   RC.ctrl.x = Y
end

function pings.GNRCCARjump()
   RC.vel.y = RC.jump_height
   RC.g = RC.jg
end

function pings.GNRCCARunjump()
   RC.g = RC.ng
end

function pings.syncState(x,y,z,r)
   if H then return end
   RC.pos = vectors.vec3(x,y,z)
   RC.rot = r
end

function pings.honk()
   sounds:playSound("honk",RC.pos,1,1)
   animations.RCcar.honk:stop():play()
end

-->====================[ Rendering ]====================<--

local delta_frame = 0
local lsys_time = client:getSystemTime()
events.WORLD_RENDER:register(function (delta)
   local sys_time = client:getSystemTime()
   delta_frame = (sys_time-lsys_time) * 0.01
   lsys_time = sys_time
end)

events.POST_WORLD_RENDER:register(function (dt)
   local true_pos = math.lerp(RC.lpos,RC.pos,dt)
   local true_vel = math.lerp(RC.lvel,RC.vel,dt)
   local true_dist_trav = math.lerp(RC.ldistance_traveled,RC.distance_traveled,dt)
   local throttle_trav = -math.lerp(RC.ltr,RC.tr,dt)
   local true_steer = -math.lerp(RC.lstr,RC.str,dt)
   local true_sus = math.lerp(RC.ls,RC.s,dt)
   local true_rot = math.lerp(RC.lrot,RC.rot,dt)
   Parts.root:setPos(true_pos * 16):setRot((true_vel.y-RC.g)*-math.sign(math.floor(RC.loc_vel.z*100+0.5)/100)*90,true_rot,0)
   Parts.base:setPos(0,true_sus.y,0):setRot(math.deg(true_sus.z)*0.3,0,math.deg(true_sus.x))
   for _, wheelData in pairs(Parts.steer_wheels) do
      wheelData[2]:setRot(math.deg(true_dist_trav)*wheelData[1],true_steer)
   end
   for _, wheelData in pairs(Parts.engine_wheels) do
      wheelData[2]:setRot(math.deg(throttle_trav)*wheelData[1] / 4,0)
      if (math.abs(RC.et+RC.loc_vel.z / RC.a_f) > 0.2 or math.abs(RC.loc_vel.x) > 0.05) and RC.is_on_floor then
         particles:newParticle("minecraft:block "..RC.floor_block.id,wheelData[2]:partToWorldMatrix().c4.xyz,RC.mat.c3.xyz*RC.et*100)
      end
   end

   if not H then return end
      if not player:isLoaded() then return end
      local crot = player:getRot()
      crot.y = (crot.y) % 360 -- <=== El stupido
      local true_cam_dir = math.lerp(Camera.ldir,Camera.dir,dt)
      true_cam_dir = vectors.vec3(true_cam_dir.x,0.5,true_cam_dir.y):add(0,0.5,0)*Camera.dist
      if player:isLoaded() then
         local hpos = player:getPos(dt):add(0,player:getEyeHeight(),0)
         if Camera.mode then
            Camera.transition = math.min(Camera.transition + delta_frame * Camera.transition_duration,1)
         else
            Camera.transition = math.max(Camera.transition - delta_frame * Camera.transition_duration,0)
         end
         if Camera.transition < 0.001 then
            renderer:setCameraPivot()
            renderer:setCameraRot()
         else
            local transition = -(math.cos(math.pi * Camera.transition) - 1) / 2
            if renderer:isFirstPerson() then
               renderer:setCameraPivot(math.lerp(hpos,true_pos:add(0,0.45+(true_sus.y)/16,0),transition))
               local shake = vectors.vec2()
               if RC.is_on_floor then
                  local intensity = math.min(RC.vel.xz:length(),2)
                  shake = vectors.vec2(intensity*(math.random()-.5),intensity*(math.random()-.5))
               end
               renderer:setCameraRot(crot.x+shake.x,math.lerp(crot.y,(crot.y-true_rot)%360,transition),math.deg(true_sus.x)*.3+shake.y)
               
            else
               renderer:setCameraPivot(math.lerp(hpos,true_pos:add(0,0.4,0),transition))
               if renderer:isCameraBackwards() then
                  renderer:setCameraRot(crot.x,math.lerp(crot.y, math.deg(math.atan2(true_cam_dir.z,true_cam_dir.x))+90+180,transition),0)
               else
                  renderer:setCameraRot(crot.x,math.lerp(crot.y, math.deg(math.atan2(true_cam_dir.z,true_cam_dir.x))+90,transition),0)
               end
            end
         end
      end
   renderer:setFOV(math.lerp(1,th_pow/RC.a_sfw + 1,Camera.transition))
end)

local lprot = vectors.vec2()
events.POST_RENDER:register(function (x,y)
   if not player:isLoaded() and not H then return end
   local prot = player:getRot()
   local d = lprot-prot
   lprot = prot
   if not renderer:isFirstPerson() and RC.engine then
      Camera.dir = vectors.rotateAroundAxis(d.y,vectors.vec3(Camera.dir.x,0,Camera.dir.y),vectors.vec3(0,1,0)).xz
   end
end)

events.RENDER:register(function (delta, context)
   local hide = (context ~= "FIRST_PERSON" or not RC.engine)
   vanilla_model.RIGHT_ARM:setVisible(hide)
   vanilla_model.RIGHT_ITEM:setVisible(hide)
   vanilla_model.RIGHT_SLEEVE:setVisible(hide)
   vanilla_model.LEFT_ARM:setVisible(hide)
   vanilla_model.LEFT_ITEM:setVisible(hide)
   vanilla_model.LEFT_SLEEVE:setVisible(hide)
end)


return API