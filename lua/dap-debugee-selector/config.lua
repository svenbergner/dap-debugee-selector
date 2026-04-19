local M = {}

--- Default plugin configuration
M.defaults = {
   --- Patterns used to exclude entries from the executable finder.
   --- Any executable whose path matches one of these substrings is hidden.
   exclude_patterns = {
      'Frameworks',
      'plugins ',
      'CMakeFiles',
      '.dylib',
      'jdk/bin',
      'jdk/lib',
      'Resources',
   },
}

--- Active configuration (starts as a copy of the defaults)
M.options = vim.deepcopy(M.defaults)

--- Merge user-supplied options into the active configuration.
--- Only known keys are accepted; unknown keys are silently ignored.
--- @param user_opts table|nil: User options from the setup() call
function M.setup(user_opts)
   if type(user_opts) ~= 'table' then
      return
   end
   if type(user_opts.exclude_patterns) == 'table' then
      M.options.exclude_patterns = user_opts.exclude_patterns
   end
end

return M

