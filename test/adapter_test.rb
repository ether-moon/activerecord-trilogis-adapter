# frozen_string_literal: true

require_relative "test_helper"

class AdapterTest < ActiveSupport::TestCase
  def test_adapter_name
    assert_equal "Trilogis", ActiveRecord::Base.connection.adapter_name
  end

  def test_supports_spatial
    assert ActiveRecord::Base.connection.supports_spatial?
  end

  def test_spatial_types_registered
    %i[geometry point linestring polygon].each do |type|
      assert(ActiveRecord::Type.registry.send(:registrations).any? do |r|
        r.send(:matches?, type, :trilogis)
      end)
    end
  end

  def test_native_database_types_includes_spatial
    types = ActiveRecord::Base.connection.native_database_types
    assert types.key?(:geometry)
    assert types.key?(:point)
    assert types.key?(:linestring)
    assert types.key?(:polygon)
  end
end
