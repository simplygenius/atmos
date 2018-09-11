require 'simplygenius/atmos/generator'
require 'simplygenius/atmos/source_path'

module SimplyGenius
  module Atmos

    describe Generator do

      include TestConstruct::Helpers

      before(:each) do
        SourcePath.clear_registry
      end

      let(:gen) { described_class.new(quiet: true, force: true) }

      def with_sourcepaths
        within_construct do |sp_dir|
          sp_dir.file('sp1/template1/templates.yml')
          sp_dir.file('sp2/template2/templates.yml')
          sp1 = SourcePath.register("sp1", "#{sp_dir}/sp1")
          sp2 = SourcePath.register("sp2", "#{sp_dir}/sp2")

          within_construct do |app_dir|
            # cwd at this point for tests using this is app_dir
            yield sp_dir, app_dir
          end
        end
      end

      describe "apply_template" do

        it "handles simple template" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/foo.txt', "hello")
            gen.apply_template(SourcePath.find_template('template1'))
            expect(File.exist?("#{app_dir}/foo.txt")).to be true
            expect(open("foo.txt").read).to eq("hello")
            expect(Dir["*"]).to eq(["foo.txt"])
          end
        end

        it "handles nested template" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/subdir/template3/templates.yml')
            sp_dir.file('sp1/subdir/template3/foo.txt', "hello")
            gen.apply_template(SourcePath.find_template('subdir/template3'))
            expect(File.exist?('foo.txt')).to be true
            expect(open("foo.txt").read).to eq("hello")
          end
        end

        it "ignores template metadata" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/templates.yml')
            sp_dir.file('sp1/template1/templates.rb')
            gen.apply_template(SourcePath.find_template('template1'))
            expect(File.exist?('templates.yml')).to be false
            expect(File.exist?('templates.rb')).to be false
          end
        end

        it "preserves directory structure" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/subdir/foo.txt', "hello")
            gen.apply_template(SourcePath.find_template('template1'))
            expect(File.exist?('subdir/foo.txt')).to be true
            expect(open("#{app_dir}/subdir/foo.txt").read).to eq("hello")
          end
        end

        it "handles optional qualifier" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/templates.yml', YAML.dump('optional' => {'sub/bar.txt' => 'false'}))
            sp_dir.file('sp1/template1/foo.txt', "hello")
            sp_dir.file('sp1/template1/sub/bar.txt', "there")
            gen.apply_template(SourcePath.find_template('template1'))
            expect(File.exist?('foo.txt')).to be true
            expect(File.exist?('sub/bar.txt')).to be false
          end
        end

        it "optional qualifier sees helper methods" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/templates.yml', YAML.dump('optional' => {
                'sub/foo.txt' => 'get_config("foo.yml", "not")',
                'sub/bar.txt' => 'get_config("foo.yml", "foo")'
            }))
            sp_dir.file('sp1/template1/foo.yml', YAML.dump("foo" => "bar"))
            sp_dir.file('sp1/template1/sub/foo.txt', "hello")
            sp_dir.file('sp1/template1/sub/bar.txt', "there")
            gen.apply_template(SourcePath.find_template('template1'))
            expect(File.exist?('sub/foo.txt')).to be false
            expect(File.exist?('sub/bar.txt')).to be true
          end
        end

        it "processes procedural template" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/templates.yml', YAML.dump('optional' => {'sub/bar.txt' => 'false'}))
            sp_dir.file('sp1/template1/templates.rb', 'append_to_file "foo.txt", "there"')
            sp_dir.file('sp1/template1/foo.txt', "hello")
            gen.apply_template(SourcePath.find_template('template1'))
            expect(File.exist?('foo.txt')).to be true
            expect(open("#{app_dir}/foo.txt").read).to eq("hellothere")
          end
        end

      end

      describe "generate" do

        it "generates single" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/foo.txt')
            gen.generate('template1')
            expect(File.exist?('foo.txt')).to be true
          end
        end

        it "generates multiple" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/foo.txt')
            sp_dir.file('sp2/template2/bar.txt')
            sp_dir.file('sp2/subdir/template3/templates.yml')
            sp_dir.file('sp2/subdir/template3/baz.txt')
            gen.generate('template1', 'template2', 'subdir/template3')
            expect(File.exist?('foo.txt')).to be true
            expect(File.exist?('bar.txt')).to be true
            expect(File.exist?('baz.txt')).to be true
          end
        end

        it "can choose when to perform dependencies" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => 'template1'))
            gen = described_class.new(quiet: true, force: true)
            expect(gen.generate('template2').to_a.collect(&:name)).to eq(['template1', 'template2'])
            gen = described_class.new(quiet: true, force: true, dependencies: true)
            expect(gen.generate('template2').to_a.collect(&:name)).to eq(['template1', 'template2'])
            gen = described_class.new(quiet: true, force: true, dependencies: false)
            expect(gen.generate('template2').to_a.collect(&:name)).to eq(['template2'])
          end
        end

        it "generates with deps" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/foo.txt')
            sp_dir.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => ['template1']))
            sp_dir.file('sp2/template2/bar.txt')
            sp_dir.file('sp2/subdir/template3/templates.yml', YAML.dump('dependent_templates' => ['template2']))
            sp_dir.file('sp2/subdir/template3/baz.txt')
            gen.generate('subdir/template3')
            expect(File.exist?('foo.txt')).to be true
            expect(File.exist?('bar.txt')).to be true
            expect(File.exist?('baz.txt')).to be true
          end
        end

        it "generates uniquely" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/templates.rb', 'create_file "files/#{Time.now.to_f}", "foo"')
            sp_dir.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => ['template1']))
            sp_dir.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => ['template2', 'template1']))
            gen.generate('template3')
            expect(Dir["files/*"].size).to eq 1
          end
        end

        it "factors context into uniqueness" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/templates.rb', 'create_file "files/#{Time.now.to_f}", context')
            sp_dir.file('sp2/template2/templates.yml', YAML.dump(
                'dependent_templates' => [
                    {'name' => 'template1', 'context' => {'template1' => {'foo' => 'bar'}}}
                ]))
            sp_dir.file('sp2/template3/templates.yml', YAML.dump(
                'dependent_templates' => [
                    {'name' => 'template1', 'context' => {'template1' => {'bar' => 'baz'}}}
                ]))
            sp_dir.file('sp2/template4/templates.yml', YAML.dump(
                'dependent_templates' => ['template2', 'template3']
            ))
            expect(gen.generate('template4').collect(&:name)).to eq(['template1', 'template2', 'template1', 'template3', 'template4'])
            expect(Dir["files/*"].size).to eq 2
          end
        end

        it "ignores other template context for uniqueness" do
          with_sourcepaths do |sp_dir, app_dir|
            sp_dir.file('sp1/template1/templates.rb', 'create_file "files/#{Time.now.to_f}", context')
            sp_dir.file('sp2/template2/templates.yml', YAML.dump(
                'dependent_templates' => [
                    {'name' => 'template1', 'context' => {'template5' => {'foo' => 'bar'}}}
                ]))
            sp_dir.file('sp2/template3/templates.yml', YAML.dump(
                'dependent_templates' => [
                    {'name' => 'template1', 'context' => {'template5' => {'bar' => 'baz'}}}
                ]))
            sp_dir.file('sp2/template4/templates.yml', YAML.dump(
                'dependent_templates' => ['template2', 'template3']
            ))
            expect(gen.generate('template4').collect(&:name)).to eq(['template1', 'template2', 'template3', 'template4'])
            expect(Dir["files/*"].size).to eq 1
          end
        end

      end

      describe "custom template actions" do

        describe "uses UI actions" do

          it "passes through to UI" do
            with_sourcepaths do |sp_dir, app_dir|
              thor = gen.apply_template(SourcePath.find_template('template1'))

              expect{thor.say('foo')}.to output("foo\n").to_stdout
              expect{thor.error.say('foo')}.to output("foo\n").to_stdout
              result = nil
              expect { simulate_stdin("y") { result = thor.agree("foo ") } }.to output("foo ").to_stdout
              expect(result).to eq(true)
              result = nil
              expect { simulate_stdin("y") { result = thor.ask("foo ") } }.to output("foo ").to_stdout
              expect(result).to eq("y")
              result = nil
              expect { simulate_stdin("foo") {
                result = thor.choose {|m| m.prompt = "foo "; m.choices(:foo, :bar); m.default = :bar}
              }}.to output("1. foo\n2. bar\n(bar) foo ").to_stdout
              expect(result).to eq(:foo)
            end
          end

          it "skips UI by looking up from context" do
            with_sourcepaths do |sp_dir, app_dir|
              tmpl = SourcePath.find_template('template1')
              tmpl.scoped_context.merge!({foo: "answer", bar: "yes", baz: :bar})
              thor = gen.apply_template(tmpl)

              result = nil
              expect { simulate_stdin("other") { result = thor.ask("question ", varname: :askfoo) } }.to output("question ").to_stdout
              expect(result).to eq("other")
              expect(thor.ask("question ", varname: :foo)).to eq("answer")

              result = nil
              expect { simulate_stdin("n") { result = thor.agree("question ", varname: :agreefoo) } }.to output("question ").to_stdout
              expect(result).to eq(false)
              expect(thor.agree("question ", varname: :foo)).to eq(true)

              result = nil
              expect { simulate_stdin("foo") { result = thor.choose(varname: :choosefoo) {|m| m.prompt = "foo "; m.choices(:foo, :bar); m.default = :bar}}}.to output("1. foo\n2. bar\n(bar) foo ").to_stdout
              expect(result).to eq(:foo)
              expect(thor.choose(varname: :baz) {|m| m.prompt = "foo "; m.choices(:foo, :bar); m.default = :bar}).to eq(:bar)
            end
          end

          it "populates context with answer" do
            with_sourcepaths do |sp_dir, app_dir|
              tmpl = SourcePath.find_template('template1')
              thor = gen.apply_template(tmpl)

              result = nil
              expect { simulate_stdin("other") { result = thor.ask("question ", varname: :askfoo) } }.to output("question ").to_stdout
              expect(result).to eq("other")
              expect(tmpl.scoped_context[:askfoo]).to eq("other")

              result = nil
              expect { simulate_stdin("n") { result = thor.agree("question ", varname: :agreefoo) } }.to output("question ").to_stdout
              expect(result).to eq(false)
              expect(tmpl.scoped_context[:agreefoo]).to eq(false)

              result = nil
              expect { simulate_stdin("foo") {
                result = thor.choose(varname: :choosefoo) {|m| m.prompt = "foo "; m.choices(:foo, :bar); m.default = :bar}
              }}.to output("1. foo\n2. bar\n(bar) foo ").to_stdout
              expect(result).to eq(:foo)
              expect(tmpl.scoped_context[:choosefoo]).to eq(:foo)

            end
          end

          it "uses template name to namespace context lookup" do
            with_sourcepaths do |sp_dir, app_dir|
              sp_dir.file('sp2/subdir/template-3/templates.yml')
              tmpl = SourcePath.find_template('subdir/template-3')
              tmpl.context.merge!(subdir: {template_3: {foo: "answer"}})
              expect(tmpl.scoped_context).to eq({"foo" => "answer"})
              thor = gen.apply_template(tmpl)

              expect(thor.ask("question ", varname: :foo)).to eq("answer")
            end
          end

          it "passes context to dependencies by defaut" do
            with_sourcepaths do |sp_dir, app_dir|
              sp_dir.file('sp1/template1/templates.rb', 'create_file("foo.txt", ask("question", varname: :foo))')
              sp_dir.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => ['template1']))
              sp_dir.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => [{name: 'template2', context: {template1: {foo: "other"}, template2: {foo: "answer"}}}]))
              gen.generate('template3')
              expect(File.exist?('foo.txt')).to be true
              expect(File.read('foo.txt')).to eq("other")
            end
          end

          it "uses context for varname lookups" do
            with_sourcepaths do |sp_dir, app_dir|
              tmpl = SourcePath.find_template('template1')
              tmpl.scoped_context.merge!({foo: "answer"})
              thor = gen.apply_template(tmpl)

              result = nil
              expect { simulate_stdin("other") { result = thor.ask("question ", varname: :askfoo) } }.to output("question ").to_stdout
              expect(result).to eq("other")
              expect(tmpl.scoped_context[:askfoo]).to eq("other")
              expect(thor.askfoo).to eq("other")
              expect(thor.foo).to eq("answer")
            end
          end

        end

        describe "raw_configs" do

          it "loads config file once" do
            with_sourcepaths do |sp_dir, app_dir|
              app_dir.file('foo.yml', YAML.dump('foo' => 'bar'))

              expect(YAML).to receive(:load_file).once.with('foo.yml').and_call_original

              thor = gen.apply_template(SourcePath.find_template('template1'))
              config = thor.raw_config('foo.yml')
              expect(config).to be_a_kind_of(SettingsHash)
              expect(config['foo']).to eq('bar')

              config = thor.raw_config('foo.yml')
              expect(config).to be_a_kind_of(SettingsHash)
              expect(config['foo']).to eq('bar')
            end
          end

        end

        describe "get_config" do

          it "gets config from yml" do
            with_sourcepaths do |sp_dir, app_dir|
              thor = gen.apply_template(SourcePath.find_template('template1'))

              app_dir.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}))

              expect(thor.get_config('foo.yml', 'foo.bar')).to eq('baz')
            end
          end

        end

        describe "config_present?" do

          it "checks for presence" do
            with_sourcepaths do |sp_dir, app_dir|
              thor = gen.apply_template(SourcePath.find_template('template1'))

              app_dir.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}, 'list' => ['one']))

              expect(thor.config_present?('foo.yml', 'foo.bar')).to be true
              expect(thor.config_present?('foo.yml', 'list')).to be true
              expect(thor.config_present?('foo.yml', 'blah')).to be false
            end
          end

          it "checks for simple value" do
            with_sourcepaths do |sp_dir, app_dir|
              thor = gen.apply_template(SourcePath.find_template('template1'))

              app_dir.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}))

              expect(thor.config_present?('foo.yml', 'foo.bar', 'baz')).to be true
              expect(thor.config_present?('foo.yml', 'foo.bar', 'not')).to be false
            end
          end

          it "checks for list contents" do
            with_sourcepaths do |sp_dir, app_dir|
              thor = gen.apply_template(SourcePath.find_template('template1'))

              app_dir.file('foo.yml', YAML.dump('foo' => {'bar' => ['hum', 'baz']}))

              expect(thor.config_present?('foo.yml', 'foo.bar', 'baz')).to be true
              expect(thor.config_present?('foo.yml', 'foo.bar', 'not')).to be false
              expect(thor.config_present?('foo.yml', 'not', 'not')).to be false
            end
          end

          it "checks for all of list to be present" do
            with_sourcepaths do |sp_dir, app_dir|
              thor = gen.apply_template(SourcePath.find_template('template1'))

              app_dir.file('foo.yml', YAML.dump('foo' => ['hum', 'baz']))

              expect(thor.config_present?('foo.yml', 'foo', 'hum')).to be true
              expect(thor.config_present?('foo.yml', 'foo', 'baz')).to be true
              expect(thor.config_present?('foo.yml', 'foo', 'blah')).to be false
              expect(thor.config_present?('foo.yml', 'foo', ['baz'])).to be true
              expect(thor.config_present?('foo.yml', 'foo', ['hum', 'baz'])).to be true
              expect(thor.config_present?('foo.yml', 'foo', ['baz', 'hum'])).to be true
              expect(thor.config_present?('foo.yml', 'foo', ['baz', 'hum', 'blah'])).to be false
              expect(thor.config_present?('foo.yml', 'foo', ['blah'])).to be false
            end
          end

        end

        describe "add_config" do

          it "adds to config file multiple times preseving comments" do
            with_sourcepaths do |sp_dir, app_dir|

              sp_dir.file('sp1/template1/templates.rb', <<~EOF
                add_config "config/atmos.yml", "foo.bar.baz", "bum"
                add_config "config/atmos.yml", "dude", "ette"
              EOF
              )
              data = <<~EOF
                # comment 1
                foo:
                  # comment 2
                  bah: blah
                hum: hi
              EOF
              app_dir.file("config/atmos.yml", data)
              gen.apply_template(SourcePath.find_template('template1'))

              new_data = File.read("config/atmos.yml")
              expect(new_data.lines.grep(/comment/).length).to eq(2)

              new_data = YAML.load(new_data)
              expect(new_data).to eq({"foo"=>{"bah"=>"blah", "bar"=>{"baz"=>"bum"}}, "hum"=>"hi", "dude"=>"ette"})
            end
          end

        end

        describe "new_keys?" do

          it "checks if config has more keys" do
            with_sourcepaths do |sp_dir, app_dir|

              thor = gen.apply_template(SourcePath.find_template('template1'))

              data = {"foo" => 'bar', "hum" => 'hi'}
              sp_dir.file("foo.yml", YAML.dump(data))
              app_dir.file("foo.yml", YAML.dump(data))

              expect(thor.new_keys?("#{sp_dir}/foo.yml", 'foo.yml')).to be false

              # new_keys? only reads a file once (via raw_config)
              within_construct do |sp_dir|
                sp_dir.file("foo.yml", YAML.dump({"foo" => 'bar'}))
                expect(thor.new_keys?("#{sp_dir}/foo.yml", 'foo.yml')).to be false
              end

              within_construct do |sp_dir|
                sp_dir.file("foo.yml", YAML.dump({"baz" => "bum"}))
                expect(thor.new_keys?("#{sp_dir}/foo.yml", 'foo.yml')).to be true
              end

              within_construct do |sp_dir|
                sp_dir.file("foo.yml", YAML.dump(data.merge("baz" => "bum")))
                expect(thor.new_keys?("#{sp_dir}/foo.yml", 'foo.yml')).to be true
              end

            end
          end

        end

        describe "generate" do

          it "can generate another template" do
            with_sourcepaths do |sp_dir, app_dir|
              sp_dir.file('sp2/template2/foo.txt', "hello")
              thor = gen.apply_template(SourcePath.find_template('template1'))

              expect(File.exist?('foo.txt')).to be false
              thor.generate('template2')
              expect(File.exist?('foo.txt')).to be true
            end
          end

          it "passes context to dependencies by defaut" do
            with_sourcepaths do |sp_dir, app_dir|
              sp_dir.file('sp1/template1/templates.rb', <<~EOF
                create_file("context.yml", context.to_yaml)
                create_file("scoped_context.yml", scoped_context.to_yaml)
              EOF
              )
              sp_dir.file('sp2/template2/templates.rb', "generate('template1')")
              ctx = {template1: {foo: "other"}, template2: {foo: "answer"}}
              sp_dir.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => [
                  {name: 'template2'}.merge(context: ctx)
              ]))
              gen.generate('template3')
              expect(File.exist?('context.yml')).to be true
              expect(File.exist?('scoped_context.yml')).to be true
              expect(YAML.load_file('context.yml')).to eq(SettingsHash.new(ctx))
              expect(YAML.load_file('scoped_context.yml')).to eq(SettingsHash.new(ctx)[:template1])
            end
          end

        end

      end
    end

  end
end
