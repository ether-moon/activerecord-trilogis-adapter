# frozen_string_literal: true

require_relative "test_helper"

class AxisOrderTest < ActiveSupport::TestCase
  def test_axis_order_constant_defined
    assert_equal "'axis-order=long-lat'", ActiveRecord::ConnectionAdapters::TrilogisAdapter::AXIS_ORDER_LONG_LAT
  end

  def test_quote_includes_axis_order
    # Create a point with specific coordinates
    factory = RGeo::Cartesian.factory(srid: 4326)
    point = factory.point(139.7, 35.7) # Tokyo (longitude, latitude)

    quoted = ActiveRecord::Base.connection.quote(point)

    # Should use ST_GeomFromWKB with SRID and axis-order option
    assert_match(/ST_GeomFromWKB/, quoted)
    assert_match(/4326/, quoted) # SRID should be included
    assert_match(/'axis-order=long-lat'/, quoted) # axis-order should be included
  end

  def test_arel_visitor_includes_axis_order
    visitor = Arel::Visitors::Trilogis.new(ActiveRecord::Base.connection)
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

  def test_wkt_string_includes_axis_order
    visitor = Arel::Visitors::Trilogis.new(ActiveRecord::Base.connection)
    collector = Arel::Collectors::SQLString.new

    # Test with WKT string
    wkt = "POINT(139.7 35.7)"
    visitor.visit_wkt_string(wkt, collector)

    result = collector.value
    assert_match(/ST_GeomFromText/, result)
    assert_match(/'axis-order=long-lat'/, result) # axis-order should be included
  end

  def test_ewkt_string_with_srid_includes_axis_order
    visitor = Arel::Visitors::Trilogis.new(ActiveRecord::Base.connection)
    collector = Arel::Collectors::SQLString.new

    # Test with EWKT string (includes SRID)
    ewkt = "SRID=4326;POINT(139.7 35.7)"
    visitor.visit_wkt_string(ewkt, collector)

    result = collector.value
    assert_match(/ST_GeomFromText/, result)
    assert_match(/4326/, result) # SRID should be extracted and included
    assert_match(/'axis-order=long-lat'/, result) # axis-order should be included
  end
end
