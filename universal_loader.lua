-- universal_loader.lua  (ZENTRAL)
-- Erkennt das Game, laedt shared Module + game-spezifische Tabs.
-- Author: Nico

local VERSION = "2.0.0"

-- ================================================================
-- SHARED_BASE = das Repo, in dem DIESE Datei liegt.
-- Die shared Dateien (dj_main, dj_ui_base, dj_tab_key, dj_tab_settings,
-- dj_utils) liegen im selben Repo wie der universal_loader.
-- => Falls du das Repo umbenennst, NUR diese eine Zeile anpassen.
-- ================================================================
local SHARED_BASE = "https://raw.githubusercontent.com/DJB5001/Universal-loader/main/"

-- ================================================================
-- GAME-CONFIG  (pro PlaceId)
--  gameName  -> Titel oben + Settings/Credits
--  footer    -> Text unten im Fenster (pro Game unterschiedlich!)
--  developer -> Credits
--  discord   -> Invite
--  repo      -> Repo mit den game-spezifischen Tabs (main/ingame/minigame)
--  api/provider/service -> Key-System
--  tabs      -> Liste der game-spezifischen Tab-Dateien (Reihenfolge = Anzeige)
-- ================================================================
local GAMES = {
    -- Kick a Lucky Block
    [89469502395769] = {
        gameName  = "DJ HUB | Kick a Lucky Block",
        footer    = "DJ HUB · Kick a Lucky Block",
        developer = "Nico",
        discord   = "https://discord.gg/MTXnFfHXW9",
        repo      = "https://raw.githubusercontent.com/DJB5001/Kick-a-lucky-block-script/main/",
        api       = "ef8c4422-f7d4-4b3c-ab4e-c3363317dba9",
        provider  = "Keys",
        service   = "RaiseAnimal_DJHUB",
        tabs = {
            { file = "dj_tab_ingame.lua",   label = "Ingame"   },
            { file = "dj_tab_minigame.lua", label = "Minigame" },
        },
    },

    -- Be Flash For Brainrots
    [136066387156306] = {
        gameName  = "DJ HUB | Be Flash For Brainrots",
        footer    = "DJ HUB · Be Flash For Brainrots",
        developer = "Nico",
        discord   = "https://discord.gg/MTXnFfHXW9",
        repo      = "https://raw.githubusercontent.com/DJB5001/Be-Flash-For-Brainrots-script/main/",
        api       = "ef8c4422-f7d4-4b3c-ab4e-c3363317dba9",
        provider  = "Keys",
        service   = "RaiseAnimal_DJHUB",
        tabs = {
            { file = "bf_tab_ingame.lua",   label = "Ingame"   },
            { file = "bf_tab_minigame.lua", label = "Minigame" },
        },
    },

    -- The Forge  (optional, falls genutzt)
    [76558904092080] = {
        gameName  = "DJ HUB | The Forge",
        footer    = "DJ HUB · The Forge",
        developer = "Nico",
        discord   = "https://discord.gg/MTXnFfHXW9",
        repo      = "https://raw.githubusercontent.com/DJB5001/The-Forge-script/main/",
        api       = "ef8c4422-f7d4-4b3c-ab4e-c3363317dba9",
        provider  = "Keys",
        service   = "RaiseAnimal_DJHUB",
        tabs = {
            { file = "dj_tab_ingame.lua",   label = "Ingame"   },
            { file = "dj_tab_minigame.lua", label = "Minigame" },
        },
    },
}

-- ================================================================
-- HTTP
-- ================================================================
local HttpService = game:GetService("HttpService")

local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(res) == "string" and #res > 0 then return res end
    local env = getfenv()
    local req = env.http_request or env.request or (env.syn and env.syn.request)
    if req then
        local ok2, r = pcall(function()
            return req({ Url = url, Method = "GET", Headers = { ["User-Agent"] = "Mozilla/5.0" } })
        end)
        if ok2 and r then
            local body = (type(r)=="table" and (r.Body or r.body)) or (type(r)=="string" and r) or ""
            if type(body)=="string" and #body > 0 then return body end
        end
    end
    return nil
end

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = 8,
        })
    end)
end

-- ================================================================
-- LADER (shared vs game-repo)
-- ================================================================
local function loadFrom(base, name)
    local src = httpGet(base .. name)
    if not src then warn("[DJ HUB] Download failed: " .. name) return nil end
    local ok, chunk = pcall(loadstring, src)
    if not ok or not chunk then warn("[DJ HUB] Compile failed: " .. name) return nil end
    local ok2, mod = pcall(chunk)
    if not ok2 then warn("[DJ HUB] Execution failed: " .. name .. " -> " .. tostring(mod)) return nil end
    return mod
end

-- ================================================================
-- GAME-CHECK
-- ================================================================
local placeId = game.PlaceId
local GAME    = GAMES[placeId]

if not GAME then
    local names = {}
    for _, v in pairs(GAMES) do table.insert(names, v.gameName) end
    notify("DJ HUB — Wrong Game",
        "No script for Game ID: " .. tostring(placeId) ..
        "\nSupported:\n" .. table.concat(names, "\n"))
    error("[DJ HUB] No script for PlaceId: " .. tostring(placeId))
end

print("[DJ HUB] Game: " .. GAME.gameName .. " (" .. tostring(placeId) .. ")")

-- ================================================================
-- SAVE SYSTEM  (zentral)
-- ================================================================
local SaveSystem = {}
local SAVE_DIR   = "DJHub/Settings"

local function hasFS()
    return typeof(writefile)  == "function" and typeof(readfile)   == "function"
       and typeof(makefolder) == "function" and typeof(isfile)     == "function"
       and typeof(isfolder)   == "function" and typeof(delfile)    == "function"
end

local function ensureDir()
    if not hasFS() then return false end
    pcall(function()
        if not isfolder("DJHub")  then makefolder("DJHub")  end
        if not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
    end)
    return isfolder(SAVE_DIR)
end

local function cfgPath(name)
    return ("%s/%s_%s.json"):format(SAVE_DIR, tostring(placeId), name:gsub("[^%w%-_]","_"))
end

function SaveSystem.save(name)
    if not ensureDir() then return false, "Filesystem not available" end
    local flags = {}
    local RF = _G.Rayfield
    if RF and RF.Flags then
        for flagName, flag in pairs(RF.Flags) do
            local val
            if     flag.CurrentOption  ~= nil then val = flag.CurrentOption
            elseif flag.CurrentKeybind ~= nil then val = flag.CurrentKeybind
            elseif flag.CurrentValue   ~= nil then val = flag.CurrentValue end
            local t = type(val)
            if t == "boolean" or t == "number" or t == "string" or t == "table" then
                flags[flagName] = val
            end
        end
    end
    local data = { version = VERSION, saved = os.time(), flags = flags }
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false, "Encoding failed" end
    local okw = pcall(function() writefile(cfgPath(name), json) end)
    return okw, okw and nil or "Write failed"
end

function SaveSystem.load(name)
    if not hasFS() then return false, "Filesystem not available" end
    local path = cfgPath(name)
    if not isfile(path) then return false, "File not found" end
    local okr, raw = pcall(readfile, path)
    if not okr or type(raw) ~= "string" then return false, "Read failed" end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" then return false, "Decode failed" end
    local RF = _G.Rayfield
    if data.flags and RF and RF.Flags then
        for flagName, val in pairs(data.flags) do
            local flag = RF.Flags[flagName]
            if flag and typeof(flag.Set) == "function" then
                pcall(function() flag:Set(val) end)
            end
        end
    end
    return true
end

function SaveSystem.delete(name)
    if not hasFS() then return false end
    local path = cfgPath(name)
    if isfile(path) then pcall(delfile, path) end
    return true
end

_G.saveSettings   = SaveSystem.save
_G.loadSettings   = SaveSystem.load
_G.deleteSettings = SaveSystem.delete

-- ================================================================
-- SHARED MODULE LADEN
-- ================================================================
print("[DJ HUB] Loading shared modules...")

local Utils  = loadFrom(SHARED_BASE, "dj_utils.lua")
if not Utils then warn("[DJ HUB] Utils failed") end

local UIBase = loadFrom(SHARED_BASE, "dj_ui_base.lua")
if not UIBase then error("[DJ HUB] FATAL: UI base failed to load") end

-- Fenster mit Game-Name + Footer
local Rayfield, Window = UIBase.createWindow({
    Name   = GAME.gameName,
    Footer = GAME.footer,
})
if not Rayfield or not Window then error("[DJ HUB] FATAL: Window could not be created") end
_G.Rayfield = Rayfield

-- Config-Objekt fuer alle Module
local Config = {
    api       = GAME.api,
    provider  = GAME.provider,
    service   = GAME.service,
    gameName  = GAME.gameName,
    footer    = GAME.footer,
    developer = GAME.developer,
    discord   = GAME.discord,
}

-- ================================================================
-- TABS NACH KEY-VERIFIZIERUNG
-- ================================================================
local function onKeyVerified()
    task.wait(0.2)
    print("[DJ HUB] Loading tabs...")

    -- Shared Home/Dashboard ZUERST
    local buildHome = loadFrom(SHARED_BASE, "dj_main.lua")
    if buildHome then
        local ok, err = pcall(buildHome, Window, Rayfield, Utils, Config)
        if not ok then warn("[DJ HUB] Home tab error: " .. tostring(err)) end
    end

    -- Game-spezifische Tabs (ingame/minigame)
    for _, entry in ipairs(GAME.tabs) do
        local build = loadFrom(GAME.repo, entry.file)
        if build then
            local ok, err = pcall(build, Window, Rayfield, Utils, Config)
            if ok then print("[DJ HUB] " .. entry.label .. " loaded")
            else warn("[DJ HUB] " .. entry.label .. " error: " .. tostring(err)) end
        else
            warn("[DJ HUB] Could not load: " .. entry.file)
        end
    end

    -- Shared Settings-Tab (ehemals Misc) IMMER zuletzt
    local buildSettings = loadFrom(SHARED_BASE, "dj_tab_settings.lua")
    if buildSettings then
        local ok, err = pcall(buildSettings, Window, Rayfield, Utils, Config)
        if not ok then warn("[DJ HUB] Settings tab error: " .. tostring(err)) end
    end

    Rayfield:Notify({
        Title   = "DJ HUB Ready!",
        Content = GAME.gameName .. " loaded!\nDiscord: " .. GAME.discord,
        Duration = 6,
    })

    task.delay(10, function()
        pcall(function()
            if Rayfield and typeof(Rayfield.DiscordPrompt) == "function" then
                Rayfield:DiscordPrompt({ Invite = GAME.discord })
            end
        end)
    end)

    print("[DJ HUB] All tabs loaded.")
end

-- ================================================================
-- KEY SYSTEM (shared)
-- ================================================================
local buildKey = loadFrom(SHARED_BASE, "dj_tab_key.lua")
if buildKey then
    local ok, err = pcall(buildKey, Window, Rayfield, Utils, Config, onKeyVerified)
    if not ok then
        warn("[DJ HUB] Key tab error: " .. tostring(err))
        onKeyVerified()
    end
else
    warn("[DJ HUB] Key tab failed — skipping key check")
    onKeyVerified()
end

print("[DJ HUB] Loader complete v" .. VERSION)
