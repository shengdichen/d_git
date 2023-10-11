local U = {}

U["BR_MAIN"] = "main"
U["BR_PREV"] = "@{-1}"

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
    for _, cmd in ipairs(cmds) do
        os.execute("git " .. cmd)
    end
end

U.branchname = function(commit)
    if commit == "" then
        commit = "HEAD"
    end
    local br_name
    local p = io.popen("git rev-parse --abbrev-ref " .. commit)
    if p ~= nil then
        for l in p:lines() do
            br_name = l -- will only return one value
            break
        end
        p:close()
    end
    return br_name
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
        U.exec_git("stash")
        f()
        U.exec_git("stash pop")
    else
        f()
    end
end

return U
