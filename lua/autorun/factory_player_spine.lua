if SERVER then
    AddCSLuaFile()
    return
end

local SpineModels = SpineModels or {}

hook.Add("PostPlayerDraw", "Factory_Render_SpineDevice", function(ply)
    -- ИСПРАВЛЕНО (ФИКС КРАША): Заменили невалидный :NoDraw() на эталонный :GetNoDraw()
    if not IsValid(ply) or not ply:Alive() or ply:GetNoDraw() then return end

    if ply:GetNWBool("Factory_HasTransponder", false) then
        local modelIndex = ply:EntIndex()
        
        if not IsValid(SpineModels[modelIndex]) then
            SpineModels[modelIndex] = ClientsideModel("models/props_citizen_tech/transponder.mdl", RENDERGROUP_OPAQUE)
            if IsValid(SpineModels[modelIndex]) then
                SpineModels[modelIndex]:SetNoDraw(true)
                SpineModels[modelIndex]:SetModelScale(0.55, 0)
            end
        end

        local trans = SpineModels[modelIndex]
        if not IsValid(trans) then return end

        local boneIndex = ply:LookupBone("ValveBiped.Bip01_Spine2")
        if not boneIndex then return end

        local matrix = ply:GetBoneMatrix(boneIndex)
        if not matrix then return end

        local bonePos = matrix:GetTranslation()
        local boneAng = matrix:GetAngles()

        -- Смещаем устройство к лопаткам, а не к поясу. Смещение считаем до
        -- поворота модели, чтобы оно всегда оставалось на спине игрока.
        local offset = boneAng:Forward() * -7 + boneAng:Up() * 8

        local transAng = Angle(boneAng)
        transAng:RotateAroundAxis(transAng:Forward(), 90)
        transAng:RotateAroundAxis(transAng:Right(), 270)

        trans:SetPos(bonePos + offset)
        trans:SetAngles(transAng)
        trans:SetModelScale(0.55, 0)
        trans:SetupBones()
        trans:DrawModel()
    else
        if IsValid(SpineModels[ply:EntIndex()]) then
            SpineModels[ply:EntIndex()]:Remove()
            SpineModels[ply:EntIndex()] = nil
        end
    end
end)

hook.Add("EntityRemoved", "Factory_CleanSpineModels", function(ent)
    if ent:IsPlayer() and IsValid(SpineModels[ent:EntIndex()]) then
        SpineModels[ent:EntIndex()]:Remove()
        SpineModels[ent:EntIndex()] = nil
    end
end)
