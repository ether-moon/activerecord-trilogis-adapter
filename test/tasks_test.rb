# frozen_string_literal: true

require "test_helper"
require "fileutils"

class TasksTest < ActiveSupport::TestCase
  def test_empty_sql_dump
    setup_database_tasks
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(new_connection, tmp_sql_filename)
    sql = File.read(tmp_sql_filename)

    refute_includes(sql, "CREATE TABLE")
  end

  def test_sql_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon", srid: 4326
      t.geometry "geo_col", srid: 4326
      t.column "poly", :multi_polygon, srid: 4326
    end
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(new_connection, tmp_sql_filename)
    data = File.read(tmp_sql_filename)

    assert_includes data, "`latlon` point"
    assert_includes data, "`geo_col` geometry"
    assert_includes data, "`poly` multipolygon"
  end

  def test_index_sql_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon", null: false, srid: 4326
      t.string "name"
    end
    connection.add_index :spatial_test, :latlon, type: :spatial
    connection.add_index :spatial_test, :name, using: :btree
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(new_connection, tmp_sql_filename)
    data = File.read(tmp_sql_filename)

    assert_includes data, "`latlon` point"
    assert_includes data, "SPATIAL KEY `index_spatial_test_on_latlon` (`latlon`)"
    assert_includes data, "KEY `index_spatial_test_on_name` (`name`) USING BTREE"
  end

  def test_empty_schema_dump
    setup_database_tasks
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
    end
    data = File.read(tmp_sql_filename)

    assert_includes data, "ActiveRecord::Schema"
  end

  def test_basic_geometry_schema_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.spatial "object1", srid: connection.default_srid, type: "geometry"
      t.spatial "object2", srid: connection.default_srid, type: "geometry"
    end
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    data = File.read(tmp_sql_filename)

    # Ruby 3.2/3.3 uses {:key=>value} format, Ruby 3.4+ uses {key: value} format
    # Match either format by checking for the essential parts
    assert_match(/t\.geometry "object1".*"geometry".*#{connection.default_srid}/, data)
    assert_match(/t\.geometry "object2".*"geometry".*#{connection.default_srid}/, data)
  end

  def test_basic_geography_schema_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon1", srid: 4326
      t.spatial "latlon2", srid: 4326, type: "point"
    end
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    data = File.read(tmp_sql_filename)

    # Ruby 3.2/3.3 uses {:key=>value} format, Ruby 3.4+ uses {key: value} format
    # Match either format by checking for the essential parts
    assert_match(/t\.geometry "latlon1".*"point".*4326/, data)
    assert_match(/t\.geometry "latlon2".*"point".*4326/, data)
  end

  def test_index_schema_dump
    setup_database_tasks
    connection.create_table(:spatial_test, force: true) do |t|
      t.point "latlon", null: false, srid: 4326
    end
    connection.add_index :spatial_test, :latlon, type: :spatial
    File.open(tmp_sql_filename, "w:utf-8") do |file|
      ActiveRecord::SchemaDumper.dump(connection, file)
    end
    data = File.read(tmp_sql_filename)

    # Ruby 3.2/3.3 uses {:key=>value} format, Ruby 3.4+ uses {key: value} format
    # Match either format by checking for the essential parts
    assert_match(/t\.geometry "latlon".*"point".*4326.*null: false/, data)
    assert_includes data, %(t.index ["latlon"], name: "index_spatial_test_on_latlon", type: :spatial)
  end

  private

  def new_connection(options = {})
    configuration_options = { "database" => "trilogis_tasks_test" }.merge(options)
    configuration_hash = ActiveRecord::Base.test_connection_hash.merge(configuration_options)
    ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", configuration_hash)
  end

  def connection
    ActiveRecord::Base.connection
  end

  def tmp_sql_filename
    File.expand_path("tmp/tmp.sql", __dir__)
  end

  def setup_database_tasks
    FileUtils.rm_f(tmp_sql_filename)
    FileUtils.mkdir_p(File.dirname(tmp_sql_filename))
    drop_db_if_exists
    ActiveRecord::Tasks::MySQLDatabaseTasks.new(new_connection).create
  rescue ActiveRecord::DatabaseAlreadyExists
    # ignore
  end

  def drop_db_if_exists
    ActiveRecord::Tasks::MySQLDatabaseTasks.new(new_connection).drop
  rescue ActiveRecord::NoDatabaseError
    # ignore
  end
end
