require 'sieve_actor'

require 'test/unit'

class SieveActorTest < Test::Unit::TestCase

  def test_model_basic

    model = Actors.actorOf { Sieve::Model.new }
    model.start

    # We shouldn't have any data yet
    (1..10).each do |val|
      msg = [:check,val]
      assert(! (model.sendRequestReply msg))
    end

    # Add in a few data items
    model.tell [:add,3]
    model.tell [:add,7]

    # Re-run the tests, this time searching for true results for the values we just added
    (1..10).each do |val|
      msg = [:check,val]
      if val == 3 or val == 7
        assert(model.sendRequestReply msg)
      else 
        assert(! (model.sendRequestReply msg))
      end
    end

    model.stop
  end
end
