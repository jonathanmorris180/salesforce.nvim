local Debug = require("salesforce.debug")
local Util = require("salesforce.util")

local M = {}

local executable = Util.get_sf_executable()
local prompt_for_name_and_dir = function(name_prompt, directory_prompt)
    local lwc_name = vim.fn.input(name_prompt)
    local directory = vim.fn.input(directory_prompt, vim.fn.expand("%:p:h"), "dir")
    if vim.fn.isdirectory(directory) == 1 then
        print("Selected directory: " .. directory)
    else
        error("invalid directory selected")
    end
    return lwc_name, directory
end

local component_creation_callback = function(job)
    vim.schedule(function()
        local sfdx_output = job:result()
        sfdx_output = table.concat(sfdx_output)
        Debug:log("component_generator.lua", "Result from command:")
        Debug:log("component_generator.lua", sfdx_output)

        -- Errors still trigger this callback, but have an emty output.
        if sfdx_output ~= nil and sfdx_output ~= "" then
            vim.notify(sfdx_output, vim.log.levels.INFO)
        end
    end)
end

M.create_lightning_component = function()
    local name, dir = prompt_for_name_and_dir("Component Name: ", "Please select a directory")

    vim.ui.select(
        { "Aura", "Lightning Web Component" },
        {
            prompt = "Lightning Component Type: ",
        },
        vim.schedule_wrap(function(choice)
            local type
            if choice == "Aura" then
                type = "aura"
            else
                type = "lwc"
            end
            local command = string.format(
                "%s lightning generate component --name %s --type %s --output-dir %s",
                executable,
                name,
                type,
                dir
            )
            Util.send_cli_command(
                command,
                component_creation_callback,
                "generate component",
                "component_generator.lua"
            )
        end)
    )
end

M.create_apex = function()
    local name, dir = prompt_for_name_and_dir("Apex Name: ", "Please select a directory: ")
    vim.ui.select(
        { "class", "trigger" },
        {
            prompt = "Apex file type: ",
        },
        vim.schedule_wrap(function(choice)
            local command = string.format(
                "%s apex generate %s --name %s --output-dir %s",
                executable,
                choice,
                name,
                dir
            )
            Util.send_cli_command(
                command,
                component_creation_callback,
                "generate component",
                "component_generator.lua"
            )
        end)
    )
end

return M
