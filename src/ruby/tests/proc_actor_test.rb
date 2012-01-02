require 'proc_actor'

require 'test/unit'

require 'java'
require 'lib/akka-actor-1.2.jar'
require 'lib/scala-library.jar'

java_import 'akka.actor.Actors'

class ProcActorTest < Test::Unit::TestCase

  def test_proc_actor

    exp = []

    # Create a factory for an actor that uses the input block to pass incoming messages.
    factory = ProcActorFactory.new do |msg|
      exp << msg
    end
    ref = Actors.actorOf factory
    ref.start

    vals = (1..10).map { |i| rand 1000 }
    print "Vals: #{vals.join ','}\n"
    vals.each { |val| ref.tell val }

    # Give messages time to propagate
    sleep 3

    print "Exp: #{exp.join ','}\n"

    assert_equal(10,exp.size)
    vals.each do |val|
      assert(exp.include? val)
    end

    ref.stop
  end

  # This test currently fails for a known reason... albeit one that I can't resolve yet.  The closure passed
  # into the actor factory references all free variables to the scope in which it was defiend; that's sort of
  # the point of a closure.  The problem is that we also need to allow the code within this closure to reference
  # the actor in which it runs, or at least the context for that actor, in order to use getContext.replySafe from
  # the Java API.  But at this point in the process the actor isn't accessible to the scope... for that matter the
  # actor isn't even built yet.
  def test_proc_actor_with_futures

    # Create a factory for an actor that uses the input block to pass incoming messages.
    factory = ProcActorFactory.new do |msg|
      rv = 2 * msg
      # Fails completely.  self in this code references the unit test scope, but what we need is some way
      # to refer to the actor's scope.
      self.getContext.replySafe rv
    end
    ref = Actors.actorOf factory
    ref.start

    sample = rand 100
    resp = ref.sendRequestReplyFuture sample

    # Give messages time to propagate
    sleep 3

    resp.await
    assert resp.isCompleted
    respval = resp.result
    assert respval.isDefined
    assert_equal(2 * sample,respval.get)
  end
end
