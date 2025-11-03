# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      class SchemaCreation < MySQL::SchemaCreation
        private

        def add_column_options!(sql, options)
          # Add SRID option for spatial columns in MySQL 8.0+
          # Format: /*!80003 SRID #{srid} */
          if options[:srid]
            sql_result = "#{sql} /*!80003 SRID #{options[:srid]} */"
            sql.replace(sql_result)
          end

          super
        end
      end
    end
  end
end
