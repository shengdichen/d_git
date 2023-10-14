local U = {}

U["BR_MAIN"] = "main"
U["BR_PREV"] = "@{-1}"

local function retval(cmd)
    local res
    local p = io.popen(cmd)
    if p ~= nil then
        for l in p:lines() do
            res = l
            break
        end
        p:close()
    end
    return res
end

U.has_untracked = function(opt)
    return not os.execute("git ls-files --others --exclude-standard")
end

U.check_tree = function(mode)
    if mode == "df" then
        return not os.execute("git diff-files --quiet --")
    elseif mode == "dc" then
        return not os.execute("git diff-index --quiet --cached HEAD --")
    elseif mode == "dfdc" then
        return not os.execute("git diff-index --quiet HEAD --")
    else
        print("Provide correct mode")
        os.exit(1)
    end
end

U.exec_git = function(cmds)
    if type(cmds) == "string" then
        cmds = { cmds }
    end
    for _, cmd in ipairs(cmds) do
        os.execute("git " .. cmd)
    end
end

U.branchname = function(commit)
    if commit == "" then
        commit = "HEAD"
    end
    return retval("git rev-parse --abbrev-ref " .. commit)
end

U.need_stash = function()
    -- stashing will forget the currently staged
    if U.check_tree("dc") then
        print("Exists --cached: commit now!")
        os.exit(1)
    end

    if U.check_tree("df") then return true end
    return false
end

U.do_within_stash = function(f)
    if U.need_stash() then
        io.write("Tree dirty, stash? [y]es (default), [n]o ")
        local input = io.read()
        if input == "n" then
            print("Not doing anything, exiting")
            return
        else
            U.exec_git("stash")
            f()
            U.exec_git("stash pop")
        end
    else
        f()
    end
end

U.select_branch = function()
    return retval(
        "git br -a  --no-color --no-column | fzf | sed " .. [["s/^\*\?\s*\(\S*\).*/\1/"]]
    )
end

U.select_commit = function()
    local res = retval(
        "git alo --no-color -n 97" .. " | " ..
        "fzf --reverse" .. " | " ..
        "grep " .. [["\w\+"]] .. " | " ..
        "sed " .. [=["s/^\W\+\s\(\w\+\)\s.*$/\1/"]=]
    )
    if not res then
        print("Invalid commit, reselect! Exiting")
        os.exit(1)
    else
        return res
    end
end

U.add_p = function()
    if not U.check_tree("df") then
        print("Nothing to add, done!")
    else
        U.exec_git("add -p")
        local done = false
        while not done do
            io.write(
                "What now? " ..
                "(Default: [q]uit; d[c]; d[f]; [a]d; c[l]ear; [r]estart from scratch) "
            )
            local input = io.read()
            if input == "" or input == "q" then
                break
            elseif input == "c" then
                U.exec_git("dc")
            elseif input == "f" then
                U.exec_git("df")
            elseif input == "a" then
                U.exec_git("add -p")
            elseif input == "l" then
                os.execute("clear")
            elseif input == "r" then
                U.exec_git({ "rt", "add -p" })
            else
                print("Specify correct mode")
            end
        end
    end
end

U.commit = function(cmd_extra)
    if not U.check_tree("dc") then
        U.add_p()
    end
    U.exec_git("commit " .. (cmd_extra or ""))
end

U.rebase = function(base, cmd_extra)
    U.do_within_stash(function()
        base = base or U.select_commit()
        U.exec_git(
            "rebase -i --autosquash" .. (cmd_extra or "") .. " " .. base
        )
    end)
end

return U
