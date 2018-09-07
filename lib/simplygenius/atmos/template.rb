require_relative '../atmos'
require_relative '../atmos/source_path'

module SimplyGenius
  module Atmos

    class Template
      include GemLogger::LoggerSupport

      TEMPLATES_SPEC_FILE = 'templates.yml'
      TEMPLATES_ACTIONS_FILE = 'templates.rb'

      attr_reader :name, :directory, :source, :context

      def initialize(name, directory, source, context: {})
        @name = name
        @directory = directory
        @source = source
        @context = context
        @context = SettingsHash.new(@context) unless @context.kind_of?(SettingsHash)
      end

      def to_s
        "#{name}"
      end

      def to_h
        SettingsHash.new({name: name, source: source.to_h, context: context})
      end

      def context_path
        name.gsub('-', '_').gsub('/', '.')
      end

      def scoped_context
        result = context.notation_get(context_path)
        if result.nil?
          context.notation_put(context_path, SettingsHash.new, additive: false)
          result = context.notation_get(context_path)
        end
        result
      end

      def actions_path
        File.join(directory, TEMPLATES_ACTIONS_FILE)
      end

      def actions
        @actions ||= (File.exist?(actions_path) ? File.read(actions_path) : "")
      end

      def config_path
        File.join(directory, TEMPLATES_SPEC_FILE)
      end

      def config
        @config ||= begin
          data = File.read(config_path)
          SettingsHash.new(YAML.load(data) || {})
        end
      end

      def optional
        result = config[:optional] || {}
        raise TypeError.new("Template config item :optional must be a hash: #{result.inspect}") unless result.is_a?(Hash)
        result
      end

      def dependencies
        @dependencies ||= begin
          deps = Array(config[:dependent_templates])
          deps.collect do |d|
            if d.kind_of?(String)
              tmpl = SourcePath.find_template(d)
            elsif d.kind_of?(Hash)
              raise ArgumentError.new("Template must be named with name key: #{tmpl}") unless d[:name]
              tmpl = SourcePath.find_template(d[:name])
              tmpl.context.merge!(d[:context]) if d[:context]
            else
              raise TypeError.new("Invalid template structure: #{d}")
            end

            tmpl
          end
        end
      end

      def dup
        dependencies
        Marshal.load(Marshal.dump(self))
      end

      # depth first iteration of dependencies
      def walk_dependencies(seen=Set.new)
        Enumerator.new do |yielder|
          if seen.include?(name)
            seen << name
            raise ArgumentError.new("Circular template dependency: #{seen.to_a.join(" => ")}")
          end
          seen << name

          dependencies.each do |dep|

            dep = dep.dup
            dep.context.merge!(context)
            dep.walk_dependencies(seen.dup).each do |d|
              yielder << d
            end
          end
          yielder << dup
        end
      end

    end

  end
end
