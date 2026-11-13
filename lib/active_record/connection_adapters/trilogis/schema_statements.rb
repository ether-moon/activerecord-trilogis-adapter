# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      module SchemaStatements
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, **)
          return super unless (spatial_type = TrilogisAdapter.spatial_type(type))

          spatial_type = TrilogisAdapter.spatial_type(limit[:type]) if limit.is_a?(Hash) && limit[:type]
          sql = spatial_type.upcase
          sql += " SRID #{Integer(limit[:srid])}" if limit.is_a?(Hash) && limit[:srid]
          sql
        end

        def add_index(table_name, column_name, **options)
          options.delete(:using) if options[:type] == :spatial
          super
        end

        def indexes(table_name)
          super.each do |index|
            # MySQL reports a prefix length for SPATIAL keys that cannot be reloaded.
            index.instance_variable_set(:@lengths, {}) if index.type == :spatial
          end
        end

        def columns(table_name)
          previous_metadata = @spatial_column_metadata
          @spatial_column_metadata = nil
          super
        ensure
          @spatial_column_metadata = previous_metadata
        end

        def new_column_from_field(table_name, field, definitions = nil)
          return super unless (spatial_type = TrilogisAdapter.spatial_type(field["Type"]))

          @spatial_column_metadata ||= SpatialColumnInfo.new(self, table_name).all
          info = @spatial_column_metadata[field["Field"]]
          cast_type = Type::Spatial.new(info ? "geometry(#{info[:type]},#{info[:srid] || 0})" : spatial_type).freeze
          SpatialColumn.new(
            field["Field"], cast_type,
            nil, fetch_type_metadata(field["Type"]), field["Null"] == "YES", nil,
            collation: field["Collation"], comment: field["Comment"].presence, spatial_info: info
          )
        end

        def create_table_definition(name, **)
          Trilogis::TableDefinition.new(self, name, **)
        end

        def build_change_column_definition(table_name, column_name, type, **options)
          column = column_for(table_name, column_name)
          if column.spatial? && (type.nil? || TrilogisAdapter.spatial_type(type))
            type ||= column.type
            options[:srid] = column.srid_constraint unless options.key?(:srid) || options[:limit].is_a?(Hash)
          end
          super
        end
      end
    end
  end
end
