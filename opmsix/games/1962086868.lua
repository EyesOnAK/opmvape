local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local runService = cloneref(game:GetService('RunService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))

local lplr = playersService.LocalPlayer
local vape = shared.vape

local toh = {}

run(function()
	toh = {
		Controls = require(lplr.PlayerScripts.PlayerModule).controls
	}

	vape:Clean(function()
		table.clear(toh)
	end)
end)

run(function()
	local AutoPlay
	local Path
	local Color
	
	local folder, probe, rig, route, step, began, launched, airborne, peak, aim, bent, waited, movement, planning, building, built, tower, escape, sunk, hovered, old
	local slip = Vector3.zero
	local nodes, cells, sections, moving, hazards, platforms, trusses, blocked, parts, tracks, demos, strikes, watched = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
	local version, changed, sampled, checked = 0, 0, 0, 0
	local overlap = OverlapParams.new()
	overlap.RespectCanCollide = true
	overlap.FilterType = Enum.RaycastFilterType.Include
	local killoverlap = OverlapParams.new()
	killoverlap.FilterType = Enum.RaycastFilterType.Include
	local finishoverlap = OverlapParams.new()
	finishoverlap.FilterType = Enum.RaycastFilterType.Include
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.FilterType = Enum.RaycastFilterType.Include
	local killparams = RaycastParams.new()
	killparams.FilterType = Enum.RaycastFilterType.Include
	local include = RaycastParams.new()
	include.FilterType = Enum.RaycastFilterType.Include
	
	local function push(heap, item)
		table.insert(heap, item)
		local i = #heap
		while i > 1 and heap[i // 2][2] > item[2] do
			heap[i] = heap[i // 2]
			i //= 2
		end
		heap[i] = item
	end
	
	local function pop(heap)
		local top, last = heap[1], table.remove(heap)
		if heap[1] then
			local i = 1
			while i * 2 <= #heap do
				local child = i * 2
				if child < #heap and heap[child + 1][2] < heap[child][2] then
					child += 1
				end
				if heap[child][2] >= last[2] then break end
				heap[i] = heap[child]
				i = child
			end
			heap[i] = last
		end
		return top
	end
	
	local function getRig()
		local root = lplr.Character.HumanoidRootPart
		local humanoid = lplr.Character:FindFirstChildOfClass('Humanoid')
		local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
		local collidelow, collidehigh, leglow, leghigh = low, high, low, high
		for _, v in lplr.Character:GetChildren() do
			if v:IsA('BasePart') then
				local cf = root.CFrame:ToObjectSpace(v.CFrame)
				local half = ((cf.RightVector * v.Size.X):Abs() + (cf.UpVector * v.Size.Y):Abs() + (cf.LookVector * v.Size.Z):Abs()) * 0.5
				low, high = low:Min(cf.Position - half), high:Max(cf.Position + half)
				if cf.Position.Y - half.Y < -1.2 then
					leglow, leghigh = leglow:Min(cf.Position - half), leghigh:Max(cf.Position + half)
				end
				if v.CanCollide then
					collidelow, collidehigh = collidelow:Min(cf.Position - half), collidehigh:Max(cf.Position + half)
				end
			end
		end
	
		local width = math.max(-collidelow.X, collidehigh.X, -collidelow.Z, collidehigh.Z) * 2 - 0.4
		local hover = humanoid.RigType == Enum.HumanoidRigType.R15 and humanoid.HipHeight + root.Size.Y / 2 or root.Size.Y / 2 + 2
		return {
			hover = hover,
			lift = hover + collidelow.Y - 0.25,
			slope = math.max(math.cos(math.rad(humanoid.MaxSlopeAngle)), 0.25),
			speed = humanoid.WalkSpeed,
			gravity = workspace.Gravity,
			jump = rig and rig.jump or math.max(humanoid.JumpPower, math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)),
			size = Vector3.new(width, collidehigh.Y - collidelow.Y, width),
			offset = Vector3.new(0, (collidelow.Y + collidehigh.Y) / 2, 0),
			kills = {
				{Vector3.new(math.max(-leglow.X, leghigh.X) * 2 + 0.4, -1 - low.Y + 0.3, math.max(-leglow.Z, leghigh.Z) * 2 + 1), Vector3.new(0, (low.Y - 1.3) / 2, 0)},
				{Vector3.new(math.max(-low.X, high.X) * 2 + 0.4, high.Y + 1.2, math.max(-low.Z, high.Z) * 2 + 1.8), Vector3.new(0, (high.Y - 0.8) / 2, 0)}
			}
		}
	end
	
	local function getNodes()
		local current, snapshot, clock, group, count, recorded, rungs = version, {}, os.clock(), lplr.Character.HumanoidRootPart.CollisionGroup, 0, 0, {}
		table.clear(nodes)
		table.clear(cells)
		table.clear(sections)
		table.clear(moving)
		table.clear(hazards)
		table.clear(platforms)
		table.clear(trusses)
		table.clear(blocked)
		for _, v in workspace.tower:GetDescendants() do
			if v:IsA('BasePart') then
				snapshot[v] = v.CFrame
			end
		end
		task.wait(1)
		for i, v in snapshot do
			if (i.Position - v.Position).Magnitude > 0.05 or i.CFrame.LookVector:Dot(v.LookVector) < 0.9999 or not i:IsGrounded() then
				moving[i] = true
			end
		end
	
		local kills = collectionService:GetTagged('LobbyPortal')
		for _, v in replicatedStorage.GameValues.killbricksDisabled.Value and {} or collectionService:GetTagged('KillBrick') do
			table.insert(kills, v)
		end
		overlap.CollisionGroup = group
		params.CollisionGroup = group
		overlap.FilterDescendantsInstances = {workspace.tower}
		params.FilterDescendantsInstances = {workspace.tower}
		killoverlap.FilterDescendantsInstances = kills
		killparams.FilterDescendantsInstances = kills
		table.clear(watched)
		for _, v in kills do
			if moving[v] then
				hazards[v] = {part = v, linear = Vector3.zero, angular = Vector3.zero, center = v.Position}
			else
				watched[v] = v.CFrame
			end
		end
		finishoverlap.FilterDescendantsInstances = {workspace.tower.finishes}
		local box, extents = workspace.tower.finishes:GetBoundingBox()
		local recorder = runService.Heartbeat:Connect(function()
			if os.clock() - recorded > 0.25 then
				recorded = os.clock()
				for _, v in platforms do
					table.insert(v.track, v.part.CFrame)
				end
			end
		end)
	
		for _, v in workspace.tower.sections:GetChildren() do
			if v:FindFirstChild('i') then
				sections[v.i.Value] = v
				for _, v2 in v:GetDescendants() do
					if v2:IsA('BasePart') and v2.CanCollide and not collectionService:HasTag(v2, 'KillBrick') and v2.Position.Y - (math.abs(v2.CFrame.RightVector.Y) * v2.Size.X + math.abs(v2.CFrame.UpVector.Y) * v2.Size.Y + math.abs(v2.CFrame.LookVector.Y) * v2.Size.Z) / 2 < box.Y + extents.Y / 2 + 2 then
						local half = ((v2.CFrame.RightVector * v2.Size.X):Abs() + (v2.CFrame.UpVector * v2.Size.Y):Abs() + (v2.CFrame.LookVector * v2.Size.Z):Abs()) * 0.5
						local footprint = math.abs(v2.CFrame.UpVector.Y) >= math.max(math.abs(v2.CFrame.RightVector.Y), math.abs(v2.CFrame.LookVector.Y)) and math.min(v2.Size.X, v2.Size.Z) or math.abs(v2.CFrame.RightVector.Y) >= math.abs(v2.CFrame.LookVector.Y) and math.min(v2.Size.Y, v2.Size.Z) or math.min(v2.Size.X, v2.Size.Y)
						local spacing = footprint > 16 and 2 or 1
						local columns, rows = math.max(math.floor(half.X * 2 / spacing), 1) - 1, math.max(math.floor(half.Z * 2 / spacing), 1) - 1
						local platform
						if moving[v2] then
							count += 1
							platform = {part = v2, samples = {}, track = {}, swept = {}, linear = Vector3.zero, angular = Vector3.zero, center = v2.Position}
							platform.node = {position = v2.Position, section = v.i.Value, links = {}, border = true, index = -count, island = -count, platform = platform}
						end
						include.FilterDescendantsInstances = {v2}
						for x = v2.Position.X - columns * spacing / 2, v2.Position.X + columns * spacing / 2 + 0.01, spacing do
							for z = v2.Position.Z - rows * spacing / 2, v2.Position.Z + rows * spacing / 2 + 0.01, spacing do
								local hit = workspace:Raycast(Vector3.new(x, v2.Position.Y + half.Y + 0.1, z), Vector3.new(0, -half.Y * 2 - 0.2, 0), include)
								if hit and hit.Normal.Y > rig.slope and platform then
									table.insert(platform.samples, v2.CFrame:PointToObjectSpace(hit.Position))
								elseif hit and hit.Normal.Y > rig.slope then
									probe.Size, probe.CFrame = Vector3.new(1, 0.2, 1), CFrame.new(hit.Position + Vector3.new(0, 0.2, 0))
									local buried = workspace:GetPartsInPart(probe, overlap)
									local safe = not buried[1] or buried[1] == v2 and not buried[2]
									probe.Size, probe.CFrame = rig.size, CFrame.new(hit.Position + Vector3.new(0, rig.hover + (1 - hit.Normal.Y) * 2, 0) + rig.offset)
									safe = safe and not workspace:GetPartsInPart(probe, overlap)[1]
									for _, v3 in rig.kills do
										if not safe then break end
										probe.Size, probe.CFrame = Vector3.new(v3[1].Z, v3[1].Y, v3[1].Z), CFrame.new(hit.Position + Vector3.new(0, rig.hover, 0) + v3[2])
										safe = not workspace:GetPartsInPart(probe, killoverlap)[1]
									end
									if safe then
										local node = {
											position = hit.Position,
											section = v.i.Value,
											spacing = spacing,
											links = {},
											index = #nodes + 1,
											belt = collectionService:HasTag(v2, 'Conveyor') and v2.AssemblyLinearVelocity or nil,
											finish = workspace:GetPartsInPart(probe, finishoverlap)[1] ~= nil
										}
										local key = `{hit.Position.X // 4},{hit.Position.Y // 4},{hit.Position.Z // 4}`
										cells[key] = cells[key] or {}
										table.insert(cells[key], node)
										table.insert(nodes, node)
									end
								end
								if os.clock() - clock > 0.004 then
									task.wait()
									clock = os.clock()
									if current ~= version then
										recorder:Disconnect()
										return
									end
								end
							end
						end
						if platform and platform.samples[1] then
							platforms[v2] = platform
						end
						if not platform and (v2:IsA('TrussPart') and math.abs((v2.Size.Y >= math.max(v2.Size.X, v2.Size.Z) and v2.CFrame.UpVector or v2.Size.X >= v2.Size.Z and v2.CFrame.RightVector or v2.CFrame.LookVector).Y) > 0.85 or half.Y <= 0.8) then
							local key = `{math.floor(v2.Position.X + 0.5)},{math.floor(v2.Position.Z + 0.5)}`
							rungs[key] = rungs[key] or {}
							table.insert(rungs[key], {v2.Position, half, v2:IsA('TrussPart')})
						end
					end
				end
			end
		end
	
		for _, v in rungs do
			table.sort(v, function(a, b)
				return a[1].Y < b[1].Y
			end)
			local first = 1
			for i, v2 in v do
				local gap = v[i + 1] and v[i + 1][1].Y - v[i + 1][2].Y - v2[1].Y - v2[2].Y
				if not gap or gap > 2.5 or gap < 0.2 and not (v2[3] and v[i + 1][3]) then
					if i - first >= 2 or v2[3] and v2[1].Y + v2[2].Y - v[first][1].Y + v[first][2].Y >= 4 then
						table.insert(trusses, {position = v[first][1], half = v2[2] * Vector3.new(1, 0, 1), bottom = v[first][1].Y - v[first][2].Y, top = v2[1].Y + v2[2].Y})
					end
					first = i + 1
				end
			end
		end
	
		for _, v in nodes do
			for i = v.position.X // 4 - 1, v.position.X // 4 + 1 do
				for i2 = v.position.Y // 4 - 1, v.position.Y // 4 + 1 do
					for i3 = v.position.Z // 4 - 1, v.position.Z // 4 + 1 do
						for _, v2 in cells[`{i},{i2},{i3}`] or {} do
							local offset = v2.position - v.position
							local flat = offset * Vector3.new(1, 0, 1)
							if v2.index > v.index and math.abs(offset.Y) <= math.max(1.2, flat.Magnitude * math.sqrt(1 - rig.slope * rig.slope) / rig.slope) and flat.Magnitude > 0.1 and flat.Magnitude <= math.max(v.spacing, v2.spacing) * 1.5 then
								local hit = workspace:Raycast((v.position + v2.position) / 2 + Vector3.new(0, 1.5, 0), Vector3.new(0, -3, 0), params)
								local safe = hit and hit.Normal.Y > rig.slope and (math.abs(offset.Y) <= 1.2 or hit.Normal.Y < 0.95)
								for _, v3 in rig.kills do
									if not safe then break end
									probe.Size, probe.CFrame = v3[1], CFrame.lookAt(v.position, v.position + flat) + Vector3.new(0, rig.hover, 0) + v3[2]
									safe = not workspace:GetPartsInPart(probe, killoverlap)[1]
									probe.CFrame += offset
									safe = safe and not workspace:GetPartsInPart(probe, killoverlap)[1]
								end
								if safe then
									table.insert(v.links, v2)
									table.insert(v2.links, v)
								end
							end
						end
					end
				end
			end
			if os.clock() - clock > 0.004 then
				task.wait()
				clock = os.clock()
				if current ~= version then
					recorder:Disconnect()
					return
				end
			end
		end
		recorder:Disconnect()
	
		local island = 0
		for _, v in nodes do
			local directions = 0
			for _, v2 in v.links do
				directions = bit32.bor(directions, bit32.lshift(1, math.floor(math.atan2(v2.position.Z - v.position.Z, v2.position.X - v.position.X) / math.pi * 4 + 8.5) % 8))
			end
			v.border = directions ~= 255
			if not v.island then
				island += 1
				v.island = island
				local queue, head = {v}, 1
				while queue[head] do
					for _, v2 in queue[head].links do
						if not v2.island then
							v2.island = island
							table.insert(queue, v2)
						end
					end
					head += 1
				end
			end
		end
	
		for _, v in platforms do
			local total = Vector3.zero
			for _, v2 in v.track do
				for i, v3 in v.samples do
					if i % math.ceil(#v.samples / 5) == 0 then
						table.insert(v.swept, v2 * v3)
						total += v2 * v3
					end
				end
			end
			v.node.position = v.swept[1] and total / #v.swept or v.part.Position
		end
	
		return current == version
	end
	
	local function getJumps(node)
		local candidates, counts = {}, {}
		node.jumps = {}
		for i, v in node.platform and node.platform.swept or {node.position} do
			if i % 3 == 1 or not node.platform then
				for i2 = v.X // 4 - 4, v.X // 4 + 4 do
					for i3 = (v.Y - 12) // 4, (v.Y + 10) // 4 do
						for i4 = v.Z // 4 - 4, v.Z // 4 + 4 do
							for _, v2 in cells[`{i2},{i3},{i4}`] or {} do
								if v2.island ~= node.island and ((v2.position - v) * Vector3.new(1, 0, 1)).Magnitude <= 14 then
									table.insert(candidates, {v2, ((v2.position - v) * Vector3.new(1, 0, 1)).Magnitude, v, v2.position})
								end
							end
						end
					end
				end
				for _, v2 in platforms do
					if v2.node ~= node then
						for _, v3 in v2.swept do
							if v3.Y - v.Y > -12 and v3.Y - v.Y < 10 and ((v3 - v) * Vector3.new(1, 0, 1)).Magnitude <= 14 then
								table.insert(candidates, {v2.node, ((v3 - v) * Vector3.new(1, 0, 1)).Magnitude, v, v3})
							end
						end
					end
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a[2] < b[2]
		end)
	
		for _, v in trusses do
			local reach = (((node.position - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude
			if not node.platform and reach <= 7.5 and node.position.Y > v.bottom - 6 and node.position.Y < v.top - 1 then
				for i = (v.position.X - v.half.X - 4) // 4, (v.position.X + v.half.X + 4) // 4 do
					for i2 = node.position.Y // 4, (v.top + 2) // 4 do
						for i3 = (v.position.Z - v.half.Z - 4) // 4, (v.position.Z + v.half.Z + 4) // 4 do
							for _, v2 in cells[`{i},{i2},{i3}`] or {} do
								local count = counts[v2.island] or {0, 0, {}}
								counts[v2.island] = count
								if count[1] < 2 and v2.island ~= node.island and v2.position.Y > node.position.Y + 1.5 and v2.position.Y < v.top + 2.5 and (((v2.position - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude <= 3.5 then
									count[1] += 1
									table.insert(node.jumps, {from = node, node = v2, time = (v2.position.Y - node.position.Y) / (rig.speed * 0.7) + reach / rig.speed + 1, delay = 0, jump = 0, climb = v})
								end
							end
						end
					end
				end
			end
		end
	
		for _, v in candidates do
			local dynamic = node.platform or v[1].platform
			local count = counts[v[1].island] or {0, 0, {}}
			counts[v[1].island] = count
			local fresh = true
			for _, v2 in count[3] do
				fresh = fresh and (v2 - v[4]).Magnitude > 1.5
			end
			if count[1] < 2 and count[2] < (dynamic and 12 or 8) and fresh then
				count[2] += 1
				table.insert(count[3], v[4])
				local offset, edge = v[4] - v[3], 0
				local direction = offset * Vector3.new(1, 0, 1)
				direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.zAxis
				for i = 1, node.platform and 0 or 6 do
					probe.Size, probe.CFrame = rig.kills[1][1], CFrame.lookAt(Vector3.zero, direction) + v[3] + direction * (i * 0.25) + Vector3.new(0, rig.hover, 0) + rig.kills[1][2]
					if i * 0.25 > v[2] - 0.5 or not workspace:Raycast(v[3] + direction * (i * 0.25) + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), params) or workspace:GetPartsInPart(probe, killoverlap)[1] then break end
					edge = i * 0.25
				end
				local origin, land = v[3] + direction * edge + Vector3.new(0, rig.hover, 0), 0
				offset -= direction * edge
				for i = 1, v[1].platform and 0 or 6 do
					probe.Size, probe.CFrame = rig.kills[1][1], CFrame.lookAt(Vector3.zero, direction) + v[4] - direction * (i * 0.25) + Vector3.new(0, rig.hover, 0) + rig.kills[1][2]
					if i * 0.25 > (offset * Vector3.new(1, 0, 1)).Magnitude - 0.5 or not workspace:Raycast(v[4] - direction * (i * 0.25) + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), params) or workspace:GetPartsInPart(probe, killoverlap)[1] then break end
					land = i * 0.25
				end
				offset -= direction * land
				local flat = offset * Vector3.new(1, 0, 1)
				local facing = CFrame.lookAt(Vector3.zero, direction)
				local move, found, safe = flat.Magnitude / rig.speed, nil, true
				for _, v2 in rig.kills do
					probe.Size, probe.CFrame = v2[1], facing + origin + v2[2]
					safe = safe and (node.platform or not workspace:GetPartsInPart(probe, killoverlap)[1])
				end
				for _, v2 in {rig.jump, 0} do
					if safe and not found and v2 * v2 - 2 * rig.gravity * (offset.Y - rig.lift + 0.1) >= 0 and (v2 > 0 or offset.Y < -1) then
						local time = (v2 + math.sqrt(v2 * v2 - 2 * rig.gravity * (offset.Y - rig.lift))) / rig.gravity
						local stop = math.min(time, v2 * v2 - 2 * rig.gravity * (offset.Y + 0.3) >= 0 and (v2 + math.sqrt(v2 * v2 - 2 * rig.gravity * (offset.Y + 0.3))) / rig.gravity or time)
						if dynamic and move <= time - 0.05 then
							found = {from = node, node = v[1], time = time, delay = 0, jump = v2, takeoff = edge}
						elseif not dynamic then
							local bends, index = {origin + flat / 2}, 1
							while bends[index] and not found do
								local bend = bends[index]
								local first, second = bend - origin, origin + flat - bend
								local length = first.Magnitude + second.Magnitude
								if length / rig.speed <= time - 0.02 then
									for _, v4 in v2 > 0 and {math.max(time - length / rig.speed - 0.06, 0), 0} or {0} do
										local last, clear = origin, true
										for i = 1, math.ceil(stop / 0.04) do
											local elapsed = math.min(i * 0.04, stop)
											local travelled = math.clamp((elapsed - v4) * rig.speed, 0, length)
											local segment = travelled < first.Magnitude and first or second
											local turn = CFrame.lookAt(Vector3.zero, segment.Magnitude > 0.01 and segment or direction)
											local point = (travelled < first.Magnitude and origin + (first.Magnitude > 0.01 and first.Unit or Vector3.zero) * travelled or bend + (second.Magnitude > 0.01 and second.Unit or Vector3.zero) * (travelled - first.Magnitude)) + Vector3.new(0, v2 * elapsed - rig.gravity * elapsed * elapsed / 2, 0)
											local hit = (point - last).Magnitude > 0.001 and workspace:Blockcast(CFrame.new(last + rig.offset), rig.size, point - last, params)
											if hit and index == 1 and not bends[2] and math.max(hit.Instance.Size.X, hit.Instance.Size.Z) <= 24 then
												for _, v5 in {Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1)} do
													local corner = hit.Instance.CFrame * (hit.Instance.Size / 2 * v5 + v5 * 1.3)
													table.insert(bends, Vector3.new(corner.X, origin.Y, corner.Z))
												end
												for _, v5 in {origin, origin + flat} do
													local pad = hit.Instance.Size / 2 + Vector3.new(1.3, 0, 1.3)
													local rel = hit.Instance.CFrame:PointToObjectSpace(v5)
													rel = Vector3.new(math.clamp(rel.X, -pad.X, pad.X), 0, math.clamp(rel.Z, -pad.Z, pad.Z))
													local outline = hit.Instance.CFrame * (pad.X - math.abs(rel.X) < pad.Z - math.abs(rel.Z) and Vector3.new(rel.X >= 0 and pad.X or -pad.X, 0, rel.Z) or Vector3.new(rel.X, 0, rel.Z >= 0 and pad.Z or -pad.Z))
													table.insert(bends, Vector3.new(outline.X, origin.Y, outline.Z))
												end
											end
											if hit or (point - last).Magnitude > 0.001 and (workspace:Blockcast(turn + last + rig.kills[1][2], rig.kills[1][1], point - last, killparams) or workspace:Blockcast(turn + last + rig.kills[2][2], rig.kills[2][1], point - last, killparams)) then
												clear = false
												break
											end
											last = point
										end
										if clear then
											found = {from = node, node = v[1], time = time, delay = v4, jump = v2, takeoff = edge, bend = index > 1 and bend - Vector3.new(0, rig.hover, 0) or nil}
											break
										end
									end
								end
								index += 1
							end
						end
					end
				end
				if found then
					count[1] += 1
					table.insert(node.jumps, found)
				end
			end
		end
	
		return node.jumps
	end
	
	local function getPath(start, goals)
		local current, target = version, sections[start.section + 1] and sections[start.section + 1]:FindFirstChild('start')
		target = target and target.Position or workspace.tower.finishes:GetPivot().Position
		local heap, costs, parents, closed, clock, count = {{start, 0}}, {[start] = 0}, {}, {}, os.clock(), 0
		while heap[1] and current == version and count < 60000 do
			local node = pop(heap)[1]
			if not closed[node] then
				closed[node] = true
				if node.section > start.section or node.finish or goals and goals[node] then
					local list = {}
					while parents[node] do
						table.insert(list, 1, parents[node])
						node = parents[node].from
					end
					return list
				end
	
				for _, v in node.links do
					local flat = (v.position - node.position) * Vector3.new(1, 0, 1)
					local speed = rig.speed + (node.belt and node.belt:Dot(flat.Unit) or 0)
					local cost = costs[node] + flat.Magnitude / math.max(speed, 0.1)
					if speed > 3 and cost < (costs[v] or math.huge) and (blocked[`{node.index},{v.index}`] or 0) < 2 then
						costs[v], parents[v] = cost, {from = node, node = v, time = flat.Magnitude / speed}
						push(heap, {v, cost + (target - v.position).Magnitude / rig.speed * 2})
					end
				end
				if node.border then
					for _, v in node.jumps or getJumps(node) do
						local cost = costs[node] + v.time + ((node.platform or v.node.platform) and 1.5 or 0.3)
						if cost < (costs[v.node] or math.huge) and (blocked[`{node.index},{v.node.index}`] or 0) < 2 then
							costs[v.node], parents[v.node] = cost, v
							push(heap, {v.node, cost + (target - v.node.position).Magnitude / rig.speed * 2})
						end
					end
				end
	
				count += 1
				if os.clock() - clock > 0.004 then
					task.wait()
					clock = os.clock()
				end
			end
		end
	
		return nil
	end
	
	local function getDemo(samples, feet)
		local list, index, distance = {}, nil, 24
		local function anchor(sample, position, name, snap)
			for i, v in sample.frames or {} do
				if platforms[i] and (v:PointToObjectSpace(position):Abs() - i.Size / 2):Max(Vector3.zero).Magnitude < 1.5 then
					return {position = position, index = name, part = i, frame = v, offset = v:PointToObjectSpace(position)}
				end
			end
			if snap and not workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -3.5, 0), params) then
				local best, distance = nil, 2.5
				for i = position.X // 4 - 1, position.X // 4 + 1 do
					for i2 = position.Y // 4 - 1, position.Y // 4 do
						for i3 = position.Z // 4 - 1, position.Z // 4 + 1 do
							for _, v in cells[`{i},{i2},{i3}`] or {} do
								local flat = ((v.position - position) * Vector3.new(1, 0, 1)).Magnitude
								if flat < distance and v.position.Y > position.Y - 3.5 and v.position.Y < position.Y + 1 then
									best, distance = v, flat
								end
							end
						end
					end
				end
				position = best and best.position or position
			end
			return {position = position, index = name}
		end
		for i, v in samples do
			local offset = v.position - Vector3.new(0, rig.hover, 0) - feet
			if v.grounded and math.abs(offset.Y) < 3 and (offset * Vector3.new(1, 0, 1)).Magnitude < 4 then
				index = i
			end
		end
		if not index then
			for i, v in samples do
				local offset = v.position - Vector3.new(0, rig.hover, 0) - feet
				if v.grounded and math.abs(offset.Y) < 3 and (offset * Vector3.new(1, 0, 1)).Magnitude < distance and workspace:Blockcast(CFrame.new(feet + offset * 0.5 + Vector3.new(0, 1, 0)), Vector3.new(rig.size.X, 0.2, rig.size.Z), Vector3.new(0, -4, 0), params) then
					index, distance = i, (offset * Vector3.new(1, 0, 1)).Magnitude
				end
			end
		end
		if not index then return nil end
	
		local last = feet
		while samples[index] do
			local finish = index
			while samples[finish] and not samples[finish].grounded do
				finish += 1
			end
			if not samples[finish] then break end
	
			local rise = math.max(index - 1, 1)
			for i = rise, finish - 1 do
				if samples[i + 1].position.Y - samples[i].position.Y > 0.5 then
					rise = i
					break
				end
			end
			while rise > index and not workspace:Blockcast(CFrame.new(samples[rise].position - Vector3.new(0, rig.hover - 1, 0)), Vector3.new(rig.size.X, 0.2, rig.size.Z), Vector3.new(0, -3.5, 0), params) do
				rise -= 1
			end
			local takeoff, landing = samples[rise].position - Vector3.new(0, rig.hover, 0), samples[finish].position - Vector3.new(0, rig.hover, 0)
			for _, v in trusses do
				if v.bottom < landing.Y + 1 and v.top > landing.Y and (((landing - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude < 2.5 and not workspace:Raycast(landing + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), params) then
					landing = Vector3.new(v.position.X, landing.Y, v.position.Z) + ((landing - v.position) * Vector3.new(1, 0, 1)):Max(-v.half):Min(v.half)
				end
			end
			local line, duration = (landing - takeoff) * Vector3.new(1, 0, 1), samples[finish].time - samples[rise].time
			local peak, spread, climb = takeoff.Y, 0, nil
			for i = index, finish do
				local offset = (samples[i].position - Vector3.new(0, rig.hover, 0) - takeoff) * Vector3.new(1, 0, 1)
				peak, spread = math.max(peak, samples[i].position.Y - rig.hover), math.max(spread, offset.Magnitude)
			end
			for _, v in trusses do
				if finish > index and landing.Y - takeoff.Y > 4 and v.bottom < landing.Y and v.top > takeoff.Y and (spread < 3 and (((samples[(index + finish) // 2].position - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude < 3 or landing.Y - takeoff.Y > rig.jump * rig.jump / rig.gravity / 2 + rig.lift and (((landing - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude < 3) then
					climb = v
				end
			end
	
			if climb or finish > index and duration <= 1.6 and line.Magnitude <= 14 and line.Magnitude <= rig.speed * duration + 2 then
				for i = index, rise do
					local position = samples[i].position - Vector3.new(0, rig.hover, 0)
					if (position - last).Magnitude >= 2 then
						local offset = (position - last) * Vector3.new(1, 0, 1)
						table.insert(list, offset.Magnitude > 0.1 and workspace:Blockcast(CFrame.lookAt(last, last + offset) + Vector3.new(0, rig.hover, 0) + rig.kills[1][2], rig.kills[1][1], position - last, killparams) and {from = anchor(samples[i], last, `hop{i}`, true), node = anchor(samples[i], position, `demo{i}`, true), time = 0.6, delay = 0, jump = rig.jump, takeoff = 0} or {node = anchor(samples[i], position, `demo{i}`, true), time = (position - last).Magnitude / rig.speed})
						last = position
					end
				end
				local nearby, phase = {}, {}
				for i, v in samples[rise].frames or {} do
					local along = math.clamp((v.Position - takeoff):Dot(landing - takeoff) / math.max((landing - takeoff).Magnitude ^ 2, 0.001), 0, 1)
					local gap = (v.Position - takeoff:Lerp(landing, along)).Magnitude - i.Size.Magnitude / 2
					if gap < 6 then
						table.insert(nearby, {i, v, gap})
					end
				end
				table.sort(nearby, function(a, c)
					return a[3] < c[3]
				end)
				for i, v in nearby do
					if i > 2 then break end
					phase[v[1]] = v[2]
				end
				local jump, delay, path = not climb and peak > takeoff.Y + 1 and rig.jump or 0, 0, {}
				if jump > 0 and samples[rise + 1] then
					local airtime = (jump - math.sqrt(math.max(jump * jump - 2 * rig.gravity * math.max(samples[rise + 1].position.Y - samples[rise].position.Y, 0), 0))) / rig.gravity
					local gap = math.max(samples[rise + 1].time - samples[rise].time, 0.001)
					local launch = samples[rise + 1].time - math.min(airtime, gap)
					takeoff = Vector3.new(0, takeoff.Y, 0) + samples[rise].position:Lerp(samples[rise + 1].position, 1 - math.min(airtime, gap) / gap) * Vector3.new(1, 0, 1)
					delay = ((samples[rise + 1].position - samples[rise].position) * Vector3.new(1, 0, 1)).Magnitude / gap < 6 and 0.06 or 0
					table.insert(path, {0, takeoff * Vector3.new(1, 0, 1)})
					for i = rise + 1, finish do
						table.insert(path, {samples[i].time - launch, samples[i].position * Vector3.new(1, 0, 1)})
					end
				end
				local from, node, edge = anchor(samples[rise], takeoff, `demo{rise}`, true), anchor(samples[finish], landing, `demo{finish}`), 0
				local direction = (landing - from.position) * Vector3.new(1, 0, 1)
				for i = 1, jump > 0 and not from.part and direction.Magnitude > 2 and 6 or 0 do
					local point = from.position + direction.Unit * (i * 0.25)
					probe.Size, probe.CFrame = rig.kills[1][1], CFrame.lookAt(Vector3.zero, direction) + point + Vector3.new(0, rig.hover, 0) + rig.kills[1][2]
					if not workspace:Raycast(point + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), params) or workspace:GetPartsInPart(probe, killoverlap)[1] then break end
					edge = i * 0.25
				end
				table.insert(list, {from = from, node = node, time = duration, delay = delay, jump = jump, takeoff = edge, path = path[2] and not from.part and not node.part and path or nil, climb = climb, phase = nearby[1] and phase or nil})
				last = landing
			else
				for i = index, finish do
					local position = samples[i].position - Vector3.new(0, rig.hover, 0)
					if (position - last).Magnitude >= 2 then
						local offset = (position - last) * Vector3.new(1, 0, 1)
						table.insert(list, offset.Magnitude > 0.1 and workspace:Blockcast(CFrame.lookAt(last, last + offset) + Vector3.new(0, rig.hover, 0) + rig.kills[1][2], rig.kills[1][1], position - last, killparams) and {from = anchor(samples[i], last, `hop{i}`, true), node = anchor(samples[i], position, `demo{i}`, true), time = 0.6, delay = 0, jump = rig.jump, takeoff = 0} or {node = anchor(samples[i], position, `demo{i}`, true), time = (position - last).Magnitude / rig.speed})
						last = position
					end
				end
			end
			index = finish + 1
		end
	
		return list[1] and list or nil
	end
	
	local function getDanger(from, to, duration, jump)
		for i in hazards do
			if i.Parent and ((i.Position - from) * Vector3.new(1, 0, 1)).Magnitude < (to - from).Magnitude + i.Size.Magnitude / 2 + 12 then
				local center, angular = hazards[i].center, hazards[i].angular
				for i2 = 0, 8 do
					local elapsed = duration * i2 / 8
					local frame = CFrame.new(center + hazards[i].linear * elapsed) * CFrame.fromAxisAngle(angular.Magnitude > 0.0001 and angular.Unit or Vector3.yAxis, angular.Magnitude * elapsed) * (i.CFrame - center)
					local point = from:Lerp(to, i2 / 8)
					if jump then
						local height = from.Y + jump * elapsed - rig.gravity * elapsed * elapsed / 2
						point = Vector3.new(point.X, elapsed > jump / rig.gravity and math.max(height, to.Y) or height, point.Z)
					end
					for _, v in {1.5, 0, -1.5, -2.8} do
						if (frame:PointToObjectSpace(point + Vector3.new(0, v, 0)):Abs() - i.Size / 2):Max(Vector3.zero).Magnitude < 1.2 then
							return true, v < 0
						end
					end
				end
			end
		end
	
		return false, false
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				folder = Instance.new('Folder')
				folder.Name = 'opmvapetower'
				folder.Parent = workspace
				probe = Instance.new('Part')
				probe.Anchored = true
				for i = 1, 80 do
					local part = Instance.new('Part')
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.Material = Enum.Material.Neon
					part.Shape = Enum.PartType.Ball
					part.Size = Vector3.new(0.5, 0.5, 0.5)
					part.Transparency = 1
					part.Parent = folder
					parts[i] = part
				end
	
				old = toh.Controls.moveFunction
				toh.Controls.moveFunction = function(self, vec, face)
					return old(self, movement or Vector3.zero, false)
				end
	
				AutoPlay:Clean(lplr.CharacterAdded:Connect(function()
					route, launched = nil, nil
				end))
				AutoPlay:Clean(runService.Heartbeat:Connect(function()
					if not rig or os.clock() - sampled < 0.066 then return end
					if os.clock() - checked > 0.5 then
						checked = os.clock()
						for i, v in watched do
							if (i.Position - v.Position).Magnitude > 0.05 or i.CFrame.LookVector:Dot(v.LookVector) < 0.9999 then
								hazards[i], watched[i] = {part = i, linear = Vector3.zero, angular = Vector3.zero, center = i.Position}, nil
							end
						end
					end
					sampled = os.clock()
					local frames = {}
					for i in hazards do
						frames[i] = i.CFrame
					end
					for i in platforms do
						frames[i] = i.CFrame
					end
					for _, v in playersService:GetPlayers() do
						local root = v ~= lplr and v.Character and v.Character:FindFirstChild('HumanoidRootPart')
						local section = root and v.Character:FindFirstChild('currentSection')
						if section then
							local track = tracks[v] or {}
							local last, entrance = track[#track], track[1] and sections[track[1].section] and sections[track[1].section]:FindFirstChild('start')
							tracks[v] = track
							if last and entrance and section.Value == last.section + 1 and (root.Position - last.position).Magnitude < 25 and #track > (last.time - track[1].time) * 8 and track[1].position.Y - rig.hover > entrance.Position.Y - 2 then
								local valid, rising = last.time - track[1].time > 1.5, 0
								for i = 2, #track do
									rising = track[i].velocity > 30 and rising + 1 or 0
									if rising >= 3 or ((track[i].position - track[i - 1].position) * Vector3.new(1, 0, 1)).Magnitude / math.max(track[i].time - track[i - 1].time, 0.001) > 45 then
										valid = false
									end
								end
								if valid then
									local list = demos[last.section] or {}
									demos[last.section] = list
									table.insert(list, {samples = table.clone(track), duration = last.time - track[1].time})
									table.sort(list, function(a, c)
										return a.duration < c.duration
									end)
									if #list > 6 then
										table.remove(list)
									end
								end
							end
							if last and ((root.Position - last.position).Magnitude > 25 or section.Value ~= last.section) then
								table.clear(track)
							end
							local hit, previous, velocity = workspace:Blockcast(root.CFrame, Vector3.new(rig.size.X, 0.2, rig.size.Z), Vector3.new(0, -rig.hover - 0.1, 0), params), track[#track], root.AssemblyLinearVelocity.Y
							local grounded = hit ~= nil and hit.Normal.Y > 0.5 or previous ~= nil and math.abs(velocity) < 0.5 and math.abs(previous.velocity) < 0.5
							if previous and not previous.grounded and not grounded and velocity - previous.velocity > 8 then
								if previous.position.Y < root.Position.Y then
									previous.grounded = true
								else
									grounded = true
								end
							end
							table.insert(track, {time = os.clock(), position = root.Position, velocity = velocity, grounded = grounded, section = section.Value, frames = frames})
							if #track > 3000 then
								table.remove(track, 1)
							end
						end
					end
				end))
	
				AutoPlay:Clean(runService.PreSimulation:Connect(function(dt)
					local humanoid = lplr.Character and lplr.Character:FindFirstChildOfClass('Humanoid')
					local root = humanoid and lplr.Character:FindFirstChild('HumanoidRootPart')
					if not root or humanoid.Health <= 0 then
						route, launched, movement = nil, nil, nil
						return
					end
	
					local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
					hovered = not grounded and math.abs(root.AssemblyLinearVelocity.Y) < 1 and (hovered or os.clock()) or nil
					local settled = grounded or hovered and os.clock() - hovered > 0.5
					if built and workspace:FindFirstChild('tower') ~= tower then
						version, changed, built, route = version + 1, os.clock(), nil, nil
					end
					if not built then
						movement = Vector3.zero
						if not building and settled and os.clock() - changed > 2 and workspace:FindFirstChild('tower') and workspace.tower:FindFirstChild('sections') and workspace.tower:FindFirstChild('finishes') then
							building = true
							task.spawn(function()
								if tower ~= workspace.tower then
									tower = workspace.tower
									AutoPlay:Clean(tower.sections.ChildAdded:Connect(function()
										version, changed, built, route = version + 1, os.clock(), nil, nil
									end))
									AutoPlay:Clean(tower.sections.ChildRemoved:Connect(function()
										version, changed, built, route = version + 1, os.clock(), nil, nil
									end))
									table.clear(tracks)
									table.clear(demos)
									table.clear(strikes)
								end
								rig = getRig()
								built = getNodes()
								building = nil
							end)
						end
						return
					end
	
					for _, v in {platforms, hazards} do
						for _, v2 in v do
							if not v2.stamp or os.clock() - v2.stamp >= 0.1 then
								local previous = v2.frame or v2.part.CFrame
								local axis, angle = (v2.part.CFrame.Rotation * previous.Rotation:Inverse()):ToAxisAngle()
								local elapsed = v2.stamp and os.clock() - v2.stamp or 1
								v2.linear = v2.linear:Lerp((v2.part.Position - previous.Position) / elapsed, 0.6)
								v2.angular = v2.angular:Lerp(axis * angle / elapsed, 0.6)
								v2.frame, v2.stamp = v2.part.CFrame, os.clock()
							end
							v2.center = v2.part.Position
						end
					end
	
					local feet = root.Position - Vector3.new(0, rig.hover, 0)
					local floor = grounded and workspace:Raycast(root.Position, Vector3.new(0, -rig.hover - 1.5, 0), params)
					slip = floor and floor.Instance.Anchored and floor.Instance.AssemblyLinearVelocity.Magnitude > 1 and slip:Lerp((root.AssemblyLinearVelocity - humanoid.MoveDirection * rig.speed) * Vector3.new(1, 0, 1), 0.1) or Vector3.zero
					local drift = slip.Magnitude > 3 and slip or Vector3.zero
					local entrance = sections[2] and sections[2]:FindFirstChild('start')
					if entrance and lplr.Character:FindFirstChild('currentSection') and lplr.Character.currentSection.Value == 1 and feet.Y < entrance.Position.Y - 18 then
						sunk = sunk or os.clock()
						if os.clock() - sunk > 4 then
							humanoid.Health = 0
						end
					else
						sunk = nil
					end
					local threat, low = getDanger(root.Position, root.Position, 0.35)
					if grounded and not launched and threat and low then
						humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					local entry = route and route[step]
					if entry then
						for _, v in {entry.from or entry.node, entry.node} do
							if v.part then
								v.position = v.part.CFrame * v.offset
							end
						end
					end
					if not entry then
						local lead = escape and (escape - feet) * Vector3.new(1, 0, 1)
						movement = lead and lead.Magnitude > 0.5 and lead.Unit or humanoid:GetState() == Enum.HumanoidStateType.Climbing and root.CFrame.LookVector * Vector3.new(1, 0, 1) or Vector3.zero
						if escape and grounded and escape.Y > feet.Y + 1 then
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
						for _, v in parts do
							v.Transparency = 1
						end
						if not planning and settled then
							planning = true
							task.spawn(function()
								local hit = workspace:Raycast(root.Position, Vector3.new(0, -rig.hover - 1.5, 0), params)
								local start, distance, nearest = hit and platforms[hit.Instance] and platforms[hit.Instance].node, 3, nil
								for i = feet.X // 4 - 2, feet.X // 4 + 2 do
									for i2 = feet.Y // 4 - 2, feet.Y // 4 + 2 do
										for i3 = feet.Z // 4 - 2, feet.Z // 4 + 2 do
											for _, v in cells[`{i},{i2},{i3}`] or {} do
												local flat = ((v.position - feet) * Vector3.new(1, 0, 1)).Magnitude
												if not (start and start.platform) and flat < distance and math.abs(v.position.Y - feet.Y) < 2 then
													start, distance = v, flat
												end
												if (grounded or v.position.Y > feet.Y - 3) and (not nearest or (v.position - feet).Magnitude < (nearest.position - feet).Magnitude) then
													nearest = v
												end
											end
										end
									end
								end
								if not start and not nearest then
									for _, v in nodes do
										if (v.position - feet).Magnitude < 60 and (grounded or v.position.Y > feet.Y - 3) and (not nearest or (v.position - feet).Magnitude < (nearest.position - feet).Magnitude) then
											nearest = v
										end
									end
								end
	
								local section = lplr.Character and lplr.Character:FindFirstChild('currentSection')
								local candidates = section and demos[math.max(section.Value, start and start.section or 0)]
								local list = (not candidates or (strikes[section.Value] or 0) < 3) and start and getPath(start)
								if list then
									table.insert(list, 1, {node = start})
								else
									for i = 1, candidates and #candidates or 0 do
										list = list or getDemo(candidates[((strikes[section.Value] or 0) + i - 1) % #candidates + 1].samples, feet)
									end
									if not list and start and candidates then
										local goals = {}
										for _, v in candidates do
											for i = 1, #v.samples, 3 do
												local position = v.samples[i].position - Vector3.new(0, rig.hover, 0)
												for _, v2 in v.samples[i].grounded and cells[`{position.X // 4},{position.Y // 4},{position.Z // 4}`] or {} do
													if ((v2.position - position) * Vector3.new(1, 0, 1)).Magnitude < 1.5 and math.abs(v2.position.Y - position.Y) < 1.5 then
														goals[v2] = v
													end
												end
											end
										end
										local path = next(goals) and getPath(start, goals)
										local goal = path and (path[1] and path[#path].node or start)
										local demo = goal and goals[goal] and getDemo(goals[goal].samples, goal.position)
										if path and (demo or not goals[goal]) then
											list = path
											table.insert(list, 1, {node = start})
											for _, v in demo or {} do
												table.insert(list, v)
											end
										end
									end
								end
								escape = not list and not start and nearest and nearest.position or nil
								if list and built then
									route, step, began, launched = list, start and start.platform and list[1].node == start and 2 or 1, os.clock(), nil
									for i, v in parts do
										v.Position = list[math.ceil(i * #list / #parts)].node.position + Vector3.new(0, 0.25, 0)
										v.Transparency = Path.Enabled and 0.3 or 1
									end
								else
									task.wait(1)
								end
								planning = nil
							end)
						end
						return
					end
	
					local target, source = entry.node.platform, entry.from and entry.from.platform
					local flat = (entry.node.position - feet) * Vector3.new(1, 0, 1)
					if os.clock() - began > (entry.time or 0) + ((target or source) and 12 or 2.5) or feet.Y < math.min(entry.node.position.Y, entry.from and entry.from.position.Y or feet.Y) - 6 then
						if entry.from then
							blocked[`{entry.from.index},{entry.node.index}`] = (blocked[`{entry.from.index},{entry.node.index}`] or 0) + 2
						end
						if lplr.Character:FindFirstChild('currentSection') then
							strikes[lplr.Character.currentSection.Value] = (strikes[lplr.Character.currentSection.Value] or 0) + 1
						end
						route, launched, waited = nil, nil, nil
						return
					end
	
					if not entry.jump then
						local danger = entry.node.part and not (floor and floor.Instance == entry.node.part) and ((entry.node.part.CFrame:PointToObjectSpace(feet):Abs() - entry.node.part.Size / 2) * Vector3.new(1, 0, 1)):Max(Vector3.zero).Magnitude > 1.5 or flat.Magnitude > 0.1 and getDanger(root.Position, root.Position + flat.Unit * math.min(flat.Magnitude, 4), 0.8)
						waited, began = danger and (waited or os.clock()) or nil, danger and (os.clock() - (waited or os.clock()) < 10 and os.clock() or 0) or began
						local climbing, above = humanoid:GetState() == Enum.HumanoidStateType.Climbing, entry.node.position.Y > feet.Y + 1.2
						movement = not danger and (flat.Magnitude > 0.1 and flat.Unit or climbing and above and root.CFrame.LookVector * Vector3.new(1, 0, 1)) or Vector3.zero
						if grounded and not climbing and not danger and (above and flat.Magnitude < 2 or flat.Magnitude > 1 and drift:Dot(flat.Unit) < -rig.speed * 0.5 or flat.Magnitude > 1 and os.clock() - began > 0.6 and root.AssemblyLinearVelocity:Dot(flat.Unit) < 2) then
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
						if flat.Magnitude < 0.8 and math.abs(entry.node.position.Y - feet.Y) < 2 then
							step, began = step + 1, os.clock()
						end
					elseif entry.climb and not launched then
						local lead = (entry.from.position - feet) * Vector3.new(1, 0, 1)
						local synced = true
						if entry.phase and os.clock() - (waited or os.clock()) < 6 and not (floor and platforms[floor.Instance]) then
							for i, v in entry.phase do
								if (i.Position - v.Position).Magnitude > 2 or i.CFrame.LookVector:Dot(v.LookVector) < 0.94 then
									synced = false
								end
							end
						end
						waited, began = not synced and (waited or os.clock()) or nil, not synced and (os.clock() - (waited or os.clock()) < 12 and os.clock() or 0) or began
						movement = lead.Magnitude > 0.1 and lead.Unit or Vector3.zero
						if lead.Magnitude < 0.6 and grounded and synced then
							launched = os.clock()
						end
					elseif entry.climb then
						local core = entry.climb.half - Vector3.new(1, 0, 1) * math.min(entry.climb.half.X, entry.climb.half.Z)
						local axis = (entry.climb.position + ((feet - entry.climb.position) * Vector3.new(1, 0, 1)):Max(-core):Min(core) - feet) * Vector3.new(1, 0, 1)
						if feet.Y < entry.node.position.Y + 0.6 and not (grounded and feet.Y > entry.node.position.Y - 0.5) then
							movement = axis.Magnitude > 0.1 and axis.Unit or Vector3.zero
							if grounded and ((((feet - entry.climb.position) * Vector3.new(1, 0, 1)):Abs() - entry.climb.half):Max(Vector3.zero).Magnitude > 1.2 or feet.Y + 4.5 < entry.climb.bottom) then
								humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
							if humanoid:GetState() == Enum.HumanoidStateType.Climbing and root.AssemblyLinearVelocity.Y < 1 and axis.Magnitude > 1 and os.clock() - launched > 1 then
								humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								launched = os.clock()
							end
						else
							movement = flat.Magnitude > 0.1 and flat.Unit or Vector3.zero
							if humanoid:GetState() == Enum.HumanoidStateType.Climbing and (((entry.node.position - entry.climb.position) * Vector3.new(1, 0, 1)):Abs() - entry.climb.half):Max(Vector3.zero).Magnitude > 0.5 then
								humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
						if grounded and feet.Y > entry.node.position.Y - 1 and flat.Magnitude < 1.5 then
							step, began, launched = step + 1, os.clock(), nil
						end
					elseif not launched then
						local direction = (entry.node.position - entry.from.position) * Vector3.new(1, 0, 1)
						direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.zero
						local takeoff = source and source.part.Position or entry.from.position + direction * entry.takeoff
						local lead = (takeoff - feet) * Vector3.new(1, 0, 1)
						local lateral = lead - direction * lead:Dot(direction)
						local settle = source or entry.delay > 0.05 or os.clock() - began > 1.5
						if settle then
							movement = lead.Magnitude > (source and 0.4 or 0.1) and lead.Unit * math.clamp(lead.Magnitude * 1.5, 0.3, 1) or Vector3.zero
						else
							movement = (lead:Dot(direction) > 1.5 or lateral.Magnitude > 0.35 or lead:Dot(direction) < -0.5) and lead.Magnitude > 0.1 and lead.Unit or (lead + direction * 2).Magnitude > 0.1 and (lead + direction * 2).Unit or Vector3.zero
						end
						if grounded and lead.Magnitude > 0.8 and drift:Dot(lead.Unit) < -rig.speed * 0.5 then
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
						if grounded and (source or settle and lead.Magnitude < 0.35 or not settle and lead.Magnitude < 0.8 and lead:Dot(direction) <= 0.15 and lateral.Magnitude < 0.35 and root.AssemblyLinearVelocity:Dot(direction) > -1 or lead.Magnitude < 1.5 and drift.Magnitude > rig.speed * 0.5) then
							local choice = not target and not source and {}
							if target then
								for _, v in target.samples do
									local point = target.part.CFrame * v
									local reach = entry.jump * entry.jump - 2 * rig.gravity * (point.Y - feet.Y - rig.lift + 0.1)
									if reach >= 0 then
										local time = (entry.jump + math.sqrt(reach)) / rig.gravity
										point = target.center + target.linear * time + CFrame.fromAxisAngle(target.angular.Magnitude > 0.0001 and target.angular.Unit or Vector3.yAxis, target.angular.Magnitude * time) * (point - target.center)
										if rig.speed * time - ((point - feet) * Vector3.new(1, 0, 1)).Magnitude > 1.2 and (not choice or v.Magnitude < choice[1].Magnitude) then
											local safe = true
											for _, v2 in rig.kills do
												probe.Size, probe.CFrame = v2[1], CFrame.new(point + Vector3.new(0, rig.hover, 0) + v2[2])
												safe = safe and not workspace:GetPartsInPart(probe, killoverlap)[1]
											end
											if safe then
												choice = {v}
											end
										end
									end
								end
							elseif source then
								local reach = entry.jump * entry.jump - 2 * rig.gravity * (entry.node.position.Y - feet.Y - rig.lift + 0.1)
								choice = reach >= 0 and rig.speed * (entry.jump + math.sqrt(reach)) / rig.gravity - flat.Magnitude > 1 and {}
							end
							local synced = true
							if entry.phase and os.clock() - (waited or os.clock()) < 6 and not (floor and platforms[floor.Instance]) then
								for i, v in entry.phase do
									if (i.Position - v.Position).Magnitude > 2 or i.CFrame.LookVector:Dot(v.LookVector) < 0.94 then
										synced = false
									end
								end
							end
							local motion = entry.node.part and platforms[entry.node.part]
							if motion and not (floor and floor.Instance == entry.node.part) then
								local elapsed = entry.time or 0.5
								local predicted = CFrame.new(motion.center + motion.linear * elapsed) * CFrame.fromAxisAngle(motion.angular.Magnitude > 0.0001 and motion.angular.Unit or Vector3.yAxis, motion.angular.Magnitude * elapsed) * entry.node.part.CFrame.Rotation
								synced = (predicted.Position - entry.node.frame.Position).Magnitude < 2 and predicted.LookVector:Dot(entry.node.frame.LookVector) > 0.94
							end
							local danger = choice and (not synced or getDanger(root.Position, entry.node.position + Vector3.new(0, rig.hover, 0), entry.time or 0.5, entry.jump > 0 and entry.jump or nil))
							waited, began = danger and (waited or os.clock()) or nil, danger and (os.clock() - (waited or os.clock()) < 10 and os.clock() or 0) or began
							if choice and not danger then
								launched, airborne, peak, aim, bent = os.clock(), nil, 0, choice[1], nil
								if entry.jump > 0 then
									humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
							end
						end
					else
						local elapsed = os.clock() - launched
						local velocity = root.AssemblyLinearVelocity
						local destination = entry.node.position
						if target and aim then
							local point = target.part.CFrame * aim
							local reach = velocity.Y * velocity.Y + 2 * rig.gravity * (feet.Y - point.Y + (velocity.Y * velocity.Y + 2 * rig.gravity * (feet.Y - point.Y) < 0 and rig.lift or 0))
							local time = reach >= 0 and (velocity.Y + math.sqrt(reach)) / rig.gravity or 0
							destination = target.center + target.linear * time + CFrame.fromAxisAngle(target.angular.Magnitude > 0.0001 and target.angular.Unit or Vector3.yAxis, target.angular.Magnitude * time) * (point - target.center)
						end
						flat = (destination - feet) * Vector3.new(1, 0, 1)
						local high = velocity.Y * velocity.Y + 2 * rig.gravity * (feet.Y - destination.Y) < 0
						local reach = velocity.Y * velocity.Y + 2 * rig.gravity * (feet.Y - destination.Y + (high and rig.lift or 0))
						local remaining = high and velocity.Y > 0 and velocity.Y / rig.gravity + 0.05 or reach >= 0 and (velocity.Y + math.sqrt(reach)) / rig.gravity or 0
						local rate = remaining > 0.05 and flat.Magnitude / remaining / rig.speed or 1
						airborne, peak = airborne or not grounded, math.max(peak, velocity.Y)
						bent = bent or not entry.bend or ((feet - entry.bend) * Vector3.new(1, 0, 1)):Dot((entry.node.position - entry.bend) * Vector3.new(1, 0, 1)) > 0 or ((entry.bend - feet) * Vector3.new(1, 0, 1)).Magnitude < 0.8
						movement = flat.Magnitude > 0.1 and elapsed >= entry.delay and (not bent and ((entry.bend - feet) * Vector3.new(1, 0, 1)).Unit or flat.Unit * math.clamp(entry.jump > 0 and rate or 1, 0, 1)) or Vector3.zero
						if entry.path then
							local point = entry.path[#entry.path][2]
							for i = 2, #entry.path do
								if entry.path[i][1] >= elapsed + 0.1 + entry.takeoff / rig.speed then
									point = entry.path[i - 1][2]:Lerp(entry.path[i][2], math.clamp((elapsed + 0.1 + entry.takeoff / rig.speed - entry.path[i - 1][1]) / math.max(entry.path[i][1] - entry.path[i - 1][1], 0.001), 0, 1))
									break
								end
							end
							local lead = (point - feet) * Vector3.new(1, 0, 1)
							movement = lead.Magnitude > 0.1 and lead.Unit * math.clamp(lead.Magnitude / 0.1 / rig.speed, 0, 1) or Vector3.zero
						end
						if humanoid:GetState() == Enum.HumanoidStateType.Climbing and feet.Y <= destination.Y - 1 and flat.Magnitude < 1 then
							movement = root.CFrame.LookVector * Vector3.new(1, 0, 1)
						end
						if (grounded or humanoid:GetState() == Enum.HumanoidStateType.Climbing and feet.Y > destination.Y - 1) and (airborne or elapsed > 0.3 and flat.Magnitude < 1 and math.abs(destination.Y - feet.Y) < 1) then
							if entry.jump > 0 and peak > 20 and peak < 150 then
								rig.jump = math.max(rig.jump, peak)
							end
							launched = nil
							local hit, support = workspace:Raycast(root.Position, Vector3.new(0, -rig.hover - 1.5, 0), params), not target and workspace:Raycast(destination + Vector3.new(0, 1, 0), Vector3.new(0, -4, 0), params)
							if target and hit and hit.Instance == target.part or not target and (flat.Magnitude < 2.5 and math.abs(destination.Y - feet.Y) < 1.5 or flat.Magnitude < 6 and hit and support and hit.Instance == support.Instance) then
								step, began = step + 1, os.clock()
							else
								blocked[`{entry.from.index},{entry.node.index}`] = (blocked[`{entry.from.index},{entry.node.index}`] or 0) + 1
								if lplr.Character:FindFirstChild('currentSection') then
									strikes[lplr.Character.currentSection.Value] = (strikes[lplr.Character.currentSection.Value] or 0) + 1
								end
								route = nil
							end
						end
					end
	
					if grounded and not launched and movement and drift.Magnitude > 1 then
						movement -= drift / rig.speed
						movement = movement.Magnitude > 1 and movement.Unit or movement
					end
				end))
			else
				toh.Controls.moveFunction = old
				route, rig, built, tower, launched, aim, bent, movement, planning, building, escape, sunk, hovered = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
				version += 1
				table.clear(nodes)
				table.clear(cells)
				table.clear(sections)
				table.clear(moving)
				table.clear(hazards)
				table.clear(platforms)
				table.clear(trusses)
				table.clear(blocked)
				table.clear(parts)
				table.clear(tracks)
				table.clear(demos)
				table.clear(strikes)
				table.clear(watched)
				if folder then
					folder:Destroy()
					folder = nil
				end
				if probe then
					probe:Destroy()
					probe = nil
				end
			end
		end,
		Tooltip = 'Climbs the tower for you by walking and jumping like a player. It maps every section, plans the jumps it can actually make, times jumps onto moving platforms and steers around kill bricks.'
	})
	
	Path = AutoPlay:CreateToggle({
		Name = 'Path',
		Function = function(callback)
			for _, v in parts do
				v.Transparency = callback and route and 0.3 or 1
			end
		end,
		Default = true,
		Tooltip = 'Draws the route it is following.'
	})
	Color = AutoPlay:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in parts do
				v.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		DefaultHue = 0.44
	})
end)