require 'simplygenius/atmos/terraform_executor'

module SimplyGenius
  module Atmos

    describe TerraformExecutor do
      let(:te) { described_class.new(process_env: Hash.new) }

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

          t = te.send(:pipe_stream, r, dest) do |data|
            "1#{data}2"
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
            Atmos.config = Config.new("ops")
            te = described_class.new(process_env: Hash.new, working_group: "bootstrap")
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

      end

      describe "link_support_dirs" do

        it "links dirs into working dir" do
          within_construct do |c|
            c.file('config/atmos.yml')
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
            c.file('config/atmos.yml')
            c.directory('modules')
            c.directory('templates')
            c.file('recipes/foo.tf')

            Atmos.config = Config.new("ops")
            te = described_class.new(process_env: Hash.new, working_group: "bootstrap")
            expect(te.send(:tf_recipes_dir)).to match(/\/bootstrap\/recipes$/)
            te.send(:link_support_dirs)
            ['modules', 'templates'].each do |f|
              link = File.join(Atmos.config.tf_working_dir("bootstrap"), "#{f}")
              expect(File.symlink?(link)).to be true
              expect(File.readlink(link)).to eq(File.join(Atmos.config.root_dir, "#{f}"))
            end
          end

        end

      end

      describe "link_shared_plugin_dir" do

        it "links a shared plugin dir into terraform cwd" do
          within_construct do |c|
            c.file('config/atmos.yml')

            Atmos.config = Config.new("ops")
            te.send(:link_shared_plugin_dir)

            dest = File.join(Atmos.config.tmp_root, "terraform_plugins")
            expect(File.exist?(dest)).to be true
            link = File.join(te.send(:tf_recipes_dir), '.terraform', 'plugins')
            expect(File.symlink?(link)).to be true
            expect(File.readlink(link)).to eq(dest)
          end
        end

        it "doesn't link if config disabled" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump("terraform" => {"disable_shared_plugins" => true}))

            Atmos.config = Config.new("ops")
            te.send(:link_shared_plugin_dir)

            dest = File.join(Atmos.config.tmp_root, "terraform_plugins")
            expect(File.exist?(dest)).to be false
            link = File.join(te.send(:tf_recipes_dir), '.terraform', 'plugins')
            expect(File.symlink?(link)).to be false
          end
        end

      end

      describe "clean_links" do

        it "removes atmos working dir links" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'default' => ['foo']}))
            c.directory('modules')
            c.directory('templates')
            Atmos.config = Config.new("ops")

            te.send(:link_support_dirs)
            te.send(:link_recipes)

            # simulate a terraform module link
            module_src = 'modules/mymod'
            module_link = File.join(te.send(:tf_recipes_dir), '.terraform', 'modules', 'deadbeef')
            FileUtils.mkdir_p(File.dirname(module_link))
            c.directory(module_src)
            File.symlink("#{c.to_s}/#{module_src}", module_link)

            count = 0
            Find.find(Atmos.config.tf_working_dir) {|f|  count += 1 if File.symlink?(f) }
            expect(count).to eq(4)

            te.send(:clean_links)
            count = 0
            Find.find(Atmos.config.tf_working_dir) {|f|  count += 1 if File.symlink?(f) }
            expect(count).to eq(1)
            expect(File.exist?(module_link)).to be true
            expect(File.symlink?(module_link)).to be true
          end

        end

        it "removes atmos working group dir links" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump('recipes' => {'bootstrap' => ['foo']}))
            c.directory('modules')
            c.directory('templates')
            Atmos.config = Config.new("ops")
            te = described_class.new(process_env: Hash.new, working_group: "bootstrap")
            expect(te.send(:tf_recipes_dir)).to match(/\/bootstrap\/recipes$/)

            te.send(:link_support_dirs)
            te.send(:link_recipes)

            count = 0
            Find.find(Atmos.config.tf_working_dir("bootstrap")) {|f|  count += 1 if File.symlink?(f) }
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

      describe "write_atmos_vars" do

        it "writes the terraform var file for atmos vars" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'foo' => 'bar',
                'baz' => {'boo' => 'bum'},
                'environments' => {
                    'ops' => {
                        'account_id' => 123
                    }
                }
            ))
            Atmos.config = Config.new("ops")
            te.send(:write_atmos_vars)

            file = File.join(te.send(:tf_recipes_dir), 'atmos.auto.tfvars.json')
            expect(File.exist?(file)).to be true
            vars = JSON.parse(File.read(file))
            expect(vars['atmos_env']).to eq('ops')
            expect(vars['all_env_names']).to eq(["ops"])
            expect(vars['account_ids']).to eq("ops" => 123)
            expect(vars['atmos_config']['foo']).to eq('bar')
            expect(vars['atmos_config']['baz_boo']).to eq('bum')
            expect(vars['foo']).to eq('bar')
            expect(vars['baz']).to eq({'boo' => 'bum'})
          end
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

        it "changes backend key to reflect working group" do
          within_construct do |c|
            c.file('config/atmos.yml', YAML.dump(
                'foo' => 'bar',
                'providers' => {
                    'aws' => {
                      'backend' => {
                          'type' => "mytype",
                          'key' => 'foo'
                      }
                    }
                }
            ))
            Atmos.config = Config.new("ops")
            te = described_class.new(process_env: Hash.new, working_group: "bootstrap")
            te.send(:setup_backend)

            file = File.join(te.send(:tf_recipes_dir), 'atmos-backend.tf.json')
            expect(File.exist?(file)).to be true
            vars = JSON.parse(File.read(file))
            expect(vars['terraform']['backend']['mytype']).
                to eq('key' => 'bootstrap-foo')
          end
        end

        it "skips the terraform backend" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")
            te.send(:setup_backend, true)

            file = File.join(Atmos.config.tf_working_dir, 'atmos-backend.tf.json')
            expect(File.exist?(file)).to be false
          end
        end

        it "deletes the terraform backend when skipping" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            file = File.join(te.send(:tf_recipes_dir), 'atmos-backend.tf.json')
            c.file(file)

            te.send(:setup_backend, true)

            expect(File.exist?(file)).to be false
          end
        end

        it "deletes the terraform backend when not skipping but no config" do
          within_construct do |c|
            c.file('config/atmos.yml')
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
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect(te).to receive(:clean_links)
            expect(te).to receive(:link_support_dirs)
            expect(te).to receive(:link_recipes)
            expect(te).to receive(:write_atmos_vars)
            expect(te).to receive(:setup_backend)

            te.send(:setup_working_dir)
          end
        end

      end

      describe "run" do

        it "performs the setup and execution steps" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect(te).to receive(:setup_working_dir)
            expect(te).to receive(:execute)

            te.send(:run)
          end
        end

        it "runs get before the command when desired" do
          within_construct do |c|
            c.file('config/atmos.yml')
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
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect(te).to receive(:secrets_env).and_return({'foo' => 'bar'})
            expect(te).to receive(:spawn).with(hash_including('foo' => 'bar'), any_args)
            expect(Process).to receive(:wait)
            expect($?).to receive(:exitstatus).and_return 0

            te.send(:execute, "init", skip_secrets: false)
          end
        end

        it "skips secrets when desired" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect(te).to_not receive(:secrets_env)
            expect(te).to receive(:spawn)
            expect(Process).to receive(:wait)
            expect($?).to receive(:exitstatus).and_return 0

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "runs terraform" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect { te.send(:execute, "init", skip_secrets: true) }.
                to output(/Terraform initialized in an empty directory/).to_stdout
          end
        end

        it "runs terraform with stderr" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect { te.send(:execute, "init", "1", "2", skip_secrets: true) rescue TerraformExecutor::ProcessFailed }.
                to output(/The init command expects at most one argument/).to_stderr
          end
        end

        it "runs terraform with output_io" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            io = StringIO.new
            expect { te.send(:execute, "init", "1", "2", skip_secrets: true, output_io: io) rescue TerraformExecutor::ProcessFailed }.
                to_not output(/The init command expects at most one argument/).to_stderr
            expect(io.string).to match(/The init command expects at most one argument/)
          end
        end

        it "runs terraform with stdin" do
          within_construct do |c|
            c.file('config/atmos.yml')
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
            # other methods weren't reliable.  As a resut, we can't simply simulate
            # stdin with an IO, so hack it this way
            c.file(File.join(te.send(:tf_recipes_dir), "stdin.txt"), "foo\nyes\n")
            allow(te).to receive(:tf_cmd).and_return(["bash", "-c", "cat stdin.txt | terraform apply"])
            expect {
                te.send(:execute, "apply", skip_secrets: true)
            }.to output(/showme = got var foo/).to_stdout
          end
        end

        it "sets TMPDIR in env" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect(te).to receive(:spawn).
                with(hash_including('TMPDIR' => Atmos.config.tmp_dir), any_args)
            expect(Process).to receive(:wait)
            expect($?).to receive(:exitstatus).and_return 0

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "passes ipc env to terraform" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            expect(te).to receive(:spawn).
                with(hash_including('ATMOS_IPC_SOCK', 'ATMOS_IPC_CLIENT'), any_args)
            expect(Process).to receive(:wait)
            expect($?).to receive(:exitstatus).and_return 0

            te.send(:execute, "init", skip_secrets: true)
          end
        end

        it "allows disabling ipc" do
          within_construct do |c|
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")
            Atmos.config.send(:load)
            Atmos.config.instance_variable_get(:@config).notation_put('ipc.disable', true)

            expect(te).to receive(:spawn).
                with(hash_including('ATMOS_IPC_CLIENT' => ':'), any_args)
            expect(Process).to receive(:wait)
            expect($?).to receive(:exitstatus).and_return 0

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
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            filter = Class.new do
              def self.data; @data ||= {output: ""}; end
              def initialize(c); self.class.data[:context] = c; end
              def filter(data); self.class.data[:filter_called] = true; self.class.data[:output] += data; ""; end
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
            c.file('config/atmos.yml')
            Atmos.config = Config.new("ops")

            filter = Class.new do
              def self.data; @data ||= {output: ""}; end
              def initialize(c); self.class.data[:context] = c; end
              def filter(data); self.class.data[:filter_called] = true; self.class.data[:output] += data; ""; end
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
