local getopt = require("getopt")

if #({...}) == 0 then
    io.write("Riko4\n")
    return
end

getopt({...}, "-so", {
    ["kernel-name"]      = {hasArg = getopt.noArgument, val = "s"},
    ["operating-system"] = {hasArg = getopt.noArgument, val = "o"}
}) {
    s = function()
        io.write("Riko4")
    end,
    o = function()
        io.write("rikoOS ")
    end
}

-- io.write("\n")
