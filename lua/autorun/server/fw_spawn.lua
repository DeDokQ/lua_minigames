if SERVER then
    local function SpawnForType(ply, typ)
        if IsValid(ply) and not ply:IsAdmin() then
            ply:ChatPrint("Только админ может спавнить энтити.")
            return
        end

        local spawnPos
        if IsValid(ply) then
            spawnPos = ply:GetEyeTrace().HitPos + Vector(0,0,20)
        else
            spawnPos = Vector(0,0,100)
        end

        local class = typ == "repair" and "fw_repaircube"
                   or typ == "clean"  and "fw_cleanercube"
                   or typ == "sort" and "fw_sortcube"
                   or "fw_trashcube"

        local ent = ents.Create(class)
        if not IsValid(ent) then
            if IsValid(ply) then ply:ChatPrint("Не удалось создать "..class) end
            return
        end

        ent:SetPos(spawnPos)
        ent:Spawn()
        ent:Activate()
        if IsValid(ply) then ply:ChatPrint(class.." создан.") else print(class.." spawned at", spawnPos) end
    end

    concommand.Add("fw_spawn_trash", function(ply) SpawnForType(ply, "trash") end)
    concommand.Add("fw_spawn_repair", function(ply) SpawnForType(ply, "repair") end)
    concommand.Add("fw_spawn_clean", function(ply) SpawnForType(ply, "clean") end)
    concommand.Add("fw_spawn_sort", function(ply) SpawnForType(ply, "sort") end)
    concommand.Add("fw_spawn_sort", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("Только админ может спавнить энтити.")
        return
    end
    local spawnPos
    if IsValid(ply) then
        spawnPos = ply:GetEyeTrace().HitPos + Vector(0,0,20)
    else
        spawnPos = Vector(0,0,100)
    end
    local ent = ents.Create("fw_sortcube")
    if not IsValid(ent) then
        if IsValid(ply) then ply:ChatPrint("Не удалось создать fw_sortcube") end
        return
    end
    ent:SetPos(spawnPos)
    ent:Spawn()
    ent:Activate()
    if IsValid(ply) then ply:ChatPrint("fw_sortcube создан.") else print("fw_sortcube spawned at", spawnPos) end
    end)


    
end

