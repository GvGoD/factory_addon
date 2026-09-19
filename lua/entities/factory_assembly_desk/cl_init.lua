include("shared.lua")

local ButtonCombinations = {
    [1] = {1, 2, 3},
    [2] = {1, 3, 2},
    [3] = {2, 1, 3},
    [4] = {2, 3, 1},
    [5] = {3, 1, 2},
    [6] = {3, 2, 1}
}

local DeskCurrentLayout = {}

net.Receive("Factory_Desk_SyncCycle", function()
    local ent = net.ReadEntity()
    if IsValid(ent) then
        local randomIndex = math.random(1, 6)
        DeskCurrentLayout[ent:EntIndex()] = ButtonCombinations[randomIndex]
    end
end)

local function DrawOnyxText(text, font, x, y, color)
    draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 240), TEXT_ALIGN_CENTER)
    draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_CENTER)
end

local function GetComponentData(id, ent)
    if id == 1 then 
        return "Материнская плата", ent:GetHasMotherboard()
    elseif id == 2 then 
        return "Процессор", ent:GetHasCPU()
    elseif id == 3 then 
        return "Видеокарта", ent:GetHasGPU()
    end
    return "Неизвестно", false
end

function ENT:Draw()
    self:DrawModel() 
end

hook.Add("PostDrawTranslucentRenderables", "Factory_AssemblyDesk_GlobalRender", function()
    local localPly = LocalPlayer()
    if not IsValid(localPly) then return end

    for _, self in ipairs(ents.FindByClass("factory_assembly_desk")) do
        if not IsValid(self) or not self.GetAssemblyStage then continue end

        local stage = self:GetAssemblyStage()
        local worker = self:GetWorker()

        local panelPos = self:LocalToWorld(Vector(-18, -4, 24.2))
        local panelAng = self:LocalToWorldAngles(Angle(0, -90, 15)) 

        cam.Start3D2D(panelPos, panelAng, 0.08)
            
            if stage == 0 then
                local boxW, boxH = 360, 70
                local boxX, boxY = -(boxW / 2), -35
                draw.RoundedBox(6, boxX, boxY, boxW, boxH, Color(46, 204, 113, 180))
                draw.SimpleText("ЗАНЯТЬ РАБОЧЕЕ МЕСТО", "DermaDefaultBold", 0, -8, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                draw.SimpleText("Нажмите [ E ] для начала сборки ПК", "DermaDefault", 0, 12, Color(240, 240, 240, 180), TEXT_ALIGN_CENTER)

            elseif IsValid(worker) then
                
                if worker == localPly then
                    if stage == 5 or FACTORY_GLOBAL_STATUS == FACTORY_STATUS_HACKING then
                    -- ЗАВОД ОБЕСТОЧЕН СИНДИКАТОМ
                    draw.RoundedBox(6, -200, -35, 400, 70, Color(192, 57, 43, 230)) -- Кроваво-красный фон Onyx
                    draw.SimpleText("ЗАВОД ЗАБЛОКИРОВАН СИНДИКАТОМ!", "DermaDefaultBold", 0, -10, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                    draw.SimpleText("Системы обесточены. Ожидайте зачистки склада полицией...", "DermaDefault", 0, 12, Color(255, 255, 255, 160), TEXT_ALIGN_CENTER)
                    elseif stage == 4 then
                        draw.RoundedBox(6, -200, -35, 400, 70, Color(39, 174, 96, 220))
                        draw.SimpleText("КОМПЬЮТЕР ГОТОВ К СДАЧЕ!", "DermaDefaultBold", 0, -10, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                        draw.SimpleText("Зачисление 1000$ и подготовка нового корпуса...", "DermaDefault", 0, 12, Color(255, 255, 255, 180), TEXT_ALIGN_CENTER)
                    else
                        local shootPos = localPly:GetShootPos()
                        local aimVector = localPly:GetAimVector()
                        local planeNormal = panelAng:Up()
                        local hitPos3D = util.IntersectRayWithPlane(shootPos, aimVector, panelPos, planeNormal)
                        
                        local cursorX, cursorY = 0, 0
                        local isHoveringPanel = false

                        if hitPos3D then
                            local diff = hitPos3D - panelPos
                            cursorX = diff:Dot(panelAng:Forward()) / 0.08
                            cursorY = diff:Dot(panelAng:Right()) / 0.08
                            
                            if cursorX >= -250 and cursorX <= 250 and cursorY >= -60 and cursorY <= 60 then
                                isHoveringPanel = true
                            end
                        end

                        local neededParts = {}
                        if not self:GetHasMotherboard() then table.insert(neededParts, "Материнку") end
                        if not self:GetHasCPU() then table.insert(neededParts, "Процессор") end
                        if not self:GetHasGPU() then table.insert(neededParts, "Видеокарту") end
                        
                        local taskText = "Осталось вставить: " .. table.concat(neededParts, ", ")
                        DrawOnyxText(taskText, "OnyxDetectiveFont", 0, -70, Color(241, 196, 15))

                        local btnW, btnH = 140, 65
                        local startX = -230 
                        local buttonNames = { "Материнская плата", "Процессор", "Видеокарта" }

                        local layout = DeskCurrentLayout[self:EntIndex()] or {1, 2, 3}

                        for i = 1, 3 do
                            local compID = layout[i]
                            local bX = startX + (i - 1) * 160 
                            local bY = -32

                            local isInstalled = (compID == 1 and self:GetHasMotherboard()) or (compID == 2 and self:GetHasCPU()) or (compID == 3 and self:GetHasGPU())
                            local isHovered = isHoveringPanel and not isInstalled and (cursorX >= bX and cursorX <= bX + btnW and cursorY >= bY and cursorY <= bY + btnH)

                            local boxColor = Color(41, 128, 185, 220) 
                            if isInstalled then
                                boxColor = Color(127, 140, 141, 60) 
                            elseif isHovered then
                                boxColor = Color(52, 152, 219, 255) 
                                
                                self.HoveredComponentID = compID
                            end

                            if not isHovered and self.HoveredComponentID == compID then
                                self.HoveredComponentID = nil
                            end

                            draw.RoundedBox(4, bX, bY, btnW, btnH, boxColor)

                            if isInstalled then
                                draw.SimpleText("ВСТАВЛЕНО", "OnyxDetectiveFont", bX + btnW/2, bY + btnH/2 - 2, Color(255, 255, 255, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                            else
                                draw.SimpleText(buttonNames[compID], "DermaDefaultBold", bX + btnW/2, bY + btnH/2 - 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                            end
                        end
                    end
                else
                    local boxW = 340
                    local boxH = 70
                    local boxX = -(boxW / 2)
                    local boxY = -35
                    draw.RoundedBox(6, boxX, boxY, boxW, boxH, Color(24, 24, 24, 240))
                    surface.SetDrawColor(231, 76, 60, 255)
                    surface.DrawRect(boxX, boxY, boxW, 4)

                    draw.SimpleText("СТОЛ ЗАНЯТ ИНЖЕНЕРОМ", "OnyxDetectiveFont", 0, -10, Color(231, 76, 60), TEXT_ALIGN_CENTER)
                    draw.SimpleText(worker:Name() .. " собирает компьютер", "DermaDefault", 0, 12, Color(200, 200, 200), TEXT_ALIGN_CENTER)
                end
            end

        cam.End3D2D()
    end
end)

-- ИСПРАВЛЕНО (ЗАЩИТА ДЛЯ МУЛЬТИПЛЕЕРА):
-- Перехватываем нажатие кнопки строго на клиенте и ставим жесткий тайм-блок на повторный клик
hook.Add("PlayerButtonDown", "Factory_AssemblyDesk_SingleClick", function(ply, button)
    if button ~= KEY_E or ply ~= LocalPlayer() then return end
    if not CLIENT then return end -- Полная изоляция от выполнения серверным Lua-потоком хука

    -- ЗАЩИТА 1: Локальный анти-спам таймер (Блокировка мульти-кликов в мультиплеере)
    if ply.Factory_ClickBlock and ply.Factory_ClickBlock > CurTime() then return end

    for _, desk in ipairs(ents.FindByClass("factory_assembly_desk")) do
        if IsValid(desk) and desk:GetWorker() == ply then
            local currentStage = desk:GetAssemblyStage()
            
            if currentStage >= 1 and currentStage <= 3 then
                local targetCompID = desk.HoveredComponentID
                
                if targetCompID then
                    -- Ставим блок на клики на 0.4 секунды для пинга мультиплеера
                    ply.Factory_ClickBlock = CurTime() + 0.4
                    surface.PlaySound("buttons/blip1.wav") 
                    
                    net.Start("Factory_Desk_ClickButton")
                    net.WriteEntity(desk)
                    net.WriteInt(targetCompID, 4) 
                    net.SendToServer()
                    
                    break 
                end
            end
        end
    end
end)

net.Receive("Factory_Desk_SendNotify", function()
    local text = net.ReadString() or ""
    local typeID = net.ReadInt(4) or 0
    local soundPath = net.ReadString() or ""

    if notification and notification.AddLegacy then
        notification.AddLegacy(text, typeID, 5)
    end
    if soundPath ~= "" then
        surface.PlaySound(soundPath)
    end
end)

hook.Add("EntityRemoved", "Factory_AssemblyDesk_CleanCache", function(ent)
    if IsValid(ent) and ent:GetClass() == "factory_assembly_desk" then
        DeskCurrentLayout[ent:EntIndex()] = nil
    end
end)
