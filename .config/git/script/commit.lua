local SCRIPT_DIR = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
package.path = package.path .. ";" .. SCRIPT_DIR .. "?.lua"
local util = require("util")

local function merge_auto_abort(br)
    if not os.execute("git merge --no-ff " .. br) then
        os.execute("git merge abort")
    end
end

local function merge_current(br)
    br = br or util.branchname("HEAD")
    if br == util.BR_MAIN then
        print("On " .. util.BR_MAIN .. " already, done!")
        return
    end

    util.do_within_stash(
        function()
            util.exec_git({ "co main" })
            merge_auto_abort(util.BR_PREV)
            util.exec_git({ "br -d " .. br })
        end
    )
end

local function main(arg)
    if arg[1] == "mm" then
        merge_current(arg[2])
    else
        print("Enter correct mode, exiting")
        os.exit(1)
    end
end
main(arg)
