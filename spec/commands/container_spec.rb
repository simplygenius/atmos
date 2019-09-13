require "simplygenius/atmos/commands/container"

module SimplyGenius
  module Atmos
    module Commands

      describe Container do

        let(:cli) { described_class.new("") }

        around(:each) do |ex|
          within_construct do |c|
            c.file('config/atmos.yml', "foo: bar")
            Atmos.config = Config.new("ops")
            ex.run
            Atmos.config = nil
          end
        end

        describe "--help" do

          it "produces help text under standard width" do
            expect(cli.help).to be_line_width_for_cli
          end

        end

        describe "push" do

          it "produces help text under standard width" do
            expect(described_class.new("push").help).to be_line_width_for_cli
          end

          it "requires a cluster" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.container_manager).to_not receive(:push)
            expect { cli.run(["push", "bar"]) }.to raise_error(Clamp::UsageError, /'-c' is required/)
          end

          it "requires a name" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.container_manager).to_not receive(:push)
            expect { cli.run(["push", "-c", "foo"]) }.to raise_error(Clamp::UsageError, /NAME.*no value provided/)
          end

          it "pushing an image" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz")
            cli.run(["push", "-c", "foo", "bar"])
          end

          it "uses role when pushing an image" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: "myrole").and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz")
            cli.run(["push", "-r", "myrole", "-c", "foo", "bar"])
          end

          it "uses image when pushing an image" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "myimage", revision: nil).and_return(remote_image: "baz")
            cli.run(["push", "-i", "myimage", "-c", "foo", "bar"])
          end

          it "uses revision when pushing an image" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "bar", revision: 'v123').and_return(remote_image: "baz")
            cli.run(["push", "-v", "v123", "-c", "foo", "bar"])
          end

        end

        describe "activate" do

          it "produces help text under standard width" do
            expect(described_class.new("activate").help).to be_line_width_for_cli
          end

          it "requires a cluster" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect { cli.run(["activate", "bar"]) }.to raise_error(Clamp::UsageError, /'-c' is required/)
          end

          it "requires a name" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect { cli.run(["activate", "-c", "foo"]) }.to raise_error(Clamp::UsageError, /NAME.*no value provided/)
          end

          it "lists service revisions" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:list_image_tags).with("foo", "bar").and_return({tags: ["one"], latest: "one", current: "one"})
            expect(Atmos.config.provider.container_manager).
                to_not receive(:remote_image)
            expect(Atmos.config.provider.container_manager).
                to_not receive(:deploy)
            cli.run(["activate", "-c", "foo", "-l", "bar"])
            expect(Logging.contents).to  match(/Recent revisions/)
            expect(Logging.contents).to  match(/^\tone$/)
            expect(Logging.contents).to  match(/Currently active revision is: one/)
            expect(Logging.contents).to  match(/The revision associated with the `latest` tag is: one/)
          end

          it "uses tagcount to lists service revisions" do
            env = Hash.new
            taglist = Array.new(5) { |i| "tag#{i}" }
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:list_image_tags).with("foo", "bar").and_return({tags: taglist, latest: "one", current: "one"})
            expect(Atmos.config.provider.container_manager).
                to_not receive(:remote_image)
            expect(Atmos.config.provider.container_manager).
                to_not receive(:deploy)
            cli.run(["activate", "-c", "foo", "-l", "-t", "3", "bar"])
            # '-t 3' gets the last 3 only
            expect(Logging.contents).to  match(/Recent revisions/)
            expect(Logging.contents).to  match(/^\ttag2/)
            expect(Logging.contents).to  match(/^\ttag3/)
            expect(Logging.contents).to  match(/^\ttag4/)
            expect(Logging.contents).to_not  match(/^\ttag0/)
            expect(Logging.contents).to_not  match(/^\ttag1/)
          end

          it "activates a service" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:remote_image).with("bar", "xyz").and_return("bar/xyz")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "bar/xyz").and_return({})
            cli.run(["activate", "-c", "foo", "-v", "xyz", "bar"])
          end

          it "activates multiple services with the first's image" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:remote_image).with("bar", "xyz").and_return("bar/xyz")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "bar/xyz").and_return({})
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bum", "bar/xyz").and_return({})
            cli.run(["activate", "-c", "foo", "-v", "xyz", "bar", "bum"])
          end

          it "uses role when activating a service" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: "myrole").and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:remote_image).with("bar", "xyz").and_return("bar/xyz")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "bar/xyz").and_return({})
            cli.run(["activate", "-r", "myrole", "-c", "foo", "-v", "xyz", "bar"])
          end

          it "prompts with revision picker if none supplied" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:list_image_tags).with("foo", "bar").and_return({tags: ["one", "two"], latest: "one", current: "one"})
            expect(Atmos.config.provider.container_manager).
                to receive(:remote_image).with("bar", "two").and_return("bar/two")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "bar/two").and_return({})


            expect do
              simulate_stdin("two") do
                cli.run(["activate", "-c", "foo", "bar"])
              end
            end.to output(/Which revision would you like to activate/).to_stdout

          end

        end

        describe "deploy" do

          it "produces help text under standard width" do
            expect(described_class.new("deploy").help).to be_line_width_for_cli
          end

          it "requires a cluster" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.container_manager).to_not receive(:push)
            expect { cli.run(["deploy", "bar"]) }.to raise_error(Clamp::UsageError, /'-c' is required/)
          end

          it "requires a name" do
            expect(Atmos.config.provider.auth_manager).to_not receive(:authenticate)
            expect(Atmos.config.provider.container_manager).to_not receive(:push)
            expect { cli.run(["deploy", "-c", "foo"]) }.to raise_error(Clamp::UsageError, /NAME.*no value provided/)
          end

          it "deploys a service" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "baz").and_return({})
            cli.run(["deploy", "-c", "foo", "bar"])
          end

          it "deploys multiple services with the first's image" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz").once
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "baz").and_return({})
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bum", "baz").and_return({})
            cli.run(["deploy", "-c", "foo", "bar", "bum"])
          end

          it "uses role when deploying a service" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: "myrole").and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "bar", revision: nil).and_return(remote_image: "baz")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "baz").and_return({})
            cli.run(["deploy", "-r", "myrole", "-c", "foo", "bar"])
          end

          it "uses image when deploying a service" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "myimage", revision: nil).and_return(remote_image: "baz")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "baz").and_return({})
            cli.run(["deploy", "-i", "myimage", "-c", "foo", "bar"])
          end

          it "uses revision when deploying a service" do
            env = Hash.new
            expect(Atmos.config.provider.auth_manager).
                to receive(:authenticate).with(ENV, role: nil).and_yield(env)
            expect(Atmos.config.provider.container_manager).
                to receive(:push).with("bar", "bar", revision: 'v123').and_return(remote_image: "baz")
            expect(Atmos.config.provider.container_manager).
                to receive(:deploy).with("foo", "bar", "baz").and_return({})
            cli.run(["deploy", "-v", "v123", "-c", "foo", "bar"])
          end

        end

      end

    end
  end
end
