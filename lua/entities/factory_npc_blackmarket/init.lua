AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("entities/factory_assembly_desk/shared.lua")

function ENT:Initialize()
    -- ВОЗВРАЩЕНО: Модель заложника из CS:S
    self:SetModel("models/Characters/Hostage_02.mdl")
    self:SetSolid(SOLID_BBOX) 
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)
    
    self:SetAutomaticFrameAdvance(true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then 
        phys:EnableMotion(false) 
        phys:Wake()
    end

    -- Насильно подвязываем скелет к общей базе анимаций
    local targetAnim = self:LookupSequence("idle_subtle") or self:LookupSequence("idle") or 0
    if targetAnim and targetAnim ~= -1 then
        self:ResetSequence(targetAnim)
        self:SetSequence(targetAnim)
    end
    self:SetPlaybackRate(1.0)
end

-- Хук SpawnFunction отвечает за спавн NPC, когда ты вытаскиваешь его руками из Q-меню Энтити
function ENT:SpawnFunction(ply, trace, ClassName)
    if not trace.Hit then return end
    
    local ent = ents.Create(ClassName)
    -- ИСПРАВЛЕНО (ПЛОТНАЯ ПОСАДКА ДЛЯ Q-МЕНЮ): Сразу при создании опускаем точку на 4 юнита ниже прицела!
    ent:SetPos(trace.HitPos - Vector(0, 0, 2))
    
    local ang = ply:GetAngles()
    ent:SetAngles(Angle(0, ang.y + 180, 0))
    ent:Spawn()
    ent:Activate()
    
    return ent
end

function ENT:Think()
    if not SERVER then return end
    self:FrameAdvance(0.1)
    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:AcceptInput(name, activator, caller)
    if name == "Use" and IsValid(activator) and activator:IsPlayer() and activator:Alive() then
        if not FAC_MAFIA_TEAMS[activator:Team()] then
            net.Start("Factory_Desk_SendNotify")
            net.WriteString("Проваливай, я работаю только с Мафией!")
            net.WriteInt(1, 4)
            net.WriteString("buttons/combine_button_locked.wav")
            net.Send(activator)
            return
        end

        if activator:GetNWBool("Factory_HasTransponder", false) then
            net.Start("Factory_Desk_SendNotify")
            net.WriteString("У тебя уже есть одно устройство на спине!")
            net.WriteInt(3, 4)
            net.WriteString("buttons/combine_button_locked.wav")
            net.Send(activator)
            return
        end

        local currentPrice = FACTORY_CONFIG.DevicePrice or 25000
        if activator.canAfford and not activator:canAfford(currentPrice) then
            net.Start("Factory_Desk_SendNotify")
            net.WriteString("У тебя недостаточно денег! Нужно " .. currentPrice .. "$.")
            net.WriteInt(1, 4)
            net.WriteString("buttons/combine_button_locked.wav")
            net.Send(activator)
            return
        end

        if activator.addMoney then activator:addMoney(-currentPrice) end
        activator:SetNWBool("Factory_HasTransponder", true)
        net.Start("Factory_Desk_SendNotify")
        net.WriteString("Вы купили взламывающее устройство за " .. currentPrice .. "$.")
        net.WriteInt(0, 4)
        net.Send(activator)
    end
end
