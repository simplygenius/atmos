require 'simplygenius/atmos/settings_hash'

module SimplyGenius
  module Atmos

    describe SettingsHash do


      [true, false].each do |exp|

        @exp = exp
        def create(*args)
          i = described_class.new(*args)
          i.enable_expansion = @exp
          i
        end

        describe "basic operations" do

          it "makes sub hashes same class" do
            config = create(foo: {bar: {baz: {bum: "hum"}}})
            expect(config["foo"]).to be_a_kind_of(described_class)
            expect(config["foo"]["bar"]).to be_a_kind_of(described_class)
            expect(config.foo.bar.baz).to be_a_kind_of(described_class)
          end

          it "preserves root for sub hashes" do
            config = create(foo: {bar: {baz: {bum: "hum"}}})
            expect(config._root_).to be_nil
            expect(config["foo"]._root_).to eq(config)
            expect(config["foo"]["bar"]._root_).to eq(config)
            expect(config.foo.bar.baz._root_).to eq(config)
          end

          it "preserves error_resolver for sub hashes" do
            config = create(foo: {bar: {baz: {bum: "hum"}}})
            er = ->(e) {}
            config.error_resolver = er
            expect(config["foo"].error_resolver).to eq(er)
            expect(config["foo"]["bar"].error_resolver).to eq(er)
            expect(config.foo.bar.baz.error_resolver).to eq(er)
          end

        end

        describe "notation_get" do

          it "handles hash dot notation in keys" do
            config = create(foo: {bar: "baz"})
            expect(config.notation_get("foo.bar")).to eq("baz")
          end

          it "handles list dot notation in keys" do
            config = create(foo: ["bar", "baz"])
            expect(config.notation_get("foo.0")).to eq("bar")
            expect(config.notation_get("foo[1]")).to eq("baz")
          end

          it "handles deep dot notation in keys" do
            config = create(foo: {bar: [{baz: 'bum'}]})
            expect(config.notation_get("foo.bar.0.baz")).to eq("bum")
          end

          it "returns nil for keys that aren't present" do
            config = create
            expect(config.notation_get("foo.bar")).to be_nil
            expect(Logging.contents).to match(/Settings missing value for key='foo.bar'/)
          end

        end

        describe "notation_put" do

          it "handles empty" do
            config = create
            config.notation_put("foo", "bar")
            expect(config["foo"]).to eq("bar")
          end

          it "puts list val" do
            config = create
            config.notation_put("foo", ["bar"])
            expect(config["foo"]).to eq(["bar"])
          end

          it "puts list val additively with list arg" do
            config = create
            config.notation_put("foo", ["bar"])
            config.notation_put("foo", ["baz"], additive: true)
            expect(config["foo"]).to eq(["bar", "baz"])
          end

          it "does union when putting list val additively with list arg" do
            config = create
            config.notation_put("foo", ["bar"])
            config.notation_put("foo", ["baz"], additive: true)
            expect(config["foo"]).to eq(["bar", "baz"])
            config.notation_put("foo", ["baz", "boo"], additive: true)
            expect(config["foo"]).to eq(["bar", "baz", "boo"])
          end

          it "is additive by default" do
            config = create
            config.notation_put("foo", ["bar"])
            config.notation_put("foo", ["baz"])
            expect(config["foo"]).to eq(["bar", "baz"])
          end

          it "puts list val additively with scalar arg" do
            config = create
            config.notation_put("foo", ["bar"])
            config.notation_put("foo", "baz", additive: true)
            expect(config["foo"]).to eq(["bar", "baz"])
          end

          it "puts list val not-additively" do
            config = create
            config.notation_put("foo", ["bar"])
            config.notation_put("foo", ["baz"], additive: false)
            expect(config["foo"]).to eq(["baz"])
            config.notation_put("foo", "baz", additive: false)
            expect(config["foo"]).to eq("baz")
          end

          it "puts deeply" do
            config = create
            config.notation_put("foo.bar.baz", "bum")
            level = config["foo"]
            expect(level).to be_a_kind_of(Hash)
            expect(config.notation_get("foo")).to be_a_kind_of(Hash)
            level = level["bar"]
            expect(level).to be_a_kind_of(Hash)
            expect(config.notation_get("foo.bar")).to be_a_kind_of(Hash)
            level = level["baz"]
            expect(level).to eq("bum")
            expect(config.notation_get("foo.bar.baz")).to eq("bum")
          end

          it "puts list deeply" do
            config = create
            config.notation_put("foo.bar.baz", ["bum"])
            config.notation_put("foo.bar.baz", "boo", additive: true)
            expect(config.notation_get("foo.bar.baz")).to eq(["bum", "boo"])
          end

          it "uses list notation when putting list deeply" do
            config = create
            config.notation_put("foo.0.baz", "bum")
            expect(config.notation_get("foo.0.baz")).to eq("bum")
          end

          it "uses alternate list notation when putting list deeply" do
            config = create
            config.notation_put("foo[0].baz", "bum")
            expect(config.notation_get("foo[0].baz")).to eq("bum")
          end

        end

        describe "add_config" do

          it "adds to config file" do
              within_construct do |c|
                data = {"foo" => {"bah" => 'blah'}, "hum" => 'hi'}
                c.file("foo.yml", YAML.dump(data))
                new_yml = described_class.add_config("foo.yml", "foo.bar.baz", "bum")
                new_data = YAML.load(new_yml)
                expect(new_data).to eq({"foo"=>{"bah"=>"blah", "bar"=>{"baz"=>"bum"}}, "hum"=>"hi"})
              end
            end

          it "preserves comments when adding to config file" do
            within_construct do |c|
              data = <<~EOF
                # multi comment
                # line comment
                foo:
                  # comment 1
                  bah: blah
                  # comment 2
                  dum: bleh
                hum: hi
                empty:
                # comment 3
                dim:
                - sum
                # comment 4
                - bar
              EOF
              c.file("foo.yml", data)
              File.write("foo.yml", described_class.add_config("foo.yml", "foo.bar.baz", "bum"))
              File.write("foo.yml", described_class.add_config("foo.yml", "dim", "some"))
              File.write("foo.yml", described_class.add_config("foo.yml", "empty", "not"))

              new_data = File.read("foo.yml")
              expect(new_data.lines.grep(/comment/).length).to eq(6)
              new_data = YAML.load(new_data)
              expect(new_data['foo']['bar']['baz']).to eq('bum')
              expect(new_data['dim']).to eq(['sum', 'bar', 'some'])
              expect(new_data['empty']).to eq('not')
            end
          end

          it "check stock yml works, preserving comments" do
            within_construct do |c|
              yml = File.read(File.expand_path("../../templates/new/config/atmos.yml", __FILE__))
              c.file("foo.yml", yml)
              comment_count = yml.lines.grep(/^#/).size

              File.write("foo.yml", described_class.add_config("foo.yml",
                                                               "recipes.default", ["atmos-scaffold"]))
              File.write("foo.yml", described_class.add_config("foo.yml", "foo", "bar"))
              File.write("foo.yml", described_class.add_config("foo.yml", "org", "myorg"))

              new_data = File.read("foo.yml")
              new_comment_count = new_data.lines.grep(/^#/).size
              # File.write("/tmp/old.yml", yml)
              # File.write("/tmp/new.yml", new_data)
              # system("diff /tmp/old.yml /tmp/new.yml")
              expect(new_comment_count).to eq(comment_count)

              new_data = YAML.load(new_data)
              expect(new_data['recipes']['default']).to eq(['atmos-scaffold'])
              expect(new_data['foo']).to eq('bar')
            end
          end

        end

      end

      describe "expand" do

        def create(*args)
          i = described_class.new(*args)
          i.enable_expansion = true
          i
        end

        it "handles simple interpolation" do
          config = create(foo: "bar", baz: '#{foo}')
          expect(config["baz"]).to eq("bar")
        end

        it "handles dot notation interpolation" do
          config = create(foo: {bar: ["boo"]}, baz: '#{foo.bar[0]}')
          expect(config["baz"]).to eq("boo")
        end

        it "prevents cycles in interpolation" do
          config = create(foo: '#{baz}', baz: '#{foo}')
          expect { config["foo"] }.to raise_error(SimplyGenius::Atmos::Exceptions::ConfigInterpolationError)
        end

        it "handles multi eval" do
          config = create(foo: "bar", baz: "bum", boo: '#{foo} is #{baz}')
          expect(config["boo"]).to eq("bar is bum")
        end

        it "handles complex eval" do
          config = create(foo: "bar", boo: {bum: "dum"}, baz: '#{foo.size * boo.bum.size}')
          expect(config["baz"]).to eq("9")
        end

        it "handles iterative interpolation" do
          config = create(foo: "bar", baz: '#{foo}', bum: ['#{foo}'])
          expect(config.collect {|k,v| [k,v]}).to eq([["foo", "bar"], ["baz", "bar"], ["bum", ["bar"]]])
          expect(config.to_a).to eq([["foo", "bar"], ["baz", "bar"], ["bum", ["bar"]]])
        end

        it "uses resolver for config error" do
          config = create({baz: '#{1/0}'})
          config.error_resolver = ->(s) { return "atmos.yml", 57 }
          expect{config["baz"]}.
              to raise_error(SimplyGenius::Atmos::Exceptions::ConfigInterpolationError,
                             /Failing config statement '\#{1\/0}' in atmos.yml:57 => ZeroDivisionError.*/)
        end

        it "raises when interpolating a non-existant path" do
          config = create(foo: '#{bar.baz.boo}')
          expect{config.foo}.
              to raise_error(SimplyGenius::Atmos::Exceptions::ConfigInterpolationError,
                            /Failing config statement '\#{bar.baz.boo}' => NoMethodError undefined method `baz' for nil:NilClass/)
        end


        it "handles truthy" do
          config = create(foo: true, bar: false,
                                         baz: '#{foo}', bum: '#{bar}',
                                         foo2: 'true', bar2: 'false',
                                         baz2: '#{foo2}', bum2: '#{bar2}')
          expect(config["foo"]).to be true
          expect(config["bar"]).to be false
          expect(config["baz"]).to be true
          expect(config["bum"]).to be false
          expect(config["foo2"]).to be true
          expect(config["bar2"]).to be false
          expect(config["baz2"]).to be true
          expect(config["bum2"]).to be false
        end

        it "handles additive merge hack" do
          config = create(foo: ["^", "bar", ["^", "baz"]])
          expect(config["foo"]).to eq(["bar", ["baz"]])
        end

        it "handles interpolation references to other interpolations" do
          config = create(foo: '#{"x" + "y"}', baz: '#{foo + "z"}')
          expect(config["baz"]).to eq("xyz")
        end

        it "handles interpolation references to complex interpolations" do
          config = create(foo: '#{ !! /prod/.match(atmos_env) }', baz: '#{foo ? 0 : 1}')
          expect(config["foo"]).to eq(false)
          expect(config["baz"]).to eq("1")
        end

        it "handles interpolation references to unresolved complex interpolations" do
          config = create(baz: '#{foo ? 0 : 1}', foo: '#{ !! /prod/.match(atmos_env) }')
          expect(config["foo"]).to eq(false)
          expect(config["baz"]).to eq("1")
        end

        it "looks up from root deeply" do
          config = create(foo: {bar: "baz", bum: '#{bar}', hum: '#{foo.bar}'})
          expect(config.foo.hum).to eq("baz")
        end

        it "looks up from local first" do
          config = create(foo: {bar: "hum", baz: '#{bar}', bazzy: '#{_root_.bar}', hum: 'dum', bum: '#{hum}'}, bar: "bah")
          expect(config.foo.baz).to eq("hum")
          expect(config.foo.bazzy).to eq("bah")
          expect(config.foo.bum).to eq("dum")
        end

        it "can use root qualifier when looking up from root" do
          config = create(foo: {bar: "baz"}, bum: {hum: '#{_root_.foo.bar}'})
          expect(config.bum.hum).to eq("baz")
        end

        it "can use fetch" do
          config = create(foo: "bar", fetch: "baz")
          expect(config.fetch("foo")).to eq("bar")
          expect(config.fetch("fetch")).to eq("baz")
        end

        it "expands for notation_get" do
          config = create(foo: {bar: "baz", boo: '#{bar}'})
          expect(config.notation_get("foo.boo")).to eq("baz")
        end

      end

    end

  end
end
