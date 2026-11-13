# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      class SchemaCreation < MySQL::SchemaCreation
        private

        def add_column_options!(sql, options)
          sql << " SRID #{Integer(options[:srid])}" if options[:srid]
          super
        end
      end
    end
  end
end
