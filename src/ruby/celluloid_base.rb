require 'celluloid'

# Non-blocking implementation of our actor-based Sieve of Eratosthenes implementation.
# This implementation uses Celluloid actors (http://celluloid.io) rather than Akka.
module Sieve

  # Basic Enumerable wrapper for a Controller actor... just a convenience thing really
  class Primes
    include Enumerable

    def initialize
      @controller = Controller.new
    end

    def each
      loop do
        # Value used in this message is largely irrelevant
        yield @controller.next
      end
    end
  end

  # Enumerable implementation representing the set of prime number candidates > 10.  Use of an
  # enumerable here allows us to isolate the state associated with candidate selection to this
  # class, freeing up the model and controller actors to focus on other parts of the computation
  class Candidates
    include Enumerable

    def initialize
      # Note that this initial value is never actually returned; we're only setting the stage for the
      # first increment to generate the first candidate
      @next = 9
    end

    # Primes must be a number ending in 1, 3, 7 or 9... a bit of reflection will make it clear why
    def each
      loop do
        @next += (@next % 10 == 3) ? 4 : 2
        yield @next
      end
    end
  end

  class Controller
    include Celluloid

    def initialize
      @models = 0.upto(3).map { |i| Model.new }

      # Seed models with a few initial values... just to get things going
      @seeds = [2,3,5,7]
      0.upto(3).each { |idx| @models[idx].add! @seeds[idx] }

      @candidates = Candidates.new
    end

    # Revert back to the old future-based semantics here.  This function has to support both
    # synchronous and async execution so it always has to return an answer when called.
    def next
      # If we still have seeds to return do so up front
      seed = @seeds.shift
      if seed
        return seed
      end

      # Otherwise loop through candidates and build a collection of futures (one for each model) for each
      # of those candidates.  The first value that returns all true values wins!
      nextprime = @candidates.find do |candidate|
        @models.map { |m| m.future :is_prime,candidate }.all? { |f| f.value }
      end

      # We found our next prime so update one of the models...
      @models[(rand @models.size)].add! nextprime

      # ... and return
      nextprime
    end
  end

  # A model represents a fragment of the state of our sieve, specifically some subset
  # of the primes discovered so far.
  #
  # In the Celluloid model there is no one unified entry point for message handling.  Each handled
  # message type is now implemented as a distinct method that can be called synchronously or
  # asynchronously.  Since method calls are logically equivalent to messages (see Smalltalk)
  # this should work reasonably well.
  class Model
    include Celluloid

    def initialize
      @primes = []
    end

    def add newprime
      @primes << newprime
    end

    def is_prime candidate
      # Upfront validation; make sure we have some primes
      if @primes.empty?
        return nil
      end

      # The model only considers a value prime if it doesn't equal or divide evenly into any previously 
      # observed prime.
      @primes.none? { |prime| candidate != prime and candidate % prime == 0 }
    end
  end
end
