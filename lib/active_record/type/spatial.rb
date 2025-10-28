# frozen_string_literal: true

module ActiveRecord
  module Type
    class Spatial < ActiveModel::Type::Value
      # Geographic SRIDs that use latitude-longitude coordinate system
      # These need special handling with RGeo::Geographic factory
      GEOGRAPHIC_SRIDS = [
        4326, # WGS 84 (GPS)
        4269, # NAD83
        4267, # NAD27
        4258, # ETRS89
        4019  # Unknown datum based upon the GRS 1980 ellipsoid
      ].freeze

      attr_reader :geo_type, :srid

      def initialize(sql_type = "geometry")
        @sql_type = sql_type
        @geo_type, @srid = self.class.parse_sql_type(sql_type)
      end

      def type
        :geometry
      end

      # Class method for parsing SQL type
      def self.parse_sql_type(sql_type)
        original_sql_type = sql_type.to_s
        sql_type = sql_type.to_s.downcase

        # Only parse known spatial types
        # For non-spatial types, return them unchanged
        spatial_types = %w[geometry point linestring polygon multipoint multilinestring multipolygon geometrycollection]

        # Check if it's a spatial type
        base_type = sql_type.split("(").first
        return [original_sql_type, 0] unless spatial_types.include?(base_type)

        # Extract geometry type and SRID from SQL type
        # Examples: "geometry", "point", "linestring", "geometry(Point,4326)"
        if sql_type =~ /(\w+)(?:\((\w+)(?:,(\d+))?\))?/
          geo_type = Regexp.last_match(1)
          sub_type = Regexp.last_match(2)
          srid = Regexp.last_match(3).to_i

          geo_type = sub_type.downcase if sub_type
          [geo_type, srid]
        else
          [sql_type, 0]
        end
      end

      def serialize(value)
        return nil if value.nil?

        # Return the RGeo geometry object as-is
        # The adapter's quote method will handle conversion to SQL
        cast(value)
      end

      def deserialize(value)
        return nil if value.nil?

        # Handle RGeo objects directly
        return value if value.is_a?(RGeo::Feature::Instance)

        # Convert to string if needed and check for empty
        value = value.to_s if value.respond_to?(:to_s)
        return nil if value.empty?

        # MySQL returns binary WKB with SRID prefix
        # Try to parse as binary WKB first
        if [Encoding::ASCII_8BIT, Encoding::BINARY].include?(value.encoding)
          result = parse_wkb_binary(value)
          return result if result
        end

        # Try hex WKB
        return parse_wkb_hex(value) if value.match?(/\A[0-9a-fA-F]+\z/)

        # Try WKT
        parse_wkt(value)
      end

      def cast(value)
        return nil if value.nil?

        # Check by class name instead of is_a? due to ActiveRecord wrapping values
        if value.is_a?(RGeo::Feature::Instance)
          value
        elsif value.instance_of?(::String) || value.respond_to?(:to_str)
          parse_string(value.to_s)
        elsif value.is_a?(Hash)
          cast_hash(value)
        end
      end

      def changed?(old_value, new_value, _new_value_before_type_cast)
        old_value != new_value
      end

      def changed_in_place?(raw_old_value, new_value)
        deserialize(raw_old_value) != new_value
      end

      private

      def parse_sql_type(sql_type)
        original_sql_type = sql_type.to_s
        sql_type = sql_type.to_s.downcase

        # Only parse known spatial types
        # For non-spatial types, return them unchanged
        spatial_types = %w[geometry point linestring polygon multipoint multilinestring multipolygon geometrycollection]

        # Check if it's a spatial type
        base_type = sql_type.split("(").first
        return [original_sql_type, 0] unless spatial_types.include?(base_type)

        # Extract geometry type and SRID from SQL type
        # Examples: "geometry", "point", "linestring", "geometry(Point,4326)"
        if sql_type =~ /(\w+)(?:\((\w+)(?:,(\d+))?\))?/
          geo_type = Regexp.last_match(1)
          sub_type = Regexp.last_match(2)
          srid = Regexp.last_match(3).to_i

          geo_type = sub_type.downcase if sub_type
          [geo_type, srid]
        else
          [sql_type, 0]
        end
      end

      def parse_string(string)
        return nil if string.blank?

        # Handle EWKT format: SRID=xxxx;GEOMETRY(...)
        if string =~ /SRID=(\d+);(.+)/i
          srid = Regexp.last_match(1).to_i
          wkt = Regexp.last_match(2)

          # Use Geographic factory for geographic SRIDs
          geo_factory = if geographic_srid?(srid)
                          RGeo::Geographic.spherical_factory(srid: srid)
                        else
                          RGeo::Cartesian.preferred_factory(
                            srid: srid,
                            has_z_coordinate: false,
                            has_m_coordinate: false
                          )
                        end
          begin
            return geo_factory.parse_wkt(wkt)
          rescue RGeo::Error::ParseError
            return nil
          end
        end

        # Try to parse as WKT
        if string.match?(/^[A-Z]/i)
          parse_wkt(string)
        # Try to parse as WKB hex
        elsif string.match?(/^[0-9a-fA-F]+$/)
          parse_wkb_hex(string)
        end
      end

      def parse_wkt(string)
        factory.parse_wkt(string)
      rescue RGeo::Error::ParseError
        # WKT parsing failed, return nil
        nil
      end

      def parse_wkb_hex(hex_string)
        return nil if hex_string.nil? || hex_string.empty?

        # MySQL returns WKB as hex string
        binary = [hex_string].pack("H*")
        factory.parse_wkb(binary)
      rescue RGeo::Error::ParseError
        nil
      end

      def parse_wkb_binary(binary_string)
        return nil if binary_string.nil? || binary_string.empty?

        # MySQL internal format: first 4 bytes are SRID (little-endian), then WKB
        if binary_string.length >= 5
          srid = binary_string[0..3].unpack1("V") # V = unsigned 32-bit little-endian
          wkb_data = binary_string[4..]

          # Create factory with the correct SRID
          # Use Geographic factory for geographic SRIDs
          geo_factory = if geographic_srid?(srid)
                          RGeo::Geographic.spherical_factory(srid: srid)
                        else
                          RGeo::Cartesian.preferred_factory(
                            srid: srid,
                            has_z_coordinate: false,
                            has_m_coordinate: false
                          )
                        end

          geo_factory.parse_wkb(wkb_data)
        else
          # Fall back to standard WKB parsing
          factory.parse_wkb(binary_string)
        end
      rescue RGeo::Error::ParseError, ArgumentError
        # Failed to parse, return nil
        nil
      end

      def cast_hash(hash)
        return nil unless hash.is_a?(Hash)

        # Support GeoJSON-like hashes
        RGeo::GeoJSON.decode(hash.to_json, geo_factory: factory) if hash["type"] && hash["coordinates"]
      end

      # Check if a SRID is geographic (uses latitude-longitude coordinate system)
      def geographic_srid?(srid)
        GEOGRAPHIC_SRIDS.include?(srid)
      end

      def factory
        @factory ||= RGeo::Cartesian.preferred_factory(
          srid: @srid,
          has_z_coordinate: false,
          has_m_coordinate: false
        )
      end
    end
  end
end
