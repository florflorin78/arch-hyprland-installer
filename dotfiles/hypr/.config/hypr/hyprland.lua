-- ~/.config/hypr/hyprland.lua  —  Hyprland >= 0.55 (config în Lua; hyprland.conf e deprecat)
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- Dacă ceva nu merge după un update de Hyprland:  hyprctl configerrors
-- Lista tuturor shortcut-urilor (generată automat din acest fișier):  SUPER + F1

local mod      = "SUPER"
local terminal = "kitty"
local home     = os.getenv("HOME") or ""
local bin      = home .. "/.local/bin/"

------------------------------------------------------------------ MONITOR
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })

------------------------------------------------------------------ ENV
hl.env("PATH", bin .. ":" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")
hl.env("TERMINAL", terminal)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("LIBVA_DRIVER_NAME", "iHD")            -- accelerare video pe Intel HD 520
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

------------------------------------------------------------------ AUTOSTART
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("swaybg -i " .. home .. "/Pictures/wallpapers/badass-dark.png -m fill")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(bin .. "power-watch")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
    hl.exec_cmd(bin .. "first-run")
end)

------------------------------------------------------------------ MOD ENERGIE
-- Scriptul ~/.local/bin/power-watch scrie aici "normal" | "battery" | "eco" și face `hyprctl reload`.
--   normal  = pe priză: blur + umbre + animații
--   battery = pe baterie: fără blur/umbre
--   eco     = SUPER+F10: fără blur/umbre/animații
local function read_power_mode()
    local path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-power-mode"
    local ok, f = pcall(io.open, path, "r")
    if ok and f then
        local m = f:read("*l")
        f:close()
        return m or "normal"
    end
    return "normal"
end
local power_mode = read_power_mode()
local effects    = (power_mode == "normal")
local animate    = (power_mode ~= "eco")

------------------------------------------------------------------ ASPECT
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(ff2e63ff)", "rgba(08d9d6ff)" }, angle = 45 },
            inactive_border = "rgba(2a2a3aaa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.96,
        shadow = {
            enabled = effects,
            range = 16,
            render_power = 3,
            color = "rgba(ff2e6340)",
        },
        blur = {
            enabled = effects,
            size = 4,
            passes = 2,
            vibrancy = 0.17,
        },
    },

    animations = { enabled = animate },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },

    input = {
        kb_layout = "us,ro",
        kb_options = "grp:alt_shift_toggle,caps:escape",  -- Alt+Shift schimbă layout; CapsLock = Esc (vim)
        repeat_rate = 40,
        repeat_delay = 250,
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },
})

-- Animații fluide: curbe fără "săritură", viteze mici = mișcare rapidă și lină
hl.curve("smooth", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("snappy", { type = "bezier", points = { { 0.16, 1 }, { 0.30, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 6,   bezier = "smooth" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4,   bezier = "snappy", style = "popin 85%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3.5, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4,   bezier = "smooth" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "smooth" })
hl.animation({ leaf = "border",        enabled = true, speed = 6,   bezier = "smooth" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.5, bezier = "snappy", style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,   bezier = "snappy", style = "slide" })

-- Gest: 3 degete stânga/dreapta = alt workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

------------------------------------------------------------------ REGULI FEREASTRĂ
-- ferestre mici de utilitare (nmtui, mixer, bluetooth) apar plutitor, centrat
hl.window_rule({
    name = "float-term",
    match = { class = "^float-term$" },
    float = true,
    center = true,
    size = { "(monitor_w*0.6)", "(monitor_h*0.6)" },
})
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
-- nu bloca ecranul cât rulează un video în fullscreen
hl.window_rule({
    name = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

------------------------------------------------------------------ SHORTCUT-URI
-- Toate au descriere => apar în SUPER+F1 (cheatsheet automat).
local function bind(keys, dsp, desc, flags)
    flags = flags or {}
    flags.description = desc
    hl.bind(keys, dsp, flags)
end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end
local function float_term(cmd) return run(terminal .. " --class float-term -e " .. cmd) end

-- Aplicații
bind(mod .. " + Return",           run(terminal),                                 "Terminal (kitty)")
bind(mod .. " + D",                run("pkill wofi || wofi --show drun"),         "Launcher aplicații")
bind(mod .. " + SHIFT + D",        run("pkill wofi || wofi --show run"),          "Rulează comandă")
bind(mod .. " + B",                run("firefox"),                                "Firefox")
bind(mod .. " + SHIFT + B",        run("qutebrowser"),                            "Qutebrowser (browser din tastatură)")
bind(mod .. " + E",                run(terminal .. " -e yazi"),                   "File manager (yazi)")
bind(mod .. " + C",                run("code"),                                   "VS Code")
bind(mod .. " + N",                float_term("nmtui"),                           "Rețea (nmtui)")
bind(mod .. " + A",                float_term("pulsemixer"),                      "Mixer audio")
bind(mod .. " + Y",                float_term("bluetui"),                         "Bluetooth")
bind(mod .. " + SHIFT + T",        float_term("btop"),                            "Monitor sistem (btop)")
bind(mod .. " + V",                run(bin .. "clipboard-menu"),                  "Istoric clipboard")
bind(mod .. " + M",                run("wl-kbptr"),                               "Mouse din tastatură (hint-uri)")
bind(mod .. " + F1",               run(bin .. "keybinds-help"),                   "Lista shortcut-uri")
bind(mod .. " + F10",              run(bin .. "eco-mode"),                        "Eco mode ON/OFF (baterie maximă)")

-- Sesiune
bind(mod .. " + Escape",           run("loginctl lock-session"),                  "Blochează ecranul")
bind(mod .. " + SHIFT + E",        run(bin .. "powermenu"),                       "Meniu oprire/repornire/suspend")
bind("XF86PowerOff",               run(bin .. "powermenu"),                       "Buton power: meniu")
bind(mod .. " + SHIFT + R",        run("hyprctl reload"),                         "Reîncarcă config Hyprland")

-- Ferestre
bind(mod .. " + Q",                hl.dsp.window.close(),                         "Închide fereastra")
bind(mod .. " + F",                hl.dsp.window.fullscreen(),                    "Fullscreen")
bind(mod .. " + Space",            hl.dsp.window.float({ action = "toggle" }),    "Plutitor / tiled")
bind(mod .. " + P",                hl.dsp.window.pseudo(),                        "Pseudotile")
bind(mod .. " + T",                hl.dsp.layout("togglesplit"),                  "Schimbă orientarea split")
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end, { description = "Următoarea fereastră (Alt+Tab)" })

-- Focus (vim + săgeți)
local dirs = { h = "left", j = "down", k = "up", l = "right" }
for key, d in pairs(dirs) do
    bind(mod .. " + " .. key,                    hl.dsp.focus({ direction = d }),         "Focus " .. d)
    bind(mod .. " + SHIFT + " .. key,            hl.dsp.window.move({ direction = d }),   "Mută fereastra " .. d)
end
bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }),  "Focus stânga")
bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), "Focus dreapta")
bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }),    "Focus sus")
bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }),  "Focus jos")

-- Redimensionare (apasă și ține: se repetă)
local step = 40
bind(mod .. " + CTRL + h", hl.dsp.window.resize({ x = -step, y = 0, relative = true }), "Redimensionează stânga", { repeating = true })
bind(mod .. " + CTRL + l", hl.dsp.window.resize({ x = step,  y = 0, relative = true }), "Redimensionează dreapta", { repeating = true })
bind(mod .. " + CTRL + k", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), "Redimensionează sus", { repeating = true })
bind(mod .. " + CTRL + j", hl.dsp.window.resize({ x = 0, y = step,  relative = true }), "Redimensionează jos", { repeating = true })

-- Workspace-uri 1..10
for i = 1, 10 do
    local key = i % 10
    bind(mod .. " + " .. key,           hl.dsp.focus({ workspace = i }),          "Workspace " .. i)
    bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }),    "Mută fereastra pe workspace " .. i)
end
bind(mod .. " + Tab",               hl.dsp.focus({ workspace = "e+1" }), "Workspace următor")
bind(mod .. " + SHIFT + Tab",       hl.dsp.focus({ workspace = "e-1" }), "Workspace anterior")
bind(mod .. " + bracketright",      hl.dsp.focus({ workspace = "e+1" }), "Workspace următor")
bind(mod .. " + bracketleft",       hl.dsp.focus({ workspace = "e-1" }), "Workspace anterior")
bind(mod .. " + S",                 hl.dsp.workspace.toggle_special("magic"),                  "Scratchpad ON/OFF")
bind(mod .. " + SHIFT + S",         hl.dsp.window.move({ workspace = "special:magic" }),       "Trimite fereastra în scratchpad")

-- Screenshot
bind("Print",                       run(bin .. "screenshot full"),   "Screenshot ecran întreg")
bind(mod .. " + Print",             run(bin .. "screenshot region"), "Screenshot regiune")

-- Taste Fn ThinkPad (funcționează și cu ecranul blocat)
local fn = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",   run(bin .. "osd volume up"),     "Volum +",            fn)
bind("XF86AudioLowerVolume",   run(bin .. "osd volume down"),   "Volum -",            fn)
bind("XF86AudioMute",          run(bin .. "osd volume mute"),   "Mute",               { locked = true })
bind("XF86AudioMicMute",       run(bin .. "osd mic"),           "Mute microfon",      { locked = true })
bind("XF86MonBrightnessUp",    run(bin .. "osd brightness up"),   "Luminozitate +",   fn)
bind("XF86MonBrightnessDown",  run(bin .. "osd brightness down"), "Luminozitate -",   fn)
bind("XF86AudioPlay",          run("playerctl play-pause"),     "Play/Pause",         { locked = true })
bind("XF86AudioNext",          run("playerctl next"),           "Următoarea piesă",   { locked = true })
bind("XF86AudioPrev",          run("playerctl previous"),       "Piesa anterioară",   { locked = true })

-- Mouse (opțional): SUPER + click stânga = mută, click dreapta = redimensionează
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
