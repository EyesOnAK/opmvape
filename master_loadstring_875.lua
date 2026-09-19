local adapter = {}

function adapter.new(context, config)
	local hooks = {}
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.RespectCanCollide = true
	local ownBed, base, lastCharacter
	local nextScan, destinations, beds = 0, {}, {}
	local nextShot = 0
	local movement, jumpUntil
	local offsets = {Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3)}

	function hooks.Surface(position)
		local height = context.Entity.character and context.Entity.character.HipHeight or 3
		local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -height - 2, 0), params)
		local sides = 0
		if hit and hit.Normal.Y > 0.65 then
			for _, v in offsets do
				local side = workspace:Raycast(position + v + Vector3.new(0, 1, 0), Vector3.new(0, -height - 2, 0), params)
				if side and side.Normal.Y > 0.65 and math.abs(side.Position.Y - hit.Position.Y) < 1 then sides += 1 end
			end
		end
		return {safe = hit ~= nil and hit.Normal.Y > 0.65, narrow = sides <= 2, nearVoid = sides < 2, hit = hit}
	end

	function hooks.Observe(now)
		local character = context.Player.Character
		local root = character and character:FindFirstChild('HumanoidRootPart')
		local humanoid = character and character:FindFirstChildOfClass('Humanoid')
		local inventory = context.Store.inventory.inventory
		local excluded = {}
		for _, v in context.Players:GetPlayers() do
			if v.Character then table.insert(excluded, v.Character) end
		end
		if context.PathModel then table.insert(excluded, context.PathModel) end
		params.FilterDescendantsInstances = excluded
		overlap.FilterDescendantsInstances = excluded
		local snapshot = {
			self = {
				alive = context.Entity.isAlive and root ~= nil and humanoid ~= nil and humanoid.Health > 0 and (character:GetAttribute('Health') or humanoid.Health) > 0,
				position = root and root.Position or Vector3.zero, velocity = root and root.AssemblyLinearVelocity or Vector3.zero,
				health = character and character:GetAttribute('Health') or humanoid and humanoid.Health,
				maxHealth = character and character:GetAttribute('MaxHealth') or humanoid and humanoid.MaxHealth,
				grounded = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air or false,
				speed = humanoid and humanoid.WalkSpeed or 16, hipHeight = context.Entity.character and context.Entity.character.HipHeight or 3,
				jumpVelocity = humanoid and (humanoid.UseJumpPower and humanoid.JumpPower or math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)) or 42.6,
				gravity = workspace.Gravity, placeInterval = 1 / (context.Bedwars.SharedConstants.BLOCK_PLACE_CPS or 12),
				resources = {}, blocks = 0, projectiles = 0, utilities = {}, armor = 0, swordDamage = 0, tools = {},
				hotbar = context.Store.inventory.hotbar, selectedItem = context.Store.hand.tool and context.Store.hand.tool.Name,
				inventoryCount = #inventory.items, reservedResources = {iron = config.IronReserve},
				blockReserve = config.BlockReserve, inventorySpace = context.InventorySpace and context.InventorySpace(),
				canBuildUp = false
			},
			environment = {ownBed = ownBed, matchEnded = context.Store.matchState == 2, matchTime = 0, bedThreat = false},
			enemies = {}, teammates = {}, destinations = {}, canBreakBed = context.BreakEnabled(),
			sources = {resources = 'inventory', blocks = 'inventory', armor = 'inventory', swordDamage = 'inventory', tools = 'inventory', safeSurface = 'raycast', nearVoid = 'raycast', narrowBridge = 'raycast', ownBed = 'event'},
			confidence = {inventorySpace = context.InventorySpace and 1 or 0}
		}
		local armor = {}
		for _, v in {inventory.items, inventory.armor} do
			for _, v2 in v or {} do
				local item = type(v2) == 'table' and v2.itemType or v2
				local meta = context.Bedwars.ItemMeta[item]
				if meta and meta.armor then armor[meta.armor.slot] = math.max(armor[meta.armor.slot] or 0, meta.armor.damageReductionMultiplier or 0) end
				if meta and meta.sword and (meta.sword.damage or 0) > snapshot.self.swordDamage then
					snapshot.self.swordDamage, snapshot.self.weapon = meta.sword.damage, item
					snapshot.self.attackRange = math.min(meta.sword.attackRange or 10, config.LethalRange) * 0.8
				end
			end
		end
		for _, v in armor do snapshot.self.armor += v end
		snapshot.self.armor = math.clamp(snapshot.self.armor, 0, 0.9)
		for _, v in inventory.items do
			snapshot.self.resources[v.itemType] = (snapshot.self.resources[v.itemType] or 0) + v.amount
			local meta = context.Bedwars.ItemMeta[v.itemType]
			if meta and meta.block and v.itemType:find('wool') then snapshot.self.blocks += v.amount end
			if meta and meta.breakBlock then snapshot.self.tools[v.itemType] = meta.breakBlock end
			if meta and not meta.block and not meta.sword then table.insert(snapshot.self.utilities, v.itemType) end
		end
		snapshot.self.projectiles = #context.Projectiles({'arrow', 'snowball'})
		if not snapshot.self.alive then return snapshot end
		if character ~= lastCharacter then
			lastCharacter, nextScan = character, 0
		end
		local surface = hooks.Surface(root.Position)
		snapshot.self.safeSurface, snapshot.self.nearVoid, snapshot.self.narrowBridge = surface.safe, surface.nearVoid, surface.narrow
		snapshot.self.airborne = not snapshot.self.grounded
		snapshot.self.falling = snapshot.self.airborne and root.AssemblyLinearVelocity.Y < -12 and not workspace:Raycast(root.Position, Vector3.new(0, -14, 0), params)
		local team = tostring(context.Player:GetAttribute('Team'))
		if now >= nextScan then
			nextScan, destinations, beds = now + 1, {}, {}
			local foundBed
			for _, v in context.Collection:GetTagged('bed') do
				local owner = tostring(v:GetAttribute('TeamId'))
				beds[owner] = {value = true, timestamp = now, confidence = 1, source = 'event'}
				if owner == team then
					foundBed, ownBed, base = v, true, v.Position
				elseif not v:GetAttribute(`Team{team}NoBreak`) then
					table.insert(destinations, {id = `bed:{owner}`, kind = 'enemybed', position = v.Position, target = v, owner = owner})
				end
			end
			if not foundBed and ownBed == true then ownBed = false end
			for _, v in context.Collection:GetTagged('Generator') do
				local id = v:GetAttribute('Id') or ''
				local owner = id:match('^(.-)_generator$')
				local resource = owner and 'iron' or id:match('^(diamond)_') or id:match('^(emerald)_')
				if owner == team then base = base or v.Position end
				if resource and (not owner or owner == team) then
					table.insert(destinations, {id = id, kind = 'generator', position = v.Position, target = v, resource = resource, owner = owner})
				end
			end
			for _, v in context.Collection:GetTagged('BedwarsItemShop') do
				local id = v:GetAttribute('Id') or ''
				if id:match('^(.-)_item_shop') == team then
					local merchant = v:FindFirstChild('desertMerchant')
					local part = merchant and merchant.PrimaryPart
					if part then table.insert(destinations, {id = id, kind = 'shop', position = part.Position + part.CFrame.LookVector * 7, target = v, shopId = id}) end
				end
			end
			for _, v in context.Collection:GetTagged('TeamUpgradeShopkeeper') do
				if base and (v.Position - base).Magnitude <= config.BedThreatRadius then
					table.insert(destinations, {id = `upgrade:{tostring(v.Position)}`, kind = 'upgrade', position = v.Position, target = v})
				end
			end
		end
		snapshot.environment.ownBed, snapshot.environment.beds, snapshot.environment.base = ownBed, beds, base
		if workspace.StreamingEnabled and ownBed == false then snapshot.environment.ownBed, snapshot.confidence.ownBed = nil, 0 end
		for _, v in destinations do table.insert(snapshot.destinations, v) end
		for _, v in context.Collection:GetTagged('ItemDrop') do
			if config.ResourceWeights[v.Name] and (v.Position - root.Position).Magnitude <= config.SupportRadius and not workspace:Raycast(root.Position, v.Position - root.Position, params) then
				table.insert(snapshot.destinations, {id = `drop:{tostring(v.Position)}`, kind = 'drop', position = v.Position, target = v, resource = v.Name})
			end
		end
		if base then
			table.insert(snapshot.destinations, {id = 'base', kind = 'base', position = base})
			snapshot.self.insideBase = (root.Position - base).Magnitude <= config.BaseRadius
		end
		for _, v in context.Players:GetPlayers() do
			if v == context.Player or not v.Team or v.Team.Name == 'Spectators' then continue end
			local other = v.Character
			local part = other and other:FindFirstChild('HumanoidRootPart')
			local enemy = tostring(v:GetAttribute('Team')) ~= team
			local visible = part and (part.Position - root.Position).Magnitude <= config.ThreatRadius and not workspace:Raycast(root.Position, part.Position - root.Position, params)
			local baseVisible = part and base and (part.Position - base).Magnitude <= config.BedThreatRadius and not workspace:Raycast(base + Vector3.new(0, 4, 0), part.Position - base - Vector3.new(0, 4, 0), params)
			visible = visible or baseVisible
			if enemy and not visible then
				table.insert(snapshot.enemies, {id = tostring(v.UserId), visible = false})
			elseif part and (other:GetAttribute('Health') or 0) > 0 then
				local entry = {
					id = tostring(v.UserId), kind = enemy and 'enemy' or 'teammate', position = part.Position,
					velocity = part.AssemblyLinearVelocity, health = other:GetAttribute('Health'),
					visible = visible, target = part, player = v, owner = tostring(v:GetAttribute('Team')),
					protected = other:FindFirstChildOfClass('ForceField') ~= nil
				}
				entry.threatensBed, entry.confidence = baseVisible, baseVisible and 0.75 or 1
				if visible and context.Store.inventories[v] then
					local damage, protection = context.Gear(context.Store.inventories[v])
					entry.damage, entry.armor, entry.projectiles = damage, 0, false
					for _, v2 in protection do entry.armor += v2 end
					entry.armor = math.clamp(entry.armor, 0, 0.9)
					for _, v2 in context.Store.inventories[v].items or {} do
						local meta = context.Bedwars.ItemMeta[v2.itemType]
						entry.projectiles = entry.projectiles or meta and meta.projectileSource ~= nil
					end
				end
				table.insert(enemy and snapshot.enemies or snapshot.teammates, entry)
				if enemy and base and (part.Position - base).Magnitude <= config.BedThreatRadius then snapshot.environment.bedThreat = true end
				if not enemy then table.insert(snapshot.destinations, entry) end
			end
		end
		for _, v in snapshot.teammates do
			for _, v2 in snapshot.enemies do
				if v2.position and (v2.position - v.position).Magnitude <= config.LethalRange then v.underPressure = true end
			end
		end
		snapshot.self.distanceToSafety = math.huge
		for _, v in snapshot.destinations do
			if v.kind ~= 'enemybed' then
				local distance, safe = (v.position - root.Position).Magnitude, true
				for _, v2 in snapshot.enemies do
					if v2.position and (v.position - v2.position).Magnitude <= config.RouteEnemyRadius then safe = false end
				end
				if safe and hooks.Surface(v.position).safe then snapshot.self.distanceToSafety = math.min(snapshot.self.distanceToSafety, distance) end
			end
		end
		snapshot.self.escapeAvailable = snapshot.self.distanceToSafety < math.huge
		snapshot.self.canBuildCover = surface.safe and snapshot.self.blocks > config.BlockReserve and not surface.nearVoid
		snapshot.self.cover = false
		local ranged, nearest = false, math.huge
		for _, v in snapshot.enemies do
			if v.position then
				nearest = math.min(nearest, (v.position - root.Position).Magnitude)
				ranged = ranged or v.projectiles
				snapshot.self.cover = snapshot.self.cover or workspace:Raycast(root.Position - Vector3.new(0, 2, 0), v.position - root.Position, params) ~= nil
			end
		end
		snapshot.self.underPressure = nearest <= config.LethalRange
		if surface.safe and not surface.nearVoid and not ranged and nearest > config.LethalRange * 0.5 and snapshot.self.blocks >= config.BlockReserve + 4 then
			for _, v in offsets do
				local upper = workspace:Raycast(root.Position + v * 2 + Vector3.new(0, 8, 0), Vector3.new(0, -8, 0), params)
				if upper and upper.Normal.Y > 0.65 and upper.Position.Y - surface.hit.Position.Y >= 3 and upper.Position.Y - surface.hit.Position.Y <= 6
					and not workspace:Raycast(upper.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, 6, 0), params) then
					local destination = upper.Position + Vector3.new(0, snapshot.self.hipHeight, 0)
					local safe = true
					for _, v2 in snapshot.enemies do
						if v2.position and (destination - v2.position).Magnitude <= config.LethalRange then safe = false end
					end
					if safe then
						snapshot.upperExit = {id = `upper:{tostring(upper.Position)}`, kind = 'surface', position = destination}
						snapshot.self.canBuildUp = true
						break
					end
				end
			end
		end
		local started = context.Bedwars.Store:getState().Game.startTime
		snapshot.environment.matchTime = started and started > 0 and math.max(0, workspace:GetServerTimeNow() - started) or 0
		local geared, missing = context.GearNeeded()
		local item = snapshot.self.blocks < config.TravelBlocks and 'wool_white' or not geared and missing
		if not item and context.Store.shopLoaded and snapshot.environment.matchTime >= config.EarlyTime and snapshot.self.armor < 0.9 then
			for _, v in {'diamond_chestplate', 'diamond_sword'} do
				local meta = context.Bedwars.ItemMeta[v]
				if meta and not context.Item(v) and (meta.sword and meta.sword.damage > snapshot.self.swordDamage or meta.armor and (armor[meta.armor.slot] or 0) < meta.armor.damageReductionMultiplier) then
					item = v
					break
				end
			end
		end
		if item and context.Store.shopLoaded then
			local purchase = context.Bedwars.Shop.getShopItem(item, context.Player)
			if purchase and not purchase.disabled and not purchase.lockedByForge and (not purchase.ignoredByKit or not table.find(purchase.ignoredByKit, context.Store.equippedKit)) then
				local upgrade = purchase.require and purchase.require.teamUpgrade
				local upgrades = context.Bedwars.Store:getState().Bedwars.teamUpgrades
				if not upgrade or (upgrades[upgrade.upgradeId] or -1) >= upgrade.lowestTierIndex then
					snapshot.purchase = {item = item, currency = purchase.currency, cost = purchase.price + (item == 'wool_white' and 0 or purchase.currency == 'iron' and config.IronReserve or 0), price = purchase.price, data = purchase}
					snapshot.self.plannedPurchase = snapshot.purchase
				end
			end
		end
		if context.Bedwars.TeamUpgradeMeta and snapshot.self.blocks >= config.TravelBlocks and (not snapshot.purchase or (snapshot.self.resources.diamond or 0) >= config.DiamondTarget) then
			local upgrades = context.Bedwars.Store:getState().Bedwars.teamUpgrades[context.Player:GetAttribute('Team')] or {}
			for _, v in {'ARMOR', 'DAMAGE'} do
				local meta = context.Bedwars.TeamUpgradeMeta[v]
				local tier = meta and meta.tiers[(upgrades[v] or 0) + 1]
				if tier and (not meta.disabledInQueue or not table.find(meta.disabledInQueue, context.Store.queueType)) and (not tier.availableOnlyInQueue or table.find(tier.availableOnlyInQueue, context.Store.queueType)) then
					snapshot.purchase = {item = v, upgrade = true, currency = 'diamond', cost = tier.cost, price = tier.cost, tier = (upgrades[v] or 0) + 1}
					break
				end
			end
		end
		return snapshot
	end

	function hooks.Valid(destination)
		if destination.target and not destination.target.Parent then return false end
		if destination.player then
			return destination.player.Character == destination.target.Parent and (destination.target.Parent:GetAttribute('Health') or 0) > 0
				and tostring(destination.player:GetAttribute('Team')) == destination.owner and not destination.target.Parent:FindFirstChildOfClass('ForceField')
		end
		return true
	end

	function hooks.Stop()
		movement, jumpUntil = nil, nil
		if context.Entity.isAlive then context.Entity.character.Humanoid:Move(Vector3.zero, false) end
	end

	function hooks.Move(position, jump, kind)
		movement = {position = position, jump = jump, kind = kind}
		if jump then jumpUntil = os.clock() + config.JumpCommitTime end
	end

	function hooks.Update()
		if not context.Entity.isAlive or not context.Entity.character.RootPart.Parent then return end
		local root = context.Entity.character.RootPart
		local direction = movement and (movement.position - root.Position) * Vector3.new(1, 0, 1) or Vector3.zero
		if direction.Magnitude > 0.1 then
			local jump = jumpUntil and os.clock() <= jumpUntil
			local step = direction.Unit * math.min(direction.Magnitude, 1)
			if not jump and (not hooks.Surface(root.Position + step).safe and movement.kind ~= 'Drop' or workspace:Blockcast(CFrame.new(root.Position), Vector3.new(1.8, 3.5, 1.8), step, params)) then
				direction = Vector3.zero
			end
		end
		context.Entity.character.Humanoid:Move(direction.Magnitude > 0.1 and direction.Unit or Vector3.zero, false)
		if movement and movement.jump then
			context.Entity.character.Humanoid.Jump = true
			movement.jump = false
		end
	end

	function hooks.Look(position)
		if not context.Entity.isAlive then return end
		local root = context.Entity.character.RootPart
		local direction = (position - root.Position) * Vector3.new(1, 0, 1)
		if direction.Magnitude > 0.1 then
			root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, root.Position + direction), 0.25)
		end
	end

	function hooks.ValidateMove(action, airborne)
		local root = context.Entity.character.RootPart
		local direction = action.Position - root.Position
		if direction.Magnitude < 0.1 then return true end
		local landing = hooks.Surface(action.Position)
		if not landing.safe then return false end
		local step = direction.Unit * math.min(direction.Magnitude, 2)
		if action.Type == 'Jump' then
			return airborne or context.Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air and not workspace:Blockcast(CFrame.new(root.Position), Vector3.new(1.8, 3.5, 1.8), Vector3.new(0, 4, 0), params)
		end
		if action.Type == 'Drop' then
			return root.Position.Y - action.Position.Y <= 12 and not workspace:Blockcast(CFrame.new(root.Position), Vector3.new(1.8, 3.5, 1.8), step, params)
		end
		return hooks.Surface(root.Position + step).safe and not workspace:Blockcast(CFrame.new(root.Position), Vector3.new(1.8, 3.5, 1.8), step, params)
	end

	function hooks.Block(grid)
		local block = context.PlacedBlock(grid * 3)
		return block ~= nil and workspace:Raycast(grid * 3 + Vector3.new(0, 2, 0), Vector3.new(0, -3, 0), params) ~= nil
	end

	function hooks.ValidatePlacement(placement, nextAction)
		if not context.Entity.isAlive or not context.CanPlace() then return false end
		local root = context.Entity.character.RootPart
		if (root.Position - placement.Position).Magnitude > 18 then return false end
		if #workspace:GetPartBoundsInBox(CFrame.new(placement.Position), Vector3.new(2.8, 2.8, 2.8), overlap) > 0 then return false end
		if nextAction and nextAction.Type ~= 'PlaceBlock' and math.abs(nextAction.Position.Y - placement.Position.Y) < 2 and ((nextAction.Position - placement.Position) * Vector3.new(1, 0, 1)).Magnitude < 2 then return false end
		return true
	end

	function hooks.Place(position)
		local wool = context.Wool()
		if wool then context.Bedwars.placeBlock(position, wool) end
	end

	function hooks.Build(kind, assessment, limit)
		local root = context.Entity.character.RootPart
		local direction = assessment.target and assessment.target.position - root.Position or root.CFrame.LookVector
		local grid = context.Navigation.WorldToGrid(root.Position - Vector3.new(0, context.Entity.character.HipHeight + 1.5, 0))
		local name = kind == 'BuildCover' and (assessment.highGround and assessment.ranged and 'Roof' or assessment.chased and 'RetreatBlocker' or 'Cover') or kind
		local pattern = context.Controller.Pattern(name, grid, name == 'RetreatBlocker' and -direction or direction)
		local result = {}
		for _, v in pattern or {} do
			if #result >= limit then break end
			if not hooks.Block(v) then table.insert(result, v) end
		end
		return result
	end

	function hooks.Attack(destination)
		if not hooks.Valid(destination) or not context.Entity.isAlive then return end
		local root = context.Entity.character.RootPart
		local sword = context.Store.tools.sword
		if not sword or not sword.tool or (root.Position - destination.target.Position).Magnitude > config.LethalRange then return end
		if workspace:Raycast(root.Position, destination.target.Position - root.Position, params) then return end
		local slot = context.Hotbar(sword.tool)
		if slot and context.Store.inventory.hotbarSlot ~= slot then
			context.Bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = slot})
			return
		end
		if context.Store.hand.tool ~= sword.tool or not context.CanSwing() then return end
		hooks.Look(destination.target.Position)
		context.Bedwars.SwordController:swingSwordAtMouse(0.39)
	end

	function hooks.Ranged(destination)
		if not destination or not hooks.Valid(destination) or not context.Entity.isAlive or os.clock() < nextShot then return end
		local root = context.Entity.character.RootPart
		if workspace:Raycast(root.Position, destination.target.Position - root.Position, params) then return end
		local target
		for _, v in context.Entity.List do
			if v.Player == destination.player then
				target = v
				break
			end
		end
		if not target then return end
		for _, v in context.Projectiles({'arrow', 'snowball'}) do
			local item, ammo, projectile, meta = unpack(v)
			local slot = context.Hotbar(item.tool)
			if slot and context.Store.inventory.hotbarSlot ~= slot then
				context.Bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = slot})
				return
			end
			if context.Store.hand.tool == item.tool then
				nextShot = os.clock() + math.max(meta.fireDelaySec or 0, config.RangedInterval)
				context.FireProjectile(item, ammo, projectile, target)
			end
			break
		end
	end

	function hooks.Pickup(destination)
		if hooks.Valid(destination) and context.Entity.isAlive and (context.Entity.character.RootPart.Position - destination.target.Position).Magnitude <= config.ArrivalRadius then
			context.Bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {itemDrop = destination.target})
		end
	end

	function hooks.Buy(destination, purchase, callback)
		if not hooks.Valid(destination) or not context.Entity.isAlive or (context.Entity.character.RootPart.Position - destination.position).Magnitude > config.ArrivalRadius then
			callback(false)
			return
		end
		local currency = context.Item(purchase.currency)
		if purchase.upgrade then
			local meta = context.Bedwars.TeamUpgradeMeta[purchase.item]
			local upgrades = context.Bedwars.Store:getState().Bedwars.teamUpgrades[context.Player:GetAttribute('Team')] or {}
			local tier = meta and meta.tiers[(upgrades[purchase.item] or 0) + 1]
			if currency and currency.amount >= purchase.cost and tier and tier.cost == purchase.price and (upgrades[purchase.item] or 0) + 1 == purchase.tier then
				context.Bedwars.Handler:Get('RequestPurchaseTeamUpgrade'):Fire('CallServerAsync', purchase.item):andThen(function(success)
					callback(success == true)
				end)
			else
				callback(false)
			end
			return
		end
		local current = context.Bedwars.Shop.getShopItem(purchase.item, context.Player)
		if not currency or currency.amount < purchase.cost or not current or current.price ~= purchase.price or current.disabled or current.lockedByForge then
			callback(false)
			return
		end
		local promise = context.Bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {shopItem = current, shopId = destination.shopId})
		promise:andThen(function(success)
			callback(success == true)
		end)
		if promise.catch then
			promise:catch(function()
				callback(false)
			end)
		end
	end

	function hooks.BreakBed(destination)
		if hooks.Valid(destination) and (destination.target:GetAttribute('BedShieldEndTime') or 0) <= workspace:GetServerTimeNow() then
			context.Bedwars.breakBlock(destination.target, true, true, nil, true)
		end
	end

	function hooks.Log(name, reason)
		if context.DebugEnabled() then warn(`[opmvape] brain {name} | {reason}`) end
	end

	return hooks
end

return adapter
