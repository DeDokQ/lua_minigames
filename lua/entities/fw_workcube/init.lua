AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Таблица для проверки кто начал игру (по steamid)
local startedPlayers = {}

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
    self:SetUseType(SIMPLE_USE)
end

-- При использовании энтити: отправляем клиенту открыть UI и регистрируем старт (в обработчике FW_WorkStart будет явное подтверждение старта)
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- отправляем клиенту событие открыть UI (клиент создаёт интерфейс)
    net.Start("FW_WorkOpen")
        net.WriteEntity(self)
    net.Send(activator)
end

-- Серверная обработка начала и завершения -- реализована в одном файле, но требует доступности net-сообщений
-- Обработчики net.Receive регистрируются глобально, но делаем это здесь, чтобы логика рядом с энтити
if SERVER then
    -- когда клиент нажал "Открыть" и начал игру - регистрируем старт
    net.Receive("FW_WorkStart", function(len, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) or ent:GetClass() ~= "fw_workcube" then return end

        local sid = ply:SteamID()
        startedPlayers[sid] = {
            ent = ent,
            time = CurTime()
        }
        -- можно логировать: print(ply, "started work on", ent)
    end)

    -- получение результата от клиента
    net.Receive("FW_WorkComplete", function(len, ply)
        local ent = net.ReadEntity()
        local gamename = net.ReadString()
        local success = net.ReadBool()

        local sid = ply:SteamID()
        local record = startedPlayers[sid]

        -- базовая валидация: существовал старт и ent совпадает и время не превысило 120 с.
        local valid = false
        if record and IsValid(record.ent) and record.ent == ent and CurTime() - record.time < 120 then
            valid = true
        end

        -- дополнительно проверяем расстояние между игроком и энтити (не более 300 юнитов)
        if valid then
            local dist = ply:GetPos():Distance(ent:GetPos())
            if dist > 300 then valid = false end
        end

        if not valid then
            ply:ChatPrint("Невалидное завершение мини-игры (провал проверки).")
            startedPlayers[sid] = nil
            return
        end

        -- Успех => выдаём награду-заглушку, вызываем хук
        if success then
            ply:ChatPrint("Ты победил! (мини-игра: " .. gamename .. ")")
            hook.Run("FW_OnWorkCompleted", ply, gamename)
        else
            ply:ChatPrint("Вы проиграли. Попробуйте ещё раз.")
        end

        startedPlayers[sid] = nil
    end)
end
