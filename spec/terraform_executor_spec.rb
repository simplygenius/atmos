require 'simplygenius/atmos/terraform_executor'

module SimplyGenius
  module Atmos

    describe TerraformExecutor do
      let(:te) { described_class.new(process_env: Hash.new) }
      let(:okstatus) { double(Process::Status, exitstatus: 0) }
      let(:failstatus) { double(Process::Status, exitstatus: 1) }

      after :all do
        Atmos.config = nil
      end

      describe "pipe_stream" do

        around :each do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump({}))
            Atmos.config = Config.new("ops")
            ex.run
          end
        end

        it "pipes data between streams" do
          r, w = IO.pipe
          dest = StringIO.new

          t = te.send(:pipe_stream, r, dest)
          w.puts("foo")
          w.puts("bar")
          w.close
          t.join
          expect(dest.string).to eq("foo\nbar\n")
        end

        it "handles data without newline" do
          r, w = IO.pipe
          dest = StringIO.new

          t = te.send(:pipe_stream, r, dest)
          w.write("foo")
          sleep 0.1
          expect(dest.string).to eq("foo")

          w.close
          t.join
          expect(dest.string).to eq("foo")
        end

        it "can markup data with a block" do
          r, w = IO.pipe
          dest = StringIO.new

          t = te.send(:pipe_stream, r, dest) do |data, flushing: false|
            flushing ? data : "1#{data}2"
          end
          w.write("foo")
          w.close
          t.join
          expect(dest.string).to eq("1foo2")
        end

      end

      describe "link_recipes" do

        it "links recipes into working dir" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'default' => ['foo', 'bar']}))
            c.file('recipes/foo.tf')
            c.file('recipes/bar.tf')
            c.file('recipes/baz.tf')
            Atmos.config = Config.new("ops")
            te.send(:link_recipes)
            ['foo', 'bar'].each do |f|
              link = File.join(Atmos.config.tf_working_dir, 'recipes', "#{f}.tf")
              expect(File.exist?(link)).to be true
              expect(File.symlink?(link)).to be true
              expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "recipes/#{f}.tf"))
            end
            expect(File.exist?(File.join(Atmos.config.tf_working_dir, 'recipes', "baz.tf"))).to be false

          end

        end

        it "links working group recipes into working group dir" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'recipes' => {'bootstrap' => ['foo', 'bar'], 'default' => ['hum']}))
            c.file('recipes/foo.tf')
            c.file('recipes/bar.tf')
            c.file('recipes/baz.tf')
            c.file('recipes/hum.tf')
            Atmos.config = Config.new("ops", 'bootstrap')
            te = described_class.new(process_env: Hash.new)
            expect(te.send(:tf_recipes_dir)).to match(/\/bootstrap\/recipes$/)
            te.send(:link_recipes)
            ['foo', 'bar'].each do |f|
              link = File.join(te.send(:tf_recipes_dir), "#{f}.tf")
              expect(File.exist?(link)).to be true
              expect(File.symlink?(link)).to be true
              expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "recipes/#{f}.tf"))
            end
            expect(File.exist?(File.join(te.send(:tf_recipes_dir), "baz.tf"))).to be false
            expect(File.exist?(File.join(te.send(:tf_recipes_dir), "hum.tf"))).to be false
          end
        end

        it "links selected recipe files into working dir" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'default' => ['baz.hcl']}))
            c.file('recipes/baz.hcl')
            Atmos.config = Config.new("ops")
            te.send(:link_recipes)
            link = File.join(Atmos.config.tf_working_dir, 'recipes', 'baz.hcl')
            expect(File.exist?(link)).to be true
            expect(File.symlink?(link)).to be true
            expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "recipes/baz.hcl"))
          end

        end

        it "only links each recipe a single time with preference to the short form" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'default' => ['baz', 'baz.tf']}))
            c.file('recipes/baz.tf')
            c.file('recipes/baz.tf.tf')
            Atmos.config = Config.new("ops")
            te.send(:link_recipes)
            link = File.join(Atmos.config.tf_working_dir, 'recipes', 'baz.tf')
            expect(File.exist?(link)).to be true
            expect(File.symlink?(link)).to be true
            expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "recipes/baz.tf"))
            link = File.join(Atmos.config.tf_working_dir, 'recipes', 'baz.tf.tf')
            expect(File.exist?(link)).to be true
            expect(File.symlink?(link)).to be true
            expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "recipes/baz.tf.tf"))
            expect(Dir["#{Atmos.config.tf_working_dir}/recipes/*"].size).to eq(2)
          end
        end

        it "reports an error if no target for recipe" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'default' => ['foo']}))
            Atmos.config = Config.new("ops")
            te.send(:link_recipes)
            expect(Dir["#{Atmos.config.tf_working_dir}/recipes/*"].size).to eq(0)
            expect(Logging.contents).to match(/Recipe 'foo' is not present/)
          end
        end

      end

      describe "link_support_dirs" do

        it "links dirs into working dir" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            c.directory('modules')
            c.directory('templates')
            c.file('recipes/foo.tf')

            Atmos.config = Config.new("ops")
            te.send(:link_support_dirs)
            ['modules', 'templates'].each do |f|
              link = File.join(Atmos.config.tf_working_dir, "#{f}")
              expect(File.symlink?(link)).to be true
              expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "#{f}"))
            end
          end

        end

        it "links dirs into working group dir" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            c.directory('modules')
            c.directory('templates')
            c.file('recipes/foo.tf')

            Atmos.config = Config.new("ops", 'bootstrap')
            te = described_class.new(process_env: Hash.new)
            expect(te.send(:tf_recipes_dir)).to match(/\/bootstrap\/recipes$/)
            te.send(:link_support_dirs)
            ['modules', 'templates'].each do |f|
              link = File.join(Atmos.config.tf_working_dir, "#{f}")
              expect(File.symlink?(link)).to be true
              expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "#{f}"))
            end
          end

        end

        it "links nested dirs into working dir" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            c.file('recipes/foo.json')

            Atmos.config = Config.new("ops")
            Atmos.config["atmos.terraform.working_dir_links"] = ["recipes/foo.json"]
            te.send(:link_support_dirs)
            link = File.join(Atmos.config.tf_working_dir, "recipes", "foo.json")
            expect(File.symlink?(link)).to be true
            expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "recipes", "foo.json"))
          end
        end

      end

      describe "clean_links" do

        it "removes atmos working dir links" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'default' => ['foo']}))
            c.directory('modules')
            c.directory('templates')
            c.file('recipes/foo.tf')
            Atmos.config = Config.new("ops")

            te.send(:link_support_dirs)
            te.send(:link_recipes)

            # simulate a terraform module link
            module_src = 'modules/mymod'
            module_link = File.join(te.send(:tf_recipes_dir), '.terraform', 'modules', 'deadbeef')
            FileUtils.mkdir_p(File.dirname(module_link))
            c.directory(module_src)
            File.symlink("#{c.to_s}/#{module_src}", module_link)

            # simulate a terraform provider link
            provider_src = 'dummy'
            provider_link = File.join(te.send(:tf_recipes_dir), ".terraform/providers/registry.terraform.io/hashicorp/aws/3.23.0/darwin_amd64")
            FileUtils.mkdir_p(File.dirname(provider_link))
            c.directory(provider_src)
            File.symlink("#{c.to_s}/#{provider_src}", provider_link)

            count = 0
            Find.find(Atmos.config.tf_working_dir) {|f|  count += 1 if File.symlink?(f) }
            expect(count).to eq(5)

            te.send(:clean_links)
            count = 0
            Find.find(Atmos.config.tf_working_dir) {|f|  count += 1 if File.symlink?(f) }
            expect(count).to eq(2)
            expect(File.exist?(module_link)).to be true
            expect(File.symlink?(module_link)).to be true
            expect(File.exist?(provider_link)).to be true
            expect(File.symlink?(provider_link)).to be true
          end

        end

        it "removes atmos working group dir links" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'bootstrap' => ['foo']}))
            c.directory('modules')
            c.directory('templates')
            c.file('recipes/foo.tf')
            Atmos.config = Config.new("ops", "bootstrap")
            te = described_class.new(process_env: Hash.new)
            expect(te.send(:tf_recipes_dir)).to match(/\/bootstrap\/recipes$/)

            te.send(:link_support_dirs)
            te.send(:link_recipes)

            count = 0
            Find.find(Atmos.config.tf_working_dir) {|f|  count += 1 if File.symlink?(f) }
            expect(count).to eq(3)

            te.send(:clean_links)
            count = 0
            Find.find(Atmos.config.tf_working_dir) {|f|  count += 1 if File.symlink?(f) }
            expect(count).to eq(0)
          end

        end

      end

      describe "secrets_env" do

        it "passes secrets as env vars" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('providers' => {'aws' => {'secret' => {}}}))
            Atmos.config = Config.new("ops")
            expect(Atmos.config.provider.secret_manager).to receive(:to_h).
                and_return({"s1" => "a1", "s2" => "a2"})

            env = te.send(:secrets_env)
            expect(env).to eq({"TF_VAR_s1" => "a1", "TF_VAR_s2" => "a2"})
          end

        end

      end

      describe "encode_tf_env_value" do

        around :each do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump({}))
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = Config.new("ops")
          end
        end

        it "handles scalars" do
          expect(Atmos.config['atmos.terraform.compat11']).to be_falsey
          expect(te.send(:encode_tf_env_value, "foo")).to eq("foo")
          expect(te.send(:encode_tf_env_value, 1)).to eq("1")
          expect(te.send(:encode_tf_env_value, true)).to eq("true")
          expect(te.send(:encode_tf_env_value, false)).to eq("false")
          expect(te.send(:encode_tf_env_value, nil)).to eq("null")
        end

        it "handles scalars in compat mode" do
          Atmos.config['atmos.terraform.compat11'] = true
          expect(Atmos.config['atmos.terraform.compat11']).to be_truthy
          expect(te.send(:encode_tf_env_value, "foo")).to eq("foo")
          expect(te.send(:encode_tf_env_value, 1)).to eq("1")
          expect(te.send(:encode_tf_env_value, true)).to eq("true")
          expect(te.send(:encode_tf_env_value, false)).to eq("false")
          expect(te.send(:encode_tf_env_value, nil)).to eq("")
        end

        it "encodes map as json" do
          expect(Atmos.config['atmos.terraform.compat11']).to be_falsey
          expect(te.send(:encode_tf_env_value, {"foo" => "bar"})).to eq('{"foo":"bar"}')
        end

        it "encodes map as tfvar map in compat mode" do
          Atmos.config['atmos.terraform.compat11'] = true
          expect(Atmos.config['atmos.terraform.compat11']).to be_truthy
          expect(te.send(:encode_tf_env_value, {"foo" => "bar"})).to eq('{"foo"="bar"}')
        end

        it "encodes list as json" do
          expect(te.send(:encode_tf_env_value, ["foo", "bar"])).to eq('["foo","bar"]')
        end

      end

      describe "encode_tf_env" do

        around :each do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump({}))
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = Config.new("ops")
          end
        end

        it "converts a map to a TF_VAR env map" do
          expect(te.send(:encode_tf_env, {"foo" => "bar"})).to eq({"TF_VAR_foo" => "bar"})
        end

      end

      describe "atmos_env" do

        it "generates env for atmos vars" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'string' => 'str',
                'booltrue' => true,
                'boolfalse' => false,
                'numint' => 1,
                'numfloat' => 2.1,
                'map' => {'foo' => 'bar'},
                'list' => ['one', 'two'],
                'environments' => {
                    'ops' => {
                        'account_id' => 123
                    }
                }
            ))
            Atmos.config = Config.new("ops")
            vars = te.send(:atmos_env)
            atmos_config = JSON.parse(vars['TF_VAR_atmos_config'])
            expect(vars['TF_VAR_string']).to eq('str')
            expect(atmos_config['string']).to eq(vars['TF_VAR_string'])
            expect(vars['TF_VAR_booltrue']).to eq('true')
            expect(atmos_config['booltrue'].to_s).to eq(vars['TF_VAR_booltrue'])
            expect(vars['TF_VAR_boolfalse']).to eq('false')
            expect(atmos_config['boolfalse'].to_s).to eq(vars['TF_VAR_boolfalse'])
            expect(vars['TF_VAR_numint']).to eq('1')
            expect(atmos_config['numint'].to_s).to eq(vars['TF_VAR_numint'])
            expect(vars['TF_VAR_numfloat']).to eq('2.1')
            expect(atmos_config['numfloat'].to_s).to eq(vars['TF_VAR_numfloat'])
            expect(vars['TF_VAR_map']).to eq('{"foo":"bar"}')
            expect(atmos_config['map_foo']).to eq('bar')
            expect(vars['TF_VAR_list']).to eq('["one","two"]')

            expect(vars['TF_VAR_atmos_env']).to eq('ops')
            expect(vars['TF_VAR_all_env_names']).to eq('["ops"]')
            expect(vars['TF_VAR_account_ids']).to eq('{"ops":123}')
            expect(vars['TF_VAR_atmos_working_group']).to eq("default")
          end
        end

        it "writes a env file for atmos vars" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'foo' => 'bar',
                'environments' => {
                    'ops' => {
                        'account_id' => 123
                    }
                }
            ))
            Atmos.config = Config.new("ops")
            te.send(:atmos_env)

            file = File.join(te.send(:tf_recipes_dir), 'atmos-tfvars.env')
            expect(File.exist?(file)).to be true
            expect(File.read(file).lines).to include("TF_VAR_foo='bar'\n")
          end
        end

        it "homogenizes global vars for compat mode" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'map' => {'submap' => {'foo' => 'bar'}},
                ))
            Atmos.config = Config.new("ops")
            Atmos.config['atmos.terraform.compat11'] = true
            vars = te.send(:atmos_env)
            expect(vars['TF_VAR_map']).to eq('{"submap_foo"="bar"}')
          end
        end

        it "doesn't homogenize global vars for non-compat mode" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'map' => {'submap' => {'foo' => 'bar'}},
                ))
            Atmos.config = Config.new("ops")
            Atmos.config['atmos.terraform.compat11'] = false
            vars = te.send(:atmos_env)
            expect(vars['TF_VAR_map']).to eq('{"submap":{"foo":"bar"}}')
          end
        end


      end

      describe "homogenize_encode" do

        around :each do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump({}))
            Atmos.config = Config.new("ops")
            ex.run
          end
        end

        it "handles scalars" do
          expect(Atmos.config['atmos.terraform.compat11']).to be_falsey
          expect(te.send(:homogenize_encode, "foo")).to eq("foo")
          expect(te.send(:homogenize_encode, 1)).to eq(1)
          expect(te.send(:homogenize_encode, true)).to eq(true)
          expect(te.send(:homogenize_encode, false)).to eq(false)
          expect(te.send(:homogenize_encode, nil)).to eq(nil)
        end

        it "handles scalars in compat mode" do
          Atmos.config['atmos.terraform.compat11'] = true
          expect(Atmos.config['atmos.terraform.compat11']).to be_truthy
          expect(te.send(:homogenize_encode, "foo")).to eq("foo")
          expect(te.send(:homogenize_encode, 1)).to eq(1)
          expect(te.send(:homogenize_encode, true)).to eq(true)
          expect(te.send(:homogenize_encode, false)).to eq(false)
          expect(te.send(:homogenize_encode, nil)).to eq("")
        end

      end

      describe "homogenize_for_terraform" do

        around :each do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump({}))
            Atmos.config = Config.new("ops")
            ex.run
          end
        end

        it "handles empty maps" do
          expect(te.send(:homogenize_for_terraform, {})).to eq({})
        end

        it "handles empty lists" do
          expect(te.send(:homogenize_for_terraform, [])).to eq("")
        end

        it "handles scalars" do
          expect(te.send(:homogenize_for_terraform, "foo")).to eq("foo")
          expect(te.send(:homogenize_for_terraform, 1)).to eq(1)
          expect(te.send(:homogenize_for_terraform, true)).to eq(true)
          expect(te.send(:homogenize_for_terraform, false)).to eq(false)
          expect(te.send(:homogenize_for_terraform, nil)).to eq(nil)
        end

        it "handles basic maps" do
          expect(te.send(:homogenize_for_terraform, {"k1" => 1})).to eq({"k1" => 1})
        end

        it "handles basic arrays" do
          expect(te.send(:homogenize_for_terraform, [1,2])).to eq("1,2")
        end

        it "handles arrays in maps" do
          expect(te.send(:homogenize_for_terraform, {"k1" => [1,2]})).to eq({"k1" => "1,2"})
        end

        it "handles maps in arrays" do
          expect(te.send(:homogenize_for_terraform, [{"k1" => "v1", "k2" => "v2"}, {"k3" => "v3"}])).to eq("k1=v1;k2=v2,k3=v3")
        end

        it "flattens deep maps" do
          expect(te.send(:homogenize_for_terraform,
                         {"k0" => "v0", "k1" => {"k2" => 2, "k3" => 3, "k4" => {"k5" => 5, "k6" => [4, 5, 6]}}})).
              to eq({"k0" => "v0", "k1_k2" => 2, "k1_k3" => 3, "k1_k4_k5" => 5, "k1_k4_k6" => "4,5,6"})
        end

      end

      describe "setup_backend" do

        it "writes the terraform backend file" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'foo' => 'bar',
                'providers' => {
                    'aws' => {
                      'backend' => {
                          'type' => "mytype",
                          'foo' => 'bar',
                          'baz' => 'boo'
                      }
                    }
                }
            ))
            Atmos.config = Config.new("ops")
            te.send(:setup_backend)

            file = File.join(te.send(:tf_recipes_dir), 'atmos-backend.tf.json')
            expect(File.exist?(file)).to be true
            vars = JSON.parse(File.read(file))
            expect(vars['terraform']['backend']['mytype']).
                to match(hash_including('foo' => 'bar', 'baz' => 'boo'))
          end
        end

        it "skips the terraform backend" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")
            te.send(:setup_backend, true)

            file = File.join(Atmos.config.tf_working_dir, 'atmos-backend.tf.json')
            expect(File.exist?(file)).to be false
          end
        end

        it "deletes the terraform backend when skipping" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            file = File.join(te.send(:tf_recipes_dir), 'atmos-backend.tf.json')
            c.file(file)

            te.send(:setup_backend, true)

            expect(File.exist?(file)).to be false
          end
        end

        it "deletes the terraform backend when not skipping but no config" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            file = File.join(te.send(:tf_recipes_dir), 'atmos-backend.tf.json')
            c.file(file)

            te.send(:setup_backend)

            expect(File.exist?(file)).to be false
          end
        end

      end

      describe "setup_working_dir" do

        it "performs the setup steps" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to receive(:clean_links)
            expect(te).to receive(:link_support_dirs)
            expect(te).to receive(:link_recipes)
            expect(te).to receive(:setup_backend)

            te.send(:setup_working_dir)
          end
        end

      end

      describe "run" do

        it "performs the setup and execution steps" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to receive(:setup_working_dir)
            expect(te).to receive(:execute)

            te.send(:run)
          end
        end

        it "runs get before the command when desired" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to receive(:setup_working_dir)
            expect(te).to receive(:execute).with("get", output_io: instance_of(StringIO)).ordered
            expect(te).to receive(:execute).with(hash_including(output_io: nil)).ordered

            te.send(:run, get_modules: true)
          end
        end

      end

      describe "execute" do

        it "passes secrets via env terraform" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to receive(:secrets_env).and_return({'foo' => 'bar'})
            expect(te).to receive(:spawn).with(hash_including('foo' => 'bar'), any_args)
            expect(Process).to receive(:wait2).and_return([999, okstatus])

            te.send(:execute, "init", skip_secrets: false)
          end
        end

        it "skips secrets when desired" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to_not receive(:secrets_env)
            expect(te).to receive(:spawn)
            expect(Process).to receive(:wait2).and_return([999, okstatus])

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "runs terraform" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect { te.send(:execute, "init", skip_secrets: true) }.
                to output(/Terraform initialized in an empty directory/).to_stdout
          end
        end

        it "runs terraform with stderr" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect { te.send(:execute, "init", "1", "2", skip_secrets: true) rescue TerraformExecutor::ProcessFailed }.
                to output(/The init command expects at most one argument/).to_stderr
          end
        end

        it "runs terraform with output_io" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            io = StringIO.new
            expect { te.send(:execute, "init", "1", "2", skip_secrets: true, output_io: io) rescue TerraformExecutor::ProcessFailed }.
                to_not output(/The init command expects at most one argument/).to_stderr
            expect(io.string).to match(/The init command expects at most one argument/)
          end
        end

        it "runs terraform with stdin" do
          within_construct do |c|
            c.file('config/atmos.yml', "provider: none")
            Atmos.config = Config.new("ops")

            c.file(File.join(te.send(:tf_recipes_dir), 'stdin.tf.json'), JSON.dump(
                        'variable' => {
                            'needed' => {}
                        },
                        'output' => {
                            'showme' => {
                                'value' => 'got var ${var.needed}'
                            }
                        }
                    ))

            expect { te.send(:execute, "init", skip_secrets: true) }.
                to output(/Terraform has been successfully initialized/).to_stdout

            # We redirect terminal stdin to process using spawn (:in => :in), as
            # other methods weren't reliable.  As a result, we can't simply
            # simulate stdin with an IO, so call it as a new process.  Terraform
            # 0.13 also seems to no longer allow multiple newline separated
            # responses to be placed in stdin up front, so need to supply each
            # stdin answer only once terraform asks for it.  We could use
            # auto-approve to allow us to supply only one answer up front, but
            # its good to be able to test that a user can supply a "yes" via
            # stdin through atmos for plan/apply confirmations as well as for
            # missing vars
            #
            output = ""
            answers = ["foo", "yes"]

            pipe_atmos("apply") do |stdin, stdout_and_stderr|
              begin
                while data = stdout_and_stderr.readpartial(1024)
                  if data =~ /Enter a value:/
                    stdin.puts(answers.shift)
                  end
                  output += data
                end
              rescue IOError, EOFError => e
                #puts "ioerror in spec: #{e}"
              end
            end

            expect(output).to match(/showme = \"?got var foo\"?/)
          end
        end

        it "sets TMPDIR in env" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to receive(:spawn).
                with(hash_including('TMPDIR' => Atmos.config.tmp_dir), any_args)
            expect(Process).to receive(:wait2).and_return([999, okstatus])

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "passes current atmos location through process env" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to receive(:spawn).
                with(hash_including(
                         'ATMOS_ROOT' => Atmos.config.root_dir,
                         'ATMOS_CONFIG' => Atmos.config.config_file), any_args)
            expect(Process).to receive(:wait2).and_return([999, okstatus])

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "passes ipc env to terraform" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            expect(te).to receive(:spawn).
                with(hash_including('ATMOS_IPC_SOCK', 'ATMOS_IPC_CLIENT'), any_args)
            expect(Process).to receive(:wait2).and_return([999, okstatus])

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "allows disabling ipc" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")
            Atmos.config.send(:load)
            Atmos.config.instance_variable_get(:@config).notation_put('atmos.ipc.disable', true)

            expect(te).to receive(:spawn).
                with(hash_including('ATMOS_IPC_CLIENT' => ':'), any_args)
            expect(Process).to receive(:wait2).and_return([999, okstatus])

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "no-ops ipc with disabled ipc script" do
          disabled_script = ':'
          data = {'action' => 'ping', 'data' => 'foo'}
          input = JSON.generate(data)

          output, status = Open3.capture2(
              {'ATMOS_IPC_CLIENT' => disabled_script},
              "sh", "-c", %Q(printf '#{input}' | $ATMOS_IPC_CLIENT)
          )
          expect(status.success?).to be true
          expect(output).to eq("")

          output, status = Open3.capture2(
              {'ATMOS_IPC_CLIENT' => disabled_script},
              "sh", "-c", %Q($ATMOS_IPC_CLIENT '#{input}')
          )
          expect(status.success?).to be true
          expect(output).to eq("")

          output, status = Open3.capture2(
              {'ATMOS_IPC_CLIENT' => disabled_script},
              "sh", "-c", "$ATMOS_IPC_CLIENT",
              stdin_data: input
          )
          expect(status.success?).to be true
          expect(output).to eq("")
        end

      end

      describe "plugins" do

        it "provides stdout to output filter plugin" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            filter = Class.new do
              def self.data; @data ||= {output: ""}; end
              def initialize(c); self.class.data[:context] = c; end
              def filter(data, flushing: false); self.class.data[:filter_called] = true; self.class.data[:output] += data; ""; end
              def close; self.class.data[:close_called] = true; end
            end

            Atmos.config.plugin_manager.register_output_filter(:stdout, filter)

            te.send(:execute, "init", skip_secrets: true)
            expect(filter.data[:context]).to match(hash_including(:process_env, :working_group))
            expect(filter.data[:filter_called]).to eq(true)
            expect(filter.data[:close_called]).to eq(true)
            expect(filter.data[:output]).to match("Terraform initialized")
          end
        end


        it "provides stderr to output filter plugin" do
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")

            filter = Class.new do
              def self.data; @data ||= {output: ""}; end
              def initialize(c); self.class.data[:context] = c; end
              def filter(data, flushing: false); self.class.data[:filter_called] = true; self.class.data[:output] += data; ""; end
              def close; self.class.data[:close_called] = true; end
            end

            Atmos.config.plugin_manager.register_output_filter(:stderr, filter)

            te.send(:execute, "init", "1", "2", skip_secrets: true) rescue TerraformExecutor::ProcessFailed
            expect(filter.data[:context]).to match(hash_including(:process_env, :working_group))
            expect(filter.data[:filter_called]).to eq(true)
            expect(filter.data[:close_called]).to eq(true)
            expect(filter.data[:output]).to match("The init command expects at most one argument")
          end
        end

      end

    end

  end
end
