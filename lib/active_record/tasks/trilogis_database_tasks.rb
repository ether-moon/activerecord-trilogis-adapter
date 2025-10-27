# frozen_string_literal: true

# Register Trilogis adapter to use MySQL database tasks
# This ensures rake db:create, db:drop, etc. work correctly
ActiveRecord::Tasks::DatabaseTasks.register_task(
  "trilogis",
  "ActiveRecord::Tasks::MySQLDatabaseTasks"
)
