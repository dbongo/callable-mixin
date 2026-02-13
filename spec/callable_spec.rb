# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Callable do
  # Captures any yields into an array we can assert on
  def capture_events
    events = []
    yield(events)
    events
  end

  # ------------------------------------------------------------------
  # 1. INITIALIZE PARAMETER VARIATIONS
  # ------------------------------------------------------------------
  describe "initialize parameter variations" do
    context "no parameters" do
      class NoParams
        include Callable

        def call
          :ok
        end
      end

      it { expect(NoParams.call).to eq(:ok) }
    end

    context "required positional parameters" do
      class PositionalReq
        include Callable

        def initialize(a)
          @a = a
        end

        def call
          @a
        end
      end

      it "passes required values through" do
        expect(PositionalReq.call(3)).to eq(3)
      end

      it "raises ConstructionError when missing args" do
        expect { PositionalReq.call }.to raise_error(Callable::ConstructionError)
      end
    end

    context "optional positional parameters" do
      class PositionalOpt
        include Callable

        def initialize(a = 5)
          @a = a
        end

        def call
          @a
        end
      end

      it { expect(PositionalOpt.call).to eq(5) }
      it { expect(PositionalOpt.call(9)).to eq(9) }
    end

    context "splat positional parameters (*args)" do
      class RestPositional
        include Callable

        def initialize(*nums)
          @sum = nums.inject(0, :+)
        end

        def call
          @sum
        end
      end

      it { expect(RestPositional.call(1, 2, 3)).to eq(6) }
      it { expect(RestPositional.call).to eq(0) }
    end

    context "required keyword parameters" do
      class KeywordReq
        include Callable

        def initialize(x:)
          @x = x
        end

        def call
          @x
        end
      end

      it { expect(KeywordReq.call(x: 10)).to eq(10) }
      it { expect { KeywordReq.call }.to raise_error(Callable::ConstructionError) }
    end

    context "optional keyword parameters" do
      class KeywordOpt
        include Callable

        def initialize(x: 7)
          @x = x
        end

        def call
          @x
        end
      end

      it { expect(KeywordOpt.call).to eq(7) }
      it { expect(KeywordOpt.call(x: 3)).to eq(3) }
    end

    context "keyword rest (**kwargs) only" do
      class KeywordRest
        include Callable

        def initialize(**opts)
          @opts = opts
        end

        def call
          @opts
        end
      end

      it { expect(KeywordRest.call(foo: 1, bar: 2)).to eq(foo: 1, bar: 2) }
      it { expect(KeywordRest.call).to eq({}) }
    end

    context "mixed positional + keyword parameters" do
      class Combo
        include Callable

        def initialize(a, b = 2, c:, d: 4, **rest)
          @vals = [a, b, c, d, rest]
        end

        def call
          @vals
        end
      end

      it "passes all variations correctly" do
        expect(Combo.call(1, c: 3, e: 5)).to eq([1, 2, 3, 4, { e: 5 }])
      end
    end

    context "rest positional AND rest keyword (**kwargs + *args)" do
      class RestCombo
        include Callable

        def initialize(*nums, **opts)
          @nums = nums
          @opts = opts
        end

        def call
          [@nums, @opts]
        end
      end

      it "passes both splats in one go" do
        expect(RestCombo.call(1, 2, foo: :bar)).to eq([[1, 2], { foo: :bar }])
      end
    end

    context "empty vs non-empty kwargs path" do
      class KwPath
        include Callable

        def initialize(**opts)
          @opts = opts
        end

        def call
          @opts
        end
      end

      it { expect(KwPath.call).to eq({}) }
      it { expect(KwPath.call(foo: 1)).to eq({foo: 1}) }
    end

    context "complex positional and keyword args with empty kwargs" do
      class ComplexCtor
        include Callable

        def initialize(a, b = 2, c:, d: 4, **rest)
          @vals = [a, b, c, d, rest]
        end

        def call
          @vals
        end
      end

      it "handles explicit empty kwargs correctly" do
        expect(ComplexCtor.call(1, c: 3)).to eq([1, 2, 3, 4, {}])
      end
    end

    context "positional hash argument (Ruby 2.7 compat)" do
      class HashReceiver
        include Callable

        def initialize(data)
          @data = data
        end

        def call
          @data
        end
      end

      it "passes a hash as a positional arg without triggering kwargs conversion" do
        expect(HashReceiver.call({a: 1, b: 2})).to eq({a: 1, b: 2})
      end
    end
  end

  # ------------------------------------------------------------------
  # 2. BLOCK-FORWARDING RULES
  # ------------------------------------------------------------------
  describe "block forwarding" do
    context "block forwarded when #call captures &block and has arity 0" do
      class Forwarded
        include Callable

        def call(&blk)
          blk.call(:call) if blk
        end
      end

      it "yields inside #call" do
        events = capture_events { |e|
          Forwarded.call { |tag| e << tag }
        }
        expect(events).to eq([:call])
      end
    end

    context "no block given at all" do
      class NoForward
        include Callable

        def initialize
        end

        def call
          :ok
        end
      end

      it "still returns without error" do
        expect(NoForward.call).to eq(:ok)
      end
    end

    context "block NOT forwarded to initialize" do
      class InitNoForward
        include Callable

        def initialize
          yield(:init) if block_given? # would capture if forwarded
        end

        def call
          :ok
        end
      end

      it "does not yield inside initialize" do
        events = capture_events do |e|
          InitNoForward.call { |tag| e << tag }
        end
        expect(events).to eq([])
      end
    end

    context "block forwarded to #call even when #call has parameters" do
      class CallWithArgs
        include Callable

        def call(msg = nil)
          yield(:call) if block_given?
          msg || :done
        end
      end

      it "yields inside #call even without constructor args" do
        events = capture_events do |e|
          CallWithArgs.call { |tag| e << tag }
        end
        expect(events).to eq([:call])
      end
    end
  end

  # ------------------------------------------------------------------
  # 2b. TO_PROC SHORTHAND
  # ------------------------------------------------------------------
  describe "to_proc shorthand" do
    class Doubler
      include Callable

      def initialize(n)
        @n = n
      end

      def call
        @n * 2
      end
    end

    it "allows &Class syntax with Enumerable methods" do
      expect([1, 2, 3].map(&Doubler)).to eq([2, 4, 6])
    end
  end

  # ------------------------------------------------------------------
  # 3. SPECIAL CONSTRUCTOR CASES
  # ------------------------------------------------------------------
  describe "constructor visibility" do
    class PrivateInit
      include Callable

      def initialize(x)
        @x = x
      end
      private :initialize

      def call
        @x * 2
      end
    end

    it "works even when initialize is private" do
      expect(PrivateInit.call(4)).to eq(8)
    end
  end

  # ------------------------------------------------------------------
  # 4. ERROR HANDLING
  # ------------------------------------------------------------------
  describe "error propagation" do
    class BadInit
      include Callable

      def initialize(x)
      end

      def call
      end
    end

    it "wraps ArgumentError from constructor in ConstructionError" do
      expect { BadInit.call }.to raise_error(Callable::ConstructionError)
    end

    class CallError
      include Callable

      def call
        raise "boom"
      end
    end

    it "does NOT wrap errors raised by #call" do
      expect { CallError.call }.to raise_error(RuntimeError, "boom")
    end

    context "missing call implementation" do
      class NoCallMethod
        include Callable

        # no `call` defined
      end

      it "raises NotImplementedError when #call is not implemented" do
        expect { NoCallMethod.call }.to raise_error(
          NotImplementedError,
          /NoCallMethod must implement #call/
        )
      end
    end
  end

  # ------------------------------------------------------------------
  # 5. WRAP-vs-PROPAGATE MATRIX
  # ------------------------------------------------------------------
  describe "wrap vs propagate" do
    class InitArgumentError
      include Callable

      def initialize(*)
        raise ArgumentError, "bad ctor"
      end

      def call
        :never
      end
    end

    it "wraps ArgumentError raised in #initialize" do
      expect { InitArgumentError.call }
        .to raise_error(Callable::ConstructionError, /bad ctor/)
    end

    class CallArgumentError
      include Callable

      def call
        raise ArgumentError, "bad call"
      end
    end

    it "propagates ArgumentError raised in #call untouched" do
      expect { CallArgumentError.call }
        .to raise_error(ArgumentError, "bad call")
    end

    context "non-ArgumentError raised by constructor" do
      class InitTypeError
        include Callable

        def initialize(*)
          raise TypeError, "unexpected type"
        end

        def call
          :never
        end
      end

      it "does NOT wrap TypeError from initialize" do
        expect { InitTypeError.call }.to raise_error(TypeError, "unexpected type")
      end
    end
  end

  # ------------------------------------------------------------------
  # 6. SUBCLASS vs BASE ArgumentError
  # ------------------------------------------------------------------
  describe "ArgumentError handling nuances" do
    class CtorCustomError < ArgumentError; end
    class InitCustomErrorService
      include Callable

      def initialize(*)
        raise CtorCustomError, "custom ctor err"
      end

      def call
        :never
      end
    end

    it "propagates custom ArgumentError subclass from #initialize" do
      expect { InitCustomErrorService.call }
        .to raise_error(CtorCustomError, "custom ctor err")
    end

    class CallCustomErrorService
      include Callable

      def call
        raise CtorCustomError, "custom call err"
      end
    end

    it "propagates custom ArgumentError subclass from #call" do
      expect { CallCustomErrorService.call }
        .to raise_error(CtorCustomError, "custom call err")
    end
  end
end
