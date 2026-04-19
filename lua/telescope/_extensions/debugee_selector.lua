local state = require('dap-debugee-selector.state')
local dap_helper = require('dap-debugee-selector.dap')
local finder = require('dap-debugee-selector.finder')

-- Load persisted state from disk
state.load()

-- Restore the last selected program/args into the DAP config after all plugins are loaded
vim.schedule(function()
   if state.data.last_program ~= '' then
      dap_helper.update_config(state.data.last_program, state.parse_args(state.data.last_debugee_args))
   end
end)

--- Sets the search path to the default value
local function reset_search_path()
   state.data.searchPathRoot = ''
   state.save()
end

--- Resets the stored debugee arguments
local function reset_debugee_args()
   state.data.last_debugee_args = ''
   state.save()
end

--- Edit the debugee arguments without re-selecting the executable
local function edit_debugee_args()
   finder.show_args_picker(state.data.last_program, function(args_str)
      state.data.last_debugee_args = args_str
      state.add_to_args_history(state.data.last_program, args_str)
      state.save()
      dap_helper.update_config(state.data.last_program, state.parse_args(args_str))
   end)
end

local function get_last_program()
   return state.data.last_program
end

local function get_last_debugee_args()
   return state.data.last_debugee_args
end

--- Register the extension
return require('telescope').register_extension({
   exports = {
      show_debugee_candidates = finder.show_debugee_candidates,
      selectSearchPathRoot = function(opts)
         finder.get_build_path_for_configuration(opts, finder.show_debugee_candidates)
      end,
      reset_search_path = reset_search_path,
      reset_debugee_args = reset_debugee_args,
      edit_debugee_args = edit_debugee_args,
      get_last_program = get_last_program,
      get_last_debugee_args = get_last_debugee_args,
   },
})
