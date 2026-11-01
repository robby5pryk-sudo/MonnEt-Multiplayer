-- ███╗   ███╗███████╗      ███╗   ███╗██████╗ 
-- ████╗ ████║██╔════╝      ████╗ ████║██╔══██╗
-- ██╔████╔██║█████╗  █████╗██╔████╔██║██████╔╝
-- ██║╚██╔╝██║██╔══╝  ╚════╝██║╚██╔╝██║██╔═══╝ 
-- ██║ ╚═╝ ██║███████╗      ██║ ╚═╝ ██║██║     
-- ╚═╝     ╚═╝╚══════╝      ╚═╝     ╚═╝╚═╝
-- Hello developers, I am handing this project over to you, as I likely won’t be continuing with it myself—feel free to work on it however you like.
-- But I’m not stopping this project 100% here; I’ll update the code later when I have some time.
-- visit my official website: https://afreldocommunity.vercel.app
-- Made with love

script_name("MonnEt")
script_author("Afreldo")
script_version("1.0")

local imgui = require 'mimgui'
local ffi   = require 'ffi'
local bit   = require 'bit'
local new, str = imgui.new, ffi.string
local ImVec2, ImVec4 = imgui.ImVec2, imgui.ImVec4

local okEffil, effil = pcall(require, 'effil')
if not okEffil then okEffil, effil = pcall(require, 'lib.effil') end
local HAS_EFFIL = okEffil and type(effil) == 'table' and effil.channel ~= nil and effil.thread ~= nil

local okReq, requestsLib = pcall(require, 'requests')
if not okReq then okReq, requestsLib = pcall(require, 'lib.requests') end

local okEv, sampev = pcall(require, 'lib.samp.events')
if not okEv then okEv, sampev = pcall(require, 'samp.events') end
local HAS_SYNC = okEv and sampev ~= nil

local okSocket, socketLib = pcall(require, 'socket')
local okSsl, sslLib = pcall(require, 'ssl')
local HAS_FASTHTTP = okSocket and okSsl
local HAS_STREAM = HAS_EFFIL and HAS_FASTHTTP

local clk = (type(getGameTimer) == 'function') and function() return getGameTimer() / 1000 end or os.clock

local IS_ANDROID = (rawget(_G, 'MONET_VERSION') ~= nil) or (jit ~= nil and jit.os ~= 'Windows')

local DISCORD_URL   = "https://discord.gg/R5pXKg9FQN"
local DEFAULT_DB    = "https://monnetmultiplayer.app (yourfirebasedatabase)"
local HEARTBEAT     = 30
local TIMEOUT       = 90
local POLL_CHAT     = 0.8
local POLL_LIST     = 5
local CHAT_COOLDOWN = 2
local LOCAL_COOLDOWN= 0.6
local MAX_MSG_LEN   = 100
local LIVE_SEND     = 0.1
local LIVE_POLL     = 0.15
local GHOST_STALE   = 6

if not HAS_EFFIL or not HAS_FASTHTTP then
    POLL_CHAT = HAS_FASTHTTP and 1.5 or 3
    POLL_LIST = HAS_FASTHTTP and 5 or 8
    LIVE_SEND = HAS_FASTHTTP and 0.2 or 0.4
    LIVE_POLL = HAS_FASTHTTP and 0.25 or 0.5
    GHOST_STALE = HAS_FASTHTTP and 7 or 9
end

local RULES = [[{
  "rules": {
    "players": { ".read": true, "$nick": { ".write": true } },
    "chat":    { ".read": true, ".write": true },
    "live":    { ".read": true, "$nick": { ".write": true } }
  }
}]]

local defaults = {
    enabled     = true,
    shareMe     = true,
    seeOthers   = true,
    nametags    = true,
    localChat   = true,
    globalChat  = true,
    bubbles     = true,
    chatToLog   = false,
    useCustomDb = false,
    customUrl   = "",
    renderDist  = 200,
    chatRange   = 20,
    feedY       = 38,
    scale       = 1.0,
    smoothT     = 0.12,
    lang        = "id",
}
local cfg, dirty = {}, false

local function cfgPaths()
    local dir = getWorkingDirectory() .. "/config"
    return dir, dir .. "/monnet.json"
end

local function loadCfg()
    for k, v in pairs(defaults) do cfg[k] = v end
    pcall(function()
        local _, file = cfgPaths()
        local f = io.open(file, "r")
        if not f then return end
        local txt = f:read("*a")
        f:close()
        local data = decodeJson(txt)
        if type(data) == 'table' then
            for k, v in pairs(defaults) do
                if type(data[k]) == type(v) then cfg[k] = data[k] end
            end
        end
    end)
    if cfg.lang ~= "id" and cfg.lang ~= "en" then cfg.lang = "id" end
end

local function saveCfg()
    pcall(function()
        local dir, file = cfgPaths()
        if doesDirectoryExist and not doesDirectoryExist(dir) then createDirectory(dir) end
        local f = io.open(file, "w")
        if f then f:write(encodeJson(cfg)); f:close() end
    end)
end

loadCfg()

local LANG = {
    id = {
        toast_fast = "MonnEt nyala  -  /monnet.settings",
        toast_slow = "MonnEt nyala",
        toast_fb = "MonnEt nyala",
        toast_nolib = "MonnEt: library 'requests' ga ketemu",
        chat_nolib = "{F87171}[ERROR|MonnEt] effil sama requests ga ada, psng dulu",
        gc_off = "Chat global mati",
        gc_usage = "Pake: /gc <pesan>",
        gc_wait = "dilarang spam",
        gc_invalid = "Pesannya ada karakter yang ga valid",
        no_ghost = "Pemain itu belum keliatan di dunia lu",
        marked = "%s - %.0f m. Lokasinya udah ditandain di peta",
        gfind_off = "Fitur liat pemain lain lagi mati",
        gfind_none = "Pemain ga ketemu",
        rules_copied = "Rules udah disalin",
        log_global = "{F5A524}[Global] {FFFFFF}%s {AAAAAA}(%s){FFFFFF}: %s",
        log_local = "{FFFFFF}%s {AAAAAA}(lokal){FFFFFF}: %s",
        tag_global = "Global",
        tag_local = "Lokal",
        err_conn = "Ga bisa konek",
        err_rules = "Rules belum diatur",
        err_db = "Error database",
        st_off = "Mati",
        st_ok = "Nyambung",
        st_wait = "Nyambungin...",
        nav_players = "Pemain",
        nav_chat = "Chat",
        nav_settings = "Pengaturan",
        nav_database = "Database",
        nav_about = "Tentang",
        players_t = "Pemain",
        players_sub = "%d online  -  %d keliatan di duniamu",
        players_none = "Belum ada pemain lain yang online",
        you = "Kamu",
        skin = "Skin %d",
        chat_t = "Chat",
        chat_sub = "Riwayat chat global dan lokal",
        chat_none = "Belum ada pesan",
        send = "Kirim",
        set_t = "Pengaturan",
        set_sub = "tersimpan otomatis otomatis",
        sec_general = "Umum",
        sec_multi = "Multiplayer",
        sec_chat = "Chat",
        sec_display = "Tampilan",
        enable = "Nyalain MonnEt",
        enable_d = "Matiin buat ngehentiin semua fitur",
        share = "Bagiin posisiku",
        share_d = "Pemain lain bisa liat karaktermu",
        see = "Tampilin pemain lain",
        see_d = "Pemain dari server lain muncul di duniamu",
        tags = "Nametag",
        tags_d = "Nama di atas kepala pemain",
        rdist = "Jarak tampil pemain",
        lchat = "Chat lokal",
        lchat_d = "Chat biasa cuma keliatan sama pemain di sekitar",
        gchat = "Chat global",
        gchat_d = "Kirim dan terima lewat /gc",
        bubbles = "Bubble chat",
        bubbles_d = "Pesan muncul di atas kepala pemain",
        tolog = "Tampilin di chatlog",
        tolog_d = "Salin chat MonnEt ke chatlog game",
        crange = "Jangkauan chat lokal",
        feedy = "Posisi chat overlay",
        scale = "Ukuran tampilan",
        smooth = "Kehalusan gerakan",
        smooth_d = "Makin gede makin halus, tapi gerakan agak telat nyusul",
        lang_t = "Bahasa",
        lang_d = "Pilih bahasa buat menu dan notifikasi",
        no_samp = "Chat lokal butuh SAMP.Lua (samp.events) tapi ga ketemu.",
        db_t = "Database",
        db_sub = "Tempat data pemain sama chat disimpen",
        db_active = "DATABASE AKTIF",
        db_custom = "Custom",
        db_default = "Default MonnEt",
        usedb = "Pakai database sendiri",
        usedb_d = "Pakai Firebase Realtime Database punyamu",
        db_url = "URL Realtime Database",
        save_apply = "Simpan & Terapin",
        saved = "Kesimpen",
        url_bad = "URL ga valid",
        url_ex = "Contoh: https://nama-project-default-rtdb.firebaseio.com",
        test = "Tes Koneksi",
        testing = "Lagi ngetes...",
        test_conn = "Gagal: ga bisa konek (cek URL, internet, library SSL)",
        test_rules = "Gagal: rules belum diatur",
        test_url = "Gagal: URL database salah",
        test_ok = "Database nyambung",
        rules_t = "Rules Firebase",
        rules_d = "Console > Realtime Database > Rules, tempel terus Publish",
        copy_rules = "Salin Rules",
        about_t = "Tentang",
        about_sub = "MonnEt Multiplayer %s  -  %s",
        cmds = "Perintah",
        cmd1 = "/monnet.settings   buka menu ini",
        cmd2 = "/gc <pesan>        chat global ke semua pemain MonnEt",
        cmd3 = "/gfind <nick>      tandain pemain di peta",
        cmd4 = "Chat biasa tanpa /  jadi chat lokal buat pemain di sekitar",
        priv_t = "Privasi",
        credit_t = "Dibuat oleh",
        copy_link = "Salin Link Discord",
        link_copied = "Link Discord udah disalin",
        priv = "Pas 'Bagiin posisiku' nyala, nick, skin, server, sama koordinatmu dikirim ke database yang dipilih. Chat biasa yang kamu ketik (bukan perintah) juga ikut dikirim kalau 'Chat lokal' nyala. Jangan ngetik data pribadi di chat. Semuanya bisa dimatiin di Pengaturan.",
    },
    en = {
        toast_fast = "MonnEt on  -  /monnet.settings",
        toast_slow = "MonnEt on",
        toast_fb = "MonnEt on",
        toast_nolib = "MonnEt: 'requests' library not found",
        chat_nolib = "{F87171}[MonnEt] effil and requests are missing, online features can't run.",
        gc_off = "Global chat is off",
        gc_usage = "Use: /gc <message>",
        gc_wait = "Chill for a sec, no spamming",
        gc_invalid = "Your message has invalid characters",
        no_ghost = "That player isn't visible in your world yet",
        marked = "%s - %.0f m. Location marked on the map",
        gfind_off = "See-other-players is turned off",
        gfind_none = "Player not found",
        rules_copied = "Rules copied",
        log_global = "{F5A524}[Global] {FFFFFF}%s {AAAAAA}(%s){FFFFFF}: %s",
        log_local = "{FFFFFF}%s {AAAAAA}(local){FFFFFF}: %s",
        tag_global = "Global",
        tag_local = "Local",
        err_conn = "Can't connect",
        err_rules = "Rules not set yet",
        err_db = "Database error",
        st_off = "Off",
        st_ok = "Connected",
        st_wait = "Connecting",
        nav_players = "Players",
        nav_chat = "Chat",
        nav_settings = "Settings",
        nav_database = "Database",
        nav_about = "About",
        players_t = "Players",
        players_sub = "%d online  -  %d visible in your world",
        players_none = "No other players online yet",
        you = "You",
        skin = "Skin %d",
        chat_t = "Chat",
        chat_sub = "Global and local chat history",
        chat_none = "No messages yet",
        send = "Send",
        set_t = "Settings",
        set_sub = "Saved automatically and restored when you join",
        sec_general = "General",
        sec_multi = "Multiplayer",
        sec_chat = "Chat",
        sec_display = "Display",
        enable = "Enable MonnEt",
        enable_d = "Turn off to stop every feature",
        share = "Share my position",
        share_d = "Other players can see your character",
        see = "Show other players",
        see_d = "Players from other servers show up in your world",
        tags = "Nametag",
        tags_d = "Name above players' heads",
        rdist = "Player render distance",
        lchat = "Local chat",
        lchat_d = "Normal chat is only seen by nearby players",
        gchat = "Global chat",
        gchat_d = "Send and receive through /gc",
        bubbles = "Chat bubbles",
        bubbles_d = "Messages pop up above players' heads",
        tolog = "Show in chatlog",
        tolog_d = "Copy MonnEt chat into the game chatlog",
        crange = "Local chat range",
        feedy = "Chat overlay position",
        scale = "Interface size",
        smooth = "Movement smoothness",
        smooth_d = "Higher is smoother, but movement trails a bit more",
        lang_t = "Language",
        lang_d = "Pick the language for menus and notifications",
        no_samp = "Local chat needs SAMP.Lua (samp.events) but it wasn't found.",
        db_t = "Database",
        db_sub = "Where player and chat data is stored",
        db_active = "ACTIVE DATABASE",
        db_custom = "Custom",
        db_default = "MonnEt Default",
        usedb = "Use your own database",
        usedb_d = "Use your own Firebase Realtime Database",
        db_url = "Realtime Database URL",
        save_apply = "Save & Apply",
        saved = "Saved",
        url_bad = "Invalid URL",
        url_ex = "Example: https://project-name-default-rtdb.firebaseio.com",
        test = "Test Connection",
        testing = "Testing...",
        test_conn = "Failed: can't connect (check URL, internet, SSL library)",
        test_rules = "Failed: rules aren't set",
        test_url = "Failed: wrong database URL",
        test_ok = "Database connected",
        rules_t = "Firebase Rules",
        rules_d = "Console > Realtime Database > Rules, paste then Publish",
        copy_rules = "Copy Rules",
        about_t = "About",
        about_sub = "MonnEt Multiplayer %s  -  %s",
        cmds = "Commands",
        cmd1 = "/monnet.settings   open this menu",
        cmd2 = "/gc <message>      global chat to every MonnEt player",
        cmd3 = "/gfind <nick>      mark a player on the map",
        cmd4 = "Normal chat without /  becomes local chat for nearby players",
        priv_t = "Privacy",
        credit_t = "Made by",
        copy_link = "Copy Discord Link",
        link_copied = "Discord link copied",
        priv = "While 'Share my position' is on, your nick, skin, server, and coordinates are sent to the selected database. Normal chat you type (not commands) is also sent when 'Local chat' is on. Don't type personal info in chat. You can turn everything off in Settings.",
    },
}

local function L(k, ...)
    local t = LANG[cfg.lang] or LANG.id
    local s = t[k] or LANG.id[k] or k
    if select('#', ...) > 0 then return string.format(s, ...) end
    return s
end

local lastKey, chatInited, polling, pollStart = nil, false, false, 0
local lastSendGlobal, lastSendLocal = 0, 0
local ghosts = {}
local livePolling, livePollStart, liveSeq = false, 0, 0
local liveBusy, liveBusyT = false, 0
local sessionId = os.time()
local prevPos, findBlip = nil, nil
local onlineList = {}
local lastOk, lastErr = -1e9, nil
local feed, feedSeq, bubbles, toasts = {}, 0, {}, {}
local liveData, streamUp = {}, false

local function say(text) sampAddChatMessage(text, -1) end
local function safeKey(s) return (tostring(s):gsub("[%.%$#%[%]/]", "_")) end
local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
local function round1(v) return math.floor(v * 10 + 0.5) / 10 end
local function clamp(v, lim) return math.max(-lim, math.min(lim, v)) end
local function clamp01(v) return math.max(0, math.min(1, v)) end

local function cleanText(s, maxLen)
    s = tostring(s or ""):gsub("{%x%x%x%x%x%x}", "")
    return s:sub(1, maxLen or MAX_MSG_LEN)
end

local function validUrl(u)
    u = tostring(u or "")
    return u:match("^https://[%w%-%.]+$") ~= nil and u:find("firebase", 1, true) ~= nil
end

local function getDB()
    if cfg.useCustomDb and validUrl(cfg.customUrl) then return cfg.customUrl end
    return DEFAULT_DB
end

local function myNick()
    local ok, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if ok then return sampGetPlayerNickname(id) end
    return nil
end

local function mySkin()
    local ok, m = pcall(getCharModel, PLAYER_PED)
    if ok and type(m) == 'number' then return m end
    return 0
end

local function myInterior()
    local ok, i = pcall(getActiveInterior)
    if ok and type(i) == 'number' then return i end
    return 0
end

local function serverName()
    return cleanText(sampGetCurrentServerName() or "?", 60)
end

local function notify(text, kind)
    toasts[#toasts + 1] = { text = text, kind = kind or "info", t = clk() }
    while #toasts > 4 do table.remove(toasts, 1) end
end

local function addFeed(m)
    m.t = clk()
    feed[#feed + 1] = m
    feedSeq = feedSeq + 1
    while #feed > 60 do table.remove(feed, 1) end
    if cfg.chatToLog then
        if m.global then
            say(L("log_global", m.nick, m.server, m.text))
        else
            say(L("log_local", m.nick, m.text))
        end
    end
end

local HTTP_SRC = [==[
local socket, ssl = ...
local conn = { sock = nil, host = nil }

local function closeConn()
    if conn.sock then pcall(function() conn.sock:close() end) end
    conn.sock, conn.host = nil, nil
end

local function openConn(host)
    closeConn()
    local raw = socket.tcp()
    raw:settimeout(8)
    if not raw:connect(host, 443) then pcall(function() raw:close() end); return false end
    local tls = ssl.wrap(raw, { mode = "client", protocol = "any", verify = "none", options = "all", servername = host })
    if not tls then pcall(function() raw:close() end); return false end
    tls:settimeout(8)
    if not tls:dohandshake() then pcall(function() tls:close() end); return false end
    conn.sock, conn.host = tls, host
    return true
end

local function readResponse(sock)
    local status = sock:receive("*l")
    if not status then return nil end
    local code = tonumber(status:match("^HTTP/%S+%s+(%d+)")) or 0
    local headers = {}
    while true do
        local line = sock:receive("*l")
        if not line then return nil end
        if line == "" then break end
        local k, v = line:match("^([^:]+):%s*(.-)%s*$")
        if k then headers[k:lower()] = v end
    end
    local keepAlive = not (headers["connection"] and headers["connection"]:lower():find("close", 1, true))
    local body = ""
    local te = headers["transfer-encoding"]
    local noBody = (code == 204 or code == 304 or (code >= 100 and code < 200))
    if noBody then
        body = ""
    elseif te and te:lower():find("chunked", 1, true) then
        local parts = {}
        while true do
            local sizeLine = sock:receive("*l")
            if not sizeLine then return nil end
            local size = tonumber(sizeLine:match("^(%x+)"), 16)
            if not size then return nil end
            if size == 0 then
                sock:receive("*l")
                break
            end
            local chunk = sock:receive(size)
            if not chunk then return nil end
            parts[#parts + 1] = chunk
            sock:receive("*l")
        end
        body = table.concat(parts)
    else
        local len = tonumber(headers["content-length"])
        if len then
            if len > 0 then
                local b = sock:receive(len)
                if not b then return nil end
                body = b
            end
        else
            local all, err, partial = sock:receive("*a")
            body = all or partial or ""
            keepAlive = false
        end
    end
    return body, keepAlive
end

local function request(method, url, bodyStr)
    local host, path = url:match("^https://([^/]+)(/.*)$")
    if not host then
        host = url:match("^https://([^/]+)$")
        path = "/"
    end
    if not host then return nil end
    local payload = bodyStr or ""
    for attempt = 1, 2 do
        if (not conn.sock) or conn.host ~= host then
            if not openConn(host) then
                closeConn()
                return nil
            end
        end
        local req = string.format(
            "%s %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: MonnEt/1.0\r\nAccept: */*\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: keep-alive\r\n\r\n%s",
            method, path, host, #payload, payload)
        local sendOk = pcall(function() conn.sock:send(req) end)
        if sendOk then
            local body, keepAlive = readResponse(conn.sock)
            if body ~= nil then
                if not keepAlive then closeConn() end
                return body
            end
        end
        closeConn()
    end
    return nil
end

return { request = request, close = closeConn }
]==]

local function workerFn(jobs, results, src)
    local okS, socket = pcall(require, 'socket')
    local okX, ssl = pcall(require, 'ssl')
    local client
    if okS and okX then
        local okL, mk = pcall(load, src)
        if okL and mk then
            local okC, c = pcall(mk, socket, ssl)
            if okC then client = c end
        end
    end
    local requests

    while true do
        local job = jobs:pop()
        if job.stop then
            if client then client.close() end
            return
        end
        local text = nil
        if client then
            text = client.request(job.method, job.url, job.body ~= "" and job.body or nil)
        else
            if not requests then
                local okR, r = pcall(require, 'requests')
                if okR then requests = r end
            end
            if requests then
                local args = {}
                if job.body ~= "" then args.data = job.body end
                local ok, res = pcall(requests.request, job.method, job.url, args)
                if ok and res then text = res.text end
            end
        end
        results:push({ id = job.id, text = text or "", ok = (text ~= nil) })
    end
end

local function streamFn(ctl, results)
    local okS, socket = pcall(require, 'socket')
    local okX, ssl = pcall(require, 'ssl')
    if not (okS and okX) then return end

    local sock, url = nil, nil
    local raw, body, state, chunked = "", "", "idle", false
    local lastData = socket.gettime()

    local function closeS()
        if sock then pcall(function() sock:close() end) end
        sock, raw, body, state = nil, "", "", "idle"
    end

    local function open()
        closeS()
        local host, path = url:match("^https://([^/]+)(/.*)$")
        if not host then return false end
        local r = socket.tcp()
        r:settimeout(8)
        if not r:connect(host, 443) then pcall(function() r:close() end); return false end
        local t = ssl.wrap(r, { mode = "client", protocol = "any", verify = "none", options = "all", servername = host })
        if not t then pcall(function() r:close() end); return false end
        t:settimeout(8)
        if not t:dohandshake() then pcall(function() t:close() end); return false end
        local req = "GET " .. path .. " HTTP/1.1\r\nHost: " .. host ..
            "\r\nUser-Agent: MonnEt/1.0\r\nAccept: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"
        local okSend = pcall(function() t:send(req) end)
        if not okSend then pcall(function() t:close() end); return false end
        t:settimeout(0.3)
        sock, state = t, "header"
        lastData = socket.gettime()
        return true
    end

    local function process()
        if state == "header" then
            local s, e = raw:find("\r\n\r\n", 1, true)
            if not s then return end
            local headRaw = raw:sub(1, s - 1)
            local head = headRaw:lower()
            raw = raw:sub(e + 1)
            local code = tonumber(head:match("^http/%S+%s+(%d+)"))
            if code == 307 or code == 302 or code == 301 then
                local loc = headRaw:match("[Ll]ocation:%s*(%S+)")
                closeS()
                if loc then url = loc end
                return
            end
            if code ~= 200 then
                closeS()
                results:push({ id = 0, ev = "down" })
                return
            end
            chunked = head:find("transfer-encoding: chunked", 1, true) ~= nil
            state = "body"
        end
        if state == "body" then
            if chunked then
                while true do
                    local s, e = raw:find("\r\n", 1, true)
                    if not s then break end
                    local size = tonumber(raw:sub(1, s - 1):match("^(%x+)"), 16)
                    if not size then
                        closeS()
                        results:push({ id = 0, ev = "down" })
                        return
                    end
                    if size == 0 then
                        closeS()
                        results:push({ id = 0, ev = "down" })
                        return
                    end
                    if #raw < e + size + 2 then break end
                    body = body .. raw:sub(e + 1, e + size)
                    raw = raw:sub(e + size + 3)
                end
            else
                body = body .. raw
                raw = ""
            end
            body = (body:gsub("\r", ""))
            while true do
                local s, e = body:find("\n\n", 1, true)
                if not s then break end
                local blk = body:sub(1, s - 1)
                body = body:sub(e + 1)
                local ev = blk:match("event:%s*([^\n]+)")
                local d = blk:match("data:%s*([^\n]*)")
                if ev == "put" or ev == "patch" then
                    if d then results:push({ id = 0, ev = ev, text = d }) end
                elseif ev == "cancel" or ev == "auth_revoked" then
                    closeS()
                    results:push({ id = 0, ev = "down" })
                    return
                end
            end
        end
    end

    local function handle(msg)
        if msg.stop then closeS(); return true end
        if msg.url ~= nil then
            url = (msg.url ~= "") and msg.url or nil
            closeS()
        end
        return false
    end

    while true do
        local msg = ctl:pop(0)
        while msg do
            if handle(msg) then return end
            msg = ctl:pop(0)
        end

        if not url then
            local m = ctl:pop(0.3)
            if m and handle(m) then return end
        elseif not sock then
            if open() then
                results:push({ id = 0, ev = "up" })
            else
                results:push({ id = 0, ev = "down" })
                local m = ctl:pop(2)
                if m and handle(m) then return end
            end
        else
            local data, err, partial = sock:receive(8192)
            local got = data or partial
            if got and got ~= "" then
                lastData = socket.gettime()
                raw = raw .. got
                process()
            end
            if sock then
                if err and err ~= "timeout" and err ~= "wantread" then
                    closeS()
                    results:push({ id = 0, ev = "down" })
                elseif socket.gettime() - lastData > 45 then
                    closeS()
                    results:push({ id = 0, ev = "down" })
                end
            end
        end
    end
end

local callbacks, nextId = {}, 0
local jobs, results
local workers = {}
local queue = {}
local streamCtl, streamThread, streamUrl = nil, nil, nil
local fbClient = nil

if HAS_EFFIL then
    jobs, results = effil.channel(), effil.channel()
end

local function syncStream()
    if not HAS_STREAM or not streamCtl then return end
    local want = nil
    if cfg.enabled and cfg.seeOthers then want = getDB() .. "/live.json" end
    if want ~= streamUrl then
        streamUrl = want
        streamCtl:push({ url = want or "" })
        streamUp = false
    end
end

local function startWorkers()
    if not HAS_EFFIL then return end
    for i = 1, 3 do workers[i] = effil.thread(workerFn)(jobs, results, HTTP_SRC) end
    if HAS_STREAM then
        streamCtl = effil.channel()
        streamThread = effil.thread(streamFn)(streamCtl, results)
        syncStream()
    end
end

local function http(method, url, body, cb)
    if HAS_EFFIL then
        nextId = nextId + 1
        if cb then callbacks[nextId] = cb end
        jobs:push({ id = nextId, method = method, url = url, body = body or "" })
        return
    end

    if not okReq and not HAS_FASTHTTP then
        if cb then pcall(cb, nil) end
        return
    end
    local job = { method = method, url = url, body = body or "", cb = cb }
    if method ~= 'POST' and method ~= 'DELETE' then
        for i = 1, #queue do
            if queue[i].method == method and queue[i].url == url then
                queue[i] = job
                return
            end
        end
    end
    queue[#queue + 1] = job
    while #queue > 25 do table.remove(queue, 1) end
end

local function fallbackLoop()
    if HAS_FASTHTTP then
        local okL, mk = pcall(load, HTTP_SRC)
        if okL and mk then
            local okC, c = pcall(mk, socketLib, sslLib)
            if okC then fbClient = c end
        end
    end
    while true do
        local job = table.remove(queue, 1)
        if job then
            local text = nil
            if fbClient then
                text = fbClient.request(job.method, job.url, job.body ~= "" and job.body or nil)
            elseif okReq then
                local args = { timeout = 6 }
                if job.body ~= "" then args.data = job.body end
                local ok, res = pcall(requestsLib.request, job.method, job.url, args)
                if ok and res then text = res.text end
            end
            if job.cb then pcall(job.cb, text) end
            wait(15)
        else
            wait(50)
        end
    end
end

local function mark(resp)
    if not resp then lastErr = "err_conn"; return false end
    if resp:find('"error"', 1, true) then
        lastErr = resp:find("Permission", 1, true) and "err_rules" or "err_db"
        return false
    end
    lastOk, lastErr = clk(), nil
    return true
end

local function removeSelfAt(db)
    local nick = myNick()
    if not nick then return end
    http('DELETE', db .. "/players/" .. safeKey(nick) .. ".json")
    http('DELETE', db .. "/live/" .. safeKey(nick) .. ".json")
end

local function removeGhostPed(g)
    if g.ped then
        if doesCharExist(g.ped) then deleteChar(g.ped) end
        g.ped = nil
    end
    g.state, g.anim, g.animSpd = nil, nil, nil
end

local function removeGhost(nick)
    local g = ghosts[nick]
    if g then removeGhostPed(g) end
    ghosts[nick] = nil
end

local function clearAllGhosts()
    for nick in pairs(ghosts) do removeGhost(nick) end
    liveData = {}
end

local function countGhosts()
    local n = 0
    for _ in pairs(ghosts) do n = n + 1 end
    return n
end

local function chatActive() return cfg.enabled and (cfg.globalChat or cfg.localChat) end

local function applyState()
    if not (cfg.enabled and cfg.seeOthers) then clearAllGhosts() end
    if not (cfg.enabled and cfg.shareMe) then
        removeSelfAt(getDB())
        prevPos = nil
    end
    if not chatActive() then lastKey, chatInited = nil, false end
    if not cfg.enabled then bubbles = {} end
    syncStream()
end

local function switchDb(oldDb)
    clearAllGhosts()
    lastKey, chatInited = nil, false
    onlineList = {}
    lastOk = -1e9
    if oldDb and oldDb ~= getDB() then removeSelfAt(oldDb) end
    syncStream()
end

local function sendHeartbeat()
    local nick = myNick()
    if not nick then return end
    local ip, port = sampGetCurrentServerAddress()
    local ok, body = pcall(encodeJson, {
        nick = nick, skin = mySkin(), server = serverName(),
        addr = string.format("%s:%d", ip, port), last = os.time()
    })
    if not ok then return end
    http('PUT', getDB() .. "/players/" .. safeKey(nick) .. ".json?print=silent", body, mark)
end

local function pollList()
    http('GET', getDB() .. "/players.json", nil, function(resp)
        if not mark(resp) then return end
        local data = decodeJson(resp)
        local list, now = {}, os.time()
        if type(data) == 'table' then
            for _, p in pairs(data) do
                if type(p) == 'table' and p.nick and tonumber(p.last)
                   and (now - tonumber(p.last)) <= TIMEOUT then
                    list[#list + 1] = p
                end
            end
        end
        table.sort(list, function(a, b)
            return tostring(a.nick):lower() < tostring(b.nick):lower()
        end)
        onlineList = list
    end)
end

local function sendGlobal(text)
    if not (cfg.enabled and cfg.globalChat) then
        notify(L("gc_off"), "warn")
        return
    end
    text = trim(text or "")
    if text == "" then
        notify(L("gc_usage"), "info")
        return
    end
    local now = clk()
    if now - lastSendGlobal < CHAT_COOLDOWN then
        notify(L("gc_wait"), "warn")
        return
    end
    local nick = myNick()
    if not nick then return end
    lastSendGlobal = now
    local clean = cleanText(text)
    local ok, body = pcall(encodeJson, {
        nick = nick, skin = mySkin(), msg = clean,
        server = serverName(), t = os.time(), m = 0
    })
    if not ok then
        notify(L("gc_invalid"), "error")
        return
    end
    http('POST', getDB() .. "/chat.json", body, mark)
    addFeed({ nick = nick, text = clean, global = true, server = serverName(), own = true })
end

local function sendLocal(text)
    if not (cfg.enabled and cfg.localChat and cfg.shareMe) then return end
    if type(text) ~= 'string' or text == "" or text:sub(1, 1) == "/" then return end
    local now = clk()
    if now - lastSendLocal < LOCAL_COOLDOWN then return end
    local nick = myNick()
    if not nick then return end
    lastSendLocal = now
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local ok, body = pcall(encodeJson, {
        nick = nick, skin = mySkin(), msg = cleanText(text),
        server = serverName(), t = os.time(), m = 1,
        x = round1(x), y = round1(y), z = round1(z), i = myInterior()
    })
    if not ok then return end
    http('POST', getDB() .. "/chat.json", body, mark)
end

local function handleIncoming(m)
    local me = myNick()
    local nick = cleanText(m.nick, 24)
    if nick == "" or m.nick == me then return end
    local text = cleanText(m.msg)
    if text == "" then return end

    if (tonumber(m.m) or 0) == 1 then
        if not cfg.localChat then return end
        local x, y, z = tonumber(m.x), tonumber(m.y), tonumber(m.z)
        if not (x and y and z) then return end
        if (tonumber(m.i) or 0) ~= myInterior() then return end
        local mx, my, mz = getCharCoordinates(PLAYER_PED)
        if getDistanceBetweenCoords3d(mx, my, mz, x, y, z) > cfg.chatRange then return end
        addFeed({ nick = nick, text = text, global = false, server = cleanText(m.server, 40) })
        if cfg.bubbles then
            bubbles[tostring(m.nick)] = { text = text, t = clk(),
                dur = math.min(10, 4 + #text * 0.05) }
        end
    else
        if not cfg.globalChat then return end
        addFeed({ nick = nick, text = text, global = true, server = cleanText(m.server, 40) })
    end
end

local function pollChat()
    if polling and clk() - pollStart < 10 then return end
    polling, pollStart = true, clk()

    local url = getDB() .. '/chat.json?orderBy=%22$key%22'
    if lastKey then
        url = url .. '&startAt=%22' .. lastKey .. '%22'
    elseif not chatInited then
        url = url .. '&limitToLast=1'
    end

    http('GET', url, nil, function(resp)
        polling = false
        if not mark(resp) then return end
        local firstLoad = not chatInited
        chatInited = true
        local data = decodeJson(resp)
        if type(data) ~= 'table' then return end
        local keys = {}
        for k in pairs(data) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            if k ~= lastKey then
                local m = data[k]
                if not firstLoad and type(m) == 'table' then pcall(handleIncoming, m) end
                lastKey = k
            end
        end
    end)
end

-- Tangkap data sync asli SAMP (keysData) buat deteksi lompat yang instan,
-- kayak cara client SAMP baca tombol pemain lokal.
local airLatch = false
local lastKeys = 0

if HAS_SYNC then
    function sampev.onSendChat(message)
        pcall(sendLocal, message)
    end

    function sampev.onSendPlayerSync(data)
        local k = data.keysData or 0
        if bit.band(k, 32) ~= 0 and bit.band(lastKeys, 32) == 0 then
            local ok, inCar = pcall(isCharInAnyCar, PLAYER_PED)
            if not (ok and inCar) then airLatch = true end
        end
        lastKeys = k
    end
end

local lastLiveSent, wasMoving, lastAirSent = 0, false, false
local pend, liveMeta = {}, {}

-- Ambil sampel posisi tiap 0.1 detik (10 Hz) dan numpuk di antrian.
-- Antrian dikirim sekaligus per paket, jadi walau koneksi lambat gerakannya tetap lengkap.
local function sampleLive()
    local now = clk()
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local vx, vy, spd = 0, 0, 0

    -- kecepatan asli dari game (satuan per tick 1/50 detik -> m/s)
    local okv, ax, ay = pcall(getCharVelocity, PLAYER_PED)
    if okv and type(ax) == 'number' and type(ay) == 'number' then
        vx, vy = ax * 50, ay * 50
        spd = math.sqrt(vx * vx + vy * vy)
    end
    -- cadangan kalau nilainya ga masuk akal: pakai selisih posisi
    if prevPos and (spd > 14 or spd ~= spd) then
        local dt = now - prevPos.t
        if dt > 0 then
            vx, vy = (x - prevPos.x) / dt, (y - prevPos.y) / dt
            spd = math.sqrt(vx * vx + vy * vy)
        end
    end
    prevPos = { x = x, y = y, z = z, t = now }
    if spd ~= spd then spd, vx, vy = 0, 0, 0 end
    if spd > 12 then
        local k = 12 / spd
        vx, vy, spd = vx * k, vy * k, 12
    end

    local air = airLatch
    airLatch = false
    local moving = spd > 0.25
    if not moving then vx, vy = 0, 0 end

    -- lagi diam: cukup 1 sampel tiap 1.5 detik
    if (not moving) and (not wasMoving) and (not air) and (now - lastLiveSent) < 1.5 then
        return
    end
    wasMoving, lastLiveSent = moving, now

    pend[#pend + 1] = string.format("%.3f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%d",
        now, x, y, z, getCharHeading(PLAYER_PED), spd, vx, vy, air and 1 or 0)
    while #pend > 30 do table.remove(pend, 1) end
    liveMeta = {
        k = mySkin(), i = myInterior(),
        c = isCharInAnyCar(PLAYER_PED) and 1 or 0,
    }
end

local function sendLive()
    local nick = myNick()
    if not nick then return end
    local now = clk()
    if liveBusy and now - liveBusyT < 1.5 then return end
    if #pend == 0 or not liveMeta.k then return end

    local sent = pend
    pend = {}
    local tm, x, y, z, h, v, vx, vy = sent[#sent]:match(
        "^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")

    liveSeq = liveSeq + 1
    local ok, body = pcall(encodeJson, {
        n = nick, k = liveMeta.k, i = liveMeta.i, c = liveMeta.c,
        x = tonumber(x), y = tonumber(y), z = tonumber(z), h = tonumber(h),
        v = tonumber(v), a = tonumber(vx), b = tonumber(vy),
        w = tonumber(tm), p = table.concat(sent, ";"),
        s = sessionId, q = liveSeq
    })
    if not ok then
        pend = sent
        return
    end
    liveBusy, liveBusyT = true, now
    http('PUT', getDB() .. "/live/" .. safeKey(nick) .. ".json?print=silent", body, function(resp)
        liveBusy = false
        if not mark(resp) then
            -- gagal kirim: balikin sampel ke antrian biar ga ada gerakan yang hilang
            for i = #sent, 1, -1 do table.insert(pend, 1, sent[i]) end
            while #pend > 30 do table.remove(pend, 1) end
        end
    end)
end

-- Paket masuk berisi beberapa sampel posisi. Semua disimpen ke buffer dan diputar ulang
-- sesuai timing aslinya (mundur sedikit dari waktu sekarang), jadi gerakannya mulus.
local function parseSamples(text)
    local out = {}
    for tm, x, y, z, h, v, vx, vy, j in tostring(text):gmatch(
        "([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+)") do
        tm, x, y, z = tonumber(tm), tonumber(x), tonumber(y), tonumber(z)
        if tm and x and y and z then
            out[#out + 1] = {
                tm = tm, x = x, y = y, z = z,
                h = tonumber(h) or 0, v = tonumber(v) or 0,
                vx = tonumber(vx) or 0, vy = tonumber(vy) or 0,
                j = (tonumber(j) or 0) == 1,
            }
        end
    end
    return out
end

local function ingestLive(p)
    if type(p) ~= 'table' or not p.n then return end
    if p.n == myNick() then return end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not (x and y and z) then return end

    local nick = tostring(p.n)
    local now = clk()
    local stamp = tostring(p.s) .. ":" .. tostring(p.q)
    local g = ghosts[nick]
    if g and g.stamp == stamp then return end
    if not g then
        g = { nick = nick, buf = {} }
        ghosts[nick] = g
    end
    if g.sess ~= p.s then
        g.buf, g.rt, g.ft, g.off, g.ivl = {}, nil, nil, nil, nil
        g.dly, g.px, g.jdone, g.lastArr = nil, nil, nil, nil
    end
    g.sess = p.s
    g.stamp, g.seen = stamp, now
    g.skin  = tonumber(p.k) or 0
    g.int   = tonumber(p.i) or 0
    g.incar = (tonumber(p.c) or 0) == 1
    g.x, g.y, g.z = x, y, z

    local samples
    if type(p.p) == 'string' and p.p ~= "" then samples = parseSamples(p.p) end
    if not samples or #samples == 0 then
        -- paket versi lama: cuma 1 posisi
        samples = {{
            tm = tonumber(p.w) or now, x = x, y = y, z = z,
            h = tonumber(p.h) or 0, v = tonumber(p.v) or 0,
            vx = tonumber(p.a) or 0, vy = tonumber(p.b) or 0,
            j = (tonumber(p.j) or 0) == 1,
        }}
    end

    local buf = g.buf
    local newest
    for _, snap in ipairs(samples) do
        local last = buf[#buf]
        local skip = false
        if last and snap.tm <= last.tm then
            if last.tm - snap.tm > 5 then
                g.buf, g.rt, g.ft, g.off, g.ivl = {}, nil, nil, nil, nil
                g.dly, g.px, g.jdone, g.lastArr = nil, nil, nil, nil
                buf, last = g.buf, nil
            else
                skip = true
            end
        end
        if not skip then
            if last and snap.tm - last.tm > 0.6 and last.v < 0.3 then
                -- habis diam lama: tahan posisi lama dulu biar ga meluncur pelan
                buf[#buf + 1] = {
                    tm = snap.tm - 0.05, x = last.x, y = last.y, z = last.z,
                    h = last.h, vx = 0, vy = 0, v = 0, j = false,
                }
            end
            buf[#buf + 1] = snap
            newest = snap
        end
    end
    while #buf > 60 do table.remove(buf, 1) end
    if not newest then return end

    -- selisih jam pengirim ke jam lokal: ambil yang paling kecil (paket paling cepat)
    local cand = now - newest.tm
    if not g.off or cand < g.off then g.off = cand end

    -- seberapa sering paket datang (dipakai buat nentuin delay tampil)
    if newest.v >= 0.25 and g.lastArr then
        local d = now - g.lastArr
        if d > 0.02 and d < 1.5 then
            g.ivl = g.ivl and (g.ivl * 0.85 + d * 0.15) or d
        end
    end
    g.lastArr = now
end

local function onStreamEvent(r)
    if r.ev == "up" then
        streamUp = true
        liveData = {}
        return
    elseif r.ev == "down" then
        streamUp = false
        return
    end
    if not (cfg.enabled and cfg.seeOthers) then return end
    local d = decodeJson(r.text or "")
    if type(d) ~= 'table' or type(d.path) ~= 'string' then return end
    local segs = {}
    for s in d.path:gmatch("[^/]+") do segs[#segs + 1] = s end
    local data = d.data

    if r.ev == "put" then
        if #segs == 0 then
            liveData = (type(data) == 'table') and data or {}
            for _, p in pairs(liveData) do ingestLive(p) end
        elseif #segs == 1 then
            liveData[segs[1]] = data
            if type(data) == 'table' then
                ingestLive(data)
            else
                removeGhost(segs[1])
            end
        else
            local p = liveData[segs[1]]
            if type(p) == 'table' then
                p[segs[2]] = data
                ingestLive(p)
            end
        end
    elseif r.ev == "patch" and type(data) == 'table' then
        if #segs == 0 then
            for k, v in pairs(data) do
                liveData[k] = v
                if type(v) == 'table' then ingestLive(v) end
            end
        elseif #segs == 1 then
            local p = liveData[segs[1]]
            if type(p) ~= 'table' then p = {}; liveData[segs[1]] = p end
            for k, v in pairs(data) do p[k] = v end
            ingestLive(p)
        end
    end
end

local function pumpResults()
    if not HAS_EFFIL then return end
    local r = results:pop(0)
    while r do
        if r.id == 0 then
            pcall(onStreamEvent, r)
        else
            local cb = callbacks[r.id]
            callbacks[r.id] = nil
            if cb then cb(r.ok and r.text or nil) end
        end
        r = results:pop(0)
    end
end

local function pollLive()
    if livePolling and clk() - livePollStart < 10 then return end
    livePolling, livePollStart = true, clk()

    http('GET', getDB() .. "/live.json", nil, function(resp)
        livePolling = false
        if not mark(resp) then return end
        if not (cfg.enabled and cfg.seeOthers) then return end
        local data = decodeJson(resp)
        if type(data) == 'table' then
            for _, p in pairs(data) do ingestLive(p) end
        end
    end)
end

local function validSkin(s)
    if s < 0 or s > 311 then return 0 end
    return s
end

local function stateFor(v, prev)
    local moving = prev ~= nil and prev ~= "idle"
    if v < (moving and 0.2 or 0.5) then return "idle" end
    if v < 2.8 then return "walk" end
    if v < 5.4 then return "run" end
    return "sprint"
end

local zOffset, zCalibrated = 0, false

local function setPos(ped, x, y, z)
    setCharCoordinates(ped, x, y, z - zOffset)
end

local function spawnGhost(g, x, y, z)
    local skin = validSkin(g.skin)
    if not hasModelLoaded(skin) then
        requestModel(skin)
        loadAllModelsNow()
    end
    pcall(function()
        if not hasAnimationLoaded("PED") then
            requestAnimation("PED")
            loadAllModelsNow()
        end
    end)
    local ok, ped = pcall(createChar, 4, skin, x, y, z)
    if ok and ped then
        g.ped, g.skinApplied, g.state, g.anim, g.animSpd = ped, skin, nil, nil, nil
        pcall(setCharProofs, ped, true, true, true, true, true)
        pcall(setCharHealth, ped, 1000)
        pcall(setCharNeverTargetted, ped, true)
        -- posisi dikendalikan penuh sama script, jadi fisika/tabrakan dimatiin
        pcall(setCharCollision, ped, false)
        markModelAsNoLongerNeeded(skin)
        if not zCalibrated then
            pcall(setCharCoordinates, ped, x, y, z)
            local okC, _, _, cz = pcall(getCharCoordinates, ped)
            if okC and type(cz) == 'number' then
                local off = cz - z
                if off > -1.5 and off < 2 then zOffset = off end
                zCalibrated = true
            end
        end
    end
end

local function lerpAngle(a, b, k)
    local d = (b - a + 180) % 360 - 180
    return a + d * k
end

-- Ambil posisi ghost dari buffer sampel. Waktu putar = waktu sekarang dikurangi delay,
-- dan delay otomatis nyesuaiin seberapa cepat paket datang (koneksi lambat = delay lebih panjang).
local function stepGhost(g, now)
    local buf = g.buf
    local n = buf and #buf or 0
    if n == 0 or not g.off then return nil end

    local dt = now - (g.ft or now)
    g.ft = now
    if dt < 0.001 then dt = 0.001 elseif dt > 0.1 then dt = 0.1 end

    -- biar offset jam ngikutin pelan-pelan kalau jam dua pemain beda laju
    g.off = g.off + 0.002 * dt

    local want = math.max(0.15, math.min(1.5, (g.ivl or 0.25) * 1.25 + cfg.smoothT))
    if not g.dly then
        g.dly = want
    else
        local k = (want > g.dly) and 1.5 or 0.4
        g.dly = g.dly + (want - g.dly) * math.min(1, dt * k)
    end

    local last = buf[n]
    local rt = now - g.off - g.dly
    if rt > last.tm + 0.6 then rt = last.tm + 0.6 end
    g.rt = rt

    -- sampel lompat dimainkan pas waktunya
    for i = 1, n do
        local s = buf[i]
        if s.j and s.tm <= rt and rt - s.tm < 0.5 and s.tm > (g.jdone or -1e18) then
            g.jumpReq = true
            g.jdone = s.tm
        end
    end

    local x, y, z, h, v
    if rt <= buf[1].tm then
        local s = buf[1]
        x, y, z, h, v = s.x, s.y, s.z, s.h, s.v
    elseif rt >= last.tm then
        local e = math.min(rt - last.tm, 0.6)
        if last.v >= 0.25 then
            x, y = last.x + last.vx * e, last.y + last.vy * e
        else
            x, y = last.x, last.y
        end
        z, h, v = last.z, last.h, last.v
    else
        local i = 1
        while i < n - 1 and buf[i + 1].tm < rt do i = i + 1 end
        local a, b = buf[i], buf[i + 1]
        local span = b.tm - a.tm
        local k = (span > 0.0001) and ((rt - a.tm) / span) or 1
        if k < 0 then k = 0 elseif k > 1 then k = 1 end
        local ddx, ddy = b.x - a.x, b.y - a.y
        if ddx * ddx + ddy * ddy > 2500 or math.abs(b.z - a.z) > 20 then
            k = 1
        end
        x = a.x + (b.x - a.x) * k
        y = a.y + (b.y - a.y) * k
        z = a.z + (b.z - a.z) * k
        h = lerpAngle(a.h, b.h, k)
        v = a.v + (b.v - a.v) * k
    end

    while n > 2 and buf[2].tm < rt - 0.5 do
        table.remove(buf, 1)
        n = n - 1
    end

    -- penghalusan terakhir: nyerap selisih kecil antar paket biar ga ada loncatan
    if not g.px then
        g.px, g.py, g.pz, g.ph = x, y, z, h
    else
        local ex, ey, ez = x - g.px, y - g.py, z - g.pz
        if ex * ex + ey * ey > 64 or math.abs(ez) > 6 then
            g.px, g.py, g.pz = x, y, z
        else
            local a = 1 - math.exp(-dt / 0.05)
            g.px = g.px + ex * a
            g.py = g.py + ey * a
            g.pz = g.pz + ez * a
        end
        g.ph = lerpAngle(g.ph, h, 1 - math.exp(-dt / 0.06))
    end

    local sp = g.sp or 0
    g.sp = sp + (v - sp) * (1 - math.exp(-dt / 0.08))
    return g.px, g.py, g.pz, g.ph, g.sp
end

-- Posisi digerakkan langsung (mulus), animasi jalan diputar terpisah.
-- Jadi ga ada tabrakan antara teleport per-frame dan task jalan bawaan game.
local ANIMS = {
    walk   = { "WALK_player", 1.9 },
    run    = { "run_player",  4.2 },
    sprint = { "sprint_civi", 7.0 },
}

local function startAnim(g, want, now)
    local ped = g.ped
    if want == "idle" then
        pcall(clearCharTasks, ped)
        g.anim = nil
    else
        local a = ANIMS[want]
        pcall(taskPlayAnim, ped, a[1], "PED", 8.0, true, true, true, false, -1)
        g.anim = a[1]
    end
    g.animSpd = nil
    g.state, g.lastTask, g.want = want, now, nil
end

local function driveGhost(g, x, y, z, h, v, now)
    local ped = g.ped
    setPos(ped, x, y, z)
    setCharHeading(ped, h)

    if g.jumpReq then
        g.jumpReq = false
        pcall(taskJump, ped, true)
        g.jumpUntil = now + 0.8
        g.state, g.anim, g.animSpd = nil, nil, nil
    end
    if now < (g.jumpUntil or 0) then return end

    local want = stateFor(v, g.state)
    if want ~= g.state then
        if g.want ~= want then
            g.want, g.wantT = want, now
        end
        if g.state ~= nil and now - g.wantT < 0.12 then want = g.state end
    else
        g.want = nil
    end

    if want ~= g.state then
        startAnim(g, want, now)
    elseif want ~= "idle" and g.anim then
        if now - (g.lastTask or 0) > 0.5 then
            g.lastTask = now
            local okp, playing = pcall(isCharPlayingAnim, ped, g.anim)
            if okp and not playing then
                startAnim(g, want, now)
                return
            end
        end
        local a = ANIMS[want]
        local k = math.max(0.5, math.min(1.7, v / a[2]))
        if not g.animSpd or math.abs(k - g.animSpd) > 0.04 then
            pcall(setCharAnimSpeed, ped, g.anim, k)
            g.animSpd = k
        end
    end
end

local function updateGhosts()
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    local myInt = myInterior()
    local now = clk()
    for nick, g in pairs(ghosts) do
        if now - (g.seen or 0) > GHOST_STALE then
            removeGhost(nick)
        else
            local x, y, z, h, sp = stepGhost(g, now)
            if x then
                local dist = getDistanceBetweenCoords3d(mx, my, mz, x, y, z)
                local lim = g.ped and (cfg.renderDist + 15) or cfg.renderDist
                local visible = (g.int == myInt) and (dist < lim) and (not g.incar)
                if g.ped and not doesCharExist(g.ped) then
                    g.ped = nil
                    g.state, g.anim, g.animSpd = nil, nil, nil
                    g.nextSpawn = now + 1
                end
                if g.ped and g.skinApplied ~= validSkin(g.skin) then removeGhostPed(g) end
                if not visible then
                    removeGhostPed(g)
                else
                    if not g.ped and now >= (g.nextSpawn or 0) then spawnGhost(g, x, y, z) end
                    if g.ped then driveGhost(g, x, y, z, h, sp, now) end
                end
            end
        end
    end
end

local function markGhost(nick)
    local g = ghosts[nick]
    if not g then
        notify(L("no_ghost"), "warn")
        return
    end
    local mx, my = getCharCoordinates(PLAYER_PED)
    local d = math.sqrt((g.x - mx) ^ 2 + (g.y - my) ^ 2)
    notify(L("marked", cleanText(nick, 24), d), "ok")
    if findBlip then pcall(removeBlip, findBlip) end
    local ok, b = pcall(addBlipForCoord, g.x, g.y, g.z)
    if ok then findBlip = b end
end

local function hex(c, a)
    return ImVec4(bit.band(bit.rshift(c, 16), 255) / 255,
                  bit.band(bit.rshift(c, 8), 255) / 255,
                  bit.band(c, 255) / 255, a or 1)
end

local function u32(v, am)
    return imgui.ColorConvertFloat4ToU32(ImVec4(v.x, v.y, v.z, v.w * (am or 1)))
end

local function lerpColor(a, b, t)
    return ImVec4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t,
                  a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t)
end

local C = {
    bg      = hex(0x0D0F14), surface = hex(0x141821), surface2 = hex(0x1B212D),
    hover   = hex(0x242C3B), border  = hex(0x252C3A),
    text    = hex(0xE8EBF1), dim     = hex(0x8C95A6), faint = hex(0x566074),
    accent  = hex(0xF5A524), green   = hex(0x34D399), red   = hex(0xF87171),
    amber   = hex(0xFBBF24), blue    = hex(0x60A5FA),
    pill    = hex(0x090B0F, 0.66), bubble = hex(0x0F1218, 0.92), clear = ImVec4(0, 0, 0, 0),
}
local AVATAR = { 0x60A5FA, 0xA78BFA, 0xF472B6, 0x34D399, 0xFBBF24, 0xFB923C, 0x22D3EE }

local function colorFor(nick)
    local h = 0
    for i = 1, #nick do h = (h * 31 + nick:byte(i)) % 100003 end
    return hex(AVATAR[h % #AVATAR + 1])
end

local F = { reg = nil, bold = nil, title = nil }
local B = 18
local hasFonts = false

local function unit() return B * cfg.scale end
local function wscale() return (hasFonts and 1 or B / 13) * cfg.scale end
local function pf(f) if f then imgui.PushFont(f) end end
local function pp(f) if f then imgui.PopFont() end end

local function flags(names)
    local f = 0
    for _, n in ipairs(names) do
        local v = imgui.WindowFlags[n]
        if v then f = bit.bor(f, v) end
    end
    return f
end

local MAIN_FLAGS = flags({ "NoTitleBar", "NoResize", "NoMove", "NoCollapse",
    "NoScrollbar", "NoScrollWithMouse", "NoSavedSettings" })
local OVERLAY_FLAGS = flags({ "NoTitleBar", "NoResize", "NoMove", "NoCollapse", "NoScrollbar",
    "NoScrollWithMouse", "NoBackground", "NoInputs", "NoSavedSettings",
    "NoFocusOnAppearing", "NoBringToFrontOnFocus", "NoNav" })

local ui = {
    win = new.bool(false), page = "players",
    urlBuf = new.char[256](), rulesBuf = new.char[1024](RULES), chatBuf = new.char[160](),
    renderDist = new.int(cfg.renderDist), chatRange = new.int(cfg.chatRange),
    feedY = new.int(cfg.feedY), scale = new.float(cfg.scale), smoothT = new.float(cfg.smoothT),
    urlMsg = "", urlOk = false, testMsg = "", testKind = "info",
    anim = {}, dragMoved = false, activeRow = false, histSeq = -1,
}
ffi.copy(ui.urlBuf, cfg.customUrl)

local function fileExists(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end

local function firstExisting(list)
    for _, p in ipairs(list) do
        if fileExists(p) then return p end
    end
end

local function findFonts()
    local wd = ""
    pcall(function() wd = getWorkingDirectory() end)
    local reg, bold = { wd .. "/resource/fonts/monnet.ttf" }, { wd .. "/resource/fonts/monnet-bold.ttf" }
    if IS_ANDROID then
        for _, n in ipairs({ "Roboto-Regular.ttf", "Roboto[wdth,wght].ttf", "RobotoStatic-Regular.ttf", "DroidSans.ttf" }) do
            reg[#reg + 1] = "/system/fonts/" .. n
        end
        for _, n in ipairs({ "Roboto-Bold.ttf", "Roboto-Medium.ttf", "RobotoStatic-Bold.ttf", "DroidSans-Bold.ttf" }) do
            bold[#bold + 1] = "/system/fonts/" .. n
        end
    else
        local dir = (os.getenv("WINDIR") or "C:\\Windows") .. "\\Fonts"
        pcall(function() dir = getFolderPath(0x14) end)
        for _, n in ipairs({ "segoeui.ttf", "tahoma.ttf", "arial.ttf" }) do reg[#reg + 1] = dir .. "\\" .. n end
        for _, n in ipairs({ "segoeuib.ttf", "tahomabd.ttf", "arialbd.ttf" }) do bold[#bold + 1] = dir .. "\\" .. n end
    end
    local r = firstExisting(reg)
    local b = firstExisting(bold) or r
    return r, b
end

local function applyStyle(U)
    local s = imgui.GetStyle()
    s.WindowPadding    = ImVec2(0, 0)
    s.FramePadding     = ImVec2(U * 0.7, U * 0.5)
    s.ItemSpacing      = ImVec2(U * 0.5, U * 0.5)
    s.ItemInnerSpacing = ImVec2(U * 0.4, U * 0.4)
    s.WindowRounding   = U * 0.9
    s.ChildRounding    = U * 0.5
    s.FrameRounding    = U * 0.45
    s.GrabRounding     = U
    s.GrabMinSize      = U * 1.1
    s.ScrollbarRounding = U
    s.ScrollbarSize    = IS_ANDROID and U * 0.8 or U * 0.5
    s.WindowBorderSize = 1
    s.ChildBorderSize  = 0
    s.FrameBorderSize  = 1
end

local logoTex = nil

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    io.IniFilename = nil

    -- logo: resource/monnet.png (kalau ga ada / gagal dimuat, dipakai kotak huruf M)
    pcall(function()
        local p = getWorkingDirectory() .. "/resource/monnet.png"
        if fileExists(p) then
            local ok, tex = pcall(imgui.CreateTextureFromFile, p)
            if ok and tex then logoTex = tex end
        end
    end)

    local _, sh = getScreenResolution()
    B = math.floor(math.max(15, math.min(IS_ANDROID and sh / 38 or sh / 58, 34)))

    local regP, boldP = findFonts()
    if regP then
        local ranges = io.Fonts:GetGlyphRangesDefault()
        local ok1, f1 = pcall(function() return io.Fonts:AddFontFromFileTTF(regP, B, nil, ranges) end)
        local ok2, f2 = pcall(function() return io.Fonts:AddFontFromFileTTF(boldP, B, nil, ranges) end)
        local ok3, f3 = pcall(function() return io.Fonts:AddFontFromFileTTF(boldP, B * 1.45, nil, ranges) end)
        if ok1 and f1 then F.reg = f1 end
        if ok2 and f2 then F.bold = f2 end
        if ok3 and f3 then F.title = f3 end
        hasFonts = F.reg ~= nil
    end
    if not F.bold then F.bold = F.reg end
    if not F.title then F.title = F.bold end

    local c, Col = imgui.GetStyle().Colors, imgui.Col
    c[Col.Text]              = C.text
    c[Col.TextDisabled]      = C.faint
    c[Col.WindowBg]          = C.bg
    c[Col.ChildBg]           = C.clear
    c[Col.PopupBg]           = C.surface
    c[Col.Border]            = C.border
    c[Col.FrameBg]           = C.surface2
    c[Col.FrameBgHovered]    = C.hover
    c[Col.FrameBgActive]     = C.hover
    c[Col.ScrollbarBg]       = C.clear
    c[Col.ScrollbarGrab]     = hex(0x2C3446)
    c[Col.ScrollbarGrabHovered] = hex(0x3A455A)
    c[Col.ScrollbarGrabActive]  = C.accent
    c[Col.CheckMark]         = C.accent
    c[Col.SliderGrab]        = C.accent
    c[Col.SliderGrabActive]  = hex(0xFFB53D)
    c[Col.Button]            = C.surface2
    c[Col.ButtonHovered]     = C.hover
    c[Col.ButtonActive]      = C.hover
    c[Col.Separator]         = C.border
    c[Col.TextSelectedBg]    = hex(0xF5A524, 0.35)
    applyStyle(unit())
end)

local function dtext(dl, x, y, col, text, font, am)
    if font then imgui.PushFont(font) end
    dl:AddText(ImVec2(x, y), u32(col, am), text)
    if font then imgui.PopFont() end
end

local function tsize(text, font)
    if font then imgui.PushFont(font) end
    local s = imgui.CalcTextSize(text)
    if font then imgui.PopFont() end
    return s.x, s.y
end

local function wrapText(text, maxW)
    local lines, cur = {}, ""
    for word in tostring(text):gmatch("%S+") do
        local try = (cur == "") and word or (cur .. " " .. word)
        if imgui.CalcTextSize(try).x > maxW and cur ~= "" then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = try
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    if #lines == 0 then lines[1] = "" end
    return lines
end

local function drawIcon(dl, kind, cx, cy, r, col)
    local c = u32(col)
    local th = math.max(1.5, r * 0.16)
    if kind == "players" then
        dl:AddCircleFilled(ImVec2(cx, cy - r * 0.45), r * 0.38, c, 16)
        dl:AddRectFilled(ImVec2(cx - r * 0.75, cy + r * 0.05), ImVec2(cx + r * 0.75, cy + r * 0.85), c, r * 0.4)
    elseif kind == "chat" then
        dl:AddRectFilled(ImVec2(cx - r * 0.9, cy - r * 0.7), ImVec2(cx + r * 0.9, cy + r * 0.45), c, r * 0.35)
        dl:AddTriangleFilled(ImVec2(cx - r * 0.5, cy + r * 0.35), ImVec2(cx - r * 0.05, cy + r * 0.35),
            ImVec2(cx - r * 0.6, cy + r * 0.9), c)
    elseif kind == "settings" then
        local xs = { -0.35, 0.4, -0.1 }
        for i = -1, 1 do
            local y = cy + i * r * 0.6
            dl:AddLine(ImVec2(cx - r * 0.9, y), ImVec2(cx + r * 0.9, y), c, th)
            dl:AddCircleFilled(ImVec2(cx + xs[i + 2] * r, y), r * 0.24, c, 12)
        end
    elseif kind == "database" then
        for i = -1, 1 do
            local y = cy + i * r * 0.62
            dl:AddRectFilled(ImVec2(cx - r * 0.85, y - r * 0.22), ImVec2(cx + r * 0.85, y + r * 0.22), c, r * 0.22)
        end
    elseif kind == "about" then
        dl:AddCircle(ImVec2(cx, cy), r * 0.88, c, 24, th)
        dl:AddLine(ImVec2(cx, cy - r * 0.05), ImVec2(cx, cy + r * 0.45), c, th)
        dl:AddCircleFilled(ImVec2(cx, cy - r * 0.38), r * 0.11, c, 10)
    elseif kind == "close" then
        dl:AddLine(ImVec2(cx - r * 0.55, cy - r * 0.55), ImVec2(cx + r * 0.55, cy + r * 0.55), c, th)
        dl:AddLine(ImVec2(cx - r * 0.55, cy + r * 0.55), ImVec2(cx + r * 0.55, cy - r * 0.55), c, th)
    end
end

-- logo header: pakai gambar resource/monnet.png, fallback ke kotak oranye huruf M
local function drawLogo(dl, x, y, size)
    local p1, p2 = ImVec2(x, y), ImVec2(x + size, y + size)
    if logoTex then
        local ok = pcall(function()
            dl:AddImageRounded(logoTex, p1, p2, ImVec2(0, 0), ImVec2(1, 1),
                imgui.ColorConvertFloat4ToU32(ImVec4(1, 1, 1, 1)), size * 0.3)
        end)
        if not ok then pcall(function() dl:AddImage(logoTex, p1, p2) end) end
    else
        dl:AddRectFilled(p1, p2, u32(C.accent), size * 0.3)
        local mw, mh = tsize("M", F.bold)
        dtext(dl, x + (size - mw) / 2, y + (size - mh) / 2, C.bg, "M", F.bold)
    end
end

local function drawWorld(dl, U)
    for nick, g in pairs(ghosts) do
        if g.ped and doesCharExist(g.ped) then
            local x, y, z = getCharCoordinates(g.ped)
            if isPointOnScreen(x, y, z, 1.0) then
                local sx, sy = convert3DCoordsToScreen(x, y, z + 1.0)
                if sx and sy then
                    local pillTop = sy
                    if cfg.nametags then
                        local nm = cleanText(nick, 24)
                        local tw, th = tsize(nm, F.bold)
                        local px, py = U * 0.6, U * 0.2
                        local x0, y0 = sx - tw / 2 - px - U * 0.3, sy - th - py * 2
                        dl:AddRectFilled(ImVec2(x0, y0), ImVec2(x0 + tw + px * 2 + U * 0.6, y0 + th + py * 2), u32(C.pill), U * 0.45)
                        dl:AddCircleFilled(ImVec2(x0 + px + U * 0.1, y0 + th / 2 + py), U * 0.17, u32(C.accent), 10)
                        dtext(dl, x0 + px + U * 0.6, y0 + py, C.text, nm, F.bold)
                        pillTop = y0
                    end

                    local b = bubbles[nick]
                    if b and cfg.bubbles then
                        local age = clk() - b.t
                        if age > b.dur then
                            bubbles[nick] = nil
                        else
                            local am = (age > b.dur - 0.6) and math.max(0, (b.dur - age) / 0.6) or 1
                            pf(F.reg)
                            local lines = wrapText(b.text, U * 13)
                            local lw = 0
                            for _, l in ipairs(lines) do lw = math.max(lw, (tsize(l))) end
                            local padx, pady, lh = U * 0.75, U * 0.5, U * 1.2
                            local w, h = lw + padx * 2, lh * #lines + pady * 2
                            local x0, y0 = sx - w / 2, pillTop - U * 0.7 - h
                            dl:AddRectFilled(ImVec2(x0, y0), ImVec2(x0 + w, y0 + h), u32(C.bubble, am), U * 0.7)
                            dl:AddTriangleFilled(ImVec2(sx - U * 0.4, y0 + h), ImVec2(sx + U * 0.4, y0 + h),
                                ImVec2(sx, y0 + h + U * 0.45), u32(C.bubble, am))
                            for i, l in ipairs(lines) do
                                dl:AddText(ImVec2(x0 + padx, y0 + pady + (i - 1) * lh), u32(C.text, am), l)
                            end
                            pp(F.reg)
                        end
                    end
                end
            end
        end
    end
end

local function drawFeed(dl, U, sw, sh)
    local now = clk()
    local list = {}
    for i = #feed, 1, -1 do
        if now - feed[i].t < 12.5 then
            table.insert(list, 1, feed[i])
            if #list >= 5 then break end
        else
            break
        end
    end
    if #list == 0 then return end

    local x, y = U * 0.8, sh * (cfg.feedY / 100)
    local w = math.min(sw * 0.40, U * 24)
    pf(F.reg)
    for _, m in ipairs(list) do
        local age = now - m.t
        local am = (age > 10) and math.max(0, 1 - (age - 10) / 2.5) or 1
        local lines = wrapText(m.text, w - U * 1.8)
        local lh = U * 1.2
        local h = U * 0.55 * 2 + lh * (1 + #lines)
        dl:AddRectFilled(ImVec2(x, y), ImVec2(x + w, y + h), u32(C.pill, am), U * 0.5)
        dl:AddRectFilled(ImVec2(x, y + U * 0.4), ImVec2(x + U * 0.22, y + h - U * 0.4),
            u32(m.global and C.accent or C.blue, am), U * 0.1)
        local nw = tsize(m.nick, F.bold)
        dtext(dl, x + U * 0.8, y + U * 0.55, colorFor(m.nick), m.nick, F.bold, am)
        local tag = m.global and (L("tag_global") .. " - " .. m.server) or L("tag_local")
        dtext(dl, x + U * 1.2 + nw, y + U * 0.55, C.dim, tag, nil, am)
        for i, l in ipairs(lines) do
            dl:AddText(ImVec2(x + U * 0.8, y + U * 0.55 + lh * i), u32(C.text, am), l)
        end
        y = y + h + U * 0.4
    end
    pp(F.reg)
end

local function drawToasts(dl, U, sw)
    local now = clk()
    for i = #toasts, 1, -1 do
        if now - toasts[i].t > 4 then table.remove(toasts, i) end
    end
    if #toasts == 0 then return end
    pf(F.bold)
    local y = U * 1.2
    for _, t in ipairs(toasts) do
        local age = now - t.t
        local am = (age > 3.4) and math.max(0, (4 - age) / 0.6) or math.min(1, age / 0.15)
        local tw, th = tsize(t.text)
        local w, h = tw + U * 3.4, U * 2.5
        local x = (sw - w) / 2
        local kc = (t.kind == "ok" and C.green) or (t.kind == "warn" and C.amber)
            or (t.kind == "error" and C.red) or C.accent
        dl:AddRectFilled(ImVec2(x, y), ImVec2(x + w, y + h), u32(C.bubble, am), h / 2)
        dl:AddRect(ImVec2(x, y), ImVec2(x + w, y + h), u32(C.border, am), h / 2)
        dl:AddCircleFilled(ImVec2(x + U * 1.3, y + h / 2), U * 0.34, u32(kc, am), 14)
        dl:AddText(ImVec2(x + U * 2.2, y + (h - th) / 2), u32(C.text, am), t.text)
        y = y + h + U * 0.5
    end
    pp(F.bold)
end

imgui.OnFrame(function() return cfg.enabled or #toasts > 0 end, function(self)
    self.HideCursor = true
    local sw, sh = getScreenResolution()
    local U = unit()
    imgui.SetNextWindowPos(ImVec2(0, 0))
    imgui.SetNextWindowSize(ImVec2(sw, sh))
    if imgui.Begin("##monnet_overlay", nil, OVERLAY_FLAGS) then
        imgui.SetWindowFontScale(wscale())
        local dl = imgui.GetWindowDrawList()
        if cfg.enabled and cfg.seeOthers then drawWorld(dl, U) end
        if cfg.enabled then drawFeed(dl, U, sw, sh) end
        drawToasts(dl, U, sw)
    end
    imgui.End()
end)

local function advance(p, h)
    imgui.SetCursorScreenPos(ImVec2(p.x, p.y + h))
    imgui.Dummy(ImVec2(1, 1))
end

local function beginCard(cw, h)
    local U = unit()
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    dl:AddRectFilled(p, ImVec2(p.x + cw, p.y + h), u32(C.surface), U * 0.7)
    dl:AddRect(p, ImVec2(p.x + cw, p.y + h), u32(C.border), U * 0.7)
    return p
end

local function pageHeader(U, title, sub)
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    dtext(dl, p.x, p.y, C.text, title, F.title)
    if sub then dtext(dl, p.x, p.y + U * 2.25, C.dim, sub) end
    advance(p, U * 3.8)
end

local function sectionLabel(U, text)
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    dtext(dl, p.x + U * 0.2, p.y, C.faint, string.upper(text), F.bold)
    advance(p, U * 1.5)
end

local function switchWidget(id, on, w, h)
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton("##" .. id, ImVec2(w, h))
    if imgui.IsItemActive() then ui.activeRow = true end
    local target = on and 1 or 0
    local a = ui.anim[id]
    if a == nil then a = target end
    a = a + (target - a) * math.min(1, imgui.GetIO().DeltaTime * 16)
    ui.anim[id] = a
    dl:AddRectFilled(p, ImVec2(p.x + w, p.y + h), u32(lerpColor(C.hover, C.accent, a)), h / 2)
    local r = h / 2 - h * 0.15
    dl:AddCircleFilled(ImVec2(p.x + h / 2 + (w - h) * a, p.y + h / 2), r,
        u32(lerpColor(C.dim, C.bg, a), 1), 16)
    return clicked and not ui.dragMoved
end

local function button(id, label, primary, w)
    local U = unit()
    local h = U * 2.4
    local lw, lh = tsize(label, F.bold)
    w = w or (lw + U * 2.6)
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton("##" .. id, ImVec2(w, h))
    local hov, act = imgui.IsItemHovered(), imgui.IsItemActive()
    if act then ui.activeRow = true end
    local bg
    if primary then
        bg = act and hex(0xD98E10) or (hov and hex(0xFFB53D) or C.accent)
    else
        bg = (act or hov) and C.hover or C.surface2
    end
    dl:AddRectFilled(p, ImVec2(p.x + w, p.y + h), u32(bg), U * 0.5)
    if not primary then dl:AddRect(p, ImVec2(p.x + w, p.y + h), u32(C.border), U * 0.5) end
    dtext(dl, p.x + (w - lw) / 2, p.y + (h - lh) / 2, primary and C.bg or C.text, label, F.bold)
    return clicked and not ui.dragMoved, w
end

local function toggleRow(U, p, cw, rh, r)
    local dl = imgui.GetWindowDrawList()
    dtext(dl, p.x + U * 1.2, p.y + U * 0.6, C.text, r.title, F.bold)
    if r.desc then dtext(dl, p.x + U * 1.2, p.y + U * 1.85, C.dim, r.desc) end
    local sw, sh = U * 2.5, U * 1.4
    imgui.SetCursorScreenPos(ImVec2(p.x + cw - U * 1.2 - sw, p.y + (rh - sh) / 2))
    if switchWidget("sw_" .. r.key, cfg[r.key], sw, sh) then
        local old = getDB()
        cfg[r.key] = not cfg[r.key]
        dirty = true
        if r.after then r.after(old) end
    end
end

local function sliderRow(U, p, cw, rh, r)
    local dl = imgui.GetWindowDrawList()
    dtext(dl, p.x + U * 1.2, p.y + U * 0.6, C.text, r.title, F.bold)
    imgui.SetCursorScreenPos(ImVec2(p.x + U * 1.2, p.y + U * 2.2))
    imgui.PushItemWidth(cw - U * 2.4)
    local s = imgui.GetStyle()
    local ox, oy = s.FramePadding.x, s.FramePadding.y
    s.FramePadding = ImVec2(U * 0.6, U * 0.2)
    local changed
    if r.float then
        changed = imgui.SliderFloat("##sl_" .. r.key, r.buf, r.min, r.max, r.fmt)
    else
        changed = imgui.SliderInt("##sl_" .. r.key, r.buf, r.min, r.max, r.fmt)
    end
    s.FramePadding = ImVec2(ox, oy)
    imgui.PopItemWidth()
    if changed then
        cfg[r.key] = r.buf[0]
        dirty = true
    end
end

local function settingsCard(U, cw, rows)
    local dl = imgui.GetWindowDrawList()
    local total = 0
    for _, r in ipairs(rows) do total = total + (r.slider and U * 4.8 or U * 3.5) end
    local p = beginCard(cw, total)
    local y = p.y
    for i, r in ipairs(rows) do
        local rh = r.slider and U * 4.8 or U * 3.5
        local rp = ImVec2(p.x, y)
        if r.slider then sliderRow(U, rp, cw, rh, r) else toggleRow(U, rp, cw, rh, r) end
        if i < #rows then
            dl:AddLine(ImVec2(p.x + U * 1.2, y + rh), ImVec2(p.x + cw - U * 1.2, y + rh), u32(C.border), 1)
        end
        y = y + rh
    end
    advance(p, total + U * 0.9)
end

local function langCard(U, cw)
    local dl = imgui.GetWindowDrawList()
    local p = beginCard(cw, U * 6.4)
    dtext(dl, p.x + U * 1.2, p.y + U * 0.6, C.text, L("lang_t"), F.bold)
    dtext(dl, p.x + U * 1.2, p.y + U * 1.85, C.dim, L("lang_d"))
    local bw = U * 9
    imgui.SetCursorScreenPos(ImVec2(p.x + U * 1.2, p.y + U * 3.4))
    if button("lang_id", "Indonesia", cfg.lang == "id", bw) then
        cfg.lang = "id"
        dirty = true
    end
    imgui.SetCursorScreenPos(ImVec2(p.x + U * 1.2 + bw + U * 0.6, p.y + U * 3.4))
    if button("lang_en", "English", cfg.lang == "en", bw) then
        cfg.lang = "en"
        dirty = true
    end
    advance(p, U * 6.4 + U * 0.9)
end

local function touchScroll(U)
    if not IS_ANDROID then return end
    if (imgui.IsWindowHovered() or ui.activeRow) and imgui.IsMouseDragging(0, U * 0.25) then
        local maxY = imgui.GetScrollMaxY()
        if maxY > 0 then
            local ny = imgui.GetScrollY() - imgui.GetIO().MouseDelta.y
            imgui.SetScrollY(math.max(0, math.min(maxY, ny)))
        end
        ui.dragMoved = true
    end
end

local function pagePlayers(U, cw)
    local dl = imgui.GetWindowDrawList()
    pageHeader(U, L("players_t"), L("players_sub", #onlineList, countGhosts()))

    if #onlineList == 0 then
        local p = beginCard(cw, U * 6)
        local msg = L("players_none")
        local mw, mh = tsize(msg)
        dtext(dl, p.x + (cw - mw) / 2, p.y + (U * 6 - mh) / 2, C.dim, msg)
        advance(p, U * 6)
        return
    end

    local me = myNick()
    local mx, my = getCharCoordinates(PLAYER_PED)
    local rowH = U * 3.8
    for i, pl in ipairs(onlineList) do
        local pos = imgui.GetCursorScreenPos()
        local clicked = imgui.InvisibleButton("##pl" .. i, ImVec2(cw, rowH))
        local hov = imgui.IsItemHovered()
        if imgui.IsItemActive() then ui.activeRow = true end
        if clicked and not ui.dragMoved then markGhost(tostring(pl.nick)) end

        dl:AddRectFilled(pos, ImVec2(pos.x + cw, pos.y + rowH), u32(hov and C.hover or C.surface), U * 0.7)
        dl:AddRect(pos, ImVec2(pos.x + cw, pos.y + rowH), u32(C.border), U * 0.7)

        local nick = cleanText(pl.nick, 24)
        local ac = colorFor(nick)
        local cx, cy = pos.x + U * 2.0, pos.y + rowH / 2
        dl:AddCircleFilled(ImVec2(cx, cy), U * 1.3, u32(ac, 0.18), 24)
        local ini = nick:sub(1, 1):upper()
        local iw, ih = tsize(ini, F.bold)
        dtext(dl, cx - iw / 2, cy - ih / 2, ac, ini, F.bold)

        dtext(dl, pos.x + U * 4.0, pos.y + U * 0.65, C.text, nick, F.bold)
        dtext(dl, pos.x + U * 4.0, pos.y + U * 1.95, C.dim, cleanText(pl.server, 40))

        local g = ghosts[tostring(pl.nick)]
        local right = pos.x + cw - U * 1.2
        local dtxt, dcol
        if tostring(pl.nick) == me then
            dtxt, dcol = L("you"), C.accent
        elseif g then
            dtxt, dcol = string.format("%.0f m", math.sqrt((g.x - mx) ^ 2 + (g.y - my) ^ 2)), C.green
        else
            dtxt, dcol = "-", C.faint
        end
        local dw = tsize(dtxt, F.bold)
        dtext(dl, right - dw, pos.y + U * 0.65, dcol, dtxt, F.bold)
        local st = L("skin", tonumber(pl.skin) or 0)
        dtext(dl, right - tsize(st), pos.y + U * 1.95, C.faint, st)
    end
    imgui.Dummy(ImVec2(1, U))
end

local function pageChat(U, cw, chH, pad)
    local dl = imgui.GetWindowDrawList()
    pageHeader(U, L("chat_t"), L("chat_sub"))

    local inputH = U * 2.6
    local histH = chH - pad * 2 - U * 3.8 - inputH - U * 1.6
    if histH < U * 6 then histH = U * 6 end

    imgui.BeginChild("##hist", ImVec2(cw, histH), false)
    imgui.SetWindowFontScale(wscale())
    if #feed == 0 then
        local p = imgui.GetCursorScreenPos()
        dtext(dl, p.x, p.y + U * 0.5, C.dim, L("chat_none"))
        advance(p, U * 2)
    end
    local hdl = imgui.GetWindowDrawList()
    for _, m in ipairs(feed) do
        local p = imgui.GetCursorScreenPos()
        local lines = wrapText(m.text, cw - U * 2.2)
        local lh = U * 1.25
        local h = U * 0.5 + lh * (1 + #lines) + U * 0.6
        local nw = tsize(m.nick, F.bold)
        dtext(hdl, p.x + U * 0.2, p.y + U * 0.4, colorFor(m.nick), m.nick, F.bold)
        dtext(hdl, p.x + U * 0.7 + nw, p.y + U * 0.4, C.faint,
            m.global and (L("tag_global") .. " - " .. m.server) or L("tag_local"))
        for i, l in ipairs(lines) do
            hdl:AddText(ImVec2(p.x + U * 0.2, p.y + U * 0.4 + lh * i), u32(C.text), l)
        end
        advance(p, h)
    end
    if ui.histSeq ~= feedSeq then
        imgui.SetScrollHereY(1.0)
        ui.histSeq = feedSeq
    end
    touchScroll(U)
    imgui.EndChild()

    local p = imgui.GetCursorScreenPos()
    local bw = tsize(L("send"), F.bold) + U * 2.6
    imgui.SetCursorScreenPos(ImVec2(p.x, p.y + U * 0.3))
    imgui.PushItemWidth(cw - bw - U * 0.6)
    local enter = imgui.InputText("##chatin", ui.chatBuf, ffi.sizeof(ui.chatBuf),
        imgui.InputTextFlags.EnterReturnsTrue)
    imgui.PopItemWidth()
    imgui.SetCursorScreenPos(ImVec2(p.x + cw - bw, p.y + U * 0.3))
    local clicked = button("sendchat", L("send"), true, bw)
    if enter or clicked then
        local t = str(ui.chatBuf)
        if trim(t) ~= "" then
            sendGlobal(t)
            ffi.copy(ui.chatBuf, "")
        end
    end
    advance(p, inputH)
end

local function pageSettings(U, cw)
    pageHeader(U, L("set_t"), L("set_sub"))

    sectionLabel(U, L("sec_general"))
    settingsCard(U, cw, {
        { key = "enabled", title = L("enable"), desc = L("enable_d"), after = applyState },
    })

    sectionLabel(U, L("sec_multi"))
    settingsCard(U, cw, {
        { key = "shareMe", title = L("share"), desc = L("share_d"), after = applyState },
        { key = "seeOthers", title = L("see"), desc = L("see_d"), after = applyState },
        { key = "nametags", title = L("tags"), desc = L("tags_d") },
        { slider = true, key = "renderDist", title = L("rdist"), buf = ui.renderDist, min = 50, max = 300, fmt = "%d m" },
        { slider = true, float = true, key = "smoothT", title = L("smooth"), buf = ui.smoothT, min = 0.05, max = 0.40, fmt = "%.2f s" },
    })

    sectionLabel(U, L("sec_chat"))
    settingsCard(U, cw, {
        { key = "localChat", title = L("lchat"), desc = L("lchat_d"), after = applyState },
        { key = "globalChat", title = L("gchat"), desc = L("gchat_d"), after = applyState },
        { key = "bubbles", title = L("bubbles"), desc = L("bubbles_d") },
        { key = "chatToLog", title = L("tolog"), desc = L("tolog_d") },
        { slider = true, key = "chatRange", title = L("crange"), buf = ui.chatRange, min = 5, max = 50, fmt = "%d m" },
        { slider = true, key = "feedY", title = L("feedy"), buf = ui.feedY, min = 5, max = 85, fmt = "%d%%" },
    })
    if not okEv then
        local dl = imgui.GetWindowDrawList()
        local p = imgui.GetCursorScreenPos()
        dtext(dl, p.x, p.y, C.amber, L("no_samp"))
        advance(p, U * 1.8)
    end

    sectionLabel(U, L("sec_display"))
    langCard(U, cw)
    settingsCard(U, cw, {
        { slider = true, float = true, key = "scale", title = L("scale"), buf = ui.scale, min = 0.8, max = 1.6, fmt = "%.1fx" },
    })
end

local function pageDatabase(U, cw)
    local dl = imgui.GetWindowDrawList()
    pageHeader(U, L("db_t"), L("db_sub"))

    local custom = cfg.useCustomDb and validUrl(cfg.customUrl)
    local p = beginCard(cw, U * 5.6)
    dtext(dl, p.x + U * 1.2, p.y + U * 0.7, C.faint, L("db_active"), F.bold)
    dtext(dl, p.x + U * 1.2, p.y + U * 2.0, custom and C.amber or C.green, custom and L("db_custom") or L("db_default"), F.bold)
    if custom then dtext(dl, p.x + U * 1.2, p.y + U * 3.4, C.dim, getDB()) end
    advance(p, U * 5.6 + U * 0.9)

    settingsCard(U, cw, {
        { key = "useCustomDb", title = L("usedb"), desc = L("usedb_d"),
          after = function(old) switchDb(old) end },
    })

    if cfg.useCustomDb then
        local cp = beginCard(cw, U * 9.2)
        dtext(dl, cp.x + U * 1.2, cp.y + U * 0.7, C.text, L("db_url"), F.bold)
        imgui.SetCursorScreenPos(ImVec2(cp.x + U * 1.2, cp.y + U * 2.4))
        imgui.PushItemWidth(cw - U * 2.4)
        imgui.InputText("##url", ui.urlBuf, ffi.sizeof(ui.urlBuf))
        imgui.PopItemWidth()
        imgui.SetCursorScreenPos(ImVec2(cp.x + U * 1.2, cp.y + U * 5.4))
        local clicked, bw = button("saveurl", L("save_apply"), true)
        if clicked then
            local url = trim(str(ui.urlBuf)):gsub("/+$", "")
            if validUrl(url) then
                local old = getDB()
                cfg.customUrl = url
                dirty = true
                ui.urlMsg, ui.urlOk = L("saved"), true
                switchDb(old)
            else
                ui.urlMsg, ui.urlOk = L("url_bad"), false
            end
        end
        if ui.urlMsg ~= "" then
            dtext(dl, cp.x + U * 1.2 + bw + U * 1.0, cp.y + U * 5.4 + U * 0.6,
                ui.urlOk and C.green or C.red, ui.urlMsg, F.bold)
        end
        dtext(dl, cp.x + U * 1.2, cp.y + U * 8.0, C.faint, L("url_ex"))
        advance(cp, U * 9.2 + U * 0.9)
    end

    local tp = beginCard(cw, U * 5)
    imgui.SetCursorScreenPos(ImVec2(tp.x + U * 1.2, tp.y + U * 1.3))
    local clicked, bw = button("testconn", L("test"), false)
    if clicked then
        ui.testMsg, ui.testKind = L("testing"), "info"
        http('GET', getDB() .. "/live.json?shallow=true", nil, function(resp)
            if not resp then
                ui.testMsg, ui.testKind = L("test_conn"), "error"
            elseif resp:find("Permission", 1, true) then
                ui.testMsg, ui.testKind = L("test_rules"), "error"
            elseif resp:find('"error"', 1, true) or (decodeJson(resp) == nil and resp ~= "null") then
                ui.testMsg, ui.testKind = L("test_url"), "error"
            else
                ui.testMsg, ui.testKind = L("test_ok"), "ok"
            end
        end)
    end
    if ui.testMsg ~= "" then
        local col = (ui.testKind == "ok" and C.green) or (ui.testKind == "error" and C.red) or C.amber
        dtext(dl, tp.x + U * 1.2 + bw + U * 1.0, tp.y + U * 1.3 + U * 0.65, col, ui.testMsg, F.bold)
    end
    advance(tp, U * 5 + U * 0.9)

    local rp = beginCard(cw, U * 16)
    dtext(dl, rp.x + U * 1.2, rp.y + U * 0.7, C.text, L("rules_t"), F.bold)
    dtext(dl, rp.x + U * 1.2, rp.y + U * 1.95, C.dim, L("rules_d"))
    imgui.SetCursorScreenPos(ImVec2(rp.x + U * 1.2, rp.y + U * 3.6))
    imgui.InputTextMultiline("##rules", ui.rulesBuf, ffi.sizeof(ui.rulesBuf),
        ImVec2(cw - U * 2.4, U * 8.6), imgui.InputTextFlags.ReadOnly)
    imgui.SetCursorScreenPos(ImVec2(rp.x + U * 1.2, rp.y + U * 12.7))
    if button("copyrules", L("copy_rules"), false) then
        imgui.SetClipboardText(RULES)
        notify(L("rules_copied"), "ok")
    end
    advance(rp, U * 16 + U * 0.5)
end

local function pageAbout(U, cw)
    local dl = imgui.GetWindowDrawList()
    pageHeader(U, L("about_t"), L("about_sub", "1.0", IS_ANDROID and "Android" or "PC"))

    local lines = {
        { L("cmds"), true },
        { L("cmd1"), false },
        { L("cmd2"), false },
        { L("cmd3"), false },
        { L("cmd4"), false },
    }
    local p = beginCard(cw, U * 11)
    local y = p.y + U * 0.8
    for _, l in ipairs(lines) do
        dtext(dl, p.x + U * 1.2, y, l[2] and C.text or C.dim, l[1], l[2] and F.bold or nil)
        y = y + U * 1.9
    end
    advance(p, U * 11 + U * 0.9)

    local pl = wrapText(L("priv"), cw - U * 2.4)
    local ph = U * 3.2 + #pl * U * 1.3
    local pp_ = beginCard(cw, ph)
    dtext(dl, pp_.x + U * 1.2, pp_.y + U * 0.8, C.amber, L("priv_t"), F.bold)
    for i, l in ipairs(pl) do
        dl:AddText(ImVec2(pp_.x + U * 1.2, pp_.y + U * 1.5 + i * U * 1.3), u32(C.dim), l)
    end
    advance(pp_, ph + U * 0.5)

    local cp_ = beginCard(cw, U * 9.4)
    dtext(dl, cp_.x + U * 1.2, cp_.y + U * 0.8, C.accent, L("credit_t"), F.bold)
    dtext(dl, cp_.x + U * 1.2, cp_.y + U * 2.3, C.text, "Afreldo", F.bold)
    dtext(dl, cp_.x + U * 1.2, cp_.y + U * 4.0, C.dim, "Discord")
    dtext(dl, cp_.x + U * 1.2, cp_.y + U * 5.2, C.blue, DISCORD_URL)
    imgui.SetCursorScreenPos(ImVec2(cp_.x + U * 1.2, cp_.y + U * 6.6))
    if button("copydc", L("copy_link"), false) then
        imgui.SetClipboardText(DISCORD_URL)
        notify(L("link_copied"), "ok")
    end
    advance(cp_, U * 9.4 + U * 0.5)
end

local NAV = {
    { id = "players",  label = "nav_players",  icon = "players" },
    { id = "chat",     label = "nav_chat",     icon = "chat" },
    { id = "settings", label = "nav_settings", icon = "settings" },
    { id = "database", label = "nav_database", icon = "database" },
    { id = "about",    label = "nav_about",    icon = "about" },
}

local function statusInfo()
    if not cfg.enabled then return L("st_off"), C.faint end
    if lastErr then return L(lastErr), C.red end
    if clk() - lastOk < 12 then return L("st_ok"), C.green end
    return L("st_wait"), C.amber
end

local function drawMain(U, W, H)
    local wp = imgui.GetWindowPos()
    local dl = imgui.GetWindowDrawList()
    local HH, SB = U * 3.6, U * 10.5

    dl:AddLine(ImVec2(wp.x, wp.y + HH), ImVec2(wp.x + W, wp.y + HH), u32(C.border), 1)
    imgui.SetCursorScreenPos(wp)
    imgui.InvisibleButton("##drag", ImVec2(W - U * 3.4, HH))
    if imgui.IsItemActive() and imgui.IsMouseDragging(0, 0.0) then
        local d = imgui.GetIO().MouseDelta
        imgui.SetWindowPos(ImVec2(wp.x + d.x, wp.y + d.y))
    end

    local Lg = U * 2.0
    local lx, ly = wp.x + U * 1.2, wp.y + (HH - Lg) / 2
    drawLogo(dl, lx, ly, Lg)
    local nameW = tsize("MonnEt", F.bold)
    local _, nh = tsize("MonnEt", F.bold)
    dtext(dl, lx + Lg + U * 0.8, wp.y + (HH - nh) / 2, C.text, "MonnEt", F.bold)
    dtext(dl, lx + Lg + U * 1.2 + nameW, wp.y + (HH - nh) / 2, C.dim, "Multiplayer")

    local cs = U * 2.2
    local cx0, cy0 = wp.x + W - cs - U * 0.9, wp.y + (HH - cs) / 2
    imgui.SetCursorScreenPos(ImVec2(cx0, cy0))
    local closeClicked = imgui.InvisibleButton("##close", ImVec2(cs, cs))
    if imgui.IsItemHovered() then
        dl:AddRectFilled(ImVec2(cx0, cy0), ImVec2(cx0 + cs, cy0 + cs), u32(C.hover), U * 0.5)
    end
    drawIcon(dl, "close", cx0 + cs / 2, cy0 + cs / 2, U * 0.6, C.dim)
    if closeClicked then ui.win[0] = false end

    local stxt, scol = statusInfo()
    local sw_, sh_ = tsize(stxt)
    local pw, ph = sw_ + U * 2.6, U * 2.0
    local px, py = cx0 - U * 0.8 - pw, wp.y + (HH - ph) / 2
    dl:AddRectFilled(ImVec2(px, py), ImVec2(px + pw, py + ph), u32(C.surface2), ph / 2)
    dl:AddCircleFilled(ImVec2(px + U * 1.0, py + ph / 2), U * 0.3, u32(scol), 12)
    dtext(dl, px + U * 1.7, py + (ph - sh_) / 2, C.dim, stxt)

    dl:AddLine(ImVec2(wp.x + SB, wp.y + HH), ImVec2(wp.x + SB, wp.y + H), u32(C.border), 1)
    local ih = U * 2.9
    for i, n in ipairs(NAV) do
        local nx, ny = wp.x + U * 0.8, wp.y + HH + U * 1.0 + (i - 1) * (ih + U * 0.3)
        imgui.SetCursorScreenPos(ImVec2(nx, ny))
        local clicked = imgui.InvisibleButton("##nav" .. n.id, ImVec2(SB - U * 1.6, ih))
        local hov = imgui.IsItemHovered()
        if clicked then ui.page = n.id end
        local active = (ui.page == n.id)
        if active then
            dl:AddRectFilled(ImVec2(nx, ny), ImVec2(nx + SB - U * 1.6, ny + ih), u32(C.surface2), U * 0.6)
            dl:AddRectFilled(ImVec2(nx, ny + U * 0.7), ImVec2(nx + U * 0.22, ny + ih - U * 0.7), u32(C.accent), U * 0.1)
        elseif hov then
            dl:AddRectFilled(ImVec2(nx, ny), ImVec2(nx + SB - U * 1.6, ny + ih), u32(C.surface), U * 0.6)
        end
        drawIcon(dl, n.icon, nx + U * 1.6, ny + ih / 2, U * 0.62, active and C.accent or C.dim)
        local label = L(n.label)
        local _, lh = tsize(label, F.bold)
        dtext(dl, nx + U * 2.9, ny + (ih - lh) / 2, active and C.text or C.dim, label, active and F.bold or nil)
    end
    dtext(dl, wp.x + U * 1.2, wp.y + H - U * 2.0, C.faint, "v1.0  -  " .. (IS_ANDROID and "Android" or "PC"))

    local pad = U * 1.5
    imgui.SetCursorScreenPos(ImVec2(wp.x + SB + 1, wp.y + HH + 1))
    imgui.BeginChild("##content", ImVec2(W - SB - 2, H - HH - 2), false)
    imgui.SetWindowFontScale(wscale())
    local cp = imgui.GetCursorScreenPos()
    imgui.SetCursorScreenPos(ImVec2(cp.x + pad, cp.y + pad))
    local cw = W - SB - 2 - pad * 2 - U * 0.8
    local chH = H - HH - 2

    if ui.page == "players" then pagePlayers(U, cw)
    elseif ui.page == "chat" then pageChat(U, cw, chH, pad)
    elseif ui.page == "settings" then pageSettings(U, cw)
    elseif ui.page == "database" then pageDatabase(U, cw)
    else pageAbout(U, cw) end

    imgui.Dummy(ImVec2(1, pad))
    touchScroll(U)
    imgui.EndChild()
end

imgui.OnFrame(function() return ui.win[0] end, function(self)
    local sw, sh = getScreenResolution()
    local U = unit()
    applyStyle(U)
    local W = math.min(sw * 0.94, U * 54)
    local H = math.min(sh * 0.90, U * 32)
    imgui.SetNextWindowSize(ImVec2(W, H), imgui.Cond.Always)
    imgui.SetNextWindowPos(ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, ImVec2(0.5, 0.5))

    ui.activeRow = false
    imgui.PushStyleColor(imgui.Col.WindowBg, C.bg)
    imgui.PushStyleColor(imgui.Col.Border, C.border)
    if imgui.Begin("##monnet_main", nil, MAIN_FLAGS) then
        imgui.SetWindowFontScale(wscale())
        pf(F.reg)
        drawMain(U, W, H)
        pp(F.reg)
    end
    imgui.End()
    imgui.PopStyleColor(2)

    if not imgui.IsMouseDown(0) then ui.dragMoved = false end
end)

function main()
    while not isSampAvailable() do wait(100) end

    startWorkers()

    local function openMenu(arg)
        ui.win[0] = not ui.win[0]
    end
    sampRegisterChatCommand("monnet.settings", openMenu)
    sampRegisterChatCommand("monnet", openMenu)
    sampRegisterChatCommand("gc", sendGlobal)
    sampRegisterChatCommand("gfind", function(arg)
        arg = trim(arg or "")
        if arg == "" then
            ui.page, ui.win[0] = "players", true
            return
        end
        if not (cfg.enabled and cfg.seeOthers) then
            notify(L("gfind_off"), "warn")
            return
        end
        local q = arg:lower()
        for nick in pairs(ghosts) do
            if nick:lower():find(q, 1, true) then
                markGhost(nick)
                return
            end
        end
        notify(L("gfind_none"), "warn")
    end)

    if HAS_EFFIL then
        if HAS_FASTHTTP then
            notify(L("toast_fast"), "info")
        else
            notify(L("toast_slow"), "warn")
        end
    elseif okReq or HAS_FASTHTTP then
        notify(L("toast_fb"), "warn")
        lua_thread.create(fallbackLoop)
    else
        notify(L("toast_nolib"), "error")
        sampAddChatMessage(L("chat_nolib"), -1)
    end

    if HAS_EFFIL then
        lua_thread.create(function()
            while true do pumpResults(); wait(0) end
        end)
    end

    lua_thread.create(function()
        while true do
            if dirty then dirty = false; saveCfg() end
            wait(500)
        end
    end)

    lua_thread.create(function()
        while true do
            if cfg.enabled and cfg.shareMe and sampIsLocalPlayerSpawned() then sendHeartbeat() end
            wait(HEARTBEAT * 1000)
        end
    end)

    lua_thread.create(function()
        while true do
            if cfg.enabled and ui.win[0] then pollList() end
            wait(POLL_LIST * 1000)
        end
    end)

    lua_thread.create(function()
        while true do
            if chatActive() and sampIsLocalPlayerSpawned() then pollChat() end
            wait(math.floor(POLL_CHAT * 1000))
        end
    end)

    lua_thread.create(function()
        while true do
            if cfg.enabled and cfg.shareMe and sampIsLocalPlayerSpawned() then sampleLive() end
            wait(100)
        end
    end)

    lua_thread.create(function()
        while true do
            if cfg.enabled and cfg.shareMe and sampIsLocalPlayerSpawned() then sendLive() end
            wait(math.floor(LIVE_SEND * 1000))
        end
    end)

    lua_thread.create(function()
        while true do
            if cfg.enabled and cfg.seeOthers and sampIsLocalPlayerSpawned()
               and not (HAS_STREAM and streamUp) then
                pollLive()
            end
            wait(math.floor(LIVE_POLL * 1000))
        end
    end)

    lua_thread.create(function()
        while true do
            if cfg.enabled and cfg.seeOthers and sampIsLocalPlayerSpawned() then
                local ok = pcall(updateGhosts)
                if not ok then wait(300) end
            end
            wait(0)
        end
    end)

    -- cadangan kalau samp.events ga ada: deteksi lompat dari status di udara (hanya saat mulai lompat)
    if not HAS_SYNC then
        lua_thread.create(function()
            local was = false
            while true do
                local ok, air = pcall(isCharInAir, PLAYER_PED)
                air = (ok and air) and true or false
                if air and not was then airLatch = true end
                was = air
                wait(0)
            end
        end)
    end

    wait(-1)
end

function onScriptTerminate(s)
    if s == thisScript() then
        pcall(clearAllGhosts)
        if findBlip then pcall(removeBlip, findBlip) end
        if HAS_EFFIL then
            pcall(removeSelfAt, getDB())
            if streamCtl then streamCtl:push({ stop = true }) end
            jobs:push({ stop = true })
            jobs:push({ stop = true })
            jobs:push({ stop = true })
        elseif okReq then
            pcall(function()
                local nick = myNick()
                if nick then
                    local db = getDB()
                    requestsLib.request('DELETE', db .. "/players/" .. safeKey(nick) .. ".json", { timeout = 3 })
                    requestsLib.request('DELETE', db .. "/live/" .. safeKey(nick) .. ".json", { timeout = 3 })
                end
            end)
        end
        saveCfg()
    end
end
