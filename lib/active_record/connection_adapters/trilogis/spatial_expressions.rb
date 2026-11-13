# frozen_string_literal: true

module RGeo
  module ActiveRecord
    module Trilogis
      # MySQL-specific spatial expressions
      module SpatialExpressions
        # Keep Arel expressions intact; the upstream implementation coerces distance to Float.
        def st_buffer(distance, units = nil)
          args = [self, distance]
          args << units.to_s if units
          SpatialNamedFunction.new("ST_Buffer", args, [true, true, false])
        end

        # MySQL ST_Distance_Sphere for geographic distance calculations
        def st_distance_sphere(rhs, units = nil)
          args = [self, rhs]
          args << units.to_s if units
          SpatialNamedFunction.new("ST_Distance_Sphere", args, [false, true, true, false])
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
