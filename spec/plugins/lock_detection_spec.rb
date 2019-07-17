require "simplygenius/atmos/plugins/lock_detection"

module SimplyGenius
  module Atmos
    module Plugins

      describe LockDetection do

        let(:plugin) { described_class.new({}) }
        let(:lockid) { "6db0d2a0-7eaa-c83b-4f3f-e24bc48a8c1f" }

        before :each do
          Atmos.config = Config.new("ops")
        end

        after :all do
          Atmos.config = nil
        end

        it 'should pass through data in filter' do
          expect(plugin.filter("foo\n")).to eq("foo\n")
        end

        it 'should detect a lock and save ID' do
          plugin.filter("Lock Info:\n")
          plugin.filter("blah\n")
          plugin.filter("ID: #{lockid}\n")
          expect(plugin.instance_variable_get(:@lock_detected)).to eq(true)
          expect(plugin.instance_variable_get(:@lock_id)).to eq(lockid)
        end

        it 'should prompt to release lock on close' do
          plugin.filter("Lock Info:\nID: #{lockid}\n")
          expect(plugin).to receive(:agree).with(/Terraform lock detected/)
          plugin.close
        end

        it 'should not prompt to release lock on close if not lock_id' do
          plugin.filter("Lock Info:\nID:\n")
          expect(plugin).to_not receive(:agree)
          plugin.close
        end

        it 'should not unlock if answer is no' do
          plugin.filter("Lock Info:\nID: #{lockid}\n")
          expect(Atmos::TerraformExecutor).to_not receive(:new)
          expect { simulate_stdin("n") { plugin.close } }.to output(/Terraform lock detected/).to_stdout
        end

        it 'should unlock if answer is yes' do
          plugin.filter("Lock Info:\nID: #{lockid}\n")
          te = Atmos::TerraformExecutor.new(process_env: Hash.new)
          expect(Atmos::TerraformExecutor).to receive(:new).and_return(te)
          expect(te).to receive(:run).with("force-unlock", "-force", lockid)
          expect { simulate_stdin("y") { plugin.close } }.to output(/Terraform lock detected/).to_stdout
        end

      end

    end
  end
end
