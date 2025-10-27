# frozen_string_literal: true

require "test_helper"

class TypeTest < ActiveSupport::TestCase
  def test_parse_simple_type
    assert_equal ["geometry", 0], spatial.parse_sql_type("geometry")
    assert_equal ["geography", 0], spatial.parse_sql_type("geography")
  end

  def test_parse_non_geo_types
    assert_equal ["x", 0], spatial.parse_sql_type("x")
    assert_equal ["foo", 0], spatial.parse_sql_type("foo")
    assert_equal ["foo(A,1234)", 0], spatial.parse_sql_type("foo(A,1234)")
  end

  private

  def spatial
    ActiveRecord::Type::Spatial
  end
end
