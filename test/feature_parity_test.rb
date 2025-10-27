# frozen_string_literal: true

require_relative "test_helper"

class FeatureParityTest < ActiveSupport::TestCase
  def test_spatial_column_info_available
    assert defined?(ActiveRecord::ConnectionAdapters::Trilogis::SpatialColumnInfo)
  end

  def test_spatial_expressions_available
    assert defined?(RGeo::ActiveRecord::Trilogis::SpatialExpressions)
  end

  def test_database_tasks_registered
    # Database tasks should be registered for trilogis adapter
    assert ActiveRecord::Tasks::DatabaseTasks.send(:class_for_adapter, "trilogis")
  end

  def test_column_methods_available
    assert defined?(ActiveRecord::ConnectionAdapters::Trilogis::ColumnMethods)
  end

  def test_supports_spatial_with_version_check
    connection = ActiveRecord::Base.connection
    if connection.mariadb?
      assert_equal false, connection.supports_spatial?
    elsif connection.version >= "5.7.6"
      # For MySQL, depends on version
      assert_equal true, connection.supports_spatial?
    else
      assert_equal false, connection.supports_spatial?
    end
  end

  def test_spatial_column_types_all_defined
    expected_types = %w[
      geometry
      point
      linestring
      polygon
      multipoint
      multilinestring
      multipolygon
      geometrycollection
    ]

    expected_types.each do |type|
      assert ActiveRecord::ConnectionAdapters::TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(type),
             "Missing spatial type: #{type}"
    end
  end

  def test_table_definition_includes_column_methods
    td = ActiveRecord::ConnectionAdapters::Trilogis::TableDefinition.new(
      ActiveRecord::Base.connection, :test_table
    )

    # Test that all spatial methods are available
    assert td.respond_to?(:spatial)
    assert td.respond_to?(:geometry)
    assert td.respond_to?(:point)
    assert td.respond_to?(:linestring)
    assert td.respond_to?(:polygon)
    assert td.respond_to?(:multipoint)
    assert td.respond_to?(:multilinestring)
    assert td.respond_to?(:multipolygon)
    assert td.respond_to?(:geometrycollection)

    # Test aliases
    assert td.respond_to?(:line_string)
    assert td.respond_to?(:multi_line_string)
    assert td.respond_to?(:multi_point)
    assert td.respond_to?(:multi_polygon)
    assert td.respond_to?(:geometry_collection)
  end

  def test_arel_attributes_include_spatial_expressions
    return unless defined?(Arel::Attribute)

    assert Arel::Attribute.included_modules.include?(
      RGeo::ActiveRecord::Trilogis::SpatialExpressions
    )
  end

  def test_axis_order_constant_defined
    assert defined?(ActiveRecord::ConnectionAdapters::TrilogisAdapter::AXIS_ORDER_LONG_LAT),
           "AXIS_ORDER_LONG_LAT constant should be defined for MySQL 8.0+ coordinate fix"
  end

  def test_spatial_functions_available
    spatial_functions = %w[
      st_distance_sphere
      st_contains
      st_within
      st_intersects
      st_buffer
      st_equals
      st_area
      st_length
    ]

    spatial_functions.each do |func|
      assert RGeo::ActiveRecord::Trilogis::SpatialExpressions.instance_methods.include?(func.to_sym),
             "Spatial function #{func} should be available"
    end
  end

  def test_required_files_exist
    required_files = [
      "lib/active_record/connection_adapters/trilogis_adapter.rb",
      "lib/activerecord-trilogis-adapter.rb",
      "lib/active_record/connection_adapters/trilogis/spatial_column.rb",
      "lib/active_record/connection_adapters/trilogis/spatial_table_definition.rb",
      "lib/active_record/connection_adapters/trilogis/schema_statements.rb",
      "lib/active_record/connection_adapters/trilogis/arel_tosql.rb",
      "lib/active_record/type/spatial.rb",
      "lib/active_record/connection_adapters/trilogis/spatial_column_info.rb",
      "lib/active_record/connection_adapters/trilogis/spatial_expressions.rb",
      "lib/active_record/tasks/trilogis_database_tasks.rb"
    ]

    required_files.each do |file|
      full_path = File.join(File.dirname(__dir__), file)
      assert File.exist?(full_path), "Required file missing: #{file}"
    end
  end
end
