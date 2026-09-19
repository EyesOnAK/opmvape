--!nocheck

local Licence = { }
Licence.Key = script_key or nil

local cloneref:(<T>(T) -> T) | (<a>(a) -> a) = cloneref or function(Reference: any) return Reference end
local isfile: (string) -> boolean = isfile or function(File: string): boolean
    local Success: boolean, Result = pcall(function()
        return readfile(File)
    end)

    return Success and Result
end

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local EncodingService: EncodingService = cloneref(game:GetService("EncodingService"))

type ContentData = {
    sha: string,
    content: string,
    encoding: string,
    path: string
}

type Contents = {files: {ContentData}}
type GotContents = {Success: boolean, Data: Contents}

local CryptHash: (Content: string, Algorithm: string) -> string = (crypt and crypt.hash)
if not CryptHash then
    local HashLibrary = loadstring(game:HttpGet('https://raw.githubusercontent.com/EyesOnAK/opmvape/main/opmsix/libraries/hash.lua'))()
    CryptHash = HashLibrary.sha1
end

local function GetGithubContents(Path: string): GotContents
    local Success: boolean, Result: string = pcall(function()
        return game:HttpGet("https://api.github.com/repos/EyesOnAK/opmvape/contents/opmsix")
    end)

    if Success then
        local SuccessfulJSONDecode, JSON = pcall(HttpService.JSONDecode, HttpService, Result)
        return {
            Success = SuccessfulJSONDecode,
            Data = JSON
        }
    end

    return {
        Success = false,
        Data = Result
    }
end

local function DownloadAsset(FileData: ContentData): ()
    if FileData.encoding == "base64" then
        FileData.content = buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(FileData.content)))
    end

    writefile(`opmsix/{FileData.path:gsub("src/", "")}`, FileData.content)
end

local function GetCurrentSHA(Path: string): string
    local FilePath: string = `opmsix/{Path:gsub("src/", "")}`
    local FileContents = (isfile(FilePath) and readfile(FilePath))
    if FileContents then
        return CryptHash(`blob {#FileContents}\0{FileContents}`, "sha1")
    end

    return ""
end

local function DownloadAssets(Contents: GotContents, NewUser: boolean): boolean
    if Contents.Success then
        for i: number, v: {content: string, path: string?, sha: string} in Contents.Data.files do
            if not NewUser and v.path:find("/profiles/") then
                continue
            end

            local CurrentSHA: string = GetCurrentSHA(v.path)
            if CurrentSHA ~= v.sha then
                DownloadAsset(v)
            end
        end
    end

    return Contents.Success
end

for _, Folder: string in {'opmsix', 'opmsix/games', 'opmsix/profiles', 'opmsix/assets', 'opmsix/libraries', 'opmsix/guis'} do
    if not isfolder(Folder) then
        makefolder(Folder)
    end
end

if not shared.VapeDeveloper then
    local Commit: string? = Licence.Commit
    if not Commit then
        local Success: boolean, Result: string = pcall(function() 
            return game:HttpGet('https://api.opmvape.dev/commit') 
        end)

        if Success then
            local SuccessJSON, JSON = pcall(HttpService.JSONDecode, HttpService, Result)
            if SuccessJSON then
                Commit = JSON.sha
            end
        end
    end

    local NewUser: boolean = not isfile('opmsix/profiles/commit.txt') or #listfiles('opmsix') < 7
    if NewUser or readfile('opmsix/profiles/commit.txt') ~= Commit then
        local Success: boolean = DownloadAssets(GetGithubContents(), NewUser)
        if Success and Commit then
            warn(`Successfully updated to {Commit}`)
            writefile('opmsix/profiles/commit.txt', Commit)
        else
            warn(`Failed to update to {Commit}`)
        end
    end
end

return loadstring(readfile('opmsix/main.lua'), 'main')(Licence)