require 'simplygenius/atmos/generator'
require 'simplygenius/atmos/source_path'

module SimplyGenius
  module Atmos

    describe Generator do

      include TestConstruct::Helpers

      def with_sourcepaths
        within_construct do |c|
          c.file('sp1/template1/templates.yml')
          c.file('sp2/template2/templates.yml')
          yield c, [SourcePath.new("sp1", "#{c}/sp1"), SourcePath.new("sp2", "#{c}/sp2")]
        end
      end

      describe "sourcepath_for" do

        it "finds sourcepath for template" do
          with_sourcepaths do |c, sps|
            gen = described_class.new(*sps)
            expect(gen.send(:sourcepath_for, "template1")).to eq(sps[0])
            expect(gen.send(:sourcepath_for, "template2")).to eq(sps[1])
          end
        end

        it "memoizes sourcepath" do
          with_sourcepaths do |c, sps|
            gen = described_class.new(*sps)
            expect(sps[0]).to receive(:template_names).once.and_call_original
            expect(gen.send(:sourcepath_for, "template1")).to eq(sps[0])
            expect(gen.send(:sourcepath_for, "template1")).to eq(sps[0])
          end
        end

        it "fails if no matching sourcepath" do
          with_sourcepaths do |c, sps|
            gen = described_class.new(*sps)
            expect { gen.send(:sourcepath_for, "template3") }.to raise_error(ArgumentError, /Could not find template/)
          end
        end

        it "prompts for duplicate sourcepath" do
          with_sourcepaths do |c, sps|
            c.file('sp2/template1/templates.yml')
            gen = described_class.new(*sps)
            result = nil
            expect {
              simulate_stdin("2") {
                result = gen.send(:sourcepath_for, "template1")
              }
            }.to output(/1. sp1\n2. sp2\n/).to_stdout
            expect(result).to eq(sps[1])
          end
        end

        it "uses first for duplicate sourcepath when forcing" do
          with_sourcepaths do |c, sps|
            c.file('sp2/template1/templates.yml')
            gen = described_class.new(*sps, force: true)
            result = gen.send(:sourcepath_for, "template1")
            expect(result).to eq(sps[0])
          end
        end

      end

      describe "walk_dependencies" do

        it "can skip dependencies" do
          with_sourcepaths do |c, sps|
            c.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => 'template1'))
            gen = described_class.new(*sps, dependencies: false)
            expect(gen.send(:walk_dependencies, {template: 'template2'}).to_a).to eq([{'template' => 'template2'}])
          end
        end

        it "handles simple dep" do
          with_sourcepaths do |c, sps|
            c.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => 'template1'))
            gen = described_class.new(*sps, dependencies: true)
            expect(gen.send(:walk_dependencies, {template: 'template2'}).to_a).to eq([{'template' => 'template1'}, {'template' => 'template2'}])
          end
        end

        it "handles nested dep" do
          with_sourcepaths do |c, sps|
            c.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => 'template1'))
            c.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => 'template2'))
            gen = described_class.new(*sps, dependencies: true)
            expect(gen.send(:walk_dependencies, {template: 'template3'}).to_a).to eq([{"template" => "template1"}, {"template" => "template2"}, {"template" => "template3"}])
          end
        end

        it "handles multiple deps" do
          with_sourcepaths do |c, sps|
            c.file('sp2/template2/templates.yml')
            c.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => ['template2', 'template1']))
            gen = described_class.new(*sps, dependencies: true)
            expect(gen.send(:walk_dependencies, {template: 'template3'}).to_a).to eq([{"template" => "template2"}, {"template" => "template1"}, {"template" => "template3"}])
          end
        end

        it "handles circular" do
          with_sourcepaths do |c, sps|
            c.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => ['template4']))
            c.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => ['template2']))
            c.file('sp2/template4/templates.yml', YAML.dump('dependent_templates' => ['template3']))
            gen = described_class.new(*sps, dependencies: true)
            expect { gen.send(:walk_dependencies, {template: 'template4'}).to_a }.to raise_error(ArgumentError, /Circular/)
          end
        end

      end

      describe "apply_template" do

        it "handles simple template" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/foo.txt', "hello")
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.send(:apply_template, {template: 'template1'})
              expect(File.exist?('foo.txt')).to be true
              expect(open("#{d}/foo.txt").read).to eq("hello")
              expect(Dir["*"]).to eq(['foo.txt'])
            end
          end
        end

        it "handles nested template" do
          with_sourcepaths do |c, sps|
            c.file('sp1/subdir/template3/templates.yml')
            c.file('sp1/subdir/template3/foo.txt', "hello")
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.send(:apply_template, {template: 'subdir/template3'})
              expect(File.exist?('foo.txt')).to be true
              expect(open("#{d}/foo.txt").read).to eq("hello")
            end
          end
        end

        it "ignores template metadata" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/templates.yml')
            c.file('sp1/template1/templates.rb')
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.send(:apply_template, {template: 'template1'})
              expect(File.exist?('templates.yml')).to be false
              expect(File.exist?('templates.rb')).to be false
            end
          end
        end

        it "preserves directory structure" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/subdir/foo.txt', "hello")
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.send(:apply_template, {template: 'template1'})
              expect(File.exist?('subdir/foo.txt')).to be true
              expect(open("#{d}/subdir/foo.txt").read).to eq("hello")
            end
          end
        end

        it "handles optional qualifier" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/templates.yml', YAML.dump('optional' => {'sub/bar.txt' => 'false'}))
            c.file('sp1/template1/foo.txt', "hello")
            c.file('sp1/template1/sub/bar.txt', "there")
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.send(:apply_template, {template: 'template1'})
              expect(File.exist?('foo.txt')).to be true
              expect(File.exist?('sub/bar.txt')).to be false
            end
          end
        end

        it "optional qualifier sees helper methods" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/templates.yml', YAML.dump('optional' => {
                'sub/foo.txt' => 'get_config("foo.yml", "not")',
                'sub/bar.txt' => 'get_config("foo.yml", "foo")'
            }))
            c.file('sp1/template1/foo.yml', YAML.dump("foo" => "bar"))
            c.file('sp1/template1/sub/foo.txt', "hello")
            c.file('sp1/template1/sub/bar.txt', "there")
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.send(:apply_template, {template: 'template1'})
              expect(File.exist?('sub/foo.txt')).to be false
              expect(File.exist?('sub/bar.txt')).to be true
            end
          end
        end

        it "processes procedural template" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/templates.yml', YAML.dump('optional' => {'sub/bar.txt' => 'false'}))
            c.file('sp1/template1/templates.rb', 'append_to_file "foo.txt", "there"')
            c.file('sp1/template1/foo.txt', "hello")
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.send(:apply_template, {template: 'template1'})
              expect(File.exist?('foo.txt')).to be true
              expect(open("#{d}/foo.txt").read).to eq("hellothere")
            end
          end
        end

      end

      describe "generate" do

        it "generates single" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/foo.txt')
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.generate('template1')
              expect(File.exist?('foo.txt')).to be true
            end
          end
        end

        it "generates multiple" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/foo.txt')
            c.file('sp2/template2/bar.txt')
            c.file('sp2/subdir/template3/templates.yml')
            c.file('sp2/subdir/template3/baz.txt')
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.generate(['template1', 'template2', 'subdir/template3'])
              expect(File.exist?('foo.txt')).to be true
              expect(File.exist?('bar.txt')).to be true
              expect(File.exist?('baz.txt')).to be true
            end
          end
        end

        it "generates with deps" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/foo.txt')
            c.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => ['template1']))
            c.file('sp2/template2/bar.txt')
            c.file('sp2/subdir/template3/templates.yml', YAML.dump('dependent_templates' => ['template2']))
            c.file('sp2/subdir/template3/baz.txt')
            gen = described_class.new(*sps, quiet: true, force: true)
            within_construct do |d|
              gen.generate('subdir/template3')
              expect(File.exist?('foo.txt')).to be true
              expect(File.exist?('bar.txt')).to be true
              expect(File.exist?('baz.txt')).to be true
            end
          end
        end

        it "generates uniquely" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/templates.rb', 'create_file "files/#{Time.now.to_f}", "foo"')
            c.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => ['template1']))
            c.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => ['template2', 'template1']))
            gen = described_class.new(*sps, quiet: true, dependencies: true)
            within_construct do |d|
              gen.generate('template3')
              expect(Dir["files/*"].size).to eq 1
            end
          end
        end

        it "factors context into uniqueness" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/templates.rb', 'create_file "files/#{Time.now.to_f}", context')
            c.file('sp2/template2/templates.yml', YAML.dump(
                'dependent_templates' => [
                    {'template' => 'template1', 'template1' => {'name' => 'template2'}}
                ]))
            c.file('sp2/template3/templates.yml', YAML.dump(
                'dependent_templates' => [
                    'template2',
                    {'template' => 'template1', 'template1' => {'name' => 'template3'}}
                ]))
            gen = described_class.new(*sps, quiet: true, dependencies: true)
            within_construct do |d|
              gen.generate('template3')
              expect(Dir["files/*"].size).to eq 2
            end
          end
        end

        it "ignores other template context for uniqueness" do
          with_sourcepaths do |c, sps|
            c.file('sp1/template1/templates.rb', 'create_file "files/#{Time.now.to_f}", context')
            c.file('sp2/template2/templates.yml', YAML.dump(
                'dependent_templates' => [
                    {'template' => 'template1', 'template5' => {'name' => 'template2'}}
                ]))
            c.file('sp2/template3/templates.yml', YAML.dump(
                'dependent_templates' => [
                    'template2',
                    {'template' => 'template1', 'template5' => {'name' => 'template3'}}
                ]))
            gen = described_class.new(*sps, quiet: true, dependencies: true)
            within_construct do |d|
              gen.generate('template3')
              expect(Dir["files/*"].size).to eq 1
            end
          end
        end

      end

      describe "custom template actions" do

        describe "uses UI actions" do

          it "passes through to UI" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1'})

              expect{thor.say('foo')}.to output("foo\n").to_stdout
              expect{thor.error.say('foo')}.to output("foo\n").to_stdout
              result = nil
              expect { simulate_stdin("y") { result = thor.agree("foo ") } }.to output("foo ").to_stdout
              expect(result).to eq(true)
              result = nil
              expect { simulate_stdin("y") { result = thor.ask("foo ") } }.to output("foo ").to_stdout
              expect(result).to eq("y")
            end
          end

          it "skips UI by looking up from context" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1', template1: {foo: "answer", bar: "yes"}})

              result = nil
              expect { simulate_stdin("other") { result = thor.ask("question ", varname: :notfoo) } }.to output("question ").to_stdout
              expect(result).to eq("other")
              expect(thor.ask("question ", varname: :foo)).to eq("answer")

              result = nil
              expect { simulate_stdin("n") { result = thor.agree("question ", varname: :notfoo) } }.to output("question ").to_stdout
              expect(result).to eq(false)
              expect(thor.agree("question ", varname: :foo)).to eq(true)
            end
          end

          it "uses template name to namespace context lookup" do
            with_sourcepaths do |c, sps|
              c.file('sp2/subdir/template-3/templates.yml')
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'subdir/template-3', subdir: {template_3: {foo: "answer"}}})

              expect(thor.agree("question ", varname: :foo)).to eq(true)
            end
          end

          it "passes context to dependencies by defaut" do
            with_sourcepaths do |c, sps|
              c.file('sp1/template1/templates.rb', 'create_file("foo.txt", ask("question", varname: :foo))')
              c.file('sp2/template2/templates.yml', YAML.dump('dependent_templates' => ['template1']))
              c.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => [{template: 'template2', template1: {foo: "other"}, template2: {foo: "answer"}}]))
              within_construct do |d|
                gen = described_class.new(*sps, quiet: true, force: true)
                gen.generate('template3')
                expect(File.exist?('foo.txt')).to be true
                expect(File.read('foo.txt')).to eq("other")
              end
            end
          end

        end

        describe "raw_configs" do

          it "loads config file once" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              c.file('foo.yml', YAML.dump('foo' => 'bar'))

              expect(YAML).to receive(:load_file).once.with('foo.yml').and_call_original

              thor = gen.send(:apply_template, {template: 'template1'})
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
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1'})

              c.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}))

              expect(thor.get_config('foo.yml', 'foo.bar')).to eq('baz')
            end
          end

        end

        describe "config_present?" do

          it "checks for presence" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1'})

              c.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}, 'list' => ['one']))

              expect(thor.config_present?('foo.yml', 'foo.bar')).to be true
              expect(thor.config_present?('foo.yml', 'list')).to be true
              expect(thor.config_present?('foo.yml', 'blah')).to be false
            end
          end

          it "checks for simple value" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1'})

              c.file('foo.yml', YAML.dump('foo' => {'bar' => 'baz'}))

              expect(thor.config_present?('foo.yml', 'foo.bar', 'baz')).to be true
              expect(thor.config_present?('foo.yml', 'foo.bar', 'not')).to be false
            end
          end

          it "checks for list contents" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1'})

              c.file('foo.yml', YAML.dump('foo' => {'bar' => ['hum', 'baz']}))

              expect(thor.config_present?('foo.yml', 'foo.bar', 'baz')).to be true
              expect(thor.config_present?('foo.yml', 'foo.bar', 'not')).to be false
              expect(thor.config_present?('foo.yml', 'not', 'not')).to be false
            end
          end

          it "checks for all of list to be present" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1'})

              c.file('foo.yml', YAML.dump('foo' => ['hum', 'baz']))

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
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)

              c.file('sp1/template1/templates.rb', <<~EOF
                add_config "config/atmos.yml", "foo.bar.baz", "bum"
                add_config "config/atmos.yml", "dude", "ette"
              EOF
              )
              within_construct do |d|
                data = <<~EOF
                  # comment 1
                  foo:
                    # comment 2
                    bah: blah
                  hum: hi
                EOF
                d.file("config/atmos.yml", data)
                gen.send(:apply_template, {template: 'template1'})

                new_data = File.read("config/atmos.yml")
                expect(new_data.lines.grep(/comment/).length).to eq(2)

                new_data = YAML.load(new_data)
                expect(new_data).to eq({"foo"=>{"bah"=>"blah", "bar"=>{"baz"=>"bum"}}, "hum"=>"hi", "dude"=>"ette"})
              end
            end
          end

        end

        describe "new_keys?" do

          it "checks if config has more keys" do
            with_sourcepaths do |c, sps|
              gen = described_class.new(*sps, quiet: true, force: true)

              c.file('sp1/template1//templates.rb', 'new_keys? "#{template_dir}/foo.yml", "foo.yml"')
              data = {"foo" => 'bar', "hum" => 'hi'}
              c.file("foo.yml", YAML.dump(data))

              thor = gen.send(:apply_template, {template: 'template1'})

              within_construct do |d|
                d.file("foo.yml", YAML.dump(data))
                expect(thor.send(:new_keys?, "#{d}/foo.yml", 'foo.yml')).to be false
              end

              within_construct do |d|
                d.file("foo.yml", YAML.dump({"foo" => 'bar'}))
                expect(thor.send(:new_keys?, "#{d}/foo.yml", 'foo.yml')).to be false
              end

              within_construct do |d|
                d.file("foo.yml", YAML.dump(data.merge("baz" => "bum")))
                expect(thor.send(:new_keys?, "#{d}/foo.yml", 'foo.yml')).to be true
              end
            end
          end

        end

        describe "apply_template" do

          it "can generate another template" do
            with_sourcepaths do |c, sps|
              c.file('sp2/template2/foo.txt', "hello")
              gen = described_class.new(*sps, quiet: true, force: true)
              thor = gen.send(:apply_template, {template: 'template1'})

              expect(File.exist?('foo.txt')).to be false
              thor.generate('template2')
              expect(File.exist?('foo.txt')).to be true
            end
          end

          it "passes context to dependencies by defaut" do
            with_sourcepaths do |c, sps|
              c.file('sp1/template1/templates.rb', 'create_file("foo.yml", context.to_yaml)')
              c.file('sp2/template2/templates.rb', "generate('template1')")
              ctx = {template1: {foo: "other"}, template2: {foo: "answer"}}
              c.file('sp2/template3/templates.yml', YAML.dump('dependent_templates' => [{template: 'template2'}.merge(ctx)]))
              within_construct do |d|
                gen = described_class.new(*sps, quiet: true, force: true)
                gen.generate('template3')
                expect(File.exist?('foo.yml')).to be true
                expect(YAML.load_file('foo.yml')).to eq(SettingsHash.new(ctx.merge(template: 'template1')))
              end
            end
          end

        end

      end
    end

  end
end
