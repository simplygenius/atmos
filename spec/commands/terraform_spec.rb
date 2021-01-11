require "simplygenius/atmos/commands/terraform"

module SimplyGenius
  module Atmos
    module Commands

      describe Terraform do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar\nprovider: none")
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "execute" do

          it "calls terraform passing through options and args" do
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).
                with(process_env: env).and_return(te)
            expect(te).to receive(:run).with('--help', 'foo', '--bar', get_modules: false)
            expect(cli).to receive(:auto_init)
            cli.run(['--help', 'foo', '--bar'])
          end

          it "fails with non-zero code if terraform fails" do
            expect { described_class.new("").run(['badcmd']) }.to output.to_stdout.
                and raise_error(SystemExit)
          end

        end

        describe "shared_plugin_dir" do

          it "sets up plugin cache if enabled" do
            within_construct do |c|
              Atmos.config = Config.new("ops")
              env = {}
              cli.enable_shared_plugins(env)
              expect(env).to include("TF_PLUGIN_CACHE_DIR")
            end
          end

          it "doesn't setup plugin cacheif disabled" do
            within_construct do |c|
              c.file('config/atmos.yml', YAML.dump("atmos" => {"terraform" => {"disable_shared_plugins" => true}}))
              Atmos.config = Config.new("ops")
              env = {}
              cli.enable_shared_plugins(env)
              expect(env).to_not include("TF_PLUGIN_CACHE_DIR")
            end
          end

        end

        describe "auto_init" do

          it "runs init if enabled" do
            Atmos.config = Config.new("ops")
            Atmos.config["atmos.terraform.auto_init"] = true
            cli.auto_init = true
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).twice.and_return(te)
            expect(te).to receive(:run).with('init', get_modules: false)
            expect(te).to receive(:run).with('--help', 'foo', '--bar', get_modules: false)
            expect(cli).to receive(:enable_shared_plugins)
            cli.run(['--help', 'foo', '--bar'])
          end

          it "doesn't run init if already initialized" do
            Atmos.config = Config.new("ops")
            Atmos.config["atmos.terraform.auto_init"] = true
            cli.auto_init = true
            env = Hash.new
            FileUtils.mkdir_p(File.join(Atmos.config.tf_working_dir, 'recipes', '.terraform'))
            FileUtils.touch(File.join(Atmos.config.tf_working_dir, 'recipes', '.terraform', 'terraform.tfstate'))
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).and_return(te)
            expect(te).to receive(:run).with('init', get_modules: false).never
            expect(te).to receive(:run).with('--help', 'foo', '--bar', get_modules: false)
            expect(cli).to receive(:enable_shared_plugins)
            cli.run(['--help', 'foo', '--bar'])
          end

          it "doesn't run init if disabled globally" do
            Atmos.config = Config.new("ops")
            Atmos.config["atmos.terraform.auto_init"] = false
            cli.auto_init = true
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).and_return(te)
            expect(te).to receive(:run).with('init', get_modules: false).never
            expect(te).to receive(:run).with('--help', 'foo', '--bar', get_modules: false)
            expect(cli).to receive(:enable_shared_plugins)
            cli.run(['--help', 'foo', '--bar'])
          end

          it "doesn't run init if disabled by subclass" do
            Atmos.config = Config.new("ops")
            Atmos.config["atmos.terraform.auto_init"] = true
            cli.auto_init = false
            env = Hash.new
            te = TerraformExecutor.new(env)
            expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
            expect(TerraformExecutor).to receive(:new).and_return(te)
            expect(te).to receive(:run).with('init', get_modules: false).never
            expect(te).to receive(:run).with('--help', 'foo', '--bar', get_modules: false)
            expect(cli).to receive(:enable_shared_plugins)
            cli.run(['--help', 'foo', '--bar'])
          end

        end

      end

    end
  end
end
