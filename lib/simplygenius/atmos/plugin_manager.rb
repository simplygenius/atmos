require_relative '../atmos'
require_relative 'plugin_base'

module SimplyGenius
  module Atmos

    class PluginManager
      include GemLogger::LoggerSupport

      def initialize(plugin_gem_names)
        @plugin_gem_names = Array(plugin_gem_names)
        @plugin_instances = []
        @output_filters = {}
      end

      def load_plugins
        @plugin_gem_names.each do |plugin_gem_name|
          load_plugin(plugin_gem_name)
        end
        PluginBase.descendants.each do |plugin_class|
          begin
            unless @plugin_instances.any? {|i| i.instance_of?(plugin_class) }
              @plugin_instances << plugin_class.new
            end
          rescue StandardError => e
            logger.log_exception e, "Failed to initialize plugin: #{plugin_class}"
          end
        end
      end

      def load_plugin(plugin_gem_name)
        begin
          require_name = plugin_gem_name.gsub('-', '/')
          logger.debug("Loading plugin #{plugin_gem_name} as #{require_name}")
          require require_name
        rescue LoadError, StandardError => e
          logger.log_exception e, "Failed to load atmos plugin: #{plugin_gem_name} - #{e.message}"
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
          return Proc.new do |data|
            @filters.inject(data) do |memo, obj|
              begin
                obj.filter(memo)
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
