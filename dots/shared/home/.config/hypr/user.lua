local binds = {
    ["vesktop|discord|vencord"] = {
        "CTRL+SHIFT+M",
        "CTRL+SHIFT+D"
    },
    ["com\\.obsproject\\.Studio"] = { "F9", "F10" },
}

for app, keys in pairs(binds) do
    for _, key in ipairs(keys) do
        hl.bind(key, hl.dsp.pass({ window = "class:^(" .. app .. ")$" }))
    end
end
