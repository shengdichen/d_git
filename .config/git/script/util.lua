local U = {}

U["BR_MAIN"] = "main"
U["BR_PREV"] = "@{-1}"
U["USER"] = "shc"
U["FEATURE"] = U["USER"] .. "/"

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

local function retall(cmd)
    local res = {}
    local p = io.popen(cmd)
    if p ~= nil then
        for l in p:lines() do
            table.insert(res, l)
        end
        p:close()
    end
    return res
end

local function pipeline(cmds)
    return table.concat(cmds, " | ")
end

U.printer = function(mode, args)
    if mode == "prompt" then
        io.write(args["action"] .. "> " .. args["text"])
    elseif mode == "huh" then
        print("Huh? (aka, what is " .. (args["input"] or "blank") .. "?)\n")
    elseif mode == "giveup" then
        print("No will to " .. args["action"] .. ", backing off")
    elseif mode == "invalid" then
        print("Bad " .. args["action"] .. ", " .. args["resolve"])
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
        U.printer("invalid", { mode = "diff-mode", resolve = "reselect" })
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
    local action = "stash"
    if U.need_stash() then
        U.printer("prompt", { action = action, text = "Tree dirty, stash? [y]es (default), [n]o " })
        local input = io.read()
        if input == "n" then
            U.printer("giveup", { action = action })
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

U.select_branch = function(args)
    local cmds = { "git br -a  --no-color --no-column" }

    local br_filter = args and args["filter"]
    if br_filter then
        table.insert(cmds, "grep " .. '"' .. br_filter .. '"')
    end

    table.insert(cmds, "sed " .. [["s/^\*\?\s*\(\S*\).*/\1/"]])
    if not args or args["fzf"] then -- default to using fzf
        table.insert(cmds, "fzf")
    end

    if args and args["multi"] then
        return retall(pipeline(cmds))
    end
    return retval(pipeline(cmds))
end

U.select_commit = function()
    local res
    while true do
        res = retval(
            "git alo --no-color -n 97" .. " | " ..
            "fzf --reverse" .. " | " ..
            "grep " .. [["\w\+"]] .. " | " ..
            "sed " .. [=["s/^\W\+\s\(\w\+\)\s.*$/\1/"]=]
        )
        if res then
            break
        else
            U.printer("invalid", { mode = "commit", resolve = "reselect" })
        end
    end

    return res
end

U.add_p = function()
    if not U.check_tree("df") then
        print("Nothing to add, done!")
    else
        U.exec_git("add -p")
    end
end

U.commit_rework = function(mode, target)
    local action = "commit"
    if not target or target == "" then
        U.printer(
            "prompt",
            { action = action, text = "Paste-in commit; select interactively (default) " }
        )
        target = io.read()
        if target == "" then
            target = U.select_commit()
        end
    end
    U.exec_git("commit --" .. mode .. " " .. target)
    U.rebase(target .. "~")
end

U.commit = function(mode, args)
    local action = "commit"
    if U.check_tree("df") then
        U.printer(
            "prompt",
            { action = action, text = "Exists df, what now? [a]p; c[i] anyway (default) " }
        )
        local input = io.read()
        if input == "a" then
            U.add_p()
        end
    end
    if not U.check_tree("dc") then
        U.printer(
            "prompt",
            { action = action, text = "No dc, what now? [a]p (default); [q]uit " }
        )
        local input = io.read()
        if input == "q" then
            U.printer("giveup", { action = action })
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
        U.printer("invalid", { mode = "commit-mode", resolve = "exiting" })
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

U.merge = function(br, base, args)
    if br == base then
        print("On " .. base .. " already, done!")
        return
    end

    U.do_within_stash(
        function()
            if type(br) == "string" then
                br = { br }
            end
            for _, b in ipairs(br) do
                U.exec_git({ "co " .. base })
                if not os.execute(
                        "git merge " ..
                        (args and args["no_edit"] and "--no-edit " or "") ..
                        "--no-ff " ..
                        b
                    ) then
                    U.exec_git({ "merge --abort", "co " .. U.BR_PREV })
                else
                    if not (args and args["keep_branch"]) then
                        U.exec_git({ "br -d " .. b })
                    end
                end
            end
        end
    )
end

U.inspect = function()
    while true do
        U.printer(
            "prompt",
            {
                action = "log",
                text = "Inspect, but how? [lg]; [lo]; [alg]; [alo] (default); [q]uit "
            }
        )
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
            U.printer("huh", { input = input })
        end
    end
end

local function features()
    return U.select_branch({ multi = true, filter = U["FEATURE"] })
end

U.merge_features = function(feats)
    feats = feats or features()

    U.do_within_stash(function()
        U.merge(feats, U["BR_MAIN"], { no_edit = true, keep_branch = true })
    end
    )
end

return U
