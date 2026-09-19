if SERVER then
    AddCSLuaFile("entities/factory_robbery_beacon/shared.lua")
    AddCSLuaFile("entities/factory_robbery_beacon/cl_init.lua")
end

FACTORY_CONFIG = FACTORY_CONFIG or { DeskIncome = 1000, DevicePrice = 25000, CrippleCoef = 0.5, BoostCoef = 2.0, TerminalCooldown = 20 }

local function HasFactoryAccess(ply)
    if not IsValid(ply) then return false end
    return ply:IsSuperAdmin() or ply:IsAdmin()
end

if SERVER then
    AddCSLuaFile()
    FACTORY_GLOBAL_ZONES = FACTORY_GLOBAL_ZONES or {}

    local savedConfig = util.JSONToTable(file.Read("factory_global_config.txt", "DATA") or "")
    if istable(savedConfig) then
        FACTORY_CONFIG.DeskIncome = tonumber(savedConfig.DeskIncome) or FACTORY_CONFIG.DeskIncome
        FACTORY_CONFIG.DevicePrice = tonumber(savedConfig.DevicePrice) or FACTORY_CONFIG.DevicePrice
        FACTORY_CONFIG.CrippleCoef = tonumber(savedConfig.CrippleCoef) or FACTORY_CONFIG.CrippleCoef
        FACTORY_CONFIG.BoostCoef = tonumber(savedConfig.BoostCoef) or FACTORY_CONFIG.BoostCoef
        FACTORY_CONFIG.TerminalCooldown = tonumber(savedConfig.TerminalCooldown) or FACTORY_CONFIG.TerminalCooldown
    end

    local function SyncFactoryEconomyGlobals()
        SetGlobalInt("Factory_DeskIncome", math.Round(FACTORY_CONFIG.DeskIncome or 1000))
        SetGlobalFloat("Factory_CrippleCoef", FACTORY_CONFIG.CrippleCoef or 0.5)
        SetGlobalFloat("Factory_BoostCoef", FACTORY_CONFIG.BoostCoef or 2)
    end

    SyncFactoryEconomyGlobals()
    SetGlobalInt("Factory_AssemblyPayoutStatus", FACTORY_GLOBAL_STATUS or 0)

    util.AddNetworkString("Factory_Admin_SaveConfig")
    util.AddNetworkString("Factory_Admin_SaveMapAction")
    util.AddNetworkString("Factory_Admin_ClearMapAction")

    -- Автозагрузка карты
    -- Открой свой файл factory_admin_menu.lua, найди ХУК АВТОЗАГРУЗКИ КАРТЫ внутри PostGamemodeLoaded и замени его на этот:

    -- Автозагрузка объектов при старте сервера
    hook.Add("PostGamemodeLoaded", "Factory_System_AbsoluteLoadMap", function()
        timer.Simple(5.0, function()
            if not file.Exists("factory_system_save.txt", "DATA") then return end
            local loadData = util.JSONToTable(file.Read("factory_system_save.txt", "DATA") or "")
            if not loadData then return end

            -- Чистим объекты перед спавном новых
            for _, ent in ipairs(ents.FindByClass("factory_hack_terminal")) do ent:Remove() end
            for _, ent in ipairs(ents.FindByClass("factory_npc_blackmarket")) do ent:Remove() end
            for _, ent in ipairs(ents.FindByClass("factory_assembly_desk")) do ent:Remove() end
            for _, ent in ipairs(ents.FindByClass("factory_robbery_beacon")) do ent:Remove() end
            timer.Remove("Factory_Global_Robbery_Ticker")
            
            -- Зануляем базу данных зон для чистой перезаписи
            FACTORY_GLOBAL_ZONES = {}

            if loadData.Entities then
                for _, info in ipairs(loadData.Entities) do
                    local ent = ents.Create(info.Class)
                    if IsValid(ent) then
                        if info.Class == "factory_npc_blackmarket" then
                            ent:SetPos(info.Pos - Vector(0, 0, -1))
                        else
                            ent:SetPos(info.Pos)
                        end
                        ent:SetAngles(info.Ang)
                        ent:Spawn()
                        
                        -- ИСПРАВЛЕНО (АВТОЗАГРУЗКА БАЗЫ ВЫПЛАТ): Заносим параметры считанного маяка напрямую в глобальную таблицу сервера!
                        if info.Class == "factory_robbery_beacon" then
                            ent:SetNWInt("ZoneRadius", info.Radius or 250)
                            ent:SetNWInt("TimePayout", info.Payout or 1800)
                            ent:SetNWInt("FinalJackpot", info.Jackpot or 50000)

                            local zoneID = tostring(math.Round(info.Pos.x)) .. "_" .. tostring(math.Round(info.Pos.y))
                            FACTORY_GLOBAL_ZONES[zoneID] = {
                                Pos = info.Pos,
                                Radius = info.Radius or 250,
                                TimePayout = info.Payout or 1800,
                                Jackpot = info.Jackpot or 50000
                            }
                        end
                    end
                end
            end
        end)
    end)

    net.Receive("Factory_Admin_SaveMapAction", function(len, ply)
        if not HasFactoryAccess(ply) then return end
        local saveData = { Entities = {} }

        for _, ent in ipairs(ents.FindByClass("factory_assembly_desk")) do
            table.insert(saveData.Entities, { Class = "factory_assembly_desk", Pos = ent:GetPos(), Ang = ent:GetAngles() })
        end
        for _, ent in ipairs(ents.FindByClass("factory_npc_blackmarket")) do
            table.insert(saveData.Entities, { Class = "factory_npc_blackmarket", Pos = ent:GetPos(), Ang = ent:GetAngles() })
        end
        for _, ent in ipairs(ents.FindByClass("factory_hack_terminal")) do
            table.insert(saveData.Entities, { Class = "factory_hack_terminal", Pos = ent:GetPos(), Ang = ent:GetAngles() })
        end
        for _, ent in ipairs(ents.FindByClass("factory_robbery_beacon")) do
            table.insert(saveData.Entities, { 
                Class = "factory_robbery_beacon", 
                Pos = ent:GetPos(), 
                Ang = ent:GetAngles(),
                Radius = ent:GetNWInt("ZoneRadius", 250),
                Payout = ent:GetNWInt("TimePayout", 1800),
                Jackpot = ent:GetNWInt("FinalJackpot", 50000)
            })
        end

        file.Write("factory_system_save.txt", util.TableToJSON(saveData))
        
        net.Start("Factory_Desk_SendNotify")
        net.WriteString("Макет и энтити-зоны завода вечно сохранены на карте!")
        net.WriteInt(0, 4)
        net.Send(ply)
    end)

    -- ИСПРАВЛЕНО (ТОТАЛЬНЫЙ СБРОС ТАЙМЕРОВ ИЗ ПАМЯТИ):
    net.Receive("Factory_Admin_ClearMapAction", function(len, ply)
        if not HasFactoryAccess(ply) then return end
        
        -- Стираем все энтити завода
        for _, ent in ipairs(ents.FindByClass("factory_hack_terminal")) do ent:Remove() end
        for _, ent in ipairs(ents.FindByClass("factory_npc_blackmarket")) do ent:Remove() end
        for _, ent in ipairs(ents.FindByClass("factory_assembly_desk")) do ent:Remove() end
        for _, ent in ipairs(ents.FindByClass("factory_robbery_beacon")) do ent:Remove() end
        
        -- ЖЕСТКАЯ ЗАЧИСТКА ОПЕРАТИВНОЙ ПАМЯТИ СЕРВЕРА: Вырезаем зависшие скрытые таймеры выплат!
        timer.Remove("Factory_Global_Robbery_Ticker")
        timer.Remove("Factory_Admin_Highlight_Timeout")
        
        FACTORY_GLOBAL_STATUS = FACTORY_STATUS_NORMAL
        SetGlobalInt("Factory_AssemblyPayoutStatus", FACTORY_GLOBAL_STATUS)
        SetGlobalBool("Factory_IsRobberyActive", false)
        SetGlobalInt("Factory_Countdown", 0)
        file.Delete("factory_system_save.txt")

        net.Start("Factory_Desk_SendNotify")
        net.WriteString("Макет очищен! Все фоновые таймеры выплат завода стёрты.")
        net.WriteInt(3, 4)
        net.Send(ply)
    end)

    net.Receive("Factory_Admin_SaveConfig", function(len, ply)
        if not HasFactoryAccess(ply) then return end
        FACTORY_CONFIG.DeskIncome = net.ReadInt(32)
        FACTORY_CONFIG.DevicePrice = net.ReadInt(32)
        FACTORY_CONFIG.CrippleCoef = net.ReadFloat()
        FACTORY_CONFIG.BoostCoef = net.ReadFloat()
        FACTORY_CONFIG.TerminalCooldown = net.ReadFloat()
        file.Write("factory_global_config.txt", util.TableToJSON(FACTORY_CONFIG))
        SyncFactoryEconomyGlobals()
    end)
end

if CLIENT then
    hook.Add("PopulateToolMenu", "Factory_RegisterAdminUtilMenu", function()
        spawnmenu.AddToolMenuOption("Utilities", "Завод", "Factory_Admin_Settings", "Настройки Экономики", "", "", function(panel)
            if not IsValid(panel) then return end
            panel:ClearControls()
            panel:AddControl("Header", { Text = "Управление Заводом", Description = "Панель Суперадмина" })

            local function AddCompactTextEntry(label, value)
                -- DForm:TextEntry растягивает поле при своей раскладке, поэтому
                -- используем отдельную строку с фиксированной шириной поля.
                local row = vgui.Create("DPanel")
                row:SetTall(22)
                row.Paint = nil

                local caption = vgui.Create("DLabel", row)
                caption:Dock(LEFT)
                caption:SetWide(190)
                caption:SetFont("DermaDefault")
                caption:SetTextColor(Color(0, 0, 0))
                caption:SetText(label)
                caption:SetContentAlignment(4)

                local entry = vgui.Create("DTextEntry", row)
                entry:Dock(RIGHT)
                entry:SetWide(85)
                entry:SetFont("DermaDefault")
                entry:SetText(value)
                panel:AddItem(row)
                return entry
            end

            local income = AddCompactTextEntry("ОПЛАТА ЗА СБОРКУ($)", FACTORY_CONFIG.DeskIncome or 1000)
            local price = AddCompactTextEntry("ЦЕНА ПЕРЕДАТЧИКА ($)", FACTORY_CONFIG.DevicePrice or 25000)
            local cripple = AddCompactTextEntry("-$ БАНДИТЫ 1=100%", FACTORY_CONFIG.CrippleCoef or 0.5)
            local boost = AddCompactTextEntry("+$ ПОЛИЦЕЙСКИЕ 1=100%", FACTORY_CONFIG.BoostCoef or 2.0)
            local cooldown = AddCompactTextEntry("БЛОКИРОВКА ТЕРМИНАЛА (мин)", FACTORY_CONFIG.TerminalCooldown or 20)

            panel:Button("Сохранить настройки экономики").DoClick = function()
                net.Start("Factory_Admin_SaveConfig")
                net.WriteInt(tonumber(income:GetText()) or 1000, 32)
                net.WriteInt(tonumber(price:GetText()) or 25000, 32)
                net.WriteFloat(tonumber(cripple:GetText()) or 0.5)
                net.WriteFloat(tonumber(boost:GetText()) or 2.0)
                net.WriteFloat(tonumber(cooldown:GetText()) or 20)
                net.SendToServer()
            end

            panel:AddControl("Label", { Text = "\nУПРАВЛЕНИЕ МАКЕТОМ КАРТЫ:" }):SetFont("DermaDefaultBold")
            
            local saveMapBtn = panel:Button("СОХРАНИТЬ КОНФИГУРАЦИЮ ЗАВОДА")
            saveMapBtn:SetTextColor(Color(46, 204, 113))
            saveMapBtn.DoClick = function() net.Start("Factory_Admin_SaveMapAction") net.SendToServer() end

            local clearMapBtn = panel:Button("ОЧИСТИТЬ КОНФИГУРАЦИЮ ЗАВОДА")
            clearMapBtn:SetTextColor(Color(231, 76, 60))
            clearMapBtn.DoClick = function() net.Start("Factory_Admin_ClearMapAction") net.SendToServer() end
        end)
    end)
end
