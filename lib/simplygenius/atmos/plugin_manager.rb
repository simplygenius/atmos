require_relative '../atmos'
require_relative 'plugin'
require 'set'

module SimplyGenius
  module Atmos

    class PluginManager
      include GemLogger::LoggerSupport

      attr_reader :plugins

      def initialize(plugins)
        @plugins = []
        Array(plugins).each do |plugin|
          if plugin.is_a?(String)
            name = plugin
            plugin = SettingsHash.new
            plugin[:name] = name
          elsif plugin.is_a?(Hash)
            plugin = SettingsHash.new(plugin)
            if plugin[:name].blank?
              logger.error "Invalid plugin definition, :name missing: #{plugin}"
              next
            end
          else
            logger.error "Invalid plugin definition: #{plugin}"
            next
          end
          @plugins << plugin
        end

        @plugin_classes = Set.new
        @plugin_instances = []
        @output_filters = {}
      end

      def load_plugins
        @plugins.each do |plugin|
          load_plugin(plugin)

          # Check for new plugin classes after each plugin load so that we can
          # initialize them with their own config hash
          Plugin.descendants.each do |plugin_class|
            begin
              if ! @plugin_classes.include?(plugin_class)
                @plugin_classes << plugin_class
                @plugin_instances << plugin_class.new(plugin)
              end
            rescue StandardError => e
              logger.log_exception e, "Failed to initialize plugin: #{plugin_class}"
            end
          end
        end
      end

      def load_plugin(plugin)
        begin
          name = plugin[:name]
          require_name = plugin[:require] || name.gsub('-', '/')
          logger.debug("Loading plugin #{name} as #{require_name}")
          require require_name
        rescue LoadError, StandardError => e
          logger.log_exception e, "Failed to load atmos plugin: #{name} - #{e.message}"
        end
      end

      def validate_output_filter_type(type)
        raise "Invalid output filter type #{type}, must be one of [:stdout, :stderr]" unless [:stdout, :stderr].include?(type)
      end

      def register_output_filter(type, clazz)
        validate_output_filter_type(type)
        @output_filters[type.to_sym] ||= []
        @output_filters[type.to_sym] << clazz
      end

      def output_filters(type, context)
        validate_output_filter_type(type)
        @output_filters[type.to_sym] ||= []
        return OutputFilterCollection.new(@output_filters[type.to_sym].collect {|clazz| clazz.new(context) })
      end

      class OutputFilterCollection
        include GemLogger::LoggerSupport

        attr_accessor :filters

        def initialize(filters)
          @filters = filters
        end

        def filter_block
          return Proc.new do |data, flushing: false|
            @filters.inject(data) do |memo, obj|
              begin
                obj.filter(memo, flushing: flushing)
              rescue StandardError => e
                logger.log_exception e, "Output filter failed during filter: #{obj.class}"
                memo
              end
            end
          end
        end

        def close
          @filters.each do |f|
            begin
              f.close
            rescue StandardError => e
              logger.log_exception e, "Output filter failed during close: #{f.class}"
            end
          end
        end

      end
    end

  end
end
