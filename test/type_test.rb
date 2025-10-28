# frozen_string_literal: true

require "test_helper"

class TypeTest < ActiveSupport::TestCase
  def test_parse_simple_type
    assert_equal ["geometry", 0], ActiveRecord::Type::Spatial.parse_sql_type("geometry")
    assert_equal ["geography", 0], ActiveRecord::Type::Spatial.parse_sql_type("geography")
  end

  def test_parse_non_geo_types
    assert_equal ["x", 0], ActiveRecord::Type::Spatial.parse_sql_type("x")
    assert_equal ["foo", 0], ActiveRecord::Type::Spatial.parse_sql_type("foo")
    assert_equal ["foo(A,1234)", 0], ActiveRecord::Type::Spatial.parse_sql_type("foo(A,1234)")
  end
end
