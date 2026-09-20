local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/EyesOnAK/opmvape/main/opmsix/'..select(1, path:gsub('opmsix/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local buildclock = os.clock()
local buildbudget = 0.004
local run = function(func)
	func()

	if os.clock() - buildclock > buildbudget then
		buildbudget = math.clamp(task.wait() * 0.75, 0.004, 0.02)
		buildclock = os.clock()
	end
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local proxService = cloneref(game:GetService('ProximityPromptService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local stats = cloneref(game:GetService('Stats'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontbounds = vape.Libraries.getfontbounds
local getvapeasset = vape.Libraries.getvapeasset
local uipallet = vape.Libraries.uipallet

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getvapeasset('opmsix/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function rakNetCheck(module)
	if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
		notif(module, 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		return false
	end

	return true
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('opmsix/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('opmsix/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('opmsix/libraries/entity.lua'), 'entitylibrary')()
local render = loadstring(downloadFile('opmsix/libraries/render.lua'), 'render')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	tagcallback = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.render = render
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for i in SpeedMethods do
	if not table.find(SpeedMethodList, i) then
		table.insert(SpeedMethodList, i)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Settings.Modules.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Settings.Modules.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(render.uninstall)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)



		end,
		Tooltip = 'Rejoins the server'
	})
end)

		Tooltip = 'Teleports into a unique server'
	})
	
	Sort = ServerHop:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
	ServerHop:CreateButton({
		Name = 'Rejoin Previous Server',
		Function = function()
			notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)
			if shared.vapeserverhopprevious then
				teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
			end
		end
	})
end)



				until module or not Freecam.Enabled
	
				if module and module.activeCameraController and Freecam.Enabled then
					old = module.activeCameraController.GetSubjectPosition
					local camPos = old(module.activeCameraController) or Vector3.zero
					module.activeCameraController.GetSubjectPosition = function()
						return camPos
					end
	
					Freecam:Clean(runService.PreSimulation:Connect(function(dt)
						if not inputService:GetFocusedTextBox() then
							if not controls then
								local loaded, result = pcall(function()
									return require(lplr.PlayerScripts:WaitForChild('PlayerModule', 5)):GetControls()
								end)
								controls = loaded and result or nil
							end
	
							local moved, vector = pcall(function()
								return controls:GetMoveVector()
							end)
							local moveVector = moved and vector or Vector3.zero
							local forward = (inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) + moveVector.Z
							local side = (inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) + moveVector.X
							local up = (inputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0) + touchUp
							dt = dt * (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
							camPos = (CFrame.lookAlong(camPos, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(side, up, forward) * (Value.Value * dt))).Position
						end
					end))
	
					if inputService.TouchEnabled then
						pcall(function()
							local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
							Freecam:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
								touchUp = jumpButton.ImageRectOffset.X == 146 and 1 or 0
							end))
						end)
					end
	
					contextService:BindActionAtPriority('FreecamKeyboard'..randomkey, function()
						return Enum.ContextActionResult.Sink
					end, false, Enum.ContextActionPriority.High.Value,
						Enum.KeyCode.W,
						Enum.KeyCode.A,
						Enum.KeyCode.S,
						Enum.KeyCode.D,
						Enum.KeyCode.E,
						Enum.KeyCode.Q,
						Enum.KeyCode.Up,
						Enum.KeyCode.Down
					)
				end
			else
				touchUp = 0
				pcall(function()
					contextService:UnbindAction('FreecamKeyboard'..randomkey)
				end)
				if module and old then
					module.activeCameraController.GetSubjectPosition = old
					module = nil
					old = nil
				end
			end
		end,
		Tooltip = 'Lets you fly and clip through walls freely\nwithout moving your player server-sided.'
	})
	
	Value = Freecam:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

					end))
				end
			else
				if old then
					workspace.Gravity = old
					old = nil
				end
			end
		end,
		Tooltip = 'Changes the rate you fall'
	})
	
	Mode = Gravity:CreateDropdown({
		Name = 'Mode',
		List = {'Workspace', 'Velocity', 'Impulse'},
		Tooltip = 'Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead'
	})
	Value = Gravity:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192,
		Function = function(val)
			if Gravity.Enabled and Mode.Value == 'Workspace' then
				changed = true
				workspace.Gravity = val
				changed = false
			end
		end,
		Default = 192
	})
end)

				end))
			end
		end,
		Tooltip = 'Automatically jumps after reaching the edge'
	})
end)



	
				old = module.moveFunction
				module.moveFunction = function(self, vec, face)
					if entitylib.isAlive then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						local root = entitylib.character.RootPart
						local movedir = root.Position + vec
						local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
						if not ray then
							local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
							if check then
								vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
							end
						end
					end
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
			end
		end,
		Tooltip = 'Prevents you from walking off the edge of parts'
	})
end)





run(function()
	local Atmosphere
	local Toggles = {}
	local newobjects, oldobjects = {}, {}
	local apidump = {
		Sky = {
			SkyboxUp = 'Text',
			SkyboxDn = 'Text',
			SkyboxLf = 'Text',
			SkyboxRt = 'Text',
			SkyboxFt = 'Text',
			SkyboxBk = 'Text',
			SunTextureId = 'Text',
			SunAngularSize = 'Number',
			MoonTextureId = 'Text',
			MoonAngularSize = 'Number',
			StarCount = 'Number'
		},
		Atmosphere = {
			Color = 'Color',
			Decay = 'Color',
			Density = 'Number',
			Offset = 'Number',
			Glare = 'Number',
			Haze = 'Number'
		},
		BloomEffect = {
			Intensity = 'Number',
			Size = 'Number',
			Threshold = 'Number'
		},
		DepthOfFieldEffect = {
			FarIntensity = 'Number',
			FocusDistance = 'Number',
			InFocusRadius = 'Number',
			NearIntensity = 'Number'
		},
		SunRaysEffect = {
			Intensity = 'Number',
			Spread = 'Number'
		},
		ColorCorrectionEffect = {
			TintColor = 'Color',
			Saturation = 'Number',
			Contrast = 'Number',
			Brightness = 'Number'
		}
	}
	
	local function removeObject(v)
		if not table.find(newobjects, v) then
			local toggle = Toggles[v.ClassName]
			if toggle and toggle.Toggle.Enabled then
				if v.Parent then
					table.insert(oldobjects, v)
					v.Parent = game
				end
			end
		end
	end
	
	Atmosphere = vape.Legit:CreateModule({
		Name = 'Atmosphere',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_atmosphere.png'),
		Function = function(callback)
			if callback then
				for _, v in lightingService:GetChildren() do
					removeObject(v)
				end
	
				Atmosphere:Clean(lightingService.ChildAdded:Connect(function(v)
					task.defer(removeObject, v)
				end))
	
				for i, v in Toggles do
					if v.Toggle.Enabled then
						local obj = Instance.new(i)
						for i2, v2 in v.Objects do
							if v2.Type == 'ColorSlider' then
								obj[i2] = Color3.fromHSV(v2.Hue, v2.Sat, v2.Value)
							else
								obj[i2] = apidump[i][i2] ~= 'Number' and v2.Value or tonumber(v2.Value) or 0
							end
						end
						obj.Parent = lightingService
						table.insert(newobjects, obj)
					end
				end
			else
				for _, v in newobjects do
					v:Destroy()
				end
	
				for _, v in oldobjects do
					v.Parent = lightingService
				end
	
				table.clear(newobjects)
				table.clear(oldobjects)
			end
		end,
		Tooltip = 'Custom lighting objects'
	})
	
	for i, v in apidump do
		Toggles[i] = {Objects = {}}
		Toggles[i].Toggle = Atmosphere:CreateToggle({
			Name = i,
			Function = function(callback)
				if Atmosphere.Enabled then
					Atmosphere:Toggle()
					Atmosphere:Toggle()
				end
	
				for _, v in Toggles[i].Objects do
					v.Object.Visible = callback
				end
			end
		})
	
		for i2, v2 in v do
			if v2 == 'Text' or v2 == 'Number' then
				Toggles[i].Objects[i2] = Atmosphere:CreateTextBox({
					Name = i2,
					Function = function(enter)
						if Atmosphere.Enabled and enter then
							Atmosphere:Toggle()
							Atmosphere:Toggle()
						end
					end,
					Darker = true,
					Default = v2 == 'Number' and '0' or nil,
					Visible = false
				})
			elseif v2 == 'Color' then
				Toggles[i].Objects[i2] = Atmosphere:CreateColorSlider({
					Name = i2,
					Function = function()
						if Atmosphere.Enabled then
							Atmosphere:Toggle()
							Atmosphere:Toggle()
						end
					end,
					Darker = true,
					Visible = false
				})
			end
		end
	end
end)

run(function()
	local Breadcrumbs
	local Texture
	local Lifetime
	local Thickness
	local FadeIn
	local FadeOut
	local trail, point, point2
	
	Breadcrumbs = vape.Legit:CreateModule({
		Name = 'Breadcrumbs',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_breadcrumbs.png'),
		Function = function(callback)
			if callback then
				point = Instance.new('Attachment')
				point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
				point2 = Instance.new('Attachment')
				point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
				trail = Instance.new('Trail')
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
				trail.TextureMode = Enum.TextureMode.Static
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
				trail.Lifetime = Lifetime.Value
				trail.Attachment0 = point
				trail.Attachment1 = point2
				trail.FaceCamera = true
	
				Breadcrumbs:Clean(trail)
				Breadcrumbs:Clean(point)
				Breadcrumbs:Clean(point2)
				Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					point.Parent = ent.HumanoidRootPart
					point2.Parent = ent.HumanoidRootPart
					trail.Parent = gameCamera
				end))
	
				if entitylib.isAlive then
					point.Parent = entitylib.character.RootPart
					point2.Parent = entitylib.character.RootPart
					trail.Parent = gameCamera
				end
			else
				trail = nil
				point = nil
				point2 = nil
			end
		end,
		Tooltip = 'Shows a trail behind your character'
	})
	
	Texture = Breadcrumbs:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'Texture Id',
		Function = function(enter)
			if enter and trail then
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
			end
		end
	})
	FadeIn = Breadcrumbs:CreateColorSlider({
		Name = 'Fade In',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(hue, sat, val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
			end
		end
	})
	FadeOut = Breadcrumbs:CreateColorSlider({
		Name = 'Fade Out',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
			end
		end
	})
	Lifetime = Breadcrumbs:CreateSlider({
		Name = 'Lifetime',
		Min = 1,
		Max = 5,
		Decimal = 10,
		Function = function(val)
			if trail then
				trail.Lifetime = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Default = 3
	})
	Thickness = Breadcrumbs:CreateSlider({
		Name = 'Thickness',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Function = function(val)
			if point then
				point.Position = Vector3.new(0, val - 2.7, 0)
			end
			if point2 then
				point2.Position = Vector3.new(0, -val - 2.7, 0)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Default = 0.1
	})
end)

run(function()
	local Cape
	local Texture
	local part, motor
	
	local function createMotor(char)
		if motor then
			motor:Destroy()
		end
	
		part.Parent = gameCamera
		motor = Instance.new('Motor6D')
		motor.MaxVelocity = 0.08
		motor.Part0 = part
		motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
		motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
		motor.Parent = part
	end
	
	Cape = vape.Legit:CreateModule({
		Name = 'Cape',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_cape.png'),
		Function = function(callback)
			if callback then
				part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 0.1)
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				part.Transparency = 0
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new()
				part.CastShadow = false
				part.Parent = gameCamera
				local capesurface = Instance.new('SurfaceGui')
				capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				capesurface.Adornee = part
				capesurface.Parent = part
	
				if Texture.Value:find('.webm') then
					local decal = Instance.new('VideoFrame')
					decal.Video = getvapeasset(Texture.Value)
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Looped = true
					decal.Parent = capesurface
					decal:Play()
				else
					local decal = Instance.new('ImageLabel')
					decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://14637958134'
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Parent = capesurface
				end
	
				Cape:Clean(part)
				Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
				if entitylib.isAlive then
					createMotor(entitylib.character)
				end
	
				repeat
					if motor and entitylib.isAlive then
						local velo = math.min(entitylib.character.RootPart.AssemblyLinearVelocity.Magnitude, 90)
						motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
					end
					capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
					part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
					task.wait()
				until not Cape.Enabled
			else
				part = nil
				motor = nil
			end
		end,
		Tooltip = 'Add\'s a cape to your character'
	})
	
	Texture = Cape:CreateTextBox({
		Name = 'Texture'
	})
end)

run(function()
	local ChinaHat
	local Material
	local Color
	local hat
	
	ChinaHat = vape.Legit:CreateModule({
		Name = 'China Hat',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_chinahat.png'),
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
	
				hat = Instance.new('MeshPart')
				hat.Size = Vector3.new(3, 0.7, 3)
				hat.Name = 'ChinaHat'
				hat.Material = Enum.Material[Material.Value]
				hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				hat.CanCollide = false
				hat.CanQuery = false
				hat.Massless = true
				hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
				hat.Transparency = 1 - Color.Opacity
				hat.Parent = gameCamera
				hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
				weld.Parent = hat
	
				ChinaHat:Clean(hat)
				ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					if weld then
						weld:Destroy()
					end
					hat.Parent = gameCamera
					hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
					hat.AssemblyLinearVelocity = Vector3.zero
					weld = Instance.new('WeldConstraint')
					weld.Part0 = hat
					weld.Part1 = char.Head
					weld.Parent = hat
				end))
	
				repeat
					hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
					task.wait()
				until not ChinaHat.Enabled
			else
				hat = nil
			end
		end,
		Tooltip = 'Puts a china hat on your character (ty mastadawn)'
	})
	
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = ChinaHat:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if hat then
				hat.Material = Enum.Material[val]
			end
		end
	})
	Color = ChinaHat:CreateColorSlider({
		Name = 'Hat Color',
		DefaultOpacity = 0.7,
		Function = function(hue, sat, val, opacity)
			if hat then
				hat.Color = Color3.fromHSV(hue, sat, val)
				hat.Transparency = 1 - opacity
			end
		end
	})
end)

run(function()
	local Clock
	local ClockType
	local ShowDate
	local TwentyFourHour
	local Background
	local BackgroundColor
	local shadows = {}
	local skippedticks = {[8] = true, [9] = true, [10] = true, [14] = true, [15] = true, [16] = true, [20] = true, [21] = true, [22] = true}
	local localtime, utctime = os.date('*t'), os.date('!*t')
	local timezone = ((localtime.yday - utctime.yday) * 24) + localtime.hour - utctime.hour
	timezone = timezone > 12 and timezone - 24 or (timezone < -12 and timezone + 24 or timezone)
	local americandate = timezone <= -2 and timezone >= -11
	local holder, analog, digital, hand
	local analoghour, analogminute, analogweekday, analogdate, analogmeridiem
	local digitalhour, digitalminute, digitalmeridiem, digitaldate, digitalweekday
	
	local function addLabel(parent, textsize, alignment)
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontDisplay
		label.Size = UDim2.fromOffset(200, textsize + 6)
		label.Text = ''
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = textsize
		label.TextXAlignment = alignment
		label.Parent = parent
		local shadow = label:Clone()
		shadow.Name = 'Shadow'
		shadow.TextColor3 = Color3.new()
		shadow.TextTransparency = 0.498
		shadow.Visible = false
		shadow.ZIndex = 0
		shadow.Parent = parent
		shadows[label] = shadow
	
		return label
	end
	
	local function placeLabel(label, x, centery)
		label.Position = UDim2.fromOffset(label.TextXAlignment == Enum.TextXAlignment.Right and x - 200 or x, centery - (label.Size.Y.Offset / 2))
		shadows[label].Position = label.Position + UDim2.fromOffset(1, 1)
	end
	
	local function refreshSize()
		if ClockType.Value == 'Digital' then
			holder.Size = UDim2.fromOffset(140 + (ShowDate.Enabled and 48 or 0) + (TwentyFourHour.Enabled and 0 or 24), 64)
			return
		end
	
		holder.Size = UDim2.fromOffset(140, 130)
	end
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local now = os.date('*t')
		local hour = TwentyFourHour.Enabled and now.hour or (now.hour > 12 and now.hour - 12 or (now.hour == 0 and 12 or now.hour))
		local hourtext = string.format('%02d', hour)
		local minutetext = string.format('%02d', now.min)
		local meridiem = now.hour >= 12 and 'pm' or 'am'
		local weekday = os.date('%a'):lower()
		local datetext = string.format(ClockType.Value == 'Digital' and '%02d / %02d' or '%02d/%02d', americandate and now.month or now.day, americandate and now.day or now.month)
	
		if ClockType.Value == 'Digital' then
			digitalhour.Text = hourtext
			digitalminute.Text = minutetext
			digitalmeridiem.Text = meridiem
			digitaldate.Text = datetext
			digitalweekday.Text = weekday
			shadows[digitalhour].Text = hourtext
			shadows[digitalminute].Text = minutetext
			shadows[digitalmeridiem].Text = meridiem
			shadows[digitaldate].Text = datetext
			shadows[digitalweekday].Text = weekday
			placeLabel(digitalmeridiem, 78 + getfontbounds(minutetext, 48 * uipallet.DisplayScale, uipallet.FontDisplay).X, 46)
			placeLabel(digitaldate, holder.Size.X.Offset - 12, 24)
			placeLabel(digitalweekday, holder.Size.X.Offset - 12, 40)
	
			return
		end
	
		analoghour.Text = hourtext
		analogminute.Text = minutetext
		analogweekday.Text = weekday
		analogdate.Text = datetext
		analogmeridiem.Text = meridiem
		shadows[analoghour].Text = hourtext
		shadows[analogminute].Text = minutetext
		shadows[analogweekday].Text = weekday
		shadows[analogdate].Text = datetext
		shadows[analogmeridiem].Text = meridiem
		hand.Rotation = (hour * 30) + (now.min / 2)
	end
	
	Clock = vape.Legit:CreateModule({
		Name = 'Clock',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_clock.png'),
		Function = function(callback)
			if callback then
				repeat
					update()
					task.wait(1)
				until not Clock.Enabled
			end
		end,
		Size = UDim2.fromOffset(140, 130),
		Tooltip = 'Draws a clock with the current real-world time'
	})
	
	ClockType = Clock:CreateDropdown({
		Name = 'Clock Type',
		List = {'Analog', 'Digital'},
		Function = function(value)
			if holder then
				analog.Visible = value == 'Analog'
				digital.Visible = value == 'Digital'
				ShowDate.Object.Visible = value == 'Digital'
				refreshSize()
				update()
			end
		end
	})
	ShowDate = Clock:CreateToggle({
		Name = 'Show date',
		Function = function(callback)
			if holder then
				digitaldate.Visible = callback
				digitalweekday.Visible = callback
				shadows[digitaldate].Visible = callback and not Background.Enabled
				shadows[digitalweekday].Visible = callback and not Background.Enabled
				refreshSize()
			end
		end,
		Default = true
	})
	TwentyFourHour = Clock:CreateToggle({
		Name = '24 Hour Time',
		Function = function(callback)
			if holder then
				analogmeridiem.Visible = not callback
				digitalmeridiem.Visible = not callback
				shadows[analogmeridiem].Visible = not callback and not Background.Enabled
				shadows[digitalmeridiem].Visible = not callback and not Background.Enabled
				refreshSize()
				update()
			end
		end
	})
	Background = Clock:CreateToggle({
		Name = 'Render background',
		Function = function(callback)
			if BackgroundColor then
				holder.BackgroundTransparency = callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = callback
	
				for i, v in shadows do
					v.Visible = not callback and i.Visible
				end
			end
		end,
		Default = true
	})
	BackgroundColor = Clock:CreateColorSlider({
		Name = 'Background Color',
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = Background.Enabled and 1 - opacity or 1
			end
		end,
		Darker = true
	})
	holder = Clock.Children
	holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	holder.BackgroundTransparency = 0.6
	local holdercorner = Instance.new('UICorner')
	holdercorner.CornerRadius = UDim.new(0, 4)
	holdercorner.Parent = holder
	analog = Instance.new('Frame')
	analog.BackgroundTransparency = 1
	analog.Name = 'Analog'
	analog.Size = UDim2.fromScale(1, 1)
	analog.Parent = holder
	digital = Instance.new('Frame')
	digital.BackgroundTransparency = 1
	digital.Name = 'Digital'
	digital.Size = UDim2.fromScale(1, 1)
	digital.Visible = false
	digital.Parent = holder
	for i = 0, 23 do
		if not skippedticks[i] then
			local angle = math.rad(i * 15) - (math.pi / 2)
			local x = math.cos(angle) * 50 + 68.5
			local y = math.sin(angle) * 50 + 65.5
			local tick = Instance.new('Frame')
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.BackgroundColor3 = Color3.new(1, 1, 1)
			tick.BorderSizePixel = 0
			tick.Position = UDim2.fromOffset(x, y)
			tick.Size = UDim2.fromOffset(3, 3)
			tick.Parent = analog
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = tick
		end
	end
	hand = Instance.new('Frame')
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.BackgroundColor3 = Color3.fromRGB(6, 161, 126)
	hand.BorderSizePixel = 0
	hand.Name = 'Hand'
	hand.Position = UDim2.fromOffset(70, 65)
	hand.Size = UDim2.fromOffset(4, 52)
	hand.Parent = analog
	analoghour = addLabel(analog, 44 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	analogminute = addLabel(analog, 44 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	analogweekday = addLabel(analog, 13 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	analogdate = addLabel(analog, 13 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	analogmeridiem = addLabel(analog, 13 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	digitalhour = addLabel(digital, 48 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	digitalminute = addLabel(digital, 48 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	digitalmeridiem = addLabel(digital, 16 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	digitaldate = addLabel(digital, 16 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	digitalweekday = addLabel(digital, 16 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	local colon = Instance.new('Frame')
	colon.AnchorPoint = Vector2.new(0.5, 0.5)
	colon.BackgroundColor3 = Color3.new(1, 1, 1)
	colon.BorderSizePixel = 0
	colon.Name = 'Colon'
	colon.Position = UDim2.fromOffset(70, 32)
	colon.Size = UDim2.fromOffset(4, 4)
	colon.Parent = digital
	local coloncorner = Instance.new('UICorner')
	coloncorner.CornerRadius = UDim.new(1, 0)
	coloncorner.Parent = colon
	placeLabel(analoghour, 56, 37.5)
	placeLabel(analogminute, 130, 88.7)
	placeLabel(analogweekday, 20, 90.5)
	placeLabel(analogdate, 20, 106.5)
	placeLabel(analogmeridiem, 130, 18.1)
	placeLabel(digitalhour, 60, 34)
	placeLabel(digitalminute, 78, 34)
	ShowDate.Object.Visible = ClockType.Value == 'Digital'
	update()
end)

run(function()
	local Compass
	local Background
	local BackgroundColor
	local slots = {}
	local last = {}
	local cardinals = {[0] = 'N', [45] = 'NE', [90] = 'E', [135] = 'SE', [180] = 'S', [225] = 'SW', [270] = 'W', [315] = 'NW'}
	local tickstep = (616 + 8) / 1400
	local degreestep = tickstep * 10
	local stripcentre = tickstep + 70 * degreestep
	local majorsize = UDim2.fromOffset(2, 12)
	local majorposition = UDim2.fromOffset(0, 32)
	local minorsize = UDim2.fromOffset(2, 4)
	local minorposition = UDim2.fromOffset(0, 36)
	local platecolor = Color3.fromRGB(230, 230, 230)
	local mutedcolor = Color3.fromRGB(163, 163, 163)
	local whitecolor = Color3.new(1, 1, 1)
	local holder, strip, headinglabel
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local look = gameCamera.CFrame.LookVector
		local heading = math.deg(math.atan2(look.X, -look.Z)) % 360
		local plain = not Background.Enabled
		local index = 0
		local degrees = math.floor(heading)
		if degrees ~= last.degrees then
			last.degrees = degrees
			headinglabel.Text = tostring(degrees)
		end
	
		for value = math.ceil((heading - 70) / 5) * 5, heading + 70, 5 do
			index += 1
			local slot = slots[index]
			local normalized = value % 360
			local major = normalized % 45 == 0
			slot.Object.Position = UDim2.fromOffset(tickstep + (value - heading + 70) * degreestep, 0)
			slot.Object.Visible = true
			slot.Bar.Position = major and majorposition or minorposition
			slot.Bar.Size = major and majorsize or minorsize
			slot.Bar.BackgroundTransparency = major and 0.6 or 0.624
			slot.Label.Visible = major or normalized % 15 == 0
	
			if slot.Label.Visible and (slot.Value ~= normalized or plain ~= last.plain) then
				slot.Value = normalized
				slot.Label.Text = major and cardinals[normalized] or tostring(math.floor(normalized))
				slot.Label.FontFace = (major or plain) and uipallet.FontBold or uipallet.Font
				slot.Label.TextColor3 = plain and platecolor or (major and whitecolor or mutedcolor)
			end
		end
	
		last.plain = plain
	
		for i2, v2 in slots do
			if i2 > index then
				v2.Object.Visible = false
			end
		end
	end
	
	Compass = vape.Legit:CreateModule({
		Name = 'Compass',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_compass.png'),
		Function = function(callback)
			if callback then
				Compass:Clean(runService.RenderStepped:Connect(update))
			end
		end,
		Size = UDim2.fromOffset(616, 60),
		Tooltip = 'Shows a compass indicating your direction'
	})
	
	Background = Compass:CreateToggle({
		Name = 'Render background',
		Function = function(callback)
			if BackgroundColor then
				holder.BackgroundTransparency = callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = callback
			end
		end,
		Default = true
	})
	BackgroundColor = Compass:CreateColorSlider({
		Name = 'Background Color',
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = Background.Enabled and 1 - opacity or 1
			end
		end,
		Darker = true
	})
	holder = Compass.Children
	holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	holder.BackgroundTransparency = 0.6
	local holdercorner = Instance.new('UICorner')
	holdercorner.CornerRadius = UDim.new(0, 4)
	holdercorner.Parent = holder
	strip = Instance.new('Frame')
	strip.BackgroundTransparency = 1
	strip.ClipsDescendants = true
	strip.Name = 'Strip'
	strip.Position = UDim2.fromOffset(0, -20)
	strip.Size = UDim2.fromOffset(616, 80)
	strip.Parent = holder
	headinglabel = Instance.new('TextLabel')
	headinglabel.AnchorPoint = Vector2.new(0.5, 0)
	headinglabel.BackgroundTransparency = 1
	headinglabel.FontFace = uipallet.FontBold
	headinglabel.Position = UDim2.fromOffset(stripcentre, 0)
	headinglabel.Size = UDim2.fromOffset(200, 16)
	headinglabel.TextColor3 = platecolor
	headinglabel.TextSize = 12
	headinglabel.Parent = strip
	local arrow = Instance.new('ImageLabel')
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.BackgroundTransparency = 1
	arrow.Image = getvapeasset('opmsix/assets/new/compassarrow.png')
	arrow.Position = UDim2.fromOffset(stripcentre, 15)
	arrow.Size = UDim2.fromOffset(19, 32)
	arrow.Parent = strip
	for index = 1, 29 do
		local slot = Instance.new('Frame')
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.new()
		slot.Visible = false
		slot.Parent = strip
		local bar = Instance.new('Frame')
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.BackgroundColor3 = whitecolor
		bar.BorderSizePixel = 0
		bar.Position = majorposition
		bar.Size = majorsize
		bar.Parent = slot
		local label = Instance.new('TextLabel')
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontBold
		label.Position = UDim2.fromOffset(0, 43)
		label.Size = UDim2.fromOffset(60, 20)
		label.TextColor3 = whitecolor
		label.TextSize = 11
		label.Parent = slot
		slots[index] = {Object = slot, Bar = bar, Label = label}
	end
end)

run(function()
	local Coords
	local DisplayType
	local Background
	local BackgroundColor
	local horizontalAxes = {}
	local verticalAxes = {}
	local coords = {}
	local positives = {}
	local last = {}
	local positivecolor = Color3.fromRGB(5, 134, 105)
	local negativecolor = Color3.fromRGB(250, 50, 56)
	local trianglearrow = getvapeasset('opmsix/assets/new/triangle.png')
	local digitWidth = getfontbounds('0', 19, uipallet.Font).X
	local holder, horizontal, vertical
	local horizontalmaterial, verticalmaterial
	
	local function addLabel(parent, textsize, textcolor)
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.Font
		label.Size = UDim2.fromOffset(200, 20)
		label.TextColor3 = textcolor
		label.TextSize = textsize
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = parent
	
		return label
	end
	
	local function addArrow(parent)
		local box = Instance.new('Frame')
		box.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
		box.BackgroundTransparency = 0.431
		box.Size = UDim2.fromOffset(16, 16)
		box.Parent = parent
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = box
		local triangle = Instance.new('ImageLabel')
		triangle.BackgroundTransparency = 1
		triangle.Image = trianglearrow
		triangle.Size = UDim2.fromOffset(8, 4)
		triangle.Parent = box
	
		return box, triangle
	end
	
	local function addDivider(parent, size)
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.8
		divider.BorderSizePixel = 0
		divider.Size = size
		divider.Parent = parent
	
		return divider
	end
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		if not entitylib.isAlive then return end
	
		local pos = entitylib.character.RootPart.Position
		local look = gameCamera.CFrame.LookVector
		local material = entitylib.character.Humanoid.FloorMaterial.Name
		local x, y, z = math.round(pos.X), math.round(pos.Y), math.round(pos.Z)
		local positivex, positivez = look.X > 0, look.Z > 0
		if last.x == x and last.y == y and last.z == z and last.positivex == positivex and last.positivez == positivez and last.material == material and last.display == DisplayType.Value then return end
	
		last.x, last.y, last.z, last.positivex, last.positivez, last.material, last.display = x, y, z, positivex, positivez, material, DisplayType.Value
		coords[1] = tostring(x)
		coords[2] = tostring(y)
		coords[3] = tostring(z)
		positives[1] = positivex
		positives[3] = positivez
	
		if DisplayType.Value == 'Vertical' then
			for i, v in verticalAxes do
				v.Value.Text = coords[i]
	
				if v.Triangle then
					v.Triangle.ImageColor3 = positives[i] and positivecolor or negativecolor
					v.Triangle.Position = UDim2.fromOffset(4, positives[i] and 5 or 6)
					v.Triangle.Rotation = positives[i] and 180 or 0
				end
			end
	
			verticalmaterial.Text = material
			return
		end
	
		local offset = 20
	
		for i, v in horizontalAxes do
			v.Label.Position = UDim2.fromOffset(offset, 16)
			offset += v.Width + 5
			v.Value.Text = coords[i]
			v.Value.Position = UDim2.fromOffset(offset, 13)
			offset += math.max(44, 10 + digitWidth * #coords[i])
	
			if v.Triangle then
				v.Arrow.Position = UDim2.fromOffset(offset - 8, 18)
				v.Triangle.ImageColor3 = positives[i] and positivecolor or negativecolor
				v.Triangle.Position = UDim2.fromOffset(4, positives[i] and 5 or 6)
				v.Triangle.Rotation = positives[i] and 180 or 0
			end
	
			if v.Divider then
				offset += v.Triangle and 20 or 0
				v.Divider.Position = UDim2.fromOffset(offset - 1, 18)
				offset += 20
			end
		end
	
		horizontalmaterial.Text = material
		holder.Size = UDim2.fromOffset(offset + 24, 70)
	end
	
	Coords = vape.Legit:CreateModule({
		Name = 'Coords',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_coords.png'),
		Function = function(callback)
			if callback then
				Coords:Clean(runService.RenderStepped:Connect(update))
			end
		end,
		Size = UDim2.fromOffset(280, 70),
		Tooltip = 'Shows your current XYZ coordinates'
	})
	
	DisplayType = Coords:CreateDropdown({
		Name = 'Display Type',
		List = {'Horizontal', 'Vertical'},
		Function = function(value)
			if holder then
				horizontal.Visible = value == 'Horizontal'
				vertical.Visible = value == 'Vertical'
				holder.Size = UDim2.fromOffset(value == 'Vertical' and 140 or 280, value == 'Vertical' and 180 or 70)
			end
		end
	})
	Background = Coords:CreateToggle({
		Name = 'Render background',
		Function = function(callback)
			if BackgroundColor then
				holder.BackgroundTransparency = callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = callback
			end
		end,
		Default = true
	})
	BackgroundColor = Coords:CreateColorSlider({
		Name = 'Background Color',
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = Background.Enabled and 1 - opacity or 1
			end
		end,
		Darker = true
	})
	holder = Coords.Children
	holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	holder.BackgroundTransparency = 0.6
	local holdercorner = Instance.new('UICorner')
	holdercorner.CornerRadius = UDim.new(0, 4)
	holdercorner.Parent = holder
	horizontal = Instance.new('Frame')
	horizontal.BackgroundTransparency = 1
	horizontal.Name = 'Horizontal'
	horizontal.Size = UDim2.fromScale(1, 1)
	horizontal.Parent = holder
	vertical = Instance.new('Frame')
	vertical.BackgroundTransparency = 1
	vertical.Name = 'Vertical'
	vertical.Size = UDim2.fromScale(1, 1)
	vertical.Visible = false
	vertical.Parent = holder
	for i2, v2 in {'X', 'Y', 'Z'} do
		local v = {Width = getfontbounds(v2, 12, uipallet.Font).X}
		v.Label = addLabel(horizontal, 12, Color3.new(1, 1, 1))
		v.Label.Text = v2
		v.Value = addLabel(horizontal, 19, Color3.new(1, 1, 1))
	
		if v2 ~= 'Y' then
			v.Arrow, v.Triangle = addArrow(horizontal)
		end
	
		if v2 ~= 'Z' then
			v.Divider = addDivider(horizontal, UDim2.fromOffset(2, 16))
		end
	
		horizontalAxes[i2] = v
	end
	for i2, v2 in {'X', 'Y', 'Z'} do
		local v = {}
		v.Label = addLabel(vertical, 11, Color3.new(1, 1, 1))
		v.Label.Text = v2
		v.Label.Position = UDim2.fromOffset(16, 16 + (i2 - 1) * 45)
		v.Value = addLabel(vertical, 17, Color3.new(1, 1, 1))
		v.Value.Position = UDim2.fromOffset(21 + getfontbounds(v2, 11, uipallet.Font).X, 13 + (i2 - 1) * 45)
	
		if v2 ~= 'Y' then
			v.Arrow, v.Triangle = addArrow(vertical)
			v.Arrow.Position = UDim2.fromOffset(108, v2 == 'X' and 18 or 105)
		end
	
		verticalAxes[i2] = v
	end
	for i = 1, 3 do
		local divider = addDivider(vertical, UDim2.fromOffset(110, 2))
		divider.Position = UDim2.fromOffset(16, 2 + i * 45)
	end
	local horizontallabel = addLabel(horizontal, 12, Color3.new(1, 1, 1))
	horizontallabel.Text = 'MATERIAL:'
	horizontallabel.Position = UDim2.fromOffset(20, 41)
	horizontalmaterial = addLabel(horizontal, 12, Color3.fromRGB(255, 160, 84))
	horizontalmaterial.Position = UDim2.fromOffset(20 + getfontbounds('MATERIAL: ', 12, uipallet.Font).X, 41)
	local verticallabel = addLabel(vertical, 11, Color3.new(1, 1, 1))
	verticallabel.Text = 'MATERIAL:'
	verticallabel.Position = UDim2.fromOffset(16, 146)
	verticalmaterial = addLabel(vertical, 11, Color3.fromRGB(255, 160, 84))
	verticalmaterial.Position = UDim2.fromOffset(24 + getfontbounds('MATERIAL:', 11, uipallet.Font).X, 146)
end)

run(function()
	local Disguise
	local Mode
	local IDBox
	local cloned = {}
	
	local function itemAdded(obj, manual)
		if (obj:IsA('Accessory') or obj:IsA('ShirtGraphic') or obj:IsA('Shirt') or obj:IsA('Pants') or obj:IsA('BodyColors') or manual) and not cloned[obj] then
			obj:ClearAllChildren()
			task.defer(obj.Destroy, obj)
		end
	end
	
	local function localAdded(char)
		table.clear(cloned)
		if Mode.Value == 'Character' then
			local success, description = pcall(function()
				return playersService:GetHumanoidDescriptionFromUserId(IDBox.Value == '' and 239702688 or tonumber(IDBox.Value))
			end)
	
			if success and Disguise.Enabled then
				char.Character.Archivable = true
				local clone = char.Character:Clone()
				clone.Parent = game
	
				local original = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
					HeightScale = 1,
					SetEmotes = function() end,
					SetEquippedEmotes = function() end
				}
	
				original.JumpAnimation = description.JumpAnimation
				description.HeightScale = original.HeightScale
				clone:FindFirstChildWhichIsA('Humanoid'):ApplyDescriptionResetAsync(description)
	
				Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))
				for _, v in char.Character:GetChildren() do
					itemAdded(v)
				end
	
				for _, v in clone:GetChildren() do
					cloned[v] = true
					if v:IsA('Accessory') then
						for _, v in v:GetDescendants() do
							if v:IsA('Weld') and v.Part1 then
								v.Part1 = char.Character:FindFirstChild(v.Part1.Name)
							elseif v:IsA('RigidConstraint') then
								v.Attachment1 = char.Character:FindFirstChild(v.Attachment1.Name, true)
							end
						end
	
						v.Parent = char.Character
					elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
						v.Parent = char.Character
					elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
						char.Head.MeshId = v.MeshId
					end
				end
	
				local face = char.Character:FindFirstChild('face', true)
				local cface = clone:FindFirstChild('face', true)
	
				if face then
					itemAdded(face, true)
				end
	
				if cface then
					cface.Parent = char.Head
				end
	
				original:SetEmotes(description:GetEmotes())
				original:SetEquippedEmotes(description:GetEquippedEmotes())
				description:Destroy()
				clone:ClearAllChildren()
				clone:Destroy()
			elseif description then
				description:Destroy()
			end
		else
			local success, data = pcall(function()
				data = marketplaceService:GetProductInfo(IDBox.Value == '' and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
			end)
	
			if success and Disguise.Enabled then
				if data.BundleType == 'AvatarAnimations' then
					local animate = char.Character:FindFirstChild('Animate')
					if not animate then return end
	
					for _, v in desc.Items do
						local itemtype = v.Name:split(' ')[2]:lower()
						if itemtype ~= 'animation' then
							local suc, obj = pcall(function()
								return game:GetObjects('rbxassetid://'..item.Id)
							end)
	
							if suc then
								animate[itemtype]:FindFirstChildWhichIsA('Animation').AnimationId = obj[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
							end
						end
					end
				else
					notif('Disguise', 'that\'s not an animation pack', 5, 'warning')
				end
			elseif type(data) == 'table' then
				table.clear(data)
			end
		end
	end
	
	Disguise = vape.Legit:CreateModule({
		Name = 'Disguise',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_disguise.png'),
		Function = function(callback)
			if callback then
				Disguise:Clean(entitylib.Events.LocalAdded:Connect(localAdded))
				if entitylib.isAlive then
					task.spawn(localAdded, entitylib.character)
				end
			else
				table.clear(cloned)
			end
		end,
		Tooltip = 'Changes your character or animation to a specific ID (animation packs or userid\'s only)'
	})
	
	Mode = Disguise:CreateDropdown({
		Name = 'Mode',
		List = {'Character', 'Animation'},
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
	IDBox = Disguise:CreateTextBox({
		Name = 'Disguise',
		Placeholder = 'Disguise User Id',
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
end)

run(function()
	local FFlag
	local Flags
	local List
	local prefixes = {'DFFlag', 'DFInt', 'DFLog', 'DFString', 'SFFlag', 'FFlag', 'FInt', 'FLog', 'FString'}
	local marker = 'CVFF1:'
	
	local function unpackFlags(text)
		local size, body = text:match('^'..marker..'(%d+):(.+)$')
		if not size then return text end
	
		local suc, plain = pcall(function()
			return lz4decompress(base64decode(body), tonumber(size))
		end)
		return suc and plain or text
	end
	
	local function apply()
		if not FFlag.Enabled then return end
	
		local applied = 0
		for _, v in List.ListEnabled do
			local name, value = v:match('^%s*(.-)%s*=%s*(.-)%s*$')
			for _, v in prefixes do
				if name and name:sub(1, #v) == v then
					name = name:sub(#v + 1)
					break
				end
			end
	
			if name and name ~= '' and value ~= '' and pcall(setfflag, name, value) then
				applied += 1
			end
		end
	
		if applied > 0 then
			notif('Vape', `Applied {applied} fflag{applied == 1 and '' or 's'}, join a new game for them to take effect`, 12, 'info')
		end
	end
	
	local function ingest(text, source)
		text = unpackFlags(text)
		local suc, json = pcall(function()
			return httpService:JSONDecode(text)
		end)
	
		if not suc or typeof(json) ~= 'table' then
			notif('Vape', `{source} is not valid fflag json`, 12, 'warning')
			return
		end
	
		local added, dropped = 0, 0
		for i, v in json do
			local entry
			for _, v2 in prefixes do
				if typeof(i) == 'string' and #i > #v2 and i:sub(1, #v2) == v2 and (typeof(v) == 'string' or typeof(v) == 'number' or typeof(v) == 'boolean') then
					entry = `{i}={tostring(v)}`
					break
				end
			end
	
			if entry and not table.find(List.List, entry) then
				table.insert(List.List, entry)
				table.insert(List.ListEnabled, entry)
				added += 1
			elseif not entry then
				dropped += 1
			end
		end
	
		List:ChangeValue()
		notif('Vape', `Took {added} fflag{added == 1 and '' or 's'} from {source}{dropped > 0 and `, dropped {dropped} it did not recognise` or ''}`, 12, added > 0 and 'info' or 'warning')
	end
	
	FFlag = vape.Legit:CreateModule({
		Name = 'FFlagEditor',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_fflageditor.png'),
		Function = function(callback)
			if callback then
				apply()
			else
				notif('Vape', 'Inorder to disable fflags you have applied, You need to restart roblox', 20, 'info')
			end
		end
	})
	
	List = FFlag:CreateTextList({
		Name = 'Flags',
		Function = apply,
		Tooltip = 'One flag per entry as Name=Value, click a flag to leave it out without deleting it\nSaved with your profile, so it travels with an exported config'
	})
	Flags = FFlag:CreateTextBox({
		Name = 'FFlags',
		Placeholder = 'json format only',
		Function = function(enter)
			if enter and Flags.Value ~= '' then
				ingest(Flags.Value, 'the box')
				Flags:SetValue('')
			end
		end
	})
	FFlag:CreateButton({
		Name = 'Import from file',
		Function = function()
			if not isfile('opmsix/fflags.json') then
				notif('Vape', 'No opmsix/fflags.json to read', 12, 'warning')
				return
			end
	
			ingest(readfile('opmsix/fflags.json'), 'opmsix/fflags.json')
		end
	})
	FFlag:CreateButton({
		Name = 'Export to file',
		Function = function()
			local json = {}
			for _, v in List.ListEnabled do
				local name, value = v:match('^%s*(.-)%s*=%s*(.-)%s*$')
				if name and name ~= '' then
					json[name] = value
				end
			end
	
			local plain = httpService:JSONEncode(json)
			local suc2, blob = pcall(function()
				return marker..#plain..':'..base64encode(lz4compress(plain))
			end)
	
			local copied, packed = plain, false
			if suc2 and unpackFlags(blob) == plain then
				copied, packed = blob, true
			end
			writefile('opmsix/fflags.json', plain)
	
			if setclipboard then
				setclipboard(copied)
			end
	
			notif('Vape', packed and `Wrote opmsix/fflags.json and copied {#copied} characters to your clipboard, {math.floor(#copied / #plain * 100)}% of the raw json` or `Wrote opmsix/fflags.json and copied the raw json, packing it did not read back so it was left alone`, 12, packed and 'info' or 'warning')
		end
	})
	FFlag:CreateButton({
		Name = 'Reset',
		Function = function()
			table.clear(List.List)
			table.clear(List.ListEnabled)
			List:ChangeValue()
			notif('Vape', 'Cleared the list, restart roblox to drop the flags already applied', 20, 'info')
		end
	})
end)

run(function()
	local FOV
	local Value
	local oldfov
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_fov.png'),
		Function = function(callback)
			if callback then
				oldfov = gameCamera.FieldOfView
				repeat
					gameCamera.FieldOfView = Value.Value
					task.wait()
				until not FOV.Enabled
			else
				gameCamera.FieldOfView = oldfov
			end
		end,
		Tooltip = 'Adjusts camera vision'
	})
	
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)

run(function()
	local FPS
	local label
	
	FPS = vape.Legit:CreateModule({
		Name = 'FPS',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_fps.png'),
		Function = function(callback)
			if callback then
				local frames = {}
				local startClock = os.clock()
				local updateTick = tick()
	
				FPS:Clean(runService.Heartbeat:Connect(function()
					local updateClock = os.clock()
					for i = #frames, 1, -1 do
						frames[i + 1] = frames[i] >= updateClock - 1 and frames[i] or nil
					end
	
					frames[1] = updateClock
					if updateTick < tick() then
						updateTick = tick() + 1
						label.Text = math.floor(os.clock() - startClock >= 1 and #frames or #frames / (os.clock() - startClock))..' FPS'
					end
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current framerate'
	})
	
	FPS:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	FPS:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = 'inf FPS'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = FPS.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local Keystrokes
	local KeyStyle
	local MouseStyle
	local ShowSpacebar
	local ShowCpsOnly
	local keys = {}
	local leftclicks = {}
	local rightclicks = {}
	local arrowicons = {
		W = getvapeasset('opmsix/assets/new/key_up.png'),
		A = getvapeasset('opmsix/assets/new/key_left.png'),
		S = getvapeasset('opmsix/assets/new/key_down.png'),
		D = getvapeasset('opmsix/assets/new/key_right.png')
	}
	local keybinds = {
		[Enum.KeyCode.W] = 'W',
		[Enum.KeyCode.A] = 'A',
		[Enum.KeyCode.S] = 'S',
		[Enum.KeyCode.D] = 'D',
		[Enum.KeyCode.Space] = 'Space'
	}
	local releasedbackground = Color3.fromRGB(20, 20, 20)
	local pressedtext = Color3.fromRGB(20, 20, 20)
	local keytween = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
	local holder, mouseicons, cpsholder, cpsbackground, cpsdivider, cpsleft, cpsright, cpslabel
	local lmbicon, rmbicon, mmbicon
	
	local function addLabel(parent, name, text)
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontDisplay
		label.Name = name
		label.Size = UDim2.fromOffset(200, 22)
		label.Text = text
		label.TextColor3 = Color3.fromRGB(209, 209, 209)
		label.TextSize = 16 * uipallet.DisplayScale
		label.Parent = parent
	
		return label
	end
	
	local function placeCps(label, x, centery, alignment)
		label.Position = UDim2.fromOffset(alignment == Enum.TextXAlignment.Right and x - 200 or x, centery - 11)
		label.TextXAlignment = alignment
	end
	
	local function placeKey(entry, x, y, width, height)
		entry.Object.Position = UDim2.fromOffset(x, y - 1)
		entry.Object.Size = UDim2.fromOffset(width, height + 1)
		entry.Label.Position = UDim2.fromOffset((width / 2) - 100, 5.75)
		entry.Icon.Position = UDim2.fromOffset((width / 2) - 4.4, 6)
	end
	
	local function pressKey(entry, pressed)
		if entry.Pressed == pressed then return end
	
		entry.Pressed = pressed
		entry.Shadow.Enabled = pressed
	
		tween:Tween(entry.Object, keytween, {
			BackgroundColor3 = pressed and Color3.new(1, 1, 1) or releasedbackground,
			BackgroundTransparency = pressed and 0 or 0.294
		})
	
		tween:Tween(entry.Bar, keytween, {
			BackgroundColor3 = pressed and pressedtext or Color3.new(1, 1, 1)
		})
	
		tween:Tween(entry.Icon, keytween, {
			ImageColor3 = pressed and pressedtext or Color3.new(1, 1, 1)
		})
	
		tween:Tween(entry.Label, keytween, {
			TextColor3 = pressed and pressedtext or Color3.new(1, 1, 1)
		})
	
		if entry.Mouse then
			tween:Tween(entry.Mouse, keytween, {
				ImageColor3 = pressed and Color3.new(1, 1, 1) or releasedbackground,
				ImageTransparency = pressed and 0 or 0.294
			})
		end
	end
	
	local function countClicks(clicks)
		local now = tick()
		while clicks[1] and clicks[1] < now do
			table.remove(clicks, 1)
		end
	
		return #clicks
	end
	
	local function refreshLayout()
		if not holder then return end
	
		local iconstyle = MouseStyle.Value == 'Icon'
		local arrowstyle = KeyStyle.Value == 'Arrow'
		local spacebar = ShowSpacebar.Enabled
	
		for i, v in keys do
			v.Object.Visible = not ShowCpsOnly.Enabled and (i ~= 'Space' or spacebar) and not (iconstyle and (i == 'LMB' or i == 'RMB'))
			v.Label.Visible = not arrowstyle or i == 'LMB' or i == 'RMB' or i == 'Space'
			v.Icon.Visible = arrowstyle and arrowicons[i] ~= nil
			v.Icon.Image = arrowicons[i] or ''
		end
	
		mouseicons.Visible = iconstyle and not ShowCpsOnly.Enabled
		cpsdivider.Visible = not ShowCpsOnly.Enabled
		cpslabel.Visible = ShowCpsOnly.Enabled
		cpsright.Visible = not ShowCpsOnly.Enabled
	
		if ShowCpsOnly.Enabled then
			holder.Size = UDim2.fromOffset(150, 40)
			cpsholder.Position = UDim2.fromOffset(0, 0)
			cpsholder.Size = UDim2.fromOffset(110, 20)
			cpsbackground.Position = UDim2.fromOffset(0, 0)
			cpsbackground.Size = UDim2.fromOffset(39 + getfontbounds('CPS', 16 * uipallet.DisplayScale, uipallet.FontDisplay).X, 24)
			placeCps(cpsleft, 22, 14, Enum.TextXAlignment.Right)
			placeCps(cpslabel, 25, 14, Enum.TextXAlignment.Left)
	
			return
		end
	
		local keysy = iconstyle and 8 or 4
		local mousex = iconstyle and 122 or 0
		local mousey = (iconstyle and keysy - 12 or keysy + 80) + (spacebar and 28 or 0)
		local cpswidth = iconstyle and 80 or 110
		holder.Size = UDim2.fromOffset(108 + (iconstyle and 96 or 0), (iconstyle and 80 or 144) + (spacebar and 28 or 0))
		placeKey(keys.W, 38, keysy - 4, 34, 34)
		placeKey(keys.A, 0, keysy + 38, 34, 34)
		placeKey(keys.S, 38, keysy + 38, 34, 34)
		placeKey(keys.D, 76, keysy + 38, 34, 34)
		placeKey(keys.Space, 0, keysy + 79, 110.5, 22)
		placeKey(keys.LMB, mousex, mousey, 52.7, 32)
		placeKey(keys.RMB, mousex + 56.7, mousey, 52.7, 32)
		mouseicons.Position = UDim2.fromOffset(mousex - 4, mousey)
		cpsholder.Position = UDim2.fromOffset(mousex, mousey + (iconstyle and 44 or 34))
		cpsholder.Size = UDim2.fromOffset(cpswidth, 20)
		cpsbackground.Position = UDim2.fromOffset(0, 4)
		cpsbackground.Size = UDim2.fromOffset(cpswidth, 24)
		cpsdivider.Position = UDim2.fromOffset(cpswidth / 2, 8)
		placeCps(cpsleft, 10, 16, Enum.TextXAlignment.Left)
		placeCps(cpsright, cpswidth - 10, 16, Enum.TextXAlignment.Right)
	end
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		cpsleft.Text = tostring(countClicks(leftclicks))
		cpsright.Text = tostring(countClicks(rightclicks))
	end
	
	local function inputChanged(input, pressed)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local name = keybinds[input.KeyCode]
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			name = 'LMB'
	
			if pressed then
				table.insert(leftclicks, tick() + 1)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			name = 'RMB'
	
			if pressed then
				table.insert(rightclicks, tick() + 1)
			end
		end
	
		if name and keys[name] then
			pressKey(keys[name], pressed)
		end
	end
	
	Keystrokes = vape.Legit:CreateModule({
		Name = 'Keystrokes',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_keystrokes.png'),
		Function = function(callback)
			if callback then
				Keystrokes:Clean(inputService.InputBegan:Connect(function(input)
					inputChanged(input, true)
				end))
	
				Keystrokes:Clean(inputService.InputEnded:Connect(function(input)
					inputChanged(input, false)
				end))
	
				Keystrokes:Clean(runService.RenderStepped:Connect(update))
			else
				for _, v in keys do
					pressKey(v, false)
				end
			end
		end,
		Size = UDim2.fromOffset(108, 172),
		Tooltip = 'Shows when your movement keys or mouse buttons are pressed, as well as mouse clicks per second'
	})
	
	KeyStyle = Keystrokes:CreateDropdown({
		Name = 'Key Style',
		List = {'Keyboard', 'Arrow'},
		Function = function()
			refreshLayout()
		end
	})
	MouseStyle = Keystrokes:CreateDropdown({
		Name = 'Mouse Style',
		List = {'Button', 'Icon'},
		Function = function()
			refreshLayout()
		end
	})
	ShowSpacebar = Keystrokes:CreateToggle({
		Name = 'Show Spacebar',
		Function = function()
			refreshLayout()
		end,
		Default = true
	})
	ShowCpsOnly = Keystrokes:CreateToggle({
		Name = 'Show CPS Only',
		Function = function()
			refreshLayout()
		end
	})
	holder = Keystrokes.Children
	for _, v in {'W', 'A', 'S', 'D', 'Space', 'LMB', 'RMB'} do
		local name = v
		local key = Instance.new('Frame')
		key.BackgroundColor3 = releasedbackground
		key.BackgroundTransparency = 0.294
		key.BorderSizePixel = 0
		key.Name = name
		key.Parent = holder
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = key
		local shadow = Instance.new('UIShadow')
		shadow.BlurRadius = UDim.new(0, 6)
		shadow.Color = Color3.new()
		shadow.Enabled = false
		shadow.Offset = UDim2.new()
		shadow.Spread = UDim2.new()
		shadow.Transparency = 0.404
		shadow.Parent = key
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontBold
		label.Name = 'Label'
		label.Size = UDim2.fromOffset(200, 20)
		label.Text = name == 'Space' and '' or name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 14
		label.Parent = key
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Name = 'Icon'
		icon.Size = UDim2.fromOffset(8.8, 8.8)
		icon.Visible = false
		icon.Parent = key
		local bar = Instance.new('Frame')
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.Name = 'Bar'
		bar.Position = UDim2.new(0.5, 0, 0, 4)
		bar.Size = UDim2.fromOffset(60, 3)
		bar.Visible = name == 'Space'
		bar.Parent = key
		keys[name] = {Object = key, Label = label, Icon = icon, Bar = bar, Shadow = shadow, Pressed = false}
	
	end
	mouseicons = Instance.new('Frame')
	mouseicons.BackgroundTransparency = 1
	mouseicons.Name = 'MouseIcons'
	mouseicons.Size = UDim2.fromOffset(96, 48)
	mouseicons.Visible = false
	mouseicons.Parent = holder
	lmbicon = Instance.new('ImageLabel')
	lmbicon.BackgroundTransparency = 1
	lmbicon.Image = getvapeasset('opmsix/assets/new/key_lmb.png')
	lmbicon.ImageColor3 = releasedbackground
	lmbicon.Name = 'LMB'
	lmbicon.Size = UDim2.fromOffset(50.2, 48)
	lmbicon.Parent = mouseicons
	rmbicon = lmbicon:Clone()
	rmbicon.Image = getvapeasset('opmsix/assets/new/key_rmb.png')
	rmbicon.Name = 'RMB'
	rmbicon.Position = UDim2.fromOffset(40, 0)
	rmbicon.Parent = mouseicons
	mmbicon = Instance.new('ImageLabel')
	mmbicon.BackgroundTransparency = 1
	mmbicon.Image = getvapeasset('opmsix/assets/new/key_mmb.png')
	mmbicon.ImageColor3 = Color3.fromRGB(225, 225, 225)
	mmbicon.Name = 'MMB'
	mmbicon.Position = UDim2.fromOffset(43, 14)
	mmbicon.Size = UDim2.fromOffset(3.9, 13.8)
	mmbicon.Parent = mouseicons
	cpsholder = Instance.new('Frame')
	cpsholder.BackgroundTransparency = 1
	cpsholder.Name = 'CPS'
	cpsholder.Size = UDim2.fromOffset(110, 20)
	cpsholder.Parent = holder
	cpsbackground = Instance.new('Frame')
	cpsbackground.BackgroundColor3 = releasedbackground
	cpsbackground.BackgroundTransparency = 0.294
	cpsbackground.BorderSizePixel = 0
	cpsbackground.Name = 'Background'
	cpsbackground.ZIndex = 0
	cpsbackground.Parent = cpsholder
	local cpscorner = Instance.new('UICorner')
	cpscorner.CornerRadius = UDim.new(0, 5)
	cpscorner.Parent = cpsbackground
	cpsdivider = Instance.new('Frame')
	cpsdivider.BackgroundColor3 = Color3.fromRGB(209, 209, 209)
	cpsdivider.BorderSizePixel = 0
	cpsdivider.Name = 'Divider'
	cpsdivider.Size = UDim2.fromOffset(2, 18)
	cpsdivider.Parent = cpsholder
	cpsleft = addLabel(cpsholder, 'Left', '0')
	cpsright = addLabel(cpsholder, 'Right', '0')
	cpslabel = addLabel(cpsholder, 'Label', 'CPS')
	cpslabel.Visible = false
	keys.LMB.Mouse = lmbicon
	keys.RMB.Mouse = rmbicon
	refreshLayout()
end)

run(function()
	local Memory
	local label
	
	Memory = vape.Legit:CreateModule({
		Name = 'Memory',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_memory.png'),
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(stats.PerformanceStats.Memory:GetValue()))..' MB'
					task.wait(1)
				until not Memory.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the memory currently used by roblox'
	})
	
	Memory:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Memory:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = '0 MB'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Memory.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local Ping
	local label
	
	Ping = vape.Legit:CreateModule({
		Name = 'Ping',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_ping.png'),
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(stats.PerformanceStats.Ping:GetValue()))..' ms'
					task.wait(1)
				until not Ping.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current connection speed to the roblox server'
	})
	
	Ping:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Ping:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = '0 ms'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Ping.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = os.clock()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then
			table.clear(alreadypicked)
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat
				task.wait()
				chosensong = list[math.random(1, #list)]
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat
			task.wait()
		until songobj.IsLoaded or not SongBeats.Enabled
	
		if SongBeats.Enabled then
			beattick = os.clock() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_songbeats.png'),
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				SongBeats:Clean(songobj)
				oldfov = gameCamera.FieldOfView
	
				repeat
					if not songobj.Playing then
						choosesong()
					end
	
					if beattick < os.clock() and SongBeats.Enabled and FOV.Enabled then
						beattick = os.clock() + songbpm
						if songtween then
							songtween:Cancel()
						end
	
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {
							FieldOfView = oldfov
						})
	
						songtween:Play()
					end
	
					task.wait()
				until not SongBeats.Enabled
			else
				if songtween then
					songtween:Cancel()
				end
	
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
	
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
	
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then
				songobj.Volume = val / 100
			end
		end,
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
	local Speedmeter
	local label
	
	Speedmeter = vape.Legit:CreateModule({
		Name = 'Speedmeter',
		Category = 'HUD',
		Icon = getvapeasset('opmsix/assets/new/legit_speedmeter.png'),
		Function = function(callback)
			if callback then
				repeat
					local lastpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					local dt = task.wait(0.2)
					local newpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					label.Text = math.round(((lastpos - newpos) / dt).Magnitude)..' sps'
				until not Speedmeter.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the average velocity in studs'
	})
	
	Speedmeter:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Speedmeter:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = '0 sps'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Speedmeter.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local TimeChanger
	local Value
	local old
	
	TimeChanger = vape.Legit:CreateModule({
		Name = 'Time Changer',
		Category = 'Game',
		Icon = getvapeasset('opmsix/assets/new/legit_timechanger.png'),
		Function = function(callback)
			if callback then
				old = lightingService.TimeOfDay
				repeat
					lightingService.TimeOfDay = Value.Value..':00:00'
					task.wait()
				until not TimeChanger.Enabled
			else
				lightingService.TimeOfDay = old
				old = nil
			end
		end,
		Tooltip = 'Change the time of the current world'
	})
	
	Value = TimeChanger:CreateSlider({
		Name = 'Time',
		Min = 0,
		Max = 24,
		Function = function(val)
			if TimeChanger.Enabled then
				lightingService.TimeOfDay = val..':00:00'
			end
		end,
		Default = 12
	})
end)