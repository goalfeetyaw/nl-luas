local ffi = require("ffi")

--#region API variables

local new_vec2, new_vec, new_angle, vec_length, callback, inverter, Color_new, Render_Text, Render_Gradient, Render_ToScreen, Render_Circle, Render_BoxFilled, Render_Box , poly =
Vector2.new, Vector.new, QAngle.new, Vector.new(0, 0, 0).Length, Cheat.RegisterCallback, AntiAim.GetInverterState, Color.new, Render.Text, Render.GradientBoxFilled, Render.WorldToScreen, Render.Circle, Render.BoxFilled, Render.Box , Render.PolyFilled
local bit_band, math_floor, math_fmod, math_abs, math_random, math_max, math_min, math_pi, math_sqrt, math_abs, math_sin, math_cos, math_ceil, string_gmatch, table_insert, string_format, math_exp, table_remove , string_sub =
bit.band, math.floor, math.fmod, math.abs, math.random, math.max, math.min, math.pi, math.sqrt, math.abs, math.sin, math.cos, math.ceil, string.gmatch, table.insert, string.format, math.exp, table.remove , string.sub
local Menu_FindVar, Menu_Combo, Menu_Switch, Menu_SliderInt, Menu_SliderFloat, Menu_MultiCombo, Menu_ColorEdit, Menu_SwitchColor, Menu_Button, Menu_TextBox =
Menu.FindVar, Menu.Combo, Menu.Switch, Menu.SliderInt, Menu.SliderFloat, Menu.MultiCombo, Menu.ColorEdit, Menu.SwitchColor, Menu.Button, Menu.TextBox
local get_local_player, screensize, connected, Font, textsize, Render_line, inverter, color_int, Render_Blur , ingame , ray =
EntityList.GetLocalPlayer, EngineClient.GetScreenSize, EngineClient.IsConnected, Render.InitFont, Render.CalcTextSize, Render.Line, AntiAim.GetInverterState, Color.RGBA, Render.Blur , EngineClient.IsInGame , EngineTrace.TraceRay


--#endregion

--#region ffi integration

ffi.cdef [[
    void* GetProcAddress(void* hModule, const char* lpProcName);
    void* GetModuleHandleA(const char* lpModuleName);

    bool URLDownloadToFileA(void* LPUNKNOWN, const char* LPCSTR, const char* LPCSTR2, int a, int LPBINDSTATUSCALLBACK);  
    bool CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
    bool DeleteUrlCacheEntryA(const char* lpszUrlName);
    
    typedef struct {
        uint8_t r;
        uint8_t g;
        uint8_t b;
        uint8_t a;
    } color_struct_t;

    typedef void (*console_color_print)(const color_struct_t&, const char*, ...);
    typedef void* (__thiscall* get_client_entity_t)(void*, int);
    typedef int(__thiscall* get_clipboard_text_length)(void*);
    typedef void(__thiscall* set_clipboard_text)(void*, const char*, int);
    typedef void(__thiscall* get_clipboard_text)(void*, int, const char*, int);

    bool CreateDirectoryA(
        const char*  lpPathName,
        void*        lpSecurityAttributes
    );

]]

--// ffi helper integration
local ffi_helpers = {
    color_print_fn = ffi.cast("console_color_print",ffi.C.GetProcAddress(ffi.C.GetModuleHandleA("tier0.dll"), "?ConColorMsg@@YAXABVColor@@PBDZZ")),
    color_print = function(self, text, color) local col = ffi.new("color_struct_t")
        col.r = color.r * 255
        col.g = color.g * 255
        col.b = color.b * 255
        col.a = color.a * 255
        self.color_print_fn(col, text)
    end
}

local function coloredPrint(color, text) --// colored console print
    ffi_helpers.color_print(ffi_helpers, text, color)
end

local urlmon = ffi.load 'UrlMon'
local wininet = ffi.load 'WinInet'

local file_system = ffi.cast("void***", Utils.CreateInterface("filesystem_stdio.dll", "VBaseFileSystem011"))
local exists = ffi.cast("bool(__thiscall*)(void*, const char*, const char*)", file_system[0][10])  

local findelement = ffi.cast("unsigned long(__thiscall*)(void*, const char*)", Utils.PatternScan("client.dll", "55 8B EC 53 8B 5D 08 56 57 8B F9 33 F6 39 77 28"))
local chudchat = findelement(ffi.cast("unsigned long**", ffi.cast("uintptr_t", Utils.PatternScan("client.dll", "B9 ? ? ? ? E8 ? ? ? ? 8B 5D 08")) + 1)[0], "CHudChat")
local chatprintf = ffi.cast("void(__cdecl*)(int, int, int, const char*, ...)", ffi.cast("void***", chudchat)[0][27])

local VGUI_System = ffi.cast(ffi.typeof("void***"), Utils.CreateInterface("vgui2.dll", "VGUI_System010"))
local get_clipboard_text_length = ffi.cast("get_clipboard_text_length", VGUI_System[0][7])
local get_clipboard_text = ffi.cast("get_clipboard_text", VGUI_System[0][11])
local set_clipboard_text = ffi.cast("set_clipboard_text", VGUI_System[0][9])

ffi.C.CreateDirectoryA("nl/bordeaux", nil)

--#endregion

--#region Pointer creation

local ind_options =
{
    "Animated healthbar",
    "AA arrows",
    "Crosshair indicator",
    "Indicate damage",
    "Time warning",
    "Display information",
}

local g_cl =
{
    m_local        = get_local_player(),
    m_view         = EngineClient.GetViewAngles() , 
    m_angle_view   =  Cheat.AngleToForward(EngineClient.GetViewAngles()) , 
    m_lby          = 0 , 
    m_old_ground   = false, --// all 4 used to avoide aa flicking on land cuz other condition for 1 tick
    m_ground_ticks = 0, --//
    m_curr_flags   = nil, --//
    m_old_flags    = nil, --//
    m_condition    = "", --// local player condition
    screen         = screensize(),
    fl_exploit     = false , 
    roll           = false

}

local chat_replacements = {
    ["{white}"] = "\x01",
    ["{darkred}"] = "\x02",
    ["{team}"] = "\x03",
    ["{green}"] = "\x04",
    ["{lightgreen}"] = "\x05",
    ["{lime}"] = "\x06",
    ["{red}"] = "\x07",
    ["{grey}"] = "\x08",
    ["{yellow}"] = "\x09",
    ["{bluegrey}"] = "\x0A",
    ["{blue}"] = "\x0B",
    ["{darkblue}"] = "\x0C",
    ["{purple}"] = "\x0D",
    ["{violet}"] = "\x0E",
    ["{lightred}"] = "\x0F",
    ["{orange}"] = "\x10"
}

local center =
{
    [1] = g_cl.screen.x / 2,
    [2] = g_cl.screen.y / 2,
}

local g_callbacks =
{ --// Used for final callbacks at end of lua
    on_paint          = nil,
    on_pre_prediction = nil,
    on_prediction     = nil,
    on_createmove     = nil,
    on_impact         = nil,
    on_event          = nil,
    on_destroy        = nil
}

local g_menu = --// cheat element references
{
    pitch             = Menu_FindVar("Aimbot", "Anti Aim", "Main", "Pitch"),
    yaw_base          = Menu_FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"),
    yaw_add           = Menu_FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add"),
    yaw_mod           = Menu_FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier"),
    mod_degree        = Menu_FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree"),
    right_aa          = Menu_FindVar("Aimbot", "Anti Aim", "Fake Angle", "Right Limit"),
    left_aa           = Menu_FindVar("Aimbot", "Anti Aim", "Fake Angle", "Left Limit"),
    aa_inv            = Menu_FindVar("Aimbot", "Anti Aim", "Fake Angle", "Inverter"),
    fake_options      = Menu_FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options"),
    lby_options       = Menu_FindVar("Aimbot", "Anti Aim", "Fake Angle", "LBY Mode"),
    freestand_options = Menu_FindVar("Aimbot", "Anti Aim", "Fake Angle", "Freestanding Desync"),
    dsy_on_shot       = Menu_FindVar("Aimbot", "Anti Aim", "Fake Angle", "Desync On Shot"),
    sw                = Menu_FindVar("Aimbot", "Anti Aim", "Misc", "Slow Walk"),
    fl                = Menu_FindVar("Aimbot", "Anti Aim", "Fake Lag", "Limit"),
    enable_fl         = Menu_FindVar("Aimbot", "Anti Aim", "Fake Lag", "Enable Fake Lag"),
    dt                = Menu_FindVar("Aimbot", "Ragebot", "Exploits", "Double Tap"),
    hs                = Menu_FindVar("Aimbot", "Ragebot", "Exploits", "Hide Shots"),
    extended_bt       = Menu_FindVar("Miscellaneous", "Main", "Other", "Fake Ping"),
    fake_duck         = Menu_FindVar("Aimbot", "Anti Aim", "Misc", "Fake Duck"),
    auto_peek         = Menu_FindVar("Miscellaneous", "Main", "Movement", "Auto Peek"),
    safe_point        = Menu_FindVar("Aimbot", "Ragebot", "Misc", "Safe Points"),
    baim              = Menu_FindVar("Aimbot", "Ragebot", "Misc", "Body Aim"),
    baim_disable      = Menu_FindVar("Aimbot", "Ragebot", "Misc", "Body Aim Disablers"),
    slidewalk         = Menu_FindVar("Aimbot", "Anti Aim", "Misc", "Leg Movement"),
    strafer           = Menu_FindVar("Miscellaneous" , "Main" , "Movement" , "Auto Strafe")
}

local g_rage = --// used for rage elements of lua
{

    --// dormant aimbot

    enable_da       = Menu_Switch          ("bordeaux | Rage ", "bordeaux | Dormant aimbot ", "Enable dormant aimbot",false),
    da_options      = Menu_MultiCombo      ("bordeaux | Rage ", "bordeaux | Dormant aimbot ", "Options", {"Autoscope" , "Autostop" , "Allow lethal head" , "Debug logs"}, 0 , ""),
    da_dmg          = Menu_SliderInt       ("bordeaux | Rage ", "bordeaux | Dormant aimbot ", "Damage",5,1,100),
    da_hc           = Menu_SliderInt       ("bordeaux | Rage ", "bordeaux | Dormant aimbot ", "Hitchance [approx]",5,1,100),
    da_intensity    = Menu_Combo           ("bordeaux | Rage ", "bordeaux | Dormant aimbot ", "Hitscan intensity", {"low","medium","high"},0,"Allocates certain hitboxes to the dormant hitscan"),
    da_hitscan      = Menu_Combo           ("bordeaux | Rage ", "bordeaux | Dormant aimbot ", "Hitscan", {"safety","damage"},0,""),

    --// rage additions 
    additions       = Menu_MultiCombo      ("bordeaux | Rage ", "bordeaux | Rage additions ", "Options", {"Air hitchance" , "Noscope hitchance" , "DT shift"}, 0 , ""),
    air_hc          = Menu_SliderInt       ("bordeaux | Rage ", "bordeaux | Rage additions ", "Air hitchance ",35,0,100),
    noscope_hc      = Menu_SliderInt       ("bordeaux | Rage ", "bordeaux | Rage additions ", "Noscope hitchance ",35,0,100),
    change_shift    = Menu_SliderInt       ("bordeaux | Rage ", "bordeaux | Rage additions ", "Doubletap shift",14,12,16),

    unpredicted_data= { velocity = new_vec(0, 0, 0) }
}

local conditions    = {"Global" , "Standing" , "Slowwalk" , "Moving" , "Air" , "D + Air" , "Ducking"} 

local cond_to_int   = {["Global"] = 0, ["Standing"] = 1 , ["Slowwalk"] = 2 , ["Moving"] = 3 , ["Air"] = 4 , ["D + Air"] = 5 , ["Ducking"] = 6 } 


local g_antiaim   = --// used for aa elements of lua
{
    main            = Menu_Switch          ("bordeaux | AntiAim ", "bordeaux | Anti Aim ", "Enable Anti Aim",false),
    additions       = Menu_MultiCombo      ("bordeaux | AntiAim ", "bordeaux | Anti Aim additions ", "Anti aim additions" , {"Rollangle" , "Fakelag exploit" , "Adjust Fl" ,  "Teleport in air" , "Legit aa" , "Static air (fl)" , "No fl on shot"}  ,0,"") ,
    con_selector    = Menu_Combo           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Condition" , conditions  ,0,"") , 
    roll_cond       = Menu_MultiCombo      ("bordeaux | AntiAim ", "bordeaux | Anti Aim additions ", "Roll condition" , {"Standing" , "Slowwalk" , "Moving" , "Air" , "D + Air" , "Ducking" , "Manual"}  ,0,"") , 
    fl_exploit      = Menu_MultiCombo      ("bordeaux | AntiAim ", "bordeaux | Anti Aim additions ", "Exploit condition" , {"Standing" , "Slowwalk" , "Moving" , "Ducking"}  ,0,"") , 
    tele_weapon     = Menu_Combo           ("bordeaux | AntiAim ", "bordeaux | Anti Aim additions ", "Teleport weapon" , {"Only scout" , "All"}  ,0,"") , 
    tele_mode       = Menu_Combo           ("bordeaux | AntiAim ", "bordeaux | Anti Aim additions ", "Teleport mode" , {"Always" , "In air"}  ,0,"") , 
}

local g_custom_aa     = {}

local g_fakelag   = 
{
    main            = Menu_Switch          ("bordeaux | Fakelag ", "bordeaux | Fakelag ", "Enable custom fakelag",false , "Disable to use default fakelag"),
    mode            = Menu_Combo           ("bordeaux | Fakelag ", "bordeaux | Fakelag ", "Fakelag mode" , {"Maximum" , "Dynamic", "Step"}  , 0 , "") , 
    choke           = Menu_SliderInt       ("bordeaux | Fakelag ", "bordeaux | Fakelag ", "Fakelag choke" , 13 , 1 , 14) , 
    variance        = Menu_SliderInt       ("bordeaux | Fakelag ", "bordeaux | Fakelag ", "Fakelag variance" , 0 , 0 , 10) ,
    step1           = Menu_SliderInt       ("bordeaux | Fakelag ", "bordeaux | Fakelag ", "Step 1 value" , 8 , 1 , 14) ,
    step2           = Menu_SliderInt       ("bordeaux | Fakelag ", "bordeaux | Fakelag ", "Step 2 value" , 12 , 1 , 14) ,
    step3           = Menu_SliderInt       ("bordeaux | Fakelag ", "bordeaux | Fakelag ", "Step 3 value" , 14 , 1 , 14) 

}

--// Custom aa element creation

for i=1, #conditions do
    local v = conditions[i]
    g_custom_aa[conditions[i]] = {
        ["Override"]         = Menu_Switch              ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Override Global\0[" .. v .. "]" , false , "") ,
        ["Yaw mode"]         = Menu_Combo               ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Yaw mode\0[" .. v .. "]" , {"Static" , "L/R "} , 0 , "") ,
        ["Yaw add"]          = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Yaw add\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Left add"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Yaw add left\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Right add"]        = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Yaw add right\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Yaw mod"]          = Menu_Combo               ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Yaw mod\0[" .. v .. "]" , {"Disabled" , "Center" , "Offset" , "Random" , "Spin"} ,0 , "") , 
        ["Mod mode"]         = Menu_Combo               ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Mod mode\0[" .. v .. "]" , {"Static" , "Random" , "Jitter"} ,0 , "") , 
        ["Degree 1"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Degree 1\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Degree 2"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Degree 2\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Degree 3"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Random degree 1\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Degree 4"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Random degree 2\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Mod degree"]       = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Mod degree\0[" .. v .. "]" , 0 , -180 , 180) , 
        ["Desync mode"]      = Menu_Combo               ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Desync mode\0[" .. v .. "]" , {"Static" , "Random" , "Jitter" , "Sway"} ,0 , "") , 
        ["Desync 1"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Limit 1\0[" .. v .. "]" , 0 , 0 , 60) , 
        ["Desync 2"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Limit 2\0[" .. v .. "]" , 0 , 0 , 60) , 
        ["Desync 3"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Random 1\0[" .. v .. "]" , 0 , 0 , 60) , 
        ["Desync 4"]         = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Random 2\0[" .. v .. "]" , 0 , 0 , 60) , 
        ["Left desync"]      = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Left Desync\0[" .. v .. "]" , 0 , 0 , 60) , 
        ["Right desync"]     = Menu_SliderInt           ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Right Desync\0[" .. v .. "]" , 0 , 0 , 60) ,
        ["Fake options"]     = Menu_MultiCombo          ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Fake options\0[" .. v .. "]" , {"Avoid Overlap" , "Jitter" , "Random jitter" , "Anti Brute"} ,0 , "") , 
        ["Lby mode"]         = Menu_Combo               ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Lby mode\0[" .. v .. "]" , {"Disabled" , "Opposite" , "Sway" } ,0 , "") , 
        ["Freestanding"]     = Menu_Combo               ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "Desync freestand\0[" .. v .. "]" , {"Off" , "Fake" , "Real" } ,0 , "") , 
        ["On shot"]          = Menu_Combo               ("bordeaux | AntiAim ", "bordeaux | Custom Anti aimbot ", "On shot\0[" .. v .. "]" , {"None" , "Opposite" , "Freestand" , "Switch" } ,0 , "") , 
    }
end

local phase_amount           = Menu_SliderInt           ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Phase amount", 2 , 2 , 10)


local g_bruteforce = --// used for anti bruteforce elements of lua
{
    main                     = Menu_Switch              ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Enable Anti bruteforce",false),
    options                  = Menu_MultiCombo          ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Bruteforce options", {"Force static" , "Custom timing" , "Reset on kill"} ,0 , "") , 
    origin                   = Menu_Combo               ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Bruteforce origin", {"Eye-angle" , "Stomach" } ,0 , "") ,
    duration                 = Menu_SliderInt           ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Bruteforce duration", 3 , 2 , 8) ,  
    range                    = Menu_SliderInt           ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Activation range", 65 , 45 , 150) , 
    bf_color                 = Menu_ColorEdit           ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Indication color", Color_new(255, 255, 255, 255)) , 

    add_stage                = Menu_Button              ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Add Stage" , "" , function()
        phase_amount:SetInt(clamp(phase_amount:Get() + 1, 2, 10))
    end) ,
    remove_stage             = Menu_Button              ("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "Remove Stage" , "" , function()
        phase_amount:SetInt(clamp(phase_amount:Get() - 1, 2, 10))
    end) , 
    stage_creation =
      {
        [1]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 1] Delta", 0, -60, 60),
        [2]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 2] Delta", 0, -60, 60),
        [3]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 3] Delta", 0, -60, 60),
        [4]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 4] Delta", 0, -60, 60),
        [5]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 5] Delta", 0, -60, 60),
        [6]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 6] Delta", 0, -60, 60),
        [7]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 7] Delta", 0, -60, 60),
        [8]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 8] Delta", 0, -60, 60),
        [9]  = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 9] Delta", 0, -60, 60),
        [10] = Menu_SliderInt("bordeaux | Bruteforce ", "bordeaux | Bruteforce ", "[Stage 10] Delta", 0, -60, 60)
    },
    stage = 0 ,
    to_brute = false
}

local g_visuals = --// used for indicator / visual elements of lua
{
    main            = Menu_Switch          ("bordeaux | Visuals ", "bordeaux | Visuals ", "Enable visual options", false, ""),

    --// Indicator
    indic_options  = Menu_MultiCombo       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Indicator Options", ind_options, 0, ""),
    arrow_mode     = Menu_Combo            ("bordeaux | Visuals ", "bordeaux | Indicator ", "Arrow type", { "« »", "TS" }, 0, ""),
    indic_mode     = Menu_Combo            ("bordeaux | Visuals ", "bordeaux | Indicator ", "Indicator type", { "None", "Old", "Modern", "Name" , "Compact" }, 0, ""),
    dmg_height     = Menu_Combo            ("bordeaux | Visuals ", "bordeaux | Indicator ", "Damage height", { "Top", "Bottom" }, 0, ""),
    dmg_width      = Menu_Combo            ("bordeaux | Visuals ", "bordeaux | Indicator ", "Damage width", { "Left", "Right" }, 0, ""),
    health_speed   = Menu_SliderInt        ("bordeaux | Visuals ", "bordeaux | Indicator ", "Bar animation speed", 12 , 2 , 20),
    warning_time   = Menu_SliderInt        ("bordeaux | Visuals ", "bordeaux | Indicator ", "Warning time", 30, 10, 60),
    anim           = Menu_Switch           ("bordeaux | Visuals ", "bordeaux | Indicator ", "Animate indicators", false, ""),

    --ui option selector

    ui_options      = Menu_MultiCombo      ("bordeaux | Visuals ", "bordeaux | User interface ", "Ui options", { "Watermark", "Keybinds" }, 0, ""),

    --// Keybinds

    keybind_mode    = Menu_Combo           ("bordeaux | Visuals ", "bordeaux | User interface ", "Keybind mode", { "Solus", "borderless" }, 0, ""),
    binds_bg        = Menu_Combo           ("bordeaux | Visuals ", "bordeaux | User interface ", "Keybind background", { "Black", "Blur" }, 0, ""),
    binds_x         = Menu_SliderInt       ("bordeaux | Visuals ", "bordeaux | User interface ", "X axis", 100, 0, g_cl.screen.x),
    binds_y         = Menu_SliderInt       ("bordeaux | Visuals ", "bordeaux | User interface ", "Y axis", 100, 0, g_cl.screen.y),

    --// Watermark
    watermark_mode  = Menu_Combo           ("bordeaux | Visuals ", "bordeaux | User interface ", "Wm Mode", { "Solus", "Simple" }, 0, ""),
    watermark_loc   = Menu_Combo           ("bordeaux | Visuals ", "bordeaux | User interface ", "Wm Location", { "Top", "Center" }, 0, ""),
    watermark_bg    = Menu_Combo           ("bordeaux | Visuals ", "bordeaux | User interface ", "Wm background", { "Black", "Blur" }, 0, ""),
    enable_glow     = Menu_Combo           ("bordeaux | Visuals ", "bordeaux | User interface ", "Wm glow", { "Disable", "Enable" }, 0, ""),
    glow_intensity  = Menu_SliderFloat     ("bordeaux | Visuals ", "bordeaux | User interface ", "Glow intensity", 1, 1, 6.5),



    --// Logs
    log_mode        = Menu_MultiCombo      ("bordeaux | Visuals ", "bordeaux | Logs ", "Log Mode", { "Console", "Top", "Hud" , "chat" }, 0, ""),
    log_options     = Menu_MultiCombo      ("bordeaux | Visuals ", "bordeaux | Logs ", "Log options", {"Hit", "Miss", "Purchase" }, 0, ""),

    --// color picker
    active_side     = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Active Side", color_int(255, 255, 255, 255)),
    inactive_side   = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Inactive Side", color_int(255, 255, 255, 255)),
    valid_color     = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Valid keybind", color_int(255, 255, 255, 255)),
    invalid_color   = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Invalid Keybind", color_int(255, 255, 255, 255)),
    gradient1       = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Gradient 1", color_int(255, 255, 255, 255)),
    gradient2       = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Gradient 2", color_int(255, 255, 255, 255)),
    dmg_color       = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Damage color", color_int(255, 255, 255, 255)),
    watermark_color = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | User interface ", "Wm color", color_int(255, 255, 255, 255)),
    watermark_text  = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | User interface ", "Wm text color", color_int(255, 255, 255, 255)),
    log_color       = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Logs ", "Log color", color_int(255, 255, 255, 255)),
    bind_color      = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | User interface ", "Keybind color", color_int(255, 255, 255, 255)) ,
    warning_color   = Menu_ColorEdit       ("bordeaux | Visuals ", "bordeaux | Indicator ", "Warning color", color_int(255, 255, 255, 255))

}

local g_world =
{
    scope_viewmodel = Menu_Switch         ("bordeaux | World ", "bordeaux | Scope ", "Viewmodel in scope", false, ""), 
    custom_scope    = Menu_SwitchColor    ("bordeaux | World ", "bordeaux | Scope ", "Enable custom scope", false, color_int(255, 255, 255, 255)),
    scope_mode      = Menu_Combo          ("bordeaux | World ", "bordeaux | Scope ", "Scope mode", { "Static", "Dynamic" }, 0, ""),
    scope_offset    = Menu_SliderInt      ("bordeaux | World ", "bordeaux | Scope ", "Offset", 10, -500, 500),
    scope_length    = Menu_SliderInt      ("bordeaux | World ", "bordeaux | Scope ", "Length", 60, 0, 1000),
    scope_width     = Menu_SliderFloat    ("bordeaux | World ", "bordeaux | Scope ", "Width", 1, 0, 2),
    scope_scale     = Menu_SliderInt      ("bordeaux | World ", "bordeaux | Scope ", "Inaccuracy scale", 100, 0, 500),

    hitmarker       = Menu_SwitchColor    ("bordeaux | World ", "bordeaux | Hitmarker ", "Enable hitmarker", false, color_int(255, 255, 255, 255)),
    marker_mode     = Menu_MultiCombo     ("bordeaux | World ", "bordeaux | Hitmarker ", "Hitmarker mode", { "+", "Damage" }, 0, ""),
    damage_fade     = Menu_Combo          ("bordeaux | World ", "bordeaux | Hitmarker ", "Fading", { "Alpha", "Alpha + Dmg" }, 0, ""),
    fade_mode       = Menu_Combo          ("bordeaux | World ", "bordeaux | Hitmarker ", "Damage mode", {"Down" , "Up" } , 0 , ""),


    snaplines       = Menu_SwitchColor    ("bordeaux | World ", "bordeaux | Snaplines ", "Enable snaplines", false, Color_new(255, 255, 255, 255)),
    snapline_player = Menu_Combo          ("bordeaux | World ", "bordeaux | Snaplines ", "Snapline players", { "All", "closest" }, 0, ""),
    snapline_mode   = Menu_MultiCombo     ("bordeaux | World ", "bordeaux | Snaplines ", "Snapline exception", { "Skip team", "Skip dormant"}, 0, ""),
    snapline_start  = Menu_Combo          ("bordeaux | World ", "bordeaux | Snaplines ", "Snapline start", { "Bottom", "Local player" }, 0, ""),

}

local g_misc = --// used for misc related elements of lua
{
    clantag_on      = Menu_Switch         ("bordeaux | Misc ", "bordeaux | Misc ", "Enable clantag", false, ""),
    custom_hitsound = Menu_Switch         ("bordeaux | Misc ", "bordeaux | Misc ", "Custom Hitsound", false, "") , 
    hitsound_path   = Menu_TextBox        ("bordeaux | Misc ", "bordeaux | Misc ", "Hitsound path", 128 , "buttons/arena_switch_press_02", "Default is csgo/sound ") , 

    trashtalk       = Menu_Switch         ("bordeaux | Misc ", "bordeaux | Trashtalk ", "Enable trashtalk", false, ""),
    trashtalk_mode  = Menu_Combo          ("bordeaux | Misc ", "bordeaux | Trashtalk ", "Trashtalk mode", { "Random", "Hs/Baim based" }, 0, "")

}

local g_events = --// used for event callback / functions
{

}

local g_Fonts =
{
    Verdana     = Font("Verdana", 11),
    Verdana_wtr = Font("Verdana", 11, { 'r' }),
    Pixel       = Font("nl\\bordeaux\\pixel.ttf", 10, { "r" }),
    Calibri     = Font("Calibri", 30, { "b" }),
    Log         = Font("Lucida Console", 10, {"r"}) , 
    hitmarker   = Font("verdana", 11, {"b", "i"}),

}

local g_bomb = {
    site = nil,
    render = nil,
    time = 0
}

local logs = {}
local logs_hud = {}

local miss_reason = 
{
    "?",
    "spread",
    "occlusion",
    "prediction error"
}

local hitgroup_names = 
{
    "generic",
    "head",
    "chest",
    "stomach",
    "left arm",
    "right arm",
    "left leg",
    "right leg",
    "neck",
    "?",
    "gear"
}

--#endregion

--#region Static functions

local white       = Color_new( 255 , 255 , 255 , 255)
local black       = Color_new( 0, 0 , 0 , 255)
local processticks = CVar.FindVar("sv_maxusrcmdprocessticks")
local second_check = true

function download(from, to)
    wininet.DeleteUrlCacheEntryA(from)
    urlmon.URLDownloadToFileA(nil, from, to, 0,0)
end

function http_message(string)
    local answer =  Http.Get(string)

    if  answer:sub(1 , 15) == "<!DOCTYPE html>" then --// if smth went wrong eg. wrong link / broken link etc
        return {"Invalid http response, please report on discord" , false}
    elseif answer == "" then --// if we get empty response 
        return  {"Unable to establish connection, please report on discord" , false}
    else
        return  {answer , true}
    end
end

local function print_chat(text)
    for k, v in pairs(chat_replacements) do text = text:gsub(k, v) end
    chatprintf(chudchat, 0, 0, string.format(" %s", text))
end

function button_sound()
    EngineClient.ExecuteClientCmd("playvol buttons/arena_switch_press_02 0.6")
end

function lerp(start, vend, time)
    return start + (vend - start) * time
end

function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math_floor(num * mult + 0.5) / mult
end

function clamp(val, lower, upper)
    if lower > upper then
        lower, upper = upper, lower
    end
    return math.max(lower, math.min(upper, val))
end

function distance(start , finish )
   return start:DistTo(finish)
end

function AngleDiff(destAngle, srcAngle) 

    local delta

    delta = math.fmod(destAngle - srcAngle, 360.0);
    if destAngle > srcAngle then
        if delta >= 180 then 
            delta = delta - 360
        end
    else 
        if delta <= -180 then 
            delta = delta + 360
        end
    end
    return delta
end

function scan_ray( start , finish , me) 

    local a   = distance(me , start)
    local b   = distance( start, finish)
    local c   = distance( me, finish)

    if   b < a  then return distance( me , finish ) end

    return 0.5/b * math.sqrt((a+b+c) * (-a+b+c) * (a-b+c) * (a+b-c)) --heron's formula -> still buggy sometimes though and idk why

end 

function add_log(text)
    table_insert(logs, {text = text, expiration = 8, fadein = 0, color = {255, 255, 255, 255}})
end

function ticks_to_time(a)
    return GlobalVars.interval_per_tick * a
end

function is_alive(entity) --// alive + nullptr
    if entity == nil or not entity then return false end
    return entity:IsAlive()
end

function in_air(entity) --// air check
    return bit_band(entity:GetProp("m_fFlags"), 1) == 0
end

function delta()
    local real = AntiAim.GetCurrentRealRotation()
    local fake = AntiAim.GetFakeRotation()

    return round(math_min(math_abs(real - fake), AntiAim.GetMaxDesyncDelta()))
end

function Render_Shadow(text, pos, clr, size, font, aliasing, centering) --// self explenatory 
    if aliasing == nil then
        aliasing = false
    end
    if centering == nil then
        centering = false
    end

    Render_Text(text, pos + new_vec2(1, 1), Color_new(0, 0, 0, clr.a), size, font, aliasing, centering)
    Render_Text(text, pos, clr, size, font, aliasing, centering)
end

function set_local() --// we do dis so no crashes / errors 
    g_cl.m_local = ingame() and get_local_player() or nil
end

function update_screen() --// in case some1 changes res mid game (braindead)
    g_cl.screen = screensize()
end

local frame_rate = 0
function get_fps() 
    frame_rate = 0.9 * frame_rate + (1.0 - 0.9) * GlobalVars.absoluteframetime
    return math_floor((1.0 / frame_rate) + 0.5)
end

local DoHitchance = function( speed , weap ) --// absolutely dumb but we do it since actual hc fucks fps (sadge)

    local accurate     = weap:GetMaxSpeed() / 3 

    local current_accurcary 

    if speed >= weap:GetMaxSpeed() / 2 then 
        current_accurcary = accurate / speed * 100 / 1.6
    else 
        current_accurcary = accurate / speed * 100
    end
    
    if g_cl.m_local:GetProp("m_bIsScoped") == false then 
        current_accurcary = 0
    end

    return clamp(current_accurcary,0,100)

end

g_rage.autostop = function(cmd) --actual proper autostop in lua ? (wow) pls approve it only stops on dormant aimbot -> wont mess with ragebot

    if not g_rage.da_options:Get(2) then
        return
    end

    local weapon = g_cl.m_local:GetActiveWeapon()

    if not weapon then
        return
    end

    local hvel = g_cl.m_local:GetProp("m_vecVelocity")
    hvel.z = 0
    local speed = hvel:Length2D()

    local maxSpeed = weapon:GetMaxSpeed()

    if g_rage.unpredicted_data.velocity:Length2D() < maxSpeed / 5 or speed < maxSpeed / 5 then
        return
    end

    local accel = CVar.FindVar("sv_accelerate"):GetFloat()

    local playerSurfaceFriction = 1 --pLocalPlayer:GetProp("C_BasePlayer", "m_surfaceFriction") -- I'm a slimy boi
    local max_accelspeed = accel * GlobalVars.interval_per_tick * maxSpeed * playerSurfaceFriction

    local wishspeed = 0.0


    if (speed - max_accelspeed <= -1.0) then
        wishspeed = max_accelspeed / (speed / (accel * GlobalVars.interval_per_tick))
    else 
        wishspeed = max_accelspeed
    end

    local ndir = Cheat.VectorToAngle(hvel * -1.0)
    ndir.yaw = cmd.viewangles.yaw - ndir.yaw
    local ndir_vec = Cheat.AngleToForward(ndir)

    cmd.forwardmove = ndir_vec.x * wishspeed
    cmd.sidemove = ndir_vec.y * wishspeed
end

g_antiaim.player_condition = function() --// get our players current condition for anti aim

    if not is_alive(g_cl.m_local) then
        return "Standing" -- doesnt matter, wont be used
    end

    local vel = g_cl.m_local:GetProp("m_vecVelocity"):Length2D()
    local standing = g_cl.roll and vel <= 3 or vel <= 1.2 --// roll affects micromove iirc

    if in_air(g_cl.m_local) or (g_cl.m_ground_ticks <= 1 and not g_cl.m_old_ground) then
        if g_cl.m_local:GetProp("m_flDuckAmount") >= 0.6 then --// if crouching in air
            return "D + Air"
        else
            return "Air"
        end
    else
        if g_cl.m_local:GetProp("m_flDuckAmount") >= 0.6 or g_menu.fake_duck:GetBool() then
            return "Ducking"
        end

        if standing then
            return "Standing"
        end

        if g_menu.sw:GetBool() then
            return "Slowwalk"
        end

        return "Moving"
    end
end

function closest_player()

    local players = EntityList.GetPlayers()

    local best = players[#players]
    if best == nil then return end
    local temp_dist = distance(best:GetProp("m_vecOrigin") , g_cl.m_local:GetProp("m_vecOrigin"))

    for k , v in ipairs(players) do 

        if v == g_cl.m_local then goto skip end

        local dist = distance(v:GetProp("m_vecOrigin") , g_cl.m_local:GetProp("m_vecOrigin"))

        if dist < temp_dist then 
            temp_dist = dist
            best = v
        end

        ::skip::

    end

    return best

end

g_cl.update_status = function()
    g_cl.m_condition = g_antiaim.player_condition() --// updating condition string
end

update_lby = function ()
    if ClientState.m_choked_commands == 0 then
        g_cl.m_lby = AngleDiff ( g_cl.m_local:GetProp("m_flLowerBodyYawTarget") , AntiAim.GetCurrentRealRotation())
    end
end

g_antiaim.store_for_next_tick = function() --// Checking for ground ticks -> if more than 1 set non air aa, if only 1 tick then set air aa
    g_cl.m_old_flags = g_cl.m_local:GetProp("m_fFlags")
    g_cl.m_ground_ticks = bit_band(g_cl.m_old_flags, 1) == 1 and g_cl.m_ground_ticks + 1 or 0
    g_cl.m_old_ground = bit_band(g_cl.m_old_flags, 1) == 1
end

function add_notification ( Text, Time,  Color,  TextColor )
    logs_hud[#logs_hud + 1] = {Text, GlobalVars.realtime + Time, 0, Color, TextColor}
end

function Render_Solus_Gradient(x, y, w, h, c, size, bg, glow, intensity) --// for easy use by swedish licorish enjoyer (nasty af) freaut

    local color1 = color_int(math_floor(c.r * 255), math_floor(c.g * 255), math_floor(c.b * 255), 255)
    local color2 = color_int(math_floor(c.r * 255), math_floor(c.g * 255), math_floor(c.b * 255), 0)

    -- background
    if bg == nil then
        bg = ""
    end

    --// half of box / full box
    if size == nil then 
        size = ""
    end

    --// outline glow
    if glow == nil then
        glow = ""
    end

    local h2 = size == "full" and h or h / 2

    local box_bg = bg == "black" and black or color_int(17, 17, 17, 130) 

    Render_Blur(new_vec2(x, y), new_vec2(x + w, y + h), box_bg, 4)

    -- top bar
    Render_BoxFilled(new_vec2(x + 3, y - 2), new_vec2(x + w - 3, y), color1, 0)

    -- corner left
    Render_Circle(new_vec2(x + 3, y + 3), 4, 30, color1, 2, 270, 180)
    Render_Gradient(new_vec2(x - 2, y + 3), new_vec2(x, y + h2 - 2), color1, color1, color2, color2)

    -- corner right
    Render_Circle(new_vec2(x + w - 3, y + 3), 4, 30, color1, 2, 270, 360)
    Render_Gradient(new_vec2(x + w + 2, y + 3), new_vec2(x + w, y + h2 - 2), color1, color1, color2, color2)
    
    if glow == "true" then
        for i = 1, 5 do -- glow
            Render_Box(new_vec2(x - i, y - i), new_vec2(x + w + i, y + h + i), Color_new(c.r, c.g, c.b, 0.1 * (intensity - i)), 7)
        end
    end
end

function clr_to_string(clr)
    return string_format("%02X%02X%02X%02X", math.floor(clr.r * 255), math.floor(clr.g * 255), math.floor(clr.b * 255), math.floor(clr.a * 255))
end

function str_to_clr (str)

    if (str:sub(1, 2) == nil or str:sub(1, 2) == "") or (str:sub(3, 4) == nil or str:sub(3, 4) == "") or (str:sub(5, 6) == nil or str:sub(5, 6) == "") or (str:sub(7, 8) == nil or str:sub(7, 8) == "") then 
        return "fail"
    end

    return Color_new(tonumber("0x"..str:sub(1, 2))/255, tonumber("0x"..str:sub(3, 4))/255, tonumber("0x"..str:sub(5, 6))/255, tonumber("0x"..str:sub(7, 8))/255)
end

local user         = Cheat.GetCheatUserName()
local build = (user == "Xanqrul" or user == "Freaut") and "lby" or "Stable"
local lua_dir = string_sub(EngineClient.GetGameDirectory() , 0 , -5).."nl\\bordeaux\\"

local function requirements()

    local required = not exists(file_system,lua_dir.."pixel.ttf" , nil)

    if required  then
        add_notification("Required font not found, procceeding to download" , 1 , Color_new( 255 , 0 , 0 , 255 ) , white)
        download("https://fontsforyou.com/downloads/99851-smallestpixel7","nl\\bordeaux\\pixel.ttf")

        return
    else 
        add_notification("Required font initilized" , 1 , Color_new( 0 , 255 , 0 , 255 ) , white)
        second_check = false
    end

end

--#endregion

--#region welcome msg
EngineClient.ExecuteClientCmd("clear")
local welcome_string = "https://pastebin.com/raw/8mmxMQ75"
local raw_welcome    = http_message(welcome_string)
local console_print  = raw_welcome[1]

if raw_welcome[2] == false then 

    print(raw_welcome[1].." -> Welcome message")
else 
    button_sound()
    coloredPrint(Color_new(241 / 255, 146 / 255, 247 / 255, 255 / 255), console_print) 
    add_notification( "Welcome to bordeaux.rbx" , 1 , Color_new(235, 103, 230, 255) , white)
end

requirements()

--#endregion

--#region dormant aimbot
local low_intensity =  
{
    0,  1,  3,  4,
}

local medium_intensity = 
{
    0, 1,  3,  4,  5,  6,  7
}

local high_intensity = 
{
    0, 1 , 2 , 3 , 4 , 5 , 6 , 7 , 8 , 9 , 10 , 
11, 12 , 13 , 14 , 15 , 16 , 17 , 18 
}

local network_data = 
{
    [-1] = "None"  ,
    [1] = "cheat" ,
    [2] = "shared",
    [3] = "sound" ,
    [4] = "None"  ,
}

local attack = function(cmd)
    cmd.buttons = bit.bor(cmd.buttons, 1) 
end

local attack2 = function(cmd)
    cmd.buttons = bit.bor(cmd.buttons, 2048)
end

g_rage.dormant_aimbot = function(cmd)
    if not g_rage.enable_da:GetBool() then return end

    local hitscan_intensity

    if g_rage.da_intensity:GetInt() == 1 then
        hitscan_intensity = medium_intensity
    elseif g_rage.da_intensity:GetInt() == 2 then 
        hitscan_intensity = high_intensity
    else
        hitscan_intensity = low_intensity
    end
    
    local weap = g_cl.m_local:GetActiveWeapon()
    local players = EntityList.GetPlayers()

    if weap == nil or in_air(g_cl.m_local) or #players == 1 then return end

    local min_damage = g_rage.da_dmg:GetInt()
    local local_eye = g_cl.m_local:GetEyePosition()
    local scoped = g_cl.m_local:GetProp("m_bIsScoped")

    local aimpunch_ang = g_cl.m_local:GetProp("m_aimPunchAngle")
    
    local safety = g_rage.da_hitscan:GetInt() == 0

    local best_player 
    local best_damage = 0
    local best_player_point
    local best_hitbox = 0

    local clip = weap:GetProp("DT_BaseCombatWeapon", "m_iClip1")

    if weap:GetProp("m_flNextPrimaryAttack") > GlobalVars.curtime or weap:IsReloading() or clip <= 0 then
        return
    end

    for i, player in ipairs(players) do

        if player:IsTeamMate() or not is_alive(player) or not player:IsDormant() then
            goto next
        end

        local hp = player:GetProp("m_iHealth")
        local best_hbx = 0
        local best_point

        for k , v in ipairs(hitscan_intensity) do 
            
            local center = player:GetHitboxCenter(v)

            if distance(local_eye , center) <= weap:GetWeaponRange() then
                local point = Cheat.FireBullet(g_cl.m_local, local_eye, center)

                if point.damage >= min_damage or point.damage >= hp then
                    
                    if not best_point or (not safety and (point.damage >= best_point.damage)) or safety then
                        best_point = point
                        best_hbx = v
                    end
                end

                if best_point then

                    if safety and best_hbx > 2 then
                        break
                    end

                    if best_point.damage > hp and (g_rage.da_options:Get(3) or best_hbx > 2) then
                        break
                    end
                end
            end
        end

        local point_cond = not best_player_point and best_point
        local dmg_cond = (best_point and (best_damage < best_point.damage))

        if point_cond or dmg_cond then
            best_player = player
            best_damage = best_point.damage
            best_hitbox = best_hbx
            best_player_point = best_point
        end


        if best_player then
            if best_damage >= best_player:GetProp("m_iHealth") and best_hitbox > 2 then
                break
            end
        end

        ::next::
    end

    if best_player then
        g_rage.autostop(cmd)
    end

    if best_player and g_rage.da_options:Get(1) and not scoped and weap:IsSniper() then
        attack2(cmd)
        return
    end

    if best_player and best_damage > 0 then

        --// the angle our shot is gonna have 
        local shot_angle = Cheat.VectorToAngle(best_player_point.trace.endpos - local_eye)
        local hc = DoHitchance( g_cl.m_local:GetProp("m_vecVelocity"):Length2D() , weap )

        if  hc >= g_rage.da_hc:Get() then 

            -- // aim at target
            cmd.viewangles = shot_angle 

            -- // compensate recoil
            cmd.viewangles = cmd.viewangles - (new_angle(aimpunch_ang.x, aimpunch_ang.y, aimpunch_ang.z) * CVar.FindVar("weapon_recoil_scale"):GetFloat()) 

            local fina_inacc = weap:GetInaccuracy(weap) + weap:GetSpread(weap)

            --// shoot at target 
            attack(cmd)
            if g_rage.da_options:Get(4) then 
                local hb = best_player:GetHitboxCenter(best_hitbox)
                local shot_str = string.format("attempted shot at %s, data=%s, approx damage=%i, best calculated hitbox=%i position = {%.2f,%.2f,%.2f}, approx hc=%i final inaccuracy : %.4f" ,
                best_player:GetName() , network_data[best_player:GetNetworkState()], best_damage, best_hitbox , hb.x , hb.x , hb.z , hc , fina_inacc )
                print(shot_str)
                add_log(shot_str)
            end
        end
    end

end

g_rage.store_unpredicted_data = function()
    g_rage.unpredicted_data.velocity = g_cl.m_local:GetProp("m_vecVelocity") --// used for autostop
end

--#endregion

--#region rage additions

g_rage.handle_rage_additions = function()

    if not g_rage.additions:Get(1) and not g_rage.additions:Get(2) and not g_rage.additions:Get(4) then return end

    local players

    if g_rage.additions:Get(1) or g_rage.additions:Get(2) then 
       players = EntityList.GetPlayers()
    end

    if g_rage.additions:Get(1) then 
        if  in_air(g_cl.m_local) or (g_cl.m_ground_ticks <= 1 and not g_cl.m_old_ground) then 
            for k , v in ipairs(players) do 
                RageBot.OverrideHitchance(v:EntIndex(), g_rage.air_hc:GetInt())
            end
        end
    end
    if g_rage.additions:Get(2) then 
        local scoped   = g_cl.m_local:GetProp("m_bIsScoped")
        local wpn = g_cl.m_local:GetActiveWeapon()
        if wpn == nil or not wpn:IsSniper() or scoped then return end
        for k , v in ipairs(players) do  -- we use a loop to set the hc for every enemy -> "global" hitchance 
           RageBot.OverrideHitchance(v:EntIndex(), g_rage.noscope_hc:GetInt()) 
        end
    end

    if g_rage.additions:Get(3) and g_menu.dt:GetBool() and Exploits.GetCharge() == 1 then 
        processticks:SetInt(g_rage.change_shift:GetInt() + 2) -- + 2 so we cant go below 14 -> wont break fakelag etc 
        Exploits.OverrideDoubleTapSpeed(g_rage.change_shift:GetInt()) -- max shift amount without desync is 15 and with 14 on every normal sv anyway lOl
    end
end

--#endregion 

--#region custom aa 
g_antiaim.hanle_custom_aa = function()

    if not g_antiaim.main:GetBool() then return end

    local cond = g_cl.m_condition
    local jitter = GlobalVars.tickcount % 4 > 1

    if g_cl.fl_exploit or g_cl.roll or (g_antiaim.additions:Get(6) and Exploits.GetCharge() ~= 1 and ( cond == "Air" or cond == "D + Air")) then 
        g_menu.yaw_add:Set(10)
        g_menu.yaw_mod:Set(0)
        g_menu.right_aa:SetInt(60)
        g_menu.left_aa:SetInt(60)
        g_menu.fake_options:SetInt(0)
        g_menu.freestand_options:SetInt(0)
        return
    end

    if g_custom_aa[cond]["Override"]:Get() then

        if g_custom_aa[cond]["Yaw mode"]:GetInt() == 1 then 
            g_menu.yaw_add:SetInt(inverter() and g_custom_aa[cond]["Left add"]:Get() or g_custom_aa[cond]["Right add"]:Get())
        else 
            g_menu.yaw_add:SetInt(g_custom_aa[cond]["Yaw add"]:Get())
        end

        g_menu.yaw_mod:SetInt(g_custom_aa[cond]["Yaw mod"]:Get())

        if g_custom_aa[cond]["Mod mode"]:Get() == 0 then 
            g_menu.mod_degree:SetInt(g_custom_aa[cond]["Mod degree"]:Get())
        elseif g_custom_aa[cond]["Mod mode"]:Get() == 1 then 
            g_menu.mod_degree:SetInt(math_random( g_custom_aa[cond]["Degree 3"]:Get() , g_custom_aa[cond]["Degree 4"]:Get() ) )
        else
            g_menu.mod_degree:SetInt( jitter and g_custom_aa[cond]["Degree 1"]:Get() or g_custom_aa[cond]["Degree 2"]:Get() )
        end

        if g_custom_aa[cond]["Desync mode"]:Get() == 0 then 
            g_menu.right_aa:SetInt(g_custom_aa[cond]["Right desync"]:Get())
            g_menu.left_aa:SetInt(g_custom_aa[cond]["Left desync"]:Get())
        elseif g_custom_aa[cond]["Desync mode"]:Get() == 1 then 
            local dsy = math_random( g_custom_aa[cond]["Desync 3"]:Get() , g_custom_aa[cond]["Desync 4"]:Get() )
            g_menu.right_aa:SetInt(dsy)
            g_menu.left_aa:SetInt(dsy)
        elseif  g_custom_aa[cond]["Desync mode"]:Get() == 2 then
            local dsy_jit = jitter and g_custom_aa[cond]["Desync 1"]:Get() or g_custom_aa[cond]["Desync 2"]:Get()
            g_menu.right_aa:SetInt(dsy_jit)
            g_menu.left_aa:SetInt(dsy_jit)
        else 
            local max = 180 * 0.65
            local min = 8
            local dsy_sway = math_abs(round(math.min(math.max(math.floor(math.abs(math.cos(GlobalVars.curtime / 70 * 100)) * max), min), max) - max / 2 ))
            g_menu.right_aa:SetInt(dsy_sway)
            g_menu.left_aa:SetInt(dsy_sway)
        end

        g_menu.fake_options:SetInt(g_custom_aa[cond]["Fake options"]:Get())
        g_menu.lby_options:SetInt(g_custom_aa[cond]["Lby mode"]:Get())
        g_menu.freestand_options:SetInt(g_custom_aa[cond]["Freestanding"]:Get())
        g_menu.dsy_on_shot:SetInt(g_custom_aa[cond]["On shot"]:Get())

    else 

        if g_custom_aa["Global"]["Yaw mode"]:GetInt() == 1 then 
            g_menu.yaw_add:SetInt(inverter() and g_custom_aa["Global"]["Left add"]:Get() or g_custom_aa["Global"]["Right add"]:Get())
        else 
            g_menu.yaw_add:SetInt(g_custom_aa["Global"]["Yaw add"]:Get())
        end

        g_menu.yaw_mod:SetInt(g_custom_aa["Global"]["Yaw mod"]:Get())

        if g_custom_aa["Global"]["Mod mode"]:Get() == 0 then 
            g_menu.mod_degree:SetInt(g_custom_aa["Global"]["Mod degree"]:Get())
        elseif g_custom_aa["Global"]["Mod mode"]:Get() == 1 then 
            g_menu.mod_degree:SetInt(math_random( g_custom_aa["Global"]["Degree 3"]:Get() , g_custom_aa["Global"]["Degree 4"]:Get() ) )
        else
            g_menu.mod_degree:SetInt( jitter and g_custom_aa["Global"]["Degree 1"]:Get() or g_custom_aa["Global"]["Degree 2"]:Get() )
        end

        if g_custom_aa["Global"]["Desync mode"]:Get() == 0 then 
            g_menu.right_aa:SetInt(g_custom_aa["Global"]["Right desync"]:Get())
            g_menu.left_aa:SetInt(g_custom_aa["Global"]["Left desync"]:Get())
        elseif g_custom_aa["Global"]["Desync mode"]:Get() == 1 then 
            local dsy = math_random( g_custom_aa["Global"]["Desync 3"]:Get() , g_custom_aa["Global"]["Desync 4"]:Get() )
            g_menu.right_aa:SetInt(dsy)
            g_menu.left_aa:SetInt(dsy)
        else
            local dsy_jit = jitter and g_custom_aa["Global"]["Desync 1"]:Get() or g_custom_aa["Global"]["Desync 2"]:Get()
            g_menu.right_aa:SetInt(dsy_jit)
            g_menu.left_aa:SetInt(dsy_jit)
        end

        g_menu.fake_options:SetInt(g_custom_aa["Global"]["Fake options"]:Get())
        g_menu.lby_options:SetInt(g_custom_aa["Global"]["Lby mode"]:Get())
        g_menu.freestand_options:SetInt(g_custom_aa["Global"]["Freestanding"]:Get())
        g_menu.dsy_on_shot:SetInt(g_custom_aa["Global"]["On shot"]:Get())

    end


end
--#endregion

--#region legit aa 

g_antiaim.legit_aa = function(cmd)

    local wpn = g_cl.m_local:GetActiveWeapon()
    if not wpn or not g_antiaim.additions:Get(5) then return end

    local team = g_cl.m_local:GetProp("m_iTeamNum")
    local can_plant =  g_cl.m_local:GetProp("m_bInBombZone") and wpn:GetClassName() == "CC4" 
    
    local bombs     = EntityList.GetEntitiesByName("CPlantedC4")
    local bomb_distance = #bombs > 0 and distance(bombs[#bombs]:GetProp("m_vecOrigin") , g_cl.m_local:GetProp("m_vecOrigin")) or 9999
    local can_defuse = bomb_distance < 62 and team == 3

    if can_plant or can_defuse then return end 

    local eyepos = g_cl.m_local:GetEyePosition()
    local final_point = eyepos + g_cl.m_angle_view * 8192 -- awp range -> highest possible range 

    local trace = ray (eyepos, final_point, g_cl.m_local , 0x4600400B)

    if trace == nil or trace.fraction > 1 or trace.hit_entity == nil then return end --if we dont look at any entity (most likely never gonna happen)

    local name = trace.hit_entity:GetClassName()
    local override = name == "CWorld" or name == "CFuncBrush" or name == "CCSPlayer" --if we look at any of these we can override our yaw and pitch 

    if bit.band(cmd.buttons, 32) ~= 32 or not override then return end

    AntiAim.OverridePitch(0)
    AntiAim.OverrideYawOffset(180)
    cmd.buttons = bit.band(cmd.buttons, bit.bnot(bit.lshift(1, 5)))

end

--#endregion

--#region rollangle 

angle_vec = function(angles)
    local forward, right = new_vec(), new_vec()

    local pitch, yaw, roll = angles.pitch * math_pi / 180, angles.yaw * math_pi / 180, angles.roll * math_pi / 180
    local cp = math_cos(pitch)
    local sp = math_sin(pitch)

    local cy = math_cos(yaw)
    local sy = math_sin(yaw)

    local cr = math_cos(roll)
    local sr = math_sin(roll)

    forward.x = cp * cy
    forward.y = cp * sy
    forward.z = -sp

    right.x = -1 * sr * sp * cy + -1 * cr * -sy
    right.y = -1 * sr * sp * sy + -1 * cr * cy
    right.z = -1 * sr * cp

    return forward, right
end

local actual_mov = new_vec2(0, 0)
mov_fix = function(cmd)
    local frL, riL = angle_vec(new_angle(0, cmd.viewangles.yaw, 0))
    local frC, riC = angle_vec(cmd.viewangles)

    frL.z = 0
    riL.z = 0
    frC.z = 0
    riC.z = 0

    frL = frL / vec_length(frL)
    riL = riL / vec_length(riL)
    frC = frC / vec_length(frC)
    riC = riC / vec_length(riC)

    local worldCoords = frL * actual_mov.x + riL * actual_mov.y

    cmd.sidemove = (frC.x * worldCoords.y - frC.y * worldCoords.x) / (riC.y * frC.x - riC.x * frC.y)
    cmd.forwardmove = (riC.y * worldCoords.x - riC.x * worldCoords.y) / (riC.y * frC.x - riC.x * frC.y)
end

g_antiaim.roll = function(cmd)
    if not g_antiaim.additions:Get(1) then return end

    g_cl.roll = false
    local status
    local manual   = g_menu.yaw_base:GetInt() == 3 or g_menu.yaw_base:GetInt() == 2
    local roll_val = inverter() and -45 or 45

    if manual then 
        status = "Manual"
    else  
       status = g_cl.m_condition
    end

    local cond     =  status ~= "Manual" and cond_to_int[g_cl.m_condition] or 7

    if g_antiaim.roll_cond:Get(cond) then 
        cmd.viewangles.roll = roll_val
        g_cl.roll = true
    end

end

g_antiaim.roll_fix = function(cmd)
    if not g_antiaim.additions:Get(1) then return end
    actual_mov = new_vec2(cmd.forwardmove, cmd.sidemove)
    mov_fix(cmd)
end
--#endregion

--#region anti bruteforce 
local brute_timer = 0
local brute_delay = 0
g_bruteforce.handle_impact = function(e)
    if e:GetName() ~= "bullet_impact" or not g_bruteforce.main:GetBool() then return end

    local id = e:GetInt("userid")
    local player = EntityList.GetPlayerForUserID(id)

    if id == nil or player == nil or player:IsTeamMate() or player == g_cl.m_local then return end

    local to_trace = g_bruteforce.origin:GetInt() == 0 and g_cl.m_local:GetEyePosition() or g_cl.m_local:GetHitboxCenter(6)
    local start    = player:GetEyePosition()
    local finish   = new_vec( e:GetInt("x") , e:GetInt("y") , e:GetInt("z") )
    local distance = scan_ray(start , finish , to_trace )

    if distance < g_bruteforce.range:GetInt() then
        if brute_delay < GlobalVars.realtime then 

            g_bruteforce.stage =  g_bruteforce.stage == phase_amount:GetInt() and 0 or g_bruteforce.stage + 1

            brute_timer = g_bruteforce.options:Get(2) and GlobalVars.realtime + g_bruteforce.duration:GetInt() or  GlobalVars.realtime + 3.5

            if not is_alive(g_cl.m_local) then return end

            if g_bruteforce.stage >= 1 then
                local str = string_format("anti brute triggedred by %s from distance [%d][%d] " , player:GetName() , round(distance) , g_bruteforce.stage)
                add_notification(str , 1 , g_bruteforce.bf_color:GetColor() , white)
            else
                local str = string_format("reinitialized bruteforce [%d][0] ", round(distance))

                add_notification(str, 1 , g_bruteforce.bf_color:GetColor() , white)
            end
       end

        brute_delay = GlobalVars.realtime + 0.175 -- we want to wait a bit cuz of fast firing weapons 

    end

end

g_bruteforce.apply_settings = function ()

    if not g_bruteforce.main:GetBool() then return end
    if g_bruteforce.stage == 0 then return end

    g_bruteforce.to_brute = brute_timer > GlobalVars.realtime and true or false

    if brute_timer < GlobalVars.realtime then return end --// if our timer expired -> dont bruteforce

    local delta = g_bruteforce.stage_creation[g_bruteforce.stage]:GetInt()

    AntiAim.OverrideLimit(math_abs(delta))
    AntiAim.OverrideInverter(delta < 0)

    if g_bruteforce.options:Get(1) then 
        AntiAim.OverrideYawOffset(0) -- if we force static -> inverter static cause line above + static yaw -> full static
    end

end

--#endregion

--#region fakelag exploit 

g_antiaim.handle_fakelag_exploit = function(cmd)

    g_cl.fl_exploit = false

    if g_menu.dt:GetBool() or g_menu.hs:GetBool() or g_menu.fake_duck:GetBool() or not g_antiaim.additions:Get(2) then return end

    local exp_cond =  g_cl.m_condition ~= "Ducking" and cond_to_int[g_cl.m_condition] or cond_to_int[g_cl.m_condition] - 2

    local lby = math_random(0,1) == 0 and 58 or -58

    local tick = cmd.tick_count % 2 == 0

    if g_antiaim.fl_exploit:Get(exp_cond) then 

        processticks:SetInt( tick and 17 or 18)

        g_cl.fl_exploit = true

        if ClientState.m_choked_commands < 17 then
            FakeLag.SetState(false)
            if ClientState.m_choked_commands >= 16 then
                AntiAim.OverrideYawOffset(inverter and 115 or -115)
                AntiAim.OverrideLBYOffset(lby)
            end

        end

    end

end

--#endregion

--#region disable fl on hs 
local to_fl
g_antiaim.disable_fl = function ()
    to_fl = true
    if g_fakelag.main:GetBool() and g_antiaim.additions:Get(3) and g_menu.hs:GetBool() then
       to_fl = false
    elseif not g_fakelag.main:GetBool() and g_antiaim.additions:Get(3) and g_menu.hs:GetBool() then
       g_menu.enable_fl:SetBool(false)
    elseif g_antiaim.additions:Get(3) and not g_fakelag.main:GetBool() then 
      g_menu.enable_fl:SetBool(true)
    end
   
end

--#endregion

--#region teleport in air 

g_antiaim.handle_teleport = function()
    local weap = g_cl.m_local:GetActiveWeapon()
    if not g_menu.dt:GetBool() or not g_antiaim.additions:Get(4) or weap == nil or Exploits.GetCharge() ~= 1 then return end
 
    local players = EntityList.GetPlayers()
    
    for k , v in ipairs(players) do

        if (g_antiaim.tele_weapon:GetInt() == 0 and weap:GetWeaponID() ~= 40) or g_antiaim.tele_mode:GetInt() == 1 and not in_air(g_cl.m_local) then goto skip end

        if v:IsTeamMate() or v == g_cl.m_local or not is_alive(v) or v:IsDormant() then  goto skip end

        if Cheat.FireBullet(v, v:GetEyePosition(), g_cl.m_local:GetEyePosition()).damage > 0 then --// if enemy can possibly damage us
            Exploits.ForceTeleport()
        end

        ::skip::

    end

end

--#endregion

--#region no fl on shot -> called later on in shot handler

g_events.on_shot = function(shot)
    if not g_antiaim.additions:Get(7) then return end
    FakeLag.ForceSend()
end

--#endregion


--# region separate ground ticks
g_fakelag.ground_ticks = 0

g_fakelag.handle_land = function()

    if in_air(g_cl.m_local) then
        g_fakelag.ground_ticks = 0
    else
        g_fakelag.ground_ticks = g_fakelag.ground_ticks + 1
    end
    
end

--#region custom fakelag
local step = 0
local step_limit = 14
local current_choke = 0
local ticks_to_choke

g_fakelag.initilize_choke = function()

    if not g_fakelag.main:GetBool() or Exploits.GetCharge() == 1 or not to_fl then current_choke = 0 return end

    if g_fakelag.mode:GetInt() == 0 then 
        ticks_to_choke = g_fakelag.choke:GetInt() - math.random(0 , g_fakelag.variance:GetInt()) 
    elseif g_fakelag.mode:GetInt() == 2 then

        if step > 2 then
            step = 0
        end
    
        if step == 0 then
            step_limit = g_fakelag.step1:GetInt()
        elseif step == 1 then
            step_limit = g_fakelag.step2:GetInt()
        elseif step == 2 then
            step_limit = g_fakelag.step3:GetInt()
        end

        ticks_to_choke = step_limit
    else

        local weap = g_cl.m_local:GetActiveWeapon()
        if weap == nil then return end
        local speed = weap:GetMaxSpeed()

        ticks_to_choke =  round(g_cl.m_local:GetProp("m_vecVelocity"):Length() / speed *  g_fakelag.choke:GetInt()) - math.random(0 , g_fakelag.variance:GetInt())
    end

    if g_cl.fl_exploit then 
        ticks_to_choke = 17
    end
    if g_menu.fake_duck:GetBool() then 
        ticks_to_choke = 14
    end

    if g_fakelag.ground_ticks <= 1 and g_fakelag.ground_ticks >= 5 then 
        current_choke = 0
    end
    
end

g_fakelag.handle_choke = function()

    if not g_fakelag.main:GetBool() or Exploits.GetCharge() == 1 or not to_fl then return end

    g_menu.enable_fl:SetBool(false)

    local state = current_choke < ticks_to_choke

    if g_fakelag.ground_ticks >= 1 and g_fakelag.ground_ticks <= 5 then
       FakeLag.SetState(true)
       return
    end
    
    if current_choke < ticks_to_choke then
        current_choke = current_choke + 1
    else 
        step = step + 1
        current_choke = 0
    end

    FakeLag.SetState(not state)

end

--#endregion

--#region Indicators

local lua_name     = "bordeaux"
local name1        = "bord"
local name2        = "eaux"
local dsy_size     = 0
local scope_size   = 0
local scope_size_2 = 0

g_visuals.handle_anti_aim_arrow = function()
    if not g_visuals.indic_options:Get(2) or not g_visuals.main:GetBool() then return end
    local active    = inverter() and g_visuals.active_side:GetColor() or g_visuals.inactive_side:GetColor()
    local inactive  = inverter() and g_visuals.inactive_side:GetColor() or g_visuals.active_side:GetColor()
    local inactive2 = inverter() and color_int(17, 17, 17, 130) or g_visuals.active_side:GetColor()
    local active2   = inverter() and g_visuals.active_side:GetColor() or color_int(17, 17, 17, 130) 

    local scoped   = g_cl.m_local:GetProp("m_bIsScoped")
    local size     = (scoped and g_visuals.indic_mode:GetInt() == 2) and 55 or 0
    local speed    = g_visuals.indic_mode:GetInt() == 2 and 12 or 6
    
    if g_visuals.indic_mode:GetInt() == 4 and g_visuals.anim:GetBool() and scoped then 
        size = 55
    end

    if size ~= scope_size_2 then
        scope_size_2 = lerp(scope_size_2, size, GlobalVars.frametime * speed)
    end

    if g_visuals.arrow_mode:GetInt() == 0 then

       Render_Text("«",  new_vec2(center[1] - 30 + scope_size_2, center[2] - 1 ), active, 25, false, true)
       Render_Text("»",  new_vec2(center[1] + 30 + scope_size_2, center[2] - 1 ), inactive, 25, false, true)

    else

        local poly1 =  --// Teamskit arrows no clue y everyone likes them so much
        {
        new_vec2(  g_cl.screen.x/2-30 + scope_size_2 , g_cl.screen.y/2 - 11 ),
        new_vec2(  g_cl.screen.x/2-30 + scope_size_2 , g_cl.screen.y/2 + 11 ),
        new_vec2(  g_cl.screen.x/2-50 + scope_size_2 , g_cl.screen.y/2 )
        }

        local poly2 = 
        {
        new_vec2(  g_cl.screen.x/2+30 + scope_size_2 , g_cl.screen.y/2 - 10 ),
        new_vec2(  g_cl.screen.x/2+30 + scope_size_2 , g_cl.screen.y/2 + 10 ),
        new_vec2(  g_cl.screen.x/2+50 + scope_size_2 , g_cl.screen.y/2 )
        }

        poly(color_int(17, 17, 17, 130),poly1[1],poly1[2],poly1[3])

        poly(color_int(17, 17, 17, 130),poly2[1],poly2[2],poly2[3])

        Render_BoxFilled(poly1[1] + new_vec2(1,0) , poly1[2] + new_vec2(3,0) , active2)

        Render_BoxFilled(poly2[1] - new_vec2(1,0) , poly2[2] - new_vec2(3,0) , inactive2)

    end

end

g_visuals.handle_dmg_ind = function()
    if not g_visuals.indic_options:Get(4) or Cheat.IsMenuVisible() or not g_visuals.main:GetBool() then return end
    local dmg    = tostring(Menu_FindVar("Aimbot", "Ragebot", "Accuracy", "Minimum Damage"):GetInt())
    local height = g_visuals.dmg_height:GetInt() == 0 and -25 or 15
    local width  = g_visuals.dmg_width:GetInt() == 0 and -15 or 15
    local color  = g_visuals.dmg_color:GetColor()

    Render_Text(dmg, new_vec2(center[1] + width, center[2] + height), color, 10, g_Fonts.Pixel, true, true)
end

local g_indicators = {
    [1] = {
        active = function() return g_menu.fake_duck:GetBool() end,
        color  = function(valid, invalid) return valid end,
        ypos   = center[2] + 30,
        name   = "FD"
    },
    [2] = {
        active = function() return g_menu.dt:GetBool() end,
        color  = function(valid, invalid) return Exploits.GetCharge() == 1 and valid or invalid end,
        ypos   = center[2] + 30,
        name   = "DT"
    },
    [3] = {
        active = function() return g_menu.hs:GetBool() end,
        color  = function(valid, invalid) return (g_menu.fake_duck:GetBool() or g_menu.dt:GetBool()) and invalid or valid end,
        ypos   = center[2] + 30,
        name   = "OS-AA"
    },
    [4] = {
        active = function() return g_menu.auto_peek:GetBool() end,
        color  = function(valid, invalid) return valid end,
        ypos   = center[2] + 30 ,
        name   = "PEEK"
    },
    [5] = {
        active = function() return (g_menu.baim:GetInt() == 2 and g_menu.baim_disable:GetInt() == 0) end,
        color  = function(valid, invalid) return valid end,
        ypos   = center[2] + 30 ,
        name   = "SAFE"
    },
    [6] = {
        active = function() return g_menu.safe_point:GetInt() == 2 end,
        color  = function(valid, invalid) return valid end,
        ypos   = center[2] + 30 ,
        name   = "BAIM"
    }
}

g_visuals.handle_crosshair_indicator = function()

    if not g_visuals.main:GetBool() or g_visuals.indic_mode:GetInt() == 0 or not g_visuals.indic_options:Get(3) then return end

    local scoped   = g_cl.m_local:GetProp("m_bIsScoped")
    local size     = scoped and 55 or 0
    local color1   = g_visuals.gradient1:GetColor()
    local color2   = g_visuals.gradient2:GetColor()
    local bf_color = g_bruteforce.bf_color:GetColor()
    local height   = 0
    local timing   = g_bruteforce.options:Get(2) and g_bruteforce.duration:GetInt() or 3.5 
    local percent  = (brute_timer - GlobalVars.realtime ) / timing
    local active , inactive   = inverter() and g_visuals.active_side:GetColor() or g_visuals.inactive_side:GetColor() ,  inverter() and g_visuals.inactive_side:GetColor() or g_visuals.active_side:GetColor()

    if g_visuals.indic_mode:GetInt() == 1 then
        local valid, invalid = g_visuals.valid_color:GetColor(), g_visuals.invalid_color:GetColor()


        Render_Text(name1, new_vec2(center[1] - textsize(name1, 15, g_Fonts.Calibri).x, center[2] + 25), active, 15, g_Fonts.Calibri, true, false)
        Render_Text(name2, new_vec2(center[1], center[2] + 25), inactive, 15, g_Fonts.Calibri, true, false)

        if g_bruteforce.to_brute and g_bruteforce.stage > 0 and  bf_color.a > 0 then 
           
            Render_BoxFilled(new_vec2(center[1] , center[2] + 44 + height), new_vec2(center[1] - 51 * percent, center[2] + 48 + height), black) -- 1st outline

            Render_BoxFilled(new_vec2(center[1] , center[2] + 44 + height), new_vec2(center[1] + 51 * percent, center[2] + 48 + height), black) -- 2nd outline 

            Render_BoxFilled(new_vec2(center[1] , center[2] + 45 + height), new_vec2(center[1] - 50 * percent, center[2] + 47 + height), bf_color)

            Render_BoxFilled(new_vec2(center[1] , center[2] + 45 + height), new_vec2(center[1] + 50 * percent, center[2] + 47 + height), bf_color)

            height = height + 15
        end

        local idx = 0
        for i = 1 , #g_indicators do
            local v = g_indicators[i]
            local k = v.name
            if v.active() then
                local y_position = center[2] + 45 + (idx * 10) + height
                v.ypos = lerp(v.ypos, y_position, GlobalVars.frametime * 8)
                Render_Text(k, new_vec2(center[1] + 2, v.ypos), v.color(valid, invalid), 10, g_Fonts.Pixel, true, true)
                idx = idx + 1
            end
        end

    elseif g_visuals.indic_mode:GetInt() == 2 then
        local weap = g_cl.m_local:GetActiveWeapon()
        if weap == nil then return end
        height = 155

        local height2 = 0

        local vel      = g_cl.m_local:GetProp("m_vecVelocity"):Length() / weap:GetMaxSpeed() <= 1 and  g_cl.m_local:GetProp("m_vecVelocity"):Length() / weap:GetMaxSpeed() or 1
        local dsy      = delta() / 58 >= 0.15 and delta() / 58 or 0
        local fl       = not (g_menu.dt:GetBool() and Exploits.GetCharge() == 1) and clamp(ClientState.m_choked_commands / 14,0,1) or 0
        local dt_color = (g_menu.dt:GetBool() and Exploits.GetCharge() ~= 1) and color_int(255, 36, 76, 255) or color1

        if dsy_size ~= dsy then
            dsy_size = lerp(dsy_size, dsy, GlobalVars.frametime * 10)
        end

        if size ~= scope_size then
            scope_size = (lerp(scope_size, size, GlobalVars.frametime * 12))
        end

        if g_bomb.time > 0 then
            local str = string_format("%s - %s", g_bomb.site, round(g_bomb.time, 2))
            Render_Text(str, new_vec2(center[1] + scope_size - 21, center[2] + height), color1, 10, g_Fonts.Pixel, true, false)
            height = height + 20
        end

        if g_menu.dt:GetBool() then
            local dt_str = (g_menu.dt:GetBool() and Exploits.GetCharge() == 1) and "DOUBLETAP" or "DOUBLETAP [CHARGE: " .. round(Exploits.GetCharge() * 100) .. "%]"
            Render_Text(dt_str, new_vec2(center[1] + scope_size, center[2] + height), dt_color, 10, g_Fonts.Pixel, true, true)
            height = height + 10
        end

        if g_menu.yaw_base:GetInt() == 5 then
            Render_Text("FREESTAND", new_vec2(center[1] + scope_size, center[2] + height), color1, 10, g_Fonts.Pixel, true, true)
            height = height + 10
        end

        Render_Gradient(new_vec2(center[1] + scope_size - 0.5, center[2] + 45), new_vec2(center[1] + scope_size + 0.5, center[2] + 150), color1, color1, color2, color2)
        Render_Text(lua_name, new_vec2(center[1] + scope_size, center[2] + 32), color1, 10, g_Fonts.Pixel, true, true)

        if g_bruteforce.to_brute and g_bruteforce.stage > 0 and bf_color.a > 0 then 
            local timing  = g_bruteforce.options:Get(2) and g_bruteforce.duration:GetInt() or 3.5 
            local percent = (brute_timer - GlobalVars.realtime ) / timing
            Render_Text("BRUTING", new_vec2(center[1] + scope_size - textsize("BRUTING", 10, g_Fonts.Pixel).x - 5, center[2] + 43), color1, 10, g_Fonts.Pixel, true, false)
            Render_Gradient(new_vec2(center[1] + scope_size - 0.5, center[2] + 45), new_vec2(center[1] + scope_size + 50 * percent, center[2] + 47), color1, color2, color1, color2)
            height2 = height2 + 15
        end

        Render_Text("DESYNC", new_vec2(center[1] + scope_size - textsize("DESYNC", 10, g_Fonts.Pixel).x - 5, center[2] + 43 + height2), color1, 10, g_Fonts.Pixel, true, false)
        Render_Gradient(new_vec2(center[1] + scope_size - 0.5, center[2] + 45 + height2 ), new_vec2(center[1] + scope_size + 50 * dsy_size, center[2] + 47 + height2), color1, color2, color1, color2)

        Render_Text("FAKELAG", new_vec2(center[1] + scope_size - textsize("FAKELAG", 10, g_Fonts.Pixel).x - 5, center[2] + 57 + height2), color1, 10, g_Fonts.Pixel, true, false)
        Render_Gradient(new_vec2(center[1] + scope_size - 0.5, center[2] + 60 + height2), new_vec2(center[1] + scope_size + 50 * fl, center[2] + 62 + height2), color1, color2, color1, color2)

        Render_Text("VELOCITY", new_vec2(center[1] + scope_size - textsize("VELOCITY", 10, g_Fonts.Pixel).x - 5, center[2] + 72 + height2), color1, 10, g_Fonts.Pixel, true, false)
        Render_Gradient(new_vec2(center[1] + scope_size - 0.5, center[2] + 75 + height2), new_vec2(center[1] + scope_size + 50 * vel, center[2] + 77 + height2), color1, color2, color1, color2)

    elseif g_visuals.indic_mode:GetInt() == 3 then


        Render_Text(name1, new_vec2(center[1] - textsize(name1, 15, g_Fonts.Calibri).x, center[2] + 25), active, 15, g_Fonts.Calibri, true, false)

        Render_Text(name2, new_vec2(center[1], center[2] + 25), inactive, 15, g_Fonts.Calibri, true, false)

        if g_bruteforce.to_brute and g_bruteforce.stage > 0 and bf_color.a > 0 then 

            Render_BoxFilled(new_vec2(center[1] , center[2] + 44 ), new_vec2(center[1] - 51 * percent, center[2] + 48 ), black) -- 1st outline

            Render_BoxFilled(new_vec2(center[1] , center[2] + 44 ), new_vec2(center[1] + 51 * percent, center[2] + 48 ), black) -- 2nd outline 

            Render_BoxFilled(new_vec2(center[1] , center[2] + 45 ), new_vec2(center[1] - 50 * percent, center[2] + 47 ), bf_color)

            Render_BoxFilled(new_vec2(center[1] , center[2] + 45 ), new_vec2(center[1] + 50 * percent, center[2] + 47 ), bf_color)

        end

    else 

        local valid, invalid = g_visuals.valid_color:GetColor(), color_int( 211, 72, 72 , 255 )

        if g_visuals.anim:GetBool() then 
            if size ~= scope_size then
                scope_size = (lerp(scope_size, size, GlobalVars.frametime * 6))
            end
        else 
            scope_size = 0 
        end

        

        if g_bruteforce.to_brute and g_bruteforce.stage > 0 and bf_color.a > 0 then 

            Render_BoxFilled(new_vec2(center[1] , center[2] + 44 ), new_vec2(center[1] - 51 * percent, center[2] + 48 ), black) -- 1st outline

            Render_BoxFilled(new_vec2(center[1] , center[2] + 44 ), new_vec2(center[1] + 51 * percent, center[2] + 48 ), black) -- 2nd outline 

            Render_BoxFilled(new_vec2(center[1] , center[2] + 45 ), new_vec2(center[1] - 50 * percent, center[2] + 47 ), bf_color)

            Render_BoxFilled(new_vec2(center[1] , center[2] + 45 ), new_vec2(center[1] + 50 * percent, center[2] + 47 ), bf_color)

        end

        Render_Shadow(lua_name , new_vec2(center[1] + scope_size , center[2] + 25) , white , 10 , g_Fonts.Pixel , true , true)


        local lby = math_abs(round(g_cl.m_lby))
        local lby_str = tostring(lby)
        if lby < 100 then 
            lby_str = "0"..lby
        elseif lby < 10 then 
            lby_str = "00"..lby
        end

        local delta_str = string_format("%s" , delta() >= 10 and delta() or "0"..delta())
        local info_str   = string_format("[%s][%d][%s]" , delta_str , inverter() and 1 or 0 , lby_str)

        Render_Shadow(info_str , new_vec2(center[1] + scope_size , center[2] + 35) , white , 10 , g_Fonts.Pixel , true , true)

        local idx = 0
        for i = 1 , #g_indicators do
            local v = g_indicators[i]
            local k = v.name
            if v.active() then
                if k == "DT" then k = "Shift" end
                local y_position = center[2] + 48 + (idx * 10)
                v.ypos = lerp(v.ypos, y_position, GlobalVars.frametime * 18)
                Render_Text(k, new_vec2(center[1] + scope_size , v.ypos), v.color(valid, invalid), 10, g_Fonts.Pixel, true, true)
                idx = idx + 1
            end
        end

    end

end
--#endregion

--#region Watermark

g_visuals.handle_watermark = function()

    if not ingame() or not g_visuals.ui_options:Get(1) or not g_visuals.main:GetBool() then
        return -- or just make a separate text for not ingame
    end

    local g_net = EngineClient.GetNetChannelInfo()

    if not g_net then
        return
    end

    local color_text = g_visuals.watermark_text:GetColor()
    local actual_txt = Color_new(color_text.r, color_text.g, color_text.b, 255)
    local color_gradient = g_visuals.watermark_color:GetColor()
    local glow = g_visuals.enable_glow:GetInt() == 1 and "true" or "false"
    local glow_intensity = g_visuals.enable_glow:GetInt() == 1 and g_visuals.glow_intensity:GetFloat() or 0

    local ms = clamp(round(g_net:GetAvgLatency(0) * 1000.0), 0, 999)

    local text = string_format("%s [%s | %s] | fps: %i | ping: %i", lua_name, user, build, get_fps(), ms)

    local size = textsize(text, 11, g_Fonts.Verdana_wtr)

    local bg_str = g_visuals.watermark_bg:GetInt() == 0 and "black" or "blur"

    local centerr   = g_visuals.watermark_loc:GetInt() == 1
    local x        = g_visuals.watermark_loc:GetInt() == 0 and g_cl.screen.x - size.x - 20 or center[1] - (size.x / 2) - 5
    local y        = g_visuals.watermark_loc:GetInt() == 0 and 10 or g_cl.screen.y - 17
    local w        = size.x + 10
    local h        = size.y + 4
    local textpos  = g_visuals.watermark_loc:GetInt() == 0 and new_vec2(g_cl.screen.x - size.x - 15, 11) or new_vec2(center[1], g_cl.screen.y - 10)

    if g_visuals.watermark_mode:GetInt() == 1 then 
        textpos = new_vec2(center[1], g_cl.screen.y - 50)
    end

    if CVar.FindVar("cl_hud_playercount_pos"):GetInt() == 1 and g_visuals.watermark_loc:GetInt() == 1 then
        textpos = new_vec2(center[1], 10)
    end

    if g_visuals.watermark_mode:GetInt() == 0 then
        Render_Solus_Gradient(x, y, w, h, color_gradient, "full" , bg_str, glow, glow_intensity)
        Render_Text(text, textpos, actual_txt, 11, g_Fonts.Verdana_wtr, false, centerr)
    else
        Render_Text("bordeaux | "..build, textpos, actual_txt, 11, g_Fonts.Verdana_wtr, false, true)
    end

end

--#endregion

--#region Keybinds
local drag = {false , false}
local value_to_change = 0
local label = "keybinds"
local static_alpha = 0

g_visuals.keybinds = function()

    local binds = Cheat.GetBinds()

    local do_binds = g_visuals.main:GetBool() and g_visuals.ui_options:Get(2) and (#binds > 0 or Cheat.IsMenuVisible())

    local alpha = do_binds and 255 or 0

    if static_alpha ~= alpha then
        static_alpha = lerp(static_alpha , alpha, GlobalVars.frametime * 8)
    end

    if not do_binds then return end

    local biggest_length = 0
    local biggest_length_mode = -1
    local color = g_visuals.bind_color:GetColor()

    xx = g_visuals.binds_x:Get()
    yy = g_visuals.binds_y:Get()

    local for_centering = textsize(label, 11, g_Fonts.Verdana_wtr).x / 2
    local pos = new_vec2(g_visuals.binds_x:GetInt(), g_visuals.binds_y:GetInt())
    local base_pos_x = pos.x + 5
    local height_offset = 17
    local newest_value = 77

    local function calc_size(bind_table) --@param all keybinds we wanna scan
        
        for i = 1, #bind_table do
            if biggest_length < textsize(bind_table[i]:GetName(), 11, g_Fonts.Verdana_wtr).x then
                biggest_length = textsize(bind_table[i]:GetName(), 11, g_Fonts.Verdana_wtr).x
                biggest_length_mode = bind_table[i]:GetMode()
            end
        end

        local _biggest_length = biggest_length
        local bind_type =        biggest_length_mode == 0 and "[toggled]" or biggest_length_mode == 1 and "[holding]" or "[Testing]"
        _biggest_length = _biggest_length * 1.25 + textsize(bind_type, 11, g_Fonts.Verdana_wtr).x
    
        if _biggest_length >= newest_value then
            newest_value = _biggest_length
        end
    
        if value_to_change ~= newest_value then
            value_to_change = lerp(value_to_change, newest_value, GlobalVars.frametime * 8)
        end
    
        newest_value = value_to_change
    
    end

    local function add_keybind(bind) --@param keybind

        if not bind:IsActive() then return end

        local bind_clr = g_visuals.keybind_mode:GetInt() == 1 and Color_new(color.r, color.g, color.b,  math_floor(static_alpha) ) or color_int(white.r, white.g, white.b,  math_floor(static_alpha) )
        
        Render_Shadow(bind:GetName(), new_vec2(base_pos_x, pos.y + height_offset), bind_clr, 11, g_Fonts.Verdana_wtr)
        local bind_type = bind:GetMode() == 0 and "[toggled]" or bind:GetMode() == 1 and "[holding]"

        if g_visuals.keybind_mode:GetInt() == 0 then
        Render_Shadow(bind_type, new_vec2( pos.x + newest_value - textsize(bind_type, 11, g_Fonts.Verdana_wtr).x - 3, pos.y + height_offset ),color_int(white.r, white.g, white.b,  math_floor(static_alpha) ), 11, g_Fonts.Verdana_wtr )
        end

        height_offset = height_offset + 15
    
    end

    local function render_container(bind , bind2) --@ param first bind , last bind

        if Cheat.IsMenuVisible() then goto hi end
        if not bind:IsActive() and not bind2:IsActive() then return end
        ::hi::
        local bg = g_visuals.binds_bg:GetInt() == 0 and "black" or ""
        local color = g_visuals.bind_color:GetColor()

        if g_visuals.keybind_mode:GetInt() == 0  then 
        Render_Solus_Gradient(pos.x , pos.y , newest_value + 1 , 16 , color, "full" , bg )  
        end  

        local label_pos = g_visuals.keybind_mode:GetInt() == 0 and (pos.x + newest_value / 2 - for_centering) or pos.x + 5

        local bind_clr = g_visuals.keybind_mode:GetInt() == 1 and Color_new(color.r, color.g, color.b,  math_floor(static_alpha) ) or color_int(white.r, white.g, white.b,  math_floor(static_alpha) )

        Render_Shadow(label, new_vec2(label_pos, pos.y + 1), bind_clr, 11, g_Fonts.Verdana_wtr)


    end
   
    if static_alpha > 0 then  --// no clue why i have to do it this way because if i do it any other way binds are delayed when disabled ?_? idk why
        calc_size(binds)
        render_container(binds[1], binds[#binds])
        for i = 1, #binds do
            add_keybind(binds[i])
        end 
    end

    if Cheat.IsKeyDown(0x1) and Cheat.IsMenuVisible() then
        local mouse = Cheat.GetMousePos()
        if drag[1] == true then
            g_visuals.binds_x:SetInt(mouse.x)
            g_visuals.binds_y:SetInt(mouse.y)
        end
        if mouse.x >= xx and mouse.y >= yy and mouse.x <= xx + newest_value and mouse.y <= yy + 19 then
            if drag[2] == false then
                drag[1] = true
            end
        end
    else
        drag[1] = false
    end
    
end
--#endregion

--#region Time warning

g_visuals.handle_time_warning = function()
    if not ingame() or not g_visuals.indic_options:Get(5) or not g_visuals.main:GetBool() then
        return
    end

    local game_rules        = EntityList.GetGameRules()
    local m_fRoundStartTime = game_rules:GetProp("m_fRoundStartTime") --// start
    local m_iRoundTime      = game_rules:GetProp("m_iRoundTime") --// round time
    local time_left         = (g_bomb.site == "" or g_bomb.site == nil) and (m_fRoundStartTime + m_iRoundTime) - GlobalVars.curtime or g_bomb.time --// time left
    local max               = g_visuals.warning_time:GetInt() --// max time for rendering scale
    local clr               = g_visuals.warning_color:GetColor()
    local team              = g_cl.m_local:GetProp("m_iTeamNum")
    local t                 = team == 2 
    local ct                = team == 3 

    local pct               = clamp(time_left / max, 0, 1)

    local warn              = time_left < max and time_left > 0

    if (t and g_bomb.site == "A") or (t and g_bomb.site == "B") then return end --// enemy needs to push no need to look at time

    if (ct and g_bomb.site == "") or (ct and g_bomb.site == nil) then return end --// enemy needs to push no need to look at time

    if warn  then
        Render_Text("Time Warning", new_vec2(center[1], center[2] - 125), clr , 11, g_Fonts.Verdana_wtr, true, true)
        Render_Text(tostring(round(time_left, 2)), new_vec2(center[1] - 15, center[2] - 115), clr, 11, g_Fonts.Verdana_wtr, true, false)
        Render_BoxFilled(new_vec2(center[1] - 99, center[2] - 98), new_vec2(center[1] + 99, center[2] - 101), black, 2) --// Static bar
        Render_BoxFilled(new_vec2(center[1] - 98, center[2] - 99), new_vec2(center[1] - 98 + 196 * pct, center[2] - 100), clr, 2) -- // Timer
    end

end
--#endregion

--#region Info display

g_visuals.handle_information_display = function()
    if not ingame() or not g_visuals.indic_options:Get(6) or not g_visuals.main:GetBool() then
        return
    end

    local height   = (g_visuals.watermark_loc:GetInt() == 0 and g_visuals.ui_options:Get(1) and g_visuals.watermark_mode:GetInt() == 0) and 35 or 5
    local usr_str  = string_format("user - > %s", user)
    local usr_size = textsize(usr_str, 11, g_Fonts.Verdana_wtr).x

    Render_Shadow(usr_str, new_vec2(g_cl.screen.x - 10 - usr_size, height), white , 11, g_Fonts.Verdana_wtr)
    height = height + 15

    local net_str  = string_format("yaw - > %d", EngineClient.GetViewAngles().yaw)
    local net_size  = textsize(net_str, 11, g_Fonts.Verdana_wtr).x
    Render_Shadow(net_str, new_vec2(g_cl.screen.x - net_size - 10, height), white, 11, g_Fonts.Verdana_wtr)
    height = height + 15

    local fl_str  = string_format("choke - > %d", g_fakelag.main:GetBool() and current_choke or ClientState.m_choked_commands)
    local fl_size = textsize(fl_str, 11, g_Fonts.Verdana_wtr).x
    Render_Shadow(fl_str, new_vec2(g_cl.screen.x - fl_size - 10, height), white, 11, g_Fonts.Verdana_wtr)
    height = height + 15

    local interp   = round(GlobalVars.interpolation_amount)
    local interp_str  = string_format("interp - > %s", interp)
    local interp_size = textsize(interp_str, 11, g_Fonts.Verdana_wtr).x
    Render_Shadow(interp_str, new_vec2(g_cl.screen.x - 10 - interp_size, height), white , 11, g_Fonts.Verdana_wtr)
    height = height + 15

    local dsy      = delta() / 58 >= 0.1 and tostring(round(delta() / 58, 2)) or "fail"
    local dsy_str  = string_format("dsy - > %s", dsy)
    local dsy_size = textsize(dsy_str, 11, g_Fonts.Verdana_wtr).x
    Render_Shadow(dsy_str, new_vec2(g_cl.screen.x - 10 - dsy_size, height), white , 11, g_Fonts.Verdana_wtr)
    height = height + 15

    if g_menu.dt:GetBool() or g_menu.hs:GetBool() then
        local chrg_str  = string_format("charge - > %d", Exploits.GetCharge())
        local chrg_size = textsize(chrg_str, 11, g_Fonts.Verdana_wtr).x
        Render_Shadow(chrg_str, new_vec2(g_cl.screen.x - 10 - chrg_size, height), white, 11, g_Fonts.Verdana_wtr)
        height = height + 15
    end

end
--#endregion

--#region Bomb information

g_bomb.update_bomb_info = function()

    local planted_bombs = EntityList.GetEntitiesByName('CPlantedC4') --// all planted bombs

    for index, bomb in ipairs(planted_bombs) do
        if not bomb then
            goto skip
        end
        --// grab additional info on bomb
        local bomb_time = bomb:GetProp("m_flC4Blow")
        g_bomb.time = bomb_time - GlobalVars.curtime
        local bomb_defused = bomb:GetProp("m_bBombDefused") == 1

        if g_bomb.time < 0 or bomb_defused then --// exploded or defused
            goto skip
        end

        ::skip::
    end
end

g_bomb.update_site = function(e)
    if e:GetName() == "bomb_planted" then --// if bomb is planted
        g_bomb.site = e:GetInt("site") % 2 == 0 and "A" or "B" --// % since valve gives us site as an int :kek:
    elseif e:GetName() == "bomb_defused" or g_bomb.time < 0 or e:GetName() == "round_end" or e:GetName() == "round_start" then --// no bomb = no site
        g_bomb.site = ""
        g_bomb.time = 0
    end
end
--#endregion

--#region Console / Top screen log render

g_visuals.handle_log_render = function()
    if not g_visuals.main:GetBool() or not connected() or not g_visuals.log_mode:Get(2) then return end
    -- event log
    local color = g_visuals.log_color:GetColor()

    local left_time = 0.0
    local size = 12
    local base_y = 5

    if #logs > 0 and #logs <= 10 then
        for i = 1, #logs do
            if (logs[i] ~= nil) then
                logs[i].expiration = logs[i].expiration - GlobalVars.frametime
                if (logs[i].expiration <= 0.00) then
                    table_remove(logs, i)
                end
            end
        end
    elseif #logs > 10 then 
        table_remove(logs, 1)
    end

    if #logs > 0 then
        for i = 1, #logs do
            -- nil check
            if (logs[i] ~= nil) then

                left_time = logs[i].expiration
                local color_a = 255

                if left_time <= 0.5 then
                    local f = left_time
                    f = clamp(f, 0.0, 0.5)

                    f = f / 0.5

                    color_a = round(f * 255.0)

                    if (i == 1 and f <= 0.25) then
                        base_y = base_y - (size * (1.0 - f / 0.25))
                    end
                else
                    color_a = 255
                end

                local color_log = Color_new(color.r, color.g, color.b, color_a / 255)

                local pos = new_vec2(8, base_y)
                local pos2 = new_vec2(pos.x+1, pos.y+1)

                Render_Shadow(logs[i].text, pos, color_log, 10, g_Fonts.Log, false, false)

                base_y = base_y + size
            end
        end
    end
    
end
--#endregion

--#region Hud log / message renderer

g_visuals.handle_hud_render = function ()
    local x = g_cl.screen.x
    local y = g_cl.screen.y
    if #logs_hud > 0 then
        if GlobalVars.realtime >= logs_hud[1][2] then
            if logs_hud[1][3] > 0 then
                logs_hud[1][3] = logs_hud[1][3] - 2
            elseif logs_hud[1][3] <= 0 then
                table_remove(logs_hud, 1)
            end
        end
        if #logs_hud > 5 then
            table_remove(logs_hud, 1)
        end
        for i = 1, #logs_hud do
            local size_str   = textsize(logs_hud[i][1], 11, g_Fonts.Verdana)
            if logs_hud[i][3] < 255 then
                logs_hud[i][3] = logs_hud[i][3] + 1
            end

            local color      = Color_new(logs_hud[i][4].r, logs_hud[i][4].g, logs_hud[i][4].b, 255)
            local text_clr   = Color_new(logs_hud[i][5].r, logs_hud[i][5].g, logs_hud[i][5].b, 255)
            
            Render_Blur(new_vec2(math_min(50, logs_hud[i][3] * 2) - 60 + x / 2 - size_str.x / 2, y - 256 + 34 * i), new_vec2(math_min(50, logs_hud[i][3] * 2) - 40 + x / 2 + size_str.x / 2, y - 242 + 34 * i + size_str.y), color_int(17,17,17,130) , 100)
            Render_BoxFilled(new_vec2(math_min(50, logs_hud[i][3] * 2) - 50 + x / 2 - size_str.x / 2, y - 256 + 34 * i), new_vec2(math_min(50, logs_hud[i][3] * 2) - 50 + x / 2 - size_str.x / 2 + math_min(size_str.x, logs_hud[i][3] * 7), y - 254 + 34 * i), color)
            Render_BoxFilled(new_vec2(math_min(50, logs_hud[i][3] * 2) - 50 + x / 2 + size_str.x / 2 - math_min(size_str.x, logs_hud[i][3] * 7), y - 241 + size_str.y + 34 * i), new_vec2(math_min(50, logs_hud[i][3] * 2) - 50 + x / 2 + size_str.x / 2, y - 243 + size_str.y + 34 * i), color)
            Render_Circle(new_vec2(math_min(50, logs_hud[i][3] * 2) - 50 + x / 2 - size_str.x / 2, y - 243 + 34 * i), 12, 30, color, 2, 270 - math_min(180, logs_hud[i][3] * 3), 270)
            Render_Circle(new_vec2(math_min(50, logs_hud[i][3] * 2) - 50 + x / 2 + size_str.x / 2, y - 243 + 34 * i), 12, 30, color, 2.5, 90, 90 - math_min(180, logs_hud[i][3] * 3))
            Render_Shadow(logs_hud[i][1], new_vec2(math_min(50, logs_hud[i][3] * 2) - 50 + x / 2 - size_str.x / 2, y - 250 + 34 * i), text_clr, 11, g_Fonts.Verdana)
        end
    end
end
--#endregion

--#region Hit log

g_events.on_hit = function(shot)
    if not g_visuals.main:GetBool() or not g_visuals.log_options:Get(1) or shot.reason ~= 0 then
        return
    end

    local entity = EntityList.GetClientEntity(shot.target_index)
    local player = entity:GetPlayer()
    local hitbox = hitgroup_names[shot.hitgroup + 1] or ""
    local aimed_hitbox = hitgroup_names[shot.wanted_hitgroup + 1] or ""
    local name = player:GetName()

    local hc = string.format("%i%s", round(shot.hitchance), "%")

    local log = string.format("Hit %s's %s for %i(%i) damage, aimed=%s(%s) bt=%i(%ims)%s\n" , name, hitbox, shot.damage, shot.wanted_damage, aimed_hitbox, hc, shot.backtrack, math_floor(ticks_to_time(shot.backtrack) * 1000), (aimed_hitbox ~= hitbox or shot.damage ~= shot.wanted_damage) and "(mismatch)" or "" )
    local chat_log = string.format("{green} Hit {white} %s's  %s for {green} %i damage" , name , hitbox , shot.damage)

    if g_visuals.log_mode:Get(1) then
        coloredPrint(Color_new(160 / 255, 203 / 255, 39 / 255, 1), "[bordeaux] ")
        coloredPrint(Color_new(220 / 255, 220 / 255, 220 / 255, 1), log)
    end

    if g_visuals.log_mode:Get(2) then
        add_log(log)
    end

    if g_visuals.log_mode:Get(3) then 
        add_notification(log , 1 , g_visuals.log_color:GetColor() , white)
    end

    if g_visuals.log_mode:Get(4) then 
        print_chat(chat_log)
    end

end
--#endregion

--#region Miss log 

g_events.on_miss = function(shot)
    if not g_visuals.main:GetBool() or not g_visuals.log_options:Get(1) or shot.reason == 0 then
        return
    end

    local entity = EntityList.GetClientEntity(shot.target_index)
    local player = entity:GetPlayer()
    local aimed_hitbox = hitgroup_names[shot.wanted_hitgroup + 1] or "?"
    local reason = miss_reason[shot.reason]
    local name = player:GetName()
    local hc = string.format("%i%s", round(shot.hitchance), "%")

    local log = string.format("Missed %s's %s(%s) due to %s, bt=%i(%ims)\n", name, aimed_hitbox, hc, reason, shot.backtrack, math_floor(ticks_to_time(shot.backtrack) * 1000))
    local chat_log = string.format("{red} missed {white} %s's  %s due to {red} %s" , name , aimed_hitbox , reason)


    if g_visuals.log_mode:Get(1) then
        coloredPrint(Color_new(160 / 255, 203 / 255, 39 / 255, 1), "[bordeaux] ")
        coloredPrint(Color_new(220 / 255, 220 / 255, 220 / 255, 1), log)
    end

    if g_visuals.log_mode:Get(2) then
        add_log(log)
    end

    if g_visuals.log_mode:Get(3) then 
        add_notification(log , 1 , g_visuals.log_color:GetColor() , white)
    end

    if g_visuals.log_mode:Get(4) then 
        print_chat(chat_log)
    end
end
--#endregion

--#region Shot handler

g_events.handle_shot = function(shot)
    g_events.on_hit(shot)
    g_events.on_miss(shot)
    g_events.on_shot()
end
--#endregion


--#region  purchase logs 

g_visuals.handle_purchases = function(e)
    if not g_visuals.main:GetBool() or not g_visuals.log_options:Get(3) or e:GetName() ~= "item_purchase" then return end

    local uid = e:GetInt("userid")
    local ent =  EntityList.GetPlayerForUserID(uid)

    if ent == nil or ent:IsTeamMate()  then return end

    local item = e:GetString("weapon"):gsub("weapon_", "")
    
    item = item:gsub("item_", "")
    item = item:gsub("assaultsuit", "kevlar + helmet")
    item = item:gsub("incgrenade", "molotov")
    item = item:gsub( "hegrenade", "flashbang")
    
    if item ~= "unknown" then
        local name = ent:GetName()
        if g_visuals.log_mode:Get(1) then
            coloredPrint(Color_new(160 / 255, 203 / 255, 39 / 255, 1), "[bordeaux] ")
            coloredPrint(Color_new(220 / 255, 220 / 255, 220 / 255, 1), name .. " bought " .. item.."\n")
        end
        if g_visuals.log_mode:Get(2) then
            add_log(name .. " bought " .. item)
        end
    end

end
--#endregion

--#region Custom Scope

g_world.handle_custom_scope = function()

    if g_world.scope_viewmodel:GetBool() then CVar.FindVar("fov_cs_debug"):SetInt(90) else CVar.FindVar("fov_cs_debug"):SetInt(0)end

    if not g_cl.m_local:GetProp("m_bIsScoped") or not g_world.custom_scope:GetBool() then return end
    local weap = g_cl.m_local:GetActiveWeapon()
    if weap == nil then return end

    local offset     = g_world.scope_offset:Get()
    local length     = g_world.scope_length:Get()
    local color      = g_world.custom_scope:GetColor()
    local inaccuracy = weap:GetInaccuracy(weap) + weap:GetSpread(weap)
    local color_2    = Color_new(color.r, color.g, color.b, 0)
    local width      = g_world.scope_width:GetFloat()
    local start_x    = g_cl.screen.x / 2
    local start_y    = g_cl.screen.y / 2

    if g_world.scope_mode:GetInt() == 1 and offset > 0 then
        offset = offset + inaccuracy * g_world.scope_scale:GetInt()
    elseif g_world.scope_mode:GetInt() == 1 and offset < 0 then
        offset = offset - inaccuracy * g_world.scope_scale:GetInt()
    end

    Render_Gradient(new_vec2(start_x - offset + 1, start_y), new_vec2(start_x - offset - length, start_y + width), color, color_2, color, color_2)

    Render_Gradient(new_vec2(start_x + offset, start_y), new_vec2(start_x + offset + length, start_y + width), color, color_2, color, color_2)

    Render_Gradient(new_vec2(start_x, start_y + offset), new_vec2(start_x + width, start_y + offset + length), color, color, color_2, color_2)

    Render_Gradient(new_vec2(start_x, start_y - offset + 1), new_vec2(start_x + width, start_y - offset - length), color, color, color_2, color_2)
end
--#endregion

--#region Hitmarker

local hits = {}
local hitmarkerqueue = {}

g_world.handle_hit_mark = function()
    if not connected() or not g_world.hitmarker:GetBool() then return end
    local color = g_world.hitmarker:GetColor()

    if g_world.marker_mode:Get(2) then --// Damage Marker
        for i, marker in ipairs(hits) do

            if marker.dmg == nil  then goto skip end

            if #hits > 5 then
                table_remove(hits,1)
            end

            local z_raise = (g_world.fade_mode:GetInt() == 1 and g_world.damage_fade:GetInt() == 1) and 30 or 50

            marker.position.z = lerp(marker.position.z, marker.orig.z + (marker.alpha >= 1 and 0 or z_raise),GlobalVars.frametime * 8)
            local render_pos = Render_ToScreen(new_vec(marker.position.x, marker.position.y, marker.position.z))
            marker.alpha = lerp(marker.alpha, 0, GlobalVars.frametime * 3.5)
            local up , down
            
            if g_world.fade_mode:GetInt() == 0 and g_world.damage_fade:GetInt() == 1 then 
                up   = tostring(clamp(round(marker.dmg * marker.alpha), 0 , marker.dmg))
            elseif g_world.fade_mode:GetInt() == 1 and g_world.damage_fade:GetInt() == 1 then
                down = tostring(clamp(round(1 / marker.alpha * 80) , 0 , marker.dmg))
            end

            local method = g_world.fade_mode:GetInt() == 0 and up or down

            if g_world.damage_fade:GetInt() == 1 then --// if we lerp the damage and alpha
                Render_Text( method , render_pos , Color_new(color.r, color.g, color.b, marker.alpha), 11 , g_Fonts.hitmarker)
            else --// if we only lerp the alpha
                Render_Text(tostring(round(marker.dmg)), render_pos , Color_new(color.r, color.g, color.b, marker.alpha), 11 , g_Fonts.hitmarker)
            end
            
            if marker.alpha <= 0.15 then 
                table_remove(hits, 1)
            end 

            ::skip::
 
        end
    end

    if g_world.marker_mode:Get(1) then --// "+" Marker
        for k, v in ipairs(hitmarkerqueue) do
            if #hitmarkerqueue > 8 then 
                table_remove(hitmarkerqueue, 1)
            end
                
            v.alpha = lerp(v.alpha, 0, GlobalVars.frametime * 3.5)

            local render_posi = Render_ToScreen(v.position)

            -- Render_Text("+", render_posi, Color_new(color.r, color.g, color.b, v.Alpha), 20, g_Fonts.Verdana , false , true) looks ass xD 

            Render_BoxFilled(new_vec2(render_posi.x - 1, render_posi.y - 5), new_vec2(render_posi.x + 1, render_posi.y + 5), Color_new(color.r, color.g, color.b, v.alpha))

            Render_BoxFilled(new_vec2( render_posi.x - 5 , render_posi.y - 1), new_vec2( render_posi.x + 5, render_posi.y + 1) , Color_new(color.r, color.g, color.b, v.alpha))

            if v.alpha <= 0.15 then 
                table_remove(hitmarkerqueue, 1) -- dont want to always have 5 in table cuz dumb
            end        

        end

    end
end

g_events.handle_hit_event_dmg = function(shot)
    if shot.damage <= 0 or not g_world.hitmarker:GetBool() or not g_world.marker_mode:Get(2) then return end

    local enemy_pos = EntityList.GetPlayer(shot.target_index):GetProp("DT_BaseEntity", "m_vecOrigin")
    local enemy_death = is_alive(EntityList.GetPlayer(shot.target_index))

    table_insert(hits,
    {
        position = { x = enemy_pos.x, y = enemy_pos.y, z = enemy_pos.z + (enemy_death and 100 or 50) },
        orig   = { x = enemy_pos.x + 10, y = enemy_pos.y, z = enemy_pos.z + (enemy_death and 100 or 50) + 20 },
        dmg   = shot.damage,
        alpha    = 255
    })
end

g_events.handle_hit_event_cross = function(e)
    if e:GetName() ~= "bullet_impact" then return end

    if EntityList.GetPlayerForUserID(e:GetInt("userid")) ~= g_cl.m_local then return end

    table_insert(hitmarkerqueue,
    {
        position = new_vec(e:GetFloat("x") ,  e:GetFloat("y") , e:GetFloat("z") ) ,
        alpha    = 255
    })
end

--#endregion

--#region Snaplines

g_world.handle_snaplines = function()
    if not g_world.snaplines:GetBool() then return end
    local players = EntityList.GetPlayers()
    if  g_world.snapline_player:GetInt() == 0 then 
        for k, v in ipairs(players) do
            if (v:IsTeamMate() and g_world.snapline_mode:Get(1)) or (v:IsDormant() and g_world.snapline_mode:Get(2)) or v == g_cl.m_local or not is_alive(v) then
                goto skip
            end
            local position = Render_ToScreen(v:GetProp("m_vecOrigin")) 
            local start = g_world.snapline_start:GetInt() == 0 and new_vec2(g_cl.screen.x / 2, g_cl.screen.y) or Render_ToScreen(g_cl.m_local:GetProp("m_vecOrigin"))
            Render_line(position, start, g_world.snaplines:GetColor())
            ::skip::
        end
    else 
        local position = Render_ToScreen(closest_player():GetProp("m_vecOrigin")) 
        local start = g_world.snapline_start:GetInt() == 0 and new_vec2(g_cl.screen.x / 2, g_cl.screen.y) or Render_ToScreen(g_cl.m_local:GetProp("m_vecOrigin"))
        Render_line(position, start, g_world.snaplines:GetColor())
    end
end
--#endregion

--#region healthbar

local players = {
    m_health = {} ,
    m_cur_health = {}
}

for i = 1 , 64 do 
    players.m_health[i] = 100
    players.m_cur_health[i] = 100
end

g_visuals.healthbar = function()
    local playerss = EntityList.GetPlayers()
    local local_player = EntityList.GetLocalPlayer()
    for _, player_ptr in ipairs(playerss) do

        if players.m_cur_health[player_ptr:EntIndex()] == nil then
            players.m_cur_health[player_ptr:EntIndex()] = 100
        end

        if player_ptr == local_player:EntIndex() or player_ptr:IsTeamMate() or player_ptr:IsDormant() then goto skip end

        players.m_cur_health[player_ptr:EntIndex()] = player_ptr:GetProp("m_iHealth")

        if players.m_health[player_ptr:EntIndex()] == nil then
            players.m_health[player_ptr:EntIndex()] = players.m_cur_health[player_ptr:EntIndex()]
        end
            
        if players.m_health[player_ptr:EntIndex()] ~= players.m_cur_health[player_ptr:EntIndex()] then
            players.m_health[player_ptr:EntIndex()] = lerp(players.m_health[player_ptr:EntIndex()], players.m_cur_health[player_ptr:EntIndex()], GlobalVars.frametime * g_visuals.health_speed:GetInt())
        end

        ::skip::
    end
end

ESP.CustomBar("Animated healthbar", "enemies", function(ent)
    if not g_visuals.indic_options:Get(1) then return end
    return clamp(round(players.m_health[ent:EntIndex()]), 0, 100)
end)

--#endregion

--#region Trashtalk phrases

local tt_baim        = 
{
"WEAK CHICKEN COOP CLEANER (YOU) SENT BACK TO SPAIN","I AM THE BOSS SENPAI","AMONGUS SPECIALIST(ME) SENT HERE TO SLAY DOG(YOU)",
"YOU SENDED BACK TO DE_CHINA BY ZUKRASS ALPHA $","DOG YOU SENT TO CHINA BY ZUKRASS","AMONGUS MASTERMIND SENT HERE TO SLAY DOG(YOU)","BARKED FOR THE LAST TIME",
"DOG COOKED LIKE CHINA","HAHA SITTING DOWN DOG,YOU THINK YOU CAN KILL ME? HAHA NO DOG I KILL YOU","YOUR THINK YOU BOSS LIKE ME BUT YOU DOG HAHA","LOW DOG (YOU) GOT OWNED BY DE_BOSS (ME)"
}

local tt_hs          = 
{
"CLUBBED LIKE A SEAL","IMAGINE NO SKEET (YOU) DOG MAD DOG BARK","1 DOG BARK DOG","DEAD NN NICE AMOGUS LEVEL","1 SLAYED LIKE IMPOSTER","DOG SENT OUT OF SPACESHIP","NN FUCKED HARDER THAN COLLEGE WHORE",
"I HOPE U HAVE SCAT FETISH CUS U GOT SHIT ON NN","CY@MEXICO","YOUR THINK YOU ANTIAIM BETTER ME HAHA NO DOG I HEADSHOOT YOU","PROFESSIONAL SEAL CLUBBER(ME) CAME HERE TO CLUB LOW SEAL(YOU)",
"HAHA YOU WANT BE LIKE ANTIAIM SPECIALIST(ME) BUT I HEADSHOOT YOU HAHA","MAYBE DONT DO BAD ANTIAIM AND IT WILL BE GOOD","HAHA YOU COSPLAY GOERGE FLOYD? (BECOS YOU DEAD HAHA)",
"WEAK SLAVE STRANGLED INTO SUBMISSION BY HVHBOSS","WEAK DISCORDKITTEN (WHOMST) OB_LITERATED BY LEGENDE"
}

--#endregion

--#region clantag

local _last_clantag = nil
local tag_table     = 
{
"","b","bo","bor","bord","borde","bordea","bordeau","bordeaux","bordeau[","bordea[r","borde[rb","bord[rbx","bord[rbx]","bor[rbx]","bo[rbx]","b[rbx]","[rbx]","rbx]","bx]","x]","]",""
}

local _set_clantag  = ffi.cast("int(__fastcall*)(const char*, const char*)", Utils.PatternScan("engine.dll", "53 56 57 8B DA 8B F9 FF 15"))
local set_clantag   = function(v) if v == _last_clantag then return end _set_clantag(v, v) _last_clantag = v end

g_misc.clantag_animation = function()
    if not connected() then
        return
    end

    local netchann_info = EngineClient.GetNetChannelInfo()
    if netchann_info == nil then
        return
    end

    if g_misc.clantag_on:GetBool() then
        local latency = netchann_info:GetLatency(0) / GlobalVars.interval_per_tick
        local tickcount_pred = GlobalVars.tickcount + latency
        local iter = math_floor(math_fmod(tickcount_pred / 35, #tag_table + 1) + 1)
        set_clantag(tag_table[iter + 1] ~= nil and tag_table[iter + 1] or "")
    else
        set_clantag("")
    end
end

--#endregion

--#region custom hitsound 

g_misc.hitsound = function(e)
    if e:GetName() ~= "player_hurt" or not g_misc.custom_hitsound:GetBool() then return end
  
    local attacker = EntityList.GetPlayerForUserID(e:GetInt("attacker", 0))
 
    if g_cl.m_local == target or g_cl.m_local ~= attacker then return end
 
    local sound = string.format("playvol %s %d" , g_misc.hitsound_path:GetString() , 1)
 
    EngineClient.ExecuteClientCmd(sound)

end

--#endregion

--#region hooks 

function hook_round_start(e)

    if e:GetName() ~= "round_start" then return end
    for i = 1 , 64 do 
        players.m_health[i] = 100
        players.m_cur_health[i] = 100
    end

    g_bruteforce.stage = 0

    add_notification("reinitialized bruteforce due to round_start" , 1 , g_bruteforce.bf_color:GetColor() , white)

end

function hook_round_end(e)
    if e:GetName() ~= "round_end" then return end

end

function hook_death(e)
    if e:GetName() ~= "player_death" or not EntityList.GetPlayerForUserID(e:GetInt("userid")) then return end
    
end

function hook_kill(e)
    if e:GetName() ~= "player_death" then return end

    local victim = EntityList.GetPlayerForUserID(e:GetInt("userid"))
    local attacker = EntityList.GetPlayerForUserID(e:GetInt("attacker"))
    local hs = e:GetBool("headshot")
    if victim == attacker or attacker ~= g_cl.m_local or victim:IsTeamMate() then return end

    if g_bruteforce.options:Get(3) then 
        add_notification("reinitialized bruteforce due to target death" , 1 , g_bruteforce.bf_color:GetColor() , white)
        g_bruteforce.stage = 0
    end
    
    if not g_misc.trashtalk:GetBool() then goto skip end

    if g_misc.trashtalk_mode:GetInt() == 0 then
        local table = math_random(0, 1) == 1 and tt_baim or tt_hs
        local phrase = tostring(table[math_random(1, #table)])
        EngineClient.ExecuteClientCmd(string_format("say %s", phrase))
    else
        local phrase = hs and tostring(tt_hs[math_random(1, #tt_hs)]) or tostring(tt_baim[math_random(1, #tt_baim)])
        EngineClient.ExecuteClientCmd(string_format("say %s", phrase))
    end

    ::skip::

end

--#endregion

--#region cryption

local watermark = "bordeaux["..build.."]_"
local charset ='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- charset for enc / dec

function remove_watermark(string)
    local watermark_len = string.len(watermark) + 1
    local string_len = string.len(string)
    return string.sub(string, watermark_len, string_len)
end

--// encoding
function encode(string)
    return ((string:gsub('.', function(x) 
        local r,charset='',x:byte()
        for i=8,1,-1 do r=r..(charset%2^i-charset%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return charset:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#string%3+1])
end
--// decoding
function decode(string)
    string = string.gsub(string, '[^'..charset..'=]', '')
    return (string:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(charset:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end
--#endregion

--#region cfg initilization


function clipboard_to_cfg()
    local clipboard_text_length = get_clipboard_text_length(VGUI_System)

    if (clipboard_text_length > 0) then
        local buffer = ffi.new("char[?]", clipboard_text_length)

        get_clipboard_text(VGUI_System, 0, buffer, clipboard_text_length * ffi.sizeof("char[?]", clipboard_text_length))
        return ffi.string(buffer, clipboard_text_length - 1)
    end

end

function cfg_to_clipboard(text)
    set_clipboard_text(VGUI_System, text, #text)
end

--// i do not like that i have to get the time and date like this but with ffi its even more gay imo so we use panorama 

local json = Panorama.LoadString([[                  
    return {
        stringify: JSON.stringify,
        parse: JSON.parse , 
        get_time: () => {
            var today     = new Date(); 

            var hour    = today.getHours();
            var min     = today.getMinutes();

            if(hour < 10) 
            {
                hour = '0'+ hour;
            }

            if(min < 10) 
            {
                min = '0' + min;
            }

            return  hour + ':' + min   
        },
        get_date: () => {
            var today     = new Date(); 

            today.getFullYear()+'-'+(today.getMonth()+1)+'-'+today.getDate();

            var year  = today.getFullYear()
            var month = today.getMonth()+1
            var day   = today.getDate()

            if(month < 10) 
            {
                month = '0'+ month;
            }

            if(day < 10) 
            {
                day = '0' + day;
            }

            return  day + '-' + month + "-" + year 
        }
    };
]])()

--#endregion   

--#region lua elements

local cfg_metadata = 
{

    ["color"]     = 
    {
        --// color picker
        g_visuals.active_side     ,
        g_visuals.inactive_side   ,
        g_visuals.valid_color     ,
        g_visuals.invalid_color   ,
        g_visuals.dmg_color       ,
        g_visuals.gradient1       ,
        g_visuals.gradient2       ,
        g_visuals.watermark_color ,
        g_visuals.watermark_text  ,
        g_visuals.log_color       ,
        g_visuals.bind_color      ,
        g_visuals.warning_color   , 
        --// World

        g_world.custom_scope      ,
        g_world.hitmarker         ,
        g_world.snaplines         ,
        g_bruteforce.bf_color     , 
    } ,


    ["non_color"] = 
    { 
        --// Rage
        g_rage.enable_da          ,
        g_rage.da_options         ,
        g_rage.da_dmg             ,
        g_rage.da_hc              ,
        g_rage.da_intensity       ,
        g_rage.da_hitscan         ,

        --// Anti aim

        g_antiaim.main            ,
        g_antiaim.additions       ,
        g_antiaim.con_selector    ,
        g_antiaim.fl_exploit      ,
        g_antiaim.tele_weapon     ,
        g_antiaim.tele_mode       ,

        --// Visuals 
        g_visuals.main            ,

        --// Indicator
        g_visuals.indic_options   ,
        g_visuals.indic_mode      ,
        g_visuals.arrow_mode      , 
        g_visuals.dmg_height      ,
        g_visuals.dmg_width       ,
        g_visuals.health_speed    ,
        g_visuals.warning_time    ,

        --ui option selector

        g_visuals.ui_options      ,

        --// Keybinds

        g_visuals.keybind_mode    ,
        g_visuals.binds_bg        ,
        g_visuals.binds_x         ,
        g_visuals.binds_y         ,

        --// Watermark
        g_visuals.watermark_mode  ,
        g_visuals.watermark_loc   ,
        g_visuals.watermark_bg    ,
        g_visuals.enable_glow     ,
        g_visuals.glow_intensity  ,

        --// Logs
        g_visuals.log_mode        ,
        g_visuals.log_options     ,

        --// World

        g_world.custom_scope      ,
        g_world.scope_viewmodel   ,
        g_world.scope_mode        ,
        g_world.scope_offset      ,
        g_world.scope_length      ,
        g_world.scope_width       ,
        g_world.scope_scale       ,

        g_world.hitmarker         ,
        g_world.marker_mode       ,
        g_world.damage_fade       ,
        g_world.fade_mode         ,


        g_world.snaplines         ,
        g_world.snapline_mode     ,
        g_world.snapline_start    ,
        g_world.snapline_player   ,

        --// Misc

        g_misc.clantag_on         ,
        g_misc.trashtalk          ,
        g_misc.trashtalk_mode     ,

    } ,

    ["non_color2"] = 
    {   
       -- bruteforce
       phase_amount               , 
       g_bruteforce.main          , 
       g_bruteforce.options       ,
       g_bruteforce.origin        , 
       g_bruteforce.duration      , 
       g_bruteforce.range         , 
       g_antiaim.roll_cond        , 
       
       --// Fakelag

       g_fakelag.main             , 
       g_fakelag.mode             ,
       g_fakelag.choke            ,
       g_fakelag.variance         ,
       g_fakelag.step1            ,
       g_fakelag.step2            ,
       g_fakelag.step3            ,

        --// Rage additions
       g_rage.additions           ,
       g_rage.air_hc              ,
       g_rage.noscope_hc          ,
       g_rage.change_shift        ,  
    } ,

    ["info"] = 
    {
        user            ,
        build           , 
        json:get_date() , 
        json:get_time()
    }

   
}

for k , v in ipairs(conditions) do 
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Override"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Left desync"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Right desync"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Yaw mode"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Yaw add"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Left add"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Right add"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Yaw mod"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Mod mode"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Mod degree"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Degree 1"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Degree 2"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Degree 3"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Degree 4"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Fake options"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Lby mode"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Desync mode"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Desync 1"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Desync 2"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Desync 3"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Desync 4"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["Freestanding"])
    table_insert(cfg_metadata["non_color"], g_custom_aa[v]["On shot"])

end

for k , v in ipairs(g_bruteforce.stage_creation) do 
    table_insert(cfg_metadata["non_color2"] , v )
end

--#endregion

--#region exporting

local export_cfg = Menu_Button("bordeaux | Config ", "bordeaux | Config ", "Export Config", "" , function()

    local cfg ={ ["color"] = {} , ["non_color"] = {} , ["non_color2"] = {} , ["info"] = {} }

    for k , v in ipairs(cfg_metadata["non_color"]) do 
        table_insert(cfg["non_color"], v:Get())
    end

    for k , v in ipairs(cfg_metadata["non_color2"]) do 
        table_insert(cfg["non_color2"], v:Get())
    end

    for k , v in pairs(cfg_metadata["color"]) do
        local clr = v:GetColor()
        table_insert(cfg["color"], clr_to_string(clr))
    end

    for k , v in pairs(cfg_metadata["info"]) do
        table_insert(cfg["info"], v)
    end

    cfg_to_clipboard(watermark..encode(json.stringify(cfg)))

    add_notification("Succesfully exported config to clipboard" , 1 , Color_new(0 , 255 , 0 , 255) , white)

    button_sound()

end)

--#endregion

--#region importing

local function import(cfg_string)

    button_sound()

    if string.sub(cfg_string, 0 , string.len("bordeaux")) ~= "bordeaux" then 
        add_notification("Error importing cfg, err [invalid data]" , 1 , Color_new(255 , 0 , 0 , 255) , white)
        return false
    end

    local str = remove_watermark(cfg_string)

    if type(json.parse(decode(str))) ~= type(cfg_metadata) then 
        EngineClient.ExecuteClientCmd("clear")
        add_notification("Error importing cfg, err [parse type]" , 1 , Color_new(255 , 0 , 0 , 255) , white)
        return false
    end

    local data = {}

    for k, v in pairs(json.parse(decode(str))) do

        if k == nil or v == nil then 
            add_notification("Error importing cfg, err[ipair_parse]" , 1 , Color_new(255 , 0 , 0 , 255) , white)
            return false
        end

        for k2, v2 in pairs(v) do

            if k2 == nil or v2 == nil then 
                add_notification("Error importing cfg, err[ipair_v]" , 1 , Color_new(255 , 0 , 0 , 255) , white)
                return false
            end 

            if k == "non_color" or k == "non_color2" then
                if cfg_metadata[k][k2] == nil or type(cfg_metadata[k][k2]:Get()) ~= type(v2) then 
                    add_notification("Error importing cfg, err[!_clr] at count" .. k2 , 1 , Color_new(255 , 0 , 0 , 255) , white)
                    return false
                end
                cfg_metadata[k][k2]:Set(v2)
            end

            if k == "color" then
                if cfg_metadata[k][k2] == nil or type(v2) ~= "string" or type(cfg_metadata[k][k2]:GetColor()) ~= type(str_to_clr(v2)) then 
                    add_notification("Error importing cfg, err[clr] at count" .. k2 , 1 , Color_new(255 , 0 , 0 , 255) , white)
                    return false
                end
                cfg_metadata[k][k2]:SetColor(str_to_clr(v2))
            end

            if k == "info" then 
                if v2 == nil then 
                    add_notification("Error importing cfg, err[clr] at count" .. k2 , 1 , Color_new(255 , 0 , 0 , 255) , white)
                    return false
                end
                table_insert(data , v2)
            end
        end

    end

    for k , v in ipairs(data) do 
        v = v ~= nil and v or "invalid"
    end

    local cfg_str = string_format("Succesfully imported config created by %s[%s] created on %s at %sh" , data[1] , data[2] , data[3] , data[4])

    add_notification(cfg_str , 1 , Color_new(0 , 255 , 0 , 255) , white)

end

local import_cfg = Menu_Button("bordeaux | Config ", "bordeaux | Config ", "Import Config" , "" , function()

    import(clipboard_to_cfg())

    ::skip::

end)

local import_cfg = Menu_Button("bordeaux | Config ", "bordeaux | Config ", "Import default config" , "" , function()

    local cfg_answer = http_message("https://pastebin.com/raw/afu9R6jK")

    if cfg_answer[2] == false then
        add_notification("error receiving default config" , 1 , Color_new(255 , 0 , 0 , 255) , white)
        button_sound()
        goto skip 
    end

    import(cfg_answer[1])

    ::skip::

end)

local cfg_esrie  = "bordeaux[lby]_eyJub25fY29sb3IiOnsiMSI6ZmFsc2UsIjIiOjExLCIzIjo1LCI0Ijo4MCwiNSI6MiwiNiI6MSwiNyI6dHJ1ZSwiOCI6MTE4LCI5Ijo1LCIxMCI6MCwiMTEiOjAsIjEyIjowLCIxMyI6dHJ1ZSwiMTQiOjQ3LCIxNSI6MywiMTYiOjIsIjE3IjowLCIxOCI6MSwiMTkiOjUsIjIwIjozMCwiMjEiOjMsIjIyIjowLCIyMyI6MSwiMjQiOjMzMywiMjUiOjQ3NSwiMjYiOjEsIjI3IjowLCIyOCI6MCwiMjkiOjAsIjMwIjoxLCIzMSI6MywiMzIiOjcsIjMzIjpmYWxzZSwiMzQiOnRydWUsIjM1IjowLCIzNiI6MTAsIjM3Ijo2MCwiMzgiOjEsIjM5IjoxMDAsIjQwIjp0cnVlLCI0MSI6MywiNDIiOjEsIjQzIjoxLCI0NCI6ZmFsc2UsIjQ1IjowLCI0NiI6MCwiNDciOmZhbHNlLCI0OCI6ZmFsc2UsIjQ5IjowLCI1MCI6ZmFsc2UsIjUxIjowLCI1MiI6MCwiNTMiOjAsIjU0IjoxMSwiNTUiOjAsIjU2IjowLCI1NyI6MSwiNTgiOjAsIjU5IjozMywiNjAiOjAsIjYxIjowLCI2MiI6MCwiNjMiOjAsIjY0IjoyLCI2NSI6MCwiNjYiOjIsIjY3IjoxOCwiNjgiOjQ4LCI2OSI6MCwiNzAiOjAsIjcxIjowLCI3MiI6MCwiNzMiOnRydWUsIjc0IjowLCI3NSI6MCwiNzYiOjAsIjc3IjowLCI3OCI6LTIyLCI3OSI6MjgsIjgwIjoxLCI4MSI6MCwiODIiOjMzLCI4MyI6MCwiODQiOjAsIjg1IjowLCI4NiI6MCwiODciOjIsIjg4IjoxLCI4OSI6MywiOTAiOjAsIjkxIjowLCI5MiI6MCwiOTMiOjAsIjk0IjowLCI5NSI6MywiOTYiOmZhbHNlLCI5NyI6MCwiOTgiOjAsIjk5IjowLCIxMDAiOjAsIjEwMSI6MCwiMTAyIjowLCIxMDMiOjAsIjEwNCI6MCwiMTA1IjowLCIxMDYiOjAsIjEwNyI6MCwiMTA4IjowLCIxMDkiOjAsIjExMCI6MCwiMTExIjowLCIxMTIiOjAsIjExMyI6MCwiMTE0IjowLCIxMTUiOjAsIjExNiI6MCwiMTE3IjowLCIxMTgiOjAsIjExOSI6dHJ1ZSwiMTIwIjo2MCwiMTIxIjo2MCwiMTIyIjoxLCIxMjMiOjExLCIxMjQiOi02LCIxMjUiOjE1LCIxMjYiOjEsIjEyNyI6MSwiMTI4Ijo1NSwiMTI5IjowLCIxMzAiOjAsIjEzMSI6NDUsIjEzMiI6NjUsIjEzMyI6MiwiMTM0IjowLCIxMzUiOjEsIjEzNiI6NDMsIjEzNyI6NjAsIjEzOCI6MjUsIjEzOSI6NjAsIjE0MCI6MCwiMTQxIjozLCIxNDIiOmZhbHNlLCIxNDMiOjAsIjE0NCI6MCwiMTQ1IjowLCIxNDYiOjAsIjE0NyI6MCwiMTQ4IjowLCIxNDkiOjAsIjE1MCI6MCwiMTUxIjowLCIxNTIiOjAsIjE1MyI6MCwiMTU0IjowLCIxNTUiOjAsIjE1NiI6MCwiMTU3IjowLCIxNTgiOjAsIjE1OSI6MCwiMTYwIjowLCIxNjEiOjAsIjE2MiI6MCwiMTYzIjowLCIxNjQiOjAsIjE2NSI6dHJ1ZSwiMTY2Ijo0OCwiMTY3Ijo2MCwiMTY4IjoxLCIxNjkiOjExLCIxNzAiOjgsIjE3MSI6MTgsIjE3MiI6MSwiMTczIjoxLCIxNzQiOjU1LCIxNzUiOjAsIjE3NiI6MCwiMTc3Ijo0NSwiMTc4Ijo1NSwiMTc5IjoyLCIxODAiOjAsIjE4MSI6MywiMTgyIjowLCIxODMiOjAsIjE4NCI6MCwiMTg1IjowLCIxODYiOjAsIjE4NyI6MCwiMTg4IjpmYWxzZSwiMTg5IjowLCIxOTAiOjAsIjE5MSI6MCwiMTkyIjowLCIxOTMiOjAsIjE5NCI6MCwiMTk1IjowLCIxOTYiOjAsIjE5NyI6MCwiMTk4IjowLCIxOTkiOjAsIjIwMCI6MCwiMjAxIjowLCIyMDIiOjAsIjIwMyI6MCwiMjA0IjowLCIyMDUiOjAsIjIwNiI6MCwiMjA3IjowLCIyMDgiOjAsIjIwOSI6MCwiMjEwIjowfSwibm9uX2NvbG9yMiI6eyIxIjoyLCIyIjp0cnVlLCIzIjowLCI0IjowLCI1IjozLCI2Ijo2NSwiNyI6MTI2LCI4Ijp0cnVlLCI5IjowLCIxMCI6MTMsIjExIjowLCIxMiI6OCwiMTMiOjEyLCIxNCI6MTMsIjE1Ijo0OCwiMTYiOi0zMCwiMTciOjAsIjE4IjowLCIxOSI6MCwiMjAiOjAsIjIxIjowLCIyMiI6MCwiMjMiOjAsIjI0IjowfSwiaW5mbyI6eyIxIjoiWGFucXJ1bCIsIjIiOiJsYnkiLCIzIjoiMDgtMDgtMjAyMiIsIjQiOiIwMTo1OSJ9LCJjb2xvciI6eyIxIjoiOTA5NkQ1RkYiLCIyIjoiRkZGRkZGRkYiLCIzIjoiRkZGRkZGRkYiLCI0IjoiRkZGRkZGRkYiLCI1IjoiOTA5NkQ1RkYiLCI2IjoiRkZGRkZGRkYiLCI3IjoiRkZGRkZGRkYiLCI4IjoiRkZGRkZGRkYiLCI5IjoiOTA5NkQ1RkYiLCIxMCI6IjkwOTZENUZGIiwiMTEiOiI5MDk2RDVGRiIsIjEyIjoiRkZGRkZGRkYiLCIxMyI6IkZGRkZGRkZGIiwiMTQiOiI5MDk2RDVGRiIsIjE1IjoiRkUwMUZFMDEiLCIxNiI6IjkwOTZENUZGIn19"
local cfg_freaut = "bordeaux[lby]_eyJub25fY29sb3IiOnsiMSI6ZmFsc2UsIjIiOjExLCIzIjo1LCI0Ijo3OSwiNSI6MiwiNiI6MSwiNyI6dHJ1ZSwiOCI6MCwiOSI6MywiMTAiOjAsIjExIjowLCIxMiI6MCwiMTMiOnRydWUsIjE0IjozMCwiMTUiOjEsIjE2IjowLCIxNyI6MCwiMTgiOjEsIjE5IjoxMiwiMjAiOjIwLCIyMSI6MSwiMjIiOjEsIjIzIjowLCIyNCI6NzA0LCIyNSI6NDgxLCIyNiI6MCwiMjciOjAsIjI4IjowLCIyOSI6MSwiMzAiOjQuMDk5OTk5OTA0NjMyNTY4LCIzMSI6MywiMzIiOjcsIjMzIjpmYWxzZSwiMzQiOmZhbHNlLCIzNSI6MCwiMzYiOjEwLCIzNyI6MTUwLCIzOCI6MC41LCIzOSI6MTAwLCI0MCI6dHJ1ZSwiNDEiOjIsIjQyIjowLCI0MyI6MCwiNDQiOmZhbHNlLCI0NSI6MCwiNDYiOjAsIjQ3IjpmYWxzZSwiNDgiOmZhbHNlLCI0OSI6MCwiNTAiOmZhbHNlLCI1MSI6NjAsIjUyIjo2MCwiNTMiOjAsIjU0IjowLCI1NSI6MTEsIjU2IjoxNiwiNTciOjEsIjU4IjowLCI1OSI6NDgsIjYwIjoxNSwiNjEiOjM1LCI2MiI6MCwiNjMiOjAsIjY0IjoyLCI2NSI6MCwiNjYiOjAsIjY3Ijo2MCwiNjgiOjYwLCI2OSI6MCwiNzAiOjAsIjcxIjowLCI3MiI6MCwiNzMiOmZhbHNlLCI3NCI6NjAsIjc1Ijo2MCwiNzYiOjAsIjc3IjowLCI3OCI6NywiNzkiOjE0NCwiODAiOjMsIjgxIjoyLCI4MiI6LTE2LCI4MyI6LTgwLCI4NCI6MTA3LCI4NSI6MCwiODYiOjAsIjg3IjoyLCI4OCI6MSwiODkiOjAsIjkwIjoyNCwiOTEiOjE1LCI5MiI6MCwiOTMiOjAsIjk0IjoxLCI5NSI6MSwiOTYiOmZhbHNlLCI5NyI6MTksIjk4IjowLCI5OSI6MCwiMTAwIjowLCIxMDEiOjAsIjEwMiI6MCwiMTAzIjowLCIxMDQiOjAsIjEwNSI6MCwiMTA2IjowLCIxMDciOjAsIjEwOCI6MCwiMTA5IjowLCIxMTAiOjAsIjExMSI6MCwiMTEyIjowLCIxMTMiOjAsIjExNCI6MCwiMTE1IjowLCIxMTYiOjAsIjExNyI6MCwiMTE4IjowLCIxMTkiOnRydWUsIjEyMCI6NjAsIjEyMSI6NjAsIjEyMiI6MCwiMTIzIjowLCIxMjQiOi04LCIxMjUiOjE1LCIxMjYiOjEsIjEyNyI6MSwiMTI4Ijo1MiwiMTI5Ijo0NSwiMTMwIjo3NCwiMTMxIjowLCIxMzIiOjAsIjEzMyI6MiwiMTM0IjoxLCIxMzUiOjEsIjEzNiI6MzksIjEzNyI6NTgsIjEzOCI6MCwiMTM5IjowLCIxNDAiOjAsIjE0MSI6MCwiMTQyIjp0cnVlLCIxNDMiOjQ4LCIxNDQiOjQ4LCIxNDUiOjAsIjE0NiI6MCwiMTQ3Ijo4LCIxNDgiOjE0LCIxNDkiOjEsIjE1MCI6MCwiMTUxIjo1NiwiMTUyIjowLCIxNTMiOjAsIjE1NCI6MCwiMTU1IjowLCIxNTYiOjIsIjE1NyI6MCwiMTU4IjowLCIxNTkiOjAsIjE2MCI6MCwiMTYxIjowLCIxNjIiOjAsIjE2MyI6MCwiMTY0IjoxLCIxNjUiOnRydWUsIjE2NiI6NDgsIjE2NyI6NDgsIjE2OCI6MCwiMTY5IjowLCIxNzAiOjIsIjE3MSI6MTcsIjE3MiI6MSwiMTczIjowLCIxNzQiOjU3LCIxNzUiOjMwLCIxNzYiOjQ1LCIxNzciOjAsIjE3OCI6MCwiMTc5IjoyLCIxODAiOjEsIjE4MSI6MCwiMTgyIjo2MCwiMTgzIjo1OCwiMTg0IjowLCIxODUiOjAsIjE4NiI6MCwiMTg3IjozLCIxODgiOmZhbHNlLCIxODkiOjAsIjE5MCI6NjAsIjE5MSI6MCwiMTkyIjowLCIxOTMiOi0xODAsIjE5NCI6MTgwLCIxOTUiOjQsIjE5NiI6MCwiMTk3IjoxODAsIjE5OCI6MCwiMTk5IjowLCIyMDAiOjAsIjIwMSI6MCwiMjAyIjozLCIyMDMiOjEsIjIwNCI6MCwiMjA1IjowLCIyMDYiOjAsIjIwNyI6MCwiMjA4IjowLCIyMDkiOjAsIjIxMCI6MH0sIm5vbl9jb2xvcjIiOnsiMSI6MiwiMiI6ZmFsc2UsIjMiOjAsIjQiOjAsIjUiOjMsIjYiOjY1LCI3IjowLCI4IjowLCI5IjowLCIxMCI6MCwiMTEiOjAsIjEyIjowLCIxMyI6MCwiMTQiOjAsIjE1IjowLCIxNiI6MH0sImluZm8iOnsiMSI6IkZyZWF1dCIsIjIiOiJsYnkiLCIzIjoiMDQtMDgtMjAyMiIsIjQiOiIyMToyNCJ9LCJjb2xvciI6eyIxIjoiREU5QjlCRkYiLCIyIjoiRkZGRUZGRkYiLCIzIjoiQzE2NzY3RkYiLCI0IjoiRkZGRUZFRkYiLCI1IjoiRkVGRUZGRkYiLCI2IjoiRkUwMUZFMDEiLCI3IjoiRkUwMUZFMDEiLCI4IjoiREU5QjlCRkYiLCI5IjoiRkZGRUZFMDEiLCIxMCI6IkZGRkVGRjAxIiwiMTEiOiJGRUZFRkZGRiIsIjEyIjoiRkUwMUZFMDFGRTAxRkUwMSIsIjEzIjoiRTc5QUVGRkYiLCIxNCI6IkRFOUI5QkZGIiwiMTUiOiJGRTAxRkUwMSIsIjE2IjoiRkUwMUZFMDFGRTAxRkUwMSJ9fQ=="

local user = ""

local function console_reg(text)

    if text == "load esrie" then 
        import(cfg_esrie)
    elseif text == "load freaut" then
        import(cfg_freaut)
    elseif 
    text == "load user" then
        import(user)
    end
    
end

--#endregion

--#region menu visibility

g_menu.visibility = function()

    if not Cheat.IsMenuVisible() then return end
    local aa_main   = g_antiaim.main:GetBool()
    local vis_main  = g_visuals.main:GetBool()
    local bf_main   = g_bruteforce.main:GetBool()
    local da_main   = g_rage.enable_da:GetBool()
    local fl_main   = g_fakelag.main:GetBool() 

    -- dormant aimbot 
    g_rage.da_options:SetVisible(da_main)
    g_rage.da_dmg:SetVisible(da_main)
    g_rage.da_intensity:SetVisible(da_main)
    g_rage.da_hitscan:SetVisible(da_main)
    g_rage.da_hc:SetVisible(da_main)

    --// Rage additions

    g_rage.air_hc:SetVisible(g_rage.additions:Get(1))
    g_rage.noscope_hc:SetVisible(g_rage.additions:Get(2))
    g_rage.change_shift:SetVisible(g_rage.additions:Get(4))

    -- Custom aa

    g_antiaim.con_selector:SetVisible(aa_main )


    for i=1, #conditions do
        local should_show = conditions[g_antiaim.con_selector:GetInt() + 1] == conditions[i] and g_custom_aa[conditions[i]]["Override"]:GetBool() and aa_main 
        if i == 1 then 
            should_show = conditions[g_antiaim.con_selector:GetInt() + 1] == conditions[i] and aa_main 
        end 
        g_custom_aa[conditions[i]]["Override"]:SetVisible(conditions[g_antiaim.con_selector:GetInt()+1] == conditions[i] and g_antiaim.con_selector:GetInt() ~= 0 and aa_main)

        g_custom_aa[conditions[i]]["Yaw mode"]:SetVisible(should_show)


        g_custom_aa[conditions[i]]["Left desync"]:SetVisible(should_show and  g_custom_aa[conditions[i]]["Desync mode"]:GetInt() == 0)
        g_custom_aa[conditions[i]]["Right desync"]:SetVisible(should_show and  g_custom_aa[conditions[i]]["Desync mode"]:GetInt() == 0)
        g_custom_aa[conditions[i]]["Yaw add"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Yaw mode"]:GetInt() == 0)
        g_custom_aa[conditions[i]]["Left add"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Yaw mode"]:GetInt() == 1)
        g_custom_aa[conditions[i]]["Right add"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Yaw mode"]:GetInt() == 1)
        g_custom_aa[conditions[i]]["Yaw mod"]:SetVisible(should_show)
        g_custom_aa[conditions[i]]["Mod mode"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Yaw mod"]:GetInt() ~= 0 )
        g_custom_aa[conditions[i]]["Mod degree"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Mod mode"]:GetInt() == 0 and g_custom_aa[conditions[i]]["Yaw mod"]:GetInt() ~= 0)
        g_custom_aa[conditions[i]]["Degree 1"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Mod mode"]:GetInt() == 2 and g_custom_aa[conditions[i]]["Yaw mod"]:GetInt() > 0)
        g_custom_aa[conditions[i]]["Degree 2"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Mod mode"]:GetInt() == 2 and g_custom_aa[conditions[i]]["Yaw mod"]:GetInt() > 0) 
        g_custom_aa[conditions[i]]["Degree 3"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Mod mode"]:GetInt() == 1 and g_custom_aa[conditions[i]]["Yaw mod"]:GetInt() > 0)
        g_custom_aa[conditions[i]]["Degree 4"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Mod mode"]:GetInt() == 1 and g_custom_aa[conditions[i]]["Yaw mod"]:GetInt() > 0) 
        g_custom_aa[conditions[i]]["Fake options"]:SetVisible(should_show)
        g_custom_aa[conditions[i]]["Lby mode"]:SetVisible(should_show)
        g_custom_aa[conditions[i]]["Desync mode"]:SetVisible(should_show)
        g_custom_aa[conditions[i]]["Desync 1"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Desync mode"]:GetInt() == 2 )
        g_custom_aa[conditions[i]]["Desync 2"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Desync mode"]:GetInt() == 2 )
        g_custom_aa[conditions[i]]["Desync 3"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Desync mode"]:GetInt() == 1 )
        g_custom_aa[conditions[i]]["Desync 4"]:SetVisible(should_show and g_custom_aa[conditions[i]]["Desync mode"]:GetInt() == 1 )
        g_custom_aa[conditions[i]]["Freestanding"]:SetVisible(should_show)
        g_custom_aa[conditions[i]]["On shot"]:SetVisible(should_show)
        
    end

    --// Additions 
    g_antiaim.additions:SetVisible(aa_main)
    g_antiaim.fl_exploit:SetVisible(aa_main and g_antiaim.additions:Get(2))
    g_antiaim.tele_mode:SetVisible(aa_main and g_antiaim.additions:Get(4))
    g_antiaim.tele_weapon:SetVisible(aa_main and g_antiaim.additions:Get(4))
    g_antiaim.roll_cond:SetVisible(aa_main and g_antiaim.additions:Get(1))



    --anti bruteforce 
    phase_amount:SetVisible(false)
    g_bruteforce.options:SetVisible(bf_main)
    g_bruteforce.origin:SetVisible(bf_main)
    g_bruteforce.range:SetVisible(bf_main)
    g_bruteforce.duration:SetVisible(bf_main and g_bruteforce.options:Get(2))
    g_bruteforce.bf_color:SetVisible(bf_main)

    for k , v in ipairs(g_bruteforce.stage_creation) do 
        v:SetVisible(g_bruteforce.main:GetBool() and phase_amount:GetInt() >= k)
    end

    --// Fakelag

    g_fakelag.mode:SetVisible(fl_main)
    g_fakelag.choke:SetVisible(fl_main and g_fakelag.mode:GetInt() ~= 2)
    g_fakelag.variance:SetVisible(fl_main and g_fakelag.mode:GetInt() ~= 2)
    g_fakelag.step1:SetVisible(fl_main and g_fakelag.mode:GetInt() == 2)
    g_fakelag.step2:SetVisible(fl_main and g_fakelag.mode:GetInt() == 2)
    g_fakelag.step3:SetVisible(fl_main and g_fakelag.mode:GetInt() == 2)


    --// Visuals
    
    --//Indicator
    local side = g_visuals.indic_options:Get(3) and g_visuals.indic_mode:GetInt() == 1 or g_visuals.indic_mode:GetInt() == 3

    g_visuals.health_speed:SetVisible(vis_main and g_visuals.indic_options:Get(1))

    g_visuals.indic_options:SetVisible(vis_main)
    g_visuals.arrow_mode:SetVisible(vis_main and g_visuals.indic_options:Get(2))
    g_visuals.active_side:SetVisible(vis_main and g_visuals.indic_options:Get(2) or side )
    g_visuals.inactive_side:SetVisible(vis_main and g_visuals.indic_options:Get(2) or side and g_visuals.arrow_mode ~= 2)
    g_visuals.indic_mode:SetVisible(vis_main and g_visuals.indic_options:Get(3))
    g_visuals.anim:SetVisible(vis_main and g_visuals.indic_options:Get(3) and g_visuals.indic_mode:GetInt() == 4)

    g_visuals.dmg_color:SetVisible(vis_main and g_visuals.indic_options:Get(4))
    g_visuals.dmg_width:SetVisible(vis_main and g_visuals.indic_options:Get(4))
    g_visuals.dmg_height:SetVisible(vis_main and g_visuals.indic_options:Get(4))

    g_visuals.valid_color:SetVisible(vis_main and g_visuals.indic_options:Get(3) and (g_visuals.indic_mode:GetInt() == 1 or g_visuals.indic_mode:GetInt() == 4))
    g_visuals.invalid_color:SetVisible(vis_main and g_visuals.indic_options:Get(3) and g_visuals.indic_mode:GetInt() == 1)

    g_visuals.gradient1:SetVisible(vis_main and g_visuals.indic_options:Get(3) and g_visuals.indic_mode:GetInt() == 2)
    g_visuals.gradient2:SetVisible(vis_main and g_visuals.indic_options:Get(3) and g_visuals.indic_mode:GetInt() == 2)

    g_visuals.warning_time:SetVisible(vis_main and g_visuals.indic_options:Get(5))
    g_visuals.warning_color:SetVisible(vis_main and g_visuals.indic_options:Get(5))

    --// keybinds
    g_visuals.keybind_mode:SetVisible(vis_main and g_visuals.ui_options:Get(2))
    g_visuals.binds_bg:SetVisible(vis_main and g_visuals.ui_options:Get(2))
    g_visuals.bind_color:SetVisible(vis_main and g_visuals.ui_options:Get(2))
    g_visuals.binds_x:SetVisible(false)
    g_visuals.binds_y:SetVisible(false)

    --//Watermark
    g_visuals.ui_options:SetVisible(vis_main)
    g_visuals.watermark_bg:SetVisible(vis_main and g_visuals.ui_options:Get(1) and g_visuals.watermark_mode:GetInt() == 0)
    g_visuals.enable_glow:SetVisible(vis_main and g_visuals.ui_options:Get(1) and g_visuals.watermark_mode:GetInt() == 0)
    g_visuals.glow_intensity:SetVisible(vis_main and g_visuals.ui_options:Get(1) and g_visuals.enable_glow:GetInt() == 1 and g_visuals.watermark_mode:GetInt() == 0)
    g_visuals.watermark_color:SetVisible(vis_main and g_visuals.ui_options:Get(1) and g_visuals.watermark_mode:GetInt() == 0)
    g_visuals.watermark_text:SetVisible(vis_main and g_visuals.ui_options:Get(1) )
    g_visuals.watermark_mode:SetVisible(vis_main and g_visuals.ui_options:Get(1))
    g_visuals.watermark_loc:SetVisible(vis_main and g_visuals.ui_options:Get(1) and g_visuals.watermark_mode:GetInt() == 0)

    --// Logs 
    g_visuals.log_mode:SetVisible(vis_main)
    g_visuals.log_options:SetVisible(vis_main and g_visuals.log_mode:Get() >= 1)
    g_visuals.log_color:SetVisible(vis_main and g_visuals.log_mode:Get() >= 1)

    --// World Visuals

    g_world.scope_mode:SetVisible(g_world.custom_scope:GetBool())
    g_world.scope_length:SetVisible(g_world.custom_scope:GetBool())
    g_world.scope_width:SetVisible(g_world.custom_scope:GetBool())
    g_world.scope_offset:SetVisible(g_world.custom_scope:GetBool())
    g_world.scope_scale:SetVisible(g_world.custom_scope:GetBool() and g_world.scope_mode:GetInt() == 1)

    g_world.marker_mode:SetVisible(g_world.hitmarker:GetBool())
    g_world.fade_mode:SetVisible(g_world.hitmarker:GetBool() and g_world.damage_fade:GetInt() == 1 and g_world.marker_mode:Get(2))
    g_world.damage_fade:SetVisible(g_world.hitmarker:GetBool())

    g_world.snapline_mode:SetVisible(g_world.snaplines:GetBool() and g_world.snapline_player:GetInt() == 0)
    g_world.snapline_start:SetVisible(g_world.snaplines:GetBool())
    g_world.snapline_player:SetVisible(g_world.snaplines:GetBool())

    --// Misc

    g_misc.trashtalk_mode:SetVisible(g_misc.trashtalk:GetBool())

    g_misc.hitsound_path:SetVisible(g_misc.custom_hitsound:GetBool())

end
--#endregion

--#region Lua callbacks

g_callbacks.on_paint = function()
    set_local()
    g_menu.visibility()
    update_screen()
    g_visuals.healthbar()
    g_visuals.handle_watermark()
    g_misc.clantag_animation()
    g_world.handle_hit_mark()
    g_visuals.handle_log_render()
    g_visuals.handle_hud_render()
    if not is_alive(g_cl.m_local) or not connected() then return end
    g_visuals.keybinds()
    g_visuals.handle_crosshair_indicator()
    g_world.handle_custom_scope()
    g_world.handle_snaplines()
    g_visuals.handle_anti_aim_arrow()
    g_visuals.handle_dmg_ind()
    g_bomb.update_bomb_info()
    g_visuals.handle_time_warning()
    g_visuals.handle_information_display()
end

g_callbacks.on_createmove = function(cmd)
    if not is_alive(g_cl.m_local) then return end
    g_antiaim.handle_teleport()
    g_antiaim.roll_fix(cmd)
end

g_callbacks.on_event = function(e)
    hook_round_start(e)
    hook_round_end(e)
    hook_death(e)
    if not is_alive(g_cl.m_local) then return end
    g_bruteforce.handle_impact(e)
    hook_kill(e)
    g_bomb.update_site(e)
    g_visuals.handle_purchases(e)
    g_events.handle_hit_event_cross(e)
    g_misc.hitsound(e)
end

g_callbacks.on_impact = function(shot)
    if not is_alive(g_cl.m_local) then return end
    g_events.handle_hit_event_dmg(shot)
    g_events.handle_shot(shot)
end

g_callbacks.on_prediction = function(cmd)
    if g_menu.pitch:GetInt() == 1 then 
    AntiAim.OverridePitch(89)
    end
    if not is_alive(g_cl.m_local) then return end
    update_lby()
    g_cl.update_status()
    g_fakelag.handle_land()
    g_fakelag.initilize_choke()
    g_fakelag.handle_choke()
    g_antiaim.roll(cmd)
    g_antiaim.legit_aa(cmd)
    g_rage.dormant_aimbot(cmd)
    g_antiaim.hanle_custom_aa()
    g_antiaim.disable_fl()
    g_bruteforce.apply_settings()
    g_antiaim.store_for_next_tick()
    g_rage.handle_rage_additions()
end

g_callbacks.on_destroy = function()
end

g_callbacks.on_pre_prediction = function(cmd)
    if not is_alive(g_cl.m_local) then return end
    g_cl.update_status()
    g_antiaim.handle_fakelag_exploit(cmd)
    g_rage.store_unpredicted_data()
end

g_callbacks.frame_stage = function(stage)
    if stage ~= 1 and stage ~= 2 then return end
    set_local()
end

g_callbacks.console = function(text)
   console_reg(text)
end
--#endregion

--#region Final callbacks
callback("draw", g_callbacks.on_paint)
callback("pre_prediction", g_callbacks.on_pre_prediction)
callback("prediction", g_callbacks.on_prediction)
callback("createmove", g_callbacks.on_createmove)
callback("registered_shot", g_callbacks.on_impact)
callback("events", g_callbacks.on_event)
callback("frame_stage", g_callbacks.frame_stage)
callback("console" , g_callbacks.console)
callback("destroy", g_callbacks.on_destroy)
--#endregion

if second_check then 
  requirements()
end
