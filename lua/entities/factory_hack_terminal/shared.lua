ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Терминал Взламывания (Завод)"
ENT.Category = "Завод"
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- ИСПРАВЛЕНО СИНТАКСИС: Двоеточие возвращено на место, движок GLua скомпилирует NetworkVar без ошибок!
function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "IsHackingActive")
end
