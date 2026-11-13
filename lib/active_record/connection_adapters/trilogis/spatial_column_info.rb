# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      # Queries MySQL INFORMATION_SCHEMA for spatial column metadata
      class SpatialColumnInfo
        def initialize(adapter, table_name)
          @adapter = adapter
          @table_name = table_name
        end

        def all
          scope = @adapter.send(:quoted_scope, @table_name)
          # Query MySQL's ST_GEOMETRY_COLUMNS view for SRID info
          # This view properly returns SRS_ID for spatial columns
          sql = <<~SQL.squish
            SELECT
              gc.COLUMN_NAME as column_name,
              gc.SRS_ID as srs_id,
              c.COLUMN_TYPE as column_type
            FROM INFORMATION_SCHEMA.ST_GEOMETRY_COLUMNS gc
            JOIN INFORMATION_SCHEMA.COLUMNS c
              ON gc.TABLE_SCHEMA = c.TABLE_SCHEMA
              AND gc.TABLE_NAME = c.TABLE_NAME
              AND gc.COLUMN_NAME = c.COLUMN_NAME
            WHERE gc.TABLE_SCHEMA = #{scope[:schema]}
              AND gc.TABLE_NAME = #{scope[:name]}
          SQL

          result = {}
          @adapter.exec_query(sql, "SCHEMA").each do |row|
            column_name = row["column_name"] || row["COLUMN_NAME"]
            srs_id = row["srs_id"] || row["SRS_ID"]
            column_type = (row["column_type"] || row["COLUMN_TYPE"]).to_s.sub(/m$/, "")

            result[column_name] = {
              name: column_name,
              srid: srs_id&.to_i,
              type: TrilogisAdapter.spatial_type(column_type)
            }
          end
          result
        end
      end
    end
  end
end
