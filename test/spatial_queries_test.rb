# frozen_string_literal: true

require "test_helper"

class SpatialQueriesTest < ActiveSupport::TestCase
  def test_query_point
    create_model
    obj = SpatialModel.create!(latlon: factory.point(1, 2))
    id = obj.id
    assert_empty SpatialModel.where(latlon: factory.point(2, 2))
    obj1 = SpatialModel.find_by(latlon: factory.point(1, 2))
    refute_nil(obj1)
    assert_equal id, obj1.id
  end

  def test_query_point_wkt
    create_model
    obj = SpatialModel.create!(latlon: factory.point(1, 2))
    id = obj.id
    obj2 = SpatialModel.find_by(latlon: "SRID=3857;POINT(1 2)")
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = SpatialModel.find_by(latlon: "SRID=3857;POINT(2 2)")
    assert_nil(obj3)
  end

  def test_query_st_distance
    create_model
    obj = SpatialModel.create!(latlon: factory.point(1, 2))
    id = obj.id
    obj2 = SpatialModel.find_by(SpatialModel.arel_table[:latlon].st_distance("SRID=3857;POINT(2 3)").lt(2))
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = SpatialModel.find_by(SpatialModel.arel_table[:latlon].st_distance("SRID=3857;POINT(2 3)").gt(2))
    assert_nil(obj3)
  end

  def test_query_st_distance_from_constant
    create_model
    obj = SpatialModel.create!(latlon: factory.point(1, 2))
    id = obj.id

    # Query with distance less than 2
    point = ::Arel.spatial("SRID=3857;POINT(2 3)")
    distance = point.st_distance(SpatialModel.arel_table[:latlon])
    obj2 = SpatialModel.find_by(distance.lt(2))
    refute_nil(obj2)
    assert_equal(id, obj2.id)

    # Query with distance greater than 2
    obj3 = SpatialModel.find_by(distance.gt(2))
    assert_nil(obj3)
  end

  def test_query_st_length
    create_model
    obj = SpatialModel.new
    obj.path = factory.line(factory.point(1.0, 2.0), factory.point(3.0, 2.0))
    obj.save!
    id = obj.id
    obj2 = SpatialModel.find_by(SpatialModel.arel_table[:path].st_length.eq(2))
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = SpatialModel.find_by(SpatialModel.arel_table[:path].st_length.gt(3))
    assert_nil(obj3)
  end

  private

  def create_model
    SpatialModel.connection.create_table(:spatial_models, force: true) do |t|
      t.column "latlon", :point, srid: 3857
      t.column "points", :multi_point, srid: 3857
      t.column "path", :line_string, srid: 3857
    end
    SpatialModel.reset_column_information
  end
end
