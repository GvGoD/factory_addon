include("shared.lua")

function ENT:Draw()
    -- Нативно рисуем модель торговца со всеми правильными тенями сервера
    self:DrawModel()
end
