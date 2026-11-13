# frozen_string_literal: true

require "test_helper"
require "open3"

class TypeTest < Minitest::Test
  POINT_WKB_HEX = %w[0101000000000000000000F03F0000000000000040 00000000013FF00000000000004000000000000000].freeze

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

  def test_standard_wkb_uses_column_srid_in_both_byte_orders
    type = ActiveRecord::Type::Spatial.new("geometry(point,4326)")
    POINT_WKB_HEX.each do |hex|
      [type.cast(hex), type.deserialize(hex), type.deserialize([hex].pack("H*"))].each do |point|
        refute_nil point
        assert_equal [4326, 1, 2], [point.srid, point.x, point.y]
      end
    end
  end

  def test_mysql_wkb_keeps_prefix_srid_even_when_it_resembles_a_wkb_header
    type = ActiveRecord::Type::Spatial.new("geometry(point,3857)")
    [0, 1, 4326].each do |srid|
      POINT_WKB_HEX.each do |hex|
        binary = [srid].pack("V") + [hex].pack("H*")
        mysql_hex = binary.unpack1("H*")
        [type.cast(mysql_hex), type.deserialize(mysql_hex), type.deserialize(binary)].each do |point|
          refute_nil point
          assert_equal [srid, 1, 2], [point.srid, point.x, point.y]
        end
      end
    end
  end

  def test_malformed_and_trailing_wkb_hex_remains_invalid
    hex = "0101000000000000000000F03F0000000000000040"
    mysql_hex = "E6100000#{hex}"
    [hex, mysql_hex].each do |valid_hex|
      [valid_hex[0...-1], "#{valid_hex}00", "#{valid_hex}\n00"].each do |invalid_hex|
        assert_nil spatial.cast(invalid_hex)
        assert_nil spatial.deserialize(invalid_hex)
      end
    end
  end

  def test_truncated_and_trailing_wkb_binary_remains_invalid
    hex = POINT_WKB_HEX.first
    [hex, "E6100000#{hex}"].each do |valid_hex|
      binary = [valid_hex].pack("H*")

      assert_nil spatial.deserialize(binary.byteslice(0...-1))
      assert_nil spatial.deserialize("#{binary}\x00".b)
    end
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
