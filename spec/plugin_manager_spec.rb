require 'simplygenius/atmos/plugin_manager'
require 'simplygenius/atmos/plugins/output_filter'

module SimplyGenius
  module Atmos

    describe PluginManager do

      describe "initialize" do

        it "creates the manager with nil plugins" do
          pm = described_class.new(nil)
          expect(pm.plugins).to eq []
        end

        it "creates the manager with empty plugins" do
          pm = described_class.new([])
          expect(pm.plugins).to eq []
        end

        it "creates the manager with plugin name only" do
          pm = described_class.new(["my_plugin_gem", "other_plugin"])
          expect(pm.plugins).to eq [{"name" => "my_plugin_gem"}, {"name" => "other_plugin"}]
          expect(pm.plugins.first["name"]).to eq "my_plugin_gem"
          expect(pm.plugins.first[:name]).to eq "my_plugin_gem"
          expect(pm.plugins.last["name"]).to eq "other_plugin"
          expect(pm.plugins.last[:name]).to eq "other_plugin"
        end

        it "creates the manager with plugin hashes" do
          pm = described_class.new([{name: "my_plugin_gem"}, {"name" => "other_plugin"}])
          expect(pm.plugins).to eq [{"name" => "my_plugin_gem"}, {"name" => "other_plugin"}]
          expect(pm.plugins.first["name"]).to eq "my_plugin_gem"
          expect(pm.plugins.first[:name]).to eq "my_plugin_gem"
          expect(pm.plugins.last["name"]).to eq "other_plugin"
          expect(pm.plugins.last[:name]).to eq "other_plugin"
        end

        it "skips invalid plugins" do
          pm = described_class.new([1])
          expect(pm.plugins).to eq([]), "plugin thats not a hash or string should be skipped"
          pm = described_class.new([{foo: "bar"}])
          expect(pm.plugins).to eq([]), "plugin missing name should be skipped"
        end

      end

      describe "load_plugin" do

        it "handles gems named with dashes" do
          pm = described_class.new([])
          expect(pm).to receive(:require).with("my/plugin")
          pm.load_plugin(name: "my-plugin")
        end

        it "handles gems named without dashes" do
          pm = described_class.new([])
          expect(pm).to receive(:require).with("my_plugin")
          pm.load_plugin(name: "my_plugin")
        end

        it "allows plugin loading to fail" do
          pm = described_class.new([])
          expect { pm.load_plugin(name: "my_plugin") }.to_not raise_error
          expect(Logging.contents).to match(/Failed to load atmos plugin/)
        end

        it "initializes plugin classes once" do
          # we check for new plugin classes after each load of a plugin, so use a real gem here
          pm = described_class.new(["rubygems"])
          existing = Plugin.descendants
          existing_instances = existing.collect {|e| instance_of(e) }
          c1 = Class.new(Plugin)
          c2 = Class.new(Plugin)
          expect { pm.load_plugins }.to_not raise_error
          expect(pm.instance_variable_get(:@plugin_classes)).to contain_exactly c1, c2, *existing
          expect(pm.instance_variable_get(:@plugin_instances)).to contain_exactly instance_of(c1), instance_of(c2), *existing_instances
          expect { pm.load_plugins }.to_not raise_error
          expect(pm.instance_variable_get(:@plugin_classes)).to contain_exactly c1, c2, *existing
          expect(pm.instance_variable_get(:@plugin_instances)).to contain_exactly instance_of(c1), instance_of(c2), *existing_instances
        end

        it "initializes plugin classes after each plugin loaded, with that plugins config" do
          plugin1 = {name: "plugin1", foo: "bar"}
          plugin2 = {name: "plugin2", baz: "boo"}
          c1, c2  = nil, nil
          pm = described_class.new([plugin1, plugin2])
          expect(pm).to receive(:load_plugin).with(plugin1) do
            c1 = Class.new(Plugin)
            expect(c1).to receive(:new).with(pm, plugin1)
          end
          expect(pm).to receive(:load_plugin).with(plugin2) do
            c2 = Class.new(Plugin)
            expect(c2).to receive(:new).with(pm, plugin2)
          end

          pm.load_plugins
        end

        it "allows plugin init to fail" do
          pm = described_class.new(["rubygems"])
          c1 = Class.new(Plugin) do
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
          expect(pm).to receive(:load_plugin).with(name: "foo").ordered
          expect(pm).to receive(:load_plugin).with(name: "bar").ordered
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
