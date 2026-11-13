# frozen_string_literal: true

module Arel
  module Visitors
    class Trilogis < Arel::Visitors::MySQL
      include RGeo::ActiveRecord::SpatialToSql

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

      # Override st_func to use our function mappings
      def st_func(standard_name)
        SPATIAL_FUNCTIONS[standard_name.downcase] || standard_name
      end

      # Override visit_in_spatial_context to use our axis-order logic
      def visit_in_spatial_context(node, collector)
        case node
        when String
          visit_wkt_string(node, collector)
        when RGeo::Feature::Instance
          visit_RGeo_Feature_Instance(node, collector)
        when RGeo::Cartesian::BoundingBox
          geom = node.to_geometry
          visit_RGeo_Feature_Instance(geom, collector)
        else
          visit(node, collector)
        end
      end

      def visit_RGeo_Feature_Instance(node, collector)
        srid = node.srid || 0
        wkt = node.as_text

        append_geometry(wkt, srid, collector)
      end

      def visit_wkt_string(wkt, collector)
        if (match = /\ASRID=(\d+);(.*)\z/im.match(wkt))
          append_geometry(match[2], match[1].to_i, collector)
        else
          append_geometry(wkt, 0, collector)
        end
      end

      def append_geometry(wkt, srid, collector)
        collector << "ST_GeomFromText(#{quote(wkt)}, #{srid}, " \
                     "#{ActiveRecord::ConnectionAdapters::TrilogisAdapter::AXIS_ORDER_LONG_LAT})"
      end

      def visit_RGeo_ActiveRecord_SpatialNamedFunction(node, collector)
        node = node.dup
        node.expressions = node.expressions.each_with_index.map do |argument, index|
          if node.spatial_argument?(index) || argument.is_a?(RGeo::ActiveRecord::SpatialConstantNode)
            argument
          else
            Arel::Nodes.build_quoted(argument)
          end
        end
        super
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
            # Regular string literal
            collector << quote(value)
          end
        else
          # For numeric or other values
          collector << quote(value)
        end
      end
    end
  end
end
