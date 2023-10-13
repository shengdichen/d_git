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

local function rehead(br_to)
    local br_tmp = "__TMP"
    local br_from = util.branchname("HEAD")

    util.exec_git({
        "cb " .. br_tmp,
        "br -f " .. br_from .. " " .. br_to,
    })
    util.do_within_stash(
        function() util.exec_git({ "co " .. br_from, }) end
    )
    util.exec_git({
        "br -D " .. br_tmp
    })
end

local function checkout_force(br, target)
    br = br or util.select_branch()
    target = target or "HEAD"

    util.exec_git({
        "br -f " .. br .. " " .. target,
        "co " .. br,
    })
end

local function main(arg)
    if arg[1] == "mm" then
        merge_current(arg[2])
    elseif arg[1] == "bf" then
        rehead(arg[2])
    elseif arg[1] == "cc" then
        checkout_force(arg[2], arg[3])
    else
        print("Enter correct mode, exiting")
        os.exit(1)
    end
end
main(arg)
