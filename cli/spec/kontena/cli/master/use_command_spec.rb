require 'kontena/cli/master/use_command'

describe Kontena::Cli::Master::UseCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe '#use' do
    it 'should update current master' do
      expect(subject.config).to receive(:write).and_return(true)
      subject.run(['some_master'])
      expect(subject.config.current_server).to eq 'some_master'
    end

    it 'should abort with error message if master is not configured' do
      expect { subject.run(['not_existing']) }.to output(/Could not resolve master with name: 'not_existing'/).to_stderr
    end
  end
end
