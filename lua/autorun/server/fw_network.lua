-- Регистрация сетевых сообщений (делаем на сервере один раз)
if SERVER then
    util.AddNetworkString("FW_WorkOpen")      -- сервер -> клиент: открыть UI
    util.AddNetworkString("FW_WorkStart")     -- клиент -> сервер: игрок начал мини-игру
    util.AddNetworkString("FW_WorkComplete")  -- клиент -> сервер: игрок завершил (успех/провал)
end
