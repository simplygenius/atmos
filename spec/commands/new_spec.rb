require "simplygenius/atmos/commands/new"

module SimplyGenius
  module Atmos
    module Commands

      describe New do

        before(:each) do
          SourcePath.clear_registry
        end

        let(:cli) { described_class.new("") }

        describe "--help" do

          it "produces help text under standard width" do
            expect(cli.help).to be_line_width_for_cli
          end

        end

        describe "execute" do

          it "generates the new template" do
            within_construct do |d|
              Atmos.config = Config.new("ops")
              expect { cli.run(["--quiet"]) }.to_not raise_error
              expect(File.exist?('config/atmos.yml'))
            end
          end

        end

      end

    end
  end
end
