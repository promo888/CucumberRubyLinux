#require 'minitest/autorun' #'test/unit'
require "rubygems"
require "graphviz"
#require 'ruby_fann/neural_network'
#require 'ruby_fann/neurotica'
require 'ruby_fann'
#require 'test/unit/testcase'

=begin
class NeuroticaTest < Test::Unit::TestCase
  def test_basic_output
    neurotica = RubyFann::Neurotica.new

    train = RubyFann::TrainData.new(
        :inputs=>[[0.3, 0.4, 0.5, 1.0, -1.0], [0.1, 0.2, 0.3, 1.0, 1.0], [0.6, 0.74, 0.58, -1.0, -1.0], [0.109, 0.677, 0.21, -1.0, 1.0]],
        :desired_outputs=>[[0.7, 0.4, 0.9], [0.8, -0.2, -0.5], [-0.33, 0.34, -0.22], [0.129, -0.87, 0.25]])

    neural_net = RubyFann::Standard.new(:num_inputs=>3, :hidden_neurons=>[4, 2, 1], :num_outputs=>3)
    neural_net.train_on_data(train, 100, 20, 0.01)

    neurotica.graph(neural_net, "neurotica1.png")

    # train = RubyFann::TrainData.new(:inputs=>[[0.3, 0.4, 0.5], [0.1, 0.2, 0.3]], :desired_outputs=>[[0.7], [0.8]])
    neural_net = RubyFann::Shortcut.new(:num_inputs=>3, :num_outputs=>3)
    neural_net.cascadetrain_on_data(train, 5, 10, 0.1)
    neural_net.train_on_data(train, 5, 10, 0.1)



    neurotica.graph(neural_net, "neurotica2.png")
  end

  def test_3d_output
    train = RubyFann::TrainData.new(:inputs=>[[0.3, 0.4, 0.5], [0.1, 0.2, 0.3]], :desired_outputs=>[[0.7], [0.8]])
    #neural_net = RubyFann::Shortcut.new(9, 5, [2, 4, 12, 8, 4, 3, 4], 1)
    neural_net = RubyFann::Shortcut.new(:num_inputs=>4, :num_outputs=>1)
    neural_net.cascadetrain_on_data(train, 1000, 100, 0.1)
    neurotica = RubyFann::Neurotica.new
    neurotica.graph(neural_net, "neurotica2.vrml", :three_dimensional=>true)
    assert(File.exist?('neurotica2.vrml'))
  end

end

=end