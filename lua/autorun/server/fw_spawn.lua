-- Простая команда для спавна куба
if SERVER then
    concommand.Add("fw_spawn_cube", function(ply, cmd, args)
        -- если вызвана из консоли ply == nil
        if IsValid(ply) and not ply:IsAdmin() then
            ply:ChatPrint("Только админ может спавнить этот энтити.")
            return
        end

        local spawnPos
        if IsValid(ply) then
            spawnPos = ply:GetEyeTrace().HitPos + Vector(0,0,20)
        else
            spawnPos = Vector(0,0,100)
        end

        local ent = ents.Create("fw_workcube")
        if not IsValid(ent) then
            if IsValid(ply) then ply:ChatPrint("Не удалось создать энтити (проверь название).") end
            return
        end
        ent:SetPos(spawnPos)
        ent:Spawn()
        ent:Activate()

        if IsValid(ply) then
            ply:ChatPrint("Спавнено fw_workcube.")
        else
            print("fw_workcube spawned at ", spawnPos)
        end
    end)
end
