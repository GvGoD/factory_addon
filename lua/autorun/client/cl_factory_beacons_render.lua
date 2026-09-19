if SERVER then return end

FACTORY_BEACON_HIGHLIGHT_UNTIL = FACTORY_BEACON_HIGHLIGHT_UNTIL or 0

net.Receive("Factory_Toolgun_HighlightZones", function()
    FACTORY_BEACON_HIGHLIGHT_UNTIL = CurTime() + 10
end)

hook.Add("PostDrawTranslucentRenderables", "Factory_Absolute_Beacons_Render", function()
    -- ИСПРАВЛЕНО (ФИКС ОТОБРАЖЕНИЯ ПРИ ВЗЛОМЕ): Клиент читает системный сетевой буфер GetGlobalBool.
    -- Больше никаких скрытых рассинхронизаций — лазеры складов железно загорятся у всех клиентов!
    local isRobberyActive = GetGlobalBool("Factory_IsRobberyActive", false)
    local isHighlightActive = (FACTORY_BEACON_HIGHLIGHT_UNTIL and CurTime() < FACTORY_BEACON_HIGHLIGHT_UNTIL)

    if not isRobberyActive and not isHighlightActive then return end

    local segments = 32
    local beacons = ents.FindByClass("factory_robbery_beacon")
    
    for i = 1, #beacons do
        local ent = beacons[i]
        if not IsValid(ent) then continue end

        local radius = ent:GetNWInt("ZoneRadius", 250)
        local renderPos = ent:GetPos() + Vector(0, 0, 4)

        cam.Start3D2D(renderPos, Angle(0, 0, 0), 1)
            draw.NoTexture()
            local poly = {}
            for j = 0, segments - 1 do
                local a = math.rad((j / segments) * 360)
                table.insert(poly, { x = math.cos(a) * radius, y = math.sin(a) * radius })
            end
            
            -- Подсветка: Во время налета — сочно КРАСНЫЙ, при админ-проверке на ПКМ — СИНИЙ!
            if isRobberyActive then
                surface.SetDrawColor(231, 76, 60, 15) 
                surface.DrawPoly(poly)
                surface.SetDrawColor(231, 76, 60, 140)
            else
                surface.SetDrawColor(52, 152, 219, 15) 
                surface.DrawPoly(poly)
                surface.SetDrawColor(52, 152, 219, 180)
            end

            for j = 1, segments do
                local nextIdx = j + 1
                if j == segments then nextIdx = 1 end
                surface.DrawLine(poly[j].x, poly[j].y, poly[nextIdx].x, poly[nextIdx].y)
            end
        cam.End3D2D()
    end
end)
