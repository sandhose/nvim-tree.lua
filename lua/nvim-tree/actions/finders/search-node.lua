local api = vim.api
local uv = vim.loop

local core = require "nvim-tree.core"
local filters = require "nvim-tree.explorer.filters"
local find_file = require("nvim-tree.actions.finders.find-file").fn

local M = {}

local function search(search_dir, input_path)
  local realpaths = {}

  if not search_dir then
    return
  end

  local function iter(dir)
    local realpath, path, name, stat, handle, _

    handle, _ = uv.fs_scandir(dir)
    if not handle then
      return
    end

    realpath, _ = uv.fs_realpath(dir)
    if not realpath or vim.tbl_contains(realpaths, realpath) then
      return
    end
    table.insert(realpaths, realpath)

    name, _ = uv.fs_scandir_next(handle)
    while name do
      path = dir .. "/" .. name

      stat, _ = uv.fs_stat(path)
      if not stat then
        break
      end

      if not filters.should_ignore(path) then
        if string.find(path, "/" .. input_path .. "$") then
          return path
        end

        if stat.type == "directory" then
          path = iter(path, input_path)
          if path then
            return path
          end
        end
      end

      name, _ = uv.fs_scandir_next(handle)
    end
  end

  return iter(search_dir)
end

function M.fn()
  if not core.get_explorer() then
    return
  end

  -- temporarily set &path
  local bufnr = api.nvim_get_current_buf()
  local path_existed, path_opt = pcall(api.nvim_buf_get_option, bufnr, "path")
  api.nvim_buf_set_option(bufnr, "path", core.get_cwd() .. "/**")

  vim.ui.input({ prompt = "Search: ", completion = "file_in_path" }, function(input_path)
    if not input_path or input_path == "" then
      return
    end
    -- reset &path
    if path_existed then
      api.nvim_buf_set_option(bufnr, "path", path_opt)
    else
      api.nvim_buf_set_option(bufnr, "path", nil)
    end

    -- strip trailing slash
    input_path = string.gsub(input_path, "/$", "")

    -- search under cwd
    local found = search(core.get_cwd(), input_path)
    if found then
      find_file(found)
    end
  end)
end

return M
