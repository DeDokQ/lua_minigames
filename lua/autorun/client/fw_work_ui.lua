-- fw_work_ui.lua (updated: improved CLEAN & REPAIR)
if not CLIENT then return end

local net = net
local vgui = vgui

net.Receive("FW_WorkOpen", function()
    local ent = net.ReadEntity()
    local worktype = net.ReadString() or "trash"
    if not IsValid(ent) then return end

    net.Start("FW_WorkStart")
        net.WriteEntity(ent)
        net.WriteString(worktype)
    net.SendToServer()

    OpenForcedWorkMenu(ent, worktype)
end)

local function sendResult(ent, gamename, success)
    if not IsValid(ent) then return end
    net.Start("FW_WorkComplete")
        net.WriteEntity(ent)
        net.WriteString(gamename)
        net.WriteBool(success)
    net.SendToServer()
end

-- helper: distance
local function dist2(x1,y1,x2,y2)
    return math.sqrt((x1-x2)^2 + (y1-y2)^2)
end

function OpenForcedWorkMenu(ent, worktype)
    if not IsValid(ent) then return end

    local w, h = 900, 600 -- увеличил окно
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Принудительные работы — " .. (worktype == "repair" and "Ремонт" or (worktype == "clean" and "Чистка" or "Уборка")))
    frame:SetSize(w, h)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)

    local content = vgui.Create("DPanel", frame)
    content:SetPos(8, 32)
    content:SetSize(w - 16, h - 40)
    function content:Paint(wt, ht) end

    local resultSent = false
    local function safeSend(gamename, success)
        if resultSent then return end
        resultSent = true
        sendResult(ent, gamename, success)
        if IsValid(frame) then frame:Close() end
    end

    -------------------------------------------------------
    -- CLEAN (оттирание) с кирпичной стеной и "пятнами"
    -------------------------------------------------------
    local function startClean()
        content:Clear()

        local wallPad = 16
        local wall = vgui.Create("DPanel", content)
        wall:SetPos( (content:GetWide()*0.08), 40 )
        wall:SetSize( content:GetWide()*0.84, content:GetTall()*0.8 )
        -- wall:Center() -- уже позиция задана
        function wall:Paint(w, h)
            -- фон стены
            draw.RoundedBox(0, 0, 0, w, h, Color(90, 90, 90, 255))
            -- рисуем кирпичную кладку: простая сетка кирпичей
            local brickW, brickH = 60, 28
            surface.SetDrawColor(120, 50, 40, 255)
            for yy=0, math.floor(h/brickH) do
                for xx=0, math.floor(w/brickW) do
                    local xo = (yy % 2 == 0) and 0 or brickW/2
                    local bx = xx*brickW - xo
                    local by = yy*brickH
                    -- ограничим, чтобы кирпичи рисовались полностью внутри панели
                    if bx + brickW > 0 and bx < w then
                        draw.RoundedBox(4, bx + 6, by + 6, brickW - 10, brickH - 8, Color(140, 70, 50))
                    end
                end
            end
        end

        local timeLimit = 45
        local startTime = SysTime()
        local spotsCount = 6
        local spots = {}

        -- placement area (inside wall content margins)
        local areaX, areaY = wallPad, wallPad
        local areaW, areaH = wall:GetWide() - wallPad*2, wall:GetTall() - wallPad*2

        -- spawn non-overlapping irregular spots (blobs)
        local maxAttempts = 200
        for i=1, spotsCount do
            local attempt = 0
            local placeOk = false
            local s = {}
            s.radius = math.random(36, 70) -- approximate blob size
            while attempt < maxAttempts and not placeOk do
                attempt = attempt + 1
                local cx = math.random(areaX + s.radius, areaX + areaW - s.radius)
                local cy = math.random(areaY + s.radius, areaY + areaH - s.radius)
                local coll = false
                for _,other in ipairs(spots) do
                    if dist2(cx,cy,other.cx,other.cy) < (s.radius + other.radius + 16) then
                        coll = true; break
                    end
                end
                if not coll then
                    s.cx = cx; s.cy = cy; placeOk = true
                end
            end
            if placeOk then
                -- create panel representing spot
                local sp = vgui.Create("DPanel", wall)
                sp:SetSize(s.radius*2, s.radius*2)
                sp:SetPos(s.cx - s.radius, s.cy - s.radius)
                sp.progress = math.random(35, 85)
                sp.holding = false
                sp.lastHold = 0
                -- store random offsets to draw irregular shape
                sp.blobParts = {}
                local parts = math.random(3,5)
                for p=1,parts do
                    -- part relative positions inside panel
                    table.insert(sp.blobParts, {
                        ox = math.random(-s.radius*0.3, s.radius*0.3),
                        oy = math.random(-s.radius*0.3, s.radius*0.3),
                        rw = math.random(math.floor(s.radius*0.6), s.radius),
                        rh = math.random(math.floor(s.radius*0.6), s.radius)
                    })
                end

                function sp:Paint(w, h)
                    -- background darker so blob stands out
                    draw.RoundedBox(0, 0, 0, w, h, Color(0,0,0,0))
                    -- draw blob using several overlapping rounded boxes (circles/ellipses)
                    for _,part in ipairs(self.blobParts) do
                        local px = w/2 + part.ox
                        local py = h/2 + part.oy
                        local pw = part.rw
                        local ph = part.rh
                        local rad = math.min(pw, ph)/2
                        draw.RoundedBox(rad, px - pw/2, py - ph/2, pw, ph, Color(40,40,40,220))
                    end

                    -- redness overlay to indicate remaining 'грязи'
                    local prog = math.Clamp(self.progress, 0, 100)
                    local barH = 10
                    draw.RoundedBox(4, 6, h - 22, w - 12, barH, Color(30,30,30,200))
                    draw.RoundedBox(4, 6, h - 22, (w - 12) * (prog / 100), barH, Color(180,40,40,200))
                    draw.SimpleText(tostring(math.ceil(prog)) .. "%", "DermaDefault", w/2, h - 22, color_white, TEXT_ALIGN_CENTER)
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
                    if selfp.holding then
                        local dt = math.max(0, SysTime() - (selfp.lastHold or SysTime()))
                        selfp.lastHold = SysTime()
                        selfp.progress = math.max(0, selfp.progress - (45 * dt))
                    end
                end

                table.insert(spots, {panel = sp, cx = s.cx, cy = s.cy, radius = s.radius})
            end
        end

        -- Timer label & victory check
        local timerLabel = vgui.Create("DLabel", content)
        timerLabel:SetPos(20, 14)
        timerLabel:SetText("Осталось: "..timeLimit.."s")
        timerLabel:SizeToContents()
        timerLabel.Think = function(selfp)
            local left = math.max(0, math.ceil(timeLimit - (SysTime() - startTime)))
            selfp:SetText("Осталось: "..left.."s")
            -- check all cleaned
            local allClean = true
            for _,s in ipairs(spots) do
                if IsValid(s.panel) and s.panel.progress > 0.5 then
                    allClean = false; break
                end
            end
            if allClean then
                safeSend("clean", true)
                selfp.Think = nil
            elseif left <= 0 then
                safeSend("clean", false)
                selfp.Think = nil
            end
        end
    end

    -------------------------------------------------------
    -- REPAIR (6x4 сетка с пустотами, 3 случайных cracked)
    -------------------------------------------------------
    local function startRepair()
        content:Clear()

        -- Описание сетки (6 columns x 4 rows)
        -- true = brick, false = empty
        local pattern = {
            {false, true,  true,  true,  true,  false}, -- row 1
            {true,  true,  true,  true,  false, false}, -- row 2
            {false, true,  true,  true,  true,  true }, -- row 3
            {false, false, true,  true,  true,  false}  -- row 4
        }
        local cols, rows = 6, 4
        local cellW, cellH = 88, 56
        local gridW = cols * cellW
        local gridH = rows * cellH
        local gridX = (content:GetWide() - gridW) / 2
        local gridY = 48

        local brickButtons = {}
        -- collect available bricks
        local available = {}
        for ry=1, rows do
            for cx=1, cols do
                if pattern[ry][cx] then
                    table.insert(available, {r=ry, c=cx})
                end
            end
        end

        -- select exactly 3 cracked bricks randomly from available
        local crackedIndices = {}
        local neededCracked = math.min(3, #available)
        local idxs = {}
        for i=1,#available do idxs[i] = i end
        for i=1, neededCracked do
            local pick = math.random(1, #idxs)
            local use = table.remove(idxs, pick)
            table.insert(crackedIndices, use)
        end
        -- map cracked set for quick lookup
        local crackedMap = {}
        for _,ci in ipairs(crackedIndices) do
            local pos = available[ci]
            crackedMap[pos.r .. ":" .. pos.c] = true
        end

        local fixedCount = 0
        local gameOver = false

        -- draw grid (create buttons for bricks)
        for ry=1, rows do
            for cx=1, cols do
                local px = gridX + (cx-1)*cellW
                local py = gridY + (ry-1)*cellH
                if pattern[ry][cx] then
                    local btn = vgui.Create("DButton", content)
                    btn:SetPos(px, py)
                    btn:SetSize(cellW - 8, cellH - 8)
                    btn:SetText("")
                    btn.Row = ry
                    btn.Col = cx
                    btn.IsCracked = crackedMap[ry .. ":" .. cx] == true
                    btn.Fixed = false
                    btn.Paint = function(selfp, w, h)
                        if selfp.Fixed then
                            draw.RoundedBox(6, 0, 0, w, h, Color(120,160,120)) -- fixed greenish
                            draw.SimpleText("Исправлен", "DermaDefaultBold", w/2, h/2 - 6, color_white, TEXT_ALIGN_CENTER)
                        else
                            if selfp.IsCracked then
                                draw.RoundedBox(6, 0, 0, w, h, Color(180, 90, 70)) -- cracked color
                                draw.SimpleText("Потреск.", "DermaDefaultBold", w/2, h/2 - 6, color_white, TEXT_ALIGN_CENTER)
                            else
                                draw.RoundedBox(6, 0, 0, w, h, Color(150, 75, 45)) -- normal brick
                                draw.SimpleText("Кирпич", "DermaDefault", w/2, h/2 - 6, color_white, TEXT_ALIGN_CENTER)
                            end
                        end
                    end
                    btn.DoClick = function(selfp)
                        if gameOver then return end
                        if selfp.IsCracked and not selfp.Fixed then
                            selfp.Fixed = true
                            selfp:SetEnabled(false)
                            fixedCount = fixedCount + 1
                            if fixedCount >= neededCracked then
                                gameOver = true
                                -- disable others
                                for _,b in ipairs(brickButtons) do b:SetEnabled(false) end
                                safeSend("repair", true)
                            end
                        else
                            -- clicked not cracked (или уже фиксированный) => потеря
                            gameOver = true
                            for _,b in ipairs(brickButtons) do b:SetEnabled(false) end
                            safeSend("repair", false)
                        end
                    end
                    table.insert(brickButtons, btn)
                else
                    -- optional: draw empty spot visual
                    local place = vgui.Create("DPanel", content)
                    place:SetPos(px, py)
                    place:SetSize(cellW - 8, cellH - 8)
                    place.Paint = function(selfp,w,h)
                        draw.RoundedBox(6, 0, 0, w, h, Color(40,40,40,120))
                    end
                end
            end
        end

        -- small instructions
        local instr = vgui.Create("DLabel", content)
        instr:SetPos(20, 16)
        instr:SetText("Найдите 3 потрескавшихся кирпича. Первый промах = проигрыш.")
        instr:SizeToContents()
    end

    -------------------------------------------------------
    -- TRASH — оставлю прежнюю простую реализацию (без переключателя)
    -------------------------------------------------------
    local function startTrash()
        content:Clear()
        -- простая реализация, как раньше
        local timeLimit = 35
        local needed = 6
        local collected = 0

        local basket = vgui.Create("DPanel", content)
        basket:SetPos(content:GetWide() - 180, 40)
        basket:SetSize(140, content:GetTall() - 80)
        function basket:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(40,40,40,220))
            draw.SimpleText("Корзина", "DermaDefaultBold", w/2, 6, color_white, TEXT_ALIGN_CENTER)
        end

        local items = {}
        local parent = content
        local function clampPos(x,y,wid,hei)
            if x < 0 then x = 0 end
            if y < 30 then y = 30 end
            local maxX = parent:GetWide() - wid - 8
            local maxY = parent:GetTall() - hei - 8
            if x > maxX then x = maxX end
            if y > maxY then y = maxY end
            return x, y
        end

        for i=1,needed do
            local it = vgui.Create("DButton", parent)
            it:SetSize(64,64)
            it:SetText("")
            local sx = math.random(10, parent:GetWide()-300)
            local sy = math.random(40, parent:GetTall()-110)
            it:SetPos(sx, sy)
            it.Color = Color(200, 200, 120)
            it.IsDragging = false
            it.DragOffsetX = 0
            it.DragOffsetY = 0

            it.OnMousePressed = function(selfp, mc)
                if mc == MOUSE_LEFT then
                    local mx, my = input.GetCursorPos()
                    local px, py = parent:ScreenToLocal(mx, my)
                    local ix, iy = selfp:GetPos()
                    selfp.DragOffsetX = px - ix
                    selfp.DragOffsetY = py - iy
                    selfp.IsDragging = true
                    selfp:MouseCapture(true)
                end
            end
            it.OnMouseReleased = function(selfp, mc)
                if mc == MOUSE_LEFT and selfp.IsDragging then
                    selfp.IsDragging = false
                    selfp:MouseCapture(false)
                    local centerX, centerY = selfp:LocalToScreen(selfp:GetWide()*0.5, selfp:GetTall()*0.5)
                    local bx, by = basket:LocalToScreen(0,0)
                    local bw, bh = basket:GetSize()
                    if centerX > bx and centerY > by and centerX < bx + bw and centerY < by + bh then
                        selfp:Remove()
                        collected = collected + 1
                        if collected >= needed then
                            safeSend("trash", true)
                        end
                    end
                end
            end
            it.Think = function(selfp)
                if selfp.IsDragging then
                    local mx, my = input.GetCursorPos()
                    local px, py = parent:ScreenToLocal(mx, my)
                    local nx = px - selfp.DragOffsetX
                    local ny = py - selfp.DragOffsetY
                    nx, ny = clampPos(nx, ny, selfp:GetWide(), selfp:GetTall())
                    selfp:SetPos(nx, ny)
                end
            end

            it.Paint = function(selfp, w, h)
                draw.RoundedBox(6, 0, 0, w, h, selfp.Color)
                draw.SimpleText("Мусор", "DermaDefault", w/2, h/2 - 7, Color(10,10,10), TEXT_ALIGN_CENTER)
            end

            table.insert(items, it)
        end

        local startTime = SysTime()
        local timerThink = vgui.Create("DLabel", content)
        timerThink:SetPos(10, 14)
        timerThink:SetAutoStretchVertical(true)
        timerThink:SetText("Осталось: "..timeLimit.."s | Собрано: "..collected.."/"..needed)
        timerThink.Think = function(selfp)
            local left = math.max(0, math.ceil(timeLimit - (SysTime() - startTime)))
            selfp:SetText("Осталось: "..left.."s | Собрано: "..collected.."/"..needed)
            if left <= 0 then
                for _,it in ipairs(items) do if IsValid(it) then it:Remove() end end
                safeSend("trash", false)
                selfp.Think = nil
            end
        end
    end

    -------------------------------------------------------
    -- storage_sort — оставлю прежнюю простую реализацию (без переключателя)
    -------------------------------------------------------

    -- startSort: сортировка предметов с полок в зоны 1/2/3
    -- Замените существующую функцию startSort() на эту версию
    -- Обновлённая функция startSort() — заменяет старую
    local function startSort()
        content:Clear()

        local instr = vgui.Create("DLabel", content)
        instr:SetPos(20, 12)
        instr:SetText("Отсортируйте предметы: зона 1 = мушкеты, 2 = патроны, 3 = лезвия. Первый неправильный бросок — проигрыш.")
        instr:SizeToContents()

        -- shelf layout: 3 полки сверху (вертикально), снизу зоны 1/2/3
        local shelfW = math.floor(content:GetWide() * 0.6) -- уменьшили ширину полок (центрируем)
        local shelfHeight = 80
        local shelfX = math.floor((content:GetWide() - shelfW) / 2)
        local firstY = 56
        local shelves = {}
        for i=1,3 do
            local sh = vgui.Create("DPanel", content)
            sh:SetPos(shelfX, firstY + (i-1)*(shelfHeight + 12))
            sh:SetSize(shelfW, shelfHeight)
            function sh:Paint(w,h)
                draw.RoundedBox(6, 0, 0, w, h, Color(80,60,40)) -- полка
                draw.SimpleText("Полка "..i, "DermaDefault", 8, 4, color_white)
            end
            shelves[i] = sh
        end

        -- зоны снизу
        local zoneW = 140
        local zoneH = 120
        local gap = 24
        local totalZonesW = zoneW * 3 + gap * 2
        local zoneStartX = math.floor((content:GetWide() - totalZonesW) / 2)
        local zoneY = firstY + 3*(shelfHeight + 12) + 12
        local zones = {}
        local zoneNames = { "1 — Мушкеты", "2 — Патроны", "3 — Лезвия" }
        for i=1,3 do
            local zx = zoneStartX + (i-1)*(zoneW + gap)
            local z = vgui.Create("DPanel", content)
            z:SetPos(zx, zoneY)
            z:SetSize(zoneW, zoneH)
            z.ExpectedType = i -- 1/2/3
            function z:Paint(w,h)
                draw.RoundedBox(6, 0, 0, w, h, Color(60,60,60,230))
                draw.SimpleText(zoneNames[self.ExpectedType], "DermaDefaultBold", w/2, 8, color_white, TEXT_ALIGN_CENTER)
            end
            zones[i] = z
        end

        -- items: 3 типов по 3 штуки = 9 предметов (в рандомном порядке)
        local itemTypes = {
            {type=1, model="models/weapons/w_pistol.mdl"},       -- мушкет / пистолет
            {type=2, model="models/Items/BoxSRounds.mdl"},       -- патроны (упаковка)
            {type=3, model="models/weapons/w_stunbaton.mdl"}     -- лезвие/дубинка
        }

        local pool = {}
        for _,it in ipairs(itemTypes) do
            for k=1,3 do table.insert(pool, {type=it.type, model=it.model}) end
        end
        for i=#pool,2,-1 do local j = math.random(1,i) pool[i],pool[j] = pool[j],pool[i] end
        
        local totalItems = #pool

        -- разместим слоты по центру полки: 3 слота на полку, равномерный отступ
        local slotW = 96
        local slotH = 72
        local slotGap = 24
        local slots = {}
        for shelfIndex, sh in ipairs(shelves) do
            local totalSlotsW = 3 * slotW + 2 * slotGap
            local startX = math.floor((sh:GetWide() - totalSlotsW) / 2)
            for slotIndex = 1, 3 do
                local sx = startX + (slotIndex-1) * (slotW + slotGap)
                local sy = 18
                local slot = vgui.Create("DPanel", sh)
                slot:SetPos(sx, sy)
                slot:SetSize(slotW, slotH)
                slot.Paint = function() end
                slot.used = false
                table.insert(slots, {parent = sh, slot = slot, shelf = shelfIndex})
            end
        end

        local activeItems = {}
        -- создаём визуальные предметы в слотах, по порядку из pool
        for i,slotinfo in ipairs(slots) do
            local poolItem = pool[i]
            if not poolItem then break end

            -- itemPanel как прямой дочерний элемент полки (slotinfo.parent)
            local itemPanel = vgui.Create("DButton", slotinfo.parent)
            local localPos = slotinfo.slot:GetPos() -- позиция внутри shelf
            itemPanel:SetPos(localPos)
            itemPanel:SetSize(slotW, slotH)
            itemPanel:SetText("")
            itemPanel.ItemType = poolItem.type
            itemPanel.Model = poolItem.model
            itemPanel.IsDragging = false
            itemPanel.DragOffsetX = 0
            itemPanel.DragOffsetY = 0
            itemPanel.OrigParent = slotinfo.parent
            slotinfo.used = true
            slotinfo.item = itemPanel

            -- DModelPanel для визуала — отключаем приём мыши у него
            local md = vgui.Create("DModelPanel", itemPanel)
            md:Dock(FILL)
            md:SetModel(itemPanel.Model)
            md.Entity:SetNoDraw(false)
            md:SetMouseInputEnabled(false)
            md:SetKeyboardInputEnabled(false)
            local mn, mx = md.Entity:GetRenderBounds()
            local size = 0
            size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
            md:SetFOV(45)
            md:SetLookAt((mn + mx) * 0.5)
            md:SetCamPos(Vector(size, size, size))

            function itemPanel:Paint(w,h)
                draw.RoundedBox(6, 0, 0, w, h, Color(200,200,200,10))
                surface.SetDrawColor(200,200,200,50)
                surface.DrawOutlinedRect(0,0,w,h)
            end

            -- При захвате: переводим элемент в content и корректно выставляем позицию
            itemPanel.OnMousePressed = function(selfp, mc)
                if mc ~= MOUSE_LEFT then return end
                local mx,my = input.GetCursorPos()
                -- курсор в системе content
                local cursorInContentX, cursorInContentY = content:ScreenToLocal(mx, my)

                -- абсолютная позиция itemPanel (в экранных координатах)
                local absX, absY = selfp:LocalToScreen(0,0)
                -- позиция itemPanel в координатах content
                local relX, relY = content:ScreenToLocal(absX, absY)

                -- переводим в content, выставляем корректную позицию
                selfp:SetParent(content)
                selfp:SetZPos(1000)
                selfp:SetPos(relX, relY)

                -- рассчитываем оффсет: курсор относительно элемента в координатах content
                selfp.DragOffsetX = cursorInContentX - relX
                selfp.DragOffsetY = cursorInContentY - relY
                selfp.IsDragging = true
                selfp:MouseCapture(true)
            end

            itemPanel.OnMouseReleased = function(selfp, mc)
                if mc ~= MOUSE_LEFT then return end
                if not selfp.IsDragging then return end
                selfp.IsDragging = false
                selfp:MouseCapture(false)

                -- проверяем попадание в зону
                local centerX, centerY = selfp:LocalToScreen(selfp:GetWide()*0.5, selfp:GetTall()*0.5)
                for zi, z in ipairs(zones) do
                    local zx, zy = z:LocalToScreen(0,0)
                    local zw, zh = z:GetSize()
                    if centerX > zx and centerY > zy and centerX < zx + zw and centerY < zy + zh then
                        if zi == selfp.ItemType then
                            -- правильная зона: удаляем предмет и уменьшаем счётчик
                            -- пометим слот как свободный (если он был привязан)
                            for _,s in ipairs(slots) do
                                if s.item == selfp then s.item = nil; s.used = false end
                            end

                            selfp:Remove()
                            totalItems = totalItems - 1
                            if totalItems <= 0 then
                                safeSend("sort", true)
                            end
                            return
                        else
                            -- неправильная зона => моментальный провал
                            safeSend("sort", false)
                            return
                        end
                    end
                end

                -- не попал в зону — возвращаем на ближайший свободный слот (или исходный)
                local bestSlot, bestDist
                for _,s in ipairs(slots) do
                    if not s.used then
                        local sx, sy = s.parent:LocalToScreen(s.slot:GetPos())
                        local rx, ry = content:ScreenToLocal(sx, sy)
                        local d = dist2(rx, ry, selfp:GetPos())
                        if not bestDist or d < bestDist then bestDist = d; bestSlot = s end
                    end
                end
                if bestSlot then
                    -- привязать к лучшему слоту
                    selfp:SetParent(bestSlot.parent)
                    selfp:SetPos(bestSlot.slot:GetPos())
                    bestSlot.used = true
                    bestSlot.item = selfp
                else
                    selfp:Remove()
                end
            end

            itemPanel.Think = function(selfp)
                if selfp.IsDragging then
                    local mx,my = input.GetCursorPos()
                    local px,py = content:ScreenToLocal(mx,my)
                    local nx = px - selfp.DragOffsetX
                    local ny = py - selfp.DragOffsetY
                    -- clamp
                    if nx < 0 then nx = 0 end
                    if ny < 30 then ny = 30 end
                    if nx + selfp:GetWide() > content:GetWide() then nx = content:GetWide() - selfp:GetWide() end
                    if ny + selfp:GetTall() > content:GetTall() then ny = content:GetTall() - selfp:GetTall() end
                    selfp:SetPos(nx, ny)
                end
            end

            table.insert(activeItems, itemPanel)
        end
    end


    -- Запускаем нужную игру (каждый куб — своя)
    if worktype == "repair" then
        startRepair()
    elseif worktype == "clean" then
        startClean()
    elseif worktype == "sort" then
        startSort()
    else
        startTrash()
    end
end
