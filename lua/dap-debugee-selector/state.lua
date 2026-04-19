local M = {}

local state_file = vim.fn.stdpath('data') .. '/debugee_selector_state.json'
local project_key = vim.fn.getcwd()

--- Internal state table
M.data = {
   searchPathRoot = '',
   current_index = 0,
   last_selected_index = 1,
   last_debugee_args = '',
   last_program = '',
}

--- Splits a space-separated argument string into a table of individual arguments
--- @param args_str string: The argument string, e.g. "--foo bar --baz"
--- @return table: A list of argument strings
function M.parse_args(args_str)
   local result = {}
   for arg in args_str:gmatch('%S+') do
      table.insert(result, arg)
   end
   return result
end

--- Loads persisted state from disk into the state table
function M.load()
   if vim.fn.filereadable(state_file) == 0 then
      return
   end
   local ok, all_states = pcall(function()
      return vim.fn.json_decode(table.concat(vim.fn.readfile(state_file), '\n'))
   end)
   if ok and type(all_states) == 'table' then
      local data = all_states[project_key] or {}
      M.data.searchPathRoot = data.searchPathRoot or ''
      M.data.last_selected_index = data.last_selected_index or 1
      M.data.last_debugee_args = data.last_debugee_args or ''
      M.data.last_program = data.last_program or ''
   end
end

--- Persists the current state to disk
function M.save()
   -- Read existing states for all projects first to avoid overwriting them
   local all_states = {}
   if vim.fn.filereadable(state_file) == 1 then
      local ok, decoded = pcall(function()
         return vim.fn.json_decode(table.concat(vim.fn.readfile(state_file), '\n'))
      end)
      if ok and type(decoded) == 'table' then
         all_states = decoded
      end
   end
   all_states[project_key] = {
      searchPathRoot = M.data.searchPathRoot,
      last_selected_index = M.data.last_selected_index,
      last_debugee_args = M.data.last_debugee_args,
      last_program = M.data.last_program,
   }
   vim.fn.writefile({ vim.fn.json_encode(all_states) }, state_file)
end

return M

