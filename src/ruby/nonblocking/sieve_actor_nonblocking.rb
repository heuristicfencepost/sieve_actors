require 'java'
require 'lib/akka-actor-1.2.jar'
require 'lib/scala-library.jar'

java_import 'akka.actor.Actors'
java_import 'akka.actor.UntypedActor'
java_import 'akka.actor.UntypedActorFactory'

# Non-blocking implementation of our actor-based Sieve of Eratosthenes implementation.  Key
# to this implementation is that the channel used for input message to the controller is
# preserved.  This approach frees up the controller to receive responses from the models
# using standard actor messaging.  The calling client (in this case the Primes enumerable)
# must block in order to yield a value but the actors (specifically the controller) no longer
# has to wait on a response from the model.
module SieveNonblocking

  # Basic Enumerable wrapper for a Controller actor... just a convenience thing really
  class Primes
    include Enumerable

    def initialize(controller)
      @controller = controller
    end

    def each
      loop do
        # Value used in this message is largely irrelevant
        yield @controller.sendRequestReply [:next,0]
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
        model = Actors.actorOf { SieveNonblocking::Model.new }
        model.start
        model
      end

      # Seed models with a few initial values... just to get things going
      @seeds = [2,3,5,7]
      0.upto(3).each { |idx| @models[idx].tell [:add,@seeds[idx]] }

      @candidates = Candidates.new

      # Introduce member list to keep track of the responses we've received from each
      # actor
      @replies = []
    end

    # Part of the lifecycle for an Akka actor.  When this actor is shut down
    # we'll want to shut down all the models we're aware of as well
    def postStop
      @models.each { |m| m.stop }
    end

    def onReceive(msg)
      (type,data) = msg
      case type
      when :next
        # If we still have seeds to return do so up front
        seed = @seeds.shift
        if seed
          self.getContext.replySafe seed
          return
        end

        # If we're still here then we need to evaluate candidates against our models.  Each
        # candidate value is fed into the models in parallel.  The first value that all models
        # agree is prime is returned as the value
        #
        # We're now doing this in a non-blocking fashion so we need to do the following:
        # - preserve a reference to the original sender
        # - preserve the current candidate value
        # - send the candidate to all models to initiate the process
        @reply_channel = self.getContext.channel
        @candidate = @candidates.first
        @models.each { |m| m.tell([:isprime,@candidate],self.getContext) }
      when :isprime
        # Preserve the answer we got in @replies
        @replies << data

        # If we've received replies from all models then we need further processing
        if @replies.length == @models.length

          # We have a prime, so do the following:
          # - add the new prime to one of the models
          # - reset what state we can
          # - send the result
          if @replies.all?
            reply = @candidate

            @models[(rand @models.size)].tell [:add,reply]

            @replies.clear
            @candidate = nil

            @reply_channel.tell reply

          # We don't have a prime, so get a new candidate, send it off to the models and
          # reset what state we can
          else
            @candidate = @candidates.first
            @models.each { |m| m.tell([:isprime,@candidate],self.getContext) }

            # Still need to clean up after ourselves
            @replies.clear
          end
        end
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
        self.getContext.replySafe [:isprime,resp]
      else
        puts "Unknown message type #{type}"
      end
    end
  end
end
