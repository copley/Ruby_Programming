require 'pp'

class Class
  def shortname
    name().gsub(/^.*:/, '')
  end
end

class NilClass
  def rep
    nil
  end
end

class Matrix
  def initialize(cols, rows)
    @rows = rows
    @cols = cols
    @data = []
    rows.times do |y|
      @data[y] = Array.new(cols)
    end
  end

  def [](x, y)
    @data[y][x]
  end

  def []=(x, y, value)
    @data[y][x] = value
  end

  def all_positions
    (0...@rows).collect do |y|
      (0...@cols).collect do |x|
        [x, y]
      end
    end.inject([]) {|a, b| a.concat b}
  end

  def rep
    @data.collect do |row|
      row.collect do |item|
        item.rep
      end
    end
  end
end

class Map
  attr_reader :terrain, :units

  def initialize(key, layout)
    rows = layout.split("\n")
    rows.collect! {|row| row.gsub(/\s+/, '').split(//) }

    y = rows.size
    x = rows[0].size

    @terrain = Matrix.new(x, y)
    @units  = Matrix.new(x, y)

    rows.each_with_index do |row, y|
      row.each_with_index do |glyph, x|
        @terrain[x, y] = key[glyph]
      end
    end
  end

  def place(x, y, unit)
    @units[x, y] = unit
    unit.x = x
    unit.y = y
  end

  def move(old_x, old_y, new_x, new_y)
    raise LocationOccuppiedError.new(new_x, new_y) if @units[new_x, new_y]
    @units[new_x, new_y] = @units[old_x, old_y]
    @units[old_x, old_y] = nil
  end

  def all_positions
    @terrain.all_positions
  end

  def within?(distance, x1, y1, x2, y2)
    (x1 - x2).abs + (y1 - y2).abs <= distance
  end

  def near_positions(distance, x, y)
    all_positions.find_all{|x2, y2| within?(distance, x, y, x2, y2) }
  end

  def rep
    return [@terrain.rep, @units.rep]
  end
end

class LocationOccupiedError < Exception
end

class Terrain
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def rep
    [@name]
  end
end

class Unit
  attr_reader :player, :name, :health, :movement, :actions
  attr_accessor :x, :y
  def initialize(player, name)
    @player = player
    @name = name
    @health = 10
    @movement = 2
    @actions = []
  end

  def move(x, y)
    @player.game.map.move(@x, @y, x, y)
    @x = x
    @y = y
  end

  def hurt(damage)
    return if dead?
    @health -= damage
    die if dead?
  end

  def dead?
    return @health <= 0
  end

  def alive?
    return ! dead?
  end

  def die
    @player.game.message_all("#{name} died.")
  end

  def enemy?(other)
    (other != nil) && (player != other.player)
  end

  def friend?(other)
    (other != nil) && (player == other.player)
  end

  def done?; @done; end
  def done; @done = true; end
  def new_turn; @done = false; end

  def move_choices
    map = @player.game.map
    all = map.all_positions
    near = all.find_all {|x, y| map.within?(@movement, @x, @y, x, y) }
    valid = near.find_all {|x, y| map.units[x, y].nil? }
    return valid.collect do |x, y|
      Choice.new("Move", x, y) { self.move(x, y) }
    end
  end

  def action_choices
    return actions.collect do |action|
      Choice.new(*action.rep) { action }
    end
  end

  def rep
    [self.class.shortname, name]
  end
end

class Choice
  attr_reader :rep
  def initialize(*rep, &action)
    @rep, @action = rep, action
  end

  def call(*args, &proc)
    @action.call(*args, &proc)
  end
end

DONE = Choice.new("Done")

class Action
  def self.rep
    ["Action", self.shortname]
  end

  def self.range(unit); 1; end
  def self.target?(unit, other); unit.enemy?(other); end

  # Default Action generator assumes action is something you
  # do to the enemy standing next to you. This behavior will
  # overriden in many subclasses.
  def self.generate(unit, game)
    map = game.map
    near = map.near_positions(range(unit), unit.x, unit.y)
    targets = near.find_all{|x, y| target?(unit, map.units[x, y]) }
    return targets.collect{|x, y| self.new(unit, game, x, y) }
  end

  attr_reader :unit, :game
  def initialize(unit, game, x, y)
    @unit = unit
    @game = game
    @x = x
    @y = y
  end

  def call
    raise NotImplementedError
  end

  def target
    game.map.units[@x, @y]
  end

  def rep
    [self.class.shortname, @x, @y]
  end
end

class BasePlayer
  attr_reader :name
  attr_accessor :game

  def initialize(name)
    @name  = name
    @units = []
  end

  def message(string); raise NotImplementedError; end
  def draw(map); raise NotImplementedError; end
  def do_choose; raise NotImplementedError; end

  def add_unit(unit); @units.push unit; end
  def clear_units; @units = []; end
  def units_left?; @units.any?{|unit| unit.alive? }; end
  def new_turn; @units.each{|unit| unit.new_turn }; end
  def done; @game.message_all("Level finished"); end

  def unit_choices 
    not_done = @units.find_all{|unit| unit.alive? && ! unit.done? }
    return not_done.map do |unit|
      Choice.new("Unit", unit.x, unit.y) { unit }
    end
  end

  def choose(choices, &block)
    do_choose(choices, &block) if choices?(choices)
  end

  def choices?(choices)
    ! (choices.empty? || (choices.size == 1 && choices[0] == DONE) )
  end

  def choose_all(choices, &block)
    while choices?(choices)
      choose(choices) do |choice|
        block.call(choice)
        choices.delete(choice)
      end
    end
  end

  def choose_all_or_done(choices, &block)
    choices_or_done = choices.dup
    choices_or_done.push DONE
    choose_all(choices_or_done, &block)
  end

  def choose_or_done(choices, &block)
    choices_or_done = choices.dup
    choices_or_done.push DONE
    choose(choices_or_done, &block)
  end
end

class DumbComputer < BasePlayer
  def message(string)
  end

  def draw(map)
  end

  def do_choose(choices)
    yield choices[0]
  end
end

class CLIPlayer < BasePlayer
  def message(string)
    puts string
  end

  def draw(map)
    puts "Terrain:"
    pp map.terrain.rep
    puts "Units:"
    pp map.units.rep
  end

  def do_choose(choices)
    mapping = rep_mapping(choices)

    choice = nil

    until choice
      puts "Choose: "
      puts mapping.keys

      print "Input: "
      choice_key = STDIN.gets.strip
      choice = mapping[choice_key]

      puts "Bad choice" unless choice
    end

    yield choice
  end

  def rep_mapping(data)
    mapping = {}
    data.each do |datum|
      mapping[datum.rep.inspect] = datum
    end
    return mapping
  end
end

class Game
  attr_reader :players

  def initialize
    @maps = []
    @on_start = []
    @players = []

    @map_index = 0
    @player_index = 0
    @done = false
  end

  def map; @maps[@map_index]; end
  def player; @players[@player_index]; end
  def next_map; @map_index += 1; end
  def next_player; @player_index = (@player_index + 1) % @players.size; end
  def start_map; @on_start[@map_index].call(map) if @on_start[@map_index]; end

  def add_map(map, &on_start)
    @maps.push map
    @on_start.push on_start
  end

  def add_player(player)
    @players.push player
    player.game = self
  end

  def done
    players.each{|player| player.done }
    @done = true
  end

  def done?; @done; end

  def draw_all
    @players.each {|player| player.draw(map) }
  end

  def message_all(text)
    @players.each {|player| player.message(text) }
  end

  def run
    message_all("Welcome to #{name}!")
    
    while true
      break unless map

      start_map
      until done?
        turn(player())
        next_player()
      end      

      next_map
    end

    message_all("Thanks for playing.")
  end

  def turn
    raise NotImplementedError
  end

  def name
    raise NotImplementedError
  end
end

class DinoWars < Game
  def name
    return "DinoWars: Westward Ho!"
  end

  def turn(player)
    player.new_turn

    draw_all()

    player.choose_all_or_done(player.unit_choices) do |choice|
      break if choice == DONE
      unit = choice.call

      draw_all()

      player.choose(unit.move_choices) do |move|
        move.call
      end

      draw_all()

      player.choose_or_done(unit.action_choices) do |choice|
        break if choice == DONE
        action = choice.call

        player.choose(action.generate(unit, self)) do |action_instance|
          action_instance.call 
        end
      end

      unit.done

      draw_all()
    end

    done() unless players().find_all{|player| player.units_left?}.size > 1
  end
end

class Attack < Action
  def damage_caused(unit); raise NotImplementedError; end
  def past_tense; raise NotImplementedError; end

  def call
    amount = damage_caused()
    game.message_all("#{unit.name} #{past_tense} #{target.name} for #{amount} damage.")
    target.hurt(amount)
  end
end

class Bite < Attack
  def damage_caused; @unit.teeth; end
  def past_tense; "bit"; end
end

class Shoot < Attack
  def self.range(unit); unit.range; end
  def damage_caused; @unit.caliber; end
  def past_tense; "shot"; end
end

class FirstAid < Action
  def self.target?(unit, other); unit.friend?(other); end
  def call
    target.hurt(-unit.heal)
    game.message_all("#{unit.name} healed #{target.name} for #{unit.heal} health.")
  end
end

class Human < Unit
  attr_reader :caliber
  attr_reader :range
  def initialize(*args)
    super(*args)
    @actions << Shoot
    @caliber = 4
    @range = 3
  end
end

class Soldier < Human; end

class Doctor < Human
  attr_reader :heal
  def initialize(*args)
    @actions << FirstAid
    @heal = 2
  end
end

class Dinosaur < Unit
  attr_reader :teeth
  def initialize(*args)
    super(*args)
    @actions << Bite
    @teeth = 2
  end
end

class TRex < Unit
  def initialize(*args)
    @teeth = 5
  end
end

class VRaptor < Dinosaur; end


forest = Terrain.new("Forest")
grass = Terrain.new("Grass")
mountains = Terrain.new("Mountains")
plains = Terrain.new("Plains")
water = Terrain.new("Water")

terrain_key = {
  "f" => forest,
  "g" => grass,
  "m" => mountains,
  "p" => plains,
  "w" => water,
}

map = Map.new terrain_key, <<-END
  gggggggggg
  gggggggwww
  ggggggwwff
  gggppppppp
  ggppggwfpf
  ggpgggwwff
END
