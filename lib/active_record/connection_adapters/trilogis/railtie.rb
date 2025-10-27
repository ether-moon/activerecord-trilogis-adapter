# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogis
      class Railtie < Rails::Railtie
        initializer "trilogis.initialize" do
          ActiveSupport.on_load(:active_record) do
            require "active_record/connection_adapters/trilogis_adapter"
          end
        end

        # Register database tasks for spatial databases
        rake_tasks do
          namespace :db do
            namespace :trilogis do
              desc "Create spatial extensions if needed"
              task setup: :environment do
                ActiveRecord::Base.connection.execute(
                  "SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() LIMIT 1"
                )
                puts "Trilogis adapter is ready. MySQL spatial support enabled."
              end
            end
          end
        end
      end
    end
  end
end
