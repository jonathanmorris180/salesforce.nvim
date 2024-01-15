local Util = require("salesforce.util")
local Job = require("plenary.job")
local Debug = require("salesforce.debug")

local M = {}

local temp_dir

local function diff_callback(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        local file_name = vim.fn.expand("%:t")
        sfdx_output = table.concat(sfdx_output)
        Debug:log("diff.lua", "Result from command:")
        Debug:log("diff.lua", sfdx_output)

        local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
        if not json_ok or not sfdx_response then
            vim.notify("Failed to parse the SFDX command output", vim.log.levels.ERROR)
            return
        end

        if
            sfdx_response.result
            and sfdx_response.result.files
            and #sfdx_response.result.files > 0
        then
            for _, file in ipairs(sfdx_response.result.files) do
                if file.error then
                    vim.notify(file.error, vim.log.levels.ERROR)
                    return
                end
            end
        elseif
            sfdx_response.result
            and sfdx_response.result.messages
            and #sfdx_respons.result.messages > 0
        then
            for _, message in ipairs(sfdx_response.result.messages) do
                if message.problem then
                    vim.notify(message.problem, vim.log.levels.ERROR)
                    return
                end
            end
        end

        local retrieved_file_path = Util.find_file(temp_dir, file_name)
        Debug:log("diff.lua", "Temp file path: " .. (retrieved_file_path or "Not found"))

        if not retrieved_file_path or not vim.fn.filereadable(retrieved_file_path) then
            vim.notify("Failed to retrieve the file from the org", vim.log.levels.ERROR)
            return
        end

        Util.clear_and_notify("Diffing " .. file_name)
        vim.cmd("vert diffsplit " .. retrieved_file_path)
        vim.fn.delete(temp_dir, "rf")
    end)
end

local function execute_job(command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    Job:new({
        command = "sf",
        args = args,
        on_exit = diff_callback,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("diff.lua", "Command stderr is: %s", data)
            end)
        end,
    }):start()
end

M.diff_with_org = function()
    local path = vim.fn.expand("%:p")
    local file_name = vim.fn.expand("%:t")
    local file_name_no_ext = Util.get_file_name_without_extension(file_name)
    local metadataType = Util.get_metadata_type(path)

    if metadataType == nil then
        vim.notify("Not a supported metadata type.", vim.log.levels.ERROR)
        return
    end

    Util.clear_and_notify("Diffing " .. file_name .. " with the org...")
    temp_dir = vim.fn.tempname()
    local temp_dir_with_suffix = string.format("%s/main/default", temp_dir)
    vim.fn.mkdir(temp_dir_with_suffix, "p")
    Debug:log("diff.lua", "Created temp dir: " .. temp_dir_with_suffix)

    local command = string.format(
        "sf project retrieve start -m %s:%s -r %s --json",
        metadataType,
        file_name_no_ext,
        temp_dir
    )
    Debug:log("diff.lua", "Command: " .. command)
    execute_job(command)
end

return M
