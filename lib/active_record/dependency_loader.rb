# frozen_string_literal: true

# ActiveRecord dependency loader for all Ruby versions
#
# This file explicitly pre-loads all required ActiveRecord modules in the correct
# dependency order. This approach:
#
# - Ensures consistent loading behavior across all Ruby versions (3.2+)
# - Avoids reliance on Ruby's autoload mechanism, which changed in Ruby 3.4
# - Prevents "uninitialized constant" errors during module inclusion
# - Works with ActiveRecord 8.0+ internal structure
#
# While this was initially created to solve Ruby 3.4 compatibility issues,
# using explicit requires for all versions provides better stability and consistency.

# Layer 0: ConnectionAdapters module setup (defines .resolve method)
require "active_record/connection_adapters"

# Layer 1: Base modules with no dependencies
require "active_record/connection_adapters/deduplicable"

# Layer 2: Abstract adapter modules
require "active_record/connection_adapters/abstract/quoting"
require "active_record/connection_adapters/abstract/database_statements"
require "active_record/connection_adapters/abstract/schema_statements"
require "active_record/connection_adapters/abstract/database_limits"
require "active_record/connection_adapters/abstract/query_cache"
require "active_record/connection_adapters/abstract/savepoints"

# Layer 3: Column and schema definitions
require "active_record/connection_adapters/column"
require "active_record/connection_adapters/abstract/schema_definitions"

# Layer 4: Connection management (needed by ActiveRecord::Base)
require "active_record/connection_adapters/abstract/connection_handler"

# Layer 5: Abstract MySQL adapter (loads MySQL-specific modules)
require "active_record/connection_adapters/abstract_mysql_adapter"
