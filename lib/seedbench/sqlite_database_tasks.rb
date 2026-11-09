require 'active_record/tasks/sqlite_database_tasks'

module Seedbench
  class SqliteDatabaseTasks < ActiveRecord::Tasks::SQLiteDatabaseTasks
    def structure_load(filename, extra_flags)
      # Preserve argv boundaries and fail on SQL errors instead of using a shell.
      run_cmd('sqlite3', '-bail', *Array(extra_flags), db_config.database, in: filename)
    end
  end
end
