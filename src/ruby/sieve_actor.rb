require 'java'
require 'lib/akka-actor-1.2.jar'
require 'lib/scala-library.jar'

java_import 'akka.actor.Actors'
java_import 'akka.actor.UntypedActor'
java_import 'akka.actor.UntypedActorFactory'

module Sieve

  # Basic Enumerable wrapper for a Controller actor... just a convenience thing really
  class Primes
    include Enumerable

    def initialize(controller)
      @controller = controller
    end

    def each
      loop do
        yield @controller.sendRequestReply(:next)
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

  class Controller < UntypedActor

    def initialize
      @models = 0.upto(3).map do |idx|
        model = Actors.actorOf { Sieve::Model.new }
        model.start
        model
      end

      # Seed models with a few initial values... just to get things going
      @seeds = [2,3,5,7]
      0.upto(3).each { |idx| @models[idx].tell [:add,@seeds[idx]] }

      @candidates = Candidates.new
    end

    # Part of the lifecycle for an Akka actor.  When this actor is shut down
    # we'll want to shut down all the models we're aware of as well
    def postStop
      @models.each { |m| m.stop }
    end

    def onReceive(msg)

      case msg
      when :next

        # If we still have seeds to return do so up front
        seed = @seeds.shift
        if seed
          self.getContext.replySafe(seed)
          return
        end

        # If we're still here then we need to evaluate candidates against our models.  Each
        # candidate value is fed into the models in parallel.  The first value that all models
        # agree is prime is returned as the value
        val = @candidates.find do |candidate|
          @models.map { |m| m.sendRequestReplyFuture [:isprime,candidate] }.all? do |f|
            f.await
            return false if not f.result.isDefined
            f.result.get
          end
        end

        # Now that we have a prime value we need to update the state of one of our models to
        # include this new value.  For now we just choose a model at random
        @models[(rand @models.size)].tell [:add,val]

        # Finally, send a response back to the caller
        self.getContext.replySafe val
      end
    end
  end

  # A model represents a fragment of the state of our sieve, specifically some subset
  # of the primes discovered so far.
  class Model < UntypedActor

    def initialize
      @primes = []
    end

    def onReceive(msg)

      # It's times like this that one really does miss Scala's pattern matching
      # but case fills in nicely enough
      (type,data) = msg
      case type
      when :add
        @primes << data
      when :isprime

        # If we haven't been fed any primes yet we can't say much...
        if @primes.empty?
          self.getContext.replySafe nil
          return
        end

        # This model only considers a value prime if it doesn't divide evenly into any
        # prime it already knows about.  Of course we have to make an exception if we're
        # testing one of the primes we already know about
        resp = @primes.none? do |prime|
          data != prime and data % prime == 0
        end
        self.getContext.replySafe resp
      else
        puts "Unknown type #{type}"
      end
    end
  end
end
