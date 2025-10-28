# frozen_string_literal: true

require_relative "test_helper"

class FeatureParityTest < ActiveSupport::TestCase
  def setup
    super
    @connection = SpatialModel.connection
  end

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
    if @connection.mariadb?
      refute_predicate @connection, :supports_spatial?
    elsif @connection.database_version >= "5.7.6"
      # For MySQL, depends on version
      assert_predicate @connection, :supports_spatial?
    else
      refute_predicate @connection, :supports_spatial?
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
      assert_includes ActiveRecord::ConnectionAdapters::TrilogisAdapter::SPATIAL_COLUMN_TYPES, type,
                      "Missing spatial type: #{type}"
    end
  end

  def test_table_definition_includes_basic_spatial_methods
    td = ActiveRecord::ConnectionAdapters::Trilogis::TableDefinition.new(
      @connection, :test_table
    )

    assert_respond_to td, :spatial
    assert_respond_to td, :geometry
    assert_respond_to td, :point
  end

  def test_table_definition_includes_all_geometry_types
    td = ActiveRecord::ConnectionAdapters::Trilogis::TableDefinition.new(
      @connection, :test_table
    )

    geometry_methods = %i[linestring polygon multipoint multilinestring multipolygon geometrycollection]
    missing_methods = geometry_methods.reject { |m| td.respond_to?(m) }

    assert_empty missing_methods, "Missing geometry methods: #{missing_methods.join(', ')}"
  end

  def test_table_definition_includes_method_aliases
    td = ActiveRecord::ConnectionAdapters::Trilogis::TableDefinition.new(
      @connection, :test_table
    )

    # Test underscored aliases are available
    assert_respond_to td, :line_string, "line_string alias should exist"
    assert_respond_to td, :multi_point, "multi_point alias should exist"
    assert_respond_to td, :geometry_collection, "geometry_collection alias should exist"
  end

  def test_arel_attributes_include_spatial_expressions
    skip unless defined?(Arel::Attribute)

    assert_includes Arel::Attribute.included_modules, RGeo::ActiveRecord::Trilogis::SpatialExpressions
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
      assert_includes RGeo::ActiveRecord::Trilogis::SpatialExpressions.instance_methods, func.to_sym,
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

      assert_path_exists full_path, "Required file missing: #{file}"
    end
  end
end
