require 'simplygenius/atmos/template'

module SimplyGenius
  module Atmos

    describe Template do

      include TestConstruct::Helpers

      let(:sp) { SourcePath.new("spname", "/tmp/mydir") }
      let(:tmpl) { described_class.new("tmplname", "/tmp/mydir/tmplname", sp) }

      describe "to_s" do

        it "provides a string" do
          expect(tmpl.to_s).to eq "tmplname"
        end

      end

      describe "to_h" do

        it "provides a hash" do
          tmpl.context[:foo] = "bar"
          expect(tmpl.to_h).to eq({"name" => "tmplname", "source" => sp.to_h, "context" => {"foo" => "bar"}})
        end

      end

      describe "context_path" do

        it "generates a hash path based on name for scoping" do
          tmpl = Template.new('subdir/my-name', nil, nil)
          expect(tmpl.context_path).to eq "subdir.my_name"
        end

      end

      describe "scoped_context" do

        it "returns an empty hash if not present" do
          tmpl = Template.new('subdir/my-name', nil, nil, context: {})
          expect(tmpl.scoped_context).to eq({})
        end

        it "always returns the same object" do
          expect(tmpl.scoped_context.object_id).to eq(tmpl.scoped_context.object_id)
        end

        it "returns the scoped hash" do
          tmpl = Template.new('subdir/my-name', nil, nil, context: {subdir: {my_name: {foo: "bar"}} })
          expect(tmpl.scoped_context).to eq({"foo" => "bar"})
        end

        it "returns a mutable scoped hash" do
          tmpl = Template.new('subdir/my-name', nil, nil, context: {})
          tmpl.scoped_context[:bar] = "baz"
          expect(tmpl.scoped_context).to eq({"bar" => "baz"})

          tmpl = Template.new('subdir/my-name', nil, nil, context: {subdir: {my_name: {foo: "bar"}} })
          tmpl.scoped_context[:bar] = "baz"
          expect(tmpl.scoped_context).to eq({"foo" => "bar", "bar" => "baz"})
        end

      end

      describe "directory" do

        it "returns the directory" do
          expect(tmpl.directory).to eq("/tmp/mydir/tmplname")
        end

      end

      describe "actions_path" do

        it "returns the actions path" do
          expect(tmpl.actions_path).to eq("/tmp/mydir/tmplname/templates.rb")
        end

      end

      describe "actions" do

        it "returns empty for non-existant actions file once" do
          expect(File).to receive(:exist?).with(tmpl.actions_path).once.and_return(false)
          expect(tmpl.actions).to eq("")
          expect(tmpl.actions).to eq("")
        end

        it "returns contents for existant actions file once" do
          expect(File).to receive(:exist?).with(tmpl.actions_path).once.and_return(true)
          expect(File).to receive(:read).with(tmpl.actions_path).once.and_return("foo")
          expect(tmpl.actions).to eq("foo")
          expect(tmpl.actions).to eq("foo")
        end

      end

      describe "config_path" do

        it "returns the config path" do
          expect(tmpl.config_path).to eq("/tmp/mydir/tmplname/templates.yml")
        end

      end

      describe "config" do

        it "fails for non-existant config file" do
          expect {tmpl.config}.to raise_error(Errno::ENOENT)
        end

        it "returns empty hash for empty config file once" do
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return("")
          expect(tmpl.config).to eq({})
          expect(tmpl.config).to eq({})
        end

        it "returns loaded hash for config file once" do
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return("foo: bar")
          expect(tmpl.config).to eq({"foo" => "bar"})
          expect(tmpl.config).to eq({"foo" => "bar"})
        end

      end

      describe "optional" do

        it "returns an empty optional hash when unset" do
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return("")
          expect(tmpl.optional).to eq({})
        end

        it "returns the optional hash when set" do
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return("optional:\n foo: bar")
          expect(tmpl.optional).to eq({"foo" => "bar"})
        end

        it "fails if optional isn't a hash" do
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return("optional: bar")
          expect { tmpl.optional }.to raise_error(TypeError)
        end

      end

      describe "dependencies" do

        before(:each) do
          allow(SourcePath).to receive(:find_template) do |name|
            Template.new(name, nil, nil)
          end
        end

        it "returns empty dependencies" do
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return("")
          expect(tmpl.dependencies).to eq([])
        end

        it "returns simple dependencies" do
          config = SettingsHash.new ({
              dependent_templates: ["foo"]
          })
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return(config.to_hash.to_yaml)
          deps = tmpl.dependencies
          expect(deps.size).to eq(1)
          expect(deps.first).to match instance_of(Template)
          expect(deps.first.name).to eq("foo")
        end

        it "fails when dependencies wrong type" do
          config = SettingsHash.new ({
              dependent_templates: [true]
          })
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return(config.to_hash.to_yaml)
          expect {tmpl.dependencies}.to raise_error(TypeError)
        end

        it "fails when dependencies hash missing name" do
          config = SettingsHash.new ({
              dependent_templates: [{}]
          })
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return(config.to_hash.to_yaml)
          expect {tmpl.dependencies}.to raise_error(ArgumentError)
        end

        it "returns hash dependencies" do
          config = SettingsHash.new ({
              dependent_templates: [{name: "foo"}]
          })
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return(config.to_hash.to_yaml)
          deps = tmpl.dependencies
          expect(deps.size).to eq(1)
          expect(deps.first).to match instance_of(Template)
          expect(deps.first.name).to eq("foo")
        end

        it "records context with hash dependency" do
          config = SettingsHash.new ({
              dependent_templates: [{name: "foo", context: {foo: "bar"}}]
          })
          expect(File).to receive(:read).with(tmpl.config_path).once.and_return(config.to_hash.to_yaml)
          deps = tmpl.dependencies
          expect(deps.size).to eq(1)
          expect(deps.first).to match instance_of(Template)
          expect(deps.first.name).to eq("foo")
          expect(deps.first.context).to eq({"foo" => "bar"})
        end

      end

      describe "walk_dependencies" do

        before(:each) do
          @templates = {}

          def define_template(name, deps=[])
            tmpl = Template.new(name, nil, nil)
            config = SettingsHash.new ({
                dependent_templates: deps
            })
            tmpl.instance_variable_set(:@config, config)
            @templates[name] = tmpl
          end

          allow(SourcePath).to receive(:find_template) do |name|
            @templates[name]
          end
        end

        it "dups correctly" do
          t1 = define_template('template1')
          t2 = define_template('template2', ['template1'])
          t2.context.merge!(a: [{b: 3}])
          t2.dependencies
          d = t2.dup
          expect(d).to_not be(t2)
          expect(d.context).to_not be(t2.context)
          expect(d.dependencies).to_not be(t2.dependencies)
          expect(d.dependencies.first).to_not be(t2.dependencies.first)

          t1 = define_template('template3')
          t2 = define_template('template4', ['template3'])
          t2.context.merge!(a: [{b: 3}])
          d = t2.dup
          t2.dependencies
          expect(d).to_not be(t2)
          expect(d.context).to_not be(t2.context)
          expect(d.dependencies).to_not be(t2.dependencies)
          expect(d.dependencies.first).to_not be(t2.dependencies.first)
        end

        it "handles simple dep" do
          t1 = define_template('template1')
          t2 = define_template('template2', ['template1'])
          expect(t2.walk_dependencies.to_a.collect(&:name)).to eq(['template1', 'template2'])
        end

        it "produces clones" do
          t1 = define_template('template1')
          t2 = define_template('template2', ['template1'])
          deps = t2.walk_dependencies.to_a
          expect(deps.size).to eq(2)
          expect(deps.first.name).to eq(t1.name)
          expect(deps.first).to_not be(t1)
          expect(deps.last.name).to eq(t2.name)
          expect(deps.last).to_not be(t2)
        end

        it "handles nested dep" do
          t1 = define_template('template1')
          t2 = define_template('template2', ['template1'])
          t3 = define_template('template3', ['template2'])
          expect(t3.walk_dependencies.to_a.collect(&:name)).to eq(['template1', 'template2', 'template3'])
        end

        it "handles multiple deps" do
          t1 = define_template('template1')
          t2 = define_template('template2')
          t3 = define_template('template3', ['template2', 'template1'])
          expect(t3.walk_dependencies.to_a.collect(&:name)).to eq(['template2', 'template1', 'template3'])
        end

        it "walks each dep according to tree path (multiple visits need to be possible as context gets pushed down the tree)" do
          t1 = define_template('template1')
          t2 = define_template('template2', ['template1'])
          t3 = define_template('template3', ['template1'])
          t4 = define_template('template4', ['template3', 'template2'])
          expect(t4.walk_dependencies.to_a.collect(&:name)).to eq(['template1', 'template3', 'template1', 'template2', 'template4'])
        end

        it "handles circular" do
          t1 = define_template('template1', ['template3'])
          t2 = define_template('template2', ['template1'])
          t3 = define_template('template3', ['template2'])
          expect { t3.walk_dependencies.to_a.collect(&:name) }.to raise_error(ArgumentError, /Circular/)
        end

      end

    end

  end
end
