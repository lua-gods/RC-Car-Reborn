--[[______   __
  / ____/ | / / By: GNamimates | https://gnon.top | Discord: @gn8.
 / / __/  |/ / a remote control car for Figura
/ /_/ / /|  / idk what else to say
\____/_/ |_/ Source: https://github.com/lua-gods/RC-Car]]

H = host:isHost()
local eventLib = require("RCcar.eventLib")
local Parts = {
	root = models.RCcar.model.root,
	base = models.RCcar.model.root.Base,
}

-->====================[ Input Map ]====================<--
local Input = {
	Start    = keybinds:fromVanilla("figura.config.action_wheel_button"),
	Honk     = keybinds:fromVanilla("key.swapOffhand"),
	Jump     = keybinds:fromVanilla("key.jump"),
	Forward  = keybinds:fromVanilla("key.forward"),
	Backward = keybinds:fromVanilla("key.back"),
	Left     = keybinds:fromVanilla("key.left"),
	Right    = keybinds:fromVanilla("key.right"),
}

local Physics = {
	margin = 0.01,
	force_solid = {
		"minecraft:soul_sand",
		"minecraft:mud",
		"minecraft:dirt_path",
		"minecraft:chest",
		"minecraft:ender_chest",
		"minecraft:powder_snow",
		"minecraft:honey_block",
	},
}
local deadly = {"lava","fire","void","spike","molten","saw"}
local safe = {"extinguished","neutered","safe","covered"}
local RC = {
	-->========================================[ Generic ]=========================================<--
	lpos--[[                    Last Tick Position ]] = vec(0,0,0) -- locked
	,pos--[[                              Position ]] = vec(0,0,0) -- locked
	
	,lvel--[[                   Last Tick Velocity ]] = vec(0,0,0) 
	,vel--[[                              Velocity ]] = vec(0,0,0) 

	,loc_lvel--[[         Last Tick Local Velocity ]] = vec(0,0,0) -- locked
	,loc_vel--[[                    Local Velocity ]] = vec(0,0,0) -- locked
	
	,lrot--[[                   Last Tick Rotation ]] = 0 -- locked
	,rot--[[                              Rotation ]] = 0
	,rvel--[[                     Angular Velocity ]] = 0
	
	-->========================================[ Suspension ]=========================================<--
	,ls--[[                   Last Tick Suspension ]] = vec(0,0,0)  -- locked
	,s--[[                              Suspension ]] = vec(0,0,0)
	,sv--[[                    Suspension Velocity ]] = vec(0,0,0)  -- locked
	
	-->========================================[ Engine ]=========================================<--
	,engine--[[                  Is Engine Running ]] = false  -- locked
	,et--[[                        Engine Throttle ]] = 0  -- locked
	,lstr--[[                      Last Tick Steer ]] = 0  -- locked
	,str--[[                                 Steer ]] = 0  -- locked
	,ctrl--[[                          Control Vec ]] = vectors.vec2()  -- locked
	,e_a--[[        engine acceleration percentage ]] = 0  -- locked
	
	-->========================================[ Physics ]=========================================<--
	,mat--[[                                       ]] = matrices.mat4()  -- locked
	,a_s--[[                                 Speed ]] = 0.4
	,a_sf_fov_mul--[[  Faster Speed FOV Multiplier ]] = 1.15
	,a_sf--[[                         Faster Speed ]] = 1
	,a_sfw--[[                   Faster Speed Wait ]] = 10
	,a_f--[[                              Friction ]] = 0.8
	,jump_height--[[                   jump height ]] = 0.3
	,g--[[                 gravity used by the car ]] = -0.07
	,wjg--[[                        normal gravity ]] = 0.2
	,ng--[[                         normal gravity ]] = -0.07
	,jg--[[                           jump gravity ]] = -0.03
	,size--[[                             Car Size ]] = vec(0.5,0.5,0.5)
	,wheels = {} --(automatic)
	-->========================================[ Statistics ]=========================================<--
	,is_underwater--[[                             ]] = false  -- locked
	,is_on_floor--[[               is on the floor ]] = false  -- locked
	,floor_block--[[           the block under car ]] = nil  -- locked
	,block_inside--[[                              ]] = nil  -- locked
	,is_jumping--[[                                ]] = false  -- locked
	,is_handbreak--[[                              ]] = false  -- locked
	
	,ltr--[[                last throttle distance ]] = 0 -- locked
	,tr--[[                      throttle distance ]] = 0 -- locked
	,ldt--[[                last distance traveled ]] = 0 -- locked
	,dt--[[                      distance traveled ]] = 0 -- locked
}
-->========================================[ Camera ]=========================================<--
local cam = {
	height--[[               ]] = 7.2/16
	,ldir--[[                ]] = vectors.vec2()
	,dir--[[                 ]] = vectors.vec2()
	,enabled--[[             ]] = false
	,dist--[[    F5 Distance ]] = 3
	,rot_offset--[[          ]] = 0
	
	,t--[[              Time ]] = 0 -- locked
	,t_d--[[   Time Duration ]] = 1

	,lcam_dist--[[           ]] = 0
	,cam_dist--[[            ]] = 0
	,d--[[           Doppler ]] = 1
}
-->==========[ Bake/Init ]==========<--
Parts.root:setParentType("World")
cam.t_d = cam.t_d / 10


-->====================[ Input ]====================<--
local respawn_time_check = 0
Input.Start.press = function ()
	respawn_time_check = respawn_time_check + 5
	RC.engine = not RC.engine
	cam.enabled = RC.engine
	if RC.engine then
		local steer = 0
		if Input.Left:isPressed() then
			steer = steer + 1
		end
		if Input.Right:isPressed() then
			steer = steer - 1
		end
		pings.GNRCcarCtrlSteer(steer)
		local throttle = 0
		if Input.Forward:isPressed() then
			throttle = throttle + 1
		end
		if Input.Backward:isPressed() then
			throttle = throttle - 1
		end
		pings.GNRCcarCtrlThrottle(throttle)
		if player:isLoaded() then
			cam.dir = RC.mat.c3.xz
		end
		host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Enabled","color":"green"}]')
	else
		pings.GNRCcarCtrlSteer(0)
		pings.GNRCcarCtrlThrottle(0)
		host:setActionbar('[{"text":"Remote Controll Mode: "},{"text":"Disabled","color":"red"}]')
	end
	if respawn_time_check > 5 then
		if player:isLoaded() then
			local pos = player:getPos()
			pings.GNRCcarSyncState(pos.x,pos.y,pos.z,0,0,0,0,0,false)
		end
	end
	return true
end

events.TICK:register(function ()
	respawn_time_check = math.max(respawn_time_check - 1,0)
end)

local honk_cooldown = 0
Input.Honk.press = function ()
	if honk_cooldown <= 0 and RC.engine then
		honk_cooldown = 10
		pings.GNRCcarHonk()
	end
	return RC.engine
end

Input.Jump.press = function () if RC.engine and RC.is_on_floor or RC.is_underwater then pings.GNRCCARjump(RC.is_underwater) end return RC.engine end
Input.Jump.release = function () if RC.engine then pings.GNRCCARunjump() end end
Input.Forward.press = function () if RC.engine then pings.GNRCcarCtrlThrottle(RC.ctrl.y + 1) end return RC.engine end
Input.Forward.release = function () if RC.engine then pings.GNRCcarCtrlThrottle(RC.ctrl.y - 1) end return RC.engine end

Input.Backward.press = function () if RC.engine then pings.GNRCcarCtrlThrottle(RC.ctrl.y - 1) end return RC.engine end
Input.Backward.release = function () if RC.engine then pings.GNRCcarCtrlThrottle(RC.ctrl.y + 1) end return RC.engine end

Input.Left.press = function () if RC.engine then pings.GNRCcarCtrlSteer(RC.ctrl.x + 1) end return RC.engine end
Input.Left.release = function () if RC.engine then pings.GNRCcarCtrlSteer(RC.ctrl.x - 1) end return RC.engine end

Input.Right.press = function () if RC.engine then pings.GNRCcarCtrlSteer(RC.ctrl.x - 1) end return RC.engine end
Input.Right.release = function () if RC.engine then pings.GNRCcarCtrlSteer(RC.ctrl.x + 1) end return RC.engine end


events.ENTITY_INIT:register(function ()
	RC.pos = player:getPos():add(0,1,0)
end)
local wh = false
events.TICK:register(function ()
	local ih = Input.Forward:isPressed() and Input.Backward:isPressed()
	if wh ~= ih then
		pings.GNRCcarHandbreak(ih)
		if ih then
			RC.ctrl.y = RC.ctrl.y + 1
		else
			RC.ctrl.y = RC.ctrl.y - 1
		end
		wh = ih
	end
	RC.lstr = RC.str
	RC.et = RC.et * 0.7 + math.lerp(RC.a_s,RC.a_sf,RC.e_a) * RC.ctrl.y * 0.4
	if RC.is_on_floor and RC.ctrl.x == 0 then
		if RC.ctrl.y ~= 0 then
			RC.e_a = math.min(RC.e_a + ((1-RC.e_a) * 0.1)/RC.a_sfw,1)
		else
			RC.e_a = math.max(RC.e_a - 1/RC.a_sfw,0)
		end
	else
		RC.e_a = math.max(RC.e_a - 0.02/RC.a_sfw,0)
	end
	RC.str = math.lerp(RC.str,RC.ctrl.x * -25,0.2) / math.clamp(math.abs(RC.et)+0.4,0.9,10)

	if honk_cooldown > 0 then
		honk_cooldown = honk_cooldown - 1
	end
end)

-->====================[ API ]====================<--
local API = {ON_JUMP = eventLib.newEvent(),
ON_UNJUMP = eventLib.newEvent(),
ON_DEATH = eventLib.newEvent(),
ON_HORN = eventLib.newEvent(),}

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

---Returns the RC car position in world coordinates.
---@param delta number?
---@return Vector3
function API:getPos(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.lpos,RC.pos,delta)
end

---Returns the RC car rotation, note that the car only has one dimensional axis(the Y axis, up to down)
---@param delta number?
---@return number
function API:getRot(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.lrot,RC.rot,delta)
end

---Returns the RC car velocity in global coordinates
---@param delta number?
---@return Vector3
function API:getVel(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.lvel,RC.vel,delta)
end

---Returns the steer, in degrees
---@param delta number?
---@return number
function API:getSteer(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.lstr,RC.str,delta)
end

---@param height number
---@return table
function API:setCameraHeight(height)
	cam.height = height/16
	return self
end

---Returns the block the car is on
---@return BlockState|nil
function API:getFloorBlock()
	return RC.floor_block
end

---Returns the block the car is in
---@return BlockState|nil
function API:getBlockInside()
	return RC.block_inside
end

---Returns the RC car control vector
---***
---`x` : Left to Right
---`y` : Forward to Backward
---@return Vector2
function API:getControlVector()
	return RC.ctrl
end

---Returns a Vector3 containing the data about the engine acceleration
--***
---`x` : minimum speed in meters/ticks  
---`y` : maximum speed in meters/ticks  
---`z` : the percentage on where in between it is, the range is 0 - 1, slowest - fastest  
---@return Vector3
function API:getEngineThrottleData()
	return vectors.vec3(RC.a_s,RC.a_sf,RC.e_a)
end

---Returns the local Velocity of the RC car.
---***
---`x` : Left-Right  
---`y` : UP-Down  
---`z` : Backward-Forward  
---@param delta number?
---@return Vector3
function API:getLocalVel(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.loc_lvel,RC.loc_vel,delta)
end

---Returns the Engine wheel distance traveled, not the movement distance traveled
---@param delta number?
---@return number
function API:getDistanceTraveled(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.ldt,RC.dt,delta)
end

---Returns the Engine wheel distance traveled, not the movement distance traveled
---@param delta number?
---@return number
function API:getThrottleDistance(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.ltr,RC.tr,delta)
end

---Returns true if the RC car can be controlled
---@return boolean
function API:isActive()
	return RC.engine
end

---Returns the Engine Throttle Speed.  
--- Backwards -1 <-0-> +1 Forward
---@return number
function API:getEngineSpeed()
	return RC.et
end

---Gets the Suspension state  
---***
--- X suspension Left to Right  
--- Y suspension Down to Up  
--- Z suspension Back to Front  
---@param delta number?
---@return Vector3
function API:getSuspension(delta)
	if not delta then delta = 0 end
	return math.lerp(RC.ls,RC.s,delta)
end

---Returns the Camera Direction, the 3rd person camera
---@param delta number?
---@return Vector2
function API:getCameraDir(delta)
	if not delta then delta = 0 end
	return math.lerp(cam.ldir,cam.dir,delta)
end

---Returns true if the car is on the ground
---@return boolean
function API:isOnGround()
	return RC.is_on_floor
end

---Returns a number ranging from 0 to 1
---***
--- Player Camera 0 <---> 1 RC Car Camera
---@return number
function API:getCameraTransition()
	return cam.t
end

---Registers the given model as a wheel
---@param model ModelPart
---@param wheel_radius number
---@param is_engine_wheel boolean
---@param steer_angle number?
function API:registerWheel(model,wheel_radius,is_engine_wheel,steer_angle)
	if not steer_angle then steer_angle = 0 end
	table.insert(RC.wheels,{m=model,wr=wheel_radius/16,isw=is_engine_wheel,sa=steer_angle})
end

-->====================[ Physics ]====================<--

local function getCollisionShapes(pos)
	local expand = RC.size * vec(0.5,1,0.5)
	local spos = pos:copy()
	
	local i = 0
	local collision = {}
	local extent = RC.size * 0.5
	
	for key, block in pairs(world.getBlocks((spos - 2),(spos + 2))) do
		local forceSolid = false
		local bpos = block:getPos()
		for _, name in pairs(Physics.force_solid) do
			if name == block.id then
				forceSolid = true
				break
			end
		end
		
		if forceSolid then
			i = i + 1
			collision[i] = {
				vec(0,0,0) + bpos - expand,
				vec(1,1,1) + bpos + expand.x_z
			}
		else
			for _, aabb in pairs(block:getCollisionShape()) do
				i = i + 1
				collision[i] = {
					aabb[1] + bpos - expand,
					aabb[2] + bpos + expand.x_z
				}
			end
		end
	end
	return collision
end

local function getStepHeight(pos)
	local spos = pos:copy()
	local stepHeight = 0
	for i = 1, 10, 1 do
		local coll = getCollisionShapes(spos)
		for key, aabb in pairs(coll) do
			if aabb[2].y > spos.y and aabb[1] <= spos and aabb[2] >= spos then
				spos.y = aabb[2].y + Physics.margin
			end
		end
	end
	stepHeight = spos.y-pos.y
	return stepHeight
end

local function collision(pos,vel,axis)
	local brpos = pos:copy()
	local collided = false
	local coll = getCollisionShapes(pos)
	for _, aabb in pairs(coll) do
		if aabb[1] <= pos and aabb[2] >= pos then
			collided = true
			if axis == 1 then
				if math.sign(vel) < 0 then
					brpos.x = aabb[2].x + Physics.margin else brpos.x = aabb[1].x - Physics.margin
				end
			elseif axis == 2 then
				if math.sign(vel) < 0 then
					brpos.y = aabb[2].y + Physics.margin else brpos.y = aabb[1].y - Physics.margin
				end
			elseif axis == 3 then
				if math.sign(vel) < 0 then
					brpos.z = aabb[2].z + Physics.margin else brpos.z = aabb[1].z - Physics.margin
				end
			end
		end
	end
	if collided then
		if axis == 1 then
			return brpos.x
  elseif axis == 2 then
			return brpos.y
  elseif axis == 3 then
			return brpos.z
		end
	end
end
local engineSound = sounds:playSound("engine",RC.pos,1,0,true)
events.TICK:register(function ()
	cam.lcam_dist = cam.cam_dist
	local cdist = (RC.pos-client:getCameraPos()):length()
	cam.cam_dist = cdist
	cam.d = math.clamp(cam.lcam_dist-cam.cam_dist,-0.9,0.9) * 0.3 +1
	local e = math.abs(RC.et*1.3)
	for i = 1, 10, 1 do
		if e > 1 then
			e = e * 1.3 - 0.8
		else
			break
		end
	end
	engineSound:setPos(RC.pos):setPitch((e*1+0.7) * cam.d):setVolume(math.clamp(math.clamp(e*8,0.0,1),0,0.1))
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
		if RC.is_underwater then
			RC.a_f = 0.9
			RC.vel = RC.vel * 0.8
			RC.vel.y = RC.vel.y - RC.g * 0.9
		end
		local ssf = (RC.a_f-1) + 1
		if result and block:hasCollision() then RC.pos.y = result RC.vel:mul(ssf,0,ssf) RC.is_on_floor = true else RC.is_on_floor = false end
		RC.block_inside = world.getBlockState(RC.pos)
		RC.is_underwater = (#RC.block_inside:getFluidTags() ~= 0)
		if RC.block_inside.id == "minecraft:bubble_column" then
			RC.vel.y = RC.vel.y + 0.1
		end
		RC.vel.y = RC.vel.y + RC.g
		RC.pos:add(0,0.01,0)
	end

	do
		local ssf = (RC.a_f-1) + 1
		if (RC.is_on_floor or RC.is_underwater) and not RC.is_handbreak then
			RC.vel.x = RC.vel.x * ssf - RC.mat.c3.x * RC.et * (1-ssf)
		end
		RC.pos.x = RC.pos.x + RC.vel.x
		local result = collision(RC.pos,RC.vel.x,1)
		if result then
			local stepHeight = getStepHeight(RC.pos)
			if stepHeight <= 1.1 and stepHeight > 0 then
				RC.pos.y = RC.pos.y + stepHeight
				RC.vel.y = RC.vel.y + 0.2
			else
				RC.pos.x = result RC.vel:mul(0,ssf,ssf)
			end
		end
	end
	
	do
		local ssf = (RC.a_f-1) + 1
		if (RC.is_on_floor or RC.is_underwater) and not RC.is_handbreak then
			RC.vel.z = RC.vel.z * ssf - RC.mat.c3.z * RC.et * (1-ssf)
		end
		RC.pos.z = RC.pos.z + RC.vel.z
		local result = collision(RC.pos,RC.vel.z,3)
		if result then
			local stepHeight = getStepHeight(RC.pos)
			if stepHeight <= 1 and stepHeight > 0 then
				RC.pos.y = RC.pos.y + stepHeight
				RC.vel.y = RC.vel.y + 0.2
			else
				RC.pos.z = result RC.vel:mul(ssf,ssf,0)
			end
		end
	end

	RC.tr = RC.tr + RC.et
	RC.loc_lvel = RC.loc_vel
	local locMat =  matrices.mat4():rotateY(RC.rot)
	RC.loc_vel = (RC.vel:copy():mul(-1,1,1):augmented() * locMat).xyz
	RC.mat = locMat
	RC.ls = RC.s:copy()
	RC.s = RC.s + RC.sv
	RC.sv = RC.sv * 0.4 + vec(
		RC.loc_vel.x-RC.loc_lvel.x,
		RC.lvel.y - RC.vel.y,
		RC.loc_vel.z-RC.loc_lvel.z) * 2 - RC.s * 0.9
	RC.rot = RC.rot + RC.str * RC.loc_vel.z
	RC.ldt = RC.dt
	RC.dt = RC.dt + RC.loc_vel.z

	if host:isHost() then
		local deafth = false
		for key, d in pairs(deadly) do
			if RC.block_inside.id:find(d) then
				deafth = true
				break
			end
		end
		if deafth then
			for key, d in pairs(safe) do
				if RC.block_inside.id:find(d) then
					deafth = false
					break
				end
			end
		end
		if deafth then
			local p = player:getPos()
			pings.GNRCcarSyncState(p.x,p.y,p.z,0,0,0,0,0,true)
		end
	end

	if math.abs(RC.loc_vel.z) > 0.1 then
		if RC.floor_block then
			sounds:playSound(RC.floor_block:getSounds().step,RC.pos,0.1)
		elseif RC.is_underwater then
			sounds:playSound("minecraft:entity.player.swim",RC.pos,0.005)
		end
	end

	if not RC.is_underwater and RC.g == RC.wjg then
		if RC.is_jumping then
			RC.g = RC.jg
		else
			RC.g = RC.ng
		end
	end

	if not H then return end
	cam.ldir = cam.dir:copy()
	cam.dir = (cam.dir - (RC.pos - RC.lpos).xz / cam.dist):normalized()
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
		pings.GNRCcarSyncState(snap(RC.pos.x,100),snap(RC.pos.y,100),snap(RC.pos.z,100),snap(RC.rot,100),RC.e_a,
		snap(RC.vel.x,100),snap(RC.vel.y,100),snap(RC.vel.z,100),false)
	end
end)

function pings.GNRCcarHandbreak(bool)
	RC.is_handbreak = bool
end

function pings.GNRCcarCtrlThrottle(throttle)
	RC.ctrl.y = throttle
end

function pings.GNRCcarCtrlSteer(steer)
	RC.ctrl.x = steer
end

function pings.GNRCCARjump(underwater)
	API.ON_JUMP:invoke()
	RC.is_jumping = true
	if RC.is_underwater then
		RC.g = RC.wjg
	else
		RC.vel.y = RC.jump_height
		RC.g = RC.jg
	end
end

function pings.GNRCCARunjump()
	API.ON_UNJUMP:invoke()
	RC.is_jumping = false
	RC.g = RC.ng
end

---@param x number
---@param y number
---@param z number
---@param r number
---@param t number
---@param vx number
---@param vy number
---@param vz number
---@param death boolean
function pings.GNRCcarSyncState(x,y,z,r,t,vx,vy,vz,death)
	if death then
		API.ON_DEATH:invoke(RC.pos:copy(),vectors.vec3(x,y,z))
	end
	RC.pos = vectors.vec3(x,y,z)
	RC.vel = vectors.vec3(vx,vy,vz)
	RC.e_a = t
	RC.rot = r
end

function pings.GNRCcarHonk()
	API.ON_HORN:invoke()
	sounds:playSound("RCcar.honk",RC.pos,1,1)
	animations["RCcar.model"].honk:stop():play()
end

-->====================[ Rendering ]====================<--

local deltaFrame = 0
local lsys_time = client:getSystemTime()
events.WORLD_RENDER:register(function (delta)
	local sys_time = client:getSystemTime()
	deltaFrame = (sys_time-lsys_time) * 0.01
	lsys_time = sys_time
end)

events.POST_WORLD_RENDER:register(function (dt)
	local tpos = math.lerp(RC.lpos,RC.pos,dt)
	local true_vel = math.lerp(RC.lvel,RC.vel,dt)
	local true_dist_trav = math.lerp(RC.ldt,RC.dt,dt)
	local throttle_trav = -math.lerp(RC.ltr,RC.tr,dt)
	local true_steer = -math.lerp(RC.lstr,RC.str,dt) / 33
	local true_sus = math.lerp(RC.ls,RC.s,dt)
	local true_rot = math.lerp(RC.lrot,RC.rot,dt)
	Parts.root:setPos(tpos * 16):setRot((true_vel.y-RC.g)*-RC.loc_vel.z*90,true_rot,0)
	Parts.base:setPos(0,true_sus.y,0):setRot(math.deg(-true_sus.z)*0.3,0,math.deg(-true_sus.x))
	for _, wheel in pairs(RC.wheels) do
		if wheel.isw then
			wheel.m:setRot(math.deg(throttle_trav)/wheel.wr,true_steer*wheel.sa)
			if RC.is_underwater and math.abs(RC.et) > 0.2 then
				particles:newParticle("minecraft:bubble_column_up",wheel.m:partToWorldMatrix().c4.xyz,RC.mat.c3.xyz*RC.et*3)
	end
			if  (math.abs(RC.et+RC.loc_vel.z / RC.a_f) > 0.2 or math.abs(RC.loc_vel.x) > 0.05) and RC.is_on_floor then
				pcall(particles.newParticle,particles,"minecraft:block "..RC.floor_block.id,wheel.m:partToWorldMatrix().c4.xyz,RC.mat.c3.xyz*RC.et*100)
		end
		else
			wheel.m:setRot(math.deg(true_dist_trav)/wheel.wr*2,true_steer*wheel.sa)
		end
	end

	if not H then return end
		if not player:isLoaded() then return end
		local crot = player:getRot()
		crot.y = (crot.y) % 360 -- <=== El stupido
		local trueCamDir = math.lerp(cam.ldir,cam.dir,dt)
		trueCamDir = vectors.vec3(trueCamDir.x,0.5,trueCamDir.y):add(0,0.5,0)*cam.dist
		if player:isLoaded() then
			local hpos = player:getPos(dt):add(0,player:getEyeHeight(),0)
			if cam.enabled then
				cam.t = math.min(cam.t + deltaFrame * cam.t_d,1)
			else
				cam.t = math.max(cam.t - deltaFrame * cam.t_d,0)
			end
			if cam.t < 0.001 then
				renderer:setCameraPivot()
				renderer:setCameraRot()
			else
				local transition = -(math.cos(math.pi * cam.t) - 1) / 2 -- easing function
				
				if renderer:isFirstPerson() then -- FIrst Person Camera
					renderer:setCameraPivot(math.lerp(hpos,tpos:add(0,cam.height+(true_sus.y)/16,0),transition))
					local shake = vectors.vec2()
					if RC.is_on_floor then
						local intensity = math.min(RC.vel.xz:length(),2)
						shake = vectors.vec2(intensity*(math.random()-.5),intensity*(math.random()-.5))
					end
					renderer:setCameraRot(crot.x+shake.x,math.lerp(crot.y,(crot.y-true_rot)%360,transition),math.deg(true_sus.x)*.3+shake.y)
					
				else -- Third Person Camera
					renderer:setCameraPivot(math.lerp(hpos,tpos:add(0,cam.height,0),transition))
					local frot = math.deg(math.atan2(trueCamDir.z,trueCamDir.x)) + 90
					if renderer:isCameraBackwards() then
						renderer:setCameraRot(crot.x,math.lerp(crot.y, frot + 180,transition),0)
					else
						renderer:setCameraRot(crot.x,math.lerp(crot.y, frot,transition),0)
					end
				end
			end
		end
	if cam.t < 0.01 then
		renderer:setFOV()
	else
	renderer:setFOV(math.lerp(1,math.lerp(1,RC.a_sf_fov_mul,RC.e_a),cam.t))
	end
end)



local lprot = vectors.vec2()
events.POST_RENDER:register(function (x,y)
	if not player:isLoaded() and not H then return end
	local prot = player:getRot()
	local d = lprot-prot
	lprot = prot
	if not renderer:isFirstPerson() and RC.engine then
		cam.dir = vectors.rotateAroundAxis(d.y,vectors.vec3(cam.dir.x,0,cam.dir.y),vectors.vec3(0,1,0)).xz
	end
end)


return API