require_relative '../atmos'

module Atmos
  class PluginManager
    include GemLogger::LoggerSupport

    def initialize(plugins)
      @plugins = Array(plugins)
      @output_filters = {}
    end

    def load_plugins
      @plugins.each do |p|
        load_plugin(p)
      end
    end

    def load_plugin(name)
      begin
        gem_name = name.gsub('-', '/')
        logger.debug("Loading plugin #{name} as #{gem_name}")
        require gem_name
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
