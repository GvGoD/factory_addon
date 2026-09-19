include("shared.lua")

FACTORY_BEACON_HIGHLIGHT_UNTIL = FACTORY_BEACON_HIGHLIGHT_UNTIL or 0

-- Принимаем пакет админ-подсветки зон на 10 секунд от клика ПКМ
net.Receive("Factory_Toolgun_HighlightZones", function()
    FACTORY_BEACON_HIGHLIGHT_UNTIL = CurTime() + 10
end)

function ENT:Draw()
    -- Так как SetNoDraw отключен, этот хук теперь нативно и стабильно вызывается движком Source!
    local radius = self:GetNWInt("ZoneRadius", 250)
    local segments = 32
    local pos = self:GetPos() + Vector(0, 0, 4)

    local isRobberyActive = GetGlobalBool("Factory_IsRobberyActive", false)
    local isHighlightActive = (FACTORY_BEACON_HIGHLIGHT_UNTIL and CurTime() < FACTORY_BEACON_HIGHLIGHT_UNTIL) -- Нажат ПКМ

    if isRobberyActive or isHighlightActive then
        cam.Start3D2D(pos, Angle(0, 0, 0), 1)
            draw.NoTexture()
            local poly = {}
            for i = 0, segments - 1 do
                local a = math.rad((i / segments) * 360)
                table.insert(poly, { x = math.cos(a) * radius, y = math.sin(a) * radius })
            end
            
            -- Окраска полей: Во время налета — сочно КРАСНЫЙ, при админ-проверке на ПКМ — СИНИЙ!
            if isRobberyActive then
                surface.SetDrawColor(231, 76, 60, 15) 
                surface.DrawPoly(poly)
                surface.SetDrawColor(231, 76, 60, 140)
            else
                surface.SetDrawColor(52, 152, 219, 15) 
                surface.DrawPoly(poly)
                surface.SetDrawColor(52, 152, 219, 180)
            end

            for i = 1, segments do
                local nextIdx = i + 1
                if i == segments then nextIdx = 1 end
                surface.DrawLine(poly[i].x, poly[i].y, poly[nextIdx].x, poly[nextIdx].y)
            end
        cam.End3D2D()
    end
end
