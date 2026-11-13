# frozen_string_literal: true

require "test_helper"
require "open3"

class TypeTest < Minitest::Test
  def test_constructor_parses_spatial_type_and_srid
    { "POINT" => ["point", 0], "geometry(Point,4326)" => ["point", 4326],
      "geometry(MultiPolygon,3857)" => ["multipolygon", 3857] }.each do |sql_type, expected|
      type = ActiveRecord::Type::Spatial.new(sql_type)

      assert_equal expected, [type.geo_type, type.srid]
    end
  end

  def test_plain_wkt_uses_column_srid_and_ewkt_uses_its_explicit_srid
    type = ActiveRecord::Type::Spatial.new("geometry(point,4326)")
    plain = type.cast("POINT(35 45)")
    explicit = type.cast("SRID=3857;POINT(35 45)")

    assert_equal [4326, 35, 45], [plain.srid, plain.x, plain.y]
    assert_equal [3857, 35, 45], [explicit.srid, explicit.x, explicit.y]
  end

  def test_mysql_binary_and_hex_values_deserialize_with_stored_srid
    point = RGeo::Cartesian.preferred_factory(srid: 3857).point(1, 2)
    binary = [3857].pack("V") + point.as_binary

    assert_equal point, spatial.deserialize(binary)
    assert_equal point, spatial.deserialize(binary.unpack1("H*"))
    refute spatial.changed_in_place?(binary, point)
  end

  def test_invalid_wkt_keeps_nil_casting_behavior
    assert_nil spatial.cast("POINT(bad)")
    assert_nil spatial.cast("")
    assert_nil spatial.serialize(nil)
  end

  def test_geojson_without_optional_library_has_an_actionable_error
    error = assert_raises(ArgumentError) do
      spatial.cast(type: "Point", coordinates: [1, 2])
    end

    assert_includes error.message, "rgeo-geojson"
  end

  def test_geojson_hash_with_optional_library
    # Load the optional library in a separate process so missing-library coverage stays valid.
    output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "-e", <<~RUBY)
      require "activerecord-trilogis-adapter"
      require "rgeo/geo_json"
      type = ActiveRecord::Type::Spatial.new("geometry(point,4326)")
      point = type.cast(type: "Point", coordinates: [139.7, 35.7])
      raise "Unexpected geometry" unless [point.srid, point.x, point.y] == [4326, 139.7, 35.7]
    RUBY

    assert_predicate status, :success?, output
  end

  private

  def spatial
    @spatial ||= ActiveRecord::Type::Spatial.new
  end
end
