# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      module SchemaStatements
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, **)
          if spatial_type?(type.to_s)
            type = type.to_s.upcase
            type = "#{type}(#{limit[:type].to_s.upcase})" if limit.is_a?(Hash) && limit[:type]
            type = "#{type} SRID #{limit[:srid]}" if limit.is_a?(Hash) && limit[:srid]
            type
          else
            super
          end
        end

        def add_index(table_name, column_name, **options)
          index_type = options[:type]

          # Handle spatial indexes specially
          if index_type == :spatial
            options = options.dup
            options[:using] = :gist if options[:using].nil?
          end

          super
        end

        def indexes(table_name)
          indexes = super

          # MySQL doesn't support prefix lengths for spatial indexes
          indexes.each do |index|
            if index.using == :gist || index.comment&.include?("spatial") || index.type == :spatial
              index.instance_variable_set(:@lengths, {})
            end
          end

          indexes
        end

        # Override columns to properly handle spatial column metadata
        def columns(table_name)
          column_definitions(table_name).map do |field|
            sql_type = field.fetch(:Type)
            type_metadata = fetch_type_metadata(sql_type)

            if spatial_type?(sql_type)
              # Get spatial metadata (SRID, etc.) from information schema
              spatial_info = spatial_column_info(table_name).get(field[:Field], sql_type)

              SpatialColumn.new(
                field[:Field],
                field[:Default],
                type_metadata,
                field[:Null] == "YES",
                field[:Extra],
                collation: field[:Collation],
                comment: field[:Comment].presence,
                spatial_info: spatial_info
              )
            else
              super_column_from_field(table_name, field)
            end
          end
        end

        # Override to properly handle spatial columns creation
        def new_column_from_field(table_name, field)
          sql_type = field[:Type]

          if spatial_type?(sql_type)
            type_metadata = fetch_type_metadata(sql_type)
            spatial_info = spatial_column_info(table_name).get(field[:Field], sql_type)

            SpatialColumn.new(
              field[:Field],
              field[:Default],
              type_metadata,
              field[:Null] == "YES",
              field[:Extra],
              collation: field[:Collation],
              comment: field[:Comment].presence,
              spatial_info: spatial_info
            )
          else
            super
          end
        end

        def create_table_definition(name, **)
          Trilogis::TableDefinition.new(self, name, **)
        end

        def add_column(table_name, column_name, type, **)
          if spatial_type?(type.to_s)
            at = create_table_definition(table_name)
            at.column(column_name, type, **)

            execute schema_creation.accept(at)
          else
            super
          end
        end

        private

        def spatial_type?(type)
          TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(type.to_s.downcase)
        end

        def schema_creation
          SchemaCreation.new(self)
        end

        # Memoized spatial column info per table
        def spatial_column_info(table_name)
          @spatial_column_info ||= {}
          @spatial_column_info[table_name.to_sym] ||= SpatialColumnInfo.new(self, table_name.to_s)
        end
      end

      class SchemaCreation < ActiveRecord::ConnectionAdapters::MySQL::SchemaCreation
        private

        def visit_ColumnDefinition(o)
          if spatial_column?(o)
            column_sql = "#{quote_column_name(o.name)} #{type_to_sql(o.sql_type)}"
            column_sql << " NOT NULL" unless o.null
            column_sql << " DEFAULT #{quote_default_expression(o.default, o)}" if o.default
            column_sql
          else
            super
          end
        end

        def spatial_column?(column)
          TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(column.sql_type.to_s.downcase)
        end
      end
    end
  end
end
