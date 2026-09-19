AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")
include("entities/factory_assembly_desk/shared.lua")

function ENT:Initialize()
    -- Полностью невидимый, сквозной серверный фантом-маркер коорднинат
    self:SetModel("models/props_junk/wood_crate002a.mdl")
    self:SetSolid(SOLID_NONE) 
    self:SetMoveType(MOVETYPE_NONE)
    
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(0, 0, 0, 0))
    self:SetKeyValue("gmod_allowtools", "0")
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    self:SetNWInt("ZoneRadius", 250)
    self:SetNWInt("TimePayout", 1800)
    self:SetNWInt("FinalJackpot", 50000)
end

-- Блокировка Physgun-захвата админами
hook.Add("PhysgunPickup", "Factory_Lock_Zones_From_Physgun", function(ply, ent)
    if IsValid(ent) and ent:GetClass() == "factory_robbery_beacon" then return false end
end)

-- ИСПРАВЛЕНО: Метод Think маяка очищен от дублирующих начислений,
-- чтобы полностью исключить баг с выдачей 4-х долей за раз!
function ENT:Think()
    self:NextThink(CurTime() + 1)
    return true
end
