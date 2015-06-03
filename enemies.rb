############################### classes abstratas ##############################

class Enemy < GameObject
  def initialize(x, y, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp = 1)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows

    @indices = indices
    @interval = interval
    @score = score
    @hp = hp
    @control_timer = 0

    @active_bounds = Rectangle.new x + img_gap.x, y + img_gap.y, @img[0].width, @img[0].height
  end

  def set_active_bounds(section)
    t = (@y + @img_gap.y).floor
    r = (@x + @img_gap.x + @img[0].width).ceil
    b = (@y + @img_gap.y + @img[0].height).ceil
    l = (@x + @img_gap.x).floor

    if t > section.size.y; @dead = true
    elsif r < 0; @dead = true
    elsif b < C::TOP_MARGIN; @dead = true #para sumir por cima, a margem deve ser maior
    elsif l > section.size.x; @dead = true
    else
      if t < @active_bounds.y
        @active_bounds.h += @active_bounds.y - t
        @active_bounds.y = t
      end
      @active_bounds.w = r - @active_bounds.x if r > @active_bounds.x + @active_bounds.w
      @active_bounds.h = b - @active_bounds.y if b > @active_bounds.y + @active_bounds.h
      if l < @active_bounds.x
        @active_bounds.w += @active_bounds.x - l
        @active_bounds.x = l
      end
    end
  end

  def update(section)
    if @dying
      @control_timer += 1
      @dead = true if @control_timer == 150
      return if @img_index == @indices[-1]
      animate @indices, @interval
      return
    end

    unless @invulnerable
      if SB.player.bomb.over? self
        hit_by_bomb(section)
        SB.player.bomb.stored_forces.y -= C::BOUNCE_FORCE
      elsif SB.player.bomb.explode? self
        hit_by_explosion(section)
      elsif section.projectile_hit? self
        hit(section)
      elsif SB.player.bomb.collide? self
        SB.player.bomb.hit
      end
    end

    return if @dying

    if @invulnerable
      @control_timer += 1
      return_vulnerable if @control_timer == C::INVULNERABLE_TIME
    end

    yield if block_given?

    set_active_bounds section
    animate @indices, @interval
  end

  def hit_by_bomb(section)
    hit(section)
  end

  def hit_by_explosion(section)
    @hp = 1
    hit(section)
  end

  def hit(section)
    @hp -= 1
    if @hp == 0
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      @dying = true
    else
      get_invulnerable
    end
  end

  def get_invulnerable
    @invulnerable = true
  end

  def return_vulnerable
    @invulnerable = false
    @control_timer = 0
  end
end

class FloorEnemy < Enemy
  def initialize(x, y, args, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp = 1, speed = 3)
    super x, y, w, h, img, img_gap, sprite_cols, sprite_rows, indices, interval, score, hp

    @dont_fall = args.nil?
    @speed_m = speed
    @forces = Vector.new -@speed_m, 0
    @facing_right = false
  end

  def update(section)
    if @invulnerable
      super section
    else
      super section do
        #puts "left: #{@left}" if @bottom.is_a? Ramp
        move @forces, section.get_obstacles(@x, @y), section.ramps
        @forces.x = 0
        if @left
          set_direction :right
        elsif @right
          set_direction :left
        elsif @dont_fall
          if @facing_right
            set_direction :left unless section.obstacle_at? @x + @w, @y + @h
          elsif not section.obstacle_at? @x - 1, @y + @h
            set_direction :right
          end
        end
      end
    end
  end

  def hit(section)
    super
    if @dying
      @indices = [2, 3, 4]
      @interval = 5
    end
  end

  def set_direction(dir)
    @speed.x = 0
    if dir == :left
      @forces.x = -@speed_m
      @facing_right = false
    else
      @forces.x = @speed_m
      @facing_right = true
    end
  end

  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
  end
end

################################################################################

class Wheeliam < FloorEnemy
  def initialize(x, y, args, section)
    super x, y, args, 32, 32, :sprite_Wheeliam, Vector.new(-4, -3), 5, 2, [0, 1], 8, 100
  end
end

class Sprinny < Enemy
  def initialize(x, y, args, section)
    super x + 3, y - 4, 26, 36, :sprite_Sprinny, Vector.new(-2, -5), 6, 1, [0], 5, 350

    @leaps = 1000
    @max_leaps = args.to_i
    @facing_right = true
  end

  def update(section)
    super section do
      forces = Vector.new 0, 0
      if @bottom
        @leaps += 1
        if @leaps > @max_leaps
          @leaps = 1
          if @facing_right
            @facing_right = false
            @indices = [0, 1, 2, 1]
            set_animation 0
          else
            @facing_right = true
            @indices = [3, 4, 5, 4]
            set_animation 3
          end
        end
        @speed.x = 0
        if @facing_right; forces.x = 4
        else; forces.x = -4; end
        forces.y = -15
      end
      move forces, section.get_obstacles(@x, @y), section.ramps
    end
  end
end

class Fureel < FloorEnemy
  def initialize(x, y, args, section)
    super x - 4, y - 4, args, 40, 36, :sprite_Fureel, Vector.new(-10, -3), 5, 2, [0, 1], 8, 300, 2, 4
  end

  def get_invulnerable
    @invulnerable = true
    @indices = [2]
    set_animation 2
  end

  def return_vulnerable
    @invulnerable = false
    @timer = 0
    @indices = [0, 1]
    set_animation 0
  end
end

class Yaw < Enemy
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_Yaw, Vector.new(-4, -4), 8, 1, [0, 1, 2], 6, 500
    @moving_eye = false
    @eye_timer = 0
    @points = [
      Vector.new(x + 64, y),
      Vector.new(x + 96, y + 32),
      Vector.new(x + 96, y + 96),
      Vector.new(x + 64, y + 128),
      Vector.new(x, y + 128),
      Vector.new(x - 32, y + 96),
      Vector.new(x - 32, y + 32),
      Vector.new(x, y)
    ]
  end

  def update(section)
    super section do
      cycle @points, 3
    end
  end

  def hit_by_bomb(section)
    SB.player.die
  end
end

class Ekips < GameObject
  def initialize(x, y, args, section)
    super x + 5, y - 10, 22, 25, :sprite_Ekips, Vector.new(-37, -8), 2, 3

    @act_timer = 0
    @active_bounds = Rectangle.new x - 32, y - 18, 96, 50
    @attack_bounds = Rectangle.new x - 32, y + 10, 96, 12
    @score = 240
  end

  def update(section)
    if SB.player.bomb.explode?(self) || section.projectile_hit?(self) && !@attacking
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      @dead = true
      return
    end

    if SB.player.bomb.over? self
      if @attacking
        SB.player.stage_score += @score
        section.add_score_effect(@x + @w / 2, @y, @score)
        @dead = true
        return
      else
        SB.player.die
      end
    elsif @attacking and SB.player.bomb.bounds.intersect? @attack_bounds
      SB.player.die
    elsif SB.player.bomb.collide? self
      SB.player.die
    end

    @act_timer += 1
    if @preparing and @act_timer >= 60
      animate [2, 3, 4, 5], 5
      if @img_index == 5
        @attacking = true
        @preparing = false
        set_animation 5
        @act_timer = 0
      end
    elsif @attacking and @act_timer >= 150
      animate [4, 3, 2, 1, 0], 5
      if @img_index == 0
        @attacking = false
        set_animation 0
        @act_timer = 0
      end
    elsif @act_timer >= 150
      @preparing = true
      set_animation 1
      @act_timer = 0
    end
  end
end

class Faller < GameObject
  def initialize(x, y, args, section)
    super x, y, 32, 32, :sprite_Faller1, Vector.new(0, 0), 4, 1
    @range = args.to_i
    @start = Vector.new x, y
    @up = Vector.new x, y - @range * 32
    @active_bounds = Rectangle.new x, @up.y, 32, (@range + 1) * 32
    @passable = true
    section.obstacles << self

    @bottom = Block.new x, y + 20, 32, 12, false
    @bottom_img = Res.img :sprite_Faller2
    section.obstacles << @bottom

    @indices = [0, 1, 2, 3, 2, 1]
    @interval = 8
    @step = 0
    @act_timer = 0
    @score = 300
  end

  def update(section)
    if SB.player.bomb.explode? self
      SB.player.stage_score += @score
      section.add_score_effect(@x + @w / 2, @y, @score)
      section.obstacles.delete self
      section.obstacles.delete @bottom
      @dead = true
      return
    elsif SB.player.bomb.bottom == @bottom
      SB.player.die
    elsif SB.player.bomb.collide? self
      SB.player.die
    end

    animate @indices, @interval

    if @step == 0 or @step == 2 # parado
      @act_timer += 1
      if @act_timer >= 90
        @step += 1
        @act_timer = 0
      end
    elsif @step == 1 # subindo
      move_carrying @up, 2, [SB.player.bomb]
      @step += 1 if @speed.y == 0
    else # descendo
      diff = ((@start.y - @y) / 5).ceil
      move_carrying @start, diff, [SB.player.bomb]
      @step = 0 if @speed.y == 0
    end
  end

  def draw(map)
    @img[@img_index].draw @x - map.cam.x, @y - map.cam.y, 0
    @bottom_img.draw @x - map.cam.x, @start.y + 15 - map.cam.y, 0
  end
end

class Turner < Enemy
  def initialize(x, y, args, section)
    super x + 2, y - 7, 60, 39, :sprite_Turner, Vector.new(-2, -25), 3, 2, [0, 1, 2, 1], 8, 300
    @harmful = true
    @passable = true

    @aim1 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim1.x - 3, @aim1.y and
      not section.obstacle_at? @aim1.x - 3, @aim1.y + 8
      @aim1.x -= C::TILE_SIZE
    end

    @aim2 = Vector.new(@x, @y)
    while not section.obstacle_at? @aim2.x + 63, @aim2.y and
      not section.obstacle_at? @aim2.x + 63, @aim2.y + 8
      @aim2.x += C::TILE_SIZE
    end

    @obst = section.obstacles
  end

  def update(section)
    @harm_bounds = Rectangle.new @x, @y - 23, 60, 62
    super section do
      if @harmful
        SB.player.die if SB.player.bomb.bounds.intersect? @harm_bounds
        move_free @aim1, 2
        if @speed.x == 0 and @speed.y == 0
          @harmful = false
          @indices = [3, 4, 5, 4]
          set_animation 3
          @obst << self
        end
      else
        move_carrying @aim2, 2, [SB.player.bomb]
        if @speed.x == 0 and @speed.y == 0
          @harmful = true
          @indices = [0, 1, 2, 1]
          set_animation 0
          @obst.delete self
        end
      end
    end
  end

  def hit_by_bomb(section); end

  def hit_by_explosion
    SB.player.stage_score += @score
    @obst.delete self unless @harmful
    @dead = true
  end
end

class Chamal < Enemy
  X_OFFSET = 320
  MAX_MOVEMENT = 160

  def initialize(x, y, args, section)
    super x - 25, y - 74, 82, 106, :sprite_chamal, Vector.new(-16, -8), 3, 1, [0, 1, 0, 2], 7, 5000, 3
    @left_limit = @x - X_OFFSET
    @right_limit = @x + X_OFFSET
    @activation_x = @x + @w / 2 - C::SCREEN_WIDTH / 2
    @spawn_points = [
      Vector.new(@x + @w / 2 - 120, 0),
      Vector.new(@x + @w / 2, -20),
      Vector.new(@x + @w / 2 + 120, 0)
    ]
    @spawns = []
    @speed_m = 4
    @timer = 0
    @turn = 0
    @facing_right = false
    @state = :waiting
  end

  def update(section)
    if @state == :waiting
      if SB.player.bomb.x >= @activation_x
        section.set_fixed_camera(@x + @w / 2 - C::SCREEN_WIDTH / 2, @y + @h / 2 - C::SCREEN_HEIGHT / 2)
        @state = :speaking
      end
    elsif @state == :speaking
      @timer += 1
      if @timer >= 300 or KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbReturn
        section.unset_fixed_camera
        @state = :acting
        @timer = 119
      end
    else
      if @dying
        @timer += 1
        if @timer >= 300 or KB.key_pressed? Gosu::KbSpace or KB.key_pressed? Gosu::KbReturn
          section.unset_fixed_camera
          section.finish
          @dead = true
        end
        return
      end
      super(section) do
        if @moving
          move_free @aim, @speed_m
          if @speed.x == 0 and @speed.y == 0
            @moving = false
            @timer = 0
          end
        else
          @timer += 1
          if @timer == 120
            x = rand @left_limit..@right_limit
            x = @x - MAX_MOVEMENT if @x - x > MAX_MOVEMENT
            x = @x + MAX_MOVEMENT if x - @x > MAX_MOVEMENT
            @aim = Vector.new x, @y
            if x < @x; @facing_right = false
            else; @facing_right = true; end
            @moving = true
            if @turn % 5 == 0 and @spawns.size < 4
              @spawn_points.each do |p|
                @spawns << Wheeliam.new(p.x, p.y, nil, section)
                section.add(@spawns[-1])
              end
              @respawned = true
            end
            @turn += 1
          end
        end
        spawns_dead = true
        @spawns.each do |s|
          if s.dead?; @spawns.delete s
          else; spawns_dead = false; end
        end
        if spawns_dead and @respawned and @gun_powder.nil?
          @gun_powder = GunPowder.new(@x, @y, nil, section, nil)
          section.add(@gun_powder)
          @respawned = false
        end
        @gun_powder = nil if @gun_powder && @gun_powder.dead?
      end
      if @dying
        set_animation 0
        section.set_fixed_camera(@x + @w / 2 - C::SCREEN_WIDTH / 2, @y + @h / 2 - C::SCREEN_HEIGHT / 2)
        @timer = 0
      end
    end
  end

  def hit_by_bomb(section); end

  def hit_by_explosion(section)
    hit(section)
    @moving = false
    @timer = -C::INVULNERABLE_TIME
  end

  def get_invulnerable
    super
    @indices = [0]
    set_animation 0
  end

  def return_vulnerable
    super
    @indices = [0, 1, 0, 2]
    set_animation 0
  end

  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
    if @state == :speaking or (@dying and not @dead)
      G.window.draw_quad 5, 495, C::PANEL_COLOR,
                         795, 495, C::PANEL_COLOR,
                         5, 595, C::PANEL_COLOR,
                         795, 595, C::PANEL_COLOR, 1
      SB.text_helper.write_breaking SB.text(@state == :speaking ? :chamal_speech : :chamal_death), 10, 500, 790, :justified, 0, 255, 1
    end
  end
end

class Electong < Enemy
  def initialize(x, y, args, section)
    super x - 12, y - 11, 56, 43, :sprite_electong, Vector.new(-4, -91), 4, 2, [0, 1, 2, 1], 7, 500, 1
    @timer = 0
    @tongue_y = @y
  end

  def hit_by_bomb(section)
    SB.player.die
  end

  def update(section)
    super(section) do
      b = SB.player.bomb
      if @will_attack
        @tongue_y -= 91 / 14.0
        if @img_index == 5
          @indices = [5, 6, 7, 6]
          @attacking = true
          @will_attack = false
          @tongue_y = @y - 91
        end
      elsif @attacking
        @timer += 1
        if @timer == 150
          @indices = [4, 3, 0]
          set_animation 4
          @attacking = false
        end
      elsif @timer > 0
        @tongue_y += 91 / 14.0
        if @img_index == 0
          @indices = [0, 1, 2, 1]
          @timer = -30
          @tongue_y = @y
        end
      else
        @timer += 1 if @timer < 0
        if @timer == 0 and b.x + b.w > @x - 20 and b.x < @x + @w + 20
          @indices = [3, 4, 5]
          set_animation 3
          @will_attack = true
        end
      end
      if b.bounds.intersect? Rectangle.new(@x + 22, @tongue_y, 12, @y + @h - @tongue_y)
        b.hit
      end
    end
  end
end

class Chrazer < Enemy
  def initialize(x, y, args, section)
    super x + 1, y - 11, 30, 43, :sprite_chrazer, Vector.new(-21, -20), 2, 2, [0, 1, 0, 2], 7, 600, 2
    @facing_right = false
  end

  def update(section)
    super(section) do
      forces = Vector.new(0, 0)
      unless @invulnerable
        d = SB.player.bomb.x - @x
        d = 150 if d > 150
        d = -150 if d < -150
        if @bottom
          forces.x = d * 0.01666667
          forces.y = -14.5
          if d > 0 and not @facing_right
            @facing_right = true
          elsif d < 0 and @facing_right
            @facing_right = false
          end
          @speed.x = 0
        else
          forces.x = d * 0.001
        end
      end
      move forces, section.get_obstacles(@x, @y), section.ramps
    end
  end

  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, @facing_right ? :horiz : nil)
  end
end

class Robort < FloorEnemy
  def initialize(x, y, args, section)
    super x - 12, y - 31, args, 56, 63, :sprite_robort, Vector.new(-6, -1), 3, 1, [0, 1, 2, 1], 7, 450, 3
  end
end