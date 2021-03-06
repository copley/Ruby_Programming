module Enumerable
  def random
    self[rand(size)]
  end
end

class GeneticAlgorithm
  attr_reader :population

  def initialize(population_size, selection_size)
    @population     = (0...population_size).map{|i| yield i }
    @selection_size = selection_size
  end

  def fittest(n=@selection_size)
    @population.sort_by{|member| member.fitness }[-n..-1]
  end
end
