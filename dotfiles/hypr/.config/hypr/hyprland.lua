-- Hyprland >= 0.55 Lua config. Errors: hyprctl configerrors. All shortcuts: SUPER + F1

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
hl.env("LIBVA_DRIVER_NAME", "iHD")            -- Intel HD 520 video acceleration
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")    -- Java apps (Ghidra, ZAP) stay blank in tiling WMs without it

------------------------------------------------------------------ AUTOSTART
hl.on("hyprland.start", function()
    hl.exec_cmd(bin .. "wallpaper")
    -- full env to dbus/systemd: without it the portals time out and GTK/Electron apps take ~25s to open
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("udiskie --tray --notify")   -- automount USB drives
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(bin .. "power-watch")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
    hl.exec_cmd(bin .. "first-run")
end)

------------------------------------------------------------------ POWER MODE
-- power-watch writes "normal" | "battery" | "eco" here and reloads.
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
local effects    = false   -- blur/shadows off: the HD 520 stays smooth
local animate    = (power_mode ~= "eco")

------------------------------------------------------------------ APPEARANCE
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(e5c95aff)", "rgba(4fb8c4ff)" }, angle = 45 },
            inactive_border = "rgba(2a3142aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = effects,
            range = 10,
            render_power = 3,
            color = "rgba(e5c95a40)",
        },
        blur = {
            enabled = effects,
            size = 3,
            passes = 1,
            vibrancy = 0.17,
        },
    },

    animations = { enabled = animate },

    dwindle = { preserve_split = true },

    -- no "Hyprland updated" window and no donation popup after updates
    ecosystem = { no_update_news = true, no_donation_nag = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },

    input = {
        kb_layout = "us,ro",
        kb_options = "grp:alt_shift_toggle",  -- Alt+Shift switches layout. No caps:escape: Esc clears the hyprlock password field
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

hl.curve("smooth", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("snappy", { type = "bezier", points = { { 0.16, 1 }, { 0.30, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 3,   bezier = "smooth" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 2.5, bezier = "snappy", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2,   bezier = "smooth", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 2.5,   bezier = "smooth" })
hl.animation({ leaf = "fade",          enabled = true, speed = 2,   bezier = "smooth" })
hl.animation({ leaf = "border",        enabled = true, speed = 3,   bezier = "smooth" })
hl.animation({ leaf = "layers",        enabled = true, speed = 2, bezier = "snappy", style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.5,   bezier = "snappy", style = "slide" })

-- 3-finger swipe = switch workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

------------------------------------------------------------------ WINDOW RULES
-- utility terminals (nmtui, mixer, ...) float centered
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
-- no auto-lock while fullscreen
hl.window_rule({
    name = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

------------------------------------------------------------------ KEYBINDS
-- Every bind has a description, so it shows up in SUPER+F1.
local function bind(keys, dsp, desc, flags)
    flags = flags or {}
    flags.description = desc
    hl.bind(keys, dsp, flags)
end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end
local function float_term(cmd) return run(terminal .. " --class float-term -e " .. cmd) end

-- Apps
bind(mod .. " + Return",           run(terminal),                                 "Terminal (kitty)")
bind(mod .. " + D",                run("pkill wofi || wofi --show drun"),         "App launcher (search by name)")
bind(mod .. " + A",                run(bin .. "apps-menu"),                       "Apps by category (with descriptions)")
bind(mod .. " + H",                run(bin .. "keybinds-help"),                   "Help: all keyboard shortcuts")
bind(mod .. " + F1",               run(bin .. "help"),                            "Help center (shortcuts, apps guide, Linux basics)")
bind(mod .. " + SHIFT + D",        run("pkill wofi || wofi --show run"),          "Run command")
bind(mod .. " + B",                run(bin .. "browser"),                         "Browser (Zen)")
bind(mod .. " + CTRL + B",         run("firefox"),                                "Firefox (fallback)")
bind(mod .. " + X",                run(terminal .. " -e claude"),                 "Claude Code (AI assistant in the terminal)")
bind(mod .. " + SHIFT + X",        run(bin .. "browser https://claude.ai"),       "Claude in browser (claude.ai)")
bind(mod .. " + CTRL + N",         run(bin .. "nightlight"),                      "Night light on/off")
bind(mod .. " + CTRL + P",         run("hyprpicker -a"),                          "Color picker (copies color)")
bind(mod .. " + CTRL + M",         run("makoctl dismiss --all"),                  "Dismiss all notifications")
bind(mod .. " + CTRL + R",         run("makoctl restore"),                        "Restore last notification")
bind(mod .. " + CTRL + D",         run(bin .. "dnd toggle"),                      "Do not disturb on/off")
bind(mod .. " + W",                run(bin .. "wallpaper next"),                  "Next wallpaper")
bind(mod .. " + SHIFT + W",         run(bin .. "rain toggle"),                     "Live data rain on/off (AC only)")
bind(mod .. " + equal",            float_term("qalc"),                            "Calculator (qalc)")
bind(mod .. " + CTRL + Return",    run(terminal .. " --class float-term"),        "Floating terminal")
bind(mod .. " + E",                run(terminal .. " -e yazi"),                   "File manager (yazi)")
bind(mod .. " + C",                run("code"),                                   "VS Code (IDE)")
bind(mod .. " + J",                run(bin .. "notebooks"),                     "JupyterLab (notebooks)")
bind(mod .. " + N",                float_term("nmtui"),                           "Network (nmtui)")
bind(mod .. " + SHIFT + A",        float_term("pulsemixer"),                      "Audio mixer")
bind(mod .. " + Y",                float_term("bluetui"),                         "Bluetooth")
bind(mod .. " + SHIFT + T",        float_term("btop"),                            "System monitor (btop)")
bind(mod .. " + V",                run(bin .. "clipboard-menu"),                  "Clipboard history")
bind(mod .. " + M",                run("wl-kbptr"),                               "Mouse from keyboard (hints)")
bind(mod .. " + F10",              run(bin .. "eco-mode"),                        "Eco mode on/off (max battery)")

-- Session
bind(mod .. " + Escape",           run("loginctl lock-session"),                  "Lock screen")
bind(mod .. " + SHIFT + E",        run(bin .. "powermenu"),                       "Power menu")
bind("XF86PowerOff",               run(bin .. "powermenu"),                       "Power button: menu")
bind(mod .. " + SHIFT + R",        run("hyprctl reload"),                         "Reload Hyprland config")

-- Windows
bind(mod .. " + Q",                hl.dsp.window.close(),                         "Close window")
bind(mod .. " + F",                hl.dsp.window.fullscreen(),                    "Fullscreen")
bind(mod .. " + Space",            hl.dsp.window.float({ action = "toggle" }),    "Floating / tiled")
bind(mod .. " + P",                hl.dsp.window.pseudo(),                        "Pseudotile")
bind(mod .. " + T",                hl.dsp.layout("togglesplit"),                  "Toggle split direction")
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end, { description = "Next window (Alt+Tab)" })

-- Focus / move / resize with the arrow keys
local arrows = { left = "left", right = "right", up = "up", down = "down" }
local step = 40
local delta = { left = { -step, 0 }, right = { step, 0 }, up = { 0, -step }, down = { 0, step } }
for key, d in pairs(arrows) do
    bind(mod .. " + " .. key,           hl.dsp.focus({ direction = d }),       "Focus window " .. d)
    bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ direction = d }), "Move window " .. d)
    bind(mod .. " + CTRL + " .. key,
         hl.dsp.window.resize({ x = delta[key][1], y = delta[key][2], relative = true }),
         "Resize window " .. d, { repeating = true })
end

-- Workspaces 1..10
for i = 1, 10 do
    local key = i % 10
    bind(mod .. " + " .. key,           hl.dsp.focus({ workspace = i }),          "Workspace " .. i)
    bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }),    "Move window to workspace " .. i)
end
bind(mod .. " + Tab",               hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind(mod .. " + SHIFT + Tab",       hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")
bind(mod .. " + bracketright",      hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind(mod .. " + bracketleft",       hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")
bind(mod .. " + S",                 hl.dsp.workspace.toggle_special("magic"),                  "Scratchpad on/off")
bind(mod .. " + SHIFT + S",         hl.dsp.window.move({ workspace = "special:magic" }),       "Send window to scratchpad")

-- Screenshot
bind("Print",                       run(bin .. "screenshot full"),   "Screenshot (full)")
bind(mod .. " + Print",             run(bin .. "screenshot region"), "Screenshot (region)")
bind(mod .. " + SHIFT + Print",     run(bin .. "screenshot annotate"), "Screenshot + annotate (satty)")
bind(mod .. " + CTRL + Print",      run(bin .. "record"),            "Screen recording on/off")
bind(mod .. " + ALT + Print",       run(bin .. "ocr"),               "OCR region to clipboard")

-- ThinkPad Fn keys (work on the lock screen)
local fn = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",   run(bin .. "osd volume up"),     "Volume up",            fn)
bind("XF86AudioLowerVolume",   run(bin .. "osd volume down"),   "Volume down",            fn)
bind("XF86AudioMute",          run(bin .. "osd volume mute"),   "Mute",               { locked = true })
bind("XF86AudioMicMute",       run(bin .. "osd mic"),           "Mute microphone",      { locked = true })
bind("XF86MonBrightnessUp",    run(bin .. "osd brightness up"),   "Brightness up",   fn)
bind("XF86MonBrightnessDown",  run(bin .. "osd brightness down"), "Brightness down",   fn)
bind("XF86AudioPlay",          run("playerctl play-pause"),     "Play/Pause",         { locked = true })
bind("XF86AudioNext",          run("playerctl next"),           "Next track",   { locked = true })
bind("XF86AudioPrev",          run("playerctl previous"),       "Previous track",   { locked = true })

-- Mouse (optional): SUPER + left drag = move, right drag = resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
