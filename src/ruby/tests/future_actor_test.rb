require 'test/unit'

require 'java'
require 'lib/akka-actor-1.2.jar'
require 'lib/scala-library.jar'

java_import 'akka.actor.Actors'
java_import 'akka.actor.UntypedActor'
java_import 'akka.actor.UntypedActorFactory'

class FutureActor < UntypedActor

  # Test the Java API for replying actors
  def onReceive(msg)
    self.getContext.replySafe "Hello #{msg}"
  end
end

class FutureActorTest < Test::Unit::TestCase

  def test_future_actor

    # JRuby automatically converts the closure below to an instance of the SAM
    # ActorFactory interface.
    ref = Actors.actorOf { FutureActor.new }
    ref.start

    # Test the Java API for send-with-futures and obtaining values
    f1 = ref.sendRequestReplyFuture "Foo"
    f2 = ref.sendRequestReplyFuture "Bar"

    f2.await
    assert(f2.isCompleted)
    f2result = f2.result
    assert(f2result.isDefined)
    assert_equal("Hello Bar",f2result.get)

    f1.await
    assert(f1.isCompleted)
    f1result = f1.result
    assert(f1result.isDefined)
    assert_equal("Hello Foo",f1result.get)

    ref.stop
  end
end
