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

local function rehead(target)
    local br_tmp = "__TMP"
    local br_from = util.branchname("HEAD")
    target = target or util.select_commit()

    util.exec_git({
        "cb " .. br_tmp,
        "br -f " .. br_from .. " " .. target,
    })
    util.do_within_stash(
        function() util.exec_git({ "co " .. br_from, }) end
    )
    util.exec_git({
        "br -D " .. br_tmp
    })
end

local function rebranch(br_from, target)
    local br_curr = util.branchname("HEAD")
    br_from = br_from or util.select_branch()
    target = target or util.select_commit()

    if br_from == br_curr then
        rehead(target)
    else
        util.exec_git("br -f " .. br_from .. " " .. target)
    end
    util.exec_git("alo")
end

local function checkout_force(br, target)
    br = br or util.select_branch()
    target = target or util.select_commit()

    util.exec_git({
        "br -f " .. br .. " " .. target,
        "co " .. br,
    })
end

local function rework_commit(mode, target)
    if mode == "cf" then
        mode = "fixup"
    elseif mode == "cs" then
        mode = "squash"
    else
        print("Specify commit fixup mode, exiting")
        os.exit(1)
    end

    if not target or target == "" then
        io.write("Paste-in commit; select interactively (default) ")
        target = io.read()
        if target == "" then
            target = util.select_commit()
        end
    end
    util.commit("--" .. mode .. " " .. target)
    util.rebase(target .. "~")
end

local function loop()
    while true do
        io.write("What now? [l]g (default); [a]d; [c]i; [r]e; [m]e; [df]; [dc]; [st]; [q]uit ")
        local input = io.read()
        if input == "l" or input == "" then
            util.inspect()
        elseif input == "a" then
            util.add_p()
        elseif input == "c" then
            util.commit()
        elseif input == "r" then
            util.rebase()
        elseif input == "m" then
            merge_current()
        elseif input == "df" or input == "dc" or input == "st" then
            util.exec_git(input)
        elseif input == "q" then
            break
        else
            print("Huh? (aka, what is " .. input .. "?)\n")
        end
    end
end

local function main(arg)
    if arg[1] == "mm" then
        merge_current(arg[2])
    elseif arg[1] == "bf" then
        rebranch(arg[2])
    elseif arg[1] == "cc" then
        checkout_force(arg[2], arg[3])
    elseif arg[1] == "cf" or arg[1] == "cs" then
        rework_commit(arg[1], arg[2])
    elseif arg[1] == "ap" then
        util.add_p()
    elseif arg[1] == "ci" then
        util.commit()
    elseif arg[1] == "ri" then
        util.rebase()
    else
        loop()
    end
end
main(arg)
