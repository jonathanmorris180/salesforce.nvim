local Util = require("salesforce.util")
local Job = require("plenary.job")
local Debug = require("salesforce.debug")
local OrgManager = require("salesforce.org_manager")

function Job:is_running()
    if self.handle and not vim.loop.is_closing(self.handle) and vim.loop.is_active(self.handle) then
        return true
    else
        return false
    end
end

local M = {}

local temp_dir
local executable = Util.get_sf_executable()
local file_name
local current_buf

local function execute_job(args, callback)
    local all_args = Util.flatten(args)
    Debug:log("diff.lua", "Command: ")
    Debug:log("diff.lua", all_args)
    local new_job = Job:new({
        command = executable,
        args = all_args,
        on_exit = callback,
        env = Util.get_env(),
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("diff.lua", "Command stderr is: %s", data)
            end)
        end,
    })
    if not M.current_job or not M.current_job:is_running() then
        M.current_job = new_job
        M.current_job:start()
    end
end

local function parse_sfdx_response(sfdx_output)
    local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
    if not json_ok or not sfdx_response then
        vim.notify("Failed to parse the SFDX command output", vim.log.levels.ERROR)
        vim.fn.delete(temp_dir, "rf")
        return
    end
    return sfdx_response
end

local function finish(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        sfdx_output = table.concat(sfdx_output)
        Debug:log("diff.lua", "Result from command:")
        Debug:log("diff.lua", sfdx_output)

        local sfdx_response = parse_sfdx_response(sfdx_output)

        if not sfdx_response then
            return -- for the compiler, will never happen
        end

        if sfdx_response.status ~= 0 or not sfdx_response.result or #sfdx_response.result == 0 then
            if sfdx_response.cause then
                vim.notify(sfdx_response.cause, vim.log.levels.ERROR)
                vim.fn.delete(temp_dir, "rf")
                return
            else
                vim.notify(
                    "Unknown error converting from metadata to source format",
                    vim.log.levels.ERROR
                )
                vim.fn.delete(temp_dir, "rf")
                return
            end
        end

        local retrieved_file_path = Util.find_file(temp_dir .. "/converted", file_name)
        Debug:log("diff.lua", "Temp file path: " .. (retrieved_file_path or "Not found"))

        if not retrieved_file_path or not vim.fn.filereadable(retrieved_file_path) then
            vim.notify("Failed to retrieve the file from the org", vim.log.levels.ERROR)
            vim.fn.delete(temp_dir, "rf")
            return
        end

        Util.clear_and_notify("Diffing " .. file_name)
        vim.api.nvim_set_current_buf(current_buf) -- In case the user moves to a different buffer while waiting
        vim.cmd("vert diffsplit " .. retrieved_file_path)
        vim.fn.delete(temp_dir, "rf")
    end)
end

local function convert_to_source(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        sfdx_output = table.concat(sfdx_output)
        Debug:log("diff.lua", "Result from command:")
        Debug:log("diff.lua", sfdx_output)

        local sfdx_response = parse_sfdx_response(sfdx_output)

        if not sfdx_response then
            return -- for the compiler, will never happen
        end

        if
            sfdx_response.result
            and sfdx_response.result.files
            and #sfdx_response.result.files > 0
        then
            for _, file in ipairs(sfdx_response.result.files) do
                if file.error then
                    vim.notify(file.error, vim.log.levels.ERROR)
                    vim.fn.delete(temp_dir, "rf")
                    return
                end
            end
        elseif
            sfdx_response.result
            and sfdx_response.result.messages
            and #sfdx_response.result.messages > 0
        then
            for _, message in ipairs(sfdx_response.result.messages) do
                if message.problem then
                    vim.notify(message.problem, vim.log.levels.ERROR)
                    vim.fn.delete(temp_dir, "rf")
                    return
                end
            end
        end

        -- Now, convert to source
        -- Note: Org flag does not exist for this command
        local unpackaged_dir = temp_dir .. "/unpackaged"
        local output_dir = temp_dir .. "/converted"
        local args = {
            "project",
            "convert",
            "mdapi",
            "--json",
            ["--root-dir"] = unpackaged_dir,
            ["--output-dir"] = output_dir,
        }

        execute_job(args, finish)
    end)
end

M.diff_with_org = function()
    if M.current_job and M.current_job:is_running() then
        -- needs to be here or temp dir will be overwritten
        Util.notify_command_in_progress("diff with org")
        return
    end
    local path = vim.fn.expand("%:p")
    file_name = vim.fn.expand("%:t")
    current_buf = vim.api.nvim_get_current_buf()
    local file_name_no_ext = Util.get_file_name_without_extension(file_name)
    local metadataType = Util.get_metadata_type(path)
    local default_username = OrgManager:get_default_username()

    if metadataType == nil then
        vim.notify("Not a supported metadata type.", vim.log.levels.ERROR)
        return
    end

    if default_username == nil then
        Util.notify_default_org_not_set()
        return
    end

    Util.clear_and_notify(string.format("Diffing %s with org %s...", file_name, default_username))
    temp_dir = vim.fn.tempname()
    Debug:log("diff.lua", "Created temp dir: " .. temp_dir)
    local args = {
        "project",
        "retrieve",
        "start",
        "--unzip",
        "--json",
        ["-m"] = string.format("%s:%s", metadataType, file_name_no_ext),
        ["--target-metadata-dir"] = temp_dir, -- See https://github.com/forcedotcom/cli/issues/3009
        ["-o"] = default_username,
    }

    execute_job(args, convert_to_source)
end

return M
