AddCSLuaFile("cl_init.lua")
AddCSLuaFile("init.lua")

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Сборочный Стол"
ENT.Category = "Завод"
ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.AllowedTeams = {} 

-- Состояния завода
FACTORY_STATUS_NORMAL = 0
FACTORY_STATUS_HACKING = 1
FACTORY_STATUS_CRIPPLED = 2 
FACTORY_STATUS_BOOSTED = 3  

FACTORY_GLOBAL_STATUS = FACTORY_GLOBAL_STATUS or FACTORY_STATUS_NORMAL

-- Глобальная конфигурация суперадмина (с фоллбэками)
FACTORY_CONFIG = FACTORY_GLOBAL_CONFIG or {
    DeskIncome = 1000,       -- Базовая плата за сборку
    DevicePrice = 25000,     -- Стоимость передатчика у NPC
    CrippleCoef = 0.5,       -- Дебафф дохода мафии (x0.5)
    BoostCoef = 2.0,         -- Бафф дохода копов (x2)
    TerminalCooldown = 20    -- [ДОБАВЛЕНО]: Время блокировки терминала после ограбления (в минутах)
}

-- Глобальная таблица мафии
FAC_MAFIA_TEAMS = FAC_MAFIA_TEAMS or {}
if TEAM_GANG then FAC_MAFIA_TEAMS[TEAM_GANG] = true end
if TEAM_MOB then FAC_MAFIA_TEAMS[TEAM_MOB] = true end

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "AssemblyStage")  
    self:NetworkVar("Entity", 0, "Worker")       
    self:NetworkVar("Bool", 0, "HasMotherboard")
    self:NetworkVar("Bool", 1, "HasCPU")
    self:NetworkVar("Bool", 2, "HasGPU")
end
