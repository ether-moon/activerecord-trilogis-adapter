# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # Add spatial? method to MySQL::Column for compatibility
    module MySQL
      class Column
        def spatial?
          false
        end
      end
    end

    module Trilogis
      class SpatialColumn < ActiveRecord::ConnectionAdapters::MySQL::Column
        attr_reader :geometric_type, :srid

        # Map SQL type strings to RGeo type classes
        GEOMETRIC_TYPES = {
          "geometry" => RGeo::Feature::Geometry,
          "point" => RGeo::Feature::Point,
          "linestring" => RGeo::Feature::LineString,
          "polygon" => RGeo::Feature::Polygon,
          "multipoint" => RGeo::Feature::MultiPoint,
          "multilinestring" => RGeo::Feature::MultiLineString,
          "multipolygon" => RGeo::Feature::MultiPolygon,
          "geometrycollection" => RGeo::Feature::GeometryCollection
        }.freeze

        def initialize(name, default, sql_type_metadata = nil, null = true, default_function = nil, collation: nil,
                       comment: nil, spatial_info: nil, **)
          super(name, default, sql_type_metadata, null, default_function, collation: collation, comment: comment)

          return unless spatial?

          if spatial_info
            # Use spatial info from INFORMATION_SCHEMA if available
            geo_type_str = spatial_info[:type].to_s.downcase
            @geometric_type = GEOMETRIC_TYPES[geo_type_str] || RGeo::Feature::Geometry
            @srid = spatial_info[:srid] || 0
            @has_z = spatial_info[:has_z] || false
            @has_m = spatial_info[:has_m] || false
          else
            # Fallback to extracting from SQL type
            type_info = Type::Spatial.new(sql_type_metadata.sql_type)
            geo_type_str = type_info.geo_type.to_s.downcase
            @geometric_type = GEOMETRIC_TYPES[geo_type_str] || RGeo::Feature::Geometry
            @srid = type_info.srid || 0
            @has_z = false
            @has_m = false
          end
        end

        def spatial?
          TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(sql_type_metadata.sql_type.downcase)
        end

        def has_z?
          @has_z || false
        end

        def has_m?
          @has_m || false
        end

        # Return limit as hash with spatial metadata for schema dumper
        def limit
          return super unless spatial?

          {
            type: sql_type_metadata.sql_type.downcase,
            srid: @srid
          }
        end
      end
    end
  end
end
