local navigation = {}
local cellSize = 3
local halfCell = 1.5
local keySpan = 8192
local keyHalf = 4096
local keyPlane = 67108864
local faces = {
	{1, 0, 0},
	{-1, 0, 0},
	{0, 1, 0},
	{0, -1, 0},
	{0, 0, 1},
	{0, 0, -1}
}
local flats = {
	{1, 0, 0},
	{-1, 0, 0},
	{0, 0, 1},
	{0, 0, -1},
	{1, 0, 1},
	{1, 0, -1},
	{-1, 0, 1},
	{-1, 0, -1}
}
local saves = {
	{1, 0, 0},
	{-1, 0, 0},
	{0, 0, 1},
	{0, 0, -1},
	{1, 0, 1},
	{-1, 0, -1},
	{-1, 0, 1},
	{1, 0, -1},
	{0, -1, 0}
}
local leaps = {
	{2, 0, 1},
	{2, 0, -1},
	{-2, 0, 1},
	{-2, 0, -1},
	{1, 0, 2},
	{-1, 0, 2},
	{1, 0, -2},
	{-1, 0, -2}
}
local corners = {}

for x = -1, 1 do
	for y = -1, 1 do
		for z = -1, 1 do
			if math.abs(x) + math.abs(y) + math.abs(z) > 1 then
				table.insert(corners, {x, y, z})
			end
		end
	end
end

export type Grid = Vector3
export type Placement = {
	Grid: Grid,
	Position: Vector3,
	Mode: string,
	PlacementType: string,
	SupportGrid: Grid?,
	Normal: Vector3?,
	AimPosition: Vector3?,
	AimDirection: Vector3?,
	Distance: number,
	Valid: boolean,
	Reason: string?
}
export type Action = {
	Type: string,
	Grid: Grid,
	Position: Vector3,
	Time: number,
	Duration: number,
	PlacementType: string?,
	Preconditions: {[string]: any}?
}
export type Result = {
	Success: boolean,
	Partial: boolean,
	Reason: string,
	Mode: string,
	WalkingPath: {Vector3},
	BridgePath: {Placement},
	Actions: {Action},
	Cost: number,
	Distance: number,
	BlocksUsed: number,
	Damage: number
}

navigation.GridSize = cellSize
navigation.CellBounds = Vector3.new(cellSize - 0.1, cellSize - 0.1, cellSize - 0.1)
navigation.Contexts = {}
navigation.Requests = {}
navigation.World = nil
navigation.DebugAdapter = nil
navigation.Profiles = {
	Default = {
		Name = 'block',
		Solid = true,
		Support = true,
		Placeable = true,
		Breakable = true,
		Climbable = false,
		Replaceable = false,
		Temporary = false,
		Cost = 0
	}
}
navigation.Config = {
	Agent = {
		Height = 5,
		Radius = 1,
		HipHeight = 3,
		BodyOffset = 1,
		HeadOffset = 2.2,
		HeadRadius = 0.6,
		WalkSpeed = 22,
		JumpVelocity = 42.6,
		Gravity = 196.2,
		Reach = 18,
		PlaceCps = 12,
		Latency = 0.08,
		MaxDrop = 27,
		ImpactLimit = 86,
		DamageScale = 0.75,
		DamageAllowance = 0,
		SafeMargin = 1,
		BlocksAvailable = math.huge
	},
	Costs = {
		Block = 1,
		Jump = 0.06,
		Drop = 0.04,
		Diagonal = 0.02,
		Risk = 0.5,
		Air = 0.25,
		Scarce = 4
	},
	Traversal = {
		Mover = 'Jump',
		MaxAirTime = 1.75,
		Margin = 1,
		Rise = 1,
		Instant = false
	},
	Retreat = {
		MaxTime = 6,
		MaxSteps = 6000,
		SafeDistance = 40,
		Weights = {
			Distance = 10,
			Passage = 4,
			Escape = 2,
			Edge = 4,
			Exposure = 3,
			Time = 0.5
		}
	},
	Search = {
		MaxSteps = 40000,
		WalkSteps = 40000,
		Budget = 0.012,
		Weight = 1.3,
		BridgeWeight = 2,
		Fallback = false,
		FieldMargin = 16,
		Tolerance = 1,
		GoalDrop = 3,
		Free = true,
		BridgeWidth = 1,
		Yield = true,
		Smooth = true,
		Bridge = true,
		Tower = true,
		JumpGap = true
	},
	Clutch = {
		Reach = 14,
		MaxFall = math.huge,
		Void = true,
		MaxBlocks = 4,
		MaxChain = 3,
		SampleTime = 0.05,
		MinSurvival = 0.55,
		ReachSteps = 16,
		Scan = 90,
		Width = 1,
		Anchored = true,
		Weights = {
			Survival = 100,
			Damage = 0.9,
			Blocks = 4,
			Escape = 6,
			Distance = 0.35
		}
	}
}

local function gridAxis(value)
	return math.round(value / cellSize)
end

local function cellKey(x, y, z)
	return (x + keyHalf) * keyPlane + (y + keyHalf) * keySpan + (z + keyHalf)
end

function navigation.WorldToGrid(pos)
	return Vector3.new(math.round(pos.X / cellSize), math.round(pos.Y / cellSize), math.round(pos.Z / cellSize))
end

function navigation.GridToWorld(grid)
	return Vector3.new(grid.X * cellSize, grid.Y * cellSize, grid.Z * cellSize)
end

function navigation.SnapToGrid(pos)
	return Vector3.new(math.round(pos.X / cellSize) * cellSize, math.round(pos.Y / cellSize) * cellSize, math.round(pos.Z / cellSize) * cellSize)
end

function navigation.SetGridSize(size)
	cellSize = size
	halfCell = size / 2
	navigation.GridSize = size
	navigation.CellBounds = Vector3.new(size - 0.1, size - 0.1, size - 0.1)
end

local worldClass = {}
worldClass.__index = worldClass

function worldClass.Solid(self, x, y, z)
	local key = cellKey(x, y, z)
	if self.Overlay then
		local entry = self.Overlay[key]
		if entry ~= nil then
			return entry ~= false
		end
	end

	local cached = self.Cells[key]
	if cached ~= nil then
		return cached
	end

	local solid = self.Hooks.GetBlock and self.Hooks.GetBlock(x, y, z) and true or false
	if not solid and self.Hooks.IsSolid then
		solid = self.Hooks.IsSolid(x, y, z) and true or false
	end

	self.Cells[key] = solid
	return solid
end

function worldClass.Block(self, x, y, z)
	local key = cellKey(x, y, z)
	if self.Overlay then
		local entry = self.Overlay[key]
		if entry ~= nil then
			return entry ~= false and entry or nil
		end
	end

	local cached = self.Blocks[key]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local block = self.Hooks.GetBlock and self.Hooks.GetBlock(x, y, z) or false
	self.Blocks[key] = block
	return block ~= false and block or nil
end

function worldClass.Profile(self, block)
	if not block then
		return nil
	end
	return self.Hooks.GetProfile and self.Hooks.GetProfile(block) or navigation.Profiles.Default
end

function worldClass.Invalidate(self, x, y, z)
	if self.Land and #self.Pending >= 4096 then
		self.Land = nil
	elseif self.Land then
		table.insert(self.Pending, Vector3.new(x, y, z))
	end

	local key = cellKey(x, y, z)
	if self.Cells[key] == nil and self.Blocks[key] == nil then
		return
	end

	self.Cells[key] = nil
	self.Blocks[key] = nil
	self.Revision += 1

	if self.DirtyIndex >= 512 then
		table.clear(self.Dirty)
		self.DirtyIndex = 0
		self.Flush += 1
		return
	end

	self.DirtyIndex += 1
	self.Dirty[self.DirtyIndex] = key
end

function worldClass.Touch(self)
	table.clear(self.Cells)
	table.clear(self.Blocks)
	table.clear(self.Dirty)
	self.DirtyIndex = 0
	self.Revision += 1
	self.Flush += 1
	self.Land = nil
end

function worldClass.Columns(self, budget)
	if not self.Hooks.GetBlocks then
		return nil
	end

	local slice = budget and os.clock() + budget
	if not self.Land then
		local land, x0, x1, z0, z1 = {}, math.huge, -math.huge, math.huge, -math.huge
		self.Land, self.Pending, self.Bounds = land, {}, {x0, x1, z0, z1}
		for _, v in self.Hooks.GetBlocks() do
			local key = cellKey(v.X, 0, v.Z)
			land[key] = math.max(land[key] or v.Y, v.Y)
			x0, x1, z0, z1 = math.min(x0, v.X), math.max(x1, v.X), math.min(z0, v.Z), math.max(z1, v.Z)
			if slice and os.clock() >= slice then
				task.wait()
				slice = os.clock() + budget
			end
		end
		self.Bounds = {x0, x1, z0, z1}
		self.LandVersion += 1
	end

	for _, v in self.Pending do
		local key = cellKey(v.X, 0, v.Z)
		local top = self.Land[key]
		if (top or -math.huge) < v.Y and self.Hooks.GetBlock(v.X, v.Y, v.Z) then
			self.LandVersion += top and 0 or 1
			self.Land[key] = v.Y
			self.Bounds[1], self.Bounds[2], self.Bounds[3], self.Bounds[4] = math.min(self.Bounds[1], v.X), math.max(self.Bounds[2], v.X), math.min(self.Bounds[3], v.Z), math.max(self.Bounds[4], v.Z)
		elseif top == v.Y and not self.Hooks.GetBlock(v.X, v.Y, v.Z) then
			local lower = nil
			for i = v.Y - 1, v.Y - 64, -1 do
				if self.Hooks.GetBlock(v.X, i, v.Z) then
					lower = i
					break
				end
			end
			self.Land[key] = lower
			self.LandVersion += lower and 0 or 1
		end
	end
	table.clear(self.Pending)
	return self.Land
end

function worldClass.Field(self, from, goal, margin, mode, budget)
	if not self:Columns(budget) then
		return nil
	end

	local goalKey = cellKey(goal.x, 0, goal.z)
	local x0, x1 = math.min(self.Bounds[1], from.x, goal.x) - margin, math.max(self.Bounds[2], from.x, goal.x) + margin
	local z0, z1 = math.min(self.Bounds[3], from.z, goal.z) - margin, math.max(self.Bounds[4], from.z, goal.z) + margin
	for _, v in {self.FieldCache, self.FieldPrevious} do
		if v.Goal == goalKey and v.Mode == mode and v.Version == self.LandVersion and v.Box[1] <= x0 and v.Box[2] >= x1 and v.Box[3] <= z0 and v.Box[4] >= z1 then
			return v.Costs, self.Land, v.Box, v.Tops
		end
	end

	local slice = budget and os.clock() + budget
	local costs = {[goalKey] = 0}
	local tops = {[goalKey] = self.Land[goalKey] or goal.y - 1}
	local buckets = {[0] = {goal.x, goal.z}}
	local level, last = 0, 0

	while level <= last do
		local bucket = buckets[level]
		local i = 1
		while bucket and i < #bucket do
			local x, z = bucket[i], bucket[i + 1]
			i += 2

			local column = cellKey(x, 0, z)
			if costs[column] == level then
				for _, v in flats do
					local tx, tz = x + v[1], z + v[3]
					local key = cellKey(tx, 0, tz)
					local cost = level + (self.Land[key] and 0 or (mode ~= 'Blatant' and v[1] ~= 0 and v[3] ~= 0 and 2 or 1))
					if tx >= x0 and tx <= x1 and tz >= z0 and tz <= z1 and (costs[key] or math.huge) > cost then
						costs[key] = cost
						tops[key] = self.Land[key] or tops[column]
						buckets[cost] = buckets[cost] or {}
						table.insert(buckets[cost], tx)
						table.insert(buckets[cost], tz)
						last = math.max(last, cost)
					end
				end
			end

			if slice and os.clock() >= slice then
				task.wait()
				slice = os.clock() + budget
			end
		end

		buckets[level] = nil
		level += 1
	end

	self.FieldPrevious, self.FieldCache = self.FieldCache, {Goal = goalKey, Mode = mode, Version = self.LandVersion, Box = {x0, x1, z0, z1}, Costs = costs, Tops = tops}
	return costs, self.Land, self.FieldCache.Box, tops
end

function worldClass.Begin(self, overlay)
	self.Overlay = overlay or {}
	return self.Overlay
end

function worldClass.Finish(self)
	self.Overlay = nil
end

function worldClass.Write(self, x, y, z, block)
	if self.Overlay then
		self.Overlay[cellKey(x, y, z)] = block or false
	end
end

function navigation.newWorld(hooks)
	return setmetatable({
		Hooks = hooks or {},
		Cells = {},
		Blocks = {},
		Dirty = {},
		DirtyIndex = 0,
		Revision = 0,
		Flush = 0,
		Pending = {},
		LandVersion = 0,
		Overlay = nil
	}, worldClass)
end

local function fallTime(drop, speed, gravity)
	local inner = speed * speed + 2 * gravity * drop
	if inner < 0 then
		return nil
	end
	return (speed + math.sqrt(inner)) / gravity
end

local function impactSpeed(drop, speed, gravity)
	return math.sqrt(math.max(speed * speed + 2 * gravity * drop, 0))
end

local function fallDamage(impact, agent)
	return impact > agent.ImpactLimit and (impact - agent.ImpactLimit) * agent.DamageScale or 0
end

local function safeDrop(speed, agent)
	local limit = agent.ImpactLimit + agent.DamageAllowance / agent.DamageScale
	local budget = (limit * limit - speed * speed) / (2 * agent.Gravity)
	return budget > 0 and budget * agent.SafeMargin or 0
end

local function jumpLand(agent, rise)
	local inner = agent.JumpVelocity * agent.JumpVelocity - 2 * agent.Gravity * rise
	if inner < 0 then
		return nil
	end
	return (agent.JumpVelocity + math.sqrt(inner)) / agent.Gravity
end

local function jumpHeight(agent, elapsed)
	return agent.JumpVelocity * elapsed - agent.Gravity * elapsed * elapsed * 0.5
end

local function traverse(agent, traversal, horizontal, vertical, speed)
	local needed = horizontal + traversal.Margin
	if traversal.Mover == 'Glide' then
		if vertical > traversal.Rise * cellSize then
			return false, 0, 0, 'TooHigh'
		end
		local climb = traversal.Instant and 0 or math.abs(vertical)
		local airtime = (needed + climb) / speed
		return airtime <= traversal.MaxAirTime, airtime, speed * traversal.MaxAirTime - climb - traversal.Margin, airtime <= traversal.MaxAirTime and 'Traversable' or 'AirTime'
	end

	local airtime = jumpLand(agent, vertical)
	if not airtime then
		return false, 0, 0, 'TooHigh'
	end
	local reach = speed * math.min(airtime, traversal.MaxAirTime) - traversal.Margin
	return reach >= horizontal, airtime, reach, reach >= horizontal and 'Traversable' or (airtime > traversal.MaxAirTime and 'AirTime' or 'Distance')
end

local function newContext(world, agent, mode)
	return {
		World = world,
		Agent = agent,
		Mode = mode,
		Fits = {},
		Stands = {},
		Height = math.max(math.ceil(agent.Height / cellSize), 1),
		Revision = world.Revision,
		Dirty = world.DirtyIndex,
		Flush = world.Flush
	}
end

local function refresh(ctx)
	local world = ctx.World
	if ctx.Revision == world.Revision then
		return
	end

	if ctx.Flush ~= world.Flush then
		table.clear(ctx.Fits)
		table.clear(ctx.Stands)
	else
		for i = ctx.Dirty + 1, world.DirtyIndex do
			for i2 = -ctx.Height, 1 do
				local shifted = world.Dirty[i] + i2 * keySpan
				ctx.Fits[shifted] = nil
				ctx.Stands[shifted] = nil
			end
		end
	end

	ctx.Revision = world.Revision
	ctx.Dirty = world.DirtyIndex
	ctx.Flush = world.Flush
end

local function fits(ctx, x, y, z)
	local key = cellKey(x, y, z)
	local cached = ctx.Fits[key]
	if cached ~= nil then
		return cached
	end

	local clear = true
	for i = 0, ctx.Height - 1 do
		if ctx.World:Solid(x, y + i, z) then
			clear = false
			break
		end
	end

	ctx.Fits[key] = clear
	return clear
end

local function stands(ctx, x, y, z)
	local key = cellKey(x, y, z)
	local cached = ctx.Stands[key]
	if cached ~= nil then
		return cached
	end

	local ok = ctx.World:Solid(x, y - 1, z) and fits(ctx, x, y, z)
	ctx.Stands[key] = ok
	return ok
end

local function canCutCorner(ctx, x, y, z, dx, dz)
	return fits(ctx, x + dx, y, z) and fits(ctx, x, y, z + dz)
end

local function traceClear(ctx, origin, target, skipA, skipB)
	local dx, dy, dz = target.X - origin.X, target.Y - origin.Y, target.Z - origin.Z
	local x, y, z = gridAxis(origin.X), gridAxis(origin.Y), gridAxis(origin.Z)
	local stepX, nextX, deltaX = 0, math.huge, math.huge
	local stepY, nextY, deltaY = 0, math.huge, math.huge
	local stepZ, nextZ, deltaZ = 0, math.huge, math.huge

	if dx ~= 0 then
		stepX = dx > 0 and 1 or -1
		nextX = ((x + stepX * 0.5) * cellSize - origin.X) / dx
		deltaX = cellSize / math.abs(dx)
	end
	if dy ~= 0 then
		stepY = dy > 0 and 1 or -1
		nextY = ((y + stepY * 0.5) * cellSize - origin.Y) / dy
		deltaY = cellSize / math.abs(dy)
	end
	if dz ~= 0 then
		stepZ = dz > 0 and 1 or -1
		nextZ = ((z + stepZ * 0.5) * cellSize - origin.Z) / dz
		deltaZ = cellSize / math.abs(dz)
	end

	for _ = 1, 64 do
		if nextX > 1 and nextY > 1 and nextZ > 1 then
			return true
		end

		if nextX <= nextY and nextX <= nextZ then
			x, nextX = x + stepX, nextX + deltaX
		elseif nextY <= nextZ then
			y, nextY = y + stepY, nextY + deltaY
		else
			z, nextZ = z + stepZ, nextZ + deltaZ
		end

		local key = cellKey(x, y, z)
		if key ~= skipA and key ~= skipB and ctx.World:Solid(x, y, z) then
			return false
		end
	end

	return true
end

local function bodyBlocked(ctx, state, x, y, z)
	local reach = halfCell + state.HeadRadius
	if math.abs(state.Head.X - x * cellSize) < reach and math.abs(state.Head.Y - y * cellSize) < reach and math.abs(state.Head.Z - z * cellSize) < reach then
		return true
	end

	if state.BodyHeight > 1 and x == state.BodyX and z == state.BodyZ then
		local low = state.BodyY + (ctx.World:Block(state.BodyX, state.BodyY + state.BodyHeight, state.BodyZ) and 0 or 1)
		if y >= low and y <= state.BodyY + state.BodyHeight - 1 then
			return true
		end
	end

	return false
end

local function supportAt(ctx, x, y, z, mode, extra)
	local world = ctx.World
	local best, score = nil, -1

	for _, v in faces do
		local sx, sy, sz = x + v[1], y + v[2], z + v[3]
		if world:Solid(sx, sy, sz) or cellKey(sx, sy, sz) == extra then
			local block = world:Block(sx, sy, sz)
			if not block or world:Profile(block).Support then
				local rank = v[2] == 0 and 2 or (v[2] < 0 and 1 or 0)
				if rank > score then
					best, score = v, rank
				end
			end
		end
	end

	if best then
		return x + best[1], y + best[2], z + best[3], -best[1], -best[2], -best[3], 'Face'
	end

	if mode ~= 'Blatant' then
		return nil
	end

	for _, v in corners do
		local sx, sy, sz = x + v[1], y + v[2], z + v[3]
		if world:Solid(sx, sy, sz) or cellKey(sx, sy, sz) == extra then
			local block = world:Block(sx, sy, sz)
			if not block or world:Profile(block).Support then
				local rank = v[2] == 0 and 2 or (v[2] < 0 and 1 or 0)
				if rank > score then
					best, score = v, rank
				end
			end
		end
	end

	if best then
		return x + best[1], y + best[2], z + best[3], -best[1], -best[2], -best[3], 'Diagonal'
	end

	return nil
end

local function placementAt(ctx, state, x, y, z, mode, extra, quick)
	local block = ctx.World:Block(x, y, z)
	if block and not ctx.World:Profile(block).Replaceable then
		return nil, 'Occupied'
	elseif not block and ctx.World:Solid(x, y, z) then
		return nil, 'Occupied'
	end

	if bodyBlocked(ctx, state, x, y, z) then
		return nil, 'Body'
	end

	local sx, sy, sz, nx, ny, nz, kind = supportAt(ctx, x, y, z, mode, extra)
	if not sx and not ctx.Floating then
		return nil, 'Support'
	end

	local aim = Vector3.new(x * cellSize, y * cellSize - halfCell, z * cellSize)
	if sx and math.abs(nx) + math.abs(ny) + math.abs(nz) == 1 then
		aim = Vector3.new(sx * cellSize + nx * halfCell, sy * cellSize + ny * halfCell, sz * cellSize + nz * halfCell)
	elseif sx then
		aim = Vector3.new(math.clamp(x * cellSize, sx * cellSize - halfCell, sx * cellSize + halfCell), math.clamp(y * cellSize, sy * cellSize - halfCell, sy * cellSize + halfCell), math.clamp(z * cellSize, sz * cellSize - halfCell, sz * cellSize + halfCell))
	end

	local distance = (aim - state.Position).Magnitude
	if distance > ctx.Reach then
		return nil, 'Reach'
	end

	if not quick and not traceClear(ctx, state.Eye, aim, sx and cellKey(sx, sy, sz) or 0, cellKey(x, y, z)) then
		return nil, 'Sight'
	end

	local direction = aim - state.Eye
	return {
		Grid = Vector3.new(x, y, z),
		Position = Vector3.new(x * cellSize, y * cellSize, z * cellSize),
		Mode = mode,
		PlacementType = sx and kind or 'Float',
		SupportGrid = sx and Vector3.new(sx, sy, sz) or nil,
		Normal = sx and Vector3.new(-nx, -ny, -nz) or nil,
		AimPosition = aim,
		AimDirection = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, -1, 0),
		AimCFrame = direction.Magnitude > 0 and CFrame.lookAt(state.Eye, aim) or nil,
		Distance = distance,
		Valid = true
	}
end

local function voidSave(ctx, state)
	for i = 1, 3 do
		local y = gridAxis(state.Position.Y - i * cellSize)
		for _, v in saves do
			if ctx.World:Solid(state.CellX + v[1], y + v[2], state.CellZ + v[3]) then
				return state.CellX, y, state.CellZ
			end
		end
	end

	return nil
end

local function heapPush(heap, node)
	local i = #heap + 1
	heap[i] = node

	while i > 1 do
		local parent = i // 2
		if heap[parent].f <= heap[i].f then break end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function heapPop(heap)
	local size = #heap
	if size == 0 then
		return nil
	end

	local top = heap[1]
	heap[1] = heap[size]
	heap[size] = nil
	size -= 1

	local i = 1
	while true do
		local left = i * 2
		local right = left + 1
		local best = i
		if left <= size and heap[left].f < heap[best].f then best = left end
		if right <= size and heap[right].f < heap[best].f then best = right end
		if best == i then break end
		heap[i], heap[best] = heap[best], heap[i]
		i = best
	end

	return top
end

local function heuristic(ctx, x, y, z, gx, gy, gz)
	local dx, dy, dz = math.abs(gx - x), (gy - y) * cellSize, math.abs(gz - z)
	return (math.max(dx, dz) + math.min(dx, dz) * 0.4142) * cellSize * ctx.FlatCost + (dy > 0 and dy * ctx.ClimbCost or -dy / cellSize * ctx.DropCost)
end

local function estimate(pack, x, y, z)
	local column = cellKey(x, 0, z)
	local top = pack.field and not pack.land[column] and pack.tops[column] and math.min(pack.tops[column] + 1, pack.gy) or pack.gy
	return heuristic(pack.ctx, x, y, z, pack.gx, top, pack.gz) + (pack.field and math.max((pack.field[column] or math.max(pack.box[1] - x, x - pack.box[2], pack.box[3] - z, z - pack.box[4])) - (pack.land[column] and 0 or 1), 0) * pack.ctx.PlaceCost or 0)
end

local function relax(pack, parent, key, x, y, z, g, blocks, kind, damage, air)
	if pack.closed[key] then
		return
	end

	local existing = pack.nodes[key]
	if existing and existing.g <= g then
		return
	end

	local node = {x = x, y = y, z = z, g = g, b = blocks, pr = parent, mt = kind, dmg = damage, air = air}
	node.f = g + estimate(pack, x, y, z) * pack.weight
	pack.nodes[key] = node
	heapPush(pack.heap, node)
end

local function dropTo(ctx, x, y, z)
	local agent = ctx.Agent

	for i = 1, math.ceil(agent.MaxDrop / cellSize) do
		if ctx.World:Solid(x, y - i - 1, z) then
			local drop = i * cellSize
			return y - i, drop, ctx.Traversal.Instant and 0 or fallDamage(impactSpeed(drop, 0, agent.Gravity), agent)
		end
		if not fits(ctx, x, y - i, z) then
			return nil
		end
	end

	return nil
end

local function gapLand(ctx, x, y, z, dx, dz, span, level)
	local agent = ctx.Agent
	local stride = cellSize * (dx ~= 0 and dz ~= 0 and 1.4142 or 1)

	if ctx.Traversal.Mover == 'Glide' then
		local height = math.max(level, y)
		for i = y + 1, height do
			if not fits(ctx, x, i, z) then
				return false
			end
		end
		local length = math.sqrt(dx * dx + dz * dz) * span * cellSize
		for i = 0, math.ceil(length) do
			local px, pz = (x + dx * span * math.min(i / length, 1)) * cellSize, (z + dz * span * math.min(i / length, 1)) * cellSize
			if not fits(ctx, gridAxis(px - agent.Radius), height, gridAxis(pz - agent.Radius)) or not fits(ctx, gridAxis(px + agent.Radius), height, gridAxis(pz - agent.Radius)) or not fits(ctx, gridAxis(px - agent.Radius), height, gridAxis(pz + agent.Radius)) or not fits(ctx, gridAxis(px + agent.Radius), height, gridAxis(pz + agent.Radius)) then
				return false
			end
		end
		for i = level + 1, y do
			if not fits(ctx, x + dx * span, i, z + dz * span) then
				return false
			end
		end
		return true
	end

	for i = 1, span do
		local height = y + math.max(math.round(jumpHeight(agent, i * stride / agent.WalkSpeed) / cellSize), i == span and level - y or -math.huge)
		if not fits(ctx, x + dx * i, height, z + dz * i) then
			return false
		end
	end

	return true
end

local function expand(pack, node)
	local ctx = pack.ctx
	local agent = ctx.Agent
	local x, y, z = node.x, node.y, node.z
	local head = ctx.World:Solid(x, y + ctx.Height, z)
	local extra = (node.mt == 'Bridge' or node.mt == 'Tower') and cellKey(x, y - 1, z) or nil
	local column = cellKey(x, 0, z)
	local top = pack.field and not pack.land[column] and pack.tops[column] and math.min(pack.tops[column] + 1, pack.gy) or pack.gy
	local rise = pack.bridge and (top > y and not (pack.field and pack.land[column] and (pack.field[column] or 0) > 0) or not fits(ctx, x + 1, y, z) or not fits(ctx, x - 1, y, z) or not fits(ctx, x, y, z + 1) or not fits(ctx, x, y, z - 1))
	local walkable = false

	for _, v in flats do
		local dx, dz = v[1], v[3]
		local diagonal = dx ~= 0 and dz ~= 0
		if diagonal and not canCutCorner(ctx, x, y, z, dx, dz) then continue end

		local step = diagonal and ctx.DiagCost or ctx.StepCost
		local tx, tz = x + dx, z + dz
		local level = stands(ctx, tx, y, tz)

		for dy = -1, 1 do
			local ty = y + dy
			if dy == 1 and (head or level or (diagonal and not canCutCorner(ctx, x, ty, z, dx, dz))) then continue end
			if dy == -1 and (diagonal or node.mt ~= 'Bridge' or level or top >= y) then continue end
			if not fits(ctx, tx, ty, tz) then continue end

			local key = cellKey(tx, ty, tz)
			local cost = step + (dy == 1 and ctx.JumpCost or dy == -1 and ctx.DropCost or 0)

			if stands(ctx, tx, ty, tz) then
				if dy ~= -1 then
					relax(pack, node, key, tx, ty, tz, node.g + cost, node.b, dy == 1 and 'Jump' or 'Walk', 0)
					walkable = true
				end
				continue
			end

			if dy == 0 then
				local landing, drop, damage = dropTo(ctx, tx, ty, tz)
				if landing and damage <= agent.DamageAllowance then
					relax(pack, node, cellKey(tx, landing, tz), tx, landing, tz, node.g + cost + ctx.DropCost + math.sqrt(2 * drop / agent.Gravity) + damage * ctx.RiskCost, node.b, 'Drop', damage)
					walkable = true
					if pack.field and pack.land[cellKey(tx, 0, tz)] then continue end
				end
			end

			if pack.bridge and node.b < pack.limit and (dy ~= 1 or rise) and supportAt(ctx, tx, ty - 1, tz, ctx.Mode, extra) then
				relax(pack, node, key, tx, ty, tz, node.g + cost + ctx.PlaceCost + (node.b >= ctx.Budgeted and ctx.ScarceCost or 0) + (node.mt == 'Bridge' and node.pr and (dx ~= x - node.pr.x or dz ~= z - node.pr.z) and ctx.TurnCost or 0), node.b + 1, 'Bridge', 0)
				walkable = true
			end
		end

		if pack.gap and not level and (not head or ctx.Traversal.Mover == 'Glide') and (node.mt ~= 'Bridge' or dx == x - node.pr.x and dz == z - node.pr.z) and not ctx.World:Solid(tx, y - 1, tz) and not ctx.World:Solid(tx, y - 2, tz) then
			local stride = cellSize * (diagonal and 1.4142 or 1)
			local land = ctx.World.Land
			for span = 2, math.floor(ctx.Leap / stride) + 1 do
				local lx, lz = x + dx * span, z + dz * span
				local surface = land and land[cellKey(lx, 0, lz)]
				local landed = false
				if surface or not land then
					for ly = math.min(y + ctx.Rise, surface and surface + 1 or math.huge), y - ctx.Dive, -1 do
						if stands(ctx, lx, ly, lz) then
							local crossable, airtime = traverse(agent, ctx.Traversal, (span - 1) * stride, (ly - y) * cellSize, agent.WalkSpeed)
							local damage = ly < y and not ctx.Traversal.Instant and fallDamage(impactSpeed((y - ly) * cellSize, ctx.Traversal.Mover == 'Glide' and 0 or agent.JumpVelocity, agent.Gravity), agent) or 0
							if crossable and (node.air or 0) + airtime <= ctx.Traversal.MaxAirTime and damage <= agent.DamageAllowance and gapLand(ctx, x, y, z, dx, dz, span, ly) then
								relax(pack, node, cellKey(lx, ly, lz), lx, ly, lz, node.g + step * span + ctx.JumpCost + ctx.AirCost * airtime + math.max(ly - y, 0) * cellSize * ctx.ClimbCost + damage * ctx.RiskCost, node.b, 'Jump', damage, (node.air or 0) + airtime)
								walkable = true
							end
							landed = true
							break
						end
					end
				end
				if landed or not fits(ctx, x + dx * (span - 1), y, z + dz * (span - 1)) or not fits(ctx, lx, y, lz) then break end
			end
		end

		if ctx.Traversal.Instant and not level then
			for i = 2, ctx.Rise do
				if not fits(ctx, x, y + i, z) then break end
				if stands(ctx, tx, y + i, tz) and (not diagonal or canCutCorner(ctx, x, y + i, z, dx, dz)) then
					relax(pack, node, cellKey(tx, y + i, tz), tx, y + i, tz, node.g + step + ctx.JumpCost + i * cellSize * ctx.ClimbCost, node.b, 'Jump', 0)
					walkable = true
					break
				end
			end
		end
	end

	if pack.gap and ctx.Traversal.Mover == 'Glide' and node.mt ~= 'Bridge' then
		local land = ctx.World.Land
		for _, v in leaps do
			local dx, dz = v[1], v[3]
			local ax, az, bx, bz = x + (math.abs(dx) == 2 and dx // 2 or 0), z + (math.abs(dz) == 2 and dz // 2 or 0), x + math.sign(dx), z + math.sign(dz)
			if stands(ctx, ax, y, az) or stands(ctx, bx, y, bz) or ctx.World:Solid(ax, y - 1, az) or ctx.World:Solid(bx, y - 1, bz) then continue end

			local stride = cellSize * math.sqrt(dx * dx + dz * dz)
			local edge = stride / math.max(math.abs(dx), math.abs(dz))
			for span = 1, math.floor((ctx.Leap + edge) / stride) do
				local lx, lz = x + dx * span, z + dz * span
				local surface = land and land[cellKey(lx, 0, lz)]
				local landed = false
				if surface or not land then
					for ly = math.min(y + ctx.Rise, surface and surface + 1 or math.huge), y - ctx.Dive, -1 do
						if stands(ctx, lx, ly, lz) then
							local crossable, airtime = traverse(agent, ctx.Traversal, span * stride - edge, (ly - y) * cellSize, agent.WalkSpeed)
							local damage = ly < y and not ctx.Traversal.Instant and fallDamage(impactSpeed((y - ly) * cellSize, 0, agent.Gravity), agent) or 0
							if crossable and (node.air or 0) + airtime <= ctx.Traversal.MaxAirTime and damage <= agent.DamageAllowance and gapLand(ctx, x, y, z, dx, dz, span, ly) then
								relax(pack, node, cellKey(lx, ly, lz), lx, ly, lz, node.g + ctx.StepCost * span * stride / cellSize + ctx.JumpCost + ctx.AirCost * airtime + math.max(ly - y, 0) * cellSize * ctx.ClimbCost + damage * ctx.RiskCost, node.b, 'Jump', damage, (node.air or 0) + airtime)
								walkable = true
							end
							landed = true
							break
						end
					end
				end
				if landed then break end
			end
		end
	end

	if pack.tower and node.b < pack.limit and not head and (rise or not walkable) and fits(ctx, x, y + 1, z) then
		relax(pack, node, cellKey(x, y + 1, z), x, y + 1, z, node.g + ctx.PlaceCost + ctx.JumpCost + (node.b >= ctx.Budgeted and ctx.ScarceCost or 0), node.b + 1, 'Tower', 0)
	end

	local climb = ctx.World:Profile(ctx.World:Block(x, y, z))
	if climb and climb.Climbable then
		for dy = -1, 1, 2 do
			local target = ctx.World:Profile(ctx.World:Block(x, y + dy, z))
			if not ctx.World:Solid(x, y + dy, z) or (target and target.Climbable) then
				relax(pack, node, cellKey(x, y + dy, z), x, y + dy, z, node.g + ctx.ClimbStep, node.b, 'Climb', 0)
			end
		end
	end
end

local function search(ctx, blocks, from, goal, weight, options, request, stage, seed)
	local pack = {
		ctx = ctx,
		heap = {},
		nodes = {},
		closed = {},
		weight = weight,
		gx = goal.x,
		gy = goal.y,
		gz = goal.z,
		limit = blocks,
		bridge = stage ~= 'Walk' and options.Bridge ~= false,
		tower = stage ~= 'Walk' and options.Tower ~= false,
		gap = options.JumpGap ~= false,
		reached = false,
		steps = 0
	}

	if stage == 'Bridge' then
		pack.field, pack.land, pack.box, pack.tops = ctx.World:Field(from, goal, options.FieldMargin, ctx.Mode, options.Yield and task and options.Budget)
	elseif pack.gap then
		ctx.World:Columns(options.Yield and task and options.Budget)
	end

	local budget = stage == 'Walk' and options.WalkSteps or options.MaxSteps
	if seed then
		for i, v in seed.nodes do
			if seed.closed[i] then
				v.f = v.g + estimate(pack, v.x, v.y, v.z) * weight
				pack.nodes[i] = v
				heapPush(pack.heap, v)
				budget += 1
			end
		end
	else
		local start = {x = from.x, y = from.y, z = from.z, g = 0, b = 0, mt = 'Start', dmg = 0}
		start.f = estimate(pack, from.x, from.y, from.z) * weight
		pack.nodes[cellKey(from.x, from.y, from.z)] = start
		heapPush(pack.heap, start)
	end

	local tolerance = options.Tolerance * cellSize
	local score = math.huge
	local slice = os.clock() + options.Budget

	while #pack.heap > 0 and pack.steps < budget do
		pack.steps += 1

		if os.clock() >= slice then
			if request and request.Cancelled then
				return pack
			end
			if options.Yield and task then
				task.wait()
			end
			slice = os.clock() + options.Budget
		end

		local node = heapPop(pack.heap)
		local key = cellKey(node.x, node.y, node.z)
		if pack.closed[key] then continue end
		pack.closed[key] = true

		local dx, dy, dz = (goal.x - node.x) * cellSize, (goal.y - node.y) * cellSize, (goal.z - node.z) * cellSize
		local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
		if distance < score then
			pack.node, score = node, distance
		end

		if distance <= tolerance then
			pack.node, pack.reached = node, true
			return pack
		end

		expand(pack, node)
	end

	return pack
end

local function standPosition(agent, x, y, z)
	return Vector3.new(x * cellSize, y * cellSize - halfCell + agent.HipHeight, z * cellSize)
end

local function buildState(input, agent, world)
	if typeof(input) == 'Vector3' then
		input = {Position = input}
	end

	local position = input.Position
	local head = position + Vector3.new(0, agent.HeadOffset, 0)
	local state = {
		Position = position,
		Velocity = input.Velocity or Vector3.zero,
		Head = head,
		Eye = input.Eye or (input.Camera and input.Camera.Position) or head,
		Aim = input.Aim or (input.Camera and input.Camera.LookVector) or nil,
		HeadRadius = agent.HeadRadius,
		BodyHeight = input.BodyHeight or 2,
		Feet = position.Y - agent.HipHeight,
		Grounded = input.Grounded,
		Blocks = input.BlocksAvailable or agent.BlocksAvailable,
		CellX = gridAxis(position.X),
		CellY = gridAxis(position.Y - agent.HipHeight + halfCell),
		CellZ = gridAxis(position.Z),
		BodyX = gridAxis(position.X),
		BodyY = gridAxis(position.Y - agent.BodyOffset),
		BodyZ = gridAxis(position.Z)
	}

	if state.Grounded == nil and world then
		state.Grounded = world:Solid(state.CellX, state.CellY - 1, state.CellZ)
	end

	return state
end

local function writeCell(ctx, x, y, z, block)
	ctx.World:Write(x, y, z, block)
	local base = cellKey(x, y, z)
	for i = -ctx.Height, 1 do
		ctx.Fits[base + i * keySpan] = nil
		ctx.Stands[base + i * keySpan] = nil
	end
end

local function walkLine(ctx, y, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local span = math.max(math.abs(dx), math.abs(dz))
	if span == 0 then
		return true
	end

	local lastX, lastZ = ax, az
	for i = 1, span do
		local cx, cz = ax + math.round(dx * i / span), az + math.round(dz * i / span)
		if not stands(ctx, cx, y, cz) then
			return false
		end
		if cx ~= lastX and cz ~= lastZ and not canCutCorner(ctx, lastX, y, lastZ, cx - lastX, cz - lastZ) then
			return false
		end
		lastX, lastZ = cx, cz
	end

	return true
end

local function compile(ctx, node, options)
	local agent = ctx.Agent
	local path = {}
	local current = node

	while current do
		table.insert(path, 1, current)
		current = current.pr
	end

	local actions, bridge, walking, depends, planned = {}, {}, {}, {}, {}
	local blocks, damage, failure = 0, 0, nil
	local lastBridge, priorBridge = nil, nil

	ctx.World:Begin()

	for i, v in path do
		for i2 = -1, ctx.Height - 1 do
			depends[cellKey(v.x, v.y + i2, v.z)] = true
		end

		if v.air then
			local previous = path[i - 1]
			local length = math.sqrt((v.x - previous.x) ^ 2 + (v.z - previous.z) ^ 2) * cellSize
			for i2 = 1, math.ceil(length) do
				for i3 = 0, ctx.Height - 1 do
					depends[cellKey(gridAxis((previous.x + (v.x - previous.x) * i2 / length * cellSize) * cellSize), math.max(previous.y, v.y) + i3, gridAxis((previous.z + (v.z - previous.z) * i2 / length * cellSize) * cellSize))] = true
				end
			end
		end

		if v.mt == 'Bridge' or v.mt == 'Tower' then
			local previous = path[i - 1]
			local lift = v.mt == 'Tower' and agent.HipHeight or 0
			local from = buildState({Position = standPosition(agent, previous.x, previous.y, previous.z) + Vector3.new(0, lift, 0)}, agent)

			if options.BridgeWidth > 1 and lastBridge and priorBridge and v.mt == 'Bridge' and (v.x - lastBridge.X ~= lastBridge.X - priorBridge.X or v.z - lastBridge.Z ~= lastBridge.Z - priorBridge.Z) then
				local fill = placementAt(ctx, from, priorBridge.X + v.x - lastBridge.X, v.y - 1, priorBridge.Z + v.z - lastBridge.Z, ctx.Mode, nil, true)
				if fill and blocks < options.BlocksAvailable then
					fill.Type = 'PlaceBlock'
					fill.Duration = 1 / agent.PlaceCps
					fill.ExpectedPosition = from.Position
					fill.Lead = math.max((ctx.Reach - fill.Distance) / agent.WalkSpeed, 0)
					fill.Preconditions = {MaxDistance = ctx.Reach, RequiredSupport = fill.SupportGrid, RequiredMode = ctx.Mode}
					table.insert(actions, fill)
					table.insert(bridge, fill)
					writeCell(ctx, fill.Grid.X, fill.Grid.Y, fill.Grid.Z, fill)
					planned[cellKey(fill.Grid.X, fill.Grid.Y, fill.Grid.Z)] = true
					blocks += 1
				end
			end

			local placement = placementAt(ctx, from, v.x, v.y - 1, v.z, ctx.Mode, nil, options.Quick)
			if not placement then
				failure = {Reason = 'Placement', Index = #actions + 1, Grid = Vector3.new(v.x, v.y - 1, v.z)}
				break
			end

			placement.Type = 'PlaceBlock'
			placement.Duration = 1 / agent.PlaceCps
			placement.ExpectedPosition = from.Position
			placement.Lead = math.max((ctx.Reach - placement.Distance) / agent.WalkSpeed, 0)
			placement.Preconditions = {
				MaxDistance = ctx.Reach,
				RequiredSupport = placement.SupportGrid,
				RequiredMode = ctx.Mode,
				Airborne = v.mt == 'Tower' or nil,
				MinHeight = v.mt == 'Tower' and v.y * cellSize - halfCell or nil
			}

			table.insert(actions, placement)
			table.insert(bridge, placement)
			writeCell(ctx, v.x, v.y - 1, v.z, placement)
			planned[cellKey(v.x, v.y - 1, v.z)] = true
			priorBridge, lastBridge = lastBridge, {X = v.x, Z = v.z}
			blocks += 1
		elseif v.mt ~= 'Start' then
			priorBridge, lastBridge = nil, nil
		end

		if v.mt ~= 'Start' then
			local previous = path[i - 1]
			damage += v.dmg
			table.insert(actions, {
				Type = v.mt == 'Bridge' and 'Walk' or (v.mt == 'Tower' and 'Jump' or v.mt),
				Grid = Vector3.new(v.x, v.y, v.z),
				Position = standPosition(agent, v.x, v.y, v.z),
				Duration = math.max(v.g - previous.g - ((v.mt == 'Bridge' or v.mt == 'Tower') and ctx.PlaceCost + (previous.b >= ctx.Budgeted and ctx.ScarceCost or 0) or 0) - (v.air and ctx.JumpCost + ctx.AirCost * (v.air - (previous.air or 0)) + math.max(v.y - previous.y, 0) * cellSize * ctx.ClimbCost + v.dmg * ctx.RiskCost or 0), 0),
				Damage = v.dmg,
				AirTime = v.air,
				Gap = v.air and math.sqrt((v.x - previous.x) ^ 2 + (v.z - previous.z) ^ 2) * cellSize * (1 - 1 / math.max(math.abs(v.x - previous.x), math.abs(v.z - previous.z))) or nil,
				Rise = v.air and v.y - previous.y or nil,
				From = v.air and Vector3.new(previous.x, previous.y, previous.z) or nil
			})
		end
	end

	ctx.World:Finish()
	table.clear(ctx.Fits)
	table.clear(ctx.Stands)

	if options.Smooth then
		local index = 2
		while index <= #actions do
			local previous, move = actions[index - 1], actions[index]
			local from = previous.From or previous.Grid
			if previous.Type == 'Walk' and move.Type == 'Walk' and previous.Grid.Y == move.Grid.Y and walkLine(ctx, move.Grid.Y, from.X, from.Z, move.Grid.X, move.Grid.Z) then
				move.From = from
				move.Duration += previous.Duration
				table.remove(actions, index - 1)
			else
				index += 1
			end
		end
	end

	local elapsed, lastPlace = 0, -math.huge
	local interval = 1 / agent.PlaceCps

	for _, v in actions do
		if v.Type == 'PlaceBlock' then
			elapsed = math.max(elapsed, lastPlace + interval)
			lastPlace = elapsed
		else
			table.insert(walking, v.Position)
		end
		v.Time = elapsed
		elapsed += v.Duration
	end

	local decisions = nil
	if options.Debug then
		decisions = {}
		local segment = nil
		for i, v in path do
			if v.mt == 'Bridge' or v.mt == 'Tower' then
				if not segment or segment.Kind ~= v.mt then
					segment = {Kind = v.mt, From = path[i - 1], Count = 0}
					table.insert(decisions, segment)
				end
				segment.Count += 1
				segment.To, segment.Next = v, path[i + 1]
			else
				segment = nil
				if v.air then
					table.insert(decisions, {Kind = 'Jump', From = path[i - 1], To = v, Count = 0})
				end
			end
		end

		for i, v in decisions do
			local from, to = v.From, v.Next and v.Next.mt ~= 'Bridge' and v.Next.mt ~= 'Tower' and v.Next or v.To
			local span = math.max(math.abs(to.x - from.x), math.abs(to.z - from.z))
			local gap = span > 0 and math.sqrt((to.x - from.x) ^ 2 + (to.z - from.z) ^ 2) * cellSize * (1 - 1 / span) or 0
			local crossable, airtime, _, reason = traverse(agent, ctx.Traversal, gap, (to.y - from.y) * cellSize, agent.WalkSpeed)
			local why = v.Kind == 'Jump' and 'gap safely traversable' or v.Kind == 'Tower' and (to.y > from.y and 'destination requires useful elevation before horizontal traversal' or 'no walkable route') or (crossable and 'landing not standable or a detour, placing is cheaper' or reason == 'TooHigh' and 'landing too high to cross without blocks' or string.format('crossing needs %.2fs, above the %.2fs limit', airtime, ctx.Traversal.MaxAirTime))
			decisions[i] = {
				Decision = v.Kind,
				Reason = why,
				CurrentGrid = Vector3.new(from.x, from.y, from.z),
				TargetGrid = Vector3.new(to.x, to.y, to.z),
				CurrentY = from.y,
				TargetY = to.y,
				Gap = gap,
				AirTime = airtime,
				MaxAirTime = ctx.Traversal.MaxAirTime,
				RequiredBlocks = v.Count,
				AvailableBlocks = ctx.Budgeted,
				AlternativeJump = crossable,
				Summary = string.format('Decision: %s | Reason: %s | CurrentGrid: %d,%d,%d | TargetGrid: %d,%d,%d | CurrentY: %d | TargetY: %d | Gap: %.1f studs | PredictedAirTime: %.2f | MaxAllowedAirTime: %.2f | RequiredBlocks: %d | AvailableBlocks: %s | AlternativeJump: %s', v.Kind, why, from.x, from.y, from.z, to.x, to.y, to.z, from.y, to.y, gap, airtime, ctx.Traversal.MaxAirTime, v.Count, tostring(ctx.Budgeted), tostring(crossable))
			}
		end
	end

	return {
		Actions = actions,
		BridgePath = bridge,
		WalkingPath = walking,
		Blocks = blocks,
		Damage = damage,
		Duration = elapsed,
		Depends = depends,
		Planned = planned,
		Decisions = decisions,
		Failure = failure
	}
end

local function standable(ctx, x, y, z, depth)
	for i = 0, 2 do
		if stands(ctx, x, y + i, z) then
			return x, y + i, z
		end
	end

	for i = 1, depth do
		if stands(ctx, x, y - i, z) then
			return x, y - i, z
		end
	end

	for radius = 1, 2 do
		for dx = -radius, radius do
			for dz = -radius, radius do
				if math.abs(dx) == radius or math.abs(dz) == radius then
					for dy = 0, radius do
						if stands(ctx, x + dx, y + dy, z + dz) then
							return x + dx, y + dy, z + dz
						end
						if stands(ctx, x + dx, y - dy, z + dz) then
							return x + dx, y - dy, z + dz
						end
					end
				end
			end
		end
	end

	return x, y, z
end

local function resolveTarget(goal)
	if typeof(goal) == 'Vector3' then
		return goal, nil
	end
	if typeof(goal) == 'Instance' then
		return goal:IsA('Model') and goal:GetPivot().Position or goal.Position, nil
	end
	if goal.Grid then
		return Vector3.new(goal.Grid.X * cellSize, goal.Grid.Y * cellSize, goal.Grid.Z * cellSize), goal.Grid
	end
	if goal.RootPart then
		return goal.RootPart.Position, nil
	end
	if goal.Character then
		return goal.Character:GetPivot().Position, nil
	end
	return goal.Position, nil
end

local function arcPosition(state, agent, elapsed)
	return state.Position + state.Velocity * elapsed - Vector3.new(0, agent.Gravity * elapsed * elapsed * 0.5, 0)
end

local function fallLine(state, agent, height)
	local drop = state.Feet - height
	local elapsed = fallTime(drop, state.Velocity.Y, agent.Gravity)
	if not elapsed or elapsed <= 0 then
		return nil
	end

	local point = arcPosition(state, agent, elapsed)
	return gridAxis(point.X), gridAxis(point.Z), elapsed, impactSpeed(drop, -state.Velocity.Y, agent.Gravity), point
end

local function landingOf(ctx, state, agent, cfg)
	local top = gridAxis(state.Feet + halfCell) - 1

	for i = 0, math.ceil(cfg.Scan / cellSize) do
		local level = top - i
		local x, z, elapsed, impact, point = fallLine(state, agent, level * cellSize + halfCell)
		if x and ctx.World:Solid(x, level, z) then
			return {Level = level, X = x, Z = z, Time = elapsed, Impact = impact, Damage = fallDamage(impact, agent), Point = point}
		end
	end

	return nil
end

local function escapeScore(ctx, x, y, z)
	local count = 0

	for _, v in flats do
		if ctx.World:Solid(x + v[1], y, z + v[3]) then
			count += 1
		end
	end

	return count
end

local function clutchCandidate(ctx, state, agent, cfg, level, offset)
	local x, z, elapsed, impact, point = fallLine(state, agent, level * cellSize + halfCell)
	if not x then
		return nil
	end

	x, z = x + offset[1], z + offset[3]
	if ctx.World:Solid(x, level, z) then
		return nil
	end

	local latency = agent.Latency + 1 / agent.PlaceCps
	if elapsed <= latency then
		return nil
	end

	local drift = math.sqrt((point.X - x * cellSize) ^ 2 + (point.Z - z * cellSize) ^ 2)
	if drift > halfCell + agent.Radius then
		return nil
	end

	local delay = 0
	local predicted = buildState({Position = arcPosition(state, agent, latency), Velocity = state.Velocity - Vector3.new(0, agent.Gravity * latency, 0)}, agent)
	local placement, reason = placementAt(ctx, predicted, x, level, z, ctx.Mode, nil, false)

	if not placement and reason == 'Reach' then
		for i = 1, math.min(math.floor((elapsed - latency) / cfg.SampleTime), cfg.ReachSteps) do
			delay = i * cfg.SampleTime
			predicted = buildState({Position = arcPosition(state, agent, latency + delay), Velocity = state.Velocity - Vector3.new(0, agent.Gravity * (latency + delay), 0)}, agent)
			placement, reason = placementAt(ctx, predicted, x, level, z, ctx.Mode, nil, false)
			if placement or reason ~= 'Reach' then
				break
			end
		end
	end

	if not placement then
		return nil, reason
	end

	local damage = fallDamage(impact, agent)
	local escape = escapeScore(ctx, x, level, z)
	local reliability = placement.PlacementType == 'Face' and 1 or (placement.PlacementType == 'Diagonal' and 0.75 or 0.35)
	local margin = math.clamp((elapsed - latency - delay) / math.max(latency, 0.05), 0, 1)
	local reach = math.clamp(1.2 - placement.Distance / ctx.Reach, 0, 1)
	local survival = math.min(reliability * margin * reach * math.clamp(1 - drift / (halfCell + agent.Radius), 0.25, 1) * (escape > 0 and 1 or 0.85), 0.99)

	return {
		Type = (offset[1] ~= 0 or offset[3] ~= 0) and 'Side' or (placement.Normal and placement.Normal.Y == 0 and 'Wall' or 'Direct'),
		Grid = Vector3.new(x, level, z),
		Placement = placement,
		Time = latency + delay,
		Impact = impact,
		Damage = damage,
		Drift = drift,
		Escape = escape,
		Blocks = 1,
		Survival = survival,
		Score = cfg.Weights.Survival * survival - cfg.Weights.Damage * damage - cfg.Weights.Blocks + cfg.Weights.Escape * math.min(escape, 2) - cfg.Weights.Distance * placement.Distance
	}
end

local function clutchColumn(ctx, state, agent, cfg, level)
	local anchor = nil

	for i = 1, cfg.MaxChain do
		anchor = clutchCandidate(ctx, state, agent, cfg, level - i, {0, 0, 0}) or clutchCandidate(ctx, state, agent, cfg, level + i, {0, 0, 0})
		if anchor then
			break
		end
	end

	if not anchor then
		return nil
	end

	ctx.World:Begin()
	writeCell(ctx, anchor.Grid.X, anchor.Grid.Y, anchor.Grid.Z, anchor.Placement)
	local deep = clutchCandidate(ctx, state, agent, cfg, level, {0, 0, 0})
	ctx.World:Finish()
	table.clear(ctx.Fits)
	table.clear(ctx.Stands)

	if not deep then
		return nil
	end

	local _, _, elapsed = fallLine(state, agent, level * cellSize + halfCell)
	local ready = math.max(anchor.Time, deep.Time) + 1 / agent.PlaceCps
	if not elapsed or ready > elapsed then
		return nil
	end

	deep.Time = ready
	deep.Type = 'Column'
	deep.Chain = {anchor.Placement, deep.Placement}
	deep.Blocks = 2
	deep.Survival *= anchor.Survival
	deep.Score = cfg.Weights.Survival * deep.Survival - cfg.Weights.Damage * deep.Damage - cfg.Weights.Blocks * 2 + cfg.Weights.Escape * math.min(deep.Escape, 2) - cfg.Weights.Distance * deep.Placement.Distance
	return deep
end

local function clutchPlan(ctx, state, agent, cfg, options)
	local landing = landingOf(ctx, state, agent, cfg)
	if landing and landing.Damage <= agent.DamageAllowance and not options.Force then
		return {Reason = 'Safe', Landing = landing}
	end
	if not landing and not cfg.Void then
		return {Reason = 'Safe'}
	end

	local deepest = math.ceil((state.Feet - math.min(safeDrop(state.Velocity.Y, agent), cfg.MaxFall) - halfCell) / cellSize)
	local top = gridAxis(state.Feet + halfCell) - 1
	if landing and landing.Level >= deepest then
		return {Reason = 'Safe', Landing = landing}
	end

	local best, settled, partial = nil, nil, false
	for level = deepest, top do
		local candidate = clutchCandidate(ctx, state, agent, cfg, level, {0, 0, 0})

		for _, v in flats do
			local side = clutchCandidate(ctx, state, agent, cfg, level, v)
			if side and (not candidate or side.Score > candidate.Score) then
				candidate = side
			end
		end

		if not candidate and cfg.MaxBlocks > 1 then
			candidate = clutchColumn(ctx, state, agent, cfg, level)
		end

		if candidate and (not best or candidate.Score > best.Score) then
			best = candidate
		end

		if candidate and candidate.Survival >= cfg.MinSurvival then
			settled = candidate
			break
		end
	end

	best = settled or best

	if not best then
		for level = deepest - 1, math.max(deepest - cfg.MaxChain * 2, landing and landing.Level + 1 or deepest - cfg.MaxChain * 2), -1 do
			local candidate = clutchCandidate(ctx, state, agent, cfg, level, {0, 0, 0})
			if candidate and (not best or candidate.Damage < best.Damage) then
				best, partial = candidate, true
			end
		end
	end

	if not best or (landing and partial and best.Damage >= landing.Damage) then
		return {Reason = landing and 'Unreachable' or 'Void', Landing = landing}
	end

	if cfg.Width > 1 and best.Blocks < cfg.MaxBlocks and best.Drift > halfCell * 0.5 then
		local dx = math.abs(state.Velocity.X) > math.abs(state.Velocity.Z) and (state.Velocity.X > 0 and 1 or -1) or 0
		local dz = dx == 0 and (state.Velocity.Z > 0 and 1 or -1) or 0

		ctx.World:Begin()
		writeCell(ctx, best.Grid.X, best.Grid.Y, best.Grid.Z, best.Placement)
		local extra = placementAt(ctx, buildState({Position = arcPosition(state, agent, best.Time)}, agent), best.Grid.X + dx, best.Grid.Y, best.Grid.Z + dz, ctx.Mode, nil, false)
		ctx.World:Finish()
		table.clear(ctx.Fits)
		table.clear(ctx.Stands)

		if extra then
			best.Chain = {best.Placement, extra}
			best.Blocks += 1
			best.Type = 'Platform'
		end
	end

	return {Best = best, Landing = landing, Partial = partial}
end

local function merge(base, override)
	local out = table.clone(base)
	if override then
		for i, v in override do
			out[i] = v
		end
	end
	return out
end

local function contextFor(self, world, agent, costs, mode, options)
	local channel = options.Channel or 'default'
	local ctx = self.Contexts[channel]

	if not ctx or ctx.World ~= world or ctx.Mode ~= mode or ctx.Height ~= math.max(math.ceil(agent.Height / cellSize), 1) then
		ctx = newContext(world, agent, mode)
		self.Contexts[channel] = ctx
	else
		refresh(ctx)
	end

	ctx.Agent = agent
	ctx.Reach = options.Reach or agent.Reach
	ctx.Floating = options.Floating == true
	ctx.StepCost = cellSize / agent.WalkSpeed
	ctx.DiagCost = ctx.StepCost * 1.4142 + costs.Diagonal
	ctx.PlaceCost = 1 / agent.PlaceCps + costs.Block + (options.BlockProfile and options.BlockProfile.Cost or 0)
	ctx.JumpCost = costs.Jump
	ctx.DropCost = costs.Drop
	ctx.RiskCost = costs.Risk
	ctx.FlatCost = 1 / agent.WalkSpeed
	ctx.ClimbCost = (jumpLand(agent, cellSize) or 0.35) / cellSize
	ctx.ClimbStep = cellSize / math.max(agent.WalkSpeed * 0.5, 1)
	ctx.TurnCost = costs.Diagonal
	ctx.AirCost = costs.Air
	ctx.ScarceCost = costs.Scarce
	ctx.Budgeted = options.BlocksBudget or math.huge
	ctx.Traversal = merge(self.Config.Traversal, options.Traversal)
	ctx.Dive = math.floor(agent.MaxDrop / cellSize)
	ctx.Rise = ctx.Traversal.Mover == 'Glide' and ctx.Traversal.Rise or math.floor(agent.JumpVelocity * agent.JumpVelocity / (2 * agent.Gravity) / cellSize)
	ctx.Leap = select(3, traverse(agent, ctx.Traversal, 0, ctx.Traversal.Mover == 'Glide' and 0 or -ctx.Dive * cellSize, agent.WalkSpeed))
	return ctx
end

local function route(ctx, blocks, from, goal, options, request)
	local walk = options.Free and search(ctx, blocks, from, goal, options.Weight, options, request, 'Walk') or nil
	local node, reached, steps = walk and walk.node, walk ~= nil and walk.reached, walk and walk.steps or 0

	if not reached and (not walk or options.Bridge ~= false and blocks > 0) then
		local ratio = (ctx.StepCost + ctx.PlaceCost) / ctx.StepCost
		local stages = {{'Bridge', options.BridgeWeight}, {'Greedy', ratio + 0.5}, {'Greedy', ratio + 3}}
		if options.Fallback then
			table.insert(stages, 2, {'Bridge', options.Fallback})
		end
		for _, v in stages do
			if request and request.Cancelled or v[1] == 'Greedy' and (options.Bridge == false or blocks <= 0 or node and heuristic(ctx, node.x, node.y, node.z, goal.x, goal.y, goal.z) <= options.Tolerance * ctx.StepCost) then
				break
			end

			local pack = search(ctx, blocks, from, goal, v[2], options, request, v[1], walk)
			steps += pack.steps

			if pack.node and (not node or heuristic(ctx, pack.node.x, pack.node.y, pack.node.z, goal.x, goal.y, goal.z) < heuristic(ctx, node.x, node.y, node.z, goal.x, goal.y, goal.z)) then
				node = pack.node
			end

			if pack.reached then
				node, reached = pack.node, true
				break
			end
		end
	end

	if request and request.Cancelled or not reached and node and node.mt == 'Start' then
		return nil, false, steps
	end

	return node, reached, steps
end

local requestClass = {}
requestClass.__index = requestClass

function requestClass.Cancel(self)
	self.Cancelled = true
end

function requestClass.Await(self)
	while not self.Done and not self.Cancelled do
		task.wait()
	end
	return self.Result
end

function requestClass.OnComplete(self, callback)
	if self.Done then
		callback(self.Result)
	else
		table.insert(self.Callbacks, callback)
	end
end

local function dispatch(self, channel, worker)
	local request = setmetatable({Cancelled = false, Done = false, Result = nil, Callbacks = {}, Channel = channel}, requestClass)
	local previous = self.Requests[channel]
	if previous then
		previous.Cancelled = true
	end
	self.Requests[channel] = request

	task.spawn(function()
		local result = worker(request)
		if request.Cancelled then
			return
		end

		request.Result = result
		request.Done = true
		if self.Requests[channel] == request then
			self.Requests[channel] = nil
		end

		for _, v in request.Callbacks do
			task.spawn(v, result)
		end
	end)

	return request
end

function navigation.SetWorld(self, world)
	self.World = world
	table.clear(self.Contexts)
end

function navigation.FindPath(self, from, goal, options, request)
	local started = os.clock()
	options = options or {}

	local world = options.World or self.World
	local mode = options.Mode or 'Legit'
	local agent = merge(self.Config.Agent, options.Agent)
	local costs = merge(self.Config.Costs, options.Costs)
	local settings = merge(self.Config.Search, options.Search)

	if options.BlocksAvailable then
		agent.BlocksAvailable = options.BlocksAvailable
	end
	if options.Reach then
		agent.Reach = options.Reach
	end
	if options.Budget then
		settings.Budget = options.Budget
	end
	if options.Yield ~= nil then
		settings.Yield = options.Yield
	end
	settings.BlocksAvailable = agent.BlocksAvailable
	settings.Debug = options.Debug

	local ctx = contextFor(self, world, agent, costs, mode, options)
	local state = buildState(from, agent, world)
	local target, override = resolveTarget(goal)
	local revision, dirty, flush = world.Revision, world.DirtyIndex, world.Flush

	if options.TargetVelocity then
		target += options.TargetVelocity * math.min((target - state.Position).Magnitude / agent.WalkSpeed, options.MaxLead or 1.5)
	end

	local goalCell = override or Vector3.new(gridAxis(target.X), gridAxis(target.Y - agent.HipHeight + halfCell), gridAxis(target.Z))
	local sx, sy, sz = standable(ctx, state.CellX, state.CellY, state.CellZ, math.ceil(agent.MaxDrop / cellSize))
	local gx, gy, gz = standable(ctx, goalCell.X, goalCell.Y, goalCell.Z, settings.GoalDrop)
	local node, reached, steps = route(ctx, state.Blocks, {x = sx, y = sy, z = sz}, {x = gx, y = gy, z = gz}, settings, request)

	if not node then
		return {
			Success = false,
			Partial = false,
			Reason = request and request.Cancelled and 'Cancelled' or 'NoPath',
			Mode = mode,
			WalkingPath = {},
			BridgePath = {},
			Actions = {},
			Cost = 0,
			Distance = 0,
			BlocksUsed = 0,
			Damage = 0,
			Steps = steps,
			Elapsed = os.clock() - started
		}
	end

	local plan = compile(ctx, node, settings)
	local continuous = true
	for _, v in plan.BridgePath do
		if v.Lead <= 0 then
			continuous = false
		end
	end

	return {
		Success = reached and plan.Failure == nil,
		Continuous = continuous,
		Partial = not reached or plan.Failure ~= nil,
		Reason = plan.Failure and plan.Failure.Reason or (reached and 'Reached' or 'Budget'),
		Mode = mode,
		WalkingPath = plan.WalkingPath,
		BridgePath = plan.BridgePath,
		Actions = plan.Actions,
		Cost = node.g,
		Distance = (standPosition(agent, node.x, node.y, node.z) - state.Position).Magnitude,
		Duration = plan.Duration,
		BlocksUsed = plan.Blocks,
		Damage = plan.Damage,
		Start = Vector3.new(sx, sy, sz),
		Goal = Vector3.new(gx, gy, gz),
		Steps = steps,
		Elapsed = os.clock() - started,
		World = world,
		Revision = revision,
		DirtyIndex = dirty,
		Flush = flush,
		Depends = plan.Depends,
		Planned = plan.Planned,
		Decisions = plan.Decisions,
		Failure = plan.Failure
	}
end

function navigation.EvaluateGap(self, horizontal, vertical, options)
	options = options or {}

	local agent = merge(self.Config.Agent, options.Agent)
	local traversal = merge(self.Config.Traversal, options.Traversal)
	local crossable, airtime, reach, reason = traverse(agent, traversal, horizontal, vertical, options.Speed or agent.WalkSpeed)
	return {
		Crossable = crossable,
		AirTime = airtime,
		MaxAirTime = traversal.MaxAirTime,
		HorizontalDistance = horizontal,
		VerticalDistance = vertical,
		Reach = reach,
		Confidence = crossable and math.clamp((reach - horizontal) / cellSize, 0, 1) or 0,
		Reason = reason
	}
end

function navigation.FindPathAsync(self, from, goal, options)
	options = options or {}
	return dispatch(self, options.Channel or 'default', function(request)
		return self:FindPath(from, goal, options, request)
	end)
end

function navigation.GetBlockCosts(self, from, goals, options)
	options = options or {}

	local world = options.World or self.World
	local settings = merge(self.Config.Search, options.Search)
	if options.Yield ~= nil then
		settings.Yield = options.Yield
	end

	local position = typeof(from) == 'Vector3' and from or from.Position
	local origin = {x = gridAxis(position.X), y = gridAxis(position.Y - self.Config.Agent.HipHeight + halfCell), z = gridAxis(position.Z)}
	local field, _, box = world:Field(origin, origin, settings.FieldMargin, options.Mode or 'Legit', settings.Yield and task and settings.Budget)
	local costs = {}

	for i, v in goals do
		local target = resolveTarget(v)
		local x, z = gridAxis(target.X), gridAxis(target.Z)
		costs[i] = field and (field[cellKey(x, 0, z)] or math.max(box[1] - x, x - box[2], box[3] - z, z - box[4])) or 0
	end

	return costs
end

function navigation.FindRetreat(self, from, threats, options, request)
	local started = os.clock()
	options = options or {}

	local world = options.World or self.World
	local mode = options.Mode or 'Legit'
	local agent = merge(self.Config.Agent, options.Agent)
	local settings = merge(self.Config.Search, options.Search)
	local cfg = merge(self.Config.Retreat, options.Retreat)
	local weights = cfg.Weights

	if options.Budget then
		settings.Budget = options.Budget
	end
	if options.Yield ~= nil then
		settings.Yield = options.Yield
	end
	settings.BlocksAvailable = 0
	settings.Debug = options.Debug

	local ctx = contextFor(self, world, agent, merge(self.Config.Costs, options.Costs), mode, options)
	local state = buildState(from, agent, world)
	local revision, dirty, flush = world.Revision, world.DirtyIndex, world.Flush
	local sx, sy, sz = standable(ctx, state.CellX, state.CellY, state.CellZ, math.ceil(agent.MaxDrop / cellSize))
	local pack = {ctx = ctx, heap = {}, nodes = {}, closed = {}, weight = 0, gx = sx, gy = sy, gz = sz, limit = 0, bridge = false, tower = false, gap = settings.JumpGap ~= false, reached = false, steps = 0}
	local start = {x = sx, y = sy, z = sz, g = 0, b = 0, mt = 'Start', dmg = 0, f = 0}
	local best, score, nearest = nil, -math.huge, math.huge
	local slice = os.clock() + settings.Budget

	if pack.gap then
		world:Columns(settings.Yield and task and settings.Budget)
	end
	pack.nodes[cellKey(sx, sy, sz)] = start
	heapPush(pack.heap, start)

	while #pack.heap > 0 and pack.steps < cfg.MaxSteps do
		pack.steps += 1

		if os.clock() >= slice then
			if request and request.Cancelled then
				break
			end
			if settings.Yield and task then
				task.wait()
			end
			slice = os.clock() + settings.Budget
		end

		local node = heapPop(pack.heap)
		local key = cellKey(node.x, node.y, node.z)
		if pack.closed[key] then continue end
		pack.closed[key] = true
		if node.g > cfg.MaxTime then break end

		local position = standPosition(agent, node.x, node.y, node.z)
		local close = math.huge
		for _, v in threats do
			close = math.min(close, (v - position).Magnitude)
		end
		node.near = math.min(node.pr and node.pr.near or close, close)

		local open, edge = 0, 0
		for _, v in flats do
			if stands(ctx, node.x + v[1], node.y, node.z + v[3]) then
				open += 1
			elseif not ctx.World:Solid(node.x + v[1], node.y - 1, node.z + v[3]) and not dropTo(ctx, node.x + v[1], node.y, node.z + v[3]) then
				edge += 1
			end
		end

		local value = weights.Distance * math.min(close, cfg.SafeDistance) / cfg.SafeDistance + weights.Passage * math.min(node.near, cfg.SafeDistance / 2) / (cfg.SafeDistance / 2) + weights.Escape * open / #flats - weights.Edge * edge / #flats - weights.Time * node.g
		if value > score then
			local exposed = 0
			for _, v in threats do
				if (v - position).Magnitude < cfg.SafeDistance * 1.5 and traceClear(ctx, v + Vector3.new(0, agent.HeadOffset, 0), position + Vector3.new(0, agent.HeadOffset, 0)) then
					exposed += 1
				end
			end
			value -= #threats > 0 and weights.Exposure * exposed / #threats or 0
			if value > score then
				best, score, nearest = node, value, close
			end
		end

		expand(pack, node)
	end

	if not best or request and request.Cancelled then
		return {
			Success = false,
			Partial = false,
			Reason = request and request.Cancelled and 'Cancelled' or 'NoPath',
			Mode = mode,
			WalkingPath = {},
			BridgePath = {},
			Actions = {},
			Cost = 0,
			Distance = 0,
			BlocksUsed = 0,
			Damage = 0,
			Steps = pack.steps,
			Elapsed = os.clock() - started
		}
	end

	local plan = compile(ctx, best, settings)
	return {
		Success = plan.Failure == nil,
		Partial = plan.Failure ~= nil,
		Reason = plan.Failure and plan.Failure.Reason or 'Retreat',
		Mode = mode,
		WalkingPath = plan.WalkingPath,
		BridgePath = plan.BridgePath,
		Actions = plan.Actions,
		Cost = best.g,
		Score = score,
		Nearest = nearest,
		Distance = (standPosition(agent, best.x, best.y, best.z) - state.Position).Magnitude,
		Duration = plan.Duration,
		BlocksUsed = plan.Blocks,
		Damage = plan.Damage,
		Start = Vector3.new(sx, sy, sz),
		Goal = Vector3.new(best.x, best.y, best.z),
		Steps = pack.steps,
		Elapsed = os.clock() - started,
		World = world,
		Revision = revision,
		DirtyIndex = dirty,
		Flush = flush,
		Depends = plan.Depends,
		Planned = plan.Planned,
		Decisions = plan.Decisions,
		Failure = plan.Failure
	}
end

function navigation.FindClutch(self, from, options)
	local started = os.clock()
	options = options or {}

	local world = options.World or self.World
	local mode = options.Mode or 'Legit'
	local agent = merge(self.Config.Agent, options.Agent)
	local costs = merge(self.Config.Costs, options.Costs)
	local cfg = merge(self.Config.Clutch, options.Clutch)

	if options.BlocksAvailable then
		agent.BlocksAvailable = options.BlocksAvailable
		cfg.MaxBlocks = math.min(cfg.MaxBlocks, options.BlocksAvailable)
	end
	if options.DamageAllowance then
		agent.DamageAllowance = options.DamageAllowance
	end

	local ctx = contextFor(self, world, agent, costs, mode, options)
	ctx.Reach = options.Reach or cfg.Reach
	ctx.Floating = cfg.Anchored == false

	local state = buildState(from, agent, world)
	local plan = clutchPlan(ctx, state, agent, cfg, options)

	if not plan.Best then
		return {
			Success = false,
			Partial = false,
			Reason = plan.Reason,
			Mode = mode,
			Actions = {},
			BridgePath = {},
			WalkingPath = {},
			BlocksUsed = 0,
			Damage = plan.Landing and plan.Landing.Damage or 0,
			TimeToImpact = plan.Landing and plan.Landing.Time or math.huge,
			Survival = plan.Reason == 'Safe' and 1 or 0,
			Elapsed = os.clock() - started
		}
	end

	local best = plan.Best
	local placements = best.Chain or {best.Placement}
	local interval = 1 / agent.PlaceCps
	local elapsed = math.max(best.Time - (#placements - 1) * interval, 0)
	local actions = {}

	for _, v in placements do
		v.Type = 'PlaceBlock'
		v.Time = elapsed
		v.Duration = interval
		v.ExpectedPosition = arcPosition(state, agent, elapsed)
		v.Preconditions = {
			MaxDistance = ctx.Reach,
			RequiredSupport = v.SupportGrid,
			RequiredMode = mode,
			Airborne = true
		}
		table.insert(actions, v)
		elapsed += interval
	end

	local _, _, impactTime = fallLine(state, agent, best.Grid.Y * cellSize + halfCell)
	table.insert(actions, {
		Type = 'Land',
		Grid = best.Grid,
		Position = standPosition(agent, best.Grid.X, best.Grid.Y + 1, best.Grid.Z),
		Time = impactTime or best.Time,
		Duration = 0,
		Damage = best.Damage
	})

	return {
		Success = true,
		Partial = plan.Partial == true,
		Reason = best.Type,
		Mode = mode,
		ClutchType = best.Type,
		Actions = actions,
		BridgePath = placements,
		WalkingPath = {},
		BlocksUsed = best.Blocks,
		Damage = best.Damage,
		Impact = best.Impact,
		Drift = best.Drift,
		Survival = best.Survival,
		Score = best.Score,
		Grid = best.Grid,
		TimeToImpact = plan.Landing and plan.Landing.Time or math.huge,
		Elapsed = os.clock() - started,
		World = world,
		Revision = world.Revision,
		DirtyIndex = world.DirtyIndex,
		Flush = world.Flush,
		Depends = {[cellKey(best.Grid.X, best.Grid.Y, best.Grid.Z)] = true}
	}
end

function navigation.FindClutchAsync(self, from, options)
	options = options or {}
	return dispatch(self, options.Channel or 'clutch', function()
		return self:FindClutch(from, options)
	end)
end

function navigation.SolvePlacement(self, from, grid, options)
	options = options or {}

	local world = options.World or self.World
	local mode = options.Mode or 'Legit'
	local agent = merge(self.Config.Agent, options.Agent)
	local ctx = contextFor(self, world, agent, merge(self.Config.Costs, options.Costs), mode, options)
	local placement, reason = placementAt(ctx, buildState(from, agent, world), grid.X, grid.Y, grid.Z, mode, nil, options.Quick)

	if placement then
		return placement
	end

	return {
		Grid = grid,
		Position = Vector3.new(grid.X * cellSize, grid.Y * cellSize, grid.Z * cellSize),
		Mode = mode,
		PlacementType = 'None',
		Distance = (Vector3.new(grid.X * cellSize, grid.Y * cellSize, grid.Z * cellSize) - (from.Position or from)).Magnitude,
		Valid = false,
		Reason = reason
	}
end

function navigation.SolveVoid(self, from, options)
	options = options or {}

	local world = options.World or self.World
	local mode = options.Mode or 'Legit'
	local agent = merge(self.Config.Agent, options.Agent)
	local ctx = contextFor(self, world, agent, merge(self.Config.Costs, options.Costs), mode, options)
	local state = buildState(from, agent, world)
	local aim = state.Aim or (state.Velocity.Magnitude > 1 and Vector3.new(state.Velocity.X, 0, state.Velocity.Z).Unit or Vector3.new(0, -1, 0))

	for i = 1, 3 do
		local level = gridAxis(state.Position.Y - i * cellSize)
		if world:Block(state.CellX, level, state.CellZ) then
			local plane = level * cellSize + halfCell
			local drop = state.Eye.Y - plane
			local span = aim.Y < -0.05 and drop / -aim.Y or math.huge
			local x, z = state.CellX, state.CellZ

			if span < math.huge then
				x, z = gridAxis(state.Eye.X + aim.X * span), gridAxis(state.Eye.Z + aim.Z * span)
			end

			local dx, dz = x - state.CellX, z - state.CellZ
			local steps = math.max(math.abs(dx), math.abs(dz))
			for i2 = 0, steps do
				local cx = state.CellX + (steps > 0 and math.round(dx * i2 / steps) or 0)
				local cz = state.CellZ + (steps > 0 and math.round(dz * i2 / steps) or 0)
				if not world:Solid(cx, level, cz) then
					local placement = placementAt(ctx, state, cx, level, cz, mode, nil, options.Quick)
					if placement then
						placement.PlacementType = placement.PlacementType == 'Face' and 'Plane' or placement.PlacementType
						return placement
					end
					break
				end
			end
		end
	end

	local sx, sy, sz = voidSave(ctx, state)
	if sx then
		local placement = placementAt(ctx, state, sx, sy, sz, mode, nil, options.Quick)
		if placement then
			placement.PlacementType = 'Void'
			return placement
		end
	end

	return nil
end

function navigation.ValidatePath(self, result, options)
	options = options or {}

	local world = options.World or result.World or self.World
	local agent = merge(self.Config.Agent, options.Agent)
	local mode = result.Mode or 'Legit'
	local ctx = contextFor(self, world, agent, merge(self.Config.Costs, options.Costs), mode, options)
	local blocks = options.BlocksAvailable or agent.BlocksAvailable
	local used = 0

	ctx.World:Begin()

	for i, v in result.Actions do
		if v.Type == 'PlaceBlock' then
			used += 1
			if used > blocks then
				ctx.World:Finish()
				return false, 'Inventory', i
			end

			local placement, reason = placementAt(ctx, buildState({Position = v.ExpectedPosition}, agent), v.Grid.X, v.Grid.Y, v.Grid.Z, mode, nil, options.Quick)
			if not placement then
				ctx.World:Finish()
				table.clear(ctx.Fits)
				table.clear(ctx.Stands)
				return false, reason, i
			end

			writeCell(ctx, v.Grid.X, v.Grid.Y, v.Grid.Z, placement)
		elseif v.Type ~= 'Land' and v.Type ~= 'Wait' and not stands(ctx, v.Grid.X, v.Grid.Y, v.Grid.Z) then
			ctx.World:Finish()
			table.clear(ctx.Fits)
			table.clear(ctx.Stands)
			return false, 'Support', i
		end
	end

	ctx.World:Finish()
	table.clear(ctx.Fits)
	table.clear(ctx.Stands)
	return true, 'Valid', #result.Actions
end

function navigation.GetState(self, from, options)
	options = options or {}

	local world = options.World or self.World
	local agent = merge(self.Config.Agent, options.Agent)
	local cfg = merge(self.Config.Clutch, options.Clutch)
	local ctx = contextFor(self, world, agent, merge(self.Config.Costs, options.Costs), options.Mode or 'Legit', options)
	local state = buildState(from, agent, world)
	local landing = landingOf(ctx, state, agent, cfg)

	if state.Grounded and state.Velocity.Y >= 0 then
		return 'Normal', landing
	end
	if not landing then
		return 'Falling', nil
	end
	if landing.Damage > agent.DamageAllowance then
		return state.Velocity.Y < -agent.JumpVelocity and 'Falling' or 'Danger', landing
	end

	return 'Normal', landing
end

function navigation.IsStale(self, result)
	local world = result.World or self.World
	if not world or world.Revision == result.Revision then
		return false
	end
	if world.Flush ~= result.Flush then
		return true
	end

	for i = result.DirtyIndex + 1, world.DirtyIndex do
		local key = world.Dirty[i]
		if result.Depends[key] and not (result.Planned and result.Planned[key]) then
			return true
		end
	end

	return false
end

function navigation.newDebugAdapter(parent, limit)
	local pool = {}
	local index = 0
	local model = Instance.new('Model')
	model.Name = 'navigation'
	model.Parent = parent or workspace.Terrain

	return {
		Model = model,
		Point = function(position, color, size)
			if index >= (limit or 600) then
				return
			end

			index += 1
			local part = pool[index]
			if not part then
				part = Instance.new('Part')
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Material = Enum.Material.Neon
				part.Parent = model
				pool[index] = part
			end

			part.Size = Vector3.new(size or 1, size or 1, size or 1)
			part.Color = color
			part.Transparency = 0.55
			part.Position = position
		end,
		Clear = function()
			for i = 1, index do
				pool[i].Transparency = 1
				pool[i].Position = Vector3.new(9e9, 9e9, 9e9)
			end
			index = 0
		end
	}
end

function navigation.Visualize(self, result)
	if not self.DebugAdapter then
		self.DebugAdapter = self.newDebugAdapter()
	end

	self.DebugAdapter.Clear()

	for _, v in result.Actions do
		if v.Type == 'PlaceBlock' then
			self.DebugAdapter.Point(v.Position, v.PlacementType == 'Diagonal' and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(70, 140, 255), cellSize - 0.4)
			self.DebugAdapter.Point(v.AimPosition, Color3.fromRGB(255, 255, 255), 0.5)
		elseif v.Type == 'Land' then
			self.DebugAdapter.Point(v.Position, Color3.fromRGB(255, 60, 60), 1.4)
		else
			self.DebugAdapter.Point(v.Position, v.Type == 'Jump' and Color3.fromRGB(255, 230, 90) or Color3.fromRGB(90, 255, 120), 1)
		end
	end

	return self.DebugAdapter
end

return navigation