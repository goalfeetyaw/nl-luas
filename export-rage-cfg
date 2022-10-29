local clipboard = require "neverlose/clipboard"
local tab = ui.create("Config File")

local weapon_groups = {"Global" , "Pistols" , "Autosnipers" , "Rifles" , "SMGs" , "Shotguns" , "AWP" , "SSG-08" , "AK-47" , "Desert Eagle" , "R8 Revolver" , "Taser"}

tab:label("Make sure to enable each weapon you want to import in ragebot")

local settings = {}

for k , v in ipairs(weapon_groups) do 
     settings[v] =
     {
        ui.find("Aimbot", "Ragebot", "Accuracy", v, "Auto Scope"),
        ui.find("Aimbot", "Ragebot", "Accuracy", v, "Auto Stop"),
        ui.find("Aimbot", "Ragebot", "Accuracy", v, "Auto Stop", "Options"),
        ui.find("Aimbot", "Ragebot", "Accuracy", v, "Auto Stop", "Double Tap"),
        ui.find("Aimbot", "Ragebot", "Accuracy", v, "Auto Stop", "Dynamic Mode"),
        ui.find("Aimbot", "Ragebot", "Accuracy", v, "Auto Stop", "Force Accuracy"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Hitboxes"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Multipoint"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Multipoint", "Head Scale"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Multipoint", "Body Scale"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Minimum Damage"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Minimum Damage", "Delay Shot"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Hit Chance"),
        ui.find("Aimbot", "Ragebot", "Selection", v, "Hit Chance", "Strict Hit Chance"),
        ui.find("Aimbot", "Ragebot", "Safety", v, "Body Aim") ,
        ui.find("Aimbot", "Ragebot", "Safety", v, "Body Aim", "Disablers"),
        ui.find("Aimbot", "Ragebot", "Safety", v, "Safe Points"),
        ui.find("Aimbot", "Ragebot", "Safety", v, "Ensure Hitbox Safety"),
        ui.find("Aimbot", "Ragebot", "Selection", v , "Penetrate Walls")
     }
end

function  export()

    print_dev("Exporting Config")

    local cfg = {}

    for index , group in ipairs(weapon_groups) do 
        cfg[group] = {}
        for name , menu_item in pairs(settings[group]) do 
            cfg[group][name] = menu_item:get()
        end
    end

    clipboard.set(json.stringify(cfg))

end

function  import()
    local cfg = json.parse(clipboard.get())

    for index , group in ipairs(weapon_groups) do 
        for name , menu_item in pairs(settings[group]) do
            menu_item:set(cfg[group][name])
        end
    end

    clipboard.set(json.stringify(cfg))

end

tab:button("Export" , function ()
    local valid , msg = pcall(export)
    local str = valid and "Successfully exported cfg" or "Error exporting cfg: "..msg
    print_dev(str)
    print_raw(str)
end)

tab:button("Import" , function ()
    local valid , msg = pcall(import)
    local str = valid and "Successfully imported cfg" or "Error importing cfg: "..msg
    print_dev(str)
    print_raw(str)
end)

