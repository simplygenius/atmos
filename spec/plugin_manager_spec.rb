require 'simplygenius/atmos/plugin_manager'
require 'simplygenius/atmos/plugins/output_filter'

module SimplyGenius
  module Atmos

    describe PluginManager do

      describe "initialize" do

        it "creates the manager with nil plugins" do
          pm = described_class.new(nil)
          expect(pm.instance_variable_get(:@plugin_gem_names)).to eq []
        end

        it "creates the manager with empty plugins" do
          pm = described_class.new([])
          expect(pm.instance_variable_get(:@plugin_gem_names)).to eq []
        end

        it "creates the manager with some plugins" do
          pm = described_class.new(["my_plugin_gem"])
          expect(pm.instance_variable_get(:@plugin_gem_names)).to eq ["my_plugin_gem"]
        end

      end

      describe "load_plugin" do

        it "handles gems named with dashes" do
          pm = described_class.new([])
          expect(pm).to receive(:require).with("my/plugin")
          pm.load_plugin("my-plugin")
        end

        it "handles gems named without dashes" do
          pm = described_class.new([])
          expect(pm).to receive(:require).with("my_plugin")
          pm.load_plugin("my_plugin")
        end

        it "allows plugin loading to fail" do
          pm = described_class.new([])
          expect { pm.load_plugin("my_plugin") }.to_not raise_error
          expect(Logging.contents).to match(/Failed to load atmos plugin/)
        end

        it "initializes plugin classes once" do
          pm = described_class.new([])
          c1 = Class.new(PluginBase)
          c2 = Class.new(PluginBase)
          expect { pm.load_plugins }.to_not raise_error
          expect(pm.instance_variable_get(:@plugin_instances)).to match [instance_of(c1), instance_of(c2)]
          expect { pm.load_plugins }.to_not raise_error
          expect(pm.instance_variable_get(:@plugin_instances)).to match [instance_of(c1), instance_of(c2)]
        end

        it "allows plugin init to fail" do
          pm = described_class.new([])
          c1 = Class.new(PluginBase) do
            def initialize
              raise "bad"
            end
          end
          expect { pm.load_plugins }.to_not raise_error
          expect(Logging.contents).to match(/Failed to initialize plugin/)
        end

      end

      describe "load_plugins" do

        it "loads each plugin" do
          pm = described_class.new(["foo", "bar"])
          expect(pm).to receive(:load_plugin).with("foo").ordered
          expect(pm).to receive(:load_plugin).with("bar").ordered
          pm.load_plugins
        end

      end

      describe "validate_output_filter_type" do

        it "passes for stdout/stderr" do
          pm = described_class.new([])
          expect { pm.validate_output_filter_type(:stdout) }.to_not raise_error
          expect { pm.validate_output_filter_type(:stderr) }.to_not raise_error
        end

        it "fails for junk" do
          pm = described_class.new([])
          expect { pm.validate_output_filter_type(:notme) }.to raise_error(RuntimeError,  /Invalid output filter type/)
        end

      end

      describe "register_output_filter" do

        it "registers filter callbacks" do
          pm = described_class.new([])
          pm.register_output_filter(:stdout, Object)
          expect(pm.instance_variable_get(:@output_filters)).to eq(:stdout => [Object])
          pm.register_output_filter(:stdout, Class)
          expect(pm.instance_variable_get(:@output_filters)).to eq(:stdout => [Object, Class])
          pm.register_output_filter(:stderr, String)
          expect(pm.instance_variable_get(:@output_filters)).to eq(:stdout => [Object, Class], :stderr => [String])
        end

      end

      describe "output_filters" do

        it "instantiates output filters" do
          f1 = Class.new(Plugins::OutputFilter)
          f2 = Class.new(Plugins::OutputFilter)
          pm = described_class.new([])
          pm.register_output_filter(:stdout, f1)
          pm.register_output_filter(:stdout, f2)
          context = {foo: :bar}
          expect(f1).to receive(:new).with(context)
          expect(f2).to receive(:new).with(context)
          filters = pm.output_filters(:stdout, context)
          expect(filters).to be_a_kind_of(PluginManager::OutputFilterCollection)
        end

      end

      describe PluginManager::OutputFilterCollection do

        describe "filter_block" do

          it "returns a block which applies each filter in turn" do
            f1 = Plugins::OutputFilter.new({})
            f2 = Plugins::OutputFilter.new({})
            expect(f1).to receive(:filter) { |data| data+"f1" }
            expect(f2).to receive(:filter) { |data| data+"f2" }
            ofc = described_class.new([f1, f2])
            result = ofc.filter_block.yield("foo")
            expect(result).to eq("foof1f2")
          end

          it "returns a block which applies a filter can override" do
            f1 = Plugins::OutputFilter.new({})
            f2 = Plugins::OutputFilter.new({})
            expect(f1).to receive(:filter) { |data| data+"f1" }
            expect(f2).to receive(:filter) { |data| "f2" }
            ofc = described_class.new([f1, f2])
            result = ofc.filter_block.yield("foo")
            expect(result).to eq("f2")
          end

          it "returns a block which ignores failures in filters" do
            f1 = Plugins::OutputFilter.new({})
            f2 = Plugins::OutputFilter.new({})
            expect(f1).to receive(:filter) { |data| raise "bad" }
            expect(f2).to receive(:filter) { |data| data+"f2" }
            ofc = described_class.new([f1, f2])
            result = ofc.filter_block.yield("foo")
            expect(result).to eq("foof2")
            expect(Logging.contents).to match(/Output filter failed during filter/)
          end


        end

        describe "close" do

          it "calls close on each filter" do
            f1 = Plugins::OutputFilter.new({})
            f2 = Plugins::OutputFilter.new({})
            expect(f1).to receive(:close)
            expect(f2).to receive(:close)
            ofc = described_class.new([f1, f2])
            ofc.close
          end

          it "allows failure when calling close on each filter" do
            f1 = Plugins::OutputFilter.new({})
            f2 = Plugins::OutputFilter.new({})
            expect(f1).to receive(:close) { raise "bad" }
            expect(f2).to receive(:close)
            ofc = described_class.new([f1, f2])
            ofc.close
            expect(Logging.contents).to match(/Output filter failed during close/)
          end

        end

      end

    end

  end
end
