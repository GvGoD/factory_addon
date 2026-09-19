if CLIENT then return end

-- Глобальная изолированная функция запуска тикера выплат
function Factory_StartRobberyTimerLogic()
    -- Намертво уничтожаем любые прошлые зависшие таймеры перед созданием нового
    timer.Remove("Factory_Global_Robbery_Ticker")

    -- Создаем единственный чистый поток, тикающий строго раз в 10 секунд
    timer.Create("Factory_Global_Robbery_Ticker", 10, 0, function()
        if FACTORY_GLOBAL_STATUS ~= 1 then 
            timer.Remove("Factory_Global_Robbery_Ticker")
            return 
        end

        FACTORY_ROBBERY_TIMER = FACTORY_ROBBERY_TIMER - 10
        SetGlobalInt("Factory_Countdown", FACTORY_ROBBERY_TIMER)

        -- Таблица для фиксации выплат строго 1 раз за тик
        local PaidPlayersThisTick = {}

        -- Читаем зоны напрямую из глобальной таблицы памяти сервера
        for id, zone in pairs(FACTORY_GLOBAL_ZONES or {}) do
            if not zone or not zone.Pos then continue end

            local mafiaInZone = {}
            local radius = zone.Radius or 250

            -- Собираем мафиози строго внутри радиуса текущей зоны
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() and FAC_MAFIA_TEAMS[ply:Team()] then
                    if zone.Pos:Distance(ply:GetPos()) <= radius then
                        table.insert(mafiaInZone, ply)
                        
                        -- ИСПРАВЛЕНО (ФИКС СПАМА «ИГРОК ОТКЛЮЧИЛСЯ»):
                        -- Мы убрали nil, вызывавший ложный лог выхода копа с сервера.
                        -- Вызываем ply:wanted() передавая ply в качестве легального свидетеля.
                        -- Строка 0-секундного кулдауна полностью стёрта. Розыск встанет намертво и без флуда в чат!
                        if not ply:getDarkRPVar("wanted") then
                            if isfunction(ply.wanted) then
                                ply:wanted(ply, "Ограбление главного склада завода!")
                            end
                        end
                    end
                end
            end
            -- Выдаем промежуточную долю
            local count = #mafiaInZone
            if count > 0 then
                local share = math.Round((zone.TimePayout or 1800) / count)
                for _, ply in ipairs(mafiaInZone) do
                    -- Защита от дублирования выплат на одном тике
                    if not PaidPlayersThisTick[ply:EntIndex()] then
                        PaidPlayersThisTick[ply:EntIndex()] = true
                        
                        if ply.addMoney then ply:addMoney(share) end
                        
                        net.Start("Factory_Desk_SendNotify")
                        net.WriteString("Доля со взлома: +" .. share .. "$")
                        net.WriteInt(0, 4)
                        net.WriteString("popup/money.wav")
                        net.Send(ply)
                    end
                end
            end

            -- Выдача финального куша при завершении налета
            if FACTORY_ROBBERY_TIMER <= 0 and count > 0 then
                local finalShare = math.Round((zone.Jackpot or 50000) / count)
                for _, ply in ipairs(mafiaInZone) do
                    if ply.addMoney then ply:addMoney(finalShare) end
                    net.Start("Factory_Desk_SendNotify")
                    net.WriteString("СКЛАД УСПЕШНО ОПУСТОШЕН: +" .. finalShare .. "$!")
                    net.WriteInt(0, 4)
                    net.Send(ply)
                end
            end
        end

        -- ПОЛНОЕ УСПЕШНОЕ ЗАВЕРШЕНИЕ ОГРАБЛЕНИЯ (5 минут истекли)
        if FACTORY_ROBBERY_TIMER <= 0 then
            FACTORY_GLOBAL_STATUS = 2 
            SetGlobalInt("Factory_AssemblyPayoutStatus", FACTORY_GLOBAL_STATUS)
            timer.Remove("Factory_Global_Robbery_Ticker")
            SetGlobalBool("Factory_IsRobberyActive", false)

            for _, term in ipairs(ents.FindByClass("factory_hack_terminal")) do
                if isfunction(term.StartTerminalCooldown) then term:StartTerminalCooldown() end
            end

            for _, desk in ipairs(ents.FindByClass("factory_assembly_desk")) do
                if desk:GetAssemblyStage() == 5 then desk:ResetDesk() end
            end

            for _, p in ipairs(player.GetAll()) do
                net.Start("Factory_Desk_SendNotify")
                net.WriteString("Склады полностью обнесены! Доход столов завода урезан на х" .. FACTORY_CONFIG.CrippleCoef)
                net.WriteInt(1, 4)
                net.Send(p)
            end

            timer.Simple(300, function()
                FACTORY_GLOBAL_STATUS = 0
                SetGlobalInt("Factory_AssemblyPayoutStatus", FACTORY_GLOBAL_STATUS)
            end)
        end
    end)
end
