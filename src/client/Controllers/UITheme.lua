--!strict
-- Shared visual language. No external image or font assets are needed to draw the HUD.
return table.freeze({
    Background = Color3.fromRGB(12, 19, 31),
    Surface = Color3.fromRGB(21, 32, 48),
    Raised = Color3.fromRGB(29, 43, 60),
    Stroke = Color3.fromRGB(66, 85, 104),
    Text = Color3.fromRGB(242, 247, 250),
    Muted = Color3.fromRGB(162, 180, 197),
    Teal = Color3.fromRGB(91, 225, 195),
    Amber = Color3.fromRGB(255, 205, 112),
    Danger = Color3.fromRGB(255, 143, 140),
    Disabled = Color3.fromRGB(49, 63, 79),
    Rarity = {
        COMMON = Color3.fromRGB(183, 200, 211),
        UNCOMMON = Color3.fromRGB(140, 225, 166),
        RARE = Color3.fromRGB(128, 199, 255),
        EPIC = Color3.fromRGB(202, 161, 255),
        LEGENDARY = Color3.fromRGB(255, 210, 120),
        MYTHIC = Color3.fromRGB(255, 156, 190),
        SECRET = Color3.fromRGB(221, 185, 255),
        DIVINE = Color3.fromRGB(245, 239, 190),
    },
})
