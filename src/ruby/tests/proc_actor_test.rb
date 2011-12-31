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
end
