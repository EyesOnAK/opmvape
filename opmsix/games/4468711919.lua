local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local runService = cloneref(game:GetService('RunService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape

local golf = {}

run(function()
	golf = {
		CameraController = require(lplr.PlayerScripts.Controllers.CameraController),
		GameController = require(lplr.PlayerScripts.Controllers.GameController),
		MechanicsController = require(lplr.PlayerScripts.Controllers.MechanicsController)
	}

	vape:Clean(function()
		table.clear(golf)
	end)
end)

run(function()
	local GolfAssist
	local Aim
	local LegitAim
	local AimSpeed
	local Power
	local LegitPower
	local PowerSpeed
	local AutoShoot
	local Legit
	local Strokes
	local Path
	local Samples
	local Color
	
	local folder, anchor, old
	local best, origin, current, field, solved, latency, fired, pending, spin, driven, unsynced
	local parts = {}
	local events = {}
	local connections = {}
	local solveid = 0
	
	local function getField(hole, finish, group)
		local area = 0
		for _, v in hole.Green:GetDescendants() do
			if v:IsA('BasePart') then
				area += v.Size.X * v.Size.Z
			end
		end
	
		local spacing = math.max(3, math.sqrt(area / 4000))
		local include = RaycastParams.new()
		include.FilterType = Enum.RaycastFilterType.Include
		local nodes, cells = {}, {}
		for _, v in hole.Green:GetDescendants() do
			if v:IsA('BasePart') and v.CanCollide then
				include.FilterDescendantsInstances = {v}
				for i = 0, math.floor(v.Size.X / spacing) do
					for i2 = 0, math.floor(v.Size.Z / spacing) do
						local point = v.CFrame * Vector3.new(i * spacing - v.Size.X * 0.5, 0, i2 * spacing - v.Size.Z * 0.5)
						local hit = workspace:Raycast(point + Vector3.new(0, v.Size.Magnitude, 0), Vector3.new(0, -v.Size.Magnitude * 2, 0), include)
						if hit and hit.Normal.Y > 0.3 then
							local node = {position = hit.Position + Vector3.new(0, 1, 0), distance = math.huge, links = {}, index = #nodes + 1}
							local key = tostring(math.floor(node.position.X / (spacing * 1.5))) .. ',' .. tostring(math.floor(node.position.Z / (spacing * 1.5)))
							cells[key] = cells[key] or {}
							table.insert(cells[key], node)
							table.insert(nodes, node)
						end
					end
				end
			end
		end
	
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = group
		for _, v in nodes do
			local x, z = math.floor(v.position.X / (spacing * 1.5)), math.floor(v.position.Z / (spacing * 1.5))
			for i = x - 1, x + 1 do
				for i2 = z - 1, z + 1 do
					for _, v2 in cells[tostring(i) .. ',' .. tostring(i2)] or {} do
						local offset = v2.position - v.position
						if v2.index > v.index and offset.Magnitude <= spacing * 1.5 and math.abs(offset.Y) <= spacing and not workspace:Raycast(v.position, offset, params) then
							table.insert(v.links, v2)
							table.insert(v2.links, v)
						end
					end
				end
			end
			if v.index % 500 == 0 then
				task.wait()
			end
		end
	
		local queue = {}
		for _, v in nodes do
			if (v.position - finish.Position).Magnitude <= spacing * 2 + finish.Size.Magnitude * 0.5 then
				v.distance = (v.position - finish.Position).Magnitude
				table.insert(queue, v)
			end
		end
		local head = 1
		while queue[head] do
			for _, v in queue[head].links do
				if queue[head].distance + (v.position - queue[head].position).Magnitude < v.distance then
					v.distance = queue[head].distance + (v.position - queue[head].position).Magnitude
					table.insert(queue, v)
				end
			end
			head += 1
		end
	
		return {cells = cells, size = spacing * 1.5, finish = finish.Position}
	end
	
	local function getDistance(position)
		local x, z = math.floor(position.X / field.size), math.floor(position.Z / field.size)
		local closest = math.huge
		for i = x - 1, x + 1 do
			for i2 = z - 1, z + 1 do
				for _, v in field.cells[tostring(i) .. ',' .. tostring(i2)] or {} do
					if math.abs(v.position.Y - position.Y) <= field.size then
						closest = math.min(closest, v.distance + (v.position - position).Magnitude)
					end
				end
			end
		end
	
		return closest < math.huge and closest or (position - field.finish).Magnitude
	end
	
	local function getDelay(shot)
		if unsynced then return 0 end
	
		local offset = driven and driven.ReceiveAge > 0 and (latency or lplr:GetNetworkPing()) or 0
		if spin then
			return (shot.launched - offset - os.clock()) % spin
		end
	
		local event
		for _, v in events do
			if not event or v[1] <= shot.launched then
				event = v
			end
		end
		if not event then return 0 end
	
		local first, last, count
		for _, v in events do
			if v[2] == event[2] and v[3] == event[3] then
				first, last, count = first or v[1], v[1], (count or 0) + 1
			end
		end
		if count < 2 then return 0 end
	
		return (last - (os.clock() + offset - (shot.launched - event[1]))) % ((last - first) / (count - 1))
	end
	
	local function launch(shots, limit, context)
		for _, v in shots do
			local part = Instance.new('Part')
			part.Anchored = true
			part.Shape = Enum.PartType.Ball
			part.Size = context.ball.Part.Size
			part.CustomPhysicalProperties = context.ball.Part.CurrentPhysicalProperties
			part.CollisionGroup = context.ball.Part.CollisionGroup
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.CFrame = CFrame.new(context.ball.Part.Position)
			local attachment = Instance.new('Attachment')
			attachment.Parent = part
			local align = Instance.new('AlignOrientation')
			align.Attachment0 = attachment
			align.Attachment1 = anchor
			align.RigidityEnabled = true
			align.Parent = part
			part.Parent = folder
			v.part, v.path, v.approach = part, {part.Position}, math.huge
		end
	
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = context.ball.Part.CollisionGroup
		local half = context.finish.Size * 0.5
		local began, done = os.clock(), false
		repeat
			runService.Heartbeat:Wait()
			local moving = false
			for _, v in shots do
				if v.part and context.id == solveid then
					if not v.launched then
						if os.clock() - began >= (v.delay or 0) then
							v.part.Anchored = false
							v.part.AssemblyLinearVelocity = CFrame.Angles(0, v.yaw, 0).LookVector * v.power * 2
							v.launched = os.clock()
						end
						moving = true
						continue
					end
	
					local position = v.part.Position
					local rel = context.finish.CFrame:PointToObjectSpace(position)
					v.approach = math.min(v.approach, (position - context.finish.Position).Magnitude)
					if (position - v.path[#v.path]).Magnitude > 1 then
						table.insert(v.path, position)
					end
	
					if not v.part.Parent or position.Y < context.floor then
						v.result = 'oob'
					elseif (rel - rel:Max(-half):Min(half)).Magnitude <= v.part.Size.X * 0.5 then
						v.result = 'holed'
						table.insert(v.path, position)
						done = context.racing
					elseif v.part.AssemblyLinearVelocity.Magnitude < 0.1 then
						v.still = v.still or os.clock()
						if os.clock() - v.still > 0.25 then
							local hit = workspace:Raycast(position, Vector3.new(0, -v.part.Size.Y, 0), params)
							v.result = hit and hit.Instance:IsDescendantOf(context.hole.Green) and 'rest' or 'oob'
						end
					else
						v.still = nil
					end
	
					if v.result then
						v.part:Destroy()
						v.part, v.time = nil, os.clock() - v.launched
					else
						moving = true
					end
				end
			end
		until done or not moving or os.clock() - began > limit
	
		for _, v in shots do
			if v.part then
				v.part:Destroy()
				v.part = nil
			end
		end
	end
	
	local function solve(ball)
		solveid += 1
		local id = solveid
		origin, best, solved = ball.Part.Position, nil, nil
	
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.CollisionGroup = ball.Part.CollisionGroup
		local hit = workspace:Raycast(origin, Vector3.new(0, -ball.Part.Size.Y, 0), params)
		local hole = hit and hit.Instance
		while hole and hole.Parent and hole.Parent.Name ~= 'Holes' do
			hole = hole.Parent
		end
		local finish = hole and hole:FindFirstChild('Finish')
		finish = finish and finish:FindFirstChildWhichIsA('BasePart', true)
		if not finish or not hole:FindFirstChild('Green') then return end
	
		if hole ~= current then
			field = getField(hole, finish, ball.Part.CollisionGroup)
			if id ~= solveid then return end
	
			current, spin, driven, unsynced = hole, nil, nil, false
			for _, v in connections do
				v:Disconnect()
			end
			table.clear(connections)
			table.clear(events)
			for _, v in hole:GetDescendants() do
				if v:IsA('AlignPosition') or v:IsA('AlignOrientation') then
					driven = v.Attachment0 and v.Attachment0.Parent or driven
					table.insert(connections, v:GetPropertyChangedSignal('Attachment1'):Connect(function()
						table.insert(events, {os.clock(), v, v.Attachment1})
						if #events > 200 then
							table.remove(events, 1)
						end
					end))
				elseif v:IsA('AngularVelocity') and v.AngularVelocity.Magnitude > 0.001 then
					driven = v.Attachment0 and v.Attachment0.Parent or driven
					unsynced = unsynced or spin and math.abs(spin - math.pi * 2 / v.AngularVelocity.Magnitude) > 0.01
					spin = math.pi * 2 / v.AngularVelocity.Magnitude
				elseif v:IsA('Constraint') and not v:IsA('AngularVelocity') then
					unsynced = true
				end
			end
			unsynced = unsynced or spin and #connections > 0
		end
	
		local floor = finish.Position.Y
		for _, v in hole.Green:GetDescendants() do
			if v:IsA('BasePart') then
				floor = math.min(floor, v.Position.Y - v.Size.Magnitude * 0.5)
			end
		end
	
		local remaining = Legit.Enabled and Strokes.Value - golf.GameController.CurrentGame:GetGamePlayer(lplr):Get('Strokes') or 1
		local target = remaining > 1 and math.min(getDistance(origin) * (remaining - 1) / remaining, 10 * (remaining - 1)) or nil
		local penalty = getDistance(origin) + 100
		local context = {id = id, ball = ball, hole = hole, finish = finish, floor = floor - 50, racing = golf.GameController.CurrentGame:Get('Settings Win Condition') == 'Quickest Time'}
		local maxpower = golf.MechanicsController:GetMaxPower()
		local minpower = golf.MechanicsController:GetThresholdPower()
		local yaws = math.max(math.floor(Samples.Value / 7), 8)
		local yawstep, powerstep = math.pi * 2 / yaws, maxpower * 0.16
		local shots, results, limit = {}, {}, context.racing and 6 or 12
		for i = 1, yaws do
			for i2, v2 in {0.08, 0.16, 0.26, 0.38, 0.54, 0.74, 1} do
				table.insert(shots, {yaw = i * yawstep, power = math.max(v2 * maxpower, minpower), seed = 0, i = i, j = i2})
			end
		end
	
		for i = 1, 4 do
			launch(shots, math.min(limit, 12), context)
			if id ~= solveid then return end
	
			for _, v in shots do
				v.score = v.result == 'holed' and (target and penalty or 0) or v.result == 'rest' and math.abs(getDistance(v.path[#v.path]) - (target or 0)) or penalty
			end
			for _, v in shots do
				local total, count = 0, 0
				for _, v2 in shots do
					if v2 ~= v and v2.seed == v.seed and math.abs(v2.i - v.i) <= 1 and math.abs(v2.j - v.j) <= 1 then
						total, count = total + v2.score, count + 1
					end
				end
				v.risk = v.score + (count > 0 and total / count * 0.1 or 0)
				if v.score < penalty then
					table.insert(results, v)
					if not best or v.risk < best.risk then
						best = v
					end
				end
			end
	
			if best then
				for i2, v2 in parts do
					v2.Position = best.path[math.ceil(i2 * #best.path / #parts)]
					v2.Transparency = Path.Enabled and 0.35 or 1
				end
			end
			if i == 4 or context.racing or i > 1 and best and best.risk == 0 then break end
	
			table.sort(shots, function(a, b)
				return math.min(a.score, target and math.huge or a.approach * 4) < math.min(b.score, target and math.huge or b.approach * 4)
			end)
			yawstep, powerstep = yawstep / 2.5, powerstep / 2.5
			local seeds = {}
			for _, v in shots do
				if #seeds >= 5 - i then break end
				local fresh = true
				for _, v2 in seeds do
					if math.abs(v2.yaw - v.yaw) < yawstep * 3 and math.abs(v2.power - v.power) < powerstep * 3 then
						fresh = false
						break
					end
				end
				if fresh then
					table.insert(seeds, v)
				end
			end
	
			shots, limit = {}, 1
			for _, v in seeds do
				limit = math.max(limit, (v.time or 12) * 1.5 + 1)
				for i2 = 0, 24 do
					table.insert(shots, {yaw = v.yaw + (i2 % 5 - 2) * yawstep, power = math.clamp(v.power + (i2 // 5 - 2) * powerstep, minpower, maxpower), seed = v, i = i2 % 5, j = i2 // 5})
				end
			end
		end
	
		for _, v in events do
			local paired = false
			for _, v2 in events do
				if v2[2] == events[1][2] and math.abs(v2[1] - v[1]) < 0.2 then
					paired = true
					break
				end
			end
			if not paired then
				unsynced = true
				break
			end
		end
	
		if unsynced and best and not context.racing then
			table.sort(results, function(a, b)
				return a.risk < b.risk
			end)
			shots = {}
			for _, v in results do
				if #shots >= 48 then break end
				for i = 0, 7 do
					table.insert(shots, {yaw = v.yaw, power = v.power, delay = i, seed = v})
				end
			end
	
			launch(shots, 20, context)
			if id ~= solveid then return end
	
			best = nil
			for _, v in shots do
				v.seed.average = (v.seed.average or 0) + (v.result == 'holed' and (target and penalty or 0) or v.result == 'rest' and math.abs(getDistance(v.path[#v.path]) - (target or 0)) or penalty) / 8
			end
			for _, v in shots do
				if not best or v.seed.average < best.average then
					best = v.seed
				end
			end
			for i, v in parts do
				v.Position = best.path[math.ceil(i * #best.path / #parts)]
				v.Transparency = Path.Enabled and 0.35 or 1
			end
		end
		solved = best ~= nil
	end
	
	GolfAssist = vape.Categories.Utility:CreateModule({
		Name = 'GolfAssist',
		Function = function(callback)
			if callback then
				folder = Instance.new('Folder')
				folder.Name = 'opmvapegolf'
				folder.Parent = workspace
				anchor = Instance.new('Attachment')
				anchor.Parent = workspace.Terrain
	
				for i = 1, 50 do
					local part = Instance.new('Part')
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.Material = Enum.Material.Neon
					part.Shape = Enum.PartType.Ball
					part.Size = Vector3.new(0.6, 0.6, 0.6)
					part.Transparency = 1
					part.Parent = folder
					parts[i] = part
				end
	
				old = golf.MechanicsController.ShootWithParams
				golf.MechanicsController.ShootWithParams = function(self, yaw, power, pitch)
					if pending then return end
	
					local shot = best
					pending = true
					task.delay(shot and getDelay(shot) or 0, function()
						pending, fired = nil, os.clock()
						old(self, shot and (Aim.Enabled or AutoShoot.Enabled) and shot.yaw or yaw, shot and (Power.Enabled or AutoShoot.Enabled) and shot.power or power, pitch)
					end)
				end
	
				GolfAssist:Clean(runService.RenderStepped:Connect(function(dt)
					local golfer = golf.MechanicsController.LocalGolfer
					local ball = golfer and golfer.Ball
					if fired and ball and ball.Part.AssemblyLinearVelocity.Magnitude > 1 then
						latency, fired = os.clock() - fired, nil
					end
					if origin and (not ball or (ball.Part.Position - origin).Magnitude > 0.5) then
						solveid += 1
						origin, best, solved = nil, nil, nil
						for _, v in parts do
							v.Transparency = 1
						end
					end
					if not origin and ball and golfer:CanShoot() and golfer:Get('ShootingDirection') == 'Forward' then
						task.spawn(solve, ball)
					end
					if not best then return end
	
					local camera = golf.CameraController:GetCamera('Classic')
					local turn = (best.yaw - camera.Rotation.Y + math.pi) % (math.pi * 2) - math.pi
					if golf.MechanicsController.IsAiming then
						if Aim.Enabled or AutoShoot.Enabled then
							camera.Rotation = Vector2.new(camera.Rotation.X, camera.Rotation.Y + (LegitAim.Enabled and turn * math.min(dt * AimSpeed.Value, 1) or turn))
						end
						if Power.Enabled or AutoShoot.Enabled then
							golf.MechanicsController:SetPower(LegitPower.Enabled and golf.MechanicsController.Power + math.clamp(best.power - golf.MechanicsController.Power, -PowerSpeed.Value * dt, PowerSpeed.Value * dt) or best.power)
						end
					end
	
					if AutoShoot.Enabled and not pending and not fired and golfer:CanShoot() then
						if not golf.MechanicsController.IsAiming then
							golf.MechanicsController:SetAiming(true)
						elseif solved and math.abs(turn) < 0.002 and math.abs(golf.MechanicsController.Power - best.power) < 0.01 and getDelay(best) < 0.1 then
							solved = nil
							golf.MechanicsController:Shoot()
						end
					end
				end))
			else
				golf.MechanicsController.ShootWithParams = old
				solveid += 1
				origin, best, current, field, solved = nil, nil, nil, nil, nil
				for _, v in connections do
					v:Disconnect()
				end
				table.clear(connections)
				table.clear(events)
				if folder then
					folder:Destroy()
					folder = nil
				end
				if anchor then
					anchor:Destroy()
					anchor = nil
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Tests every shot on a copy of your ball, draws the one that sinks it in the fewest strokes and lines your aim and power up on it. Shots are timed to trapdoors and spinning obstacles, and on holes that mix them it picks the shot that works whenever you take it.'
	})
	
	Aim = GolfAssist:CreateToggle({
		Name = 'Aim',
		Default = true,
		Tooltip = 'Turns your camera onto the best line while you aim and shoots down it exactly.'
	})
	LegitAim = GolfAssist:CreateToggle({
		Name = 'Legit aim',
		Tooltip = 'Eases your camera onto the line instead of snapping to it.'
	})
	AimSpeed = GolfAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 5,
		Tooltip = 'How quickly Legit aim settles onto the line.'
	})
	Power = GolfAssist:CreateToggle({
		Name = 'Power',
		Default = true,
		Tooltip = 'Holds your power bar on the best power while you aim.'
	})
	LegitPower = GolfAssist:CreateToggle({
		Name = 'Legit power',
		Tooltip = 'Drags your power bar up to the best power instead of setting it straight away.'
	})
	PowerSpeed = GolfAssist:CreateSlider({
		Name = 'Power speed',
		Min = 10,
		Max = 200,
		Default = 60,
		Suffix = '/s',
		Tooltip = 'How much power Legit power adds every second.'
	})
	AutoShoot = GolfAssist:CreateToggle({
		Name = 'Auto shoot',
		Tooltip = 'Aims and takes the best shot for you as soon as it is found. In racing it takes the first shot that sinks it.'
	})
	Legit = GolfAssist:CreateToggle({
		Name = 'Legit',
		Tooltip = 'Plans each hole to go in on the stroke set below instead of always going for a hole in one.'
	})
	Strokes = GolfAssist:CreateSlider({
		Name = 'Strokes',
		Min = 1,
		Max = 5,
		Default = 2,
		Tooltip = 'Which stroke Legit sinks the ball on. The shots before it leave the ball a sensible distance out.'
	})
	Path = GolfAssist:CreateToggle({
		Name = 'Path',
		Function = function(callback)
			for _, v in parts do
				v.Transparency = callback and best and 0.35 or 1
			end
		end,
		Default = true,
		Tooltip = 'Draws where the best shot goes.'
	})
	Samples = GolfAssist:CreateSlider({
		Name = 'Samples',
		Min = 70,
		Max = 700,
		Default = 700,
		Tooltip = 'How many shots are tested at once in the first pass. More finds tighter lines, but costs frames while it searches.'
	})
	Color = GolfAssist:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in parts do
				v.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		DefaultHue = 0.44
	})
end)