# frozen_string_literal: true

require "rgeo"
require "rgeo/active_record"
require "active_record/connection_adapters/trilogy_adapter"
require_relative "trilogis/version"
require_relative "trilogis/schema_creation"
require_relative "trilogis/schema_statements"
require_relative "trilogis/spatial_column"
require_relative "trilogis/spatial_column_info"
require_relative "trilogis/spatial_table_definition"
require_relative "trilogis/spatial_expressions"
require_relative "trilogis/arel_tosql"
require_relative "../type/spatial"
require_relative "../tasks/trilogis_database_tasks"

module ActiveRecord
  module ConnectionHandling
    # Establishes a connection to the database using the Trilogis adapter.
    # This adapter extends the built-in Trilogy adapter with spatial support.
    def trilogis_connection(config)
      configuration = config.dup

      # Ensure required configuration
      configuration[:prepared_statements] = true unless configuration.key?(:prepared_statements)

      # Build connection options for Trilogy
      connection_options = {
        host: configuration[:host],
        port: configuration[:port],
        database: configuration[:database],
        username: configuration[:username],
        password: configuration[:password],
        socket: configuration[:socket],
        encoding: configuration[:encoding],
        ssl_mode: configuration[:ssl_mode],
        connect_timeout: configuration[:connect_timeout],
        read_timeout: configuration[:read_timeout],
        write_timeout: configuration[:write_timeout]
      }.compact

      # Create the Trilogy client connection
      require "trilogy"
      client = Trilogy.new(connection_options)

      # Return our spatial-enabled adapter
      ConnectionAdapters::TrilogisAdapter.new(
        client,
        logger,
        nil,
        configuration
      )
    rescue Trilogy::Error => e
      raise ActiveRecord::NoDatabaseError if e.message.include?("Unknown database")

      raise
    end
  end

  module ConnectionAdapters
    class TrilogisAdapter < TrilogyAdapter
      ADAPTER_NAME = "Trilogis"

      include Trilogis::SchemaStatements

      # MySQL spatial data types
      SPATIAL_COLUMN_TYPES = %w[
        geometry
        point
        linestring
        polygon
        multipoint
        multilinestring
        multipolygon
        geometrycollection
      ].freeze

      # Default SRID for MySQL
      DEFAULT_SRID = 0

      # MySQL 8.0+ supports axis-order option for ST_GeomFromText/ST_GeomFromWKB
      # This is critical for geographic coordinate systems to interpret coordinates
      # in longitude-latitude order instead of MySQL's default latitude-longitude
      AXIS_ORDER_LONG_LAT = "'axis-order=long-lat'"

      # Common geographic SRIDs that use latitude-longitude by default in MySQL 8.0
      # These need axis-order parameter to work with standard GIS longitude-latitude format
      GEOGRAPHIC_SRIDS = [
        4326, # WGS 84 (GPS)
        4269, # NAD83
        4267, # NAD27
        4258, # ETRS89
        4019  # Unknown datum based upon the GRS 1980 ellipsoid
      ].freeze

      # Class method to check if a type is spatial
      def self.spatial_column_options(type)
        SPATIAL_COLUMN_TYPES.include?(type.to_s.downcase)
      end

      def initialize(...)
        super

        # Override the visitor for spatial support
        @visitor = Arel::Visitors::Trilogis.new(self)

        # Register spatial types
        register_spatial_types

        # Configure RGeo factory generator for SRID-based factory selection
        configure_rgeo_factory_generator
      end

      def adapter_name
        ADAPTER_NAME
      end

      def supports_spatial?
        # MySQL 5.7.6+ supports spatial indexes and functions
        # MariaDB has different spatial support, so we exclude it for now
        !mariadb? && database_version >= "5.7.6"
      end

      def default_srid
        DEFAULT_SRID
      end

      def spatial_column_options(_table_name)
        # Return empty hash as MySQL stores spatial metadata in information_schema
        {}
      end

      def with_connection
        yield self
      end

      def schema_creation
        Trilogis::SchemaCreation.new(self)
      end

      def native_database_types
        super.merge(
          geometry: { name: "geometry" },
          point: { name: "point" },
          linestring: { name: "linestring" },
          line_string: { name: "linestring" },
          polygon: { name: "polygon" },
          multipoint: { name: "multipoint" },
          multi_point: { name: "multipoint" },
          multilinestring: { name: "multilinestring" },
          multi_line_string: { name: "multilinestring" },
          multipolygon: { name: "multipolygon" },
          multi_polygon: { name: "multipolygon" },
          geometrycollection: { name: "geometrycollection" },
          geometry_collection: { name: "geometrycollection" }
        )
      end

      # Quote spatial values for SQL
      def quote(value)
        if value.is_a?(RGeo::Feature::Instance)
          srid = value.srid || DEFAULT_SRID

          # For geographic SRIDs, use axis-order parameter to ensure longitude-latitude order
          # MySQL 8.0 defaults to latitude-longitude for geographic SRS, but GIS tools use long-lat
          # ST_GeomFromWKB DOES support axis-order parameter in MySQL 8.0+
          wkb_hex = RGeo::WKRep::WKBGenerator.new(hex_format: true, little_endian: true).generate(value)
          if geographic_srid?(srid)
            "ST_GeomFromWKB(0x#{wkb_hex}, #{srid}, #{AXIS_ORDER_LONG_LAT})"
          else
            # For projected SRIDs (like 3857), no axis-order needed - uses cartesian X,Y
            "ST_GeomFromWKB(0x#{wkb_hex}, #{srid})"
          end
        else
          super
        end
      end

      def type_cast(value, column = nil)
        if column&.type == :geometry && value.is_a?(String)
          parse_spatial_value(value)
        else
          super
        end
      end

      private

      def register_spatial_types
        SPATIAL_COLUMN_TYPES.each do |geo_type|
          ActiveRecord::Type.register(
            geo_type.to_sym,
            Type::Spatial.new(geo_type),
            adapter: :trilogis
          )
        end
      end

      def configure_rgeo_factory_generator
        # Set up factory generator for RGeo::ActiveRecord::SpatialFactoryStore
        # This ensures the correct factory (Geographic vs Cartesian) is used based on SRID
        RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |factory_store|
          factory_store.default = ->(config) {
            srid = (config[:srid] || DEFAULT_SRID).to_i

            if GEOGRAPHIC_SRIDS.include?(srid)
              # Use Geographic factory for geographic coordinate systems
              RGeo::Geographic.spherical_factory(srid: srid)
            else
              # Use Cartesian factory for projected coordinate systems
              RGeo::Cartesian.preferred_factory(
                srid: srid,
                has_z_coordinate: false,
                has_m_coordinate: false
              )
            end
          }
        end
      end

      def parse_spatial_value(value)
        return nil if value.nil?

        # Parse WKB hex string
        if value.is_a?(String) && value.match?(/\A[0-9a-fA-F]+\z/)
          factory = RGeo::Cartesian.preferred_factory(srid: DEFAULT_SRID)
          RGeo::WKRep::WKBParser.new(factory).parse([value].pack("H*"))
        else
          value
        end
      end

      # Check if a SRID is geographic (uses latitude-longitude coordinate system)
      def geographic_srid?(srid)
        GEOGRAPHIC_SRIDS.include?(srid)
      end

      # Override type_map to include spatial types
      def type_map
        @type_map ||= begin
          map = super.dup

          # Add spatial types
          SPATIAL_COLUMN_TYPES.each do |geo_type|
            map.register_type(geo_type) do |sql_type|
              Type::Spatial.new(sql_type)
            end
          end

          map
        end
      end

      def translate_exception(exception, message:, sql:, binds:)
        if exception.is_a?(::Trilogy::SSLError)
          return ActiveRecord::ConnectionFailed.new(message, connection_pool: @pool)
        end

        super
      end
    end
  end
end

# Register the adapter with ActiveRecord
ActiveRecord::ConnectionAdapters.register(
  "trilogis",
  "ActiveRecord::ConnectionAdapters::TrilogisAdapter",
  "active_record/connection_adapters/trilogis_adapter"
)
