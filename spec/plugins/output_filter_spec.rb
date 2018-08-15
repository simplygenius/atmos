require "atmos/plugins/output_filter"

describe Atmos::Plugins::OutputFilter do

  let(:plugin) { described_class.new({foo: :bar}) }

  it 'should provide a context reader' do
    expect(plugin.context).to eq(foo: :bar)
  end

  it 'should raise if filter method is unimplemented' do
    expect { plugin.filter("") }.to raise_error(RuntimeError, /not implemented/)
  end

  it 'should allow close method to be unimplemented' do
    expect { plugin.close() }.to_not raise_error
  end

end
