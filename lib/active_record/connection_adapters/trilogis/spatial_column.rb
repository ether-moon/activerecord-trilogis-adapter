# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      class SpatialColumn < ActiveRecord::ConnectionAdapters::MySQL::Column
        attr_reader :geometric_type, :srid

        def initialize(name, default, sql_type_metadata = nil, null = true, default_function = nil, collation: nil,
                       comment: nil, spatial_info: nil, **)
          super(name, default, sql_type_metadata, null, default_function, collation: collation, comment: comment)

          return unless spatial?

          if spatial_info
            # Use spatial info from INFORMATION_SCHEMA if available
            @geometric_type = spatial_info[:type]
            @srid = spatial_info[:srid] || 0
          else
            # Fallback to extracting from SQL type
            type_info = Type::Spatial.new(sql_type_metadata.sql_type)
            @geometric_type = type_info.geo_type
            @srid = type_info.srid
          end
        end

        def spatial?
          TrilogisAdapter::SPATIAL_COLUMN_TYPES.include?(sql_type_metadata.sql_type.downcase)
        end
      end
    end
  end
end
