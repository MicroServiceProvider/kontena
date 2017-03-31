describe Kontena::Observable do
  let :observable_class do
    Class.new do
      include Celluloid
      include Kontena::Observable

      def crash
        fail
      end

      def spam_updates(enum)
        enum.each do |value|
          sleep 0.001
          update_observable value
        end
      end
    end
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Observer

      attr_reader :state, :values

      def initialize(*observables)
        @state = observe(*observables) do |*values|
          @values = values
        end
      end

      def ready?
        !@values.nil?
      end

      def crash
        fail
      end
    end
  end

  subject { observable_class.new }

  let(:object) { double(:test) }

  it "rejects a nil update", :celluloid => true, :log_celluloid_actor_crashes => false do
    expect{subject.update_observable nil}.to raise_error(ArgumentError)
  end

  it "stops notifying any crashed observers", :celluloid => true, :log_celluloid_actor_crashes => false do
    observer = observer_class.new(subject)
    expect(subject.observers).to_not be_empty

    expect{observer.crash}.to raise_error(RuntimeError)

    subject.update_observable(object)
    expect(subject.observers).to be_empty
  end

  it "handles concurrent observers", :celluloid => true do
    observer_count = 10
    update_count = 100

    subject.async.spam_updates(1..update_count)

    observers = observer_count.times.map {
      observer_class.new(subject)
    }

    expect(observers.map{|obs| obs.values[0]}).to eq [update_count] * observer_count
  end

  context "For chained observables" do
    let :chaining_class do
      Class.new do
        include Celluloid
        include Kontena::Observer
        include Kontena::Observable

        def initialize(observable)
          @state = observe(observable) do |value|
            update_observable "chained: " + value
          end
        end

        def ping

        end
      end
    end

    it "propagates the observed value", :celluloid => true do
      chaining = chaining_class.new(subject)
      observer = observer_class.new(chaining)

      subject.update_observable "test"

      chaining.ping # wait for intermediate actor to handle update

      expect(observer).to be_ready
      expect(observer.values).to eq ["chained: test"]
    end
  end
end
