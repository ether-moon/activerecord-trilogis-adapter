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

        def column(name, type, index: nil, **options)
          index = { type: :spatial } if TrilogisAdapter.spatial_type(type) && [true, :spatial].include?(index)
          super
        end

        def new_column_definition(name, type, **options)
          if (spatial_type = TrilogisAdapter.spatial_type(type))
            type = spatial_type.to_sym
            # Retain legacy no-op options for existing migrations.
            options.except!(:has_z, :has_m, :geographic)
            options.delete(:default)
            if options[:limit].is_a?(Hash)
              limit = options.delete(:limit)
              type = TrilogisAdapter.spatial_type(limit[:type]).to_sym if limit[:type]
              options[:srid] = limit[:srid] unless options.key?(:srid)
            end
          end
          super
        end

        private

        def valid_column_definition_options
          super + [:srid]
        end
      end
    end

    # Include column methods in MySQL::Table for migrations
    MySQL::Table.include Trilogis::ColumnMethods if defined?(MySQL::Table)
  end
end
