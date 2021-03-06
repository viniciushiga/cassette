

describe Cassette do
  def keeping_logger(&block)
    original_logger = Cassette.logger
    block.call
    Cassette.logger = original_logger
  end

  describe '.logger' do
    it 'returns a default instance' do
      expect(Cassette.logger).not_to be_nil
      expect(Cassette.logger.is_a?(Logger)).to eql(true)
    end

    it 'returns rails logger when Rails is available' do
      keeping_logger do
        Cassette.logger = nil
        rails = double('Rails')
        expect(rails).to receive(:logger).and_return(rails).at_least(:once)
        stub_const('Rails', rails)
        expect(Cassette.logger).to eql(rails)
      end
    end
  end

  describe '.logger=' do
    let(:logger) { Logger.new(STDOUT) }
    it 'defines the logger instance' do
      keeping_logger do
        Cassette.logger = logger
        expect(Cassette.logger).to eq(logger)
      end
    end
  end
end
