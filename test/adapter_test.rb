# frozen_string_literal: true

require_relative "test_helper"

class AdapterTest < ActiveSupport::TestCase
  def test_adapter_name
    assert_equal "Trilogis", SpatialModel.lease_connection.adapter_name
  end

  def test_supports_spatial
    assert_predicate SpatialModel.lease_connection, :supports_spatial?
  end

  def test_spatial_types_registered
    connection = SpatialModel.lease_connection
    type_map = connection.send(:type_map)

    %i[geometry point linestring polygon].each do |type|
      spatial_type = type_map.lookup(type.to_s)

      assert_kind_of ActiveRecord::Type::Spatial, spatial_type,
                     "Expected #{type} to be registered as Spatial type, got #{spatial_type.class}"
    end
  end

  def test_native_database_types_includes_spatial
    types = SpatialModel.lease_connection.native_database_types
    spatial_types = %i[geometry point linestring polygon]

    # Verify all spatial types are present (counts as 1 assertion)
    missing_types = spatial_types - types.keys

    assert_empty missing_types, "Missing spatial types: #{missing_types.join(', ')}"
  end

  def test_spatial_type_registration_does_not_change_plain_trilogy
    spatial = SpatialModel.lease_connection
    plain = ActiveRecord::ConnectionAdapters::TrilogyAdapter.new(ActiveRecord::Base.test_connection_hash)
    spatial.send(:type_map).lookup("point")

    refute_kind_of ActiveRecord::Type::Spatial, plain.send(:type_map).lookup("point")
    assert_kind_of ActiveRecord::Type::Spatial, spatial.send(:type_map).lookup("geomcollection")
    assert ActiveRecord::ConnectionAdapters::TrilogisAdapter.valid_type?(:multi_polygon)
  ensure
    plain&.disconnect!
  end

  def test_new_connections_do_not_register_global_factories
    registry_size = spatial_factory_store.registry.size
    adapters = Array.new(3) do
      ActiveRecord::ConnectionAdapters::TrilogisAdapter.new(ActiveRecord::Base.test_connection_hash)
    end

    assert_equal registry_size, spatial_factory_store.registry.size
  ensure
    adapters&.each(&:disconnect!)
  end

  def test_custom_factory_is_used_when_reading_from_mysql
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) { |t| t.point :location, srid: 4326 }
    SpatialModel.reset_column_information
    custom = RGeo::Cartesian.preferred_factory(srid: 4326, buffer_resolution: 16)
    spatial_factory_store.register(custom, srid: 4326)
    object = SpatialModel.create!(location: custom.point(35, 45))

    assert_equal custom, object.reload.location.factory
  end
end
