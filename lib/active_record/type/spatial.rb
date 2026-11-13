# frozen_string_literal: true

module ActiveRecord
  module Type
    class Spatial < Binary
      attr_reader :geo_type, :srid

      def initialize(sql_type = "geometry")
        @geo_type, @srid = self.class.parse_sql_type(sql_type)
      end

      def type
        :geometry
      end

      # Class method for parsing SQL type
      def self.parse_sql_type(sql_type)
        sql_type = sql_type.to_s.downcase

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

      def parse_string(string)
        return nil if string.blank?

        # Handle EWKT format: SRID=xxxx;GEOMETRY(...)
        if string =~ /SRID=(\d+);(.+)/i
          srid = Regexp.last_match(1).to_i
          wkt = Regexp.last_match(2)

          geo_factory = spatial_factory(srid)
          begin
            return RGeo::WKRep::WKTParser.new(geo_factory, support_ewkt: true, default_srid: srid).parse(wkt)
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
        # Support EWKT (Extended Well-Known Text) format with SRID
        RGeo::WKRep::WKTParser.new(spatial_factory, support_ewkt: true, default_srid: @srid).parse(string)
      rescue RGeo::Error::ParseError
        # WKT parsing failed, return nil
        nil
      end

      def parse_wkb_hex(hex_string)
        parse_wkb_binary([hex_string].pack("H*"))
      end

      def parse_wkb_binary(binary_string)
        return nil if binary_string.nil? || binary_string.empty?

        # MySQL binary values contain a four-byte SRID prefix followed by WKB.
        if binary_string.bytesize >= 5
          srid = binary_string.unpack1("V")
          RGeo::WKRep::WKBParser.new(spatial_factory(srid), support_ewkb: true, default_srid: srid)
                                .parse(binary_string.byteslice(4..))
        else
          RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: @srid).parse(binary_string)
        end
      rescue RGeo::Error::ParseError, ArgumentError
        nil
      end

      def cast_hash(hash)
        return nil unless hash.is_a?(Hash)

        # Support GeoJSON-like hashes (allow symbol or string keys)
        normalized_hash = hash.transform_keys(&:to_s)
        return unless normalized_hash["type"] && normalized_hash["coordinates"]

        unless defined?(RGeo::GeoJSON)
          raise ArgumentError, 'GeoJSON input requires the rgeo-geojson gem and require "rgeo/geo_json"'
        end

        RGeo::GeoJSON.decode(normalized_hash, geo_factory: spatial_factory)
      end

      def spatial_factory(srid = @srid)
        store = RGeo::ActiveRecord::SpatialFactoryStore.instance
        attrs = { geo_type: @geo_type, sql_type: @geo_type, srid: srid }
        registered = store.registry.any? do |entry|
          entry.attrs.any? && entry.attrs.all? { |key, value| attrs[key] == value }
        end
        # Preserve the existing geographic defaults without mutating the global registry.
        attrs[:sql_type] = "geography" if !registered && [4326, 4269, 4267, 4258, 4019].include?(srid)
        store.factory(attrs)
      end
    end
  end
end
