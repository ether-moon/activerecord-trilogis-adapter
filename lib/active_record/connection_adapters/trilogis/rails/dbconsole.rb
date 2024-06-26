# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TrilogisAdapter
      module Rails
        module DBConsole
          class AdapterAdapter < SimpleDelegator
            def adapter
              "mysql"
            end
          end

          def db_config
            if super.adapter == "trilogis"
              AdapterAdapter.new(super)
            else
              super
            end
          end
        end
      end
    end
  end
end

module Rails
  class DBConsole
    # require "rails/commands/dbconsole/dbconsole_command"
    if ActiveRecord.version < ::Gem::Version.new('6.1.a')
      alias _brick_start start

      def start
        ENV["RAILS_ENV"] ||= @options[:environment] || environment

        if config["adapter"] == "trilogis"
          begin
            ::ActiveRecord::ConnectionAdapters::TrilogisAdapter.dbconsole(config, @options)
          rescue NotImplementedError
            abort "Unknown command-line client for #{db_config.database}."
          end
        else
          _brick_start
        end
      end
    end
  end
end
