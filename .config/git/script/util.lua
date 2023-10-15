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

U.printer = function(mode, args)
    if mode == "huh" then
        print("Huh? (aka, what is " .. (args["input"] or "blank") .. "?)\n")
    end
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
    end
end

U.commit_rework = function(mode, target)
    if not target or target == "" then
        io.write("Paste-in commit; select interactively (default) ")
        target = io.read()
        if target == "" then
            target = U.select_commit()
        end
    end
    U.exec_git("commit --" .. mode .. " " .. target)
    U.rebase(target .. "~")
end

U.commit = function(mode, args)
    if U.check_tree("df") then
        io.write("Exists df, what now? [a]p; c[i] anyway (default) ")
        local input = io.read()
        if input == "a" then
            U.add_p()
        end
    end
    if not U.check_tree("dc") then
        io.write("No dc, what now? [a]p (default); [q]uit ")
        local input = io.read()
        if input == "q" then
            print("No will to commit, exiting")
            return
        else
            U.add_p()
        end
    end
    if mode == "fixup" or mode == "squash" then
        U.commit_rework(mode, args and args["target"])
    elseif mode == "" then
        U.exec_git("commit " .. (args and args["cmd_extra"] or ""))
    else
        print("Specify correct commit-mode, exiting")
        os.exit(1)
    end
end

U.rebase = function(base, cmd_extra)
    U.do_within_stash(function()
        base = base or U.select_commit()
        U.exec_git(
            "rebase -i --autosquash" .. (cmd_extra or "") .. " " .. base
        )
    end)
end

U.merge = function(br)
    if br == U.BR_MAIN then
        print("On " .. U.BR_MAIN .. " already, done!")
        return
    end

    U.do_within_stash(
        function()
            U.exec_git({ "co " .. U.BR_MAIN })
            if not os.execute("git merge --no-ff " .. br) then
                U.exec_git({ "merge --abort", "co " .. U.BR_PREV })
            else
                U.exec_git({ "br -d " .. br })
            end
        end
    )
end

U.inspect = function()
    while true do
        io.write("Inspect, but how? [lg]; [lo]; [alg]; [alo] (default); [q]uit ")
        local input = io.read()
        if input == "lg" then
            U.exec_git("log --graph --pretty=stylepatch --patch --unified=2 main..@")
        elseif input == "lo" then
            U.exec_git("log --graph --pretty=styleoneline main..@")
        elseif input == "alg" then
            U.exec_git("log --all --graph --pretty=stylepatch --patch --unified=2")
        elseif input == "alo" or input == "" then
            U.exec_git("log --all --graph --pretty=styleoneline")
        elseif input == "q" then
            break
        else
            print("Huh? (aka, what is " .. input .. "?)\n")
        end
    end
end

return U
