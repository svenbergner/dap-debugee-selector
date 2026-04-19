local M = {}

--- Updates the DAP cpp configuration with the given program and arguments
--- @param program string: The path to the debugee executable
--- @param args table: The list of arguments to pass to the debugee
function M.update_config(program, args)
   local ok, dap = pcall(require, 'dap')
   if ok and dap.configurations.cpp and dap.configurations.cpp[1] then
      ---@diagnostic disable-next-line: inject-field
      dap.configurations.cpp[1].program = program
      ---@diagnostic disable-next-line: inject-field
      dap.configurations.cpp[1].args = args
   end
end

return M

