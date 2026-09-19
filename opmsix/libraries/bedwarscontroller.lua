local controller = {}
local agent = {}
agent.__index = agent

function controller.new(brain, navigation, adapter)
	return setmetatable({
		Brain = brain, Navigation = navigation, Adapter = adapter,
		Running = true, Generation = 0, NextThink = 0, NextPlace = 0,
		NextAttack = 0, Index = 1, RecoveryState = 'REASSESS'
	}, agent)
end

function controller.Pattern(name, grid, direction)
	local forward = math.abs(direction.X) > math.abs(direction.Z) and Vector3.new(math.sign(direction.X), 0, 0) or Vector3.new(0, 0, math.sign(direction.Z))
	if forward.Magnitude == 0 then forward = Vector3.new(1, 0, 0) end
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local up = Vector3.new(0, 1, 0)
	local patterns = {
		Tower = {grid + up, grid + up * 2},
		Staircase = {grid + forward, grid + forward * 2 + up, grid + forward * 3 + up * 2},
		SideWall = {grid + side + up, grid + side + up * 2},
		Roof = {grid + forward + up, grid + forward + up * 2, grid + forward + up * 3, grid + up * 3},
		Cover = {grid + forward + up, grid + forward + up * 2},
		EmergencyPlatform = {grid + forward, grid + forward + side, grid + forward - side},
		Bridge = {grid + forward, grid + forward * 2, grid + forward * 3},
		Barrier = {grid + forward + up, grid + forward + side + up, grid + forward - side + up},
		RetreatBlocker = {grid - forward + up, grid - forward + up * 2},
		Landing = {grid + forward, grid + forward + side, grid + forward - side}
	}
	return patterns[name]
end

function agent.Cancel(self)
	self.Generation += 1
	if self.Request then self.Request:Cancel() end
	self.Request, self.Route, self.Pending, self.Build, self.TowerJump = nil, nil, nil, nil, nil
	self.Index, self.Jumping, self.RouteGoal, self.ActiveGoal = 1, nil, nil, nil
	self.Adapter.Stop()
end

function agent.Destroy(self)
	self.Running = false
	self:Cancel()
	self.Purchase = nil
	self.RecoveryState = 'RESET_GOAL'
end

function agent.Fail(self, reason, now)
	local goal = self.Brain.Goal
	self.Brain:Record('failure', goal and goal.id or 'action', reason, now, self.Brain.Snapshot.self.position)
	self:Cancel()
	if self.Purchase and self.Purchase.done then self.Purchase = nil end
	self.NextThink = 0
	self.RecoveryState = self.Brain.Recovery >= self.Brain.Config.RecoveryLimit and 'WAIT_FOR_INFORMATION' or 'REPATH'
	self.Adapter.Log('failure', reason)
end

function agent.Options(self, state, emergency)
	local config = self.Brain.Config
	local cautious = self.Brain.Retreating or self.Brain.Assessment.carrying or self.Brain.Assessment.ranged
	return {
		Channel = 'bedwarsai', Mode = 'Legit',
		BlocksAvailable = math.max(0, state.blocks - (emergency and 0 or config.BlockReserve)),
		Agent = {
			WalkSpeed = state.speed, HipHeight = state.hipHeight, JumpVelocity = state.jumpVelocity,
			Gravity = state.gravity, MaxDrop = cautious and 6 or 12, DamageAllowance = 0
		},
		Search = {
			MaxSteps = config.PlanSteps, WalkSteps = config.PlanSteps, Fallback = false,
			Smooth = false, Bridge = not cautious and state.blocks > config.BlockReserve,
			Tower = self.Brain.Goal and self.Brain.Goal.name == 'BuildUp', JumpGap = not cautious,
			GoalDrop = 4
		}
	}
end

function agent.Place(self, grid, now, emergency)
	if not self.Running then return 'failed' end

	local state, config = self.Brain.Snapshot.self, self.Brain.Config
	if self.Adapter.Block(grid) then
		self.Pending = nil
		return 'complete'
	end
	if self.Pending then
		if now - self.Pending.started > config.PlacementTimeout then
			self:Fail('Placement was not confirmed by collision geometry', now)
			return 'failed'
		end
		return 'pending'
	end
	if now < self.NextPlace then return 'pending' end
	if state.blocks <= (emergency and 0 or config.BlockReserve) then
		self:Fail('Emergency block reserve would be spent', now)
		return 'failed'
	end
	local placement = self.Navigation:SolvePlacement({Position = state.position, Velocity = state.velocity, Grounded = state.grounded}, grid, {Mode = 'Legit'})
	self.Brain.WorldState.environment.lastPlacement = {value = placement, timestamp = now, confidence = 1, source = 'cache'}
	if not placement.Valid and placement.Reason == 'Body' and self.Brain.Goal.name == 'BuildUp' and state.grounded and not self.TowerJump then
		self.TowerJump = now
		self.Adapter.Move(state.position, true)
		return 'pending'
	end
	if not placement.Valid and self.TowerJump and now - self.TowerJump < config.JumpCommitTime then return 'pending' end
	if not placement.Valid or not self.Adapter.ValidatePlacement(placement, self.Route and self.Route.Actions[self.Index + 1]) then
		self:Fail(`Invalid placement: {placement.Reason or 'collision, movement or escape corridor'}`, now)
		return 'failed'
	end
	self.NextPlace = now + math.max(config.PlacementCooldown, state.placeInterval or 0)
	self.Pending = {grid = grid, started = now}
	self.TowerJump = nil
	self.Adapter.Place(placement.Position)
	return 'pending'
end

function agent.Navigate(self, goal, now)
	local state, config = self.Brain.Snapshot.self, self.Brain.Config
	local destination = goal.destination
	if not destination or not self.Adapter.Valid(destination) then
		self:Fail('Destination disappeared or changed team', now)
		return false
	end
	if (destination.position - state.position).Magnitude <= (goal.action == 'Fight' and (state.attackRange or config.LethalRange * 0.65) or config.ArrivalRadius) then
		self.Adapter.Stop()
		if self.Request then self.Request:Cancel() end
		self.Route, self.Request = nil, nil
		return true
	end
	if self.RouteGoal and (destination.position - self.RouteGoal).Magnitude > config.ArrivalRadius then self:Cancel() end
	if self.Request then
		if self.Request.Done then
			local result = self.Request.Result
			self.Request = nil
			if not result or not result.Success or result.Partial then
				self:Fail(result and result.Reason or 'Path computation failed', now)
				return false
			end
			local samples, jumps, turns, narrow, previous, lastDirection = {}, 0, 0, false, state.position, nil
			local stride = math.max(1, math.ceil(#result.Actions / config.RouteSampleLimit))
			for i, v in result.Actions do
				if v.Type ~= 'PlaceBlock' then
					if i % stride == 0 or i == #result.Actions then
						table.insert(samples, v.Position)
						local surface = self.Adapter.Surface(v.Position)
						narrow = narrow or surface.narrow
					end
					jumps += v.Type == 'Jump' and 1 or 0
					local direction = (v.Position - previous) * Vector3.new(1, 0, 1)
					if direction.Magnitude > 0.1 then
						turns += lastDirection and lastDirection:Dot(direction.Unit) < 0.5 and 1 or 0
						lastDirection = direction.Unit
					end
					previous = v.Position
				end
			end
			local risk, nearest = self.Brain:RouteRisk(samples, now)
			local danger = risk + jumps * config.Weights.Jump + turns * config.Weights.Turns + result.BlocksUsed * config.Weights.Block + (narrow and config.Weights.Narrow or 0)
			local limit = (self.Brain.Retreating or self.Brain.Assessment.carrying) and config.SafeRouteRisk or config.RouteRiskLimit
			local destinationRisk = self.Brain:RouteRisk({destination.position}, now)
			if danger > limit or goal.emergency and self.Brain.Assessment.target and nearest + config.ArrivalRadius < self.Brain.Assessment.nearest
				or goal.name ~= 'BuildUp' and (self.Brain.Retreating or self.Brain.Assessment.carrying) and (result.BlocksUsed > 0 or jumps > 0 or destinationRisk > config.SafeRouteRisk) then
				self:Fail('Route exposes health or cargo to unacceptable risk', now)
				return false
			end
			self.Route, self.Index = result, 1
			self.ProgressAt, self.ProgressPosition, self.ProgressDistance = now, state.position, math.huge
			self.Brain.WorldState.self.currentRoute = {value = result, timestamp = now, confidence = 1, source = 'cache'}
			self.Brain.WorldState.self.currentEscapeRoute = {value = goal.emergency and result or false, timestamp = now, confidence = 1, source = 'cache'}
			self.Brain.WorldState.environment.bridgeQuality = {value = {narrow = narrow, jumps = jumps, turns = turns, blocks = result.BlocksUsed, risk = danger}, timestamp = now, confidence = 1, source = 'raycast'}
		elseif now - self.RequestedAt > config.PlanTimeout then
			self:Fail('Navigation exceeded its planning deadline', now)
		end
		return false
	end
	if not self.Route then
		self.Adapter.Stop()
		self.RequestedAt, self.RouteGoal = now, destination.position
		self.Request = self.Navigation:FindPathAsync({Position = state.position, Velocity = state.velocity, Grounded = state.grounded}, destination.position, self:Options(state))
		return false
	end
	if self.Navigation:IsStale(self.Route) then
		self:Fail('Route support changed', now)
		return false
	end
	local action = self.Route.Actions[self.Index]
	if not action then
		self:Fail('Route ended outside interaction range', now)
		return false
	end
	if action.Type == 'PlaceBlock' then
		self.Adapter.Stop()
		if self:Place(action.Grid, now) == 'complete' then
			self.Index += 1
			self.ProgressAt = now
		end
		return false
	end
	local distance = (action.Position - state.position).Magnitude
	if distance <= config.ArrivalRadius * 0.35 then
		self.Index += 1
		self.ProgressAt, self.ProgressDistance = now, math.huge
		self.Jumping = nil
		return false
	end
	if distance < self.ProgressDistance - config.ProgressDistance then
		self.ProgressAt, self.ProgressDistance = now, distance
	end
	if now - self.ProgressAt > config.StuckTime then
		self:Fail('Movement stalled or building has no continuation', now)
		return false
	end
	local jump = action.Type == 'Jump' and not self.Jumping and state.grounded
	if not self.Adapter.ValidateMove(action, self.Jumping ~= nil) then
		self:Fail('Next movement lacks collision support or clearance', now)
		return false
	end
	if jump then self.Jumping = now end
	self.Adapter.Move(action.Position, jump, action.Type)
	self.RecoveryState = 'REASSESS'
	return false
end

function agent.Step(self, snapshot, now)
	if not self.Running then return end

	if self.Jumping and self.Route and now - self.Jumping < self.Brain.Config.JumpCommitTime then
		local landing = self.Route.Actions[self.Index]
		if landing and self.Adapter.ValidateMove(landing, true) and (landing.Position - snapshot.self.position):Dot(snapshot.self.velocity) > 0 then
			snapshot.self.falling = false
		end
	end
	snapshot.self.currentlyBuilding = self.Pending ~= nil
	snapshot.self.currentlyAttacking = self.Brain.Goal and self.Brain.Goal.action == 'Fight' or false
	snapshot.self.currentlyRetreating = self.Brain.Retreating
	self.Brain:Observe(snapshot, now)
	local previous = self.Brain.Goal
	if now >= self.NextThink or snapshot.self.falling or snapshot.self.underPressure or not snapshot.self.alive or snapshot.environment.bedThreat or previous and previous.destination and not self.Adapter.Valid(previous.destination) then
		self.Brain:Decide(now)
		self.NextThink = now + self.Brain.Config.ThinkInterval
	end
	local goal, config = self.Brain.Goal, self.Brain.Config
	if not goal then return end
	if self.ActiveGoal ~= goal.id then
		if self.Jumping and self.Route and not snapshot.self.grounded and not snapshot.self.falling and now - self.Jumping < config.JumpCommitTime then
			local landing = self.Route.Actions[self.Index]
			if landing and self.Adapter.ValidateMove(landing, true) then
				self.Adapter.Move(landing.Position, false)
				return
			end
		end
		self:Cancel()
		self.ActiveGoal = goal.id
		self.ReadyAt = now + (goal.emergency and 0 or config.ReactionTime)
		self.Adapter.Log(goal.name, goal.reason)
	end
	if now < (self.ReadyAt or 0) then return end
	if not snapshot.self.alive or snapshot.environment.matchEnded then
		self.Adapter.Stop()
		return
	end
	local state = snapshot.self
	if self.Purchase and now - self.Purchase.started > config.PlanTimeout then
		self.Purchase = nil
		self.BuyUntil = now + config.FailureCooldown
	end
	if goal.action == 'Recover' then
		self.Adapter.Stop()
		if now < self.Brain.NextAction then return end
		self.RecoveryState = 'BUILD_RECOVERY_PLATFORM'
		local result = self.Navigation:FindClutch({Position = state.position, Velocity = state.velocity, Grounded = false}, {
			Mode = 'Legit', BlocksAvailable = state.blocks, Clutch = {Void = true, MaxBlocks = config.BuildLimit}
		})
		if result.Success and result.BridgePath[1] then
			self:Place(result.BridgePath[1].Grid, now, true)
		elseif not self.RecoveryReported then
			self.RecoveryReported = true
			self.Adapter.Log('FIND_SAFE_SURFACE', 'No physically valid clutch placement is available')
		end
		return
	end
	self.RecoveryReported = nil
	if goal.action == 'BuildCover' or goal.action == 'BuildUp' then
		self.Adapter.Stop()
		if not self.Build then self.Build = self.Adapter.Build(goal.action, self.Brain.Assessment, config.BuildLimit) end
		if not self.Build or not self.Build[1] then
			self:Fail('No useful legal building continuation', now)
			return
		end
		if self:Place(self.Build[1], now) == 'complete' then
			table.remove(self.Build, 1)
			if #self.Build == 0 then
				self.Build = nil
				self.Brain.Goal = nil
				self.Brain.NextAction = now + config.ReactionTime
				self.NextThink = 0
			end
		end
		return
	end
	if goal.action == 'Harass' then
		self.Adapter.Stop()
		if now >= self.NextAttack and self.Brain.Assessment.count == 0 and state.safeSurface and not state.nearVoid then
			self.NextAttack = now + config.RangedInterval
			self.Adapter.Ranged(goal.destination)
		end
		return
	end
	if goal.destination and not self:Navigate(goal, now) then
		if self.Brain.Assessment.chased and state.safeSurface and state.cover and self.Brain.Assessment.nearest > config.LethalRange and state.projectiles > 0 and now >= self.NextAttack then
			self.NextAttack = now + config.RangedInterval
			self.Adapter.Ranged(self.Brain.Assessment.target)
		end
		return
	end
	self.Adapter.Stop()
	if goal.action == 'Fight' then
		local assessment = self.Brain:Assess(now)
		if not goal.destination or not self.Adapter.Valid(goal.destination) or assessment.target and assessment.target.id ~= goal.destination.id
			or goal.name ~= 'SurvivalCombat' and goal.name ~= 'Finish' and goal.name ~= 'DefendBed' and (assessment.fightScore < config.FightThreshold or assessment.highGround or state.nearVoid or state.narrowBridge or self.Brain.Retreating) then
			self:Fail('Fight conditions changed; disengaging', now)
			return
		end
		if now >= self.NextAttack then
			self.NextAttack = now + config.AttackInterval
			self.Adapter.Attack(goal.destination)
		end
	elseif goal.action == 'Buy' then
		if self.Purchase then
			if self.Purchase.done then
				if self.Purchase.success then
					self.Brain.Goal, self.Purchase = nil, nil
					self.Brain.Recovery, self.NextThink = 0, 0
					self.BuyUntil = now + config.PlacementTimeout
				else
					self:Fail('Shop rejected purchase', now)
				end
			elseif now - self.Purchase.started > config.PlanTimeout then
				self:Fail('Purchase acknowledgement timed out', now)
			end
		elseif snapshot.purchase and now >= (self.BuyUntil or 0) and self.Brain.Assessment.count == 0 and not self.Brain.Retreating and state.inventorySpace ~= false then
			local pending = {started = now}
			self.Purchase = pending
			self.Adapter.Buy(goal.destination, snapshot.purchase, function(success)
				if self.Running and self.Purchase == pending then
					self.Purchase.done, self.Purchase.success = true, success
				end
			end)
		end
	elseif goal.action == 'BreakBed' then
		if now >= self.NextAttack and snapshot.canBreakBed and self.Brain.Assessment.count == 0 and not self.Brain.Retreating then
			self.NextAttack = now + config.AttackInterval
			self.Adapter.BreakBed(goal.destination)
		end
	elseif goal.action == 'Collect' then
		self.RecoveryState = 'REASSESS'
		local resource = goal.destination.resource
		local amount = (state.resources or {})[resource] or 0
		if self.Collected ~= amount then
			self.Collected = amount
			self.NextThink = 0
			self.Brain.Recovery = 0
		end
		if goal.destination.kind == 'drop' and now >= self.NextAttack then
			self.NextAttack = now + config.RangedInterval
			self.Adapter.Pickup(goal.destination)
		end
	elseif self.Brain.Assessment.target then
		self.Adapter.Look(self.Brain.Assessment.target.position)
	end
end

return controller
