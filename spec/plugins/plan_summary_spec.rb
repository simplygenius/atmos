require "simplygenius/atmos/plugins/plan_summary"

module SimplyGenius
  module Atmos
    module Plugins

      describe PlanSummary do

        let(:plugin) { described_class.new({}) }

        it 'should pass through data in filter' do
          expect(plugin.filter("foo\n")).to eq("foo\n")
        end

        it 'should detect a plan and save subsequent output' do
          plugin.filter("stuff\n")
          plugin.filter("before\nTerraform will perform the following actions:\nblah\n")
          plugin.filter("foo\n")
          plugin.filter("bar\n")
          expect(plugin.instance_variable_get(:@plan_detected)).to eq(true)
          expect(plugin.instance_variable_get(:@summary_data)).to eq("blah\nfoo\nbar\n")
        end

        it 'should display summary lines when Plan completed' do
          output  = ""
          output << plugin.filter("Terraform will perform the following actions:\n")
          output << plugin.filter("+ one\n")
          output << plugin.filter("- two\n")
          output << plugin.filter("~ three\n")
          output << plugin.filter("-/+ four\n")
          output << plugin.filter("<= five\n")
          output << plugin.filter("Plan: 1 to add\n")
          output << plugin.filter("Do you want to perform these actions?\n")

          expect(output).to match(/add\n\nPlan Summary:\n\+ one\n- two\n~ three\n-\/\+ four\n<= five\n\nDo you/m)
        end

        it 'should display summary lines regardless of control codes' do
          output  = ""
          output << plugin.filter("Terraform will perform the following actions:\n")
          output << plugin.filter("\e[0m  \e[33m+\e[0m\e[0m one\n")
          output << plugin.filter("Plan: 1 to add\n")
          output << plugin.filter("Do you want to perform these actions?\n")

          expect(output).to match(/add\n\nPlan Summary:\n\e\[0m  \e\[33m\+\e\[0m\e\[0m one\n\nDo you/m)
        end

        it 'should display summary lines only' do
          output = ""
          output << plugin.filter("stuff\n")
          output << plugin.filter("Terraform will perform the following actions:\n")
          output << plugin.filter("foo\n")
          output << plugin.filter("+ one\n")
          output << plugin.filter("  moreone\n")
          output << plugin.filter("    + nestedone\n")
          output << plugin.filter("- two\n")
          output << plugin.filter("  moretwo\n")
          output << plugin.filter("    ~ nestedtwo\n")
          output << plugin.filter("Plan: 1 to add\n")
          output << plugin.filter("Do you want to perform these actions?\n")
          expect(output).to match(/add\n\nPlan Summary:\n\+ one\n- two\n\nDo you/m)
        end

        it 'should display summary lines for prompt when data batched up' do
          output = ""
          output << plugin.filter(<<~EOF
            + something
            Terraform will perform the following actions:
            + one
            Plan: 1 to add
            Do you want to perform these actions?
          EOF
          )
          expect(output).to match(/add\n\nPlan Summary:\n\+ one\n\nDo you/m)
        end

      end

    end
  end
end
