local Util = require("salesforce.util")

local M = {}

M.diff_with_org = function()
    local path = vim.fn.expand("%:p")
    local file_name = vim.fn.expand("%:t")
    local file_name_no_ext = Util.get_file_name_without_extension(file_name)
    local metadataType = Util.get_metadata_type(path)

    if metadataType == nil then
        vim.notify("Not a supported metadata type.", vim.log.levels.ERROR)
        return
    end

    print("Retrieving " .. file_name .. " from the org...")
    local temp_dir = vim.fn.tempname()
    local temp_dir_with_suffix = string.format("%s/main/default", temp_dir)
    vim.fn.mkdir(temp_dir_with_suffix, "p")
    vim.notify("temp_dir_with_suffix: " .. temp_dir_with_suffix)

    local command = string.format(
        "sf project retrieve start -m %s:%s -r %s --json",
        metadataType,
        file_name_no_ext,
        temp_dir
    )
    vim.notify("Running " .. command .. "...")
    local sfdx_output = vim.fn.system(command)
    local json_start = sfdx_output:find("{")
    local json_part = json_start and sfdx_output:sub(json_start) or ""

    -- parse the JSON
    local json_ok, sfdx_response = pcall(vim.json.decode, json_part)
    if not json_ok or not sfdx_response then
        vim.notify("Failed to parse the SFDX command output.", vim.log.levels.ERROR)
        return
    end

    -- check for messages and notify if present
    if
        sfdx_response.result
        and sfdx_response.result.messages
        and #sfdx_response.result.messages > 0
    then
        for _, message in ipairs(sfdx_response.result.messages) do
            vim.notify(message.problem, vim.log.levels.ERROR)
        end
        return
    end

    local retrieved_file_path = find_file(temp_dir, file_name)
    vim.notify("Temp file path: " .. (retrieved_file_path or "Not found"))

    if not retrieved_file_path or not vim.fn.filereadable(retrieved_file_path) then
        vim.notify("Failed to retrieve the file from the org.", vim.log.levels.ERROR)
        return
    end

    vim.notify("Diffing " .. file_name .. " with the retrieved file...")
    vim.cmd("vert diffsplit " .. retrieved_file_path)
    vim.fn.delete(temp_dir, "rf")
end

return M
