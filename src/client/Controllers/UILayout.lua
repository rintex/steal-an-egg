--!strict
-- Pure presentation rules, also exercised by the standalone Luau tests.
local Layout = {}
function Layout.measure(width: number, height: number)
    local w, h = math.max(240, width), math.max(200, height)
    local portrait = w < 620 and h > w
    local short = h < 520
    local margin = if w < 360 or short then 8 else 16
    local panelW = math.min(940, w - margin * 2)
    local panelH = math.min(650, h - margin * 2)
    local sideNav = panelW >= 720
    local navW = if sideNav then 164 else 0
    local bodyW = panelW - navW - 32
    local bodyH = panelH - (if sideNav then 96 else 154)
    local columns = if bodyW >= 720 then 3 elseif bodyW >= 480 then 2 else 1
    return {
        Width = w, Height = h, Margin = margin, Portrait = portrait, Short = short,
        PanelWidth = panelW, PanelHeight = panelH, SideNav = sideNav, NavWidth = navW,
        BodyWidth = bodyW, BodyHeight = bodyH, Columns = columns,
        CardWidth = math.floor((bodyW - 10 - (columns - 1) * 12) / columns),
        CardHeight = if columns == 1 then 166 else 242,
        TopWidth = if portrait then w - margin * 2 else math.min(366, w * 0.52),
        EventWidth = if portrait then w - margin * 2 else math.min(278, w * 0.34),
        ObjectiveWidth = if portrait then w - margin * 2 else math.min(380, w * 0.48),
    }
end
function Layout.clock(seconds: number): string
    local n = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(n / 60), n % 60)
end
function Layout.number(n: number): string
    local value = tostring(math.floor(n))
    repeat
        local result, count = string.gsub(value, "^(%-?%d+)(%d%d%d)", "%1 %2")
        value = result
        if count == 0 then break end
    until false
    return value
end
function Layout.fold(value: string): string
    local result = {}
    for _, cp in utf8.codes(string.lower(value)) do
        if cp >= 1040 and cp <= 1071 then cp += 32 elseif cp == 1025 then cp = 1105 end
        table.insert(result, utf8.char(cp))
    end
    return table.concat(result)
end
function Layout.matches(name: string, query: string): boolean
    return string.find(Layout.fold(name), Layout.fold(query), 1, true) ~= nil
end
function Layout.upgrade(level: number, maximum: number, coins: number, cost: number, busy: boolean)
    if level >= maximum then return false, "Максимум", "max" end
    if busy then return false, "Покупаем…", "pending" end
    if coins < cost then return false, Layout.number(cost) .. " монет", "funds" end
    return true, Layout.number(cost) .. " монет", "ready"
end
function Layout.eggAction(readyAt: number, now: number, near: boolean, busy: boolean)
    if readyAt > 0 then return false, if readyAt > now then Layout.clock(readyAt - now) else "Вылупляется…" end
    if busy then return false, "Запускаем…" end
    if not near then return false, "К инкубатору" end
    return true, "Инкубировать"
end
function Layout.daily(deliveries: number, hatches: number, claimed: boolean, deliveryGoal: number, hatchGoal: number)
    return not claimed and deliveries >= deliveryGoal and hatches >= hatchGoal
end
function Layout.visible(top: number, height: number, scroll: number, window: number): boolean
    return top + height > scroll and top < scroll + window
end
return Layout
