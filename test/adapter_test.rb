# frozen_string_literal: true

require_relative "test_helper"

class AdapterTest < ActiveSupport::TestCase
  def test_adapter_name
    assert_equal "Trilogis", SpatialModel.connection.adapter_name
  end

  def test_supports_spatial
    assert SpatialModel.connection.supports_spatial?
  end

  def test_spatial_types_registered
    connection = SpatialModel.connection
    type_map = connection.send(:type_map)

    %i[geometry point linestring polygon].each do |type|
      spatial_type = type_map.lookup(type.to_s)
      assert spatial_type.is_a?(ActiveRecord::Type::Spatial),
             "Expected #{type} to be registered as Spatial type, got #{spatial_type.class}"
    end
  end

  def test_native_database_types_includes_spatial
    types = SpatialModel.connection.native_database_types
    assert types.key?(:geometry)
    assert types.key?(:point)
    assert types.key?(:linestring)
    assert types.key?(:polygon)
  end
end
