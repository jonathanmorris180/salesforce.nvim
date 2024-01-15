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

-- Get Current Method Name
M.get_current_method_name = function()
    local current_node = ts_utils.get_node_at_cursor()
    if not current_node then
        return nil
    end

    local expr = find_parent_by_type(current_node, "method_declaration")

    if not expr or not has_istest_annotation(expr) then
        return nil
    end

    local name = find_child_by_type(expr, "identifier")
    if not name then
        return nil
    end

    return vim.treesitter.get_node_text(name, 0)
end

-- Get Current Class Name
M.get_current_class_name = function()
    local current_node = ts_utils.get_node_at_cursor()
    if not current_node then
        return nil
    end

    local class_declaration = find_parent_by_type(current_node, "class_declaration")
    if not class_declaration then
        return nil
    end

    local child = find_child_by_type(class_declaration, "identifier")
    if not child then
        return nil
    end
    return vim.treesitter.get_node_text(child, 0)
end

return M
