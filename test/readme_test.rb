# frozen_string_literal: true

require "test_helper"

class ReadmeTest < ActiveSupport::TestCase
  def test_point_creation_reload_ewkt_update_and_distance_query
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) do |t|
      t.string :name
      t.point :location, srid: 4326, null: false
      t.index :location, type: :spatial
    end
    SpatialModel.reset_column_information
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    place = SpatialModel.create!(name: "Tokyo", location: factory.point(139.7, 35.7))

    assert_equal [139.7, 35.7], [place.reload.location.longitude, place.location.latitude]
    place.update!(location: "SRID=4326;POINT(139.7 35.7)")
    location = SpatialModel.arel_table[:location]
    nearby = SpatialModel.where(location.st_distance_sphere(factory.point(139.7, 35.7)).lt(1000))

    assert_equal [place.id], nearby.pluck(:id)
    place.update!(location: "POINT(139.8 35.8)")

    assert_equal [4326, 139.8, 35.8], [place.reload.location.srid, place.location.longitude, place.location.latitude]
  end
end
