# frozen_string_literal: true

module RGeo
  module ActiveRecord
    module Trilogis
      # MySQL-specific spatial expressions
      module SpatialExpressions
        # MySQL ST_Distance_Sphere for geographic distance calculations
        def st_distance_sphere(rhs, units = nil)
          args = [self, rhs]
          args << units.to_s if units
          SpatialNamedFunction.new("ST_Distance_Sphere", args, [false, true, true, false])
        end

        # Additional MySQL spatial functions
        def st_buffer(distance)
          SpatialNamedFunction.new("ST_Buffer", [self, distance], [false, true, false])
        end

        def st_contains(rhs)
          SpatialNamedFunction.new("ST_Contains", [self, rhs], [false, true, true])
        end

        def st_within(rhs)
          SpatialNamedFunction.new("ST_Within", [self, rhs], [false, true, true])
        end

        def st_intersects(rhs)
          SpatialNamedFunction.new("ST_Intersects", [self, rhs], [false, true, true])
        end

        def st_crosses(rhs)
          SpatialNamedFunction.new("ST_Crosses", [self, rhs], [false, true, true])
        end

        def st_touches(rhs)
          SpatialNamedFunction.new("ST_Touches", [self, rhs], [false, true, true])
        end

        def st_overlaps(rhs)
          SpatialNamedFunction.new("ST_Overlaps", [self, rhs], [false, true, true])
        end

        def st_equals(rhs)
          SpatialNamedFunction.new("ST_Equals", [self, rhs], [false, true, true])
        end

        def st_disjoint(rhs)
          SpatialNamedFunction.new("ST_Disjoint", [self, rhs], [false, true, true])
        end

        def st_area
          SpatialNamedFunction.new("ST_Area", [self], [false, true])
        end

        def st_length
          SpatialNamedFunction.new("ST_Length", [self], [false, true])
        end

        def st_centroid
          SpatialNamedFunction.new("ST_Centroid", [self], [false, true])
        end

        def st_envelope
          SpatialNamedFunction.new("ST_Envelope", [self], [false, true])
        end

        def st_astext
          SpatialNamedFunction.new("ST_AsText", [self], [false, true])
        end

        def st_asbinary
          SpatialNamedFunction.new("ST_AsBinary", [self], [false, true])
        end

        def st_srid
          SpatialNamedFunction.new("ST_SRID", [self], [false, true])
        end
      end
    end
  end
end

# Allow chaining of spatial expressions from Arel attributes
Arel::Attribute.include RGeo::ActiveRecord::Trilogis::SpatialExpressions if defined?(Arel::Attribute)

# Include in RGeo spatial nodes if they exist
if defined?(RGeo::ActiveRecord::SpatialConstantNode)
  RGeo::ActiveRecord::SpatialConstantNode.include RGeo::ActiveRecord::Trilogis::SpatialExpressions
end

if defined?(RGeo::ActiveRecord::SpatialNamedFunction)
  RGeo::ActiveRecord::SpatialNamedFunction.include RGeo::ActiveRecord::Trilogis::SpatialExpressions
end
