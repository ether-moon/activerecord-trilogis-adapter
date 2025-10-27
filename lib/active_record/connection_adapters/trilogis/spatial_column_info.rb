# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      # Queries MySQL INFORMATION_SCHEMA for spatial column metadata
      # and caches the results for performance
      class SpatialColumnInfo
        def initialize(adapter, table_name)
          @adapter = adapter
          @table_name = table_name
        end

        def all
          # Query MySQL's information schema for spatial column metadata
          sql = <<~SQL.squish
            SELECT
              column_name,
              srs_id,
              column_type
            FROM information_schema.columns
            WHERE table_schema = DATABASE()
              AND table_name = #{@adapter.quote(@table_name)}
              AND data_type IN ('geometry', 'point', 'linestring', 'polygon',
                               'multipoint', 'multilinestring', 'multipolygon',
                               'geometrycollection')
          SQL

          result = {}
          @adapter.exec_query(sql, "SCHEMA").each do |row|
            column_name = row["column_name"]
            srs_id = row["srs_id"]
            column_type = row["column_type"].to_s.sub(/m$/, "")

            result[column_name] = {
              name: column_name,
              srid: srs_id.to_i,
              type: column_type
            }
          end
          result
        end

        # Get spatial info for a specific column if it's spatial
        # Returns nil for non-spatial columns to avoid unnecessary queries
        def get(column_name, sql_type)
          # Only query for known spatial types
          return unless TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(sql_type.to_s.downcase)

          @spatial_column_info ||= all
          @spatial_column_info[column_name]
        end
      end
    end
  end
end
