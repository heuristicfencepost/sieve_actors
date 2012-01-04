require 'sieve_actor'

require 'test/unit'

class SieveControllerActorTest < Test::Unit::TestCase

  # Empty models shouldn't match anything
  def test_model_empty

    model = Actors.actorOf { Sieve::Model.new }
    model.start

    1.upto(10).each { |val| assert_equal(model.sendRequestReply([:isprime,val]),nil) }

    model.stop
  end

  # Verify that we can match some data after adding it
  def test_model_add

    model = Actors.actorOf { Sieve::Model.new }
    model.start

    seeds = [2,3,5,7]

    # Add in a few known primes
    seeds.each { |seed| model.tell [:add,seed] }

    # Verify that the values themselves show up as prime
    seeds.each { |seed| assert(model.sendRequestReply([:isprime,seed]),"Seed #{seed} failed") }

    # Verify that multiples of the known primes are NOT marked as primes
    seeds.each do |seed| 
      2.upto(100).each { |multiplier| assert(!model.sendRequestReply([:isprime,seed * multiplier]),"Multiplier #{multiplier} for seed #{seed} failed") }
    end

    # Verify that integers which aren't multiples of these primes aren't marked
    # as primes
    10.upto(1000) do |c|

      assert(model.sendRequestReply([:isprime,c]),"Candidate #{c} should be prime based on seeds but returned false") if seeds.all? { |seed| c % seed != 0 }
      assert(!model.sendRequestReply([:isprime,c]),"Candidate #{c} should not be prime based on seeds but returned true") if seeds.any? { |seed| c % seed == 0 }
    end

    model.stop
  end
end
