# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      module ColumnMethods
        # Generic spatial column method
        def spatial(name, options = {})
          raise "You must set a type. For example: 't.spatial :location, type: :point'" unless options[:type]

          column(name, options[:type], **options)
        end

        # Define spatial column types with both underscore and non-underscore versions
        def geometry(name, options = {})
          column(name, :geometry, **options)
        end

        def geometrycollection(name, options = {})
          column(name, :geometrycollection, **options)
        end
        alias geometry_collection geometrycollection

        def linestring(name, options = {})
          column(name, :linestring, **options)
        end
        alias line_string linestring

        def multilinestring(name, options = {})
          column(name, :multilinestring, **options)
        end
        alias multi_line_string multilinestring

        def multipoint(name, options = {})
          column(name, :multipoint, **options)
        end
        alias multi_point multipoint

        def multipolygon(name, options = {})
          column(name, :multipolygon, **options)
        end
        alias multi_polygon multipolygon

        def point(name, options = {})
          column(name, :point, **options)
        end

        def polygon(name, options = {})
          column(name, :polygon, **options)
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::MySQL::TableDefinition
        include ColumnMethods

        # Override column to handle spatial types
        def column(name, type, index: nil, **options)
          # Store spatial-specific options before processing
          spatial_options = {
            srid: options.delete(:srid),
            has_m: options.delete(:has_m),
            has_z: options.delete(:has_z),
            geographic: options.delete(:geographic)
          }.compact

          # Call super to create column definition
          result = super

          # Add spatial options back to the column definition if it's a spatial type
          if spatial_type?(type) && (col = @columns_hash[name.to_s])
            spatial_options.each do |key, value|
              col.options[key] = value
            end
          end

          # Add spatial index if requested
          @indexes << [name, { type: :spatial }] if index && spatial_type?(type) && [true, :spatial].include?(index)

          result
        end

        private

        def spatial_type?(type)
          TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(type.to_s)
        end
      end
    end

    # Include column methods in MySQL::Table for migrations
    MySQL::Table.include Trilogis::ColumnMethods if defined?(MySQL::Table)
  end
end
