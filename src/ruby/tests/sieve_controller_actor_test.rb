require 'sieve_actor'

require 'test/unit'

# Basic test for model actor functionality
class SieveControllerActorTest < Test::Unit::TestCase

  # Verify that we can at least obtain the seeded values from the controller
  def test_controller_seeds_only

    puts "Seeds only"

    controller = Actors.actorOf { Sieve::Controller.new }
    controller.start

    assert_equal(2,controller.sendRequestReply(:next))
    assert_equal(3,controller.sendRequestReply(:next))
    assert_equal(5,controller.sendRequestReply(:next))
    assert_equal(7,controller.sendRequestReply(:next))

    controller.stop
  end

  # Now verify that the controller correctly computes new primes
  def test_controller_computed_primes

    puts "Computed primes"

    controller = Actors.actorOf { Sieve::Controller.new }
    controller.start

    1.upto(4).each { controller.sendRequestReply(:next) }

    assert_equal(11,controller.sendRequestReply(:next))
    assert_equal(13,controller.sendRequestReply(:next))
    assert_equal(17,controller.sendRequestReply(:next))
    assert_equal(19,controller.sendRequestReply(:next))
    assert_equal(23,controller.sendRequestReply(:next))
    assert_equal(29,controller.sendRequestReply(:next))

    controller.stop
  end
end 
