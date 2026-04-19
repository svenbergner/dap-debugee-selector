local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local utils = require('telescope.previewers.utils')
local config = require('telescope.config').values

local log = require('plenary.log'):new()
-- log.level = 'debug'

local state = require('dap-debugee-selector.state')
local dap_helper = require('dap-debugee-selector.dap')

local M = {}

--- Patterns used to exclude entries from the executable finder
local EXCLUDE_PATTERNS = {
   'Frameworks',
   'plugins ',
   'CMakeFiles',
   '.dylib',
   'jdk/bin',
   'jdk/lib',
   'Resources',
}

--- Returns true if the entry matches any of the exclude patterns
--- @param entry string: The file path to check
--- @return boolean
local function is_excluded(entry)
   for _, pattern in ipairs(EXCLUDE_PATTERNS) do
      if string.find(entry, pattern) then
         return true
      end
   end
   return false
end

local function update_notification(message, title, level, timeout)
   level = level or 'info'
   timeout = timeout or 3000
   if #message < 1 then
      return
   end
   message = string.gsub(message, '\n.*$', '')
   vim.notify(message, level, {
      id = title,
      title = title,
      position = { row = 1, col = '100%' },
      timeout = timeout,
   })
end

--- Removes the searchPathRoot from the given filepath
--- @param filepath string: The full file path
--- @return string: The shortened file path
local function get_shortened_file_path(filepath)
   return '...' .. string.sub(filepath, string.len(state.data.searchPathRoot) + 1)
end

--- Returns the filename from a given filepath
--- @param filepath string: The full file path
--- @return string: The filename extracted from the file path
local function get_filename_from_filepath(filepath)
   return vim.fs.basename(filepath)
end

--- Get file information
--- @param filepath string: The full file path
--- @return table: The file information
local function get_file_info(filepath)
   local output = {}
   table.insert(output, 'Filename: ' .. get_filename_from_filepath(filepath))
   table.insert(output, 'Fullpath: ' .. filepath)
   table.insert(output, 'Size: ' .. vim.fn.getfsize(filepath) / 1024 .. ' kb')
   table.insert(output, 'Date: ' .. vim.fn.strftime('%H:%M:%S %d.%m.%Y', vim.fn.getftime(filepath)))
   return output
end

--- Get the preset name from the given entry line
--- @param entry string: The entry to extract the preset from
--- @return string: The preset name
local function get_preset_from_entry(entry)
   local startOfPreset = entry:find('"', 1) + 1
   if startOfPreset == nil then
      return ''
   end
   local endOfPreset = entry:find('"', startOfPreset + 1) - 1
   return entry:sub(startOfPreset, endOfPreset)
end

--- Get the description from the given entry line
--- @param entry string: The entry to extract the description from
--- @return string: The description
local function get_desc_from_entry(entry)
   local entryLen = #entry
   local startOfDesc = entry:find('- ', 1) + 2
   if startOfDesc == nil then
      return ''
   end
   return entry:sub(startOfDesc, entryLen)
end

--- Runs cmake with the given preset and calls callback with opts on success
--- @param preset string: The cmake preset name
--- @param callback_opts any: Options forwarded to the callback
--- @param callback function: Called with callback_opts when cmake succeeds
local function run_cmake_preset(preset, callback_opts, callback)
   local buildPath = ''
   local cmd = 'cmake --preset=' .. preset
   local searchString = 'Build files have been written to: '

   update_notification('CMake configure for preset: ' .. preset, 'CMake Preset', 'info', 5000)

   vim.fn.jobstart(cmd, {
      stdout_buffered = false,
      stderr_buffered = true,
      on_stdout = function(_, data)
         if data then
            for _, line in ipairs(data) do
               local buildPathStart = string.find(line, searchString)
               if buildPathStart then
                  buildPath = string.sub(line, buildPathStart + #searchString, -1)
               end
            end
         end
      end,
      on_exit = function(_, code)
         if code == 0 then
            state.data.searchPathRoot = buildPath
            callback(callback_opts)
         else
            state.data.searchPathRoot = ''
         end
      end,
   })
end

--- Opens a picker to select a cmake preset and then runs cmake configure
--- @param callback_opts any: Options forwarded to the executable picker
--- @param callback function: Called after successful cmake configure
function M.get_build_path_for_configuration(callback_opts, callback)
   local opts = {
      results_title = 'CMake Presets',
      prompt_title = '',
      default_selection_index = state.data.last_selected_index,
      layout_strategy = 'horizontal',
      layout_config = {
         width = 50,
         height = 16,
      },
   }
   pickers
      .new(opts, {
         finder = finders.new_async_job({
            command_generator = function()
               state.data.current_index = 0
               return { 'cmake', '--list-presets' }
            end,
            entry_maker = function(entry)
               if not string.find(entry, '"') then
                  return nil
               end
               state.data.current_index = state.data.current_index + 1
               local preset = get_preset_from_entry(entry)
               local description = get_desc_from_entry(entry)
               return {
                  value = preset,
                  display = description,
                  ordinal = entry,
                  index = state.data.current_index,
               }
            end,
         }),

         sorter = config.generic_sorter(opts),

         attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
               local selected = actions_state.get_selected_entry()
               state.data.last_selected_index = selected.index - 2
               actions.close(prompt_bufnr)
               state.save()

               local api = vim.api
               api.nvim_cmd({ cmd = 'wa' }, {}) -- save all buffers
               run_cmake_preset(selected.value, callback_opts, callback)
            end)
            return true
         end,
      })
      :find()
end

--- Show a list of all executables in the selected path
--- @param opts any: The options for the picker
function M.show_debugee_candidates(opts)
   if state.data.searchPathRoot == '' then
      state.data.searchPathRoot = vim.fn.getcwd() .. '/'
      state.data.searchPathRoot = vim.fn.input('Path to executable: ', state.data.searchPathRoot, 'dir')
   end
   opts = opts
      or {
         results_title = 'Debugee Selector',
         prompt_title = 'Select Debugee Executable',
         layout_config = {
            preview_width = 0.4,
         },
      }
   pickers
      .new(opts, {
         finder = finders.new_async_job({
            command_generator = function()
               ---@diagnostic disable-next-line: undefined-field
               if vim.loop.os_uname().sysname == 'Darwin' then
                  return { 'find', state.data.searchPathRoot, '-perm', '+111', '-type', 'f' }
               else
                  return { 'find', state.data.searchPathRoot, '-executable', '-type', 'f' }
               end
            end,
            entry_maker = function(entry)
               if is_excluded(entry) then
                  return nil
               end
               return {
                  value = entry,
                  display = get_shortened_file_path(entry),
                  ordinal = entry,
               }
            end,
         }),

         sorter = config.generic_sorter(opts),

         previewer = previewers.new_buffer_previewer({
            title = 'Debuggee Details',
            define_preview = function(self, entry)
               vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, get_file_info(entry.value))
               utils.highlighter(self.state.bufnr, 'markdown')
               vim.api.nvim_set_option_value('wrap', true, { win = self.state.winid })
            end,
         }),

         attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
               local selectedFilePath = actions_state.get_selected_entry().value
               log.debug('attach_mappings', selectedFilePath)
               actions.close(prompt_bufnr)

               state.data.last_program = selectedFilePath
               state.save()

               M.show_args_picker(selectedFilePath, function(args_str)
                  state.data.last_debugee_args = args_str
                  state.add_to_args_history(selectedFilePath, args_str)
                  state.save()
                  dap_helper.update_config(selectedFilePath, state.parse_args(args_str))
               end)
            end)
            return true
         end,
      })
      :find()
end

--- Opens a Telescope picker showing the args history for the given program.
--- The prompt field acts as the edit field: navigating up/down pre-fills it
--- with the selected entry. Enter confirms the current prompt text directly.
--- <C-d> deletes the highlighted history entry.
--- Calls callback(args_str) with the confirmed argument string.
--- @param program string: The path to the debugee executable
--- @param callback function: Called with the chosen argument string
function M.show_args_picker(program, callback)
   local sorters = require('telescope.sorters')
   local history = state.data.args_history[program] or {}

   -- +5 accounts for borders, separator, prompt line and padding
   local desired_height = math.max(#history + 5, 6)
   local max_height = math.floor(vim.o.lines * 0.8)

   local opts = {
      results_title = 'Argument History  <C-n> new  <C-d> delete',
      prompt_title = vim.fs.basename(program),
      default_text = history[1] or '',
      layout_strategy = 'horizontal',
      layout_config = {
         width = 80,
         height = math.min(desired_height, max_height),
      },
   }

   --- Fills the prompt with the value of the currently selected entry.
   --- Preserves the selection row because set_prompt triggers a re-render that
   --- would otherwise reset it to the first entry.
   --- A double vim.schedule ensures we run after all of Telescope's own
   --- re-render callbacks have completed.
   local function sync_prompt(prompt_bufnr)
      local picker = actions_state.get_current_picker(prompt_bufnr)
      local entry = actions_state.get_selected_entry()
      if entry then
         local row = picker:get_selection_row()
         picker:set_prompt(entry.value)
         vim.schedule(function()
            vim.schedule(function()
               picker:set_selection(row)
            end)
         end)
      end
   end

   pickers
      .new(opts, {
         finder = finders.new_table({
            results = history,
            entry_maker = function(entry)
               return { value = entry, display = entry, ordinal = entry }
            end,
         }),
         -- Empty sorter: prompt text is used for editing only, not for filtering
         sorter = sorters.empty(),
         attach_mappings = function(prompt_bufnr, map)
            -- Navigation fills the prompt with the selected entry.
            -- vim.schedule ensures the move has settled before we read the selection.
            local function move_and_sync(move_fn)
               move_fn(prompt_bufnr)
               vim.schedule(function()
                  sync_prompt(prompt_bufnr)
               end)
            end

            map('i', '<Down>', function() move_and_sync(actions.move_selection_next) end)
            map('i', '<Up>',   function() move_and_sync(actions.move_selection_previous) end)

            -- Clear the prompt to enter a completely new argument string
            map('i', '<C-n>', function()
               actions_state.get_current_picker(prompt_bufnr):set_prompt('')
            end)

            -- Delete the highlighted history entry and reopen
            map('i', '<C-d>', function()
               local selected = actions_state.get_selected_entry()
               if selected then
                  local prog_history = state.data.args_history[program] or {}
                  for i, v in ipairs(prog_history) do
                     if v == selected.value then
                        table.remove(prog_history, i)
                        break
                     end
                  end
                  state.data.args_history[program] = prog_history
                  state.save()
                  actions.close(prompt_bufnr)
                  vim.schedule(function()
                     M.show_args_picker(program, callback)
                  end)
               end
            end)

            -- Confirm: use the current prompt text as the final argument string
            actions.select_default:replace(function()
               local args_str = actions_state.get_current_picker(prompt_bufnr):_get_prompt()
               actions.close(prompt_bufnr)
               if args_str ~= '' then
                  state.add_to_args_history(program, args_str)
                  state.save()
               end
               callback(args_str)
            end)
            return true
         end,
      })
      :find()
end

return M

