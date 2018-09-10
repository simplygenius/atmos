require "simplygenius/atmos/commands/generate"

module SimplyGenius
  module Atmos
    module Commands

      describe Generate do

        before(:each) do
          Atmos.config = Config.new("ops")
          @config = SettingsHash.new
          Atmos.config.instance_variable_set(:@config, @config)

          SourcePath.clear_registry
        end

        let(:cli) { described_class.new("") }

        describe "--help" do

          it "produces help text under standard width" do
            expect(cli.help).to be_line_width_for_cli
          end

        end

        describe "--no-sourcepaths" do

          it "does not skip built in and configured sourcepaths by default" do
            within_construct do |c|
              c.file('sp1/foo/templates.yml')

              within_construct do |d|
                d.file("config/atmos.yml", YAML.dump(template_sources: [
                    {
                        name: "local",
                        location: c.to_s
                    }
                ]))
                Atmos.config = Config.new("ops")

                expect(SourcePath).to receive(:register).exactly(3).times
                cli.run(["--sourcepath", "#{c.to_s}/sp1", "--list"])
              end
            end
          end

          it "skips built in and configured sourcepaths" do
            within_construct do |c|
              c.file('sp1/foo/templates.yml')

              within_construct do |d|
                d.file("config/atmos.yml", YAML.dump(template_sources: [
                    {
                        name: "local",
                        location: c.to_s
                    }
                ]))
                Atmos.config = Config.new("ops")

                expect(SourcePath).to receive(:register).once.with("sp1", "#{c.to_s}/sp1")
                cli.run(["--no-sourcepaths", "--sourcepath", "#{c.to_s}/sp1", "--list"])
              end
            end
          end

        end

        describe "--sourcepath" do

          it "adds given sourcepaths to default in correct order" do
            within_construct do |c|
              c.file('sp1/foo/templates.yml')
              c.file('sp2/bar/templates.yml')
              cli.run(["--sourcepath", "#{c.to_s}/sp1", "--sourcepath", "#{c.to_s}/sp2", "--list"])
              expect(Logging.contents).to match(/Sourcepath sp1.*foo.*Sourcepath sp2.*bar.*Sourcepath bundled.*new.*/m)
            end
          end

          it "uses sourcepaths from config" do
            begin
              within_construct do |c|
                c.file('foo/templates.yml')
                within_construct do |d|
                  d.file("config/atmos.yml", YAML.dump(template_sources: [
                      {
                          name: "local",
                          location: c.to_s
                      }
                  ]))
                  Atmos.config = Config.new("ops")

                  cli.run(["--list"])
                  expect(Logging.contents).to match(/Sourcepath local.*foo/m)
                end
              end
            ensure
              Atmos.config = nil
            end
          end

        end

        describe "--context" do

          it "uses given context when running generator" do
            gen = double(generate: nil, visited_templates: [])
            expect(Generator).to receive(:new).
                with(any_args, hash_including(dependencies: true)).
                and_return(gen)
            expect(gen).to receive(:generate).with("new", context: {foo: "bar", baz: {boo: "bum"}, none: nil, blank: ""})
            cli.run(["--context", "foo=bar", "--context", "baz.boo=bum", "--context", "none", "--context", "blank=", "new"])
          end

        end

        describe "--list" do

          it "lists the templates" do
            within_construct do |c|
              c.file('foo/templates.yml')
              c.file('bar/templates.yml')
              c.file('baz/boo/templates.yml')

              cli.run(["--sourcepath", c.to_s, "--list"])
              expect(Logging.contents.lines).to include(/foo/, /bar/, /baz\/boo/)
            end
          end

          it "filters the template list" do
            within_construct do |c|
              c.file('foo/templates.yml')
              c.file('bar/templates.yml')

              cli.run(["--sourcepath", c.to_s, "--list", "fo"])
              expect(Logging.contents).to_not include("bar")
              expect(Logging.contents).to include("foo")
            end
          end

        end

        describe "--no-dependencies" do

          it "does dependencies by default" do
            expect(Generator).to receive(:new).
                with(any_args, hash_including(dependencies: true)).
                and_return(double(generate: nil, visited_templates: []))
            cli.run(["foo"])
          end

          it "can disable dependencies" do
            expect(Generator).to receive(:new).
                with(any_args, hash_including(dependencies: false)).
                and_return(double(generate: nil, visited_templates: []))
            cli.run(["--no-dependencies", "foo"])
          end

        end

        describe "state_file" do

          it "reads state file from config" do
            within_construct do |c|
              @config.notation_put("generate.state_file", nil)
              expect(cli.state_file).to be nil
              @config.notation_put("generate.state_file", ".atmos-templates.yml")
              expect(cli.state_file).to eq(".atmos-templates.yml")
            end
          end

        end

        describe "state" do

          it "has empty state when no state file" do
            within_construct do |c|
              @config.notation_put("generate.state_file", nil)
              expect(cli.state).to eq({})
            end
          end

          it "has empty state when state file not there" do
            within_construct do |c|
              @config.notation_put("generate.state_file", ".atmos-templates.yml")
              expect(cli.state).to eq({})
            end
          end

          it "reads state from state file" do
            within_construct do |c|
              c.file(".atmos-templates.yml", YAML.dump({foo: "bar"}))
              @config.notation_put("generate.state_file", ".atmos-templates.yml")
              expect(cli.state).to eq({"foo" => "bar"})
            end
          end

        end

        describe "save_state" do

          let(:file) { ".atmos-templates.yml" }
          let(:sp) { SourcePath.new("spname", "/tmp/mydir") }
          let(:t1) { Template.new("tmplname1", "/tmp/mydir/tmplname1", sp) }
          let(:t2) { Template.new("tmplname2", "/tmp/mydir/tmplname2", sp) }

          it "does nothing if no state file" do
            within_construct do |c|
              @config.notation_put("generate.state_file", nil)
              cli.save_state([t1, t2], [])
              expect(Dir["#{c}/*"]).to eq([])
            end
          end

          it "saves list of templates" do
            within_construct do |c|
              @config.notation_put("generate.state_file", file)
              cli.save_state([t1], [])
              expect(File.exist?(file)).to be true
              expect(YAML.load_file(file)).to eq({"visited_templates"=>[
                  # FIXME shallow_merge cuz scoped_context adds a hash, and Hashie::Mash aliases merge to deep_merge
                  t1.to_h.shallow_merge("context" => t1.scoped_context)
              ], "entrypoint_templates" => []})
            end
          end

          it "updates and sorts existing list of templates" do
            within_construct do |c|
              @config.notation_put("generate.state_file", file)
              cli.save_state([t2], [])
              cli.save_state([t1], [])
              expect(File.exist?(file)).to be true
              expect(YAML.load_file(file)).to eq({"visited_templates"=>[
                  t1.to_h.shallow_merge("context" => t1.scoped_context),
                  t2.to_h.shallow_merge("context" => t2.scoped_context)
              ], "entrypoint_templates" => []})
            end
          end

          it "updates and sorts entrypoint templates" do
            within_construct do |c|
              @config.notation_put("generate.state_file", file)
              cli.save_state([], ["tmpl3", "tmpl2"])
              cli.save_state([], ["tmpl1"])
              expect(File.exist?(file)).to be true
              expect(YAML.load_file(file)).to eq({"visited_templates"=>[], "entrypoint_templates" => [
                  "tmpl1", "tmpl2", "tmpl3"
              ]})
            end
          end

          it "saves plain ruby hashes and lists to state" do
            within_construct do |c|
              @config.notation_put("generate.state_file", file)
              cli.save_state([t1], [t1.name])
              cli.instance_variable_set(:@config, nil)
              cli.save_state([t2], [t2.name])
              expect(File.exist?(file)).to be true
              expect(File.read(file)).to_not match(/::/) # plain ruby hashes and lists
              expect(YAML.load_file(file)).to eq({"visited_templates"=>[
                  # FIXME shallow_merge cuz scoped_context adds a hash, and Hashie::Mash aliases merge to deep_merge
                  t1.to_h.shallow_merge("context" => t1.scoped_context),
                  t2.to_h.shallow_merge("context" => t1.scoped_context)
              ], "entrypoint_templates" => [t1.name, t2.name]})
            end
          end



        end

        describe "execute" do

          it "requires a template param" do
            within_construct do |d|
              expect { cli.run([]) }.to raise_error(Clamp::UsageError, /template/)
            end
          end

          it "generates a template" do
            within_construct do |d|
              cli.run(["--quiet", "new"])
              expect(File.exist?('config/atmos.yml')).to be true
            end
          end

          it "generates an error for bad template" do
            within_construct do |d|
              expect { cli.run(["--quiet", "foo"]) }.to raise_error(SystemExit)
            end
          end

          it "fails for duplicate templates" do
            within_construct do |c|
              c.file('sp1/new/templates.yml')
              c.file('sp1/new/foo.txt')
              c.file('sp2/new/templates.yml')
              c.file('sp2/new/bar.txt')

              within_construct do |d|
                expect { cli.run(["--quiet", "--force", "--sourcepath", "#{c.to_s}/sp1", "new"]) }.to raise_error(SystemExit)
              end
            end
          end

          it "uses first valid template from multiple sourcepaths" do
            within_construct do |c|
              c.file('sp1/foo/foo.txt')
              c.file('sp2/foo/templates.yml')
              c.file('sp2/foo/bar.txt')
              cli.run(["--sourcepath", "#{c.to_s}/sp1", "--sourcepath", "#{c.to_s}/sp2", "--quiet", "foo"])
              expect(File.exist?('foo.txt')).to be false
              expect(File.exist?('bar.txt')).to be true
            end
          end

        end

      end

    end
  end
end
