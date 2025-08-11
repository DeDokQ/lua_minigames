AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local startedPlayers = startedPlayers or {}

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
    self:SetUseType(SIMPLE_USE)
    self.WorkType = "sort"
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    net.Start("FW_WorkOpen")
        net.WriteEntity(self)
        net.WriteString(self.WorkType)
    net.Send(activator)
end

-- сетевые обработчики (серверная часть)
if SERVER then
    net.Receive("FW_WorkStart", function(len, ply)
        local ent = net.ReadEntity()
        local gamename = net.ReadString()
        if not IsValid(ent) or not ent.WorkType then return end
        -- сохраняем начало
        startedPlayers[ply:SteamID()] = { ent = ent, time = CurTime(), gamename = gamename }
    end)

    net.Receive("FW_WorkComplete", function(len, ply)
        local ent = net.ReadEntity()
        local gamename = net.ReadString()
        local success = net.ReadBool()

        local rec = startedPlayers[ply:SteamID()]
        local valid = false
        if rec and IsValid(rec.ent) and rec.ent == ent and rec.gamename == gamename and CurTime() - rec.time < 120 then
            valid = true
        end
        if valid then
            local dist = ply:GetPos():Distance(ent:GetPos())
            if dist > 300 then valid = false end
        end

        if not valid then
            ply:ChatPrint("Невалидное завершение мини-игры.")
            startedPlayers[ply:SteamID()] = nil
            return
        end

        if success then
            ply:ChatPrint("Ты победил! (мини-игра: " .. gamename .. ")")
            hook.Run("FW_OnWorkCompleted", ply, gamename)
        else
            ply:ChatPrint("Вы проиграли. Попробуйте ещё раз.")
        end

        startedPlayers[ply:SteamID()] = nil
    end)
end
