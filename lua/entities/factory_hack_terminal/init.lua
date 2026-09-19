AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("entities/factory_assembly_desk/shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_silo/launch_button.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false) 
    end

    self.AttachedDevice = nil
    self.CopHacking = nil
    self.CopProgress = 0
    
    self:SetNWBool("Client_IsHacking", false)
    self:SetNWInt("CooldownEndTime", 0)
end

function ENT:StartTerminalCooldown()
    local cooldownMinutes = FACTORY_CONFIG.TerminalCooldown or 20
    self:SetNWInt("CooldownEndTime", math.Round(CurTime() + (cooldownMinutes * 60)))
end

local function IsLawEnforcement(ply)
    if not IsValid(ply) then return false end
    local t = ply:Team()
    return (TEAM_POLICE and t == TEAM_POLICE) or (TEAM_CHIEF and t == TEAM_CHIEF) or (TEAM_MAYOR and t == TEAM_MAYOR) or (TEAM_SWAT and t == TEAM_SWAT)
end

function ENT:AcceptInput(name, activator, caller)
    if name == "Use" and IsValid(activator) and activator:IsPlayer() and activator:Alive() then
        
        local isHacking = self:GetNWBool("Client_IsHacking", false)

        if self:GetNWInt("CooldownEndTime", 0) > CurTime() then
            net.Start("Factory_Desk_SendNotify")
            net.WriteString("Терминал заблокирован службой безопасности!")
            net.WriteInt(1, 4)
            net.WriteString("buttons/combine_button_locked.wav")
            net.Send(activator)
            return
        end

        if FACTORY_GLOBAL_STATUS == FACTORY_STATUS_HACKING and isHacking then
            if IsLawEnforcement(activator) then
                if not IsValid(self.CopHacking) then
                    self.CopHacking = activator
                    self.CopProgress = 0
                    activator:EmitSound("buttons/combine_button1.wav", 65, 100)
                end
            end
            return
        end

        if FACTORY_GLOBAL_STATUS == FACTORY_STATUS_NORMAL and not isHacking then
            if not activator:GetNWBool("Factory_HasTransponder", false) then
                net.Start("Factory_Desk_SendNotify")
                net.WriteString("Вам нужно принести взламывающее устройство со спины!")
                net.WriteInt(3, 4)
                net.Send(activator)
                return
            end

            FACTORY_GLOBAL_STATUS = FACTORY_STATUS_HACKING
            SetGlobalInt("Factory_AssemblyPayoutStatus", FACTORY_GLOBAL_STATUS)
            self:SetNWBool("Client_IsHacking", true)
            SetGlobalBool("Factory_IsRobberyActive", true)
            activator:SetNWBool("Factory_HasTransponder", false)

            FACTORY_ROBBERY_TIMER = 300 
            SetGlobalInt("Factory_Countdown", FACTORY_ROBBERY_TIMER)

            timer.Remove("Factory_Global_Robbery_Ticker")

            local device = ents.Create("prop_physics")
            if IsValid(device) then
                device:SetModel("models/props_citizen_tech/transponder.mdl")
                device:SetPos(self:GetPos() + self:GetUp() * 14 + self:GetForward() * -5) 
                device:SetAngles(self:GetAngles())
                device:Spawn()
                local dPhys = device:GetPhysicsObject()
                if IsValid(dPhys) then dPhys:EnableMotion(false) end
                device:SetParent(self)
                self.AttachedDevice = device
            end

            for _, desk in ipairs(ents.FindByClass("factory_assembly_desk")) do
                if desk:GetAssemblyStage() ~= 0 then desk:ResetDesk() end
                desk:SetAssemblyStage(5) 
            end

            if isfunction(Factory_StartRobberyTimerLogic) then Factory_StartRobberyTimerLogic() end

            for _, p in ipairs(player.GetAll()) do
                net.Start("Factory_Desk_SendNotify")
                net.WriteString("ВНИМАНИЕ: Запущен взлом главного терминала завода!")
                net.WriteInt(1, 4)
                net.WriteString("ambient/alarms/siren1.wav")
                net.Send(p)
            end
        end
    end
end
function ENT:Think()
    if not SERVER then return end

    if FACTORY_GLOBAL_STATUS == FACTORY_STATUS_HACKING and IsValid(self.CopHacking) then
        local cop = self.CopHacking
        local traceEnt = cop:GetEyeTrace().Entity

        if cop:Alive() and cop:KeyDown(IN_USE) and traceEnt == self and cop:GetPos():Distance(self:GetPos()) <= 120 then
            self.CopProgress = self.CopProgress + 0.1
            cop:SetNWFloat("Factory_Cop_HoldProgress", self.CopProgress / 10)

            if self.CopProgress >= 10 then
                FACTORY_GLOBAL_STATUS = FACTORY_STATUS_BOOSTED
                SetGlobalInt("Factory_AssemblyPayoutStatus", FACTORY_GLOBAL_STATUS)
                self:SetNWBool("Client_IsHacking", false)
                SetGlobalBool("Factory_IsRobberyActive", false)
                self:StartTerminalCooldown()

                timer.Remove("Factory_Global_Robbery_Ticker")

                for _, desk in ipairs(ents.FindByClass("factory_assembly_desk")) do
                    if desk:GetAssemblyStage() == 5 then desk:ResetDesk() end
                end

                if IsValid(self.AttachedDevice) then self.AttachedDevice:Remove() end
                
                -- ИСПРАВЛЕНО (ФИКС КОНФЛИКТА СНЯТИЯ ВАРНОВ):
                -- Все старые циклы, вызывавшие p:unWanted(), ПОЛНОСТЬЮ УДАЛЕНЫ из этого хука!
                -- Теперь полиция забирает $10,000, а системный розыск города с мафии больше не слетает!
                if cop.addMoney then cop:addMoney(10000) end
                
                net.Start("Factory_Desk_SendNotify")
                net.WriteString("Вы успешно отключили устройство взлома! Премия: +10,000$.")
                net.WriteInt(0, 4)
                net.WriteString("popup/money.wav")
                net.Send(cop)

                cop:SetNWFloat("Factory_Cop_HoldProgress", 0)
                self.CopHacking = nil

                for _, p in ipairs(player.GetAll()) do
                    net.Start("Factory_Desk_SendNotify")
                    net.WriteString("Полиция остановила налет! Доход столов повышен на х" .. FACTORY_CONFIG.BoostCoef)
                    net.WriteInt(0, 4)
                    net.WriteString("npc/overwatch/radiovoice/on1.wav")
                    net.Send(p)
                end

                timer.Simple(300, function() 
                    FACTORY_GLOBAL_STATUS = FACTORY_STATUS_NORMAL
                    SetGlobalInt("Factory_AssemblyPayoutStatus", FACTORY_GLOBAL_STATUS)
                end)
            end
        else
            cop:SetNWFloat("Factory_Cop_HoldProgress", 0)
            self.CopHacking = nil
            self.CopProgress = 0
        end
    end

    local robberyTimeLeft = GetGlobalInt("Factory_Countdown", 0)
    if FACTORY_GLOBAL_STATUS ~= FACTORY_STATUS_HACKING and robberyTimeLeft <= 0 then
        if GetGlobalBool("Factory_IsRobberyActive", false) then
            SetGlobalBool("Factory_IsRobberyActive", false)
            timer.Remove("Factory_Global_Robbery_Ticker")
        end
    end

    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:OnRemove()
    if IsValid(self.AttachedDevice) then self.AttachedDevice:Remove() end
    SetGlobalBool("Factory_IsRobberyActive", false)
    timer.Remove("Factory_Global_Robbery_Ticker")
end
