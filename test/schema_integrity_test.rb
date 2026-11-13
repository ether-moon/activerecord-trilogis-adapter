# frozen_string_literal: true

require "test_helper"
require "tempfile"

# These integration cases compare a single schema contract across reloads.
# rubocop:disable Minitest/MultipleAssertions
class SchemaIntegrityTest < ActiveSupport::TestCase
  def test_same_named_columns_keep_their_own_srid_and_yaml_metadata
    connection = SpatialModel.lease_connection
    columns = [nil, 0, 4326, 3857].map do |srid|
      connection.create_table(:spatial_models, force: true) { |t| t.point :location, srid: srid }
      connection.columns(:spatial_models).find { |column| column.name == "location" }
    end

    assert_equal [0, 0, 4326, 3857], columns.map(&:srid)
    assert_equal [nil, { srid: 0 }, { srid: 4326 }, { srid: 3857 }], columns.map(&:limit)
    assert_equal 4, columns.uniq.size
    columns.each do |column|
      restored = YAML.unsafe_load(YAML.dump(column))

      assert_equal column, restored
      assert_equal column.hash, restored.hash
      assert_equal column.geometric_type, restored.geometric_type
    end
  end

  def test_alias_columns_and_alter_preserve_srid
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) do |t|
      t.column :location, :multi_polygon, srid: 4326
    end

    assert_equal 4326, connection.columns(:spatial_models).last.srid
    connection.change_column_null(:spatial_models, :location, false)
    connection.change_column_comment(:spatial_models, :location, "Area")
    column = connection.columns(:spatial_models).last

    assert_equal 4326, column.srid
    refute column.null
    assert_equal "Area", column.comment
  end

  def test_all_spatial_types_survive_schema_dump_and_load
    connection = SpatialModel.lease_connection
    types = %i[geometry point line_string polygon multi_point multi_line_string multi_polygon geometry_collection]
    [nil, 0, 4326, 3857].each do |srid|
      connection.create_table(:spatial_models, force: true) do |t|
        types.each_with_index do |type, index|
          t.column "shape_#{index}", type, srid: srid, comment: "Shape #{index}"
        end
        t.point :indexed_location, srid: srid, null: false, index: true
      end
      stream = StringIO.new
      ActiveRecord::SchemaDumper.dump(SpatialModel.connection_pool, stream)

      refute_includes stream.string, "Could not dump"
      # Execute only the schema just generated from this isolated test database.
      ActiveRecord::Migration.suppress_messages do
        eval(stream.string, binding, "schema.rb") # rubocop:disable Security/Eval
      end
      columns = connection.columns(:spatial_models).select(&:spatial?)

      assert_equal 9, columns.size
      assert_equal [srid], columns.map(&:srid_constraint).uniq
      assert_equal types.map { |type| type.to_s.delete("_").to_sym }, columns.first(8).map(&:type)
      assert_equal "Shape 7", columns[7].comment
      assert_equal :spatial, connection.indexes(:spatial_models).first.type
      second = StringIO.new
      ActiveRecord::SchemaDumper.dump(SpatialModel.connection_pool, second)

      assert_equal stream.string, second.string
    end
  end

  def test_schema_cache_file_retains_spatial_metadata
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) { |t| t.point :location, srid: 4326 }
    connection.schema_cache.add("spatial_models")
    Tempfile.create(["trilogis-schema", ".yml"]) do |file|
      connection.schema_cache.dump_to(file.path)
      restored = ActiveRecord::ConnectionAdapters::SchemaCache._load_from(file.path)
      column = restored.columns(SpatialModel.connection_pool, "spatial_models").last

      assert_equal [4326, :point, RGeo::Feature::Point], [column.srid, column.type, column.geometric_type]
    end
  end

  def test_add_column_aliases_and_shortcuts_preserve_srid
    connection = SpatialModel.lease_connection
    types = %i[geometry point line_string polygon multi_point multi_line_string multi_polygon geometry_collection]
    [nil, 0, 4326, 3857].each do |srid|
      connection.create_table(:spatial_models, force: true)
      types.each_with_index do |type, index|
        connection.add_column(:spatial_models, "added_#{index}", type, srid: srid)
      end
      connection.change_table(:spatial_models) { |t| t.geometry_collection :shortcut, srid: srid }
      columns = connection.columns(:spatial_models).select(&:spatial?)

      assert_equal 9, columns.size
      assert_equal [srid], columns.map(&:srid_constraint).uniq
    end
  end

  def test_qualified_table_keeps_spatial_metadata
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) { |t| t.point :location, srid: 4326 }
    column = nil
    assert_nothing_raised do
      column = connection.columns("#{connection.current_database}.spatial_models").last
    end

    assert_equal [4326, :point], [column.srid, column.type]
  end

  def test_other_database_uses_its_own_spatial_metadata
    connection = SpatialModel.lease_connection
    connection.create_table(:spatial_models, force: true) { |t| t.point :location, srid: 4326 }
    database = "trilogis_schema_#{SecureRandom.hex(4)}"
    connection.create_database(database)
    created = true
    table = "#{database}.spatial_models"
    connection.create_table(table) { |t| t.point :location, srid: 3857 }

    assert_equal 3857, connection.columns(table).last.srid
    assert_equal 4326, connection.columns(:spatial_models).last.srid
  ensure
    connection.drop_database(database) if created
  end
end

# rubocop:enable Minitest/MultipleAssertions
