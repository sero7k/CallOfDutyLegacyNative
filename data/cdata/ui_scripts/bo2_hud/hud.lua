-- Black Ops II's match HUD over MWR's (CallOfDutyLegacy).
--
-- Replaces MWR's team scores, weapon box, action slots, perks and experience
-- bar with the layout of CodLegacy's in-game HUD (Black Ops II's): the score
-- bar at the top centre, the ammo box and the scorestreak column at the
-- bottom right, the player's name and experience bar at the bottom left, and
-- the frame-rate box at the top right. MWR's minimap, obituary, hit markers,
-- damage and low-health overlays, hints, use bar, splashes, points popups,
-- capture widgets, scoreboard and kill cam stay as they are: they already do
-- what the BO2 HUD shows for those.
--
-- Positions are in the HUD's 1280 x 720 space, measured from CodLegacy's HUD
-- at 1920 x 1080 (x 2/3).

local mphud = luiglobals.require("LUI.mp_hud.MPHud")

local function white()
    return luiglobals.RegisterMaterial("white")
end

local function say(...)
    pcall(print, "[bo2_hud]", ...)
end

local function try(f, ...)
    local ok, a, b, c = pcall(f, ...)
    if ok then
        return a, b, c
    end
    return nil
end

local colors = {
    panel = { r = 0.10, g = 0.11, b = 0.12 },
    panel_alpha = 0.72,
    track = { r = 0.32, g = 0.33, b = 0.35 },
    friendly = { r = 0.33, g = 0.66, b = 0.95 },
    enemy = { r = 0.92, g = 0.30, b = 0.25 },
    text = { r = 0.92, g = 0.92, b = 0.92 },
    dim = { r = 0.62, g = 0.62, b = 0.62 },
    fps = { r = 0.30, g = 0.95, b = 0.45 },
}

local function rect(state, color, alpha)
    state.material = state.material or white()
    state.color = color
    state.alpha = alpha or 1
    return LUI.UIImage.new(state)
end

local function text(state, font, height, color, align)
    state.font = font.Font
    state.height = height
    state.color = color or colors.text
    state.alignment = align or LUI.Alignment.Left
    return LUI.UIText.new(state)
end

local function team_name(team)
    if team == Teams.axis then
        return Engine.ToUpperCase(Engine.Localize(Engine.GetDvarString("g_TeamName_Axis")))
    elseif team == Teams.allies then
        return Engine.ToUpperCase(Engine.Localize(Engine.GetDvarString("g_TeamName_Allies")))
    end
    return ""
end

local function my_team()
    local team = Game.GetPlayerTeam()
    if team == Teams.spectator then
        team = try(Game.GetPlayerTeam, Game.GetPlayerstateClientnum()) or team
    end
    return team
end

-- The score bar: friendly name, bar and score on the left, the timer between
-- the two team emblems, the enemy's on the right, and TIED / WINNING / LOSING
-- under the timer. Children are placed from the screen's centre (no
-- horizontal anchors: left and right are offsets from the middle).
local BAR_W = 174

local function centred(l, r, top, height)
    return { topAnchor = true, top = top, height = height, left = l, right = r }
end

local function scorebar()
    local root = LUI.UIElement.new({
        topAnchor = true,
        leftAnchor = true,
        rightAnchor = true,
        top = 8,
        left = 0,
        right = 0,
        height = 56,
    })

    local font = CoD.TextSettings.TitleFontSmallBold

    -- Timer box.
    root:addElement(rect(centred(-40, 40, 2, 38), colors.panel, colors.panel_alpha))
    local timer = LUI.UICountdown.new({ endTime = "round_end" })
    local ts = centred(-40, 40, 9, 24)
    ts.font = CoD.TextSettings.TitleFontMedium.Font
    ts.alignment = LUI.Alignment.Center
    ts.color = colors.text
    timer:registerAnimationState("default", ts)
    timer:animateToState("default")
    root:addElement(timer)

    -- Team emblems either side of the timer.
    local function emblem(l)
        local box = LUI.UIElement.new(centred(l, l + 38, 2, 38))
        box:addElement(rect({ topAnchor = true, bottomAnchor = true, leftAnchor = true, rightAnchor = true, top = 0, bottom = 0, left = 0, right = 0 }, colors.panel, colors.panel_alpha))
        local icon = LUI.UIImage.new({ topAnchor = true, leftAnchor = true, top = 3, left = 3, width = 32, height = 32, alpha = 1 })
        box:addElement(icon)
        box.icon = icon
        root:addElement(box)
        return box
    end
    local friendly_emblem = emblem(-80)
    local enemy_emblem = emblem(42)

    -- Names, bars and scores. The friendly side runs left of the friendly
    -- emblem (x -84 outward), the enemy side right of the enemy emblem.
    local function side(right_side)
        local s = { right_side = right_side }
        local inner = 84
        local outer = inner + BAR_W
        if right_side then
            s.name = text(centred(inner, outer, 10, 14), font, 14, colors.text, LUI.Alignment.Left)
            root:addElement(rect(centred(inner, outer, 31, 5), colors.track, 0.85))
            s.score = text(centred(outer + 4, outer + 44, 27, 12), font, 12, colors.text, LUI.Alignment.Left)
        else
            s.name = text(centred(-outer, -inner, 10, 14), font, 14, colors.text, LUI.Alignment.Right)
            root:addElement(rect(centred(-outer, -inner, 31, 5), colors.track, 0.85))
            s.score = text(centred(-outer - 44, -outer - 4, 27, 12), font, 12, colors.text, LUI.Alignment.Right)
        end
        root:addElement(s.name)
        root:addElement(s.score)
        s.inner = inner
        s.fill = LUI.UIImage.new(centred(0, 0, 31, 5))
        root:addElement(s.fill)
        return s
    end
    local friendly = side(false)
    local enemy = side(true)

    local status = text(centred(-60, 60, 44, 11), CoD.TextSettings.BodyFontVeryTiny, 11, colors.dim, LUI.Alignment.Center)
    root:addElement(status)

    -- A bar fills from the emblem outward.
    local function set_fill(s, value, limit)
        local frac = 0
        if limit and limit > 0 then
            frac = math.max(0, math.min(1, value / limit))
        end
        local w = math.floor(BAR_W * frac + 0.5)
        local st
        if s.right_side then
            st = centred(s.inner, s.inner + w, 31, 5)
        else
            st = centred(-s.inner - w, -s.inner, 31, 5)
        end
        st.material = white()
        st.color = s.right_side and colors.enemy or colors.friendly
        st.alpha = w > 0 and 1 or 0
        if s.last_w ~= w then
            s.last_w = w
            s.fill:registerAnimationState("v", st)
            s.fill:animateToState("v")
        end
    end

    root.update = function()
        local mine = my_team()
        local ffa = (mine == Teams.free) or try(GameX.gameModeIsFFA)
        local limit = Engine.GetDvarInt("ui_scorelimit")
        local a, b
        if ffa then
            friendly.name:setText(Engine.ToUpperCase(Game.GetPlayerName() or ""))
            enemy.name:setText("LEADER")
            a = try(Game.GetPlayerScore, Game.GetPlayerClientnum()) or 0
            local top = try(GameX.GetPlayerScoreInfoAtRankForGameMode, Teams.free, 1, GameX.GetGameMode())
            b = (type(top) == "table" and (top.score or top.points)) or a
            friendly_emblem:hide()
            enemy_emblem:hide()
        else
            local other = otherTeamLookup[mine] or Teams.axis
            friendly.name:setText(team_name(mine))
            enemy.name:setText(team_name(other))
            a = Game.GetTeamScore(mine) or 0
            b = Game.GetTeamScore(other) or 0
            friendly_emblem:show()
            enemy_emblem:show()
            local fi = Engine.GetDvarString(mine == Teams.axis and "g_TeamIcon_Axis" or "g_TeamIcon_Allies")
            local ei = Engine.GetDvarString(other == Teams.axis and "g_TeamIcon_Axis" or "g_TeamIcon_Allies")
            if fi ~= friendly_emblem.icon_name then
                friendly_emblem.icon_name = fi
                try(function() friendly_emblem.icon:setImage(luiglobals.RegisterMaterial(fi)) end)
            end
            if ei ~= enemy_emblem.icon_name then
                enemy_emblem.icon_name = ei
                try(function() enemy_emblem.icon:setImage(luiglobals.RegisterMaterial(ei)) end)
            end
        end
        friendly.score:setText(tostring(a))
        enemy.score:setText(tostring(b))
        set_fill(friendly, a, limit)
        set_fill(enemy, b, limit)
        if a == b then
            status:setText("TIED")
        elseif a > b then
            status:setText("WINNING")
        else
            status:setText("LOSING")
        end
    end

    return root
end

-- The ammo box: clip (large), stock (small), lethal and tactical counts, the
-- weapon's name above it.
local function ammobox()
    local root = LUI.UIElement.new({
        bottomAnchor = true,
        rightAnchor = true,
        bottom = -18,
        right = -14,
        width = 112,
        height = 58,
    })
    root:addElement(rect({ bottomAnchor = true, rightAnchor = true, bottom = 0, right = 0, width = 112, height = 34 }, colors.panel, colors.panel_alpha))

    local big = CoD.TextSettings.TitleFontMediumLarge
    local small = CoD.TextSettings.TitleFontSmallBold

    root.clip = text({ bottomAnchor = true, leftAnchor = true, left = 6, bottom = -4, width = 36, height = 28 }, big, 28, colors.text, LUI.Alignment.Left)
    root:addElement(root.clip)
    root:addElement(rect({ bottomAnchor = true, leftAnchor = true, left = 40, bottom = -8, width = 1, height = 18 }, colors.dim, 0.8))
    root.stock = text({ bottomAnchor = true, leftAnchor = true, left = 45, bottom = -9, width = 30, height = 16 }, small, 16, colors.dim, LUI.Alignment.Left)
    root:addElement(root.stock)

    -- Lethal and tactical: their pictures from the engine, counts beside.
    local function offhand(left, image_bind, count_watch)
        local icon = LUI.UIImage.new({ bottomAnchor = true, leftAnchor = true, left = left, bottom = -10, width = 12, height = 12, alpha = 1 })
        try(function() icon:setupUIBindImage(image_bind) end)
        root:addElement(icon)
        local count = text({ bottomAnchor = true, leftAnchor = true, left = left + 13, bottom = -10, width = 10, height = 11 }, CoD.TextSettings.BodyFontVeryTiny, 11, colors.text, LUI.Alignment.Left)
        root:addElement(count)
        local watch = LUI.UIElement.new()
        try(function() watch:setupUIIntWatch(count_watch) end)
        watch:registerEventHandler("int_watch_alert", function(element, event)
            count:setText(tostring(event.newValue or 0))
            icon:setAlpha((event.newValue or 0) > 0 and 1 or 0.4)
        end)
        root:addElement(watch)
    end
    offhand(76, "FragMaterial", "LethalCount")
    offhand(92, "FlashMaterial", "TacticalCount")

    root.name = text({ bottomAnchor = true, rightAnchor = true, right = 0, bottom = -38, width = 160, height = 12 }, small, 12, colors.text, LUI.Alignment.Right)
    root:addElement(root.name)

    root.update = function()
        local clip = try(Game.GetPlayerClipAmmo, 1) or 0
        local stock = try(Game.GetPlayerStockAmmo) or 0
        root.clip:setText(tostring(clip))
        root.stock:setText(tostring(stock))
        local name = try(Game.GetPlayerWeaponDisplayName) or ""
        root.name:setText(Engine.ToUpperCase(name))
    end

    return root
end

-- The scorestreak column above the ammo box (MWR's three action slots).
local function streaks()
    local root = LUI.UIElement.new({
        bottomAnchor = true,
        rightAnchor = true,
        bottom = -82,
        right = -14,
        width = 36,
        height = 116,
    })
    local slots = { 0, 2, 3 }
    root.icons = {}
    for i = 1, 3 do
        local top = (i - 1) * 40
        root:addElement(rect({ topAnchor = true, rightAnchor = true, top = top, right = 0, width = 36, height = 36 }, colors.panel, 0.55))
        local icon = LUI.UIImage.new({ topAnchor = true, rightAnchor = true, top = top + 3, right = -3, width = 30, height = 30, alpha = 0 })
        root:addElement(icon)
        root.icons[i] = { image = icon, slot = slots[i] }
    end
    root.update = function()
        for _, s in ipairs(root.icons) do
            local mat = try(Game.GetPlayerActionSlotMaterial, s.slot)
            if mat ~= s.material then
                s.material = mat
                if mat then
                    s.image:setImage(mat)
                    s.image:setAlpha(1)
                else
                    s.image:setAlpha(0)
                end
            end
            if mat then
                local active = try(Game.GetPlayerActionSlotActive, s.slot)
                s.image:setAlpha(active and 1 or 0.45)
            end
        end
    end
    return root
end

-- The player's name and experience bar at the bottom left.
local function playercard()
    local root = LUI.UIElement.new({
        bottomAnchor = true,
        leftAnchor = true,
        bottom = -16,
        left = 16,
        width = 140,
        height = 14,
    })
    root.name = text({ topAnchor = true, leftAnchor = true, top = 0, left = 0, width = 140, height = 9 }, CoD.TextSettings.BodyFontVeryTiny, 9, colors.text, LUI.Alignment.Left)
    root:addElement(root.name)
    root:addElement(rect({ topAnchor = true, leftAnchor = true, top = 11, left = 0, width = 140, height = 2 }, colors.track, 0.6))
    root.xp = LUI.UIImage.new({ topAnchor = true, leftAnchor = true, top = 11, left = 0, width = 0, height = 2, material = white(), color = colors.text, alpha = 1 })
    root:addElement(root.xp)
    root.update = function()
        root.name:setText(Game.GetPlayerName() or "")
        local pct = try(Game.GetOmnvar, "ui_player_xp_pct") or 0
        if pct > 1 then
            pct = pct / 100
        end
        local w = math.floor(140 * math.max(0, math.min(1, pct)) + 0.5)
        root.xp:registerAnimationState("v", { topAnchor = true, leftAnchor = true, top = 11, left = 0, width = w, height = 2, material = white(), color = colors.text, alpha = 1 })
        root.xp:animateToState("v")
    end
    return root
end

-- The frame-rate box at the top right.
local function fpsbox()
    local root = LUI.UIElement.new({
        topAnchor = true,
        rightAnchor = true,
        top = 5,
        right = -5,
        width = 130,
        height = 40,
    })
    root:addElement(rect({ topAnchor = true, bottomAnchor = true, leftAnchor = true, rightAnchor = true }, colors.panel, colors.panel_alpha))
    root.fps = text({ topAnchor = true, leftAnchor = true, top = 4, left = 5, width = 120, height = 14 }, CoD.TextSettings.TitleFontSmallBold, 14, colors.fps, LUI.Alignment.Left)
    root:addElement(root.fps)
    root.ms = text({ topAnchor = true, leftAnchor = true, top = 21, left = 5, width = 120, height = 10 }, CoD.TextSettings.BodyFontVeryTiny, 10, colors.fps, LUI.Alignment.Left)
    root:addElement(root.ms)
    root.update = function()
        local fps = try(function() return game:getfps() end) or 0
        root.fps:setText(tostring(fps) .. " FPS")
        if fps > 0 then
            root.ms:setText(string.format("Frame  %.1f ms", 1000 / fps))
        end
    end
    return root
end

local function hidden()
    local root = Engine.GetLuiRoot()
    if root:AnyActiveMenusInStack() then
        return true
    end
    if Game.InKillCam() then
        return true
    end
    local session = try(Game.GetOmnvar, "ui_session_state")
    if session == "spectator" then
        return false
    end
    return (try(Game.GetPlayerHealth) or 1) <= 0
end

-- MWR's widgets the BO2 HUD replaces.
local replaced = { "teamScores", "weaponInfo", "actionSlot", "experienceBar", "perks" }

local function build(hud)
    for _, key in ipairs(replaced) do
        local w = hud[key]
        if w then
            if hud.allWidgets then
                for i = #hud.allWidgets, 1, -1 do
                    if hud.allWidgets[i] == w then
                        table.remove(hud.allWidgets, i)
                    end
                end
            end
            try(function() w:close() end)
            hud[key] = nil
        end
    end

    local layer = LUI.UIElement.new({
        topAnchor = true,
        bottomAnchor = true,
        leftAnchor = true,
        rightAnchor = true,
    })
    layer:registerAnimationState("on", { alpha = 1 })
    layer:registerAnimationState("off", { alpha = 0 })

    local parts = {}
    local hardcore = try(GameX.IsHardcoreMode)
    local function add(name, make)
        local ok, part = pcall(make)
        if ok and part then
            local added, err = pcall(function() layer:addElement(part) end)
            if added then
                table.insert(parts, part)
                return
            end
            say(name .. " add failed: " .. tostring(err))
        else
            say(name .. " failed: " .. tostring(part))
        end
    end
    if not hardcore then
        add("scorebar", scorebar)
        add("ammobox", ammobox)
        add("streaks", streaks)
    end
    add("playercard", playercard)
    add("fpsbox", fpsbox)
    say("built " .. #parts .. " parts")

    local tick = function()
        if hidden() then
            if layer.state ~= "off" then
                layer.state = "off"
                layer:animateToState("off")
            end
            return
        end
        if layer.state ~= "on" then
            layer.state = "on"
            layer:animateToState("on")
        end
        for _, p in ipairs(parts) do
            if p.update then
                try(p.update)
            end
        end
    end

    layer:addElement(LUI.UITimer.new(50, "bo2_hud_tick"))
    layer:registerEventHandler("bo2_hud_tick", function()
        local ok, err = pcall(tick)
        if not ok and not layer.warned then
            layer.warned = true
            say("tick error: " .. tostring(err))
        end
    end)
    pcall(tick)

    local target = (hud.static and hud.static.scalable) or hud.static or hud
    target:addElement(layer)
    hud.bo2 = layer
end

LUI.onmenuopen("mp_hud", function(hud)
    if Engine.InFrontend() then
        return
    end
    say("mp_hud opened")
    local ok, err = pcall(build, hud)
    if not ok then
        say("build failed: " .. tostring(err))
    end
end)

say("loaded")

