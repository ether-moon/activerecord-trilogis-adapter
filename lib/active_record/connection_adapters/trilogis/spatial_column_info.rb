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
          # Query MySQL's ST_GEOMETRY_COLUMNS view for SRID info
          # This view properly returns SRS_ID for spatial columns
          sql = <<~SQL.squish
            SELECT
              gc.COLUMN_NAME as column_name,
              gc.SRS_ID as srs_id,
              gc.GEOMETRY_TYPE_NAME as geometry_type,
              c.COLUMN_TYPE as column_type
            FROM INFORMATION_SCHEMA.ST_GEOMETRY_COLUMNS gc
            JOIN INFORMATION_SCHEMA.COLUMNS c
              ON gc.TABLE_SCHEMA = c.TABLE_SCHEMA
              AND gc.TABLE_NAME = c.TABLE_NAME
              AND gc.COLUMN_NAME = c.COLUMN_NAME
            WHERE gc.TABLE_SCHEMA = DATABASE()
              AND gc.TABLE_NAME = #{@adapter.quote(@table_name)}
          SQL

          result = {}
          @adapter.exec_query(sql, "SCHEMA").each do |row|
            column_name = row["column_name"] || row["COLUMN_NAME"]
            srs_id = row["srs_id"] || row["SRS_ID"]
            row["geometry_type"] || row["GEOMETRY_TYPE"]
            column_type = (row["column_type"] || row["COLUMN_TYPE"]).to_s.sub(/m$/, "")

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

          # Don't memoize - always query fresh data to avoid stale cache issues
          # when columns are added during tests
          all[column_name]
        end
      end
    end
  end
end
