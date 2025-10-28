# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      module SchemaStatements
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, **)
          if spatial_type?(type.to_s)
            # Remove underscores and convert to uppercase for MySQL spatial types
            sql_type = type.to_s.delete("_").upcase

            # Handle SRID specification
            sql_type = "#{sql_type} SRID #{limit[:srid]}" if limit.is_a?(Hash) && limit[:srid]

            sql_type
          else
            super
          end
        end

        def add_index(table_name, column_name, **options)
          index_type = options[:type]

          # Handle spatial indexes - MySQL uses SPATIAL keyword, not USING
          if index_type == :spatial
            options = options.dup
            options.delete(:using) # Remove any USING clause for spatial indexes
            options[:type] = :spatial
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

        # Override columns to use parent's implementation but enhance spatial columns
        # DO NOT override - let parent class handle all column creation

        # Override to properly handle spatial columns creation
        def new_column_from_field(table_name, field, definitions = nil)
          field_name = extract_field_value(field, :Field, :field)
          sql_type = extract_field_value(field, :Type, :type)

          if spatial_type?(sql_type)
            build_spatial_column(table_name, field, field_name, sql_type)
          else
            super
          end
        end

        def create_table_definition(name, **)
          Trilogis::TableDefinition.new(self, name, **)
        end

        def create_table(table_name, **options, &)
          # Clear spatial cache when creating table with force: true
          # This ensures we don't have stale cache from a previously dropped table
          clear_spatial_cache_for(table_name) if options[:force]
          super
        end

        def add_column(table_name, column_name, type, **options)
          if spatial_type?(type.to_s)
            # Build ALTER TABLE statement for spatial column
            sql_type = type.to_s.delete("_").upcase
            sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{sql_type}"

            # Add SRID if specified
            sql << " SRID #{options[:srid]}" if options[:srid] && options[:srid] != 0

            # Add NULL constraint
            sql << " NOT NULL" if options[:null] == false

            # Add DEFAULT if specified
            sql << " DEFAULT #{quote_default_expression(options[:default], nil)}" if options[:default]

            execute sql

            # Clear memoized spatial column info for this table
            clear_spatial_cache_for(table_name)
          else
            super
          end
        end

        def drop_table(table_name, **options)
          # Clear memoized spatial column info for this table before dropping
          clear_spatial_cache_for(table_name)
          super
        end

        def rename_table(table_name, new_name)
          # Clear cache for both old and new table names
          clear_spatial_cache_for(table_name)
          clear_spatial_cache_for(new_name)
          super
        end

        # Clear all spatial column caches (useful for tests)
        def clear_spatial_cache!
          @spatial_column_info = {}
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

        # Clear spatial cache for a specific table
        def clear_spatial_cache_for(table_name)
          @spatial_column_info&.delete(table_name.to_sym)
          @spatial_column_info&.delete(table_name.to_s)
        end

        # Extract field value with case-insensitive key lookup
        def extract_field_value(field, *keys)
          keys.each do |key|
            return field[key] if field.key?(key)
            return field[key.to_s] if field.key?(key.to_s)
          end
          nil
        end

        # Build a spatial column from field metadata
        def build_spatial_column(table_name, field, field_name, sql_type)
          type_metadata = fetch_type_metadata(sql_type)
          spatial_info = spatial_column_info(table_name).get(field_name, sql_type)

          SpatialColumn.new(
            field_name,
            extract_field_value(field, :Default, :default),
            type_metadata,
            extract_field_value(field, :Null, :null) == "YES",
            extract_field_value(field, :Extra, :extra),
            collation: extract_field_value(field, :Collation, :collation),
            comment: extract_field_value(field, :Comment, :comment).presence,
            spatial_info: spatial_info
          )
        end
      end

      class SchemaCreation < ActiveRecord::ConnectionAdapters::MySQL::SchemaCreation
        private

        def visit_ColumnDefinition(o)
          if spatial_column?(o)
            # Remove underscores from spatial types (multi_point -> MULTIPOINT)
            sql_type = o.sql_type.to_s.delete("_").upcase
            column_sql = "#{quote_column_name(o.name)} #{sql_type}"

            # Add SRID if specified (MySQL 8.0+ syntax: COLUMN TYPE SRID value)
            column_sql << " SRID #{o.options[:srid]}" if o.options[:srid] && o.options[:srid] != 0

            column_sql << " NOT NULL" unless o.null
            column_sql << " DEFAULT #{quote_default_expression(o.default, o)}" if o.default
            column_sql
          else
            super
          end
        end

        def spatial_column?(column)
          # Check both with and without underscores
          sql_type = column.sql_type.to_s.downcase
          TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(sql_type) ||
            TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(sql_type.delete("_"))
        end
      end
    end
  end
end
