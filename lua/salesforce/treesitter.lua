local ts_utils = require("nvim-treesitter.ts_utils")

local M = {}

-- Find parent nodes by type
local function find_parent_by_type(expr, type_name)
    while expr do
        if expr:type() == type_name then
            break
        end
        expr = expr:parent()
    end
    return expr
end

-- Find child nodes by type
local function find_child_by_type(expr, type_name)
    local id = 0
    local expr_child = expr:child(id)
    while expr_child do
        if expr_child:type() == type_name then
            break
        end
        id = id + 1
        expr_child = expr:child(id)
    end

    return expr_child
end

local function has_istest_annotation(expr)
    local modifier = find_child_by_type(expr, "modifiers")
    if not modifier then
        return nil
    end

    local annotation = find_child_by_type(modifier, "annotation")
    if not annotation then
        return nil
    end

    local name = find_child_by_type(annotation, "identifier")
    if not name then
        return nil
    end

    return string.lower(vim.treesitter.get_node_text(name, 0)) == "istest"
end

local get_declaration_name = function(type)
    local current_node = ts_utils.get_node_at_cursor()
    if not current_node then
        return nil
    end

    local declaration = find_parent_by_type(current_node, type)
    if not declaration or not has_istest_annotation(declaration) then
        return nil
    end

    local name = find_child_by_type(declaration, "identifier")
    if not name then
        return nil
    end

    return vim.treesitter.get_node_text(name, 0)
end

M.get_current_class_name = function()
    return get_declaration_name("class_declaration")
end

M.get_current_method_name = function()
    return get_declaration_name("method_declaration")
end

return M
