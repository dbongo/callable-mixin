# frozen_string_literal: true

##
# Callable
#
# A lightweight mix‑in that gives any class a convenient class‑level `.call` helper.
#
#   class SendEmail
#     include Callable
#
#     def initialize(user)
#       @user = user
#     end
#
#     def call
#       Mailer.welcome(@user).deliver_now
#     end
#   end
#
#   SendEmail.call(User.first)  # => delivers email
#   users.each(&SendEmail)      # => thanks to #to_proc
#
# Compatible with Ruby 2.3+ and works the same on 3.x.
module Callable
  # Raised when `.call` cannot build the instance (arity/keyword mismatch).
  class ConstructionError < ArgumentError; end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    ##
    # Instantiate the class and immediately invoke its instance `#call`.
    #
    # @param args [Array] positional and keyword arguments forwarded to `initialize`
    #   (keyword transparency provided by `ruby2_keywords`).
    # @yield [optional] block passed directly to the instance method `#call`; ignored if not yielded.
    # @return anything returned by the instance `#call`.
    # @raise [ConstructionError] if construction fails (plain `ArgumentError`).
    # @raise [NotImplementedError] if the instance does not implement `#call`.
    def call(*args, &block)
      inst = new(*args)
    rescue ArgumentError => e
      # Bubble up anything that isn't exactly ArgumentError (e.g., subclasses)
      raise unless e.instance_of?(ArgumentError)
      raise ConstructionError, "Cannot instantiate #{name}: #{e.message}", e.backtrace
    else
      # Ensure the instance defines `#call`
      unless inst.respond_to?(:call)
        raise NotImplementedError, "#{name} must implement #call"
      end
      inst.call(&block)
    end
    ruby2_keywords(:call) if respond_to?(:ruby2_keywords, true)

    # @return [Proc] a proc that delegates to `.call`, enabling `&MyService` shorthand.
    def to_proc
      method(:call).to_proc
    end
  end
end
