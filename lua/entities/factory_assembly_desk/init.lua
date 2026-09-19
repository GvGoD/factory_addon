include("shared.lua")

ActiveClues = ActiveClues or {}

util.AddNetworkString("Factory_Desk_ClickButton")
util.AddNetworkString("Factory_Desk_SyncCycle")
util.AddNetworkString("Factory_Desk_SendNotify")

function ENT:SendFactoryNotify(ply, text, typeID, sound)
    if not IsValid(ply) then return end
    net.Start("Factory_Desk_SendNotify")
    net.WriteString(text)
    net.WriteInt(typeID or 0, 4)
    net.WriteString(sound or "")
    net.Send(ply)
end

function ENT:Initialize()
    self:SetModel("models/props_wasteland/controlroom_desk001b.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE) 

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetAssemblyStage(0)
    self:SetWorker(nil)
    
    self.CurrentPC = nil
    self.SpawnedParts = {}
    self.LastActionTime = 0
end

function ENT:SpawnAssemblyProp(model, localPos, localAng, key)
    if key and IsValid(self.SpawnedParts[key]) then 
        self.SpawnedParts[key]:Remove() 
        self.SpawnedParts[key] = nil
    end

    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then return nil end

    local globalPos = self:LocalToWorld(localPos)
    local globalAng = self:LocalToWorldAngles(localAng)

    ent:SetModel(model)
    ent:SetPos(globalPos)
    ent:SetAngles(globalAng)
    ent:SetParent(self) 
    ent:Spawn()

    ent:SetHealth(999999)
    ent:SetMaxHealth(999999)
    ent.AddTextValue = "FactoryPart" 

    if key then
        self.SpawnedParts[key] = ent
    else
        self.CurrentPC = ent
    end

    return ent
end

function ENT:StartNewAssemblyCycle()
    self:SetAssemblyStage(1) -- Начинаем строго с Материнской платы (1)
    self.LastActionTime = CurTime()

    self:SetHasMotherboard(false)
    self:SetHasCPU(false)
    self:SetHasGPU(false)

    -- Спавним корпуса по твоим идеальным координатам
    if not IsValid(self.CurrentPC) then
        self:SpawnAssemblyProp("models/props/cs_office/computer_caseb_p7.mdl", Vector(0, 0, 17), Angle(0, 270, 0), nil)
    else
        self.CurrentPC:SetModel("models/props/cs_office/computer_caseb_p7.mdl")
    end

    self:SpawnAssemblyProp("models/props/cs_office/computer_caseb_p7a.mdl", Vector(0, 30, 20), Angle(0, 0, 270), 1)
    self:SpawnAssemblyProp("models/props/cs_office/computer_caseb_p5b.mdl", Vector(10, -30, 15.5), Angle(90, 225, 90), 2)
    self:SpawnAssemblyProp("models/props/cs_office/computer_caseb_p2a.mdl", Vector(0, -40, 10), Angle(0, -30, 0), 3)

    -- Посылаем пинг клиенту, чтобы он у себя локально выбрал случайный пресет кнопок
    local worker = self:GetWorker()
    if IsValid(worker) then
        net.Start("Factory_Desk_SyncCycle")
        net.WriteEntity(self)
        net.Send(worker)
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end

    local stage = self:GetAssemblyStage()
    local worker = self:GetWorker()

    if stage == 0 and not IsValid(worker) then
        if self.AllowedTeams and table.Count(self.AllowedTeams) > 0 and not self.AllowedTeams[activator:Team()] then
            self:SendFactoryNotify(activator, "Ваша профессия не подходит для завода!", 1, "buttons/combine_button_locked.wav")
            return
        end

        for _, desk in ipairs(ents.FindByClass("factory_assembly_desk")) do
            if desk ~= self and desk:GetWorker() == activator then
                self:SendFactoryNotify(activator, "Вы уже заняты сборкой за другим столом!", 1, "buttons/combine_button_locked.wav")
                return
            end
        end

        self:SetWorker(activator)
        self:StartNewAssemblyCycle()
        return
    end
end

net.Receive("Factory_Desk_ClickButton", function(len, ply)
    if not IsValid(ply) then return end
    
    local desk = net.ReadEntity()
    local componentID = net.ReadInt(4) -- ИСПРАВЛЕНО: Принимаем чистый верифицированный ID детали (1, 2 или 3)

    if not IsValid(desk) or desk:GetClass() ~= "factory_assembly_desk" then return end
    if desk:GetWorker() ~= ply or desk:GetAssemblyStage() > 3 then return end

    local currentRequired = desk:GetAssemblyStage()

    -- ЖЕЛЕЗОБЕТОННАЯ СВЕРКА: Никакой путаницы с индексами кнопок на экране
    if componentID ~= currentRequired then
        desk:SendFactoryNotify(ply, "Последовательность нарушена! Сборка сброшена в начало.", 1, "buttons/combine_button_locked.wav")
        desk:StartNewAssemblyCycle()
        return
    end

    desk.LastActionTime = CurTime()
    ply:EmitSound("buttons/button9.wav", 65, 100)

    -- Прямое удаление пропов комплектующих справа со стола
    if IsValid(desk.SpawnedParts[componentID]) then 
        desk.SpawnedParts[componentID]:Remove() 
        desk.SpawnedParts[componentID] = nil
    end

    if componentID == 1 then
        desk:SetHasMotherboard(true)
        desk:SetAssemblyStage(2) -- Включаем этап Процессора
        if IsValid(desk.CurrentPC) then desk.CurrentPC:SetModel("models/props/cs_office/computer_caseb_p5.mdl") end

    elseif componentID == 2 then
        desk:SetHasCPU(true)
        desk:SetAssemblyStage(3) -- Включаем этап Видеокарты
        if IsValid(desk.CurrentPC) then desk.CurrentPC:SetModel("models/props/cs_office/computer_caseb_p3.mdl") end

    elseif componentID == 3 then
        desk:SetHasGPU(true)
        desk:SetAssemblyStage(4) -- Режим ожидания выплаты награды

        if IsValid(desk.CurrentPC) then desk.CurrentPC:SetModel("models/props/cs_office/computer_caseb.mdl") end

        -- Открой свой файл factory_assembly_desk/init.lua, найди блок успешного окончания сборки ПК (в самом низу net.Receive) 
-- и замени таймер выдачи награды на этот динамический вариант:

        timer.Simple(2, function()
            if IsValid(desk) and desk:GetAssemblyStage() == 4 then
                local currentWorker = desk:GetWorker()
                if IsValid(currentWorker) and currentWorker:Alive() then
                    
                    -- ИСПРАВЛЕНО (ДИНАМИЧЕСКАЯ ЭКОНОМИКА С УЧЕТОМ УТИЛИТ):
                    -- Читаем базовую цену из конфига админа FACTORY_CONFIG.DeskIncome.
                    -- Применяем коэффициенты CrippleCoef (дебафф мафии) или BoostCoef (бафф копов) динамически!
                    local baseIncome = FACTORY_CONFIG.DeskIncome or 1000
                    local modifier = 1
                    
                    if FACTORY_GLOBAL_STATUS == FACTORY_STATUS_CRIPPLED then
                        modifier = FACTORY_CONFIG.CrippleCoef or 0.5
                    elseif FACTORY_GLOBAL_STATUS == FACTORY_STATUS_BOOSTED then
                        modifier = FACTORY_CONFIG.BoostCoef or 2.0
                    end
                    
                    local finalReward = math.Round(baseIncome * modifier)

                    if currentWorker.addMoney then 
                        currentWorker:addMoney(finalReward) 
                    else 
                        currentWorker:SetFrags(currentWorker:Frags() + 1) 
                    end
                    
                    -- Оповещение с точным динамическим выводом суммы награды на экран
                    desk:SendFactoryNotify(currentWorker, "Компьютер успешно собран! Вы получили: " .. finalReward .. "$.", 0, "buttons/bell1.wav")
                    desk:StartNewAssemblyCycle()
                else
                    desk:ResetDesk()
                end
            end
        end)
    end
end)

function ENT:ResetDesk()
    if IsValid(self.CurrentPC) then self.CurrentPC:Remove() end
    for k, part in pairs(self.SpawnedParts) do 
        if IsValid(part) then part:Remove() end 
    end
    self.SpawnedParts = {}
    
    self:SetWorker(nil)
    self:SetAssemblyStage(0)
    self.LastActionTime = 0
end

function ENT:Think()
    if not SERVER then return end

    local worker = self:GetWorker()
    local stage = self:GetAssemblyStage()

    if stage ~= 0 and IsValid(worker) then
        local dist = self:GetPos():Distance(worker:GetPos())
        
        if dist > 200 or not worker:Alive() then
            self:SendFactoryNotify(worker, "Вы отошли слишком далеко! Работа аннулирована.", 1, "buttons/combine_button_locked.wav")
            self:ResetDesk()
            return
        end

        if CurTime() - self.LastActionTime > 60 then
            self:SendFactoryNotify(worker, "Время сборки этапа истекло (1 минута АФК). Стол освобожден!", 1, "buttons/combine_button_locked.wav")
            self:ResetDesk()
            return
        end
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:OnRemove()
    if IsValid(self.CurrentPC) then self.CurrentPC:Remove() end
    for k, part in pairs(self.SpawnedParts) do if IsValid(part) then part:Remove() end end
end

hook.Add("PhysgunPickup", "Factory_BlockPartGrab", function(ply, ent)
    if IsValid(ent) and (ent:GetClass() == "factory_assembly_desk" or ent.AddTextValue == "FactoryPart") then
        if ply:IsAdmin() and ent:GetClass() == "factory_assembly_desk" then return true end
        return false 
    end
end)

hook.Add("EntityTakeDamage", "Factory_BlockDeskDamage", function(target, dmginfo)
    if IsValid(target) and (target:GetClass() == "factory_assembly_desk" or target.AddTextValue == "FactoryPart") then
        dmginfo:SetDamage(0)
        return true
    end
end)
