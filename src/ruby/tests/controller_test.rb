puts "Running controller test with #{ARGV[1]}"
require ARGV[1]

require 'mathn'

require 'test/unit'

# Basic test for controller actor functionality
class ControllerTest < Test::Unit::TestCase

  # Verify that we can at least obtain the seeded values from the controller
  def test_controller_seeds_only

    controller = Actors.actorOf { Sieve::Controller.new }
    controller.start

    primes = Sieve::Primes.new(controller)
    assert_equal([2,3,5,7],primes.take(4))

    controller.stop
  end

  # Now verify that the controller correctly computes new primes
  def test_controller_computed_primes

    controller = Actors.actorOf { Sieve::Controller.new }
    controller.start

    # Skip past the seeded values
    primes1 = Sieve::Primes.new(controller)
    primes1.take 4

    primes2 = Prime.new
    primes2.take 4

    assert_equal(primes1.take(100),primes2.take(100))

    controller.stop
  end
end 
