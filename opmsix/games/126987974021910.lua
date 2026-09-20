local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local prediction = vape.Libraries.prediction

local soccer = {}

local function getBall()
	local match = soccer.Renderer.GetMatchBallId()
	local state = match and soccer.Renderer.GetAuthoritativeMovementState() or nil
	if state then
		return match, state
	end

	local closest, distance = nil, math.huge
	local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or gameCamera.CFrame.Position
	for _, v in workspace.Misc.Visuals:GetChildren() do
		local id = v.Name:match('^ClientBall_(.+)$')
		if id then
			local magnitude = (v.Position - localPosition).Magnitude
			if magnitude < distance then
				closest, distance = id, magnitude
			end
		end
	end

	return closest, closest and soccer.Renderer.GetMovementState(closest) or nil
end

local function getOwnedPosition()
	if not entitylib.isAlive then return nil end

	local position = soccer.Carry.GetVisualOwnedPosition(entitylib.character.Character)
	return position or entitylib.character.RootPart.Position
end

local function getIntercept(state, horizon, range)
	local hum = entitylib.character.Humanoid
	local localPosition = entitylib.character.RootPart.Position
	local reach = soccer.HitboxSettings.Receive.Size.Y * 0.5
	local airreach = soccer.HitboxSettings.AirReceive.Size.Y * 0.5 + hum.JumpHeight
	local closest, approach = math.huge, nil
	for i = 1, 60 do
		local step = i * (horizon / 60)
		local position = soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, step)
		local rise = position.Y - localPosition.Y
		local flat = ((position - localPosition) * Vector3.new(1, 0, 1)).Magnitude
		if flat < closest and flat <= range then
			closest, approach = flat, position
		end
		if flat <= math.min(range, hum.WalkSpeed * step + 2) and rise <= airreach and rise >= -reach then
			return step, position, rise > reach
		end
	end

	return nil, approach
end

local function getGoal(enemy)
	local team = soccer.ActorTeams.GetActorTeamName(lplr)
	if not team then return nil end

	local side = workspace.Map.Data:FindFirstChild(enemy and (team == 'Team1' and 'Team2' or 'Team1') or team)
	return side and side:FindFirstChild('Goal') or nil
end

local function getInput(action)
	local bind = soccer.Keybinds.Get(action)
	if not bind then return nil end

	return {
		KeyCode = bind.KeyCodes and bind.KeyCodes[1] or Enum.KeyCode.Unknown,
		UserInputType = bind.InputTypes and bind.InputTypes[1] or Enum.UserInputType.Keyboard,
		UserInputState = Enum.UserInputState.Begin
	}
end

local function getKeeper(goal)
	local closest, distance = nil, math.huge
	for _, v in entitylib.List do
		if v.Targetable then
			if v.Character:GetAttribute('ActiveGoalkeeper') then
				return v
			end
			local magnitude = (v.RootPart.Position - goal.Position).Magnitude
			if magnitude < distance then
				closest, distance = v, magnitude
			end
		end
	end

	return distance < 45 and closest or nil
end

run(function()
	soccer = {
		ActionCommands = require(replicatedStorage.Modules.Actions.ActionCommands),
		ActionMotion = require(replicatedStorage.Modules.Actions.ActionMotion),
		ActionRemoteProtocol = require(replicatedStorage.Modules.Actions.ActionRemoteProtocol),
		ActorTeams = require(replicatedStorage.Client.Gameplay.ActorTeams),
		Aim = require(replicatedStorage.Client.Gameplay.Actions.Aim),
		AimFacing = require(replicatedStorage.Modules.Actions.AimFacing),
		ChargePathPreview = require(replicatedStorage.Client.Gameplay.Actions.ChargePathPreview),
		ChargePathVelocity = require(replicatedStorage.Modules.Actions.ChargePathVelocity),
		AssistedPass = require(replicatedStorage.Modules.Actions.AssistedPass),
		Carry = require(replicatedStorage.Modules.Ball.Carry),
		Catalog = require(replicatedStorage.Modules.Cosmetics.Catalog),
		Controls = require(replicatedStorage.Modules.Gameplay.Controls),
		Dodge = require(replicatedStorage.Modules.Actions.Dodge),
		DodgeInput = require(replicatedStorage.Client.Gameplay.Actions.Dodge),
		GoalEffect = require(replicatedStorage.Client.Gameplay.Visual.GoalEffect),
		GoalkeeperDive = require(replicatedStorage.Modules.Actions.GoalkeeperDive),
		GoalkeeperPrediction = require(replicatedStorage.Modules.Gameplay.GoalkeeperPrediction),
		GoalkeeperRole = require(replicatedStorage.Client.Gameplay.Player.GoalkeeperRole),
		HitboxSettings = require(replicatedStorage.Modules.Gameplay.HitboxSettings),
		Keybinds = require(replicatedStorage.Modules.Gameplay.Keybinds),
		Kick = require(replicatedStorage.Modules.Actions.Kick),
		KickCore = require(replicatedStorage.Modules.Actions.KickCore),
		Ownership = require(replicatedStorage.Modules.Ball.Ownership),
		Pass = require(replicatedStorage.Modules.Actions.Pass),
		PassInput = require(replicatedStorage.Client.Gameplay.Actions.Pass),
		Physics = require(replicatedStorage.Modules.Ball.Physics),
		PlayerSettings = require(replicatedStorage.Modules.PlayerSettings),
		Ragdoll = require(replicatedStorage.Modules.Characters.Ragdoll),
		Remotes = require(replicatedStorage.Modules.Remotes),
		Renderer = require(replicatedStorage.Client.Gameplay.Ball.Renderer),
		Reticle = require(replicatedStorage.Client.Interface.Reticle),
		Shoot = require(replicatedStorage.Modules.Actions.Shoot),
		ShootInput = require(replicatedStorage.Client.Gameplay.Actions.Shoot),
		SlideTackle = require(replicatedStorage.Modules.Actions.SlideTackle),
		SlideTackleInput = require(replicatedStorage.Client.Gameplay.Actions.SlideTackleInput),
		Sprint = require(replicatedStorage.Modules.Actions.Sprint),
		SprintInput = require(replicatedStorage.Client.Gameplay.Player.Sprint),
		TurnControl = require(replicatedStorage.Client.Gameplay.Player.TurnControl),
		VolleyLockOn = require(replicatedStorage.Modules.Ball.VolleyLockOn),
		VolleyOpportunity = require(replicatedStorage.Client.Gameplay.Actions.VolleyOpportunity)
	}

	vape:Clean(function()
		table.clear(soccer)
	end)
end)

run(function()
	local oldcheck, oldcolor = entitylib.targetCheck, entitylib.getEntityColor
	entitylib.targetCheck = function(ent)
		local team = soccer.ActorTeams.GetActorTeamName(lplr)
		if team and soccer.ActorTeams.GetCharacterTeamName(ent.Character) == team then
			return false
		end
		return oldcheck(ent)
	end

	entitylib.getEntityColor = function(ent)
		local call = oldcolor(ent)
		if call or not vape.Settings.Modules.Options['Use team color'].Enabled then
			return call
		end
		return soccer.ActorTeams.GetCharacterTeamName(ent.Character) == 'Team1' and Color3.new(0.3, 0.55, 1) or Color3.new(1, 0.35, 0.35)
	end

	local oldstart = entitylib.start
	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, v in workspace.Characters.NPCs:GetChildren() do
				entitylib.addEntity(v)
			end
			table.insert(entitylib.Connections, workspace.Characters.NPCs.ChildAdded:Connect(entitylib.addEntity))
			table.insert(entitylib.Connections, workspace.Characters.NPCs.ChildRemoved:Connect(entitylib.removeEntity))
			table.insert(entitylib.Connections, replicatedStorage.Remotes.Match.State.OnClientEvent:Connect(function()
				task.delay(0.1, entitylib.refresh)
			end))
		end
	end
end)
entitylib.start()

for _, v in {'AimAssist', 'Reach', 'SilentAim', 'TriggerBot', 'Killaura', 'MurderMystery', 'AntiRagdoll', 'Disabler', 'PromptChanger', 'Jesus', 'Xray'} do
	vape:Remove(v)
end

run(function()
	local Sprint
	local WithBall
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				Sprint:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end
	
					local wanted = not WithBall.Enabled or soccer.Renderer.GetBallOwnedBy(lplr.UserId) ~= nil
					if wanted == soccer.SprintInput.IsSprintButtonToggled() then return end
					if wanted and not soccer.SprintInput.IsSprintButtonUsable() then return end
	
					soccer.SprintInput.ToggleSprintButton()
				end))
			elseif soccer.SprintInput.IsSprintButtonToggled() then
				soccer.SprintInput.ToggleSprintButton()
			end
		end,
		Tooltip = 'Keeps you sprinting without holding the key down.'
	})
	
	WithBall = Sprint:CreateToggle({
		Name = 'Only with ball',
		Tooltip = 'Only sprints while you are the one carrying the ball.'
	})
	
end)

run(function()
	local PerfectShot
	local Passes
	
	local oldkick, oldalpha
	local hookkick, hookalpha
	
	PerfectShot = vape.Categories.Combat:CreateModule({
		Name = 'PerfectShot',
		Function = function(callback)
			if callback then
				oldkick = oldkick or soccer.ActionCommands.Kick
				hookkick = function(command)
					local call = oldkick(command)
					if PerfectShot.Enabled and call.MaximumChargeSeconds and (Passes.Enabled or call.PassType == soccer.ActionCommands.PassTypes.Shot) then
						call.ChargeSeconds = call.MaximumChargeSeconds
					end
					return call
				end
				soccer.ActionCommands.Kick = hookkick
	
				oldalpha = oldalpha or soccer.KickCore.GetChargeAlpha
				hookalpha = function(seconds, constants)
					if PerfectShot.Enabled and (Passes.Enabled or not constants or constants == soccer.KickCore.Constants) then
						return 1
					end
					return oldalpha(seconds, constants)
				end
				soccer.KickCore.GetChargeAlpha = hookalpha
			else
				if soccer.ActionCommands.Kick == hookkick then
					soccer.ActionCommands.Kick = oldkick
				end
				if soccer.KickCore.GetChargeAlpha == hookalpha then
					soccer.KickCore.GetChargeAlpha = oldalpha
				end
			end
		end,
		Tooltip = 'Sends every shot at full power without holding the charge.'
	})
	
	Passes = PerfectShot:CreateToggle({
		Name = 'Passes',
		Tooltip = 'Puts passes, lobs and throws on full power too.'
	})
end)

run(function()
	local ShotRedirect
	local Mode
	local Height
	local Fake
	local PerfectFake
	local Switch
	local MaxAngle
	local Range
	local BodyAim
	local AutoAim
	local AimSpeed
	local Display
	
	local flatMask = Vector3.new(1, 0, 1)
	local sideInset = 7
	local topHeight = 0.72
	local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)
	local rand = Random.new()
	local roll, wascharging, chargestart
	local holds = {}
	local nextsolve = 0
	local solved = {}
	local old, oldaim
	local marker
	local aimpoint
	
	local function getSwitch()
		if not PerfectFake.Enabled then
			return Switch.Value
		end
	
		local shortest = soccer.KickCore.Constants.MaximumChargeSeconds
		for _, v in holds do
			if v < shortest then
				shortest = v
			end
		end
	
		return math.max(shortest - 0.06, 0.05)
	end
	
	local function getCharge()
		return chargestart and math.clamp(os.clock() - chargestart, 0, soccer.KickCore.Constants.MaximumChargeSeconds) or soccer.KickCore.Constants.MaximumChargeSeconds
	end
	
	local function getLaunch(origin, call, direction)
		local ray = {Origin = call.Origin, CameraCFrame = call.CameraCFrame, IsAirborne = call.IsAirborne, Direction = direction}
		local ok, velocity = pcall(soccer.ChargePathVelocity.Get, entitylib.character.Character, getCharge(), soccer.ActionCommands.PassTypes.Shot, ray, origin, nil, soccer.AimFacing.GetFlatDirection(direction), nil, soccer.ChargePathPreview.GetChargeBoundaryWorld(lplr), nil)
	
		return ok and typeof(velocity) == 'Vector3' and velocity or nil
	end
	
	local function getCrossing(origin, velocity, plane, normal)
		local state = {Mode = 'Airborne', Position = origin, Velocity = velocity, Spin = Vector3.new(0, 0, 0), Radius = 1}
		local previous, covered = origin, 0
		for i = 1, 90 do
			local position = soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, i * 0.03)
			local travelled = (position - origin):Dot(normal)
			if travelled >= plane then
				local span = travelled - covered
				local alpha = span > 0.001 and (plane - covered) / span or 0
				return previous:Lerp(position, alpha), (i - 1 + alpha) * 0.03
			end
			previous, covered = position, travelled
		end
	
		return previous, 2.7
	end
	
	local function getDirection(origin, call, aim, normal)
		local offset = (aim - origin) * flatMask
		local plane = offset:Dot(normal)
		if offset.Magnitude < 0.01 or plane < 0.01 then return nil end
	
		local now = os.clock()
		if solved.Direction and now - solved.Time < 0.03 and (solved.Origin - origin).Magnitude < 1 and (solved.Aim - aim).Magnitude < 1 then
			return solved.Direction
		end
	
		local flat, target = offset.Unit, aim
		local low, high = -1.4, 0.2
		for _ = 1, 9 do
			local slope = (low + high) * 0.5
			local velocity = getLaunch(origin, call, (flat + Vector3.new(0, slope, 0)).Unit)
			if not velocity then return nil end
	
			local point = getCrossing(origin, velocity, plane, normal)
			if point.Y < aim.Y then
				low = slope
			else
				high = slope
			end
	
			target -= (point - aim) * flatMask
			flat = ((target - origin) * flatMask).Unit
		end
	
		solved.Direction = (flat + Vector3.new(0, high, 0)).Unit
		solved.Time, solved.Origin, solved.Aim = now, origin, aim
	
		return solved.Direction
	end
	
	local function getLanding(origin, velocity, plane, normal)
		local built, state = pcall(soccer.Physics.NewState, origin, velocity, soccer.Physics.BallRadius, 0, Vector3.new(0, 0, 0))
		if not built or not state then return nil end
	
		local boundary = soccer.Renderer.GetMatchBoundaryWorld()
		local previous, covered = origin, 0
		for i = 1, 60 do
			local stepped, result = pcall(soccer.Physics.GetStateAtTime, state, i * 0.03, boundary)
			local position = stepped and result and (result.Position or result) or nil
			if typeof(position) ~= 'Vector3' then return nil end
	
			local travelled = (position - origin):Dot(normal)
			if travelled >= plane then
				local span = travelled - covered
				return previous:Lerp(position, span > 0.001 and (plane - covered) / span or 0)
			end
			previous, covered = position, travelled
		end
	
		return nil
	end
	
	local function getBest(goal, origin, call, normal, mouth)
		local keeper = getKeeper(goal)
		local feet = keeper and keeper.RootPart.Position - Vector3.new(0, keeper.HipHeight, 0) or nil
		local plane = ((mouth - origin) * flatMask):Dot(normal)
		local reachable = mouth.Y + goal.Size.Y * (topHeight - 0.5)
		local flight = plane / math.max(soccer.Shoot.Constants.Shot.MaximumSpeed * 0.85, 1)
	
		local probe = mouth + Vector3.new(0, goal.Size.Y * (topHeight - 0.5), 0)
		local direction = getDirection(origin, call, probe, normal)
		local velocity = direction and getLaunch(origin, call, direction) or nil
		if velocity then
			local point, travel = getCrossing(origin, velocity, plane, normal)
			reachable, flight = point.Y, travel
		end
	
		local cover = keeper and soccer.GoalkeeperDive.GetTravel(flight) + soccer.HitboxSettings.Receive.Size.X * 0.5 + soccer.GoalkeeperDive.Constants.SaveContactPadding or 0
		local candidates = {}
		for i = -4, 4 do
			for i2 = 0, 4 do
				local spot = i / 4
				local raise = 0.12 + i2 * ((topHeight - 0.12) / 4)
				local point = mouth + goal.CFrame.RightVector * (spot * (goal.Size.X * 0.5 - sideInset)) + Vector3.new(0, goal.Size.Y * (raise - 0.5), 0)
				if point.Y <= reachable + 0.3 then
					local score = rand:NextNumber(0, 0.5)
					if feet then
						score += math.min((Vector3.new(point.X, feet.Y, point.Z) - feet).Magnitude - cover, 10)
						score += point.Y - feet.Y > soccer.GoalkeeperDive.Constants.MaximumSaveHeight and 25 or 0
					else
						score += raise * 4
					end
					table.insert(candidates, {Side = spot, Height = raise, Point = point, Score = score})
				end
			end
		end
	
		table.sort(candidates, function(a, b)
			return a.Score > b.Score
		end)
	
		local width = goal.Size.X * 0.5 - soccer.Physics.BallRadius - 1
		local bar = goal.Size.Y * 0.5 - soccer.Physics.BallRadius
		for i = 1, math.min(#candidates, 4) do
			local candidate = candidates[i]
			local direction = getDirection(origin, call, candidate.Point, normal)
			local landing = direction and getLanding(origin, getLaunch(origin, call, direction), plane, normal) or nil
			if landing then
				local offset = landing - mouth
				if math.abs(offset:Dot(goal.CFrame.RightVector)) < width and offset.Y < bar and offset.Y > -bar then
					return candidate.Side, candidate.Height
				end
			end
		end
	
		local top = candidates[1]
		return top and top.Side or 0, top and top.Height or math.min(Height.Value / 100, topHeight)
	end
	
	local function getAim(origin, call)
		local goal = getGoal(true)
		if not goal then return nil end
		if (goal.Position - origin).Magnitude > Range.Value then return nil end
	
		local normal = (goal.CFrame.LookVector * flatMask).Unit
		if ((goal.Position - origin) * flatMask):Dot(normal) < 0 then
			normal = -normal
		end
	
		local mouth = goal.Position - normal * (goal.Size.Z * 0.5)
		local side = 0
		local height = math.min(Height.Value / 100, topHeight)
	
		if Mode.Value == 'Best' then
			if not roll then
				local spot, raise = getBest(goal, origin, call, normal, mouth)
				roll = {Side = spot, Height = raise}
			end
			side, height = roll.Side, roll.Height
		elseif Mode.Value == 'Random' then
			if not roll then
				local keeper = getKeeper(goal)
				local away = keeper and (goal.CFrame.RightVector:Dot(keeper.RootPart.Position - goal.Position) < 0 and 1 or -1) or (rand:NextInteger(0, 1) == 0 and -1 or 1)
				roll = {Side = away * rand:NextNumber(0.35, 1), Height = rand:NextNumber(0.2, topHeight)}
			end
			side = roll.Side
			height = roll.Height
		elseif Mode.Value == 'Left' then
			side = -1
		elseif Mode.Value == 'Right' then
			side = 1
		elseif Mode.Value ~= 'Center' then
			local keeper = getKeeper(goal)
			side = keeper and (goal.CFrame.RightVector:Dot(keeper.RootPart.Position - goal.Position) < 0 and 1 or -1) or 1
			if Mode.Value == 'Top corners' then
				height = topHeight
			end
		end
	
		if Fake.Enabled and (not chargestart or os.clock() - chargestart < getSwitch()) then
			side = side ~= 0 and -side or 1
		end
	
		local aim = mouth + goal.CFrame.RightVector * (side * (goal.Size.X * 0.5 - sideInset)) + Vector3.new(0, goal.Size.Y * (math.min(height, topHeight) - 0.5), 0)
		local wanted = aim - origin
		if wanted.Magnitude < 0.01 then return nil end
		if math.deg(math.acos(math.clamp(wanted.Unit:Dot(gameCamera.CFrame.LookVector), -1, 1))) > MaxAngle.Value then return nil end
	
		return aim, normal
	end
	
	ShotRedirect = vape.Categories.Combat:CreateModule({
		Name = 'ShotRedirect',
		Function = function(callback)
			if callback then
				marker = Instance.new('Part')
				marker.Anchored = true
				marker.CanCollide = false
				marker.CanQuery = false
				marker.CanTouch = false
				marker.Color = Color3.new(0.35, 1, 0.45)
				marker.Material = Enum.Material.Neon
				marker.Shape = Enum.PartType.Ball
				marker.Size = Vector3.new(2.5, 2.5, 2.5)
				marker.Transparency = 0.35
				marker.Parent = workspace
	
				oldaim = oldaim or soccer.Aim.SetDirection
				soccer.Aim.SetDirection = function(direction)
					if BodyAim.Enabled and aimpoint and entitylib.isAlive then
						local wanted = (aimpoint - entitylib.character.RootPart.Position) * flatMask
						if wanted.Magnitude > 0.01 then
							return oldaim(wanted.Unit)
						end
					end
					return oldaim(direction)
				end
	
				old = old or soccer.Reticle.GetCameraAimRayWithoutHit
				soccer.Reticle.GetCameraAimRayWithoutHit = function(...)
					local call = old(...)
					if typeof(call) ~= 'table' or not call.Origin then return call end
					if soccer.PassInput.IsCharging() then return call end
	
					local origin = getOwnedPosition()
					local aim, normal = nil, nil
					if origin then
						aim, normal = getAim(origin, call)
					end
					local direction = aim and getDirection(origin, call, aim, normal) or nil
					if not direction then return call end
	
					call.Direction = direction
					call.CameraCFrame = CFrame.lookAt(call.CameraCFrame.Position, call.CameraCFrame.Position + (aim - origin).Unit)
	
					return call
				end
	
				ShotRedirect:Clean(runService.RenderStepped:Connect(function(delta)
					local charging = soccer.ShootInput.IsCharging()
					if charging ~= wascharging then
						wascharging = charging
						if charging then
							roll = nil
							chargestart = os.clock()
						else
							if chargestart then
								table.insert(holds, 1, os.clock() - chargestart)
								if #holds > 5 then
									table.remove(holds)
								end
							end
							chargestart = nil
						end
					end
	
					if not charging and os.clock() >= nextsolve then
						nextsolve = os.clock() + 0.4
						roll = nil
					end
	
					local origin = entitylib.isAlive and soccer.Renderer.GetBallOwnedBy(lplr.UserId) and getOwnedPosition() or nil
					local ray = origin and old()
					aimpoint = ray and getAim(origin, ray) or nil
					marker.Transparency = aimpoint and Display.Enabled and 0.35 or 1
					if not aimpoint then return end
	
					marker.Position = aimpoint
					local facing = gameCamera.CFrame.LookVector
					local wanted = (aimpoint - gameCamera.CFrame.Position).Unit
					if not AutoAim.Enabled or wanted ~= wanted or not soccer.ShootInput.IsCharging() then return end
	
					local diffYaw = (math.atan2(facing.X, facing.Z) - math.atan2(wanted.X, wanted.Z)) % math.pi
					diffYaw -= diffYaw >= (math.pi / 2) and math.pi or 0
					diffYaw += diffYaw < -(math.pi / 2) and math.pi or 0
					local angle = Vector2.new(diffYaw, math.asin(facing.Y) - math.asin(wanted.Y)) // (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)
					angle *= math.min(AimSpeed.Value * delta, 1)
					mousemoverel(angle.X, angle.Y)
				end))
			else
				soccer.Reticle.GetCameraAimRayWithoutHit = old
				soccer.Aim.SetDirection = oldaim
				aimpoint, roll, wascharging = nil, nil, nil
				table.clear(solved)
				if marker then
					marker:Destroy()
					marker = nil
				end
			end
		end,
		Tooltip = 'Sends every shot you take into the enemy goal instead of where you aimed.'
	})
	
	Mode = ShotRedirect:CreateDropdown({
		Name = 'Mode',
		List = {'Best', 'Random', 'Top corners', 'Away from keeper', 'Left', 'Right', 'Center'},
		Tooltip = 'Which part of the goal to put the ball in. Best solves for the spot the keeper cannot reach in the balls flight time.'
	})
	Height = ShotRedirect:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 100,
		Default = 55,
		Suffix = '%',
		Tooltip = 'How high up the goal to aim, ignored on Top corners.'
	})
	Fake = ShotRedirect:CreateToggle({
		Name = 'Fake',
		Tooltip = 'Aims at the opposite side of the goal while you charge, then snaps to the real spot late.'
	})
	PerfectFake = ShotRedirect:CreateToggle({
		Name = 'Perfect fake',
		Default = true,
		Tooltip = 'Learns how long you actually hold shots and drops the decoy just before your shortest recent release, instead of using the slider.'
	})
	Switch = ShotRedirect:CreateSlider({
		Name = 'Fake switch',
		Min = 0.05,
		Max = 0.4,
		Default = 0.22,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'How long into the charge the decoy drops, when Perfect fake is off. Release before this and the shot goes to the decoy.'
	})
	MaxAngle = ShotRedirect:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 180,
		Default = 70,
		Tooltip = 'Stops redirecting when the goal is further off your camera than this.'
	})
	Range = ShotRedirect:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 160,
		Default = 110,
		Tooltip = 'Stops redirecting when the goal is further away than this.'
	})
	BodyAim = ShotRedirect:CreateToggle({
		Name = 'Body aim',
		Default = true,
		Tooltip = 'Turns your character onto the spot while you charge so the replay looks normal, without touching your camera.'
	})
	AutoAim = ShotRedirect:CreateToggle({
		Name = 'Auto aim',
		Tooltip = 'Physically turns your camera onto the spot as well. Leave this off if you do not want your camera moved.'
	})
	AimSpeed = ShotRedirect:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 30,
		Default = 9,
		Tooltip = 'How quickly auto aim turns you onto the spot.'
	})
	Display = ShotRedirect:CreateToggle({
		Name = 'Display',
		Default = true,
		Tooltip = 'Shows a marker on the spot your shot is going to.'
	})
end)

run(function()
	local TackleAssist
	local Targets
	local Range
	local Angle
	local BallCheck
	local Steer
	local BodyAim
	local StopDribble
	
	local flatMask = Vector3.new(1, 0, 1)
	local old, oldcommand
	local target, slidestart, aimdirection
	
	local function isTackleable(ent)
		if not (ent.Targetable and ent.Health > 0 and ent.Character.Parent and ent.RootPart.Parent) then
			return false
		end
		if soccer.Ragdoll.IsLocallyRagdolled(ent.Character) then
			return false
		end
	
		return not (StopDribble.Enabled and soccer.Dodge.IsDribbling(ent.Character))
	end
	
	local function getContact(distance)
		local constants = soccer.SlideTackle.Constants
		local ahead = -soccer.HitboxSettings.SlideTackle.CFrameOffset.Z
		for i = 0, 12 do
			local step = constants.HitboxDelaySeconds + i * 0.025
			if soccer.SlideTackle.GetTravel(step) + ahead >= distance then
				return step
			end
		end
	
		return constants.HitboxDelaySeconds + constants.HitboxSeconds
	end
	
	local function getAimPoint(ent, elapsed)
		local position = ent.RootPart.Position
		local flat = (position - entitylib.character.RootPart.Position) * flatMask
		local lead = math.max(getContact(flat.Magnitude) - elapsed, 0)
	
		return position + (ent.RootPart.AssemblyLinearVelocity * flatMask * lead)
	end
	
	local function getTarget(localPosition, direction)
		local _, state = getBall()
		local closest, best = nil, math.cos(math.rad(Angle.Value))
	
		for _, v in entitylib.AllPosition({
			Origin = localPosition,
			Range = Range.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled
		}) do
			if not isTackleable(v) then continue end
			if BallCheck.Enabled then
				local carrying = v.Player and soccer.Renderer.GetBallOwnedBy(v.Player.UserId) ~= nil
				if not carrying and not (state and not v.Player and (v.RootPart.Position - state.Position).Magnitude <= 8) then continue end
			end
	
			local flat = (v.RootPart.Position - localPosition) * flatMask
			local facing = flat.Magnitude > 0.01 and flat.Unit:Dot(direction) or -1
			if facing > best then
				closest, best = v, facing
			end
		end
	
		return closest
	end
	
	TackleAssist = vape.Categories.Combat:CreateModule({
		Name = 'TackleAssist',
		Function = function(callback)
			if callback then
				old = old or soccer.SlideTackle.Run
				soccer.SlideTackle.Run = function(root, direction, options, ...)
					if not (TackleAssist.Enabled and entitylib.isAlive and root == entitylib.character.RootPart and typeof(direction) == 'Vector3') then
						return old(root, direction, options, ...)
					end
	
					target, slidestart, aimdirection = getTarget(root.Position, direction), os.clock(), nil
					if not target then
						return old(root, direction, options, ...)
					end
	
					aimdirection = soccer.SlideTackle.GetAssistApproachDirection(root, getAimPoint(target, 0), 0, direction)
					if Steer.Enabled and typeof(options) == 'table' and options.GetDirection then
						local oldget = options.GetDirection
						options.GetDirection = function(...)
							local call = oldget(...)
							if not (target and entitylib.isAlive and isTackleable(target)) then
								return call
							end
	
							local elapsed = os.clock() - slidestart
							return soccer.SlideTackle.GetAssistApproachDirection(root, getAimPoint(target, elapsed), elapsed, call)
						end
					end
	
					return old(root, aimdirection, options, ...)
				end
	
				oldcommand = oldcommand or soccer.ActionCommands.SlideTackle
				soccer.ActionCommands.SlideTackle = function(...)
					local call = oldcommand(...)
					if aimdirection and typeof(call) == 'table' then
						call.AimDirection = aimdirection
					end
	
					return call
				end
	
				TackleAssist:Clean(runService.PostSimulation:Connect(function()
					if not (target and slidestart) then return end
	
					local constants = soccer.SlideTackle.Constants
					local elapsed = os.clock() - slidestart
					if elapsed > constants.HitboxDelaySeconds + constants.HitboxSeconds or not entitylib.isAlive or not isTackleable(target) then
						target, slidestart = nil, nil
						return
					end
					if not BodyAim.Enabled then return end
	
					local root = entitylib.character.RootPart
					if soccer.SlideTackle.IsInsideHitbox(root, target.RootPart.Position) then return end
	
					local wanted = (getAimPoint(target, elapsed) - root.Position) * flatMask
					if wanted.Magnitude > 0.01 then
						soccer.TurnControl.LockAutoRotate('SlideTackle', wanted.Unit)
					end
				end))
			elseif old then
				soccer.SlideTackle.Run = old
				soccer.ActionCommands.SlideTackle = oldcommand
				target, slidestart, aimdirection = nil, nil, nil
			end
		end,
		Tooltip = 'Aims the tackles you press yourself, steering the slide and turning your body onto the target so it lands.'
	})
	
	Targets = TackleAssist:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = TackleAssist:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 28,
		Default = 28,
		Tooltip = 'How far out opponents are worth aiming at. A slide only connects between 7.5 and 27.4 studs.'
	})
	Angle = TackleAssist:CreateSlider({
		Name = 'Angle',
		Min = 10,
		Max = 180,
		Default = 110,
		Suffix = 'degrees',
		Tooltip = 'How far off the way you are already sliding a target can be before it is left alone.'
	})
	Steer = TackleAssist:CreateToggle({
		Name = 'Steer',
		Default = true,
		Tooltip = 'Keeps correcting the slide while it is still steerable, which is the first 0.27s of it.'
	})
	BodyAim = TackleAssist:CreateToggle({
		Name = 'Body aim',
		Default = true,
		Tooltip = 'Turns your body onto the target for the whole slide, which is what points the tackle hitbox at them.'
	})
	StopDribble = TackleAssist:CreateToggle({
		Name = 'Stop on dribble',
		Default = true,
		Tooltip = 'Drops the target the moment they dribble, since the dodge makes them untouchable and chasing it only takes you out of position.'
	})
	BallCheck = TackleAssist:CreateToggle({
		Name = 'Ball check',
		Tooltip = 'Only aims at the opponent who actually has the ball.'
	})
	
end)

run(function()
	local AutoDribble
	local Range
	local Lead
	local Predict
	local KickCheck
	local KickRange
	local KickCharge
	local FakeCheck
	local AnimationCheck
	local Delay
	
	local slideanimation = 'rbxassetid://96680308558981'
	local kickanimations = {['rbxassetid://102546600977181'] = true, ['rbxassetid://71638837796273'] = true}
	local slides = setmetatable({}, {__mode = 'k'})
	local nextDribble = 0
	
	local function getSlideDirection(ent, elapsed)
		local position = ent.RootPart.Position * Vector3.new(1, 0, 1)
		local main = elapsed >= soccer.SlideTackle.Constants.StartupDashHandoffSeconds
		local sample = slides[ent.Character]
		if not sample or sample.Main ~= main then
			slides[ent.Character] = {Position = position, Main = main, Direction = sample and sample.Direction or nil}
			return sample and sample.Direction or nil
		end
	
		local step = position - sample.Position
		if step.Magnitude >= 0.3 then
			local blend = sample.Direction and (sample.Direction + step.Unit) or step.Unit
			sample.Direction = blend.Magnitude > 0.01 and blend.Unit or step.Unit
			sample.Position = position
		end
	
		return sample.Direction
	end
	
	local function getImpact(ent, elapsed, localPosition, localVelocity)
		local forward = getSlideDirection(ent, elapsed)
		if not forward then return nil end
	
		local opens = soccer.SlideTackle.Constants.HitboxDelaySeconds
		local closes = opens + soccer.SlideTackle.Constants.HitboxSeconds
		if FakeCheck.Enabled and elapsed > closes then return nil end
	
		local travelled = soccer.SlideTackle.GetTravel(elapsed)
		local size = soccer.HitboxSettings.SlideTackle.Size * 0.5
		local center = soccer.HitboxSettings.SlideTackle.CFrameOffset.Position
		for i = 0, 20 do
			local step = i * 0.025
			if not FakeCheck.Enabled or (elapsed + step >= opens and elapsed + step <= closes) then
				local ahead = ent.RootPart.Position + forward * (soccer.SlideTackle.GetTravel(elapsed + step) - travelled)
				local offset = CFrame.lookAt(ahead, ahead + forward):PointToObjectSpace(localPosition + localVelocity * step) - center
				if math.abs(offset.X) <= size.X and math.abs(offset.Y) <= size.Y and math.abs(offset.Z) <= size.Z then
					return step
				end
			end
		end
	
		return nil
	end
	
	local function getTackler(localPosition, localVelocity)
		local now = workspace:GetServerTimeNow()
		local best, soonest
		for _, v in entitylib.AllPosition({
			Origin = localPosition,
			Range = Range.Value,
			Part = 'RootPart',
			Players = true,
			NPCs = true
		}) do
			local sliding = v.Character:GetAttribute('SlidingUntil')
			if sliding and sliding > now and not soccer.Ragdoll.IsLocallyRagdolled(v.Character) then
				local animator = AnimationCheck.Enabled and v.Humanoid:FindFirstChildOfClass('Animator') or nil
				local playing = animator == nil
				if animator then
					for _, v2 in animator:GetPlayingAnimationTracks() do
						if v2.Animation and v2.Animation.AnimationId == slideanimation then
							playing = true
							break
						end
					end
				end
	
				if playing then
					local elapsed = now - (sliding - soccer.SlideTackle.Constants.TotalMotionSeconds)
					local impact = Predict.Enabled and getImpact(v, elapsed, localPosition, localVelocity) or 0
					if impact and (not soonest or impact < soonest) then
						best, soonest = v, impact
					end
				end
			end
		end
	
		return best, soonest
	end
	
	local function getKicker(localPosition)
		local size = soccer.HitboxSettings.Kick.Size * 0.5
		local center = soccer.HitboxSettings.Kick.CFrameOffset.Position
		for _, v in entitylib.AllPosition({
			Origin = localPosition,
			Range = KickRange.Value,
			Part = 'RootPart',
			Players = true,
			NPCs = true
		}) do
			local animator = v.Humanoid:FindFirstChildOfClass('Animator')
			local forward = animator and soccer.AimFacing.GetFlatDirection(v.RootPart.CFrame.LookVector) or nil
			if forward then
				for _, v2 in animator:GetPlayingAnimationTracks() do
					local id = v2.Animation and v2.Animation.AnimationId
					local wound = kickanimations[id] and v2.Length > 0.01 and v2.TimePosition / v2.Length or 0
					if wound >= KickCharge.Value / 100 then
						local ahead = v.RootPart.Position + v.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.12
						local offset = CFrame.lookAt(ahead, ahead + forward):PointToObjectSpace(localPosition) - center
						if math.abs(offset.X) <= size.X + 1 and math.abs(offset.Y) <= size.Y + 1 and math.abs(offset.Z) <= size.Z + 1 then
							return v
						end
					end
				end
			end
		end
	
		return nil
	end
	
	AutoDribble = vape.Categories.Blatant:CreateModule({
		Name = 'AutoDribble',
		Function = function(callback)
			if callback then
				repeat task.wait()
					if not entitylib.isAlive or os.clock() < nextDribble then continue end
					if not soccer.Renderer.GetBallOwnedBy(lplr.UserId) or soccer.Dodge.IsDribbling(lplr.Character) then continue end
	
					local localPosition = entitylib.character.RootPart.Position
					local localVelocity = entitylib.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					local tackler, impact = getTackler(localPosition, localVelocity)
					if tackler then
						if Predict.Enabled and impact > Lead.Value + math.clamp(lplr:GetNetworkPing(), 0, 0.4) then continue end
					elseif not (KickCheck.Enabled and getKicker(localPosition)) then
						continue
					end
	
					local input = getInput('Dribble')
					if not input then continue end
	
					nextDribble = os.clock() + soccer.Dodge.Constants.CooldownSeconds + Delay:GetRandomValue()
					soccer.DodgeInput.HandleInputBegan(input, false)
				until not AutoDribble.Enabled
			else
				nextDribble = 0
				table.clear(slides)
			end
		end,
		Tooltip = 'Dribbles out of the way the moment an opponent slides at you.'
	})
	
	Range = AutoDribble:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 45,
		Default = 32,
		Tooltip = 'How far away a sliding opponent is watched from.'
	})
	Lead = AutoDribble:CreateSlider({
		Name = 'Lead',
		Min = 0.05,
		Max = 1,
		Default = 0.6,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'How long before their slide reaches you that you dribble. The dodge protects you for a full second, so there is no reason to leave this short.'
	})
	Predict = AutoDribble:CreateToggle({
		Name = 'Predict impact',
		Default = true,
		Tooltip = 'Only dribbles when their slide is actually going to land on you.'
	})
	KickCheck = AutoDribble:CreateToggle({
		Name = 'Kick check',
		Default = true,
		Tooltip = 'Also dribbles away from tackle kicks, spotting the kick wind up animation on an opponent lined up on you.'
	})
	KickRange = AutoDribble:CreateSlider({
		Name = 'Kick range',
		Min = 3,
		Max = 30,
		Default = 12,
		Tooltip = 'How close an opponent winding up a kick has to be before you dribble out.'
	})
	KickCharge = AutoDribble:CreateSlider({
		Name = 'Kick charge',
		Min = 0,
		Max = 100,
		Default = 45,
		Suffix = '%',
		Tooltip = 'How far into their kick wind up before it counts. A kick only knocks you fully at high charge, so this stops weak taps burning your dribble.'
	})
	FakeCheck = AutoDribble:CreateToggle({
		Name = 'Fake check',
		Default = true,
		Tooltip = 'Only spends your dribble when their slide can still connect, so a baited tackle cannot waste it.'
	})
	AnimationCheck = AutoDribble:CreateToggle({
		Name = 'Animation check',
		Default = true,
		Tooltip = 'Waits until the tackle animation is really playing on them.'
	})
	Delay = AutoDribble:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0,
		DefaultMax = 0.05,
		Decimal = 100
	})
end)

run(function()
	local AutoTackle
	local Targets
	local Range
	local Angle
	local Delay
	local BallCheck
	local DodgeCheck
	local SafeRange
	local Face
	
	local nextTackle = 0
	local dribbles = setmetatable({}, {__mode = 'k'})
	
	local function getAim()
		local moving = entitylib.character.Humanoid.MoveDirection * Vector3.new(1, 0, 1)
		if moving.Magnitude > 0.05 then
			return moving.Unit
		end
	
		local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		return look.Magnitude > 0.01 and look.Unit or soccer.SlideTackle.GetFlatForward(entitylib.character.RootPart)
	end
	
	local function getTarget(localPosition)
		local _, state = getBall()
		local aim, limit = getAim(), math.cos(math.rad(Angle.Value))
		local closest, distance = nil, math.huge
	
		for _, v in entitylib.AllPosition({
			Origin = localPosition,
			Range = Range.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled
		}) do
			if soccer.Dodge.IsDribbling(v.Character) then
				dribbles[v.Character] = os.clock()
			end
	
			local flat = (v.RootPart.Position - localPosition) * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.01 and flat.Unit:Dot(aim) < limit then continue end
	
			if not BallCheck.Enabled then
				return v, state
			end
	
			if v.Player and soccer.Renderer.GetBallOwnedBy(v.Player.UserId) then
				return v, state
			end
	
			if state and not v.Player then
				local magnitude = (v.RootPart.Position - state.Position).Magnitude
				if magnitude < distance and magnitude <= 8 then
					closest, distance = v, magnitude
				end
			end
		end
	
		return closest, state
	end
	
	local function getContact(target, localPosition)
		local velocity = target.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local ahead = -soccer.HitboxSettings.SlideTackle.CFrameOffset.Z
		local slack = soccer.HitboxSettings.SlideTackle.Size.X * 0.5
		for i = 0, 12 do
			local step = soccer.SlideTackle.Constants.HitboxDelaySeconds + i * 0.025
			local predicted = target.RootPart.Position + velocity * step
			local flat = (predicted - localPosition) * Vector3.new(1, 0, 1)
			if math.abs(flat.Magnitude - (soccer.SlideTackle.GetTravel(step) + ahead)) <= slack then
				return step, predicted
			end
		end
	
		return nil
	end
	
	AutoTackle = vape.Categories.Blatant:CreateModule({
		Name = 'AutoTackle',
		Function = function(callback)
			if callback then
				repeat task.wait()
					if not entitylib.isAlive or os.clock() < nextTackle then continue end
					if soccer.Renderer.GetBallOwnedBy(lplr.UserId) then continue end
	
					local localPosition = entitylib.character.RootPart.Position
					local target, state = getTarget(localPosition)
					if not target then continue end
					if BallCheck.Enabled and state and (state.Position - localPosition).Magnitude < (target.RootPart.Position - state.Position).Magnitude then continue end
					if soccer.Dodge.IsDribbling(target.Character) then continue end
	
					local last = dribbles[target.Character]
					if DodgeCheck.Enabled and (not last or os.clock() - last > soccer.Dodge.Constants.CooldownSeconds) and (target.RootPart.Position - localPosition).Magnitude > SafeRange.Value then continue end
	
					local _, predicted = getContact(target, localPosition)
					if not predicted then continue end
	
					local direction = (predicted - localPosition) * Vector3.new(1, 0, 1)
					local input = direction.Magnitude > 0.01 and getInput('Tackle') or nil
					if not input then continue end
	
					direction = direction.Unit
					if Face.Enabled then
						entitylib.character.RootPart.CFrame = CFrame.lookAt(localPosition, localPosition + direction)
					end
	
					entitylib.character.Humanoid:Move(direction, false)
					nextTackle = os.clock() + soccer.SlideTackle.Constants.CooldownSeconds + Delay:GetRandomValue()
					soccer.SlideTackleInput.HandleInputBegan(input, false)
				until not AutoTackle.Enabled
			else
				nextTackle = 0
				table.clear(dribbles)
			end
		end,
		Tooltip = 'Slide tackles opponents, waiting for the moment their dribble cannot save them.'
	})
	
	Targets = AutoTackle:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = AutoTackle:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 28,
		Default = 28,
		Tooltip = 'How far out opponents are considered. The slide only connects between 7.5 and 27.4 studs, so it holds fire outside that.'
	})
	Angle = AutoTackle:CreateSlider({
		Name = 'Angle',
		Min = 10,
		Max = 180,
		Default = 180,
		Suffix = 'degrees',
		Tooltip = 'How far off the way you are running an opponent can be before they are left alone. Measured from your camera while you stand still.'
	})
	Delay = AutoTackle:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0,
		DefaultMax = 0.15,
		Decimal = 100
	})
	BallCheck = AutoTackle:CreateToggle({
		Name = 'Ball check',
		Default = true,
		Tooltip = 'Only tackles the opponent who actually has the ball.'
	})
	DodgeCheck = AutoTackle:CreateToggle({
		Name = 'Dodge check',
		Default = true,
		Tooltip = 'Holds the tackle while their dribble is off cooldown, so they cannot dodge it.'
	})
	SafeRange = AutoTackle:CreateSlider({
		Name = 'Safe range',
		Min = 1,
		Max = 28,
		Default = 11,
		Tooltip = 'How close they must be before you tackle anyway with their dribble ready.'
	})
	Face = AutoTackle:CreateToggle({
		Name = 'Face target',
		Default = true,
		Tooltip = 'Also turns your body into the slide, which is what aims it when you are standing still.'
	})
end)

run(function()
	local BallHitbox
	local Range
	local Vertical
	local Airborne
	
	local flatMask = Vector3.new(1, 0, 1)
	local pullCooldown = 0.4
	local nextPull = 0
	
	BallHitbox = vape.Categories.Blatant:CreateModule({
		Name = 'BallHitbox',
		Function = function(callback)
			if callback then
				nextPull = 0
				BallHitbox:Clean(runService.PostSimulation:Connect(function()
					if not entitylib.isAlive or os.clock() < nextPull then return end
	
					local _, state = getBall()
					if not state or state.Mode == 'Resting' or soccer.Renderer.GetMainMatchOwnerUserId() then return end
					if not Airborne.Enabled and state.Mode == 'Airborne' then return end
	
					local character = entitylib.character.Character
					if soccer.Dodge.IsDribbling(character) then return end
					if (soccer.SlideTackle.GetSlidingUntil(character) or 0) > workspace:GetServerTimeNow() then return end
					if soccer.Ownership.IsWithinReceiveHitbox(character, state.Position) then return end
	
					local root = entitylib.character.RootPart
					local wanted = state.Position - soccer.HitboxSettings.Receive.CFrameOffset.Position - root.Position
					local move = Vertical.Enabled and wanted or (wanted * flatMask)
					if move.Magnitude < 0.05 or move.Magnitude > Range.Value then return end
	
					nextPull = os.clock() + pullCooldown
					root.CFrame += move
				end))
			end
		end,
		Tooltip = 'Pulls you onto a loose ball that lands just out of reach. The game decides who receives the ball on the server, so the only way to widen it is to be where the ball is.'
	})
	
	Range = BallHitbox:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 10,
		Tooltip = 'How far you will be pulled to reach the ball. Anything under 2.75 studs is already inside the real hitbox, and the further you set this the more it looks like a teleport.'
	})
	Airborne = BallHitbox:CreateToggle({
		Name = 'Airborne',
		Default = true,
		Tooltip = 'Also grabs balls that are still in the air rather than only ones rolling on the ground.'
	})
	Vertical = BallHitbox:CreateToggle({
		Name = 'Vertical',
		Tooltip = 'Lets it pull you up or down as well, so headers and drops count. Off by default because it looks like flying.'
	})
	
end)

run(function()
	local BallChanger
	local Skin
	
	local old
	local real = {}
	
	local function getNames(category)
		local names = {}
		local ok, folder = pcall(soccer.Catalog.GetFolder, category)
		if ok and folder then
			for _, v in folder:GetChildren() do
				if v.Name ~= soccer.Catalog.DefaultName then
					table.insert(names, v.Name)
				end
			end
		end
	
		table.sort(names)
		table.insert(names, 1, soccer.Catalog.DefaultName)
		return names
	end
	
	BallChanger = vape.Categories.Render:CreateModule({
		Name = 'BallChanger',
		Function = function(callback)
			if callback then
				old = old or soccer.Renderer.SetSkin
				soccer.Renderer.SetSkin = function(ballid, name, ...)
					real[ballid] = name
					if BallChanger.Enabled and Skin.Value ~= soccer.Catalog.DefaultName then
						return old(ballid, Skin.Value, ...)
					end
	
					return old(ballid, name, ...)
				end
	
				BallChanger:Clean(runService.Heartbeat:Connect(function()
					local ballid = soccer.Renderer.GetMatchBallId()
					if not ballid or soccer.Renderer.GetSkinName(ballid) == Skin.Value then return end
	
					soccer.Renderer.SetSkin(ballid, Skin.Value)
				end))
			elseif old then
				soccer.Renderer.SetSkin = old
				for ballid, name in real do
					pcall(old, ballid, name)
				end
				table.clear(real)
			end
		end,
		Tooltip = 'Puts any ball skin on the match ball. It is your own view of it, so nobody else sees the change.'
	})
	
	Skin = BallChanger:CreateDropdown({
		Name = 'Skin',
		List = getNames(soccer.Catalog.Categories.Balls),
		Tooltip = 'Which skin to wear. Every one the game ships is here whether you own it or not.'
	})
	
end)

run(function()
	local BallPredict
	local Box
	local BoundingBox
	local Nametag
	local Background
	local Arc
	local LandingSpot
	local KeeperThrow
	local Horizon
	local Points
	local Color
	
	local folder
	local parts = {}
	local landing
	local keeper
	local drawings = {}
	
	local function getThrow()
		local team = soccer.ActorTeams.GetActorTeamName(lplr)
		if not team then return nil end
	
		local thrower
		for _, v in entitylib.List do
			if v.Targetable and soccer.Carry.IsGoalkeeperCarry(v.Character) then
				thrower = v
				break
			end
		end
	
		if not thrower then return nil end
	
		local goal = getGoal(false)
		local best, bestscore
		for _, v in entitylib.List do
			if v.Targetable and v ~= thrower then
				local score = goal and -(goal.Position - v.RootPart.Position).Magnitude or -(thrower.RootPart.Position - v.RootPart.Position).Magnitude
				for _, v2 in entitylib.List do
					if not v2.Targetable then
						local offset = v2.RootPart.Position - thrower.RootPart.Position
						local lane = v.RootPart.Position - thrower.RootPart.Position
						if lane.Magnitude > 0.01 and (offset - lane.Unit * math.clamp(offset:Dot(lane.Unit), 0, lane.Magnitude)).Magnitude < 8 then
							score -= 60
						end
					end
				end
				if not bestscore or score > bestscore then
					best, bestscore = v, score
				end
			end
		end
	
		return best and best.RootPart.Position or nil
	end
	
	BallPredict = vape.Categories.Render:CreateModule({
		Name = 'BallPredict',
		Function = function(callback)
			if callback then
				folder = Instance.new('Folder')
				folder.Name = 'opmvapeballpredict'
				folder.Parent = workspace
	
				for i = 1, 40 do
					local part = Instance.new('Part')
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Material = Enum.Material.Neon
					part.Shape = Enum.PartType.Ball
					part.Size = Vector3.new(0.6, 0.6, 0.6)
					part.Transparency = 1
					part.Parent = folder
					parts[i] = part
				end
	
				landing = parts[1]:Clone()
				landing.Size = Vector3.new(3, 0.3, 3)
				landing.Shape = Enum.PartType.Cylinder
				landing.Parent = folder
				keeper = parts[1]:Clone()
				keeper.Size = Vector3.new(3.5, 3.5, 3.5)
				keeper.Parent = folder
	
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				drawings.Main = Drawing.new('Square')
				drawings.Main.Transparency = BoundingBox.Enabled and 1 or 0
				drawings.Main.ZIndex = 2
				drawings.Main.Filled = false
				drawings.Main.Thickness = 1
				drawings.Border = Drawing.new('Square')
				drawings.Border.Transparency = 0.35
				drawings.Border.ZIndex = 1
				drawings.Border.Thickness = 1
				drawings.Border.Filled = false
				drawings.Border.Color = Color3.new()
				drawings.Border2 = Drawing.new('Square')
				drawings.Border2.Transparency = 0.35
				drawings.Border2.ZIndex = 1
				drawings.Border2.Thickness = 1
				drawings.Border2.Filled = false
				drawings.Border2.Color = Color3.new()
				drawings.TextBKG = Drawing.new('Square')
				drawings.TextBKG.Transparency = 0.35
				drawings.TextBKG.ZIndex = 0
				drawings.TextBKG.Thickness = 1
				drawings.TextBKG.Filled = true
				drawings.TextBKG.Color = Color3.new()
				drawings.Drop = Drawing.new('Text')
				drawings.Drop.Color = Color3.new()
				drawings.Drop.ZIndex = 1
				drawings.Drop.Center = true
				drawings.Drop.Size = 20
				drawings.Text = Drawing.new('Text')
				drawings.Text.ZIndex = 2
				drawings.Text.Center = true
				drawings.Text.Size = 20
	
				BallPredict:Clean(runService.RenderStepped:Connect(function()
					local id, state = getBall()
					local shade = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					local spot = KeeperThrow.Enabled and getThrow() or nil
					keeper.Transparency = spot and 0.4 or 1
					keeper.Color = shade
					if spot then
						keeper.Position = spot + Vector3.new(0, 4, 0)
					end
	
					local ball = id and workspace.Misc.Visuals:FindFirstChild('ClientBall_' .. id) or nil
					if not state or not ball then
						landing.Transparency = 1
						for _, v in parts do
							v.Transparency = 1
						end
						for _, v in drawings do
							v.Visible = false
						end
						return
					end
	
					local rolling = state.Mode == 'Rolling' or state.Mode == 'Resting'
					local ground, drop
					for i, v in parts do
						local step = i * (Horizon.Value / #parts)
						local position = soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, step)
						v.Color = shade
						v.Position = position
						v.Transparency = Arc.Enabled and i <= Points.Value and 0.35 or 1
						if not ground and (rolling and i == #parts or (not rolling and position.Y <= state.Radius + 1.1)) then
							ground, drop = position, step
						end
					end
	
					landing.Color = shade
					landing.Transparency = ground and LandingSpot.Enabled and 0.3 or 1
					if ground then
						landing.CFrame = CFrame.new(ground.X, state.Radius + 0.2, ground.Z) * CFrame.Angles(0, 0, math.rad(90))
					end
	
					local ballPos, ballVis = gameCamera:WorldToViewportPoint(ball.Position)
					for _, v in drawings do
						v.Visible = ballVis
					end
					if not ballVis then return end
	
					local radius = ball.Size.X * 0.5 + 0.3
					local facing = CFrame.lookAlong(ball.Position, gameCamera.CFrame.LookVector)
					local topPos = gameCamera:WorldToViewportPoint((facing * CFrame.new(radius, radius, 0)).p)
					local bottomPos = gameCamera:WorldToViewportPoint((facing * CFrame.new(-radius, -radius, 0)).p)
					local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
					local posx, posy = ballPos.X - sizex / 2, ballPos.Y - sizey / 2
					drawings.Main.Visible = Box.Enabled
					drawings.Main.Color = shade
					drawings.Main.Transparency = BoundingBox.Enabled and 1 or 0
					drawings.Main.Position = Vector2.new(posx, posy) // 1
					drawings.Main.Size = Vector2.new(sizex, sizey) // 1
					drawings.Border.Visible = Box.Enabled and BoundingBox.Enabled
					drawings.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
					drawings.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
					drawings.Border2.Visible = drawings.Border.Visible
					drawings.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
					drawings.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
	
					local text = 'Ball'
					if ground then
						text = tostring(text) .. ' [' .. tostring(math.floor((ground - state.Position).Magnitude)) .. 'm]'
						if not rolling then
							text = tostring(text) .. ' ' .. tostring(string.format('%.1f', drop)) .. 's'
						end
					end
	
					drawings.Text.Visible = Nametag.Enabled
					drawings.Text.Color = shade
					drawings.Text.Text = text
					drawings.Text.Position = Vector2.new(ballPos.X, posy - 22) // 1
					drawings.Drop.Visible = Nametag.Enabled
					drawings.Drop.Text = text
					drawings.Drop.Position = drawings.Text.Position + Vector2.new(1, 1)
					drawings.TextBKG.Visible = Nametag.Enabled and Background.Enabled
					drawings.TextBKG.Size = drawings.Text.TextBounds + Vector2.new(8, 4)
					drawings.TextBKG.Position = drawings.Text.Position - Vector2.new(4 + (drawings.Text.TextBounds.X / 2), 0)
				end))
			else
				if folder then
					folder:Destroy()
					folder = nil
				end
				for _, v in drawings do
					v:Remove()
				end
				table.clear(drawings)
				table.clear(parts)
				landing, keeper = nil, nil
			end
		end,
		Tooltip = 'Boxes the ball and draws where it is going, where it lands and who the enemy keeper is about to throw to.'
	})
	
	Box = BallPredict:CreateToggle({
		Name = 'Box',
		Default = true,
		Tooltip = 'Draws a 2D box around the ball.'
	})
	BoundingBox = BallPredict:CreateToggle({
		Name = 'Bounding Box',
		Default = true,
		Tooltip = 'Outlines the box in black so it reads against the pitch.'
	})
	Nametag = BallPredict:CreateToggle({
		Name = 'Nametag',
		Default = true,
		Tooltip = 'Labels the ball with how far it travels and how long until it lands.'
	})
	Background = BallPredict:CreateToggle({
		Name = 'Show Background',
		Default = true,
		Tooltip = 'Fills a dark box behind the label.'
	})
	Arc = BallPredict:CreateToggle({
		Name = 'Arc',
		Default = true,
		Tooltip = 'Draws the balls flight path.'
	})
	LandingSpot = BallPredict:CreateToggle({
		Name = 'Landing',
		Default = true,
		Tooltip = 'Marks the spot the ball is going to land on.'
	})
	KeeperThrow = BallPredict:CreateToggle({
		Name = 'Keeper throw',
		Default = true,
		Tooltip = 'Marks the player the enemy keeper is most likely to throw to.'
	})
	Horizon = BallPredict:CreateSlider({
		Name = 'Horizon',
		Min = 0.5,
		Max = 6,
		Default = 3,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'How far ahead the flight is read.'
	})
	Points = BallPredict:CreateSlider({
		Name = 'Points',
		Min = 4,
		Max = 40,
		Default = 24,
		Tooltip = 'How many dots the path is drawn with.'
	})
	Color = BallPredict:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0.15
	})
end)

run(function()
	local GoalChanger
	local Effect
	local OwnTeam
	
	local old
	
	local function getNames(category)
		local names = {}
		local ok, folder = pcall(soccer.Catalog.GetFolder, category)
		if ok and folder then
			for _, v in folder:GetChildren() do
				if v.Name ~= soccer.Catalog.DefaultName then
					table.insert(names, v.Name)
				end
			end
		end
	
		table.sort(names)
		table.insert(names, 1, soccer.Catalog.DefaultName)
		return names
	end
	
	local function isOurs(goalpart)
		if not OwnTeam.Enabled then return true end
	
		local goal = getGoal(true)
		return goal ~= nil and goalpart ~= nil and (goalpart == goal or goalpart:IsDescendantOf(goal))
	end
	
	GoalChanger = vape.Categories.Render:CreateModule({
		Name = 'GoalChanger',
		Function = function(callback)
			if callback then
				old = old or soccer.GoalEffect.Play
				soccer.GoalEffect.Play = function(name, position, goalpart, ...)
					if GoalChanger.Enabled and Effect.Value ~= soccer.Catalog.DefaultName and isOurs(goalpart) then
						pcall(soccer.GoalEffect.Preload, {Effect.Value})
						return old(Effect.Value, position, goalpart, ...)
					end
	
					return old(name, position, goalpart, ...)
				end
			elseif old then
				soccer.GoalEffect.Play = old
			end
		end,
		Tooltip = 'Plays any goal effect when the net goes. It is your own view of it, so nobody else sees the change.'
	})
	
	Effect = GoalChanger:CreateDropdown({
		Name = 'Effect',
		List = getNames(soccer.Catalog.Categories.GoalEffects),
		Tooltip = 'Which effect to play. Every one the game ships is here whether you own it or not.'
	})
	OwnTeam = GoalChanger:CreateToggle({
		Name = 'Own team',
		Default = true,
		Tooltip = 'Only replaces the effect for goals your team scores, so the other side keeps theirs.'
	})
	
end)

run(function()
	local GoalESP
	local Box
	local Nametag
	local OwnGoal
	local Size
	local Opacity
	local Color
	
	local drawings = {}
	
	GoalESP = vape.Categories.Render:CreateModule({
		Name = 'GoalESP',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
	
				for i = 1, 2 do
					local set = {}
					set.Main = Drawing.new('Square')
					set.Main.Thickness = 1
					set.Main.Filled = false
					set.Main.ZIndex = 2
					set.Drop = Drawing.new('Text')
					set.Drop.Color = Color3.new()
					set.Drop.ZIndex = 1
					set.Drop.Center = true
					set.Drop.Size = 16
					set.Text = Drawing.new('Text')
					set.Text.ZIndex = 2
					set.Text.Center = true
					set.Text.Size = 16
					drawings[i] = set
				end
	
				GoalESP:Clean(runService.RenderStepped:Connect(function()
					local shade = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					for i, v in {{Goal = getGoal(true), Label = 'Goal'}, {Goal = OwnGoal.Enabled and getGoal(false) or nil, Label = 'Your Goal'}} do
						local set = drawings[i]
						local center, visible
						if v.Goal then
							center, visible = gameCamera:WorldToViewportPoint(v.Goal.Position)
						end
						if not visible then
							for _, v2 in set do
								v2.Visible = false
							end
							continue
						end
	
						local facing = CFrame.lookAlong(v.Goal.Position, gameCamera.CFrame.LookVector)
						local topPos = gameCamera:WorldToViewportPoint((facing * CFrame.new(Size.Value, Size.Value, 0)).p)
						local bottomPos = gameCamera:WorldToViewportPoint((facing * CFrame.new(-Size.Value, -Size.Value, 0)).p)
						local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
						set.Main.Visible = Box.Enabled
						set.Main.Color = shade
						set.Main.Transparency = Opacity.Value / 100
						set.Main.Position = Vector2.new(center.X - sizex / 2, center.Y - sizey / 2) // 1
						set.Main.Size = Vector2.new(sizex, sizey) // 1
	
						local text = v.Label
						if entitylib.isAlive then
							text = tostring(text) .. ' [' .. tostring(math.floor((v.Goal.Position - entitylib.character.RootPart.Position).Magnitude)) .. 'm]'
						end
	
						set.Text.Visible = Nametag.Enabled
						set.Text.Color = shade
						set.Text.Transparency = Opacity.Value / 100
						set.Text.Text = text
						set.Text.Position = Vector2.new(center.X, center.Y - sizey / 2 - 18) // 1
						set.Drop.Visible = Nametag.Enabled
						set.Drop.Transparency = Opacity.Value / 100
						set.Drop.Text = text
						set.Drop.Position = set.Text.Position + Vector2.new(1, 1)
					end
				end))
			else
				for _, v in drawings do
					for _, v2 in v do
						v2:Remove()
					end
				end
				table.clear(drawings)
			end
		end,
		Tooltip = 'Marks the middle of the goal so you always know where you are shooting.'
	})
	
	Box = GoalESP:CreateToggle({
		Name = 'Box',
		Default = true,
		Tooltip = 'Draws a small box on the middle of the goal.'
	})
	Nametag = GoalESP:CreateToggle({
		Name = 'Nametag',
		Default = true,
		Tooltip = 'Labels the middle of the goal with its distance.'
	})
	OwnGoal = GoalESP:CreateToggle({
		Name = 'Own goal',
		Tooltip = 'Marks the goal you are defending as well as the one you are attacking.'
	})
	Size = GoalESP:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 18,
		Default = 3,
		Tooltip = 'How big the marker on the goal is, in studs.'
	})
	Opacity = GoalESP:CreateSlider({
		Name = 'Opacity',
		Min = 5,
		Max = 100,
		Default = 45,
		Suffix = '%',
		Tooltip = 'How strong the marker is drawn, keep it low to stay subtle.'
	})
	Color = GoalESP:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0.33
	})
end)

run(function()
	local AutoCatch
	local Charge
	local ChargeLead
	local OwnKicks
	local Range
	local Horizon
	local Jump
	
	local charged = false
	local held
	local nextCharge = 0
	local oldbegan, oldkick
	local hookbegan, hookkick
	
	local function getArrival(state, localPosition, walkspeed)
		local reach = soccer.HitboxSettings.Receive.Size.Z * 0.5
		for i = 0, 40 do
			local step = i * 0.05
			local position = soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, step)
			if ((position - localPosition) * Vector3.new(1, 0, 1)).Magnitude <= walkspeed * step + reach then
				return step
			end
		end
	
		return nil
	end
	
	AutoCatch = vape.Categories.Utility:CreateModule({
		Name = 'AutoCatch',
		Function = function(callback)
			if callback then
				oldbegan = oldbegan or soccer.ShootInput.HandleInputBegan
				hookbegan = function(input, ...)
					if charged and not held and typeof(input) == 'Instance' and soccer.Controls.IsInput('Kick', input) then
						held = os.clock()
					end
					return oldbegan(input, ...)
				end
				soccer.ShootInput.HandleInputBegan = hookbegan
	
				oldkick = oldkick or soccer.ActionCommands.Kick
				hookkick = function(...)
					local call = oldkick(...)
					if charged and held and call.ChargeSeconds then
						call.ChargeSeconds = math.clamp(os.clock() - held, soccer.KickCore.Constants.MinimumChargeSeconds, call.MaximumChargeSeconds or soccer.KickCore.Constants.MaximumChargeSeconds)
					end
					return call
				end
				soccer.ActionCommands.Kick = hookkick
	
				AutoCatch:Clean(runService.PostSimulation:Connect(function()
					if charged and not soccer.ShootInput.IsCharging() then
						charged, held = false, nil
					end
					if not entitylib.isAlive then return end
	
					local _, state = getBall()
					if not state or soccer.Renderer.GetMainMatchOwnerUserId() or soccer.Ownership.IsWithinReceiveHitbox(entitylib.character.Character, state.Position) then return end
					if not OwnKicks.Enabled and state.LastKickerUserId == lplr.UserId and workspace:GetServerTimeNow() - (state.FlightStartedAt or 0) < 1.5 then return end
	
					local step, position, needsjump = getIntercept(state, Horizon.Value, Range.Value)
					if not position then return end
	
					local hum = entitylib.character.Humanoid
					local localPosition = entitylib.character.RootPart.Position
					local flat = (position - localPosition) * Vector3.new(1, 0, 1)
					if flat.Magnitude > 1 then
						hum:Move(flat.Unit, false)
					end
	
					if needsjump and Jump.Enabled and hum.FloorMaterial ~= Enum.Material.Air and step <= math.sqrt(2 * hum.JumpHeight / workspace.Gravity) then
						hum.Jump = true
					end
	
					local lead = step or getArrival(state, localPosition, hum.WalkSpeed)
					if not Charge.Enabled or not lead or lead > ChargeLead.Value then return end
	
					local look = (state.Position - localPosition) * Vector3.new(1, 0, 1)
					if look.Magnitude > 0.01 then
						entitylib.character.RootPart.CFrame = CFrame.lookAt(localPosition, localPosition + look.Unit)
					end
	
					if charged or soccer.ShootInput.IsCharging() or os.clock() < nextCharge then return end
	
					local input = getInput('Kick')
					if not input then return end
	
					charged, nextCharge = true, os.clock() + 0.25
					soccer.ShootInput.HandleInputBegan(input, false)
				end))
			else
				if soccer.ShootInput.HandleInputBegan == hookbegan then
					soccer.ShootInput.HandleInputBegan = oldbegan
				end
				if soccer.ActionCommands.Kick == hookkick then
					soccer.ActionCommands.Kick = oldkick
				end
				if charged and not held then
					soccer.ShootInput.CancelCharge()
				end
				charged, held, nextCharge = false, nil, 0
			end
		end,
		Tooltip = 'Reads where the ball is going, walks onto it and winds a kick up so it is ready the moment it reaches you.'
	})
	
	Charge = AutoCatch:CreateToggle({
		Name = 'Charge',
		Default = true,
		Tooltip = 'Turns you onto the ball and winds a kick up as it arrives, then holds it. The power is still yours, counted from the moment you hold kick yourself.'
	})
	ChargeLead = AutoCatch:CreateSlider({
		Name = 'Charge lead',
		Min = 0.05,
		Max = 1.2,
		Default = 0.4,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'How long before the ball reaches you that the kick starts winding up.'
	})
	OwnKicks = AutoCatch:CreateToggle({
		Name = 'Own kicks',
		Tooltip = 'Also chases balls you kicked yourself, off by default so it stops eating your own passes and shots.'
	})
	Range = AutoCatch:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 90,
		Default = 45,
		Tooltip = 'How far you will run to meet the ball.'
	})
	Horizon = AutoCatch:CreateSlider({
		Name = 'Horizon',
		Min = 0.5,
		Max = 5,
		Default = 2.5,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'How far ahead the balls flight is read.'
	})
	Jump = AutoCatch:CreateToggle({
		Name = 'Jump',
		Default = true,
		Tooltip = 'Jumps at the right moment for balls above your reach.'
	})
end)

run(function()
	local AutoGoalkeeper
	local Lead
	local Margin
	local Punch
	local PunchRange
	local Positioning
	local Follow
	local Jump
	local Rush
	local RushRange
	local Delay
	
	local nextDive = 0
	local nextPunch = 0
	local nextTackle = 0
	local diveName
	local punching, punchstart
	local old
	
	local function getCrossing(state, goal)
		if -state.Velocity:Dot(goal.CFrame.LookVector) < 10 then return nil end
	
		local half = goal.Size * 0.5
		for i = 1, 60 do
			local step = i * 0.025
			local position = soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, step)
			local offset = goal.CFrame:PointToObjectSpace(position)
			if math.abs(offset.X) <= half.X + Margin.Value and offset.Y <= half.Y and offset.Y >= -half.Y - 4 and math.abs(offset.Z) <= half.Z + 8 then
				return step, position
			end
		end
	
		return nil
	end
	
	local function getContact(target, localPosition)
		local velocity = target.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local ahead = -soccer.HitboxSettings.SlideTackle.CFrameOffset.Z
		local slack = soccer.HitboxSettings.SlideTackle.Size.X * 0.5
		for i = 0, 12 do
			local step = soccer.SlideTackle.Constants.HitboxDelaySeconds + i * 0.025
			local predicted = target.RootPart.Position + velocity * step
			local flat = (predicted - localPosition) * Vector3.new(1, 0, 1)
			if math.abs(flat.Magnitude - (soccer.SlideTackle.GetTravel(step) + ahead)) <= slack then
				return step, predicted
			end
		end
	
		return nil
	end
	
	local function isKeeping(goal)
		if soccer.GoalkeeperRole.IsGoalkeeper() then return true end
	
		local zone = goal.Parent:FindFirstChild('Goalkeeper')
		if not zone then return false end
	
		local offset = zone.CFrame:PointToObjectSpace(entitylib.character.RootPart.Position)
		return math.abs(offset.X) <= zone.Size.X * 0.5 and math.abs(offset.Z) <= zone.Size.Z * 0.5
	end
	
	local function getAimed(state, goal)
		for _, v in entitylib.List do
			local carried = v.Targetable and soccer.Carry.GetOwnedPosition(v.Character) or nil
			if carried and (state.Position - carried).Magnitude < 2.5 then
				local forward = soccer.AimFacing.GetFlatDirection(v.RootPart.CFrame.LookVector)
				local facing = forward and forward:Dot(goal.CFrame.LookVector) or 0
				if facing >= -0.05 then return nil end
	
				return v.RootPart.Position + forward * ((goal.Position - v.RootPart.Position):Dot(goal.CFrame.LookVector) / facing)
			end
		end
	
		return nil
	end
	
	AutoGoalkeeper = vape.Categories.Utility:CreateModule({
		Name = 'AutoGoalkeeper',
		Function = function(callback)
			if callback then
				old = old or soccer.GoalkeeperDive.GetDirectionChoice
				soccer.GoalkeeperDive.GetDirectionChoice = function(moveDirection, cameraCFrame, forward)
					if diveName then
						return soccer.GoalkeeperDive.GetDirectionChoiceByName(diveName)
					end
					return old(moveDirection, cameraCFrame, forward)
				end
	
				AutoGoalkeeper:Clean(runService.PostSimulation:Connect(function()
					if not entitylib.isAlive then return end
	
					local goal = getGoal(false)
					local _, state = getBall()
					if not goal or not state or not isKeeping(goal) then return end
					if soccer.Renderer.GetBallOwnedBy(lplr.UserId) then
						if punching then
							soccer.ShootInput.HandleInputEnded(punching, false)
							punching = nil
						end
						return
					end
	
					local hum = entitylib.character.Humanoid
					local localPosition = entitylib.character.RootPart.Position
					local owner, carried
					for _, v in entitylib.List do
						local held = soccer.Carry.GetOwnedPosition(v.Character)
						if held and (state.Position - held).Magnitude < 2.5 then
							owner, carried = v, held
							break
						end
					end
	
					local step, landing
					if not owner then
						step, landing = getCrossing(state, goal)
					end
	
					if owner and owner.Targetable and Rush.Enabled and ((carried - goal.Position) * Vector3.new(1, 0, 1)).Magnitude <= RushRange.Value then
						if punching then
							soccer.ShootInput.HandleInputEnded(punching, false)
							punching = nil
						end
	
						local chase = (carried - localPosition) * Vector3.new(1, 0, 1)
						local _, predicted = getContact(owner, localPosition)
						local input = predicted and os.clock() >= nextTackle and not soccer.Dodge.IsDribbling(owner.Character) and getInput('Tackle') or nil
						local direction = input and (predicted - localPosition) * Vector3.new(1, 0, 1) or nil
						if direction and direction.Magnitude > 0.01 then
							direction = direction.Unit
							entitylib.character.RootPart.CFrame = CFrame.lookAt(localPosition, localPosition + direction)
							hum:Move(direction, false)
							nextTackle = os.clock() + soccer.SlideTackle.Constants.CooldownSeconds + Delay:GetRandomValue()
							soccer.SlideTackleInput.HandleInputBegan(input, false)
						elseif chase.Magnitude > 1 then
							hum:Move(chase.Unit, false)
						end
						return
					end
	
					if not step then
						if punching then
							soccer.ShootInput.HandleInputEnded(punching, false)
							punching = nil
						end
	
						if Positioning.Enabled then
							local target = Follow.Enabled and getAimed(state, goal) or soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, 0.35)
							local reach = math.clamp(goal.CFrame.RightVector:Dot(target - goal.Position), -(goal.Size.X * 0.5), goal.Size.X * 0.5)
							local stand = goal.Position + goal.CFrame.RightVector * reach + goal.CFrame.LookVector * (goal.Size.Z * 0.5 + 4)
							local move = Vector3.new(stand.X, localPosition.Y, stand.Z) - localPosition
							if move.Magnitude > 1.5 then
								hum:Move(move.Unit, false)
							end
						end
						return
					end
	
					local crossing = soccer.GoalkeeperPrediction.GetPlaneTime(state, localPosition, goal.CFrame.LookVector, 0)
					local aim = crossing and soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, crossing) or landing
					if crossing then
						step = crossing
					end
	
					local lateral = goal.CFrame.RightVector:Dot(aim - localPosition)
					local standing = soccer.HitboxSettings.Receive.Size.Y * 0.5
					local rise = aim.Y - localPosition.Y
	
					if Jump.Enabled and rise > standing and math.abs(lateral) <= soccer.HitboxSettings.AirReceive.Size.X * 0.5 and hum.FloorMaterial ~= Enum.Material.Air and step <= math.sqrt(2 * hum.JumpHeight / workspace.Gravity) then
						hum.Jump = true
					end
	
					if Punch.Enabled and math.abs(lateral) <= PunchRange.Value then
						local move = (aim - localPosition) * Vector3.new(1, 0, 1)
						if move.Magnitude > 1 then
							hum:Move(move.Unit, false)
						end
	
						if not punching and step <= 0.35 and os.clock() >= nextPunch then
							punching = getInput('Kick')
							if punching then
								punchstart = os.clock()
								soccer.ShootInput.HandleInputBegan(punching, false)
							end
						end
	
						if punching and os.clock() - punchstart >= soccer.KickCore.Constants.MinimumChargeSeconds and (step <= 0.05 or soccer.Ownership.IsWithinReceiveHitbox(entitylib.character.Character, state.Position)) then
							soccer.ShootInput.HandleInputEnded(punching, false)
							punching = nil
							nextPunch = os.clock() + soccer.Kick.Constants.CooldownSeconds
							nextDive = os.clock() + 0.5
						end
						return
					end
	
					if Positioning.Enabled then
						local reach = math.clamp(goal.CFrame.RightVector:Dot(aim - goal.Position), -(goal.Size.X * 0.5), goal.Size.X * 0.5)
						local stand = goal.Position + goal.CFrame.RightVector * reach + goal.CFrame.LookVector * (goal.Size.Z * 0.5 + 4)
						local move = Vector3.new(stand.X, localPosition.Y, stand.Z) - localPosition
						if move.Magnitude > 1.5 then
							hum:Move(move.Unit, false)
						end
					end
	
					if os.clock() < nextDive or not soccer.GoalkeeperRole.IsGoalkeeper() then return end
					if math.abs(lateral) <= soccer.HitboxSettings.Receive.Size.X * 0.5 then return end
	
					local needed = soccer.GoalkeeperDive.Constants.DurationSeconds
					for i = 1, 60 do
						local reach = i * 0.015
						if soccer.GoalkeeperDive.GetTravel(reach) >= math.abs(lateral) then
							needed = reach
							break
						end
					end
					if step > math.min(needed + 0.06, Lead.Value) then return end
	
					local wanted = goal.CFrame.RightVector * lateral
					if wanted.Magnitude < 0.01 then return end
	
					wanted = wanted.Unit
					local forward = soccer.AimFacing.GetFlatDirection(gameCamera.CFrame.LookVector) or Vector3.new(0, 0, 1)
					diveName = soccer.ActionMotion.GetDirectionName(wanted:Dot(forward), wanted:Dot(Vector3.new(-forward.Z, 0, forward.X)))
					nextDive = os.clock() + soccer.GoalkeeperDive.Constants.RepeatDelaySeconds + Delay:GetRandomValue()
					soccer.GoalkeeperRole.Dive()
					diveName = nil
				end))
			else
				soccer.GoalkeeperDive.GetDirectionChoice = old
				if punching then
					soccer.ShootInput.HandleInputEnded(punching, false)
					punching = nil
				end
				nextDive = 0
				nextPunch = 0
				diveName = nil
			end
		end,
		Tooltip = 'Keeps goal whenever you are in your own keeper zone, punching the shots you can reach and diving for the rest.'
	})
	
	Lead = AutoGoalkeeper:CreateSlider({
		Name = 'Lead',
		Min = 0.05,
		Max = 1.5,
		Default = 0.45,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Caps how early you commit. The dive itself is timed off how far it has to travel.'
	})
	Margin = AutoGoalkeeper:CreateSlider({
		Name = 'Margin',
		Min = 0,
		Max = 15,
		Default = 5,
		Tooltip = 'How far outside the posts a shot can be before you stop going for it, width only.'
	})
	Punch = AutoGoalkeeper:CreateToggle({
		Name = 'Punch',
		Default = true,
		Tooltip = 'Walks into shots close enough to reach and punches them clear instead of diving.'
	})
	PunchRange = AutoGoalkeeper:CreateSlider({
		Name = 'Punch range',
		Min = 1,
		Max = 20,
		Default = 7,
		Tooltip = 'How far to the side a shot can be and still be walked into rather than dived at.'
	})
	Positioning = AutoGoalkeeper:CreateToggle({
		Name = 'Positioning',
		Default = true,
		Tooltip = 'Walks you along your line to stay in front of the ball.'
	})
	Follow = AutoGoalkeeper:CreateToggle({
		Name = 'Follow',
		Default = true,
		Tooltip = 'Reads which part of the goal the player on the ball is lined up on and holds your line there before they shoot.'
	})
	Jump = AutoGoalkeeper:CreateToggle({
		Name = 'Jump',
		Default = true,
		Tooltip = 'Jumps for balls going in above your standing reach. A dive only lifts you 1.6 studs, so straight high shots cannot be dived at all.'
	})
	Rush = AutoGoalkeeper:CreateToggle({
		Name = 'Rush',
		Default = true,
		Tooltip = 'Comes off your line at an opponent dribbling the ball in and slide tackles it off them, instead of standing there while they walk it into the net.'
	})
	RushRange = AutoGoalkeeper:CreateSlider({
		Name = 'Rush range',
		Min = 5,
		Max = 60,
		Default = 30,
		Tooltip = 'How close to your goal a carrier has to get before you leave your line for them.'
	})
	Delay = AutoGoalkeeper:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0,
		DefaultMax = 0.1,
		Decimal = 100
	})
end)

run(function()
	local AutoPass
	local OnRequest
	local Range
	local Safety
	local Window
	local FreeAim
	local Delay
	
	local flatMask = Vector3.new(1, 0, 1)
	local samples = 16
	local requests = {}
	local curves = {}
	local nextPass = 0
	local passpoint
	local assisted
	local old, oldaim
	
	local function simulate(alpha, lob, carry)
		local settings = lob and soccer.Pass.Constants.Lob or soccer.Pass.Constants.Ground
		local kind = lob and soccer.KickCore.LaunchKinds.Lob or soccer.KickCore.LaunchKinds.Pass
		local multiplier = soccer.KickCore.GetLaunchMultiplier(kind) or 1
		local speed = (settings.MinimumSpeed + (settings.MaximumSpeed - settings.MinimumSpeed) * alpha ^ soccer.KickCore.Constants.PowerCurve) * multiplier
		local rise = lob and (settings.MinimumUpwardSpeed + (settings.MaximumUpwardSpeed - settings.MinimumUpwardSpeed) * math.sqrt(alpha)) * multiplier or speed * math.tan(math.rad(settings.LaunchAngleDegrees))
	
		local state = {Mode = 'Airborne', Position = Vector3.new(0, 0, 0), Velocity = Vector3.new(0, rise, math.max(speed + carry, 1)), Spin = Vector3.new(0, 0, 0), Radius = 1}
		local previous = Vector3.new(0, 0, 0)
		for i = 1, 140 do
			local step = i * 0.02
			local position = soccer.GoalkeeperPrediction.GetBallPositionAtTime(state, step)
			if position.Y <= 0 then
				local fall = previous.Y - position.Y
				local ratio = fall > 0.001 and previous.Y / fall or 0
				return (previous * flatMask).Magnitude + ((position - previous) * flatMask).Magnitude * ratio, step - 0.02 * (1 - ratio)
			end
			previous = position
		end
	
		return (previous * flatMask).Magnitude, 2.8
	end
	
	local function getCurve(lob, carry)
		local kind = lob and soccer.KickCore.LaunchKinds.Lob or soccer.KickCore.LaunchKinds.Pass
		local bucket = math.round(carry * 0.5)
		local key = kind..bucket..'_'..(soccer.KickCore.GetLaunchMultiplier(kind) or 1)
		local curve = curves[key]
		if curve then return curve end
	
		curve = table.create(samples + 1)
		for i = 0, samples do
			local reach, flight = simulate(i / samples, lob, bucket * 2)
			curve[i + 1] = {Reach = reach, Flight = flight}
		end
		curves[key] = curve
	
		return curve
	end
	
	local function getPower(distance, lob, carry)
		local curve = getCurve(lob, carry)
		local top = curve[samples + 1]
		if distance >= top.Reach then
			return 1, top.Flight, top.Reach
		end
		if distance <= curve[1].Reach then
			return 0, curve[1].Flight, curve[1].Reach
		end
	
		for i = 2, samples + 1 do
			local point = curve[i]
			if point.Reach >= distance then
				local previous = curve[i - 1]
				local span = point.Reach - previous.Reach
				local ratio = span > 0.001 and (distance - previous.Reach) / span or 0
				return (i - 2 + ratio) / samples, previous.Flight + (point.Flight - previous.Flight) * ratio, distance
			end
		end
	
		return 1, top.Flight, top.Reach
	end
	
	local function getHorizon(flight)
		return flight + math.clamp(lplr:GetNetworkPing(), 0, 0.4)
	end
	
	local function getLead(origin, entity, speed, horizon)
		local root = entity.RootPart
		local position = root.Position
		if speed <= 0.01 or horizon <= 0.01 then return position end
	
		local velocity = root.AssemblyLinearVelocity
		local _, impact, travel = prediction.SolveTrajectory(origin, speed, 0, position, velocity, workspace.Gravity, entity.HipHeight, nil, nil, math.abs(velocity.Y) > 0.01, position, root, nil, true)
		if not impact or not travel or travel <= 0.01 then return position end
	
		local reached = prediction.getLatency() + travel
		local scaled = position + (impact - position) * (reached > 0.01 and horizon / reached or 1)
	
		return Vector3.new(scaled.X, position.Y, scaled.Z)
	end
	
	local function solveMode(origin, entity, lob, inherited)
		local target = entity.RootPart.Position
		local alpha, flight, reach, speed
		for i = 1, 4 do
			local offset = (target - origin) * flatMask
			local distance = offset.Magnitude
			alpha, flight, reach = getPower(distance, lob, distance > 0.01 and inherited:Dot(offset.Unit) or 0)
			speed = flight > 0.01 and reach / flight or 0
			if i == 4 then break end
	
			local lead = getLead(origin, entity, speed, getHorizon(flight))
			local settled = (lead - target).Magnitude < 0.25
			target = lead
			if settled then break end
		end
	
		return target, alpha, flight, reach, speed
	end
	
	local function getSolution(origin, entity, blocked, inherited)
		local straight = ((entity.RootPart.Position - origin) * flatMask).Magnitude
		local lob = straight > getCurve(false, 0)[samples + 1].Reach or (blocked and straight >= getCurve(true, 0)[1].Reach)
		local target, alpha, flight, reach, speed = solveMode(origin, entity, lob, inherited)
		if not lob and ((target - origin) * flatMask).Magnitude > reach then
			lob = true
			target, alpha, flight, reach, speed = solveMode(origin, entity, true, inherited)
		end
	
		return target, lob, alpha, reach, speed, flight
	end
	
	local function isClear(from, to)
		local direction = to - from
		local length = direction.Magnitude
		if length < 0.01 then return false end
	
		direction = direction.Unit
		for _, v in entitylib.List do
			if v.Targetable then
				local offset = v.RootPart.Position - from
				if (offset - direction * math.clamp(offset:Dot(direction), 0, length)).Magnitude < Safety.Value then
					return false
				end
			end
		end
	
		return true
	end
	
	local function getTarget(origin)
		local team = soccer.ActorTeams.GetActorTeamName(lplr)
		if not team then return nil end
	
		local goal = getGoal(true)
		local zone = goal and goal.Parent:FindFirstChild('Goalkeeper') or nil
		local inherited = soccer.KickCore.GetInheritedVelocity(entitylib.character.Character) * flatMask
		local best, bestscore
		for _, v in entitylib.List do
			if not v.Targetable and soccer.ActorTeams.GetCharacterTeamName(v.Character) == team then
				local resting = v.RootPart.Position
				local target, lob, alpha, reach, speed, flight = getSolution(origin, v, not isClear(origin, resting), inherited)
				local distance = ((target - origin) * flatMask).Magnitude
				local asked = v.Player and requests[v.Player.UserId] and os.clock() - requests[v.Player.UserId] <= Window.Value
				if distance <= Range.Value and distance >= 8 and (asked or not OnRequest.Enabled) and (lob or isClear(origin, target)) then
					local score = (asked and 120 or 0) - distance * 0.2 - math.max(distance - reach, 0) * 4
					if goal then
						score += (goal.Position - origin).Magnitude - (goal.Position - target).Magnitude
					end
					local offset = zone and zone.CFrame:PointToObjectSpace(target) or nil
					if offset and math.abs(offset.X) <= zone.Size.X * 0.5 and math.abs(offset.Z) <= zone.Size.Z * 0.5 then
						score += 200
					end
					if not bestscore or score > bestscore then
						best, bestscore = {Entity = v, Point = target, Lob = lob, Alpha = alpha, Speed = speed, Flight = flight}, score
					end
				end
			end
		end
	
		return best
	end
	
	local function getDirection()
		local origin = getOwnedPosition()
		local wanted = origin and (passpoint - origin) * flatMask or nil
		if not wanted or wanted.Magnitude < 0.01 then return nil end
	
		return wanted.Unit
	end
	
	AutoPass = vape.Categories.Utility:CreateModule({
		Name = 'AutoPass',
		Function = function(callback)
			if callback then
				if FreeAim.Enabled then
					assisted = soccer.PlayerSettings.GetLocal(soccer.PlayerSettings.Names.AssistedPasses)
					soccer.PlayerSettings.SetLocal(soccer.PlayerSettings.Names.AssistedPasses, false)
				end
	
				old = old or soccer.Reticle.GetCameraRay
				soccer.Reticle.GetCameraRay = function(...)
					local call = old(...)
					if not passpoint then return call end
	
					local wanted = getDirection()
					if not wanted then return call end
	
					return Ray.new(call.Origin, wanted * call.Direction.Magnitude)
				end
	
				oldaim = oldaim or soccer.Reticle.GetCameraAimRayWithoutHit
				soccer.Reticle.GetCameraAimRayWithoutHit = function(...)
					local call = oldaim(...)
					if not passpoint or typeof(call) ~= 'table' or not call.Direction then return call end
	
					local wanted = getDirection()
					if not wanted then return call end
	
					call.Direction = wanted
					if typeof(call.CameraCFrame) == 'CFrame' then
						call.CameraCFrame = CFrame.lookAt(call.CameraCFrame.Position, call.CameraCFrame.Position + wanted)
					end
	
					return call
				end
	
				AutoPass:Clean(replicatedStorage.Remotes.Ball.CallForPassEffect.OnClientEvent:Connect(function(userid)
					requests[userid] = os.clock()
				end))
	
				repeat task.wait()
					if not entitylib.isAlive or os.clock() < nextPass then continue end
					if not soccer.Renderer.GetBallOwnedBy(lplr.UserId) then continue end
	
					local origin = getOwnedPosition()
					local solution = origin and getTarget(origin) or nil
					local input = solution and getInput(solution.Lob and 'Lob' or 'Pass') or nil
					if not input then continue end
	
					local passtype = solution.Lob and soccer.ActionCommands.PassTypes.FreeLobPass or soccer.ActionCommands.PassTypes.FreeLowPass
					local release = os.clock() + soccer.Pass.GetChargeSecondsFromAlpha(solution.Alpha, entitylib.character.Character, passtype)
					passpoint = solution.Point
					soccer.PassInput.HandleInputBegan(input, false)
	
					repeat task.wait()
						if not entitylib.isAlive or not solution.Entity.RootPart.Parent then break end
	
						local moved = getOwnedPosition()
						passpoint = moved and getLead(moved, solution.Entity, solution.Speed, getHorizon(solution.Flight)) or passpoint
					until os.clock() >= release
	
					soccer.PassInput.HandleInputEnded(input, false)
					passpoint = nil
					nextPass = os.clock() + Delay:GetRandomValue()
				until not AutoPass.Enabled
			else
				if assisted ~= nil then
					soccer.PlayerSettings.SetLocal(soccer.PlayerSettings.Names.AssistedPasses, assisted)
					assisted = nil
				end
	
				soccer.Reticle.GetCameraRay = old
				soccer.Reticle.GetCameraAimRayWithoutHit = oldaim
				passpoint = nil
				nextPass = 0
				table.clear(requests)
				table.clear(curves)
			end
		end,
		Tooltip = 'Passes to the best placed teammate, lobbing over anyone in the way and weighting the pass for the distance.'
	})
	
	OnRequest = AutoPass:CreateToggle({
		Name = 'Only on request',
		Default = true,
		Tooltip = 'Only passes when a teammate actually calls for it.'
	})
	Range = AutoPass:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 160,
		Default = 90,
		Tooltip = 'How far away a teammate can be to get the ball.'
	})
	Safety = AutoPass:CreateSlider({
		Name = 'Safety',
		Min = 1,
		Max = 25,
		Default = 8,
		Tooltip = 'How close an opponent may get to the pass before the lane counts as blocked and it lobs instead.'
	})
	Window = AutoPass:CreateSlider({
		Name = 'Request window',
		Min = 0.5,
		Max = 8,
		Default = 3,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'How long a teammates call for the ball stays worth answering.'
	})
	FreeAim = AutoPass:CreateToggle({
		Name = 'Free aim',
		Default = true,
		Tooltip = 'Turns the games own pass assist off while this runs. The assist aims at where your teammate is standing and throws the lead away, so leave this on.'
	})
	Delay = AutoPass:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.25,
		Decimal = 100
	})
	
end)

run(function()
	local AutoPowerup
	local OwnBall
	local AutoJump
	local ChargeLead
	local Horizon
	
	local charged
	
	AutoPowerup = vape.Categories.Utility:CreateModule({
		Name = 'AutoPowerup',
		Function = function(callback)
			if callback then
				AutoPowerup:Clean(runService.PostSimulation:Connect(function()
					if not entitylib.isAlive then
						charged = false
						return
					end
	
					local _, state = getBall()
					if not state or state.Mode == 'Resting' or state.Mode == 'Rolling' then
						charged = false
						return
					end
	
					if OwnBall.Enabled and state.LastKickerUserId ~= lplr.UserId then return end
	
					local step, position, needsjump = getIntercept(state, Horizon.Value, 25)
					if not step then return end
	
					local hum = entitylib.character.Humanoid
					local flat = (position - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1)
					if flat.Magnitude > 1.5 then
						hum:Move(flat.Unit, false)
					end
	
					if needsjump and AutoJump.Enabled and hum.FloorMaterial ~= Enum.Material.Air and step <= math.sqrt(2 * hum.JumpHeight / workspace.Gravity) then
						hum.Jump = true
					end
	
					if charged or step > ChargeLead.Value or soccer.ShootInput.IsCharging() then return end
	
					local input = getInput('Kick')
					if not input then return end
	
					charged = true
					soccer.ShootInput.HandleInputBegan(input, false)
				end))
			else
				if charged then
					soccer.ShootInput.CancelCharge()
				end
				charged = false
			end
		end,
		Tooltip = 'Times the jump onto your own flick and winds the kick up for you, leaving the shot for you to take.'
	})
	
	OwnBall = AutoPowerup:CreateToggle({
		Name = 'Own ball only',
		Default = true,
		Tooltip = 'Only times balls you put in the air yourself, not every loose ball.'
	})
	AutoJump = AutoPowerup:CreateToggle({
		Name = 'Auto jump',
		Default = true,
		Tooltip = 'Jumps so you peak exactly as the ball comes down to you.'
	})
	ChargeLead = AutoPowerup:CreateSlider({
		Name = 'Charge lead',
		Min = 0.05,
		Max = 1.2,
		Default = 0.4,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'How long before the ball reaches you that the kick starts winding up.'
	})
	Horizon = AutoPowerup:CreateSlider({
		Name = 'Horizon',
		Min = 0.5,
		Max = 5,
		Default = 2.5,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'How far ahead the balls flight is read.'
	})
end)

run(function()
	local FakeLag
	local Mode
	local Delay
	local Offset
	
	local maxHeld = 100
	local overdue = 0.09
	local rand = Random.new()
	local queue = {}
	local movement
	local namecall, oldsend, oldrelease
	local acted, dumping, lastsent = 0, 0, 0
	local sending = false
	
	local function push(...)
		local packet = table.pack(...)
		for i = 1, packet.n do
			local value = packet[i]
			if typeof(value) == 'buffer' then
				local copy = buffer.create(buffer.len(value))
				buffer.copy(copy, 0, value)
				packet[i] = copy
			end
		end
	
		packet.Time = os.clock()
		table.insert(queue, packet)
	end
	
	local function release(count)
		for _ = 1, count do
			local packet = table.remove(queue, 1)
			if not packet then break end
	
			sending = true
			pcall(movement.FireServer, movement, table.unpack(packet, 1, packet.n))
			sending = false
		end
	
		lastsent = os.clock()
	end
	
	local function getReady(now)
		if #queue >= maxHeld or not FakeLag.Enabled then
			return #queue
		end
	
		local delay = Delay.Value / 1000
		if Mode.Value == 'Repel' then
			return now >= dumping and #queue or 0
		end
		if Mode.Value == 'Dynamic' and acted >= queue[1].Time then
			return #queue
		end
	
		local spacing = Mode.Value == 'Dynamic' and Offset.Value / 1000 or 0
		local ready = 0
		for _, packet in queue do
			local age = now - packet.Time
			if age < delay then break end
			if spacing > 0 and age < delay + overdue and now - lastsent < spacing then break end
			ready += 1
		end
	
		return ready
	end
	
	FakeLag = vape.Categories.Utility:CreateModule({
		Name = 'FakeLag',
		Function = function(callback)
			if callback then
				movement = soccer.Remotes.Get('Characters', 'MovementUpdate')
				acted, dumping, lastsent = 0, 0, os.clock()
	
				oldsend = oldsend or soccer.ActionRemoteProtocol.Send
				soccer.ActionRemoteProtocol.Send = function(...)
					acted = os.clock()
					if FakeLag.Enabled and Mode.Value == 'Repel' then
						dumping = acted + (Delay.Value / 1000) + rand:NextNumber(0, 0.1)
					end
					return oldsend(...)
				end
	
				oldrelease = oldrelease or soccer.ActionRemoteProtocol.Release
				soccer.ActionRemoteProtocol.Release = function(...)
					acted = os.clock()
					return oldrelease(...)
				end
	
				namecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
					if self == movement and not sending and FakeLag.Enabled and getnamecallmethod() == 'FireServer' then
						if Mode.Value ~= 'Repel' or os.clock() < dumping then
							push(...)
							return
						end
					end
	
					return namecall(self, ...)
				end))
	
				FakeLag:Clean(runService.Heartbeat:Connect(function()
					if #queue == 0 then return end
	
					local ready = getReady(os.clock())
					if ready > 0 then
						release(ready)
					end
				end))
			elseif oldsend then
				if namecall then
					hookmetamethod(game, '__namecall', namecall)
					namecall = nil
				end
				soccer.ActionRemoteProtocol.Send = oldsend
				soccer.ActionRemoteProtocol.Release = oldrelease
				if movement then
					release(#queue)
				end
				table.clear(queue)
			end
		end,
		Tooltip = 'Holds your movement packets back so the server, and everyone watching you, sees where you were instead of where you are.'
	})
	
	Offset = FakeLag:CreateSlider({
		Name = 'Transmission offset',
		Min = 0,
		Max = 50,
		Default = 5,
		Darker = true,
		Tooltip = 'Spaces the held packets out as they go, which makes the connection look less steady. Dynamic only.'
	})
	Mode = FakeLag:CreateDropdown({
		Name = 'Mode',
		List = {'Latency', 'Dynamic', 'Repel'},
		Tooltip = 'Latency holds every packet by the same delay. Dynamic holds them but lets them all go the moment you tackle, kick or pass. Repel only lags while you act, then dumps the lot at once so you snap away from them.'
	})
	Delay = FakeLag:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 1000,
		Default = 100,
		Suffix = 'ms',
		Tooltip = 'How long each packet waits before it is sent. This adds straight onto your real ping.'
	})
end)

run(function()
	vape.Categories.Utility:CreateModule({
		Name = 'InfiniteStamina',
		Function = function(callback)
			soccer.Sprint.SetUnlimitedStamina(lplr, 'opmvape', callback)
		end,
		Tooltip = 'Stops sprinting, tackling, diving and kicking from draining your stamina bar.'
	})
end)