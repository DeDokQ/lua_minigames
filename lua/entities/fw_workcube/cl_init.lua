include("shared.lua")
local vgui = vgui

-- Когда сервер просит открыть UI
net.Receive("FW_WorkOpen", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    -- отправляем серверу, что мы начали (для валидации)
    net.Start("FW_WorkStart")
        net.WriteEntity(ent)
    net.SendToServer()

    -- открываем меню
    OpenForcedWorkMenu(ent)
end)

-- ====== UI и логика мини-игр ======

function OpenForcedWorkMenu(ent)
    if not IsValid(ent) then return end

    -- главное окно
    local w, h = 700, 420
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Принудительные работы — мини-игры")
    frame:SetSize(w, h)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)

    local leftW = 180
    local side = vgui.Create("DPanel", frame)
    side:SetPos(8, 32)
    side:SetSize(leftW, h - 40)
    function side:Paint(wt, ht) end

    local content = vgui.Create("DPanel", frame)
    content:SetPos(leftW + 16, 32)
    content:SetSize(w - leftW - 24, h - 40)
    function content:Paint(wt, ht) end

    -- Кнопки выбора мини-игр
    local btns = {}
    local function addButton(text, onClick)
        local b = vgui.Create("DButton", side)
        b:Dock(TOP)
        b:DockMargin(0, 0, 0, 6)
        b:SetTall(40)
        b:SetText(text)
        b.DoClick = function()
            for _,v in pairs(btns) do v:SetEnabled(true) end
            b:SetEnabled(false)
            onClick()
        end
        table.insert(btns, b)
        return b
    end

    -- вспомогательная функция для отправки результата на сервер
    local function sendResult(success, gamename)
        net.Start("FW_WorkComplete")
            net.WriteEntity(ent)
            net.WriteString(gamename)
            net.WriteBool(success)
        net.SendToServer()
        frame:Close()
    end

    -- 1) Уборка мусора — Drag&Drop
    local function startTrash()
        content:Clear()

        local timerLabel = vgui.Create("DLabel", content)
        timerLabel:SetPos(10, 4)
        timerLabel:SetText("Время:")
        timerLabel:SizeToContents()

        local timeLimit = 35
        local needed = 6
        local collected = 0

        local basket = vgui.Create("DPanel", content)
        basket:SetPos(content:GetWide() - 140, 40)
        basket:SetSize(120, content:GetTall() - 60)
        function basket:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(40,40,40,200))
            draw.SimpleText("Корзина", "DermaDefaultBold", w/2, 6, color_white, TEXT_ALIGN_CENTER)
        end

        local items = {}
        local function placeItems()
            for i=1,needed do
                local it = vgui.Create("DButton", content)
                it:SetSize(64,64)
                it:SetText("")
                it:SetPos(10 + math.random(0, content:GetWide()-220), 40 + math.random(30, content:GetTall()-110))
                it.Color = Color(200, 200, 120)
                it.IsDragging = false
                it.Think = function(selfp)
                    if selfp.IsDragging then
                        local mx, my = input.GetCursorPos()
                        local px, py = frame:LocalToScreen(0,0)
                        selfp:SetPos(mx - px - selfp:GetWide()/2, my - py - selfp:GetTall()/2)
                    end
                end
                it.DoRightClick = nil
                it.OnMousePressed = function(selfp, mc)
                    if mc == MOUSE_LEFT then
                        selfp.IsDragging = true
                        selfp:MouseCapture(true)
                    end
                end
                it.OnMouseReleased = function(selfp, mc)
                    if mc == MOUSE_LEFT then
                        selfp.IsDragging = false
                        selfp:MouseCapture(false)
                        -- проверка попадания в корзину
                        local bx, by = basket:LocalToScreen(0,0)
                        local bw, bh = basket:GetSize()
                        local ix, iy = selfp:LocalToScreen(0,0)
                        if ix > bx and iy > by and ix < bx + bw and iy < by + bh then
                            selfp:Remove()
                            collected = collected + 1
                            if collected >= needed then
                                sendResult(true, "trash")
                            end
                        end
                    end
                end
                it.Paint = function(selfp, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, selfp.Color)
                    draw.SimpleText("Мусор", "DermaDefault", w/2, h/2 - 7, Color(10,10,10), TEXT_ALIGN_CENTER)
                end
                table.insert(items, it)
            end
        end

        placeItems()

        -- Таймер отображение
        local startTime = SysTime()
        local timerThink = vgui.Create("DLabel", content)
        timerThink:SetPos(10, 14)
        timerThink:SetAutoStretchVertical(true)
        timerThink:SetText("Осталось: "..timeLimit.."s")
        timerThink.Think = function(selfp)
            local left = math.max(0, math.ceil(timeLimit - (SysTime() - startTime)))
            selfp:SetText("Осталось: "..left.."s | Собрано: "..collected.."/"..needed)
            if left <= 0 then
                -- очистка всех item-ов
                for _,it in ipairs(items) do if IsValid(it) then it:Remove() end end
                sendResult(false, "trash")
                selfp.Think = nil
            end
        end
    end

    -- 2) Ремонт — кирпичи (по твоему сценарию)
    local function startRepair()
        content:Clear()
        local instructions = vgui.Create("DLabel", content)
        instructions:SetPos(10, 6)
        instructions:SetText("Нажми на потрескавшийся кирпич 3 раза. Первый промах — проигрыш.")
        instructions:SizeToContents()

        local positions = {
            {x=40, y=60},
            {x=180, y=60},
            {x=40, y=160},
            {x=180, y=160}
        }

        local brickPanels = {}
        local crackedIndex = math.random(1,4)
        local successCount = 0
        local gameOver = false

        local function shuffleBricks()
            -- меняем порядок (переставляем позиции)
            local order = {1,2,3,4}
            for i=1,8 do
                local a = math.random(1,4)
                local b = math.random(1,4)
                order[a], order[b] = order[b], order[a]
            end
            for i,pan in ipairs(brickPanels) do
                local pos = positions[ order[i] ]
                pan:SetPos(pos.x, pos.y)
            end
        end

        for i=1,4 do
            local pan = vgui.Create("DButton", content)
            pan:SetSize(120, 60)
            pan:SetPos(positions[i].x, positions[i].y)
            pan:SetText("")
            pan.Index = i
            pan.Paint = function(selfp, w, h)
                local col = Color(150, 75, 0)
                if selfp.Index == crackedIndex then
                    draw.RoundedBox(6, 0, 0, w, h, Color(180, 80, 60))
                    draw.SimpleText("Потреск.", "DermaDefaultBold", w/2, h/2 - 6, color_white, TEXT_ALIGN_CENTER)
                else
                    draw.RoundedBox(6, 0, 0, w, h, col)
                    draw.SimpleText("Кирпич", "DermaDefault", w/2, h/2 - 6, color_white, TEXT_ALIGN_CENTER)
                end
            end

            pan.DoClick = function(selfp)
                if gameOver then return end
                if selfp.Index == crackedIndex then
                    successCount = successCount + 1
                    if successCount >= 1 then
                        -- после первого правильного клика — перемешиваем
                        shuffleBricks()
                    end
                    if successCount >= 3 then
                        gameOver = true
                        sendResult(true, "repair")
                    end
                else
                    gameOver = true
                    sendResult(false, "repair")
                end
            end

            table.insert(brickPanels, pan)
        end
    end

    -- 3) Чистка — Click & Hold
    local function startClean()
        content:Clear()

        local instructions = vgui.Create("DLabel", content)
        instructions:SetPos(10, 6)
        instructions:SetText("Очистите все пятна. Удерживайте для быстрой очистки или кликайте.")
        instructions:SizeToContents()

        local spotsCount = 5
        local spots = {}
        local timeLimit = 40
        local startTime = SysTime()

        for i=1,spotsCount do
            local sp = vgui.Create("DPanel", content)
            local pw = 100
            local ph = 100
            local margin = 12
            local cols = 3
            local cx = (i-1) % cols
            local cy = math.floor((i-1) / cols)
            local x = 20 + cx*(pw + margin)
            local y = 50 + cy*(ph + margin)
            sp:SetPos(x, y)
            sp:SetSize(pw, ph)
            sp.progress = math.random(30, 80) -- сколько процентов грязи осталось
            sp.holding = false
            sp.lastHold = 0

            function sp:Paint(w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(60,60,60,200))
                draw.SimpleText("Пятно", "DermaDefaultBold", w/2, 6, color_white, TEXT_ALIGN_CENTER)
                -- индикатор грязи
                local barh = math.Clamp(self.progress, 0, 100)
                draw.RoundedBox(4, 8, h - 22, w - 16, 12, Color(30,30,30,200))
                draw.RoundedBox(4, 8, h - 22, (w - 16) * (barh / 100), 12, Color(180,40,40))
                draw.SimpleText(tostring(math.ceil(barh)) .. "%", "DermaDefault", w/2, h - 22, color_white, TEXT_ALIGN_CENTER)
            end

            function sp:OnMousePressed(mc)
                if mc == MOUSE_LEFT then
                    self.holding = true
                    self.lastHold = SysTime()
                end
            end
            function sp:OnMouseReleased(mc)
                if mc == MOUSE_LEFT then
                    self.holding = false
                end
            end

            sp.Think = function(selfp)
                -- Если держим мышь — уменьшаем прогресс быстрее
                if selfp.holding then
                    local dt = math.max(0, SysTime() - (selfp.lastHold or SysTime()))
                    selfp.lastHold = SysTime()
                    -- за секунду удержания уменьшим на 40%
                    selfp.progress = math.max(0, selfp.progress - (40 * dt))
                    -- также даём маленькое снижение при кликах (имитация быстрых кликов)
                end
            end

            table.insert(spots, sp)
        end

        -- глобальный таймер по интерфейсу
        local timerLabel = vgui.Create("DLabel", content)
        timerLabel:SetPos(10, 14)
        timerLabel:SetText("Осталось: "..timeLimit.."s")
        timerLabel.Think = function(selfp)
            local left = math.max(0, math.ceil(timeLimit - (SysTime() - startTime)))
            selfp:SetText("Осталось: "..left.."s")
            -- проверка победы
            local allClean = true
            for _,s in ipairs(spots) do
                if IsValid(s) and s.progress > 0.5 then
                    allClean = false
                    break
                end
            end
            if allClean then
                sendResult(true, "clean")
                selfp.Think = nil
            elseif left <= 0 then
                sendResult(false, "clean")
                selfp.Think = nil
            end
        end
    end

    -- Добавляем кнопки
    addButton("Уборка мусора", startTrash)
    addButton("Ремонт (кирпичи)", startRepair)
    addButton("Чистка (Click & Hold)", startClean)

    -- включим первую по умолчанию
    btns[1]:DoClick()
end
