require Rails.root.join("lib/seedbench/sqlite_database_tasks")

ActiveRecord::Tasks::DatabaseTasks.register_task(/sqlite/, Seedbench::SqliteDatabaseTasks)
