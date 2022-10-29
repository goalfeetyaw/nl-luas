local font = render.load_font("C:\\Windows\\Fonts\\segoeui.ttf", 20, "a" )
local logs = {}

function lerp(start, vend, time)
    return start + (vend - start) * time
end

events.aim_ack:set(function (ctx)
    if ctx.state ~= nil then return end
    local data = 
    {
        position = ctx.aim, 
        color = ctx.hitgroup == 1 and color( 255 , 0 , 0 , 255) or color( 255 , 255 , 255) , 
        damage = math.floor(ctx.damage) , 
        alpha = 1200
    }
    table.insert(logs , data)
end)

events.render:set(function ()
     
    for index , data in ipairs(logs) do 

        if data.alpha <= 2 then 
            table.remove( logs , index)
        end

        data.alpha = lerp(data.alpha , 0 , globals.frametime * 3)

        local color = color ( data.color.r , data.color.g , data.color.b , data.alpha )

        local position = data.position + vector(0 , -5 , 30)

        render.text(font , position:to_screen() , color , "" , data.damage)

    end

end)
