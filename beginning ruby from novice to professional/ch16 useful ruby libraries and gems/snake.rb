class GameItem
  attr_accessor :x, :y
 
  def initialize(app, x, y, colour = '#fff', fill = '#000000')
    @app = app
    @x = x
    @y = y
    @app.stroke colour
    @app.fill fill
    @rect = app.rect x * cell_size, y * cell_size, cell_size - 1, cell_size - 1
  end
 
  def move_to(x, y)
    @x = x
    @y = y
    move_rect
  end
 
  def move_by(x, y)
    @x += x
    @y += y
    move_rect
  end
 
  def cell_size
    10
  end
 
  # This removes the item from the game
  def remove
    @rect.hide
    true
  end
 
  private
 
    def move_rect
      @rect.move @x * cell_size, @y * cell_size
    end
end
 
class Snake
  attr_accessor :segments, :x, :y
 
  class Segment < GameItem
  end
 
  def initialize(app, x, y)
    @app = app
    change_direction :left
    @segments = []
    @x = x
    @y = y
 
    add_segment
  end
 
  def length
    @segments.size
  end
 
  def add_segment
    segment = nil
    if @segments.empty?
      segment = Segment.new @app, @x, @y, '#ff0000'
    else
      segment = Segment.new @app, @segments.last.x, @segments.last.y
      segment.move_by @direction_x * -1, @direction_y * -1
    end
 
    # Make sure the segment is added to the back
    @segments << segment
  end
 
  def move
    @segments.reverse.each_with_index do |segment, i|
      if i + 1 == length
        segment.move_by @direction_x, @direction_y
      else
        next_segment = @segments.reverse[i + 1]
        segment.move_to next_segment.x, next_segment.y
      end
    end
 
    @x = @segments.first.x
    @y = @segments.first.y
  end
 
  def change_direction(direction)
    @direction = direction
    case direction
      when :up
        @direction_x = 0
        @direction_y = -1
      when :down
        @direction_x = 0
        @direction_y = 1
      when :left
        @direction_x = -1
        @direction_y = 0
      when :right
        @direction_x = 1
        @direction_y = 0
     end
  end
end
 
class GameBoard
  class Food < GameItem
    def initialize(app, x, y, colour = '#00ff00')
      super
    end
  end
 
  class Brick < GameItem
    def initialize(app, x, y, colour = '#6666ff', fill = '#000099')
      super
    end
  end
 
  def initialize(app, snake)
    @food_items = []
    @bricks = []
    @app = app
    @snake = snake
  end
 
  def add_food(x, y)
    # Don't add food over anything
    unless collision_with_anything? x, y
      @food_items << Food.new(@app, x, y)
    end
  end
 
  def add_brick(x, y)
    # Don't add bricks over anything
    unless collision_with_anything? x, y
      @bricks << Brick.new(@app, x, y)
    end
  end
 
  # Has the snake eaten some food?
  def food_eaten?
    collision? @snake.x, @snake.y, @food_items
  end
 
  # Add a segment to the snake and remove food at the snake's head
  def eat_food
    @snake.add_segment
    remove_food_at @snake.x, @snake.y
  end
 
  # Has the snake crashed into a brick?
  def crashed_into_brick?
    collision? @snake.x, @snake.y, @bricks
  end
 
  # Has the snake crashed into itself? Check the snake's head against the rest of its segments
  def crashed_into_self?
    collision? @snake.x, @snake.y, @snake.segments[1..-1]
  end
 
  # Is there a collision between any block in the game? Used when positioning blocks
  def collision_with_anything?(x, y)
    collision?(x, y, @bricks) or collision?(x, y, @food_items) or collision?(x, y, [@snake])
  end
 
  # Is there a collision for the x, y co-ords and a list of items that respond to x and y
  def collision?(x, y, items)
    items.find do |item|
      collision_at? x, y, item
    end
  end
 
  # Is there a collision at x, y and item (which responds to x and y)
  def collision_at?(x, y, item)
    item.x == x and item.y == y
  end
 
  def remove_food_at(x, y)
    @food_items.delete_if do |item|
      if item.x == x and item.y == y
        item.remove
      end
    end
  end
end
 
Shoes.app do
  background '#000'
 
  snake = Snake.new self, 25, 25
  board = GameBoard.new self, snake
 
  delay = 1
 
  stroke '#fff'
 
  # Add some food at random positions
  10.times do
    board.add_food rand(50), rand(50)
  end
 
  10.times do
    board.add_brick rand(50), rand(50)
  end
 
  @anim = animate 5 do
    keypress do |key|
      case key
        when :up, :down, :left, :right
          snake.change_direction key
      end
    end
 
    snake.move
 
    if board.food_eaten?
      board.eat_food
    elsif board.crashed_into_brick? or board.crashed_into_self?
      @anim.stop
    end
  end
end