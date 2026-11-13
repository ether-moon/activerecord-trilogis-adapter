# frozen_string_literal: true

require "active_record"

require "active_record/connection_adapters/trilogy_adapter"
require "rgeo"
require "rgeo/active_record"

# Load the adapter
require_relative "active_record/connection_adapters/trilogis_adapter"
