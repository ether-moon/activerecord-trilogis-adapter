# frozen_string_literal: true

module Arel
  module Visitors
    class Trilogis < Arel::Visitors::MySQL
      attr_reader :connection

      def initialize(connection)
        super
        @connection = connection
      end

      # MySQL spatial function mappings
      SPATIAL_FUNCTIONS = {
        "st_contains" => "ST_Contains",
        "st_crosses" => "ST_Crosses",
        "st_disjoint" => "ST_Disjoint",
        "st_distance" => "ST_Distance",
        "st_equals" => "ST_Equals",
        "st_intersects" => "ST_Intersects",
        "st_overlaps" => "ST_Overlaps",
        "st_touches" => "ST_Touches",
        "st_within" => "ST_Within",
        "st_area" => "ST_Area",
        "st_length" => "ST_Length",
        "st_buffer" => "ST_Buffer",
        "st_centroid" => "ST_Centroid",
        "st_envelope" => "ST_Envelope",
        "st_geomfromtext" => "ST_GeomFromText",
        "st_geomfromwkb" => "ST_GeomFromWKB",
        "st_astext" => "ST_AsText",
        "st_asbinary" => "ST_AsBinary",
        "st_srid" => "ST_SRID"
      }.freeze

      def visit_spatial_value(node, collector)
        case node
        when RGeo::Feature::Instance
          visit_RGeo_Feature_Instance(node, collector)
        when String
          if node.match?(/^[A-Z]/) # WKT string
            visit_wkt_string(node, collector)
          else
            super
          end
        else
          super
        end
      end

      def visit_RGeo_Feature_Instance(node, collector)
        srid = node.srid || 0
        wkt = node.as_text

        # MySQL ST_GeomFromText supports axis-order option for geographic SRIDs
        # This ensures longitude-latitude order for all geographic SRIDs
        if connection.send(:geographic_srid?, srid)
          collector << "ST_GeomFromText('#{wkt}', #{srid}, #{ActiveRecord::ConnectionAdapters::TrilogisAdapter::AXIS_ORDER_LONG_LAT})"
        else
          collector << "ST_GeomFromText('#{wkt}', #{srid})"
        end
      end

      def visit_wkt_string(wkt, collector)
        # Extract SRID if present in EWKT format
        if wkt =~ /^SRID=(\d+);(.+)$/i
          srid = Regexp.last_match(1).to_i
          clean_wkt = Regexp.last_match(2)
          # Use axis-order for geographic SRIDs
          if connection.send(:geographic_srid?, srid)
            collector << "ST_GeomFromText('#{clean_wkt}', #{srid}, #{ActiveRecord::ConnectionAdapters::TrilogisAdapter::AXIS_ORDER_LONG_LAT})"
          else
            collector << "ST_GeomFromText('#{clean_wkt}', #{srid})"
          end
        else
          collector << "ST_GeomFromText('#{wkt}', 0)"
        end
      end

      # Handle spatial function calls
      def visit_Arel_Nodes_NamedFunction(o, collector)
        name = o.name.downcase
        if SPATIAL_FUNCTIONS.key?(name)
          collector << SPATIAL_FUNCTIONS[name]
          collector << "("
          o.expressions.each_with_index do |arg, i|
            collector << ", " if i.positive?
            # Handle string arguments (WKT/EWKT)
            if arg.is_a?(String)
              visit_wkt_string(arg, collector)
            else
              visit(arg, collector)
            end
          end
          collector << ")"
        else
          super
        end
      end

      # Override literal visiting for spatial values
      def visit_Arel_Nodes_Quoted(o, collector)
        if o.value.is_a?(RGeo::Feature::Instance)
          visit_RGeo_Feature_Instance(o.value, collector)
        else
          super
        end
      end

      # Handle RGeo spatial constant nodes from rgeo-activerecord gem
      def visit_RGeo_ActiveRecord_SpatialConstantNode(node, collector)
        value = node.delegate
        if value.is_a?(RGeo::Feature::Instance)
          visit_RGeo_Feature_Instance(value, collector)
        elsif value.is_a?(String)
          # Handle WKT strings
          if value.match?(/^[A-Z]/)
            visit_wkt_string(value, collector)
          else
            # Regular string literal - use connection to quote or fallback to inspect
            collector << (connection ? connection.quote(value) : value.inspect)
          end
        else
          # For numeric or other values - use connection to quote or fallback to inspect
          collector << (connection ? connection.quote(value) : value.inspect)
        end
      end

      # Support for spatial predicates in WHERE clauses
      def visit_spatial_predicate(predicate_name, left, right, collector)
        collector << "#{SPATIAL_FUNCTIONS[predicate_name]}("
        visit(left, collector)
        collector << ", "
        visit(right, collector)
        collector << ")"
      end
    end
  end
end
