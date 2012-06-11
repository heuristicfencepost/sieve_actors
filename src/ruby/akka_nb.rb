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
module Sieve

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
        model = Actors.actorOf { Model.new }
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

      case msg[0]
      when :next
        # If we still have seeds to return do so up front
        seed = @seeds.shift
        if seed
          self.getContext.replySafe seed
          return
        end

        # Preserve a channel to the original sender so that we can deliver answers when we
        # get them
        @reply_channel = self.getContext.channel

        update_and_send_candidate
      when :prime
        if !validate_model_reply(msg)
          return
        end
        @replies << true
        check_replies
      when :not_prime
        if !validate_model_reply(msg)
          return
        end
        @replies << false
        check_replies
      end
    end

    # Some basic validation; make sure the message is a list of the correct size and
    # that the second element (the value the model is reporting on) matches the current
    # candidate.
    def validate_model_reply(msg)
      return msg.length == 2 && msg[1] == @candidate
    end

    # Update the candidate state and send to all models
    def update_and_send_candidate
      @candidate = @candidates.first
      @models.each { |m| m.tell([:prime?,@candidate],self.getContext) }
    end

    # Check to see if we've received responses from all models.  If we have then check to
    # see if everybody said the candidate was prime.  If that's the case we're okay to send
    # the candidate to the caller, otherwise we get to start all over with the next candidate.
    def check_replies

      if @replies.length < @models.length
        return
      end

      # We've found the next prime.  Add this value to one of the models, reset as much
      # of our state as possible and send the result to the caller
      if @replies.all?
        nextprime = @candidate

        @models[(rand @models.size)].tell [:add,nextprime]

        @replies.clear
        @candidate = nil

        @reply_channel.tell nextprime

      # We don't have a prime, so get a new candidate, send it off to the models and
      # reset what state we can
      else
        @replies.clear

        update_and_send_candidate
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
      case msg[0]
      when :add

        if msg.length != 2
          return
        end
        @primes << msg[1]
      when :prime?

        # Upfront validation; make sure we have some primes and that the message is of the appropriate size
        if msg.length != 2 || @primes.empty?
          self.getContext.replySafe nil
          return
        end

        # The model only considers a value prime if it doesn't equal or divide evenly into any previously 
        # observed prime.
        candidate = msg[1]
        resp = @primes.none? do |prime|
          candidate != prime and candidate % prime == 0
        end
        self.getContext.replySafe [resp ? :prime : :not_prime,candidate]
      else
        puts "Unknown message type #{type}"
      end
    end
  end
end
