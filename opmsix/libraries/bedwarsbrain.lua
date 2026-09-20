local brain = {}
local controller = {}
controller.__index = controller

brain.Config = {
	ThinkInterval = 0.2,
	ReactionTime = 0.18,
	ObservationLifetime = 8,
	EnemyLifetime = 12,
	FailureLifetime = 60,
	FailureCooldown = 4,
	MemoryLimit = 64,
	CommitTime = 1.5,
	SwitchMargin = 12,
	GoalTimeout = 35,
	CollectTimeout = 15,
	FightTimeout = 8,
	RecoveryLimit = 3,
	RecoveryWait = 3,
	PostKillWait = 0.8,
	BasePreference = 12,
	JumpCommitTime = 1.2,
	RangedInterval = 1,
	ArrivalRadius = 5,
	BaseRadius = 16,
	LowHealth = 0.4,
	CriticalHealth = 0.22,
	RecoverHealth = 0.7,
	HighHealth = 0.8,
	BlockReserve = 8,
	TravelBlocks = 24,
	IronReserve = 8,
	DiamondTarget = 4,
	EmeraldTarget = 2,
	ValuableThreshold = 20,
	ResourceWeights = {iron = 0.08, diamond = 5, emerald = 15},
	EarlyTime = 180,
	LateTime = 600,
	ThreatRadius = 60,
	LethalRange = 18,
	BedThreatRadius = 35,
	SupportRadius = 24,
	HighGround = 6,
	ChaseSpeed = 3,
	UnknownDamage = 30,
	UnknownArmor = 0.25,
	UnknownEnemyHealth = 100,
	AttackInterval = 0.4,
	ForecastTime = 1.2,
	MaxThreat = 45,
	FightThreshold = 12,
	FinishSupport = 1,
	RouteRiskLimit = 65,
	SafeRouteRisk = 30,
	RouteEnemyRadius = 25,
	RouteSampleLimit = 80,
	PlanTimeout = 4,
	PlanSteps = 12000,
	StuckTime = 2.5,
	ProgressDistance = 0.75,
	PlacementTimeout = 0.8,
	PlacementCooldown = 0.16,
	BuildLimit = 8,
	DebugLimit = 80,
	Priorities = {
		WaitForSpawn = 1000, Recover = 1000, WaitForInformation = 120,
		DefendBed = 245, ReturnToBase = 230, Escape = 230, BuildCover = 230,
		BuildUp = 229, SurvivalCombat = 225, Hide = 220, Finish = 290,
		Harass = 150, Reposition = 140, Fight = 120, CollectResources = 65,
		AttackBed = 70, SupportTeam = 110, CollectDrops = 85, Reassess = 1
	},
	Weights = {
		Enemy = 28, ExtraEnemy = 16, Weapon = 0.5, Elevation = 12,
		Projectile = 16, Void = 30, Narrow = 22, Uncertainty = 15,
		Support = 14, Cover = 10, Escape = 12, Health = 35,
		Equipment = 0.6, Isolation = 14, Resources = 0.35,
		NoBed = 20, Travel = 0.12, Failure = 18, Turns = 1.5,
		Jump = 6, Block = 2, Time = 0.8
	}
}

local function merge(base, override)
	local result = {}
	for i, v in base do
		result[i] = type(v) == 'table' and merge(v, override and override[i]) or v
	end
	for i, v in override or {} do
		if type(v) ~= 'table' then result[i] = v end
	end
	return result
end

function brain.new(config)
	return setmetatable({
		Config = merge(brain.Config, config),
		WorldState = {self = {}, environment = {}, enemies = {}, teammates = {}},
		Memory = {failures = {}, surfaces = {}, events = {}},
		GoalStack = {},
		Debug = {},
		Revision = 0,
		Retreating = false,
		Recovery = 0,
		NextAction = 0
	}, controller)
end

function controller.Record(self, kind, key, reason, now, position)
	local entry = {kind = kind, key = key, reason = reason, timestamp = now, position = position}
	table.insert(self.Memory.events, entry)
	if #self.Memory.events > self.Config.MemoryLimit then table.remove(self.Memory.events, 1) end
	if kind == 'failure' then
		local previous = self.Memory.failures[key]
		entry.count = previous and now - previous.timestamp < self.Config.FailureLifetime and previous.count + 1 or 1
		self.Memory.failures[key] = entry
		local count, oldest = 0, nil
		for i, v in self.Memory.failures do
			count += 1
			if not oldest or v.timestamp < self.Memory.failures[oldest].timestamp then oldest = i end
		end
		if count > self.Config.MemoryLimit then self.Memory.failures[oldest] = nil end
		self.Recovery = math.min(self.Recovery + 1, self.Config.RecoveryLimit)
		self.NextAction = now + (self.Recovery >= self.Config.RecoveryLimit and self.Config.RecoveryWait or self.Config.ReactionTime)
		self.Goal = nil
		self.Revision += 1
	elseif kind == 'kill' then
		self.NextAction = now + self.Config.PostKillWait
		self.Goal = nil
		self.Revision += 1
	elseif kind == 'bedlost' then
		self.Retreating = true
		self.Goal = nil
		self.Revision += 1
	end
end

function controller.Observe(self, snapshot, now)
	if self.Snapshot and self.Snapshot.environment.ownBed == true and snapshot.environment.ownBed == false then
		self:Record('bedlost', 'base', 'Bed lost; switch to survival risk limits', now)
	end
	self.Snapshot = snapshot
	for _, v in {'self', 'environment'} do
		for i2, v2 in snapshot[v] or {} do
			local source = snapshot.sources and snapshot.sources[i2] or (v == 'self' and 'character' or 'cache')
			self.WorldState[v][i2] = {value = v2, timestamp = now, confidence = snapshot.confidence and snapshot.confidence[i2] or 1, source = source}
		end
		for i2, v2 in self.WorldState[v] do
			if (snapshot[v] or {})[i2] == nil then
				v2.confidence = math.max(0, 1 - (now - v2.timestamp) / self.Config.ObservationLifetime)
			end
		end
	end
	for _, v in {'enemies', 'teammates'} do
		for _, v2 in snapshot[v] or {} do
			if v2.visible or v == 'teammates' then
				self.WorldState[v][v2.id] = {value = v2, timestamp = now, confidence = v2.confidence or 1, source = 'raycast'}
			elseif not self.WorldState[v][v2.id] then
				self.WorldState[v][v2.id] = {value = {id = v2.id}, timestamp = now, confidence = 0, source = 'cache'}
			end
		end
		for i2, v2 in self.WorldState[v] do
			v2.confidence = v2.value.position and math.max(0, 1 - (now - v2.timestamp) / self.Config.EnemyLifetime) * (v2.value.confidence or 1) or 0
			if now - v2.timestamp > self.Config.EnemyLifetime then self.WorldState[v][i2] = nil end
		end
	end
	for i, v in self.Memory.failures do
		if now - v.timestamp > self.Config.FailureLifetime then self.Memory.failures[i] = nil end
	end
	if snapshot.self.safeSurface and snapshot.self.position then
		local previous = self.Memory.surfaces[#self.Memory.surfaces]
		if not previous or (previous.position - snapshot.self.position).Magnitude > self.Config.BaseRadius then
			table.insert(self.Memory.surfaces, {id = 'surface:' .. tostring(now), kind = 'surface', position = snapshot.self.position, timestamp = now, confidence = 1})
			if #self.Memory.surfaces > self.Config.MemoryLimit then table.remove(self.Memory.surfaces, 1) end
		end
	end
	self.ObservedAt = now
	self.WorldState.environment.destinations = {value = snapshot.destinations, timestamp = now, confidence = 1, source = 'cache'}
	self.WorldState.environment.bedThreat = {value = snapshot.environment.bedThreat, timestamp = now, confidence = 1, source = 'character'}
	for _, v in {'inventorySpace', 'healing', 'storage', 'canBuildUp', 'escapeAvailable', 'currentTarget', 'currentSubgoal', 'currentRoute', 'currentEscapeRoute'} do
		if not self.WorldState.self[v] then self.WorldState.self[v] = {timestamp = now, confidence = 0, source = 'cache'} end
	end
end

function controller.Assess(self, now)
	local state, environment = self.Snapshot.self, self.Snapshot.environment
	local config = self.Config
	local ratio = state.health and state.maxHealth and state.maxHealth > 0 and math.clamp(state.health / state.maxHealth, 0, 1) or 0
	local result = {ratio = ratio, count = 0, pressure = 0, damage = 0, support = 0, valuable = 0, nearest = math.huge, ranged = false, chased = false, uncertainty = 0}
	for i, v in config.ResourceWeights do
		result.valuable += ((state.resources or {})[i] or 0) * v
	end
	result.carrying = result.valuable >= config.ValuableThreshold
	for _, v in self.WorldState.teammates do
		if v.value.position and (v.value.position - state.position).Magnitude <= config.SupportRadius and v.confidence > 0.5 then
			result.support += 1
		end
	end
	for _, v in self.WorldState.enemies do
		local enemy = v.value
		if not enemy.position or v.confidence <= 0 then
			result.uncertainty += 1
			continue
		end
		local distance = (enemy.position - state.position).Magnitude
		local current = now - v.timestamp <= config.ThinkInterval * 2 and enemy.visible
		if distance < config.ThreatRadius then
			local proximity = 1 - distance / config.ThreatRadius
			local damage = (enemy.damage or config.UnknownDamage) * (1 - (state.armor or 0))
			result.pressure += proximity * config.Weights.Enemy * (current and 1 or math.max(v.confidence, 0.25))
			if current then
				if distance <= config.LethalRange then result.count += 1 end
				result.damage = math.max(result.damage, damage)
				result.ranged = result.ranged or enemy.projectiles == true
				if distance < result.nearest then
					result.nearest, result.target = distance, enemy
				end
				local direction = state.position - enemy.position
				result.chased = result.chased or direction.Magnitude > 0.1 and (enemy.velocity or Vector3.zero):Dot(direction.Unit) > config.ChaseSpeed
			else
				result.uncertainty += proximity * v.confidence
			end
		end
	end
	result.highGround = result.target and result.target.position.Y - state.position.Y > config.HighGround or false
	result.oneHit = result.damage > 0 and (state.health or 0) <= result.damage
	result.twoHits = result.damage > 0 and (state.health or 0) <= result.damage * 2
	result.incoming = result.damage * math.max(result.count, 1) * config.ForecastTime / config.AttackInterval
	result.escapeTime = state.distanceToSafety and state.distanceToSafety / math.max(state.speed or 1, 1) or math.huge
	result.canEscape = state.escapeAvailable == true and (result.nearest > config.LethalRange or result.escapeTime < (state.health or 0) / math.max(result.incoming, 1) * config.ForecastTime)
	result.score = result.pressure + math.max(result.count - 1, 0) * config.Weights.ExtraEnemy
		+ (result.highGround and config.Weights.Elevation or 0)
		+ (result.ranged and config.Weights.Projectile or 0)
		+ (state.nearVoid and config.Weights.Void or 0)
		+ (state.narrowBridge and config.Weights.Narrow or 0)
		+ math.min(result.uncertainty, 1) * config.Weights.Uncertainty
		+ (1 - ratio) * config.Weights.Health
		+ (environment.ownBed ~= true and config.Weights.NoBed or 0)
		- result.support * config.Weights.Support
		- (state.cover and config.Weights.Cover or 0)
		- (state.escapeAvailable and config.Weights.Escape or 0)
	result.healthState = (ratio <= config.CriticalHealth or result.oneHit and result.nearest <= config.LethalRange and (state.nearVoid or result.carrying or result.count > 1)) and 'Critical' or nil
	result.healthState = result.healthState or (ratio <= config.LowHealth and 'Low' or ratio < config.HighHealth and 'Medium' or 'High')
	result.phase = environment.ownBed == false and 'Late' or (environment.matchTime or 0) >= config.LateTime and 'Late' or (environment.matchTime or 0) >= config.EarlyTime and 'Mid' or 'Early'
	local enemyHealth = result.target and result.target.health or config.UnknownEnemyHealth
	local dealt = (state.swordDamage or 0) * (1 - (result.target and result.target.armor or config.UnknownArmor))
	result.fightScore = (ratio - enemyHealth / config.UnknownEnemyHealth) * config.Weights.Health
		+ (dealt - result.damage) * config.Weights.Equipment
		+ result.support * config.Weights.Support + (result.count <= 1 and config.Weights.Isolation or 0)
		- result.score - result.valuable * config.Weights.Resources
	result.finish = result.target and enemyHealth <= dealt and result.nearest <= config.LethalRange and result.count == 1
		and not state.nearVoid and not state.narrowBridge and not result.highGround and state.escapeAvailable == true
		and (not result.oneHit or result.support >= config.FinishSupport) and not result.carrying
	if ratio <= config.LowHealth or result.healthState == 'Critical' or result.count > 1 and result.score >= config.MaxThreat then
		self.Retreating = true
	elseif self.Retreating and ratio >= config.RecoverHealth and result.count == 0 and result.score < config.MaxThreat then
		self.Retreating = false
	end
	self.Assessment = result
	return result
end

function controller.RouteRisk(self, positions, now)
	local risk, nearest, unknown = 0, math.huge, false
	for _, v in self.WorldState.enemies do
		if not v.value.position then
			unknown = true
			continue
		end
		local distance = math.huge
		for _, v2 in positions do distance = math.min(distance, (v2 - v.value.position).Magnitude) end
		nearest = math.min(nearest, distance)
		if distance < self.Config.RouteEnemyRadius then
			risk += (1 - distance / self.Config.RouteEnemyRadius) * self.Config.Weights.Enemy * math.max(v.confidence, 0.25)
		end
	end
	for _, v in self.Memory.failures do
		if v.position and now - v.timestamp < self.Config.FailureLifetime then
			for _, v2 in positions do
				if (v2 - v.position).Magnitude < self.Config.ArrivalRadius then
					risk += self.Config.Weights.Failure * v.count
					break
				end
			end
		end
	end
	return risk + (unknown and self.Config.Weights.Uncertainty or 0), nearest
end

function controller.Decide(self, now)
	local state, environment, config = self.Snapshot.self, self.Snapshot.environment, self.Config
	local assessment = self:Assess(now)
	local candidates = {}
	local danger = self.Retreating or assessment.score >= config.MaxThreat or state.narrowBridge and assessment.target ~= nil
	local function add(name, priority, reason, destination, action, emergency, category)
		local id = tostring(name) .. ':' .. tostring(destination and destination.id or '')
		local failed = self.Memory.failures[id]
		if failed and name ~= 'Recover' and (action ~= 'Wait' or destination) and now - failed.timestamp < (failed.count >= config.RecoveryLimit and config.FailureLifetime or config.FailureCooldown * failed.count) then return end
		priority = (config.Priorities[name] or priority) + (name == 'ReturnToBase' and config.BasePreference or 0)
		local risk = destination and self:RouteRisk({destination.position}, now) or 0
		local distance = destination and (destination.position - state.position).Magnitude or 0
		table.insert(candidates, {
			id = id, name = name, priority = priority, reason = reason, destination = destination,
			action = action, emergency = emergency == true, interruptible = not emergency,
			category = category or 'Valuable', risk = risk,
			score = priority - risk - distance * config.Weights.Travel - (failed and failed.count * config.Weights.Failure or 0),
			timeout = action == 'Collect' and config.CollectTimeout or action == 'Fight' and config.FightTimeout or config.GoalTimeout
		})
	end
	if not state.alive or environment.matchEnded then
		add('WaitForSpawn', 1000, 'Character unavailable or match finished', nil, 'Wait', true, 'Essential')
	elseif state.falling then
		add('Recover', 1000, 'Falling without a verified landing', nil, 'Recover', true, 'Essential')
	elseif now - self.ObservedAt > config.ObservationLifetime or not state.health or not state.maxHealth then
		add('WaitForInformation', 950, 'Health or perception is uncertain', nil, 'Wait', true, 'Essential')
	else
		local threatened = environment.bedThreat == true
		local purchase = self.Snapshot.purchase
		local saving = purchase and purchase.currency ~= 'iron' and (state.resources[purchase.currency] or 0) < purchase.cost and assessment.ratio >= config.HighHealth and assessment.count == 0 and not assessment.chased and assessment.score < config.SafeRouteRisk
		local returning = assessment.carrying and not state.insideBase and not saving
		local escape = {}
		for _, v in self.Snapshot.destinations or {} do
			if v.kind == 'base' or v.kind == 'teammate' or v.kind == 'surface' or v.kind == 'cover' or v.kind == 'shop' then
				table.insert(escape, v)
			end
		end
		for _, v in self.Memory.surfaces do
			if now - v.timestamp < config.ObservationLifetime then table.insert(escape, v) end
		end
		if danger or returning or threatened then
			for _, v in escape do
				local risk = self:RouteRisk({v.position}, now)
				if risk <= (threatened and not danger and config.RouteRiskLimit or config.SafeRouteRisk) and (not danger or not assessment.target or (v.position - assessment.target.position).Magnitude > assessment.nearest + config.ArrivalRadius) then
					local home = v.kind == 'base'
					local defend = threatened and home and not self.Retreating
					add(defend and 'DefendBed' or home and 'ReturnToBase' or 'Escape', (defend and 220 or danger and 230 or 160) + (home and config.BasePreference or 0),
						defend and 'Enemy entered the base' or returning and 'Secure valuable resources' or 'Reach verified safety before continuing', v,
						'Wait', danger or threatened, 'Essential')
				end
			end
			if #candidates == 0 and danger then
				if state.canBuildCover and state.blocks > config.BlockReserve then
					add('BuildCover', 230, 'No safe horizontal route; block pursuit or line of sight', nil, 'BuildCover', true, 'Essential')
				end
				if state.canBuildUp and self.Snapshot.upperExit and not assessment.ranged and not state.nearVoid and not state.falling then
					add('BuildUp', 229, 'Verified upper exit and descent are safer than remaining here', self.Snapshot.upperExit, 'Wait', true, 'Essential')
				end
				if assessment.target and assessment.nearest <= config.LethalRange and state.swordDamage > 0 then
					add('SurvivalCombat', 225, 'No safe escape; resist immediate lethal pressure', assessment.target, 'Fight', true, 'Essential')
				end
				add('Hide', 220, 'Wait for a verified escape without stepping into danger', nil, 'Wait', true, 'Essential')
			end
		end
		if threatened and not self.Retreating and not assessment.carrying and assessment.target and not state.nearVoid and not state.narrowBridge and assessment.count <= 1 then
			add('DefendBed', 245, 'Remove an isolated intruder before resuming collection', assessment.target, 'Fight', true, 'Essential')
		end
		if assessment.finish then
			add('Finish', 260, 'Isolated one-hit enemy on safe ground with a supported escape', assessment.target, 'Fight', true)
		elseif not danger and not returning and not threatened and now >= self.NextAction and assessment.target then
			if assessment.highGround then
				if (state.projectiles or 0) > 0 and state.safeSurface and state.cover and assessment.nearest > config.LethalRange and state.escapeAvailable then
					add('Harass', 150, 'Use cover and a ranged weapon against high ground', assessment.target, 'Harass')
				end
				if state.canBuildCover then add('BuildCover', 145, 'Enemy controls high ground', nil, 'BuildCover', true) end
				for _, v in escape do
					if (v.position - assessment.target.position).Magnitude > assessment.nearest then
						add('Reposition', 140, 'Change approach instead of charging high ground', v, 'Wait', true)
					end
				end
				add('WaitForInformation', 120, 'High ground cannot be challenged safely', nil, 'Wait', true)
			elseif assessment.fightScore >= config.FightThreshold and state.escapeAvailable and not state.nearVoid and not state.narrowBridge and state.swordDamage > 0 then
				add('Fight', 120, 'Isolated opponent; health, equipment and escape justify engagement', assessment.target, 'Fight')
			end
		end
		if not danger and not returning and not threatened and now >= self.NextAction then
			if purchase and state.inventorySpace ~= false then
				local missing = math.max(purchase.cost - ((state.resources or {})[purchase.currency] or 0), 0)
				for _, v in self.Snapshot.destinations or {} do
					if missing > 0 and v.kind == 'generator' and v.resource == purchase.currency then
						add('CollectForPurchase', state.blocks <= config.BlockReserve and 115 or 90, 'Need ' .. tostring(missing) .. ' ' .. tostring(purchase.currency) .. ' for ' .. tostring(purchase.item), v, 'Collect')
					elseif missing == 0 and v.kind == (purchase.upgrade and 'upgrade' or 'shop') then
						add('BuyEquipment', state.blocks <= config.BlockReserve and 116 or 95, 'Purchase ' .. tostring(purchase.item) .. '; preserve survival reserves', v, 'Buy')
					end
				end
			end
			if state.blocks >= config.TravelBlocks and assessment.ratio > config.LowHealth then
				for _, v in self.Snapshot.destinations or {} do
					if v.kind == 'generator' and v.resource ~= 'iron' and not assessment.carrying and state.inventorySpace ~= false and assessment.phase ~= 'Early' then
						if v.resource == 'diamond' and (state.resources.diamond or 0) < config.DiamondTarget or v.resource == 'emerald' and (state.resources.emerald or 0) < config.EmeraldTarget and assessment.ratio >= config.HighHealth and (assessment.support > 0 or assessment.score < config.SafeRouteRisk / 2) then
							add('CollectResources', v.resource == 'emerald' and 55 or 65, 'Collect a useful amount of ' .. tostring(v.resource) .. ' with an escape', v, 'Collect', false, 'Optional')
						end
					elseif v.kind == 'enemybed' and self.Snapshot.canBreakBed and not assessment.carrying and assessment.ratio >= config.HighHealth and environment.ownBed == true and state.escapeAvailable then
						add('AttackBed', 70, 'Healthy, equipped and able to withdraw', v, 'BreakBed', false, 'Optional')
					elseif v.kind == 'teammate' and v.underPressure and assessment.fightScore >= config.FightThreshold then
						add('SupportTeam', 110, 'Nearby teammate can be supported without a second death', v, 'Wait')
					elseif v.kind == 'drop' and not assessment.carrying and assessment.count == 0 and state.inventorySpace ~= false then
						add('CollectDrops', 85, 'Collect visible useful resources after checking reinforcements', v, 'Collect', false, 'Optional')
					end
				end
			end
		end
		add('Reassess', 1, now < self.NextAction and 'Recovering or checking for reinforcements' or 'No useful action has a verified safety advantage', nil, 'Wait')
	end
	table.sort(candidates, function(a, b)
		if a.emergency ~= b.emergency then return a.emergency end
		if a.score ~= b.score then return a.score > b.score end
		return a.id < b.id
	end)
	local selected = candidates[1]
	if self.Goal and now - self.Goal.started > self.Goal.timeout and self.Goal.action ~= 'Wait' then
		self:Record('failure', self.Goal.id, 'Objective timed out without useful progress', now, state.position)
		return self:Decide(now)
	end
	for _, v in candidates do
		if self.Goal and v.id == self.Goal.id and (not selected.emergency or v.emergency and selected.priority <= v.priority) and (now - self.Goal.started < config.CommitTime or selected.score < v.score + config.SwitchMargin) then
			selected = v
			break
		end
	end
	selected.started = self.Goal and selected.id == self.Goal.id and self.Goal.started or now
	if not self.Goal or selected.id ~= self.Goal.id then
		self.Revision += 1
		table.insert(self.Debug, {timestamp = now, goal = selected.name, reason = selected.reason, threat = assessment.score, health = assessment.healthState, resources = assessment.valuable, combat = selected.action == 'Fight' and (selected.name == 'Finish' and 'FINISH' or 'FIGHT') or danger and 'RETREAT' or 'ABORT'})
		if #self.Debug > config.DebugLimit then table.remove(self.Debug, 1) end
	end
	self.Goal, self.GoalStack = selected, candidates
	self.WorldState.self.currentGoal = {value = selected.name, timestamp = now, confidence = 1, source = 'cache'}
	self.WorldState.self.currentTarget = {value = selected.destination or false, timestamp = now, confidence = 1, source = 'cache'}
	self.WorldState.self.currentSubgoal = {value = selected.action, timestamp = now, confidence = 1, source = 'cache'}
	self.WorldState.self.currentThreat = {value = assessment, timestamp = now, confidence = math.max(0, 1 - assessment.uncertainty / 4), source = 'cache'}
	return selected
end

return brain
