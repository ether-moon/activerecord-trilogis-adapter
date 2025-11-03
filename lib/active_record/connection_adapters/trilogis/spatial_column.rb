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
        attr_reader :geometric_type, :srid, :geo_type_name

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

        def initialize(name, cast_type, default, sql_type_metadata = nil, null = true,
                       default_function = nil, collation: nil, comment: nil, spatial_info: nil, **)
          super(name, cast_type, default, sql_type_metadata, null, default_function,
                collation: collation, comment: comment)

          # Guard against nil cast_type during OID registration
          return unless cast_type && spatial?

          if spatial_info
            # Use spatial info from INFORMATION_SCHEMA if available
            @geo_type_name = spatial_info[:type].to_s.downcase
            @geometric_type = GEOMETRIC_TYPES[@geo_type_name] || RGeo::Feature::Geometry
            @srid = spatial_info[:srid] || 0
            @has_z = spatial_info[:has_z] || false
            @has_m = spatial_info[:has_m] || false
          else
            # Fallback to extracting from SQL type
            @geo_type_name = sql_type_metadata.sql_type.to_s.downcase
            type_info = Type::Spatial.new(@geo_type_name)
            @geometric_type = GEOMETRIC_TYPES[@geo_type_name] || RGeo::Feature::Geometry
            @srid = type_info.srid || 0
            @has_z = false
            @has_m = false
          end
        end

        def spatial?
          # Guard against nil sql_type_metadata during type registration
          return false unless sql_type_metadata&.sql_type

          TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(sql_type_metadata.sql_type.downcase)
        end

        def has_z?
          @has_z || false
        end

        def has_m?
          @has_m || false
        end

        # Return Rails type for schema dumper
        # Returns the actual geometric type (point, linestring, etc.) as symbol
        # This allows schema dumper to generate t.point, t.linestring, etc.
        def type
          return super unless spatial?

          # Return actual geometric type as symbol
          # This matches PostGIS approach and enables proper schema dumping
          @geo_type_name&.to_sym || :geometry
        end

        # Return limit as hash with spatial metadata for schema dumper
        # Only includes SRID (type is already in column type)
        def limit
          return super unless spatial?

          # Only include SRID in limit
          # Type information is in the type() method
          { srid: @srid }.compact
        end

        # Override default to always return nil for spatial columns
        # MySQL does not support DEFAULT values for spatial/geometry columns
        def default
          return super unless spatial?

          # Always return nil for spatial columns to prevent schema dumper
          # from generating invalid DEFAULT clauses
          nil
        end

        # Override default_function to always return nil for spatial columns
        # MySQL does not support DEFAULT values for spatial/geometry columns
        def default_function
          return super unless spatial?

          # Always return nil for spatial columns to prevent schema dumper
          # from generating invalid DEFAULT clauses
          nil
        end
      end
    end
  end
end
