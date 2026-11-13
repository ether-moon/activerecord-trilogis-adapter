# frozen_string_literal: true

require "rgeo"
require "rgeo/active_record"
require "active_record/connection_adapters/trilogy_adapter"
require_relative "trilogis/version"
require_relative "trilogis/schema_creation"
require_relative "trilogis/schema_statements"
require_relative "trilogis/spatial_column"
require_relative "trilogis/spatial_column_info"
require_relative "trilogis/spatial_table_definition"
require_relative "trilogis/spatial_expressions"
require_relative "trilogis/arel_tosql"
require_relative "../type/spatial"
require_relative "../tasks/trilogis_database_tasks"

module ActiveRecord
  module ConnectionAdapters
    class TrilogisAdapter < TrilogyAdapter
      ADAPTER_NAME = "Trilogis"

      include Trilogis::SchemaStatements

      # MySQL spatial data types
      SPATIAL_COLUMN_TYPES = %w[
        geometry
        point
        linestring
        polygon
        multipoint
        multilinestring
        multipolygon
        geometrycollection
      ].freeze

      def self.spatial_type(type)
        name = type.to_s.downcase.delete("_")
        name = "geometrycollection" if name == "geomcollection"
        name if SPATIAL_COLUMN_TYPES.include?(name)
      end

      # Default SRID for MySQL
      DEFAULT_SRID = 0

      # MySQL 8.0+ supports axis-order option for ST_GeomFromText/ST_GeomFromWKB
      # This is critical for geographic coordinate systems to interpret coordinates
      # in longitude-latitude order instead of MySQL's default latitude-longitude
      AXIS_ORDER_LONG_LAT = "'axis-order=long-lat'"

      def self.valid_type?(type)
        !!spatial_type(type) || super
      end

      def supports_spatial?
        !mariadb? && database_version >= "8.0"
      end

      def default_srid
        DEFAULT_SRID
      end

      def schema_creation
        Trilogis::SchemaCreation.new(self)
      end

      def native_database_types
        super.merge(
          geometry: { name: "geometry" },
          point: { name: "point" },
          linestring: { name: "linestring" },
          line_string: { name: "linestring" },
          polygon: { name: "polygon" },
          multipoint: { name: "multipoint" },
          multi_point: { name: "multipoint" },
          multilinestring: { name: "multilinestring" },
          multi_line_string: { name: "multilinestring" },
          multipolygon: { name: "multipolygon" },
          multi_polygon: { name: "multipolygon" },
          geometrycollection: { name: "geometrycollection" },
          geometry_collection: { name: "geometrycollection" }
        )
      end

      # Quote spatial values for SQL
      def quote(value)
        if value.is_a?(RGeo::Feature::Instance)
          srid = value.srid || DEFAULT_SRID

          wkb_hex = RGeo::WKRep::WKBGenerator.new(hex_format: true, little_endian: true).generate(value)
          "ST_GeomFromWKB(0x#{wkb_hex}, #{srid}, #{AXIS_ORDER_LONG_LAT})"
        else
          super
        end
      end

      private

      def arel_visitor
        Arel::Visitors::Trilogis.new(self)
      end

      # Override type_map to include spatial types
      def type_map
        @type_map ||= begin
          map = Type::TypeMap.new(super)

          # Add spatial types
          (SPATIAL_COLUMN_TYPES + ["geomcollection"]).each do |geo_type|
            map.register_type(geo_type) do |sql_type|
              Type::Spatial.new(sql_type)
            end
          end

          map
        end
      end
    end
  end
end

# Register spatial types globally
ActiveRecord::ConnectionAdapters::TrilogisAdapter::SPATIAL_COLUMN_TYPES.each do |geo_type|
  ActiveRecord::Type.register(
    geo_type.to_sym,
    ActiveRecord::Type::Spatial,
    adapter: :trilogis
  )
end

# Register the adapter with ActiveRecord
ActiveRecord::ConnectionAdapters.register(
  "trilogis",
  "ActiveRecord::ConnectionAdapters::TrilogisAdapter",
  "active_record/connection_adapters/trilogis_adapter"
)
