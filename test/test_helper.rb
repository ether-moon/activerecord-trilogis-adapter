# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require "activerecord-trilogis-adapter"
require "erb"
require "yaml"
require "rgeo/active_record"

require "byebug" if ENV["BYEBUG"]

module ActiveRecord
  class Base
    DATABASE_CONFIG_PATH = File.join(__dir__, "database.yml")

    def self.test_connection_hash
      YAML.safe_load(ERB.new(File.read(DATABASE_CONFIG_PATH)).result, aliases: true)
    end

    def self.establish_test_connection
      establish_connection test_connection_hash
    end
  end
end

class SpatialModel < ActiveRecord::Base
  establish_test_connection
end

class SpatialMultiModel < ActiveRecord::Base
  establish_test_connection
end

module ActiveSupport
  class TestCase
    self.test_order = :sorted

    def setup
      # Clean up any existing tables before each test
      cleanup_tables
    end

    def teardown
      # Clean up tables after each test
      cleanup_tables
    end

    def factory
      RGeo::Cartesian.preferred_factory(srid: 3857)
    end

    def geographic_factory
      RGeo::Geographic.spherical_factory(srid: 4326)
    end

    def spatial_factory_store
      RGeo::ActiveRecord::SpatialFactoryStore.instance
    end

    private

    def cleanup_tables
      return unless ActiveRecord::Base.connected?

      connection = ActiveRecord::Base.connection
      %w[spatial_models spatial_multi_models foo_bars spatial_test].each do |table|
        connection.drop_table(table) if connection.table_exists?(table)
      rescue ActiveRecord::StatementInvalid
        # Ignore errors during cleanup
      end
    end
  end
end
