# frozen_string_literal: true

require_relative "test_helper"

class AxisOrderTest < ActiveSupport::TestCase
  def setup
    super
    @connection = SpatialModel.connection
  end

  def test_axis_order_constant_defined
    assert_equal "'axis-order=long-lat'", ActiveRecord::ConnectionAdapters::TrilogisAdapter::AXIS_ORDER_LONG_LAT
  end

  def test_quote_includes_axis_order_for_geographic_srid
    # Create a point with SRID 4326 (geographic)
    factory = RGeo::Cartesian.factory(srid: 4326)
    point = factory.point(139.7, 35.7) # Tokyo (longitude, latitude)

    quoted = @connection.quote(point)

    # For SRID 4326, should use ST_GeomFromWKB with axis-order
    # ST_GeomFromWKB DOES support axis-order parameter in MySQL 8.0+
    assert_match(/ST_GeomFromWKB/, quoted)
    assert_match(/4326/, quoted) # SRID should be included
    assert_match(/'axis-order=long-lat'/, quoted) # axis-order should be included
  end

  def test_quote_without_axis_order_for_planar_srid
    # Create a point with SRID 3857 (planar/Web Mercator)
    factory = RGeo::Cartesian.factory(srid: 3857)
    point = factory.point(15_565_731, 4_257_421) # Tokyo in Web Mercator

    quoted = @connection.quote(point)

    # For non-geographic SRIDs, should use ST_GeomFromWKB without axis-order
    assert_match(/ST_GeomFromWKB/, quoted)
    assert_match(/3857/, quoted) # SRID should be included
    refute_match(/'axis-order=long-lat'/, quoted) # no axis-order for planar
  end

  def test_arel_visitor_includes_axis_order
    visitor = Arel::Visitors::Trilogis.new(@connection)
    collector = Arel::Collectors::SQLString.new

    # Test with RGeo object
    factory = RGeo::Cartesian.factory(srid: 4326)
    point = factory.point(139.7, 35.7)

    visitor.visit_RGeo_Feature_Instance(point, collector)

    result = collector.value

    assert_match(/ST_GeomFromText/, result)
    assert_match(/4326/, result) # SRID should be included
    assert_match(/'axis-order=long-lat'/, result) # axis-order should be included
  end

  def test_wkt_string_without_srid_no_axis_order
    visitor = Arel::Visitors::Trilogis.new(@connection)
    collector = Arel::Collectors::SQLString.new

    # Test with plain WKT string (no SRID)
    wkt = "POINT(139.7 35.7)"
    visitor.visit_wkt_string(wkt, collector)

    result = collector.value

    # Verify ST_GeomFromText with correct WKT and SRID 0
    assert_match(/ST_GeomFromText\('POINT\(139.7 35.7\)', 0\)$/, result)
    # Ensure no axis-order for non-geographic SRID
    refute_match(/'axis-order=long-lat'/, result)
  end

  def test_ewkt_string_with_srid_includes_axis_order
    visitor = Arel::Visitors::Trilogis.new(@connection)
    collector = Arel::Collectors::SQLString.new

    # Test with EWKT string (includes SRID)
    ewkt = "SRID=4326;POINT(139.7 35.7)"
    visitor.visit_wkt_string(ewkt, collector)

    result = collector.value

    assert_match(/ST_GeomFromText/, result)
    assert_match(/4326/, result) # SRID should be extracted and included
    assert_match(/'axis-order=long-lat'/, result) # axis-order should be included
  end

  def test_geographic_coordinates_work_correctly_end_to_end
    # End-to-end test: Create table, save geographic point, verify coordinates
    SpatialModel.connection.create_table(:spatial_models, force: true) do |t|
      t.point :location, srid: 4326
    end
    SpatialModel.reset_column_information

    # Create point with geographic coordinates (longitude, latitude)
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    tokyo = factory.point(139.7, 35.7) # Tokyo: 139.7°E, 35.7°N

    obj = SpatialModel.new
    obj.location = tokyo
    obj.save!

    # Reload and verify coordinates are preserved correctly
    obj2 = SpatialModel.find(obj.id)

    assert_in_delta 139.7, obj2.location.longitude, 0.01
    assert_in_delta 35.7, obj2.location.latitude, 0.01
    assert_equal 4326, obj2.location.srid
  ensure
    SpatialModel.connection.drop_table(:spatial_models, if_exists: true)
  end

  def test_arel_visitor_no_axis_order_for_non_geographic_srid
    visitor = Arel::Visitors::Trilogis.new(@connection)
    collector = Arel::Collectors::SQLString.new

    # Test with SRID 3857 (Web Mercator, planar)
    factory = RGeo::Cartesian.factory(srid: 3857)
    point = factory.point(15_565_731, 4_257_421)

    visitor.visit_RGeo_Feature_Instance(point, collector)

    result = collector.value

    assert_match(/ST_GeomFromText/, result)
    assert_match(/3857/, result) # SRID should be included
    refute_match(/'axis-order=long-lat'/, result) # No axis-order for non-geographic
  end
end
