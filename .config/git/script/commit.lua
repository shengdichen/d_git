local SCRIPT_DIR = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
package.path = package.path .. ";" .. SCRIPT_DIR .. "?.lua"
local util = require("util")

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

local function merge(br, base)
    if not br or br == "" then
        io.write("Merge which branch? HEAD (default), [s]elect ")
        local input = io.read()
        if input == "" then
            br = util.branchname("HEAD")
        else
            br = util.select_branch()
        end
    end

    if not base or base == "" then
        io.write("Merge base? " .. util.BR_MAIN .. " (default), [s]elect ")
        local input = io.read()
        if input == "" then
            br = util.BR_MAIN
        else
            br = util.select_branch()
        end
    end

    util.merge(br)
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

local function commit(args)
    io.write("Commit mode: [c]i (default); c[f]; c[s] ")
    local mode = io.read()
    if mode == "" or mode == "c" then
        mode = ""
    elseif mode == "f" then
        mode = "fixup"
    elseif mode == "s" then
        mode = "squash"
    else
        util.printer("huh", { input = mode })
        return
    end
    util.commit(mode, args)
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
            commit()
        elseif input == "r" then
            util.rebase()
        elseif input == "m" then
            merge()
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
        merge(arg[2], arg[3])
    elseif arg[1] == "bf" then
        rebranch(arg[2])
    elseif arg[1] == "cc" then
        checkout_force(arg[2], arg[3])
    elseif arg[1] == "cf" or arg[1] == "cs" then
        rework_commit(arg[1], arg[2])
    elseif arg[1] == "ap" then
        util.add_p()
    elseif arg[1] == "ci" then
        commit()
    elseif arg[1] == "ri" then
        util.rebase()
    else
        loop()
    end
end
main(arg)
