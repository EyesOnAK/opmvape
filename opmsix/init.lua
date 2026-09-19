--!nocheck
local Licence = {}
Licence.Key = script_key or [[KEY-HERE]]

local isfile = isfile or function(File)
    local Success, Result = pcall(function() return readfile(File) end)
    return Success and Result
end

for _, Folder in ipairs({'opmsix', 'opmsix/games', 'opmsix/profiles', 'opmsix/assets', 'opmsix/libraries', 'opmsix/guis'}) do
    if not isfolder(Folder) then
        makefolder(Folder)
    end
end

local function downloadMain()
    local Success, Result = pcall(function()
        return game:HttpGet('https://raw.githubusercontent.com/EyesOnAK/opmvape/main/opmsix/main.lua', true)
    end)
    if Success and Result then
        writefile('opmsix/main.lua', Result)
    end
end

if not isfile('opmsix/main.lua') or not shared.VapeDeveloper then
    -- Always download latest main.lua unless in developer mode
    downloadMain()
end

return loadstring(readfile('opmsix/main.lua'), 'main')(Licence)