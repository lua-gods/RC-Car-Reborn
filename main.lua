--[[______   __                _                 __
  / ____/ | / /___ _____ ___  (_)___ ___  ____ _/ /____  _____
 / / __/  |/ / __ `/ __ `__ \/ / __ `__ \/ __ `/ __/ _ \/ ___/
/ /_/ / /|  / /_/ / / / / / / / / / / / / /_/ / /_/  __(__  )
\____/_/ |_/\__,_/_/ /_/ /_/_/_/ /_/ /_/\__,_/\__/\___/____]]

H = host:isHost()
local Parts = {
   root = models.RCcar.root,
   base = models.RCcar.root.Base,
   steer_wheels = {
      {4,models.RCcar.root.Wheel.FL},
      {4,models.RCcar.root.Wheel.FR},
   },
   engine_wheels = {
      {5,models.RCcar.root.Wheel.BL},
      {5,models.RCcar.root.Wheel.BR},
   },
}


local Input = {
   Start    = keybinds:newKeybind("Start RC Car","key.keyboard.grave.accent"),
   Jump    = keybinds:newKeybind("Jump","key.keyboard.space"),
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
   mat = matrices.mat4(),
   a_s = 0.4,             -- Speed
   a_sf = 1.2,            -- Faster Speed
   a_sfw = 5*10,          -- Faster Speed Wait
   a_f = 0.8,             -- Friction
   is_on_floor = false,   -- is on the floor
   floor_block = nil,     -- the block the car is on, nil if air or transparent
   ltr = 0,               -- last throttle distance
   tr = 0,                -- throttle distance
   ldistance_traveled = 0,-- last distance traveled
   distance_traveled = 0, -- distance traveled
   lj = 0.8,              --low jump
   hj = 0.2,              -- high jump
   hjw = 1*20           -- high jump wait
}

local Camera = {
   ldir = vectors.vec3(0,0,-1),
   dir = vectors.vec3(0,0,-1),
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

local age = 0

events.ENTITY_INIT:register(function ()
   RC.pos = player:getPos():add(0,1,0)
   local slim_jim = player:getModelType() =="SLIM"
   models.RCcar.root.Base.Doll.B.LA.LASlim:setVisible(slim_jim)
   models.RCcar.root.Base.Doll.B.RA.RASlim:setVisible(slim_jim)
   models.RCcar.root.Base.Doll.B.LA.LANormal:setVisible(not slim_jim)
   models.RCcar.root.Base.Doll.B.RA.RANormal:setVisible(not slim_jim)
end)

events.TICK:register(function ()
   models.RCcar.root.Base.Doll:setPrimaryTexture("SKIN")
   if age > 30 then
      events.TICK:remove("skin_applier")
   end
end,"skin_applier")
-->====================[ Input ]====================<--

Input.Start.press = function ()
   RC.engine = not RC.engine
   Camera.mode = RC.engine
   if RC.engine then
      pings.syncControlSteer(0)
      pings.syncControlThrottle(0)
      if player:isLoaded() then
         Camera.dir = RC.mat.c3.xyz
      end
      host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Enabled","color":"green"}]')
   else
      host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Disabled","color":"red"}]')
   end
   return true
end

Input.Jump.press = function () jump_power = 0 return RC.engine end
Input.Jump.release = function () if RC.engine and RC.is_on_floor then pings.jump(math.lerp(RC.hj,RC.lj,jump_power / RC.hjw)) jump_power = 0 end return RC.engine end
Input.Forward.press = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y + 1) end return RC.engine end
Input.Forward.release = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y - 1) end return RC.engine end

Input.Backward.press = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y - 1) end return RC.engine end
Input.Backward.release = function () if RC.engine then pings.syncControlThrottle(RC.ctrl.y + 1) end return RC.engine end

Input.Left.press = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x + 1) end return RC.engine end
Input.Left.release = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x - 1) end return RC.engine end

Input.Right.press = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x - 1) end return RC.engine end
Input.Right.release = function () if RC.engine then pings.syncControlSteer(RC.ctrl.x + 1) end return RC.engine end


local th_pow = 0
events.TICK:register(function ()
   if Input.Jump:isPressed() and RC.engine then
      if jump_power < RC.hjw then
         jump_power = jump_power + 1
      end
   end
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
   age = age + 1
end)

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
local engine_sound = sounds:playSound("numero_dos",RC.pos,1,1,true):play()
events.TICK:register(function ()
   Camera.lcam_dist = Camera.cam_dist
   local cdist = (RC.pos-client:getCameraPos()):length()
   Camera.cam_dist = cdist
   Camera.doppler = math.clamp(Camera.lcam_dist-Camera.cam_dist,-0.9,0.9) * 0.3 +1
   --sounds:playSound("minecraft:block.piston.contract",RC.pos,0.1,0.5)
   local e = math.abs(RC.et)
   --print(Camera.doppler)
   engine_sound:setPos(RC.pos):setPitch((e*0.8+0.8) * Camera.doppler):setVolume(math.clamp((math.clamp(e*8,0.0,1)/cdist^2)*5,0,0.2))
   RC.lpos = RC.pos:copy()
   RC.lvel = RC.vel:copy()
   RC.lrot = RC.rot
   RC.ltr = RC.tr

   do
      RC.pos.y = RC.pos.y + RC.vel.y
      local result = collision(RC.pos,RC.vel.y,2)
      if result then RC.pos.y = result RC.vel:mul(RC.a_f,0,RC.a_f) RC.is_on_floor = true else RC.is_on_floor = false end
      RC.vel.y = RC.vel.y + Physics.gravity
      local block = world.getBlockState(RC.pos:add(0,-0.01,0))
      if block:hasCollision() then
         RC.floor_block = block
         RC.a_f = block:getFriction()
      else
         RC.floor_block = nil
      end
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
   if not H then return end
   Camera.ldir = Camera.dir:copy()
   Camera.dir = (Camera.dir - (RC.pos - RC.lpos) / Camera.dist):normalized()
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

function pings.jump(power)
   RC.vel.y = power
end

function pings.syncState(x,y,z,r)
   if H then return end
   RC.pos = vectors.vec3(x,y,z)
   RC.rot = r
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
   local true_locvel = math.lerp(RC.loc_lvel,RC.loc_vel,dt)
   Parts.root:setPos(true_pos * 16):setRot((true_vel.y-Physics.gravity)*-math.sign(math.floor(RC.loc_vel.z*100+0.5)/100)*90,true_rot,0)
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

   -->==========[ Doll Procedural Animation ]==========<--
   models.RCcar.root.Base.Doll.B.LA:setRot(60-true_steer,-(true_steer*true_steer)*0.01-5,0)
   models.RCcar.root.Base.Doll.B.RA:setRot(60+true_steer,5+(true_steer*true_steer)*0.01,0)
   models.RCcar.root.Base.SteeringWheel.Hinge:setRot(0,true_steer,0)
   models.RCcar.root.Base.Doll.B:setRot(0,0,true_steer*0.1)

   if not H then return end
      if not player:isLoaded() then return end
      local crot = player:getRot()
      crot.y = (crot.y) % 360 -- <=== El stupido
      local true_cam_dir = math.lerp(Camera.ldir,Camera.dir,dt):add(0,0.5,0)*Camera.dist
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
               renderer:setCameraPivot(math.lerp(hpos,true_pos:add(0,0.45,0),transition))
               renderer:setCameraRot(crot.x,math.lerp(crot.y,crot.y-true_rot,transition),math.deg(true_locvel.x)*.3)
               models.RCcar.root.Base.Doll.B.H:setVisible(transition < 0.95)
            else
               models.RCcar.root.Base.Doll.B.H:setVisible(true)
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
      Camera.dir = vectors.rotateAroundAxis(d.y,Camera.dir,vectors.vec3(0,1,0))
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


return RC