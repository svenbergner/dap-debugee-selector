local M = {}

M.check = function()
   vim.health.start('Debugee Selector Report')

   -- Check required dependencies
   for _, plugin in ipairs({ 'telescope', 'dap', 'plenary' }) do
      local ok, _ = pcall(require, plugin)
      if ok then
         vim.health.ok(plugin .. ' is installed')
      else
         vim.health.error(plugin .. ' is not installed or could not be loaded')
      end
   end

   -- Check DAP cpp configuration exists
   local dap_ok, dap = pcall(require, 'dap')
   if dap_ok then
      if dap.configurations.cpp and dap.configurations.cpp[1] then
         vim.health.ok('dap.configurations.cpp[1] is configured')
      else
         vim.health.warn('dap.configurations.cpp[1] is not set — debugee selector may not work correctly')
      end
   end

   -- Check state file directory is writable
   local state_dir = vim.fn.stdpath('data')
   if vim.fn.isdirectory(state_dir) == 1 and vim.fn.filewritable(state_dir) == 2 then
      vim.health.ok('State directory is writable: ' .. state_dir)
   else
      vim.health.error('State directory is not writable: ' .. state_dir)
   end

   -- Check last saved program still exists on disk
   local state_file = state_dir .. '/debugee_selector_state.json'
   if vim.fn.filereadable(state_file) == 1 then
      local ok, all_states = pcall(function()
         return vim.fn.json_decode(table.concat(vim.fn.readfile(state_file), '\n'))
      end)
      if ok and type(all_states) == 'table' then
         local project_key = vim.fn.getcwd()
         local data = all_states[project_key]
         if data and data.last_program and data.last_program ~= '' then
            if vim.fn.filereadable(data.last_program) == 1 then
               vim.health.ok('Last program exists: ' .. data.last_program)
            else
               vim.health.warn('Last program no longer exists: ' .. data.last_program)
            end
         else
            vim.health.info('No program saved for current project')
         end
      end
   else
      vim.health.info('No state file found yet — no debugee selected so far')
   end

   -- Check cmake is available in PATH
   if vim.fn.executable('cmake') == 1 then
      vim.health.ok('cmake is available in PATH')
   else
      vim.health.warn('cmake not found in PATH — preset selection will not work')
   end
end

return M
