# frozen_string_literal: true

module ActiveRecord
  module Type
    class Spatial < ActiveModel::Type::Value
      attr_reader :geo_type, :srid

      def initialize(sql_type = "geometry")
        @sql_type = sql_type
        @geo_type, @srid = parse_sql_type(sql_type)
      end

      def type
        :geometry
      end

      def serialize(value)
        return nil if value.nil?

        # Ensure we have an RGeo geometry object
        geometry = cast(value)
        return nil unless geometry

        # Convert to WKB hex string for MySQL
        wkb_generator = RGeo::WKRep::WKBGenerator.new(
          hex_format: true,
          little_endian: true,
          type_format: :ewkb
        )
        wkb_generator.generate(geometry)
      end

      def deserialize(value)
        return nil if value.nil? || value == ""

        case value
        when String
          parse_wkb_hex(value)
        when RGeo::Feature::Instance
          value
        end
      end

      def cast(value)
        return nil if value.nil?

        case value
        when RGeo::Feature::Instance
          value
        when String
          parse_string(value)
        when Hash
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

      def parse_string(string)
        return nil if string.blank?

        # Try to parse as WKT
        if string.match?(/^[A-Z]/)
          parse_wkt(string)
        # Try to parse as WKB hex
        elsif string.match?(/^[0-9a-fA-F]+$/)
          parse_wkb_hex(string)
        end
      end

      def parse_wkt(string)
        factory.parse_wkt(string)
      rescue RGeo::Error::ParseError
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

      def cast_hash(hash)
        return nil unless hash.is_a?(Hash)

        # Support GeoJSON-like hashes
        RGeo::GeoJSON.decode(hash.to_json, geo_factory: factory) if hash["type"] && hash["coordinates"]
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
