# frozen_string_literal: true

require "test_helper"

class SecurityTest < ActiveSupport::TestCase
  def test_spatial_strings_are_quoted_as_single_values
    connection = SpatialModel.lease_connection
    payload = "POINT(0 0)', 0)) OR 1=1 -- "
    visitor = connection.visitor
    expressions = [
      SpatialModel.arel_table[:location].st_distance(payload),
      Arel.spatial(payload),
      Arel::Nodes::NamedFunction.new("ST_Distance", [SpatialModel.arel_table[:location], payload])
    ]

    expressions.each do |expression|
      sql = visitor.compile(expression)

      assert_includes sql, connection.quote(payload)
    end
  end

  def test_injected_spatial_predicate_does_not_return_rows
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) { |t| t.point :location }
    SpatialModel.reset_column_information
    SpatialModel.create!(location: RGeo::Cartesian.factory.point(0, 0))
    ["POINT(0 0)', 0)) OR 1=1 -- ", "SRID=0;POINT(0 0)', 0)) OR 1=1 -- "].each do |payload|
      predicate = SpatialModel.arel_table[:location].st_distance(payload).lt(1)

      assert_raises(ActiveRecord::StatementInvalid) { SpatialModel.where(predicate).to_a }
    end
  end

  def test_shift_jis_string_cannot_escape_an_equality_predicate
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) { |t| t.string :name }
    SpatialModel.reset_column_information
    SpatialModel.create!(name: "private")
    payload = "#{[0x83, 0x5c].pack('C*').force_encoding(Encoding::Shift_JIS)}' OR 1=1 -- "

    assert_equal 0, SpatialModel.where(name: payload).count
  end

  def test_runtime_dependencies_reject_unpatched_versions
    spec = Gem::Specification.load(File.expand_path("../activerecord-trilogis-adapter.gemspec", __dir__))
    requirements = spec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement] }

    refute requirements.fetch("trilogy").satisfied_by?(Gem::Version.new("2.13.2"))
    assert requirements.fetch("trilogy").satisfied_by?(Gem::Version.new("2.13.3"))
    refute requirements.fetch("activerecord").satisfied_by?(Gem::Version.new("8.2.0"))
  end
end
