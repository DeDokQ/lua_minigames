-- регистрируем сетевые сообщения и отправляем клиентский UI (на всякий случай)
if SERVER then
    util.AddNetworkString("FW_WorkOpen")
    util.AddNetworkString("FW_WorkStart")
    util.AddNetworkString("FW_WorkComplete")

    -- убедимся, что клиентский UI будет отдан клиенту при подключении
    AddCSLuaFile("autorun/client/fw_work_ui.lua")
end
