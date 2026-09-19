include("shared.lua")

local function IsLawEnforcement(ply)
    if not IsValid(ply) then return false end
    local t = ply:Team()
    return (TEAM_POLICE and t == TEAM_POLICE) or (TEAM_CHIEF and t == TEAM_CHIEF) or (TEAM_MAYOR and t == TEAM_MAYOR) or (TEAM_SWAT and t == TEAM_SWAT)
end

function ENT:Draw()
    self:DrawModel()

    local isHacking = self:GetNWBool("Client_IsHacking", false)
    local cooldownEnd = self:GetNWInt("CooldownEndTime", 0)

    if isHacking then
        local countTime = GetGlobalInt("Factory_Countdown", 300)
        local minutes = math.floor(countTime / 60)
        local seconds = countTime % 60
        local timeStr = string.format("ДО ВЗЛОМА: %02d:%02d", minutes, seconds)

        local textPos = self:GetPos() + Vector(0, 0, 18)
        local textAng = EyeAngles()
        textAng:RotateAroundAxis(textAng:Up(), -90)
        textAng:RotateAroundAxis(textAng:Forward(), 90)

        cam.Start3D2D(textPos, textAng, 0.1)
            draw.RoundedBox(4, -90, -12, 180, 24, Color(24, 24, 24, 220))
            draw.SimpleText(timeStr, "DermaDefaultBold", 0, -1, Color(231, 76, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()

        local LocalPly = LocalPlayer()
        if IsLawEnforcement(LocalPly) then
            local promptPos = self:GetPos() + Vector(0, 0, 11)
            cam.Start3D2D(promptPos, textAng, 0.07)
                draw.RoundedBox(6, -150, -14, 300, 28, Color(41, 128, 185, 200))
                draw.SimpleText("ЗАЖМИТЕ И УДЕРЖИВАЙТЕ [ E ]", "DermaDefaultBold", 0, -1, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    
    elseif cooldownEnd > CurTime() then
        local timeLeft = math.max(0, math.Round(cooldownEnd - CurTime()))
        local minutes = math.floor(timeLeft / 60)
        local seconds = timeLeft % 60
        local cooldownStr = string.format("БЛОКИРОВКА СИСТЕМ: %02d:%02d", minutes, seconds)

        local textPos = self:GetPos() + Vector(0, 0, 18)
        local textAng = EyeAngles()
        textAng:RotateAroundAxis(textAng:Up(), -90)
        textAng:RotateAroundAxis(textAng:Forward(), 90)

        cam.Start3D2D(textPos, textAng, 0.1)
            draw.RoundedBox(4, -110, -12, 220, 24, Color(40, 40, 40, 240))
            draw.SimpleText(cooldownStr, "DermaDefaultBold", 0, -1, Color(149, 165, 166), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end

hook.Add("HUDPaint", "Factory_Cop_HoldProgressBar", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local progress = ply:GetNWFloat("Factory_Cop_HoldProgress", 0)
    if progress <= 0 then return end

    local scrW, scrH = ScrW(), ScrH()
    local barW, barH = 240, 14
    local barX, barY = (scrW / 2) - (barW / 2), (scrH / 2) + 60

    draw.RoundedBox(4, barX - 2, barY - 2, barW + 4, barH + 4, Color(15, 15, 15, 240))
    draw.RoundedBox(2, barX, barY, barW, barH, Color(40, 40, 40, 200))

    local fillW = barW * progress
    draw.RoundedBox(2, barX, barY, fillW, barH, Color(52, 152, 219, 255))

    draw.SimpleText("ПЕРЕХВАТ ТЕРМИНАЛА... " .. math.Round(progress * 100) .. "%", "DermaDefaultBold", scrW / 2, barY - 15, Color(255, 255, 255), TEXT_ALIGN_CENTER)
end)
