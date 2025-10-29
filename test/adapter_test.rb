# frozen_string_literal: true

require_relative "test_helper"

class AdapterTest < ActiveSupport::TestCase
  def test_adapter_name
    assert_equal "Trilogis", SpatialModel.connection.adapter_name
  end

  def test_supports_spatial
    assert_predicate SpatialModel.connection, :supports_spatial?
  end

  def test_spatial_types_registered
    connection = SpatialModel.connection
    type_map = connection.send(:type_map)

    %i[geometry point linestring polygon].each do |type|
      spatial_type = type_map.lookup(type.to_s)

      assert_kind_of ActiveRecord::Type::Spatial, spatial_type,
                     "Expected #{type} to be registered as Spatial type, got #{spatial_type.class}"
    end
  end

  def test_native_database_types_includes_spatial
    types = SpatialModel.connection.native_database_types
    spatial_types = %i[geometry point linestring polygon]

    # Verify all spatial types are present (counts as 1 assertion)
    missing_types = spatial_types - types.keys

    assert_empty missing_types, "Missing spatial types: #{missing_types.join(', ')}"
  end
end
