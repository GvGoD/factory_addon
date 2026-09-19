TOOL.Category = "Завод"
TOOL.Name = "Разметчик Зон Завода"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["radius"] = "250"
TOOL.ClientConVar["time_payout"] = "1800"
TOOL.ClientConVar["jackpot"] = "50000"

local function HasFactoryAccess(ply)
    if not IsValid(ply) then return false end
    return ply:IsSuperAdmin() or ply:IsAdmin()
end

if SERVER then
    util.AddNetworkString("Factory_Toolgun_Server_LeftClick")
    util.AddNetworkString("Factory_Toolgun_Server_RightClick")
    util.AddNetworkString("Factory_Toolgun_HighlightZones")

    -- Приёмник ЛКМ: Создает энтити-маяк зоны в точке прицела и пишет в общую базу данных
    net.Receive("Factory_Toolgun_Server_LeftClick", function(len, ply)
        if not HasFactoryAccess(ply) then return end
        
        local hitPos = net.ReadVector()
        local radius = net.ReadInt(32)
        local payout = net.ReadInt(32)
        local jackpot = net.ReadInt(32)

        local zoneID = tostring(math.Round(hitPos.x)) .. "_" .. tostring(math.Round(hitPos.y))
        
        -- ИСПРАВЛЕНО: Пишем параметры зоны в глобальный массив сервера для тикера выплат!
        FACTORY_GLOBAL_ZONES[zoneID] = {
            Pos = hitPos,
            Radius = radius,
            TimePayout = payout,
            Jackpot = jackpot
        }

        local beacon = ents.Create("factory_robbery_beacon")
        if IsValid(beacon) then
            beacon:SetPos(hitPos)
            beacon:Spawn()
            beacon:SetNWInt("ZoneRadius", radius)
            beacon:SetNWInt("TimePayout", payout)
            beacon:SetNWInt("FinalJackpot", jackpot)
            
            ply:EmitSound("buttons/button15.wav", 60, 100)
        end
    end)

    net.Receive("Factory_Toolgun_Server_RightClick", function(len, ply)
        if not IsValid(ply) or not HasFactoryAccess(ply) then return end
        if FACTORY_GLOBAL_STATUS == 1 then return end 

        net.Start("Factory_Toolgun_HighlightZones")
        net.Broadcast()

        net.Start("Factory_Desk_SendNotify")
        net.WriteString("Админ-подсветка складов завода включена на 10 секунд!")
        net.WriteInt(2, 4)
        net.Send(ply)
    end)
end

if CLIENT then
    language.Add("tool.factory_configurator.name", "Разметчик Зон Завода")
    language.Add("tool.factory_configurator.0", "ЛКМ: Создать Зону Ограбления, ПКМ: Подсветить все зоны на 10 секунд")

    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", { Text = "Разметчик Завода", Description = "Настройка радиуса и выплат" })
        panel:AddControl("Slider", { Label = "Радиус зоны ограбления", Type = "Int", Min = 150, Max = 600, Command = "factory_configurator_radius" })
        panel:AddControl("Slider", { Label = "Выплата за 10 сек ($)", Type = "Int", Min = 500, Max = 10000, Command = "factory_configurator_time_payout" })
        panel:AddControl("Slider", { Label = "Финальный куш ($)", Type = "Int", Min = 5000, Max = 250000, Command = "factory_configurator_jackpot" })
    end

    function TOOL:DrawHUD()
        local ply = LocalPlayer()
        if not HasFactoryAccess(ply) then return end
        local trace = ply:GetEyeTrace()
        if not trace.Hit then return end
        local radius = self:GetClientNumber("radius", 250)
        
        cam.Start3D()
            render.SetColorMaterial()
            local segments = 32
            local prevX, prevY = trace.HitPos.x + radius, trace.HitPos.y
            for i = 1, segments do
                local a = math.rad((i / segments) * 360)
                local newX = trace.HitPos.x + math.cos(a) * radius
                local newY = trace.HitPos.y + math.sin(a) * radius
                render.DrawLine(Vector(prevX, prevY, trace.HitPos.z + 2), Vector(newX, newY, trace.HitPos.z + 2), Color(46, 204, 113, 200), true)
                prevX, prevY = newX, newY
            end
        cam.End3D()
    end
end

function TOOL:LeftClick(trace)
    if not trace.Hit then return false end
    if CLIENT then
        local radius = self:GetClientNumber("radius", 250)
        local payout = self:GetClientNumber("time_payout", 1800)
        local jackpot = self:GetClientNumber("jackpot", 50000)

        net.Start("Factory_Toolgun_Server_LeftClick")
        net.WriteVector(trace.HitPos)
        net.WriteInt(radius, 32)
        net.WriteInt(payout, 32)
        net.WriteInt(jackpot, 32)
        net.SendToServer()
    end
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then
        timer.Simple(0.05, function()
            net.Start("Factory_Toolgun_Server_RightClick")
            net.SendToServer()
        end)
    end
    return true
end

function TOOL:Reload(trace) return false end
