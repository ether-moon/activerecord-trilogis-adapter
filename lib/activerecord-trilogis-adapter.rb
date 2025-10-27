# frozen_string_literal: true

require "active_record"

# Load ActiveRecord dependencies explicitly to ensure correct loading order
# This approach works across all Ruby versions and avoids autoload issues
require_relative "active_record/dependency_loader"

require "active_record/connection_adapters/trilogy_adapter"
require "rgeo"
require "rgeo/active_record"

# Load the adapter
require_relative "active_record/connection_adapters/trilogis_adapter"

# Load railtie if Rails is defined
require_relative "active_record/connection_adapters/trilogis/railtie" if defined?(Rails)
