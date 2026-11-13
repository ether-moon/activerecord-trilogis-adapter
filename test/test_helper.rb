# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start { add_filter "/test/" }
end

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

ActiveRecord::Base.establish_test_connection
ActiveRecord.deprecator.behavior = :raise

class SpatialModel < ActiveRecord::Base
end

class SpatialMultiModel < ActiveRecord::Base
end

module ActiveSupport
  class TestCase
    self.test_order = :random

    def setup
      @factory_registry = spatial_factory_store.registry.dup
      cleanup_tables
      ActiveRecord::Base.descendants.each(&:reset_column_information)
    end

    def teardown
      cleanup_tables
      spatial_factory_store.registry = @factory_registry
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
      connection = ActiveRecord::Base.lease_connection
      %w[spatial_models spatial_multi_models foo_bars spatial_test].each do |table|
        connection.drop_table(table, if_exists: true)
      end
      connection.schema_cache.clear!
    end
  end
end
