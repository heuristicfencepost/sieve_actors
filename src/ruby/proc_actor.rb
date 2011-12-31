require 'java'
require 'lib/akka-actor-1.2.jar'
require 'lib/scala-library.jar'

java_import 'akka.actor.UntypedActor'
java_import 'akka.actor.UntypedActorFactory'

# Actor implementation which takes in a Proc object; that object will be responsible for
# handling all incoming messages
class ProcActor < UntypedActor

  def proc=(b)
    @proc = b
  end

  def onReceive(msg)
    @proc.call msg
  end
end

class ProcActorFactory
  include UntypedActorFactory

  def initialize(&b)
    @proc = b
  end

  def create
    rv = ProcActor.new
    rv.proc = @proc
    rv
  end
end
