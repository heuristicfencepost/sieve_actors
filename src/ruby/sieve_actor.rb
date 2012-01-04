require 'java'
require 'lib/akka-actor-1.2.jar'
require 'lib/scala-library.jar'

java_import 'akka.actor.Actors'
java_import 'akka.actor.UntypedActor'
java_import 'akka.actor.UntypedActorFactory'

module Sieve

  class Controller < UntypedActor

    @models = []

    def onReceive(msg)
      self.getContext.replySafe "Hello #{msg}"
    end
  end

  class Model < UntypedActor

    def initialize()
      @primes = []
    end

    def onReceive(msg)

      # It's times like this that one really does miss Scala's pattern matching
      # but case fills in nicely enough
      (type,data) = msg
      case type
        when :add
        puts "Adding value #{data}"
        @primes << data
        when :check
        puts "Checking value #{data}"
        self.getContext.replySafe(@primes.include? data)
        else
        puts "Unknown type #{type}"
      end
    end
  end
end
