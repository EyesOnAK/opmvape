local renderlib = {
	Fonts = {
		UI = 0,
		System = 1,
		Plex = 2,
		Monospace = 3
	},
	Objects = {},
	Old = {},
	Installed = false,
	Mobile = false
}

local cloneref = cloneref or function(obj)
	return obj
end
local getgenv = getgenv or function()
	return shared
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local httpService = cloneref(game:GetService('HttpService'))
local lplr = playersService.LocalPlayer
local fonts = {
	[0] = Font.fromEnum(Enum.Font.SourceSans),
	[1] = Font.fromEnum(Enum.Font.Code),
	[2] = Font.fromEnum(Enum.Font.Code),
	[3] = Font.fromEnum(Enum.Font.RobotoMono)
}
local classes = {}
local paints = {
	Visible = true,
	ZIndex = true,
	Color = true,
	Transparency = true,
	Outline = true,
	OutlineColor = true
}
local wedgeimage = 'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAFeElEQVR42u3dSU4DQRQFQd//Ej5qAws2iMHGPVRVxpM+B7CcIQEebtu23TczK+5+e/9xg4BZL/6P9j8BgIBZLP6vAEDALBT/dwBAwCwS/08AQMAsEP9vAEDAbPH4/wIAAmYLx/8IABAwWzT+RwGAgNmC8T8DAATMFov/WQAgYLZQ/P8BAAJmi8T/XwAgYLZA/K8AAAGzyeN/FQAImE0c/x4AQMBs0vj3AgACZhPGvycAEDCbLP69AYCA2UTxHwEABMwmif8oACBgNkH8RwIAAbPB4z8aAAiYDRz/GQBAwGzQ+M8CAAJmA8Z/JgAQMBss/rMBgIDZQPFfAQAEzAaJ/yoAIGA2QPxXAgABs4vjvxoACJhdGP8IAEDAxB8HAAIm/jgAEDDxxwGAgIk/DgAETPxxACBg4o8DAAETfxwACJj44wBAwMQfBwACJv44ABAw8ccBgICJPw4ABEz8cQAgYOKPAwABE38cAAiY+OMAQMDEHwcAAib+OAAQMPHHAYCAiT8OAARM/HEAIGDijwMAARN/HAAImPjjAEDAxB8HAAIm/jgAEDDxxwGAgIk/DgAETPxxACBg4o8DAAHLx18HAAKWjh8AEBB//PkPAAiIHwAOAuIHgIOA+AEAARM/ACBg4gcABEz8AICAiR8AEDDxAwACJn4AQMDEDwAImPgBAAETPwAgYOIHAARM/ACAgIkfABAw8QMAAiZ+AEDAxA8ACJj4AQABEz8AIGDiBwAETPwAgICJHwAQEL8DAATE7wAAAfE7AEBA/A4AEBC/AwAExO8AAAHxOwBAQPwOABAQvwMABMTvAAAB8TsAQED8DgAQEL8DAATEDwAPAgTEDwAHAfEDwEFA/ABwEBA/ABwExA8ABwHxA8BBQPwAcBAQPwAcBMQPAAcB8QPARREQPwBcFAHxA8BFERA/AFwUAfEDwEURED8AXBQB8QPARREQPwBcFAHxA8BFERA/AFwUAfEDwEURED8AXBQB8QPARREQPwBcFAHxA8BFERA/AFwUAfEDwAHAAcD5FcABwPkjoAOA829ABwDnhUAOAM5LgR0AnDcDOQA4bwd2AHA+EMQBwPlIMAcA50NBHQCcjwV3AHC+GMQBwPlqMAcA58tBHQCcrwd3AHALxA8BALh4/BAAgIvHDwEAuHj8EACAi8cPAQC4ePwQAICLxw8BALh4/BAAgIvHDwEAuHj8EACAi8cPAQC4ePwQAICLxw8BALh4/BAAgIvHDwEAuHj8EACAi8cPAQCI3yAAAPEbBAAgfgh4fgBA/BDwXAGA+CHgACB+CDgAiB8CDgDih4ADgPgh4AAgfgg4AIgfAg4A4oeAA4D4IeAAIH4IOACIHwIOAOKHgAOA+CHgACB+CDgAiB8CAPAgiB8CAHDihwAAnPghAAAnfggAwIkfAgAQv0EAAOI3CABA/AYBAIjfIAAA8RsEACB+gwAAxG8QAID4DQIAEL9BAADiNwgAQPwGAQCI3yAAAPEbBAAgfoMAAMRvEACA+A0CABC/QQAA4jcIAED8BgEAiN8gAADxGwQAIH6DAADEbxAoAyB+g0AUAPEbBKIAiN8gEAVA/AaBKADiNwhEARC/QSAKgPgNAlEAxG8QiAIgfoNAFADxGwSiAIjfIBAFQPwGgSgA4jcIRAEQv0EgCoD4DQJRAMRvEIgCIH6DQBQA8ZtdjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjMAbGq/zRXlT3IgAAAAASUVORK5CYII='
local wedgeasset = ''
local imagecache = {}
local screengui
local measurelabel

local function createBody(set, class)
	set.Body = Instance.new(class)
	set.Body.BackgroundTransparency = 1
	set.Body.BorderSizePixel = 0
	set.Body.Visible = false
end

local function createStroke(set, mode, join)
	set.Stroke = Instance.new('UIStroke')
	set.Stroke.ApplyStrokeMode = mode
	set.Stroke.Color = Color3.new()
	set.Stroke.Enabled = false
	set.Stroke.LineJoinMode = join
	set.Stroke.Parent = set.Body
	table.insert(set.Instances, set.Stroke)
end

local function createCorner(set, radius)
	set.Corner = Instance.new('UICorner')
	set.Corner.CornerRadius = radius
	set.Corner.Parent = set.Body
	table.insert(set.Instances, set.Corner)
end

local function createPolygon(set, lines, wedges)
	for i = 1, lines do
		local line = Instance.new('Frame')
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.Visible = false
		line.Parent = screengui
		set.Lines[i] = line
		table.insert(set.Instances, line)
	end
	for i = 1, wedges do
		local wedge = Instance.new('ImageLabel')
		wedge.AnchorPoint = Vector2.new(0.5, 0.5)
		wedge.BackgroundTransparency = 1
		wedge.BorderSizePixel = 0
		wedge.Image = wedgeasset
		wedge.ImageRectSize = Vector2.new(128, 128)
		wedge.Visible = false
		wedge.Parent = screengui
		set.Wedges[i] = wedge
		table.insert(set.Instances, wedge)
	end
end

local function paintPolygon(set)
	local props = set.Props
	local transparency = 1 - math.clamp(props.Transparency, 0, 1)
	for _, v in set.Lines do
		v.BackgroundColor3 = props.Color
		v.BackgroundTransparency = transparency
		v.Visible = props.Visible and not props.Filled
		v.ZIndex = props.ZIndex
	end
	for _, v in set.Wedges do
		v.ImageColor3 = props.Color
		v.ImageTransparency = transparency
		v.Visible = props.Visible and props.Filled
		v.ZIndex = props.ZIndex
	end
end

local function setLine(frame, from, to, thickness)
	local dir = to - from
	frame.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
	frame.Size = UDim2.fromOffset(dir.Magnitude, thickness)
	frame.Rotation = math.deg(math.atan2(dir.Y, dir.X))
end

local function setWedge(set, first, second, a, b, c)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		a, c = c, a
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end

	ab, bc = b - a, c - b
	if bc.Magnitude <= 0 then
		set.Wedges[first].Size = UDim2.new()
		set.Wedges[second].Size = UDim2.new()
		return
	end

	local unit = bc.Unit
	local height = unit.X * ab.Y - unit.Y * ab.X
	local theta = math.deg(math.atan2(unit.Y, unit.X))
	local tall = math.abs(height)
	local row = height >= 0 and 128 or 0
	set.Wedges[first].ImageRectOffset = Vector2.new(0, row)
	set.Wedges[first].Rotation = theta
	set.Wedges[first].Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	set.Wedges[first].Size = UDim2.fromOffset(math.abs(unit:Dot(ab)), tall)
	set.Wedges[second].ImageRectOffset = Vector2.new(128, row)
	set.Wedges[second].Rotation = theta
	set.Wedges[second].Position = UDim2.fromOffset((a.X + c.X) / 2, (a.Y + c.Y) / 2)
	set.Wedges[second].Size = UDim2.fromOffset(math.abs(unit:Dot(c - a)), tall)
end

local function getAsset(data)
	if data == '' or data:find('://') then return data end
	if not imagecache[data] then
		if not writefile or not getcustomasset then return '' end
		local path = 'opmsix/assets/drawing/' .. tostring(httpService:GenerateGUID(false)) .. '.png'
		writefile(path, data)
		imagecache[data] = getcustomasset(path)
	end

	return imagecache[data]
end

classes.Base = {
	Properties = {
		Visible = false,
		ZIndex = 1,
		Transparency = 1,
		Color = Color3.new()
	}
}

classes.Line = {
	Properties = {
		From = Vector2.zero,
		To = Vector2.zero,
		Thickness = 1
	},
	Create = function(set)
		createBody(set, 'Frame')
		set.Body.AnchorPoint = Vector2.new(0.5, 0.5)
		set.Body.Parent = screengui
		table.insert(set.Instances, set.Body)
	end,
	Paint = function(set)
		local props = set.Props
		set.Body.BackgroundColor3 = props.Color
		set.Body.BackgroundTransparency = 1 - math.clamp(props.Transparency, 0, 1)
		set.Body.Visible = props.Visible
		set.Body.ZIndex = props.ZIndex
	end,
	Shape = function(set)
		local props = set.Props
		setLine(set.Body, props.From, props.To, props.Thickness)
	end
}

classes.Text = {
	Properties = {
		Text = '',
		Font = 0,
		Size = 16,
		Position = Vector2.zero,
		Center = false,
		Outline = false,
		OutlineColor = Color3.new(),
		TextBounds = Vector2.zero
	},
	Create = function(set)
		createBody(set, 'TextLabel')
		set.Body.RichText = false
		set.Body.TextWrapped = false
		set.Body.TextXAlignment = Enum.TextXAlignment.Center
		set.Body.TextYAlignment = Enum.TextYAlignment.Top
		createStroke(set, Enum.ApplyStrokeMode.Contextual, Enum.LineJoinMode.Round)
		set.Body.Parent = screengui
		table.insert(set.Instances, set.Body)
	end,
	Paint = function(set)
		local props = set.Props
		local transparency = 1 - math.clamp(props.Transparency, 0, 1)
		set.Body.TextColor3 = props.Color
		set.Body.TextTransparency = transparency
		set.Stroke.Enabled = props.Outline
		set.Stroke.Color = props.OutlineColor
		set.Stroke.Transparency = transparency
		set.Body.Visible = props.Visible
		set.Body.ZIndex = props.ZIndex
	end,
	Shape = function(set)
		local props = set.Props
		measurelabel.FontFace = fonts[props.Font] or fonts[0]
		measurelabel.TextSize = props.Size
		measurelabel.Text = props.Text
		props.TextBounds = measurelabel.TextBounds
		set.Body.FontFace = measurelabel.FontFace
		set.Body.TextSize = props.Size
		set.Body.Text = props.Text
		set.Body.AnchorPoint = Vector2.new(props.Center and 0.5 or 0, 0)
		set.Body.Position = UDim2.fromOffset(props.Position.X, props.Position.Y)
		set.Body.Size = UDim2.fromOffset(props.TextBounds.X, props.TextBounds.Y)
	end
}

classes.Image = {
	Properties = {
		Data = '',
		Size = Vector2.zero,
		Position = Vector2.zero,
		Rounding = 0,
		Color = Color3.new(1, 1, 1)
	},
	Create = function(set)
		createBody(set, 'ImageLabel')
		createCorner(set, UDim.new())
		set.Body.Parent = screengui
		table.insert(set.Instances, set.Body)
	end,
	Paint = function(set)
		local props = set.Props
		set.Body.ImageColor3 = props.Color
		set.Body.ImageTransparency = 1 - math.clamp(props.Transparency, 0, 1)
		set.Body.Visible = props.Visible
		set.Body.ZIndex = props.ZIndex
	end,
	Shape = function(set)
		local props = set.Props
		set.Body.Position = UDim2.fromOffset(props.Position.X, props.Position.Y)
		set.Body.Size = UDim2.fromOffset(props.Size.X, props.Size.Y)
		set.Body.Image = getAsset(props.Data)
		set.Corner.CornerRadius = UDim.new(0, props.Rounding)
	end
}

classes.Circle = {
	Properties = {
		Position = Vector2.zero,
		Radius = 0,
		NumSides = 250,
		Thickness = 1,
		Filled = false
	},
	Create = function(set)
		createBody(set, 'Frame')
		set.Body.AnchorPoint = Vector2.new(0.5, 0.5)
		createCorner(set, UDim.new(0.5, 0))
		createStroke(set, Enum.ApplyStrokeMode.Border, Enum.LineJoinMode.Round)
		set.Body.Parent = screengui
		table.insert(set.Instances, set.Body)
	end,
	Paint = function(set)
		local props = set.Props
		local transparency = 1 - math.clamp(props.Transparency, 0, 1)
		set.Body.BackgroundColor3 = props.Color
		set.Body.BackgroundTransparency = props.Filled and transparency or 1
		set.Stroke.Enabled = not props.Filled
		set.Stroke.Color = props.Color
		set.Stroke.Thickness = props.Thickness
		set.Stroke.Transparency = transparency
		set.Body.Visible = props.Visible
		set.Body.ZIndex = props.ZIndex
	end,
	Shape = function(set)
		local props = set.Props
		local diameter = props.Radius * 2 - (props.Filled and 0 or props.Thickness)
		set.Body.Position = UDim2.fromOffset(props.Position.X, props.Position.Y)
		set.Body.Size = UDim2.fromOffset(diameter, diameter)
	end
}

classes.Square = {
	Properties = {
		Position = Vector2.zero,
		Size = Vector2.zero,
		Thickness = 1,
		Filled = false
	},
	Create = function(set)
		createBody(set, 'Frame')
		createStroke(set, Enum.ApplyStrokeMode.Border, Enum.LineJoinMode.Miter)
		set.Body.Parent = screengui
		table.insert(set.Instances, set.Body)
	end,
	Paint = function(set)
		local props = set.Props
		local transparency = 1 - math.clamp(props.Transparency, 0, 1)
		set.Body.BackgroundColor3 = props.Color
		set.Body.BackgroundTransparency = props.Filled and transparency or 1
		set.Stroke.Enabled = not props.Filled
		set.Stroke.Color = props.Color
		set.Stroke.Thickness = props.Thickness
		set.Stroke.Transparency = transparency
		set.Body.Visible = props.Visible
		set.Body.ZIndex = props.ZIndex
	end,
	Shape = function(set)
		local props = set.Props
		local inset = props.Filled and 0 or props.Thickness / 2
		local corner = Vector2.new(math.min(props.Position.X, props.Position.X + props.Size.X), math.min(props.Position.Y, props.Position.Y + props.Size.Y))
		set.Body.Position = UDim2.fromOffset(corner.X + inset, corner.Y + inset)
		set.Body.Size = UDim2.fromOffset(math.abs(props.Size.X) - inset * 2, math.abs(props.Size.Y) - inset * 2)
	end
}

classes.Triangle = {
	Properties = {
		PointA = Vector2.zero,
		PointB = Vector2.zero,
		PointC = Vector2.zero,
		Thickness = 1,
		Filled = false
	},
	Create = function(set)
		createPolygon(set, 3, 2)
	end,
	Paint = function(set)
		paintPolygon(set)
	end,
	Shape = function(set)
		local props = set.Props
		setLine(set.Lines[1], props.PointA, props.PointB, props.Thickness)
		setLine(set.Lines[2], props.PointB, props.PointC, props.Thickness)
		setLine(set.Lines[3], props.PointC, props.PointA, props.Thickness)
		setWedge(set, 1, 2, props.PointA, props.PointB, props.PointC)
	end
}

classes.Quad = {
	Properties = {
		PointA = Vector2.zero,
		PointB = Vector2.zero,
		PointC = Vector2.zero,
		PointD = Vector2.zero,
		Thickness = 1,
		Filled = false
	},
	Create = function(set)
		createPolygon(set, 4, 4)
	end,
	Paint = function(set)
		paintPolygon(set)
	end,
	Shape = function(set)
		local props = set.Props
		setLine(set.Lines[1], props.PointA, props.PointB, props.Thickness)
		setLine(set.Lines[2], props.PointB, props.PointC, props.Thickness)
		setLine(set.Lines[3], props.PointC, props.PointD, props.Thickness)
		setLine(set.Lines[4], props.PointD, props.PointA, props.Thickness)
		setWedge(set, 1, 2, props.PointA, props.PointB, props.PointC)
		setWedge(set, 3, 4, props.PointA, props.PointC, props.PointD)
	end
}

renderlib.new = function(class)
	local classdata = classes[class]
	if not classdata or class == 'Base' then return end

	local set = {
		Class = class,
		Exists = true,
		Instances = {},
		Lines = {},
		Props = table.clone(classes.Base.Properties),
		Wedges = {}
	}
	for i, v in classdata.Properties do
		set.Props[i] = v
	end
	classdata.Create(set)

	local address = tostring(set):match('0x(%x+)') or '0000000000000000'
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)

	local function remove()
		if not set.Exists then return end
		set.Exists = false
		for _, v in set.Instances do
			v:Destroy()
		end
		table.clear(set.Instances)
		table.clear(set.Lines)
		table.clear(set.Wedges)
		renderlib.Objects[proxy] = nil
	end

	meta.__index = function(_, ind)
		if ind == 'Remove' or ind == 'Destroy' then return remove end
		if ind == '__OBJECT_EXISTS' then return set.Exists end

		return set.Props[ind]
	end
	meta.__newindex = function(_, ind, val)
		local old = set.Props[ind]
		if old == nil or ind == 'TextBounds' then return end
		if typeof(val) ~= typeof(old) then error("invalid argument #3 to '__newindex' (" .. tostring(typeof(old)) .. ' expected, got ' .. tostring(typeof(val)) .. ')', 2) end

		set.Props[ind] = ind == 'ZIndex' and math.floor(val) or val
		if not set.Exists then return end
		if paints[ind] then
			classdata.Paint(set)
		elseif ind == 'Filled' or ind == 'Thickness' then
			classdata.Shape(set)
			classdata.Paint(set)
		else
			classdata.Shape(set)
		end
	end
	meta.__tostring = function()
		return 'DrawingObject: 0x' .. tostring(address)
	end

	classdata.Shape(set)
	classdata.Paint(set)
	renderlib.Objects[proxy] = set

	return proxy
end

renderlib.clear = function()
	for i in table.clone(renderlib.Objects) do
		i:Remove()
	end
	table.clear(renderlib.Objects)
end

renderlib.install = function()
	if renderlib.Installed then return end
	renderlib.Installed = true

	screengui = Instance.new('ScreenGui')
	screengui.DisplayOrder = 2147483647
	screengui.IgnoreGuiInset = true
	screengui.Name = httpService:GenerateGUID(false)
	screengui.ResetOnSpawn = false
	screengui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	if not pcall(function() screengui.Parent = gethui and gethui() or cloneref(game:GetService('CoreGui')) end) then
		screengui.Parent = lplr:WaitForChild('PlayerGui')
	end

	measurelabel = Instance.new('TextLabel')
	measurelabel.BackgroundTransparency = 1
	measurelabel.Size = UDim2.fromOffset(9999, 9999)
	measurelabel.Text = ''
	measurelabel.TextTransparency = 1
	measurelabel.TextXAlignment = Enum.TextXAlignment.Left
	measurelabel.TextYAlignment = Enum.TextYAlignment.Top
	measurelabel.Parent = screengui

	if not isfolder('opmsix/assets/drawing') then
		makefolder('opmsix/assets/drawing')
	end
	if not isfile('opmsix/assets/drawing/wedge.png') then
		writefile('opmsix/assets/drawing/wedge.png', base64decode(wedgeimage))
	end
	local suc, asset = pcall(getcustomasset, 'opmsix/assets/drawing/wedge.png')
	wedgeasset = suc and asset or ''

	renderlib.Old = {
		Drawing = Drawing,
		cleardrawcache = cleardrawcache,
		isrenderobj = isrenderobj
	}
	getgenv().Drawing = {
		Fonts = renderlib.Fonts,
		clear = renderlib.clear,
		new = renderlib.new
	}
	getgenv().cleardrawcache = function()
		renderlib.clear()
		if renderlib.Old.cleardrawcache then
			renderlib.Old.cleardrawcache()
		end
	end
	getgenv().isrenderobj = function(obj)
		return renderlib.Objects[obj] ~= nil or (renderlib.Old.isrenderobj and renderlib.Old.isrenderobj(obj)) == true
	end
	getgenv().getrenderproperty = function(obj, prop)
		return obj[prop]
	end
	getgenv().setrenderproperty = function(obj, prop, val)
		obj[prop] = val
	end
end

renderlib.uninstall = function()
	if not renderlib.Installed then return end
	renderlib.Installed = false

	renderlib.clear()
	screengui:Destroy()
	screengui, measurelabel, wedgeasset = nil, nil, ''
	getgenv().Drawing = renderlib.Old.Drawing
	getgenv().cleardrawcache = renderlib.Old.cleardrawcache
	getgenv().isrenderobj = renderlib.Old.isrenderobj
	table.clear(imagecache)
end

renderlib.Mobile = inputService.TouchEnabled and not inputService.KeyboardEnabled
if renderlib.Mobile or not pcall(function() Drawing.new('Square'):Remove() end) then
	renderlib.install()
end

return renderlib