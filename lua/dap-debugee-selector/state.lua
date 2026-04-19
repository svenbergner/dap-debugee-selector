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
   --- args_history is keyed by the executable path, each value is a list of
   --- previously used argument strings (newest first, no duplicates)
   args_history = {},
}

--- Adds an argument string to the history for the given program.
--- Duplicates are removed and the new entry is placed at the top.
--- Empty strings are not stored.
--- @param program string: The path to the debugee executable
--- @param args_str string: The argument string to store
function M.add_to_args_history(program, args_str)
   if args_str == '' then
      return
   end
   local history = M.data.args_history[program] or {}
   -- Remove existing occurrence to avoid duplicates
   for i, v in ipairs(history) do
      if v == args_str then
         table.remove(history, i)
         break
      end
   end
   table.insert(history, 1, args_str)
   M.data.args_history[program] = history
end

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
      M.data.args_history = data.args_history or {}
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
      args_history = M.data.args_history,
   }
   vim.fn.writefile({ vim.fn.json_encode(all_states) }, state_file)
end

return M

