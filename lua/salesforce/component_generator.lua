local Debug = require("salesforce.debug")
local Util = require("salesforce.util")

local M = {}

local category = "Component generation"

local executable = Util.get_sf_executable()
local prompt_for_name_and_dir = function(name_prompt, directory_prompt)
    local lwc_name = vim.fn.input(name_prompt)
    local directory = vim.fn.input(directory_prompt, vim.fn.expand("%:p:h"), "dir")
    if vim.fn.isdirectory(directory) == 1 then
        Debug:log("component_generator.lua", string.format("Selected directory: %s", directory))
    else
        Util.clear_and_notify(
            string.format("Directory does not exist: %s", directory),
            vim.log.levels.ERROR
        )
        directory = nil
    end
    return lwc_name, directory
end

local component_creation_callback = function(job)
    vim.schedule(function()
        local sfdx_output = job:result()
        sfdx_output = table.concat(sfdx_output)
        Debug:log("component_generator.lua", "Result from command:")
        Debug:log("component_generator.lua", sfdx_output)
        local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
        if not json_ok or not sfdx_response then
            vim.notify(
                "Failed to parse the 'lightning generate component' SFDX command output",
                vim.log.levels.ERROR
            )
            return
        end

        if sfdx_response.status == 0 then
            Util.clear_and_notify(
                string.format("Successfully created in dir: %s", sfdx_response.result.outputDir)
            )
        else
            Util.clear_and_notify(
                string.format("Failed to create component: %s", vim.inspect(sfdx_response)),
                vim.log.levels.ERROR
            )
        end
    end)
end

M.create_lightning_component = function()
    local name, dir =
        prompt_for_name_and_dir("Lightning Component name: ", "Please select a directory: ")

    if not dir then
        return
    end

    Util.clear_prompt()

    vim.ui.select(
        { "Aura", "Lightning Web Component" },
        {
            prompt = "Lightning Component Type: ",
        },
        vim.schedule_wrap(function(choice)
            if not choice then
                return
            end
            local type
            if choice == "Aura" then
                type = "aura"
            else
                type = "lwc"
            end
            local command = string.format(
                "%s lightning generate component --name %s --type %s --output-dir %s --json",
                executable,
                name,
                type,
                dir
            )
            Util.clear_and_notify("Creating component...")
            Util.send_cli_command(
                command,
                component_creation_callback,
                category,
                "component_generator.lua"
            )
        end)
    )
end

M.create_apex = function()
    local name, dir =
        prompt_for_name_and_dir("Trigger or Class name: ", "Please select a directory: ")

    if not dir then
        return
    end

    Util.clear_prompt()

    vim.ui.select(
        { "Class", "Trigger" },
        {
            prompt = "Apex file type: ",
        },
        vim.schedule_wrap(function(choice)
            if not choice then
                return
            end
            local type
            if choice == "Class" then
                type = "class"
            else
                type = "trigger"
            end
            local command = string.format(
                "%s apex generate %s --name %s --output-dir %s --json",
                executable,
                type,
                name,
                dir
            )
            Util.clear_and_notify("Creating component...")
            Util.send_cli_command(
                command,
                component_creation_callback,
                category,
                "component_generator.lua"
            )
        end)
    )
end

return M
