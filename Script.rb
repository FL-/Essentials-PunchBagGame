#===============================================================================
# * Punch Bag Game - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. The player select a pokémon for a
# simple minigame where he gains points the closer to the center the cursor is
# when the button is pressed. EVs and IVs can be the rewards.
#
#== INSTALLATION ===============================================================
#
# Put it above main OR convert into a plugin. Create "Punch Bag" folder at 
# Graphics/UI and put the pictures (may works with other sizes):
# -  32x32  arrow 
# - 262x20  bar
# - 512x288 bg
# - 104x256 punchbag 
# -  48x40  star
#
#== HOW TO USE =================================================================
#
# Use the script command 'PunchBag.play(X)' where X is the number of rounds OR
# the Parameters class instance. This method will return the player score or nil
# if it was cancelled. 
#
# Look at Parameters class and/or at examples about how to pass options.
#
#== EXAMPLES ===================================================================
#
# - 15 rounds without reward:
#
#  PunchBag.play(15)
#
# - 10 rounds. Receive 2 EVs in all stats if the score is 30 or higher:
#
#  PunchBag.play(PunchBag::Parameters.new(10).setMinScore(30).setEvGain(2))
#
# - 5 rounds. Receive max ATK IV if the score is 22 or bigger. Accept fainted
# pokémon, but won't allow pokémon who already was ATK IV maxed or isn't at 
# level 100.
#
#  param = PunchBag::Parameters.new(5)
#  param.stats = :ATTACK
#  param.minScore = 22
#  param.maximizeIV = true
#  param.acceptFainted = true
#  param.blockMax = true
#  param.minLevel = 100
#  PunchBag.play(param)
#
#===============================================================================

if defined?(PluginManager) && !PluginManager.installed?("Punch Bag Game")
  PluginManager.register({                                                 
    :name    => "Punch Bag Game",                                        
    :version => "1.2.1",                                                     
    :link    => "https://www.pokecommunity.com/showthread.php?t=346235",
    :credits => "FL"
  })
end

module PunchBag
  class Parameters
    attr_accessor :rounds
    attr_accessor :canCancel
    attr_accessor :acceptFainted
    attr_accessor :blockMax
    attr_accessor :minLevel
    attr_accessor :minScore
    attr_accessor :stats # Should be a symbol or a symbol array
    attr_accessor :evGain
    attr_accessor :ivGain
    attr_accessor :maximizeIV

    def initialize(rounds)
      @rounds = rounds
      @canCancel = true
      @acceptFainted = false
      @blockMax = false
      @minLevel = 0
      @minScore = 0
      @stats = [
        :HP, :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE
      ]
      @evGain = 0
      @ivGain = 0
      @maximizeIV = false
    end
    
    def setCanCancel(canCancel)
      @canCancel = canCancel
      return self
    end
    
    def setAcceptFainted(acceptFainted)
      @acceptFainted = acceptFainted
      return self
    end
    
    def setBlockMax(blockMax)
      @blockMax = blockMax
      return self
    end
    
    def setMinLevel(minLevel)
      @minLevel = minLevel
      return self
    end
    
    def setMinScore(minScore)
      @minScore = minScore
      return self
    end
    
    def setStats(stats)
      @stats = stats
      return self
    end
    
    def setEvGain(evGain)
      @evGain = evGain
      return self
    end
    
    def setIvGain(ivGain)
      @ivGain = ivGain
      return self
    end
    
    def setMaximizeIV(maximizeIV)
      @maximizeIV = maximizeIV
      return self
    end

    def statArray
      return @stats.is_a?(Array) ? @stats : [@stats]
    end
  end

  class Scene
    # Time is in seconds. Speed is in pixels per seconds
    # Size of the valid bar points between the left and the center
    BAR_LEFT_SIZE = 128 
    ARROW_SPEED = 640
    ARROW_SCORE_DISTANCE = 16 # -1 for every this distance from center
    MAX_SCORE = 5
    MIN_SCORE = 1
      
    BAG_SPEED_ARRAY = [80,120,160]
    BAG_ANGLES_ARRAY = [0,16,32,64]
    POKEMON_SPEED = 640
    POKEMON_DISTANCE = 64
    WAIT_ANIMATION_TIME = 0.2
    
    def pbStartScene(pkmn,rounds)
      @sprites={} 
      @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      @viewport.z=99999
      @sprites["field"]=IconSprite.new(0,0,@viewport)
      @sprites["field"].setBitmap("Graphics/UI/Punch Bag/bg")
      @sprites["field"].y=-48
      # An extra background. Used because the first one haven't the screen size, 
      # so a small part can be seen below window.
      @sprites["fieldBack"]=IconSprite.new(0,0,@viewport)
      @sprites["fieldBack"].setBitmap("Graphics/UI/Punch Bag/bg")
      @sprites["fieldBack"].y=@sprites["field"].bitmap.height
      @sprites["fieldBack"].z=@sprites["field"].z-1 # Under Field.
      @sprites["scorebox"]=Window_AdvancedTextPokemon.new
      @sprites["scorebox"].viewport=@viewport
      pbBottomLeftLines(@sprites["scorebox"],2)
      @sprites["scorebox"].width=160
      @sprites["scorebox"].z=2
      @sprites["barbox"]=Window_AdvancedTextPokemon.new
      @sprites["barbox"].viewport=@viewport
      pbBottomLeftLines(@sprites["barbox"],2)
      @sprites["barbox"].x=@sprites["scorebox"].width
      @sprites["barbox"].width=Graphics.width-@sprites["scorebox"].width
      @sprites["barbox"].z=2
      @sprites["starbox"]=Window_AdvancedTextPokemon.new
      @sprites["starbox"].viewport=@viewport
      pbBottomLeftLines(@sprites["starbox"],1)
      @sprites["starbox"].y=@sprites["scorebox"].y-@sprites["starbox"].height
      @sprites["starbox"].z=2
      @sprites["punchbag"]=IconSprite.new(0,0,@viewport)  
      @sprites["punchbag"].setBitmap("Graphics/UI/Punch Bag/punch_bag")
      @sprites["punchbag"].x=Graphics.width/2
      # The bag center is the rope
      @sprites["punchbag"].ox=@sprites["punchbag"].bitmap.width/2 
      @sprites["punchbag"].y=-38
      @sprites["pokemonback"]=PokemonSprite.new(@viewport)
      @sprites["pokemonback"].setPokemonBitmap(pkmn,true) 
      Bridge.setPokemonBottomOffset(@sprites["pokemonback"], pkmn)
      @sprites["pokemonback"].x += @sprites["punchbag"].x-56-POKEMON_DISTANCE
      @sprites["pokemonback"].y += 228
      @sprites["pokemonback"].z=1
      @sprites["bar"]=IconSprite.new(0,0,@viewport)
      @sprites["bar"].setBitmap("Graphics/UI/Punch Bag/bar")
      @sprites["bar"].x=@sprites["barbox"].x+(
        @sprites["barbox"].width-@sprites["bar"].bitmap.width
      )/2
      @sprites["bar"].y=@sprites["barbox"].y+44
      @sprites["bar"].z=3
      @sprites["arrow"]=IconSprite.new(0,0,@viewport)
      @sprites["arrow"].setBitmap("Graphics/UI/Punch Bag/arrow")
      @arrowXMiddle = (
        @sprites["bar"].x - @sprites["arrow"].bitmap.width/2 + 4 + BAR_LEFT_SIZE
      )
      @sprites["arrow"].x = @arrowXMiddle-BAR_LEFT_SIZE
      @sprites["arrow"].y = @sprites["bar"].y-24
      @sprites["arrow"].z=3
      for i in 0...5
        @sprites["star#{i}"]=IconSprite.new(0,0,@viewport)
        @sprites["star#{i}"].setBitmap("Graphics/UI/Punch Bag/star")
        @sprites["star#{i}"].x=32+(@sprites["star#{i}"].bitmap.width+52)*i
        @sprites["star#{i}"].y=@sprites["starbox"].y+12
        @sprites["star#{i}"].z=3
      end
      @rounds = rounds
      pbMakeAllStarsInvisible
      @sprites["overlay"]=BitmapSprite.new(
        Graphics.width, Graphics.height, @viewport
      )
      @moving=true
      @right=false
      @score = 0
      @lastScore = 0
      @shoots = 0
      @endGame=false
      @nextAngle=0
      @lastAngle=0
      @angleDirection=1
      @bagAnimating=false
      @bagWaitTime=0
      @pokemonAnimating=false
      @pokemonWaitTime=0
      @animating=false
      @arrowX = @sprites["arrow"].x
      @pokemonX = @sprites["pokemonback"].x
      pbSetSystemFont(@sprites["overlay"].bitmap)
      pbDrawText
      pbFadeInAndShow(@sprites) { update }
    end

    def pbDrawText
      @sprites["scorebox"].text = _INTL(
        "Score: {1} \nHits: {2}/{3}",@score,@shoots,@rounds
      )
    end
    
    def pbDrawStars(stars)
      pbMakeAllStarsInvisible
      for i in 0...stars
        @sprites["star#{i}"].visible=true
      end
    end
    
    def pbMakeAllStarsInvisible
      for i in 0...5
        @sprites["star#{i}"].visible=false
      end
    end  

    def pbMain(canCancel)
      @timeCount=0
      loop do
        Graphics.update
        Input.update
        self.update
        if @endGame
          return @score if !@animating
        else  
          if (
            Input.trigger?(Input::B) && canCancel && 
            Bridge.confirmMessage(_INTL("Exit?")){ update }
          )
            pbPlayCursorSE
            break
          end
          if Input.trigger?(Input::C) && @lastScore==0
            distance = BAR_LEFT_SIZE 
            if @arrowX>@arrowXMiddle
              distance -= @arrowX-@arrowXMiddle
            else 
              distance -= @arrowXMiddle-@arrowX
            end
            @lastScore=[(
              (distance - BAR_LEFT_SIZE)/ARROW_SCORE_DISTANCE.to_f + MAX_SCORE
            ).round, MIN_SCORE].max
            @sprites["arrow"].visible = false
          end
          if @moving
            @right = true  if @arrowX<=@arrowXMiddle-BAR_LEFT_SIZE
            @right = false if @arrowX>=@arrowXMiddle+BAR_LEFT_SIZE            
            @arrowX += (
              (@right ? ARROW_SPEED : -ARROW_SPEED)*Bridge.delta
            )
            @sprites["arrow"].x = @arrowX.round
          end
        end
        @timeCount+=Bridge.delta
      end
      return nil
    end
    
    def update
      updateAnimation
      pbUpdateSpriteHash(@sprites)
    end
    
    def computeScore
      # Computes the score at a certain point at the animation.
      # When the bag stops at air for the first time at that punch
      @shoots+=1
      @endGame = true if @shoots==@rounds
      @score+=@lastScore
      pbSEPlay(Bridge.getAudioName("Pkmn move learnt")) if @lastScore==MAX_SCORE
      pbDrawText
      pbDrawStars(@lastScore)
      @lastScore = 0
      @scoreComputed = true
      @sprites["arrow"].visible = true
    end  
    
    def setAnimation
      lastScoreFromMax = @lastScore-MAX_SCORE
      @nextAngle = case lastScoreFromMax
      when 0;  BAG_ANGLES_ARRAY[3] # Perfect hit
      when -1; BAG_ANGLES_ARRAY[2]
      when -2; BAG_ANGLES_ARRAY[1]
      else;    BAG_ANGLES_ARRAY[0]
      end
      @angleDirection = 1
      lastScoreFromMax==0 ? 64 : 32
      @bagSpeedIndex = lastScoreFromMax==0 ? 2 : 0
      @pokemonAnimating=true
      @pokemonSpeed=POKEMON_SPEED
      @pokemonX=@pokemonX.floor
      @pokemonDestiny=@pokemonX+POKEMON_DISTANCE
      @scoreComputed=false
    end  
    
    def updateAnimation
      @animating = @pokemonAnimating || @bagAnimating
      if !@animating && @lastScore!=0
        setAnimation
      end  
      updateAnimationBag if @bagAnimating
      updateAnimationPokemon if @pokemonAnimating
    end  
    
    def updateAnimationBag
      return if @bagWaitTime>@timeCount
      angle = @sprites["punchbag"].angle
      angle = @nextAngle if reached(angle, @nextAngle, @angleDirection)
      if angle == @nextAngle
        if @nextAngle==0
          if @bagSpeedIndex>0 # Max Score
            @nextAngle=-BAG_ANGLES_ARRAY[-2]
          else
            @bagAnimating=false
          end  
        else  
          if @nextAngle<0 # Reverse direction
            @nextAngle=BAG_ANGLES_ARRAY[-3]
          else
            @nextAngle=0
          end
          @bagWaitTime=@timeCount+WAIT_ANIMATION_TIME-0.001
          computeScore if !@scoreComputed 
        end
        @angleDirection = @nextAngle>angle ? 1 : -1
      else
        # Cut the speed to half every time that bag cross middle
        if (@lastAngle < 0) != (angle < 0) && @bagSpeedIndex!=0 
          @bagSpeedIndex-=1 
        end
        @lastAngle = angle
        angle+=BAG_SPEED_ARRAY[@bagSpeedIndex] * @angleDirection * Bridge.delta
      end
      @sprites["punchbag"].angle = angle
    end  
    
    def updateAnimationPokemon
      return if @pokemonWaitTime>@timeCount
      @pokemonX+=@pokemonSpeed*Bridge.delta
      if reached(@pokemonX, @pokemonDestiny, @pokemonSpeed)
        @pokemonX = @pokemonDestiny
        if @pokemonSpeed>0 # Set thing to move backward
          # SE for hit the bag
          pbSEPlay(Bridge.getAudioName(getHitSEName(@lastScore-MAX_SCORE)))
          if @nextAngle==0 # If there's no bag animation, compute now
            computeScore
          else
            @bagAnimating=true
          end
          @pokemonSpeed/=-2
          @pokemonDestiny=@pokemonX-POKEMON_DISTANCE
          @pokemonWaitTime=@timeCount+WAIT_ANIMATION_TIME-0.001
        else
          @pokemonAnimating=false
        end
      end  
      @sprites["pokemonback"].x = @pokemonX.floor
    end

    # An >= who works with negative steps/speed
    def reached(value, destiny, sign)
      return sign < 0 ? value <= destiny : value >= destiny
    end

    def getHitSEName(lastScoreFromMax)
      return case lastScoreFromMax
        when -1,0;  "Battle damage super"
        when -2;    "Battle damage normal"
        else;       "Battle damage weak"
      end
    end
    
    def pbEndScene
      pbFadeOutAndHide(@sprites) { update }
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
    end
  end

  class Screen
    def initialize(scene)
      @scene=scene
    end

    def pbStartScreen(pokemon,rounds,canCancel)
      @scene.pbStartScene(pokemon,rounds)
      ret=@scene.pbMain(canCancel)
      @scene.pbEndScene
      return ret
    end
  end

  def self.play(param)
    score = nil
    pkmn = nil
    param = Parameters.new(param) if param.is_a?(Numeric)
    pbFadeOutIn(99999){
      loop do
        pkmn = promptChoosePokemon(param)
        break if pkmn || param.canCancel
      end
      if pkmn
        scene=Scene.new
        screen=Screen.new(scene)
        score=screen.pbStartScreen(pkmn,param.rounds,param.canCancel)
      end
    }
    giveReward(pkmn, param) if score && param.minScore <= score
    return score
  end

  def self.promptChoosePokemon(param)
    pbChoosePokemon(1,3,proc{ |pkmn| 
      next (
        !pkmn.egg? &&
        (!param.blockMax || !hasMaxedValue?(pkmn, param)) && 
        (param.acceptFainted || pkmn.hp>0) &&
        (param.minLevel <= pkmn.level)
      )
    })
    return pbGet(1)==-1 ? nil : Bridge.player.party[pbGet(1)]
  end

  def self.hasMaxedValue?(pkmn, param)
    return param.statArray.find{|stat|
      next (
        (param.evGain>0 && canIncreaseEV?(pkmn, stat)) || 
        (param.ivGain>0 && canIncreaseIV?(pkmn, stat)) || 
        (param.maximizeIV && !hasMaxedIV?(pkmn, stat))
      )
    } == nil
  end

  def self.giveReward(pkmn, param)
    for stat in param.statArray
      Bridge.message(_INTL(
        "{1}'s {2} increased.", pkmn.name, Bridge.getStatName(stat)
      )) if raiseEV(pkmn, stat, param.evGain) > 0
      Bridge.message(_INTL(
        "{1}'s {2} increased.", pkmn.name, Bridge.getStatName(stat)
      )) if raiseIV(pkmn, stat, param.ivGain) > 0
      Bridge.message(_INTL(
        "{1}'s {2} is maxed.", pkmn.name, Bridge.getStatName(stat)
      )) if param.maximizeIV && maximizeIV(pkmn, stat)
    end
  end

  def self.raiseEV(pkmn, stat, value)
    return pbJustRaiseEffortValues(pkmn, Bridge.getInternalStat(stat), value)
  end
  
  def self.raiseIV(pkmn, stat, value)
    valueToAdd = [
      Bridge.ivStatLimit - pkmn.iv[Bridge.getInternalStat(stat)], value
    ].min
    pkmn.iv[Bridge.getInternalStat(stat)] += valueToAdd
    return valueToAdd
  end
  
  def self.maximizeIV(pkmn, stat)
    return Bridge.maximizeIV(pkmn, stat)
  end
  
  def self.canIncreaseEV?(pkmn, stat)
    return false if pkmn.ev[Bridge.getInternalStat(stat)] >= Bridge.evStatLimit
    evTotal = 0
    [
      :HP, :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE
    ].each { |s| evTotal += pkmn.ev[Bridge.getInternalStat(s)] }
    return evTotal<Bridge.evLimit
  end
  
  def self.canIncreaseIV?(pkmn, stat)
    return pkmn.iv[Bridge.getInternalStat(stat)] < Bridge.ivStatLimit
  end
  
  def self.hasMaxedIV?(pkmn, stat)
    return Bridge.hasMaxedIV?(pkmn, stat)
  end

  # Essentials multiversion layer
  module Bridge
    if defined?(Essentials)
      MAJOR_VERSION = Essentials::VERSION.split(".")[0].to_i
    elsif defined?(ESSENTIALS_VERSION)
      MAJOR_VERSION = ESSENTIALS_VERSION.split(".")[0].to_i
    elsif defined?(ESSENTIALSVERSION)
      MAJOR_VERSION = ESSENTIALSVERSION.split(".")[0].to_i
    else
      MAJOR_VERSION = 0
    end

    @@audioNameHash = nil

    module_function

    def delta
      return 0.025 if MAJOR_VERSION < 21
      return Graphics.delta
    end

    def player
      return $Trainer if MAJOR_VERSION < 20
      return $player
    end
    
    def message(string, &block)
      return Kernel.pbMessage(string, &block) if MAJOR_VERSION < 20
      return pbMessage(string, &block)
    end
    
    def confirmMessage(string, &block)
      return Kernel.pbConfirmMessage(string, &block) if MAJOR_VERSION < 20
      return pbConfirmMessage(string, &block)
    end

    def setPokemonBottomOffset(sprite, pokemon)
      case MAJOR_VERSION
      when 0..15
        pbPositionPokemonSprite(sprite, sprite.x, sprite.y)
        sprite.x += 8 - sprite.bitmap.width/2 if sprite.bitmap  
        sprite.y = adjustBattleSpriteY(sprite, pokemon.species, 0)  
      when 16..19
        sprite.setOffset(PictureOrigin::Bottom) 
      else
        sprite.setOffset(PictureOrigin::BOTTOM)
      end   
    end

    def getInternalStat(stat)
      return {
        :HP              => PBStats::HP     ,
        :ATTACK          => PBStats::ATTACK ,
        :DEFENSE         => PBStats::DEFENSE,
        :SPEED           => PBStats::SPEED  ,
        :SPECIAL_ATTACK  => PBStats::SPATK  ,
        :SPECIAL_DEFENSE => PBStats::SPDEF  ,
      }.fetch(stat, stat) if MAJOR_VERSION < 19
      return stat
    end

    def getStatName(stat)
      case MAJOR_VERSION
      when 0..15
        return {
          :HP              => "HP",
          :ATTACK          => "Attack" ,
          :DEFENSE         => "Defense",
          :SPEED           => "Speed",
          :SPECIAL_ATTACK  => "Special Attack",
          :SPECIAL_DEFENSE => "Special Defense",
        }[stat]
      when 16..18
        return PBStats.getName(getInternalStat(stat))
      else
        return GameData::Stat.get(stat).name
      end
    end

    def evStatLimit
      return case MAJOR_VERSION
        when 0..15;   252
        when 16..17;  PokeBattle_Pokemon::EVSTATLIMIT
        when 18;      PokeBattle_Pokemon::EV_STAT_LIMIT
        else          Pokemon::EV_STAT_LIMIT
      end
    end
    
    def evLimit
      return case MAJOR_VERSION
        when 0..15;   510
        when 16..17;  PokeBattle_Pokemon::EVLIMIT
        when 18;      PokeBattle_Pokemon::EV_LIMIT
        else          Pokemon::EV_LIMIT
      end
    end
    
    def ivStatLimit
      return case MAJOR_VERSION
        when 0..17; 31
        when 18;    PokeBattle_Pokemon::IV_STAT_LIMIT
        else        Pokemon::IV_STAT_LIMIT
      end
    end

    def maximizeIV(pkmn, stat)
      if MAJOR_VERSION < 18
        return false if pkmn.iv[Bridge.getInternalStat(stat)] == ivStatLimit
        pkmn.iv[Bridge.getInternalStat(stat)] = ivStatLimit
      else
        return false if pkmn.ivMaxed[Bridge.getInternalStat(stat)]
        pkmn.ivMaxed[Bridge.getInternalStat(stat)] = true
      end
      return true
    end
    
    def hasMaxedIV?(pkmn, stat)
      return !PunchBag.canIncreaseIV?(pkmn, stat) if MAJOR_VERSION < 18
      return pkmn.ivMaxed[Bridge.getInternalStat(stat)]
    end

    def getAudioName(baseName)
      if !@@audioNameHash
        if MAJOR_VERSION < 17
          @@audioNameHash = {
            "Battle damage normal" => "normaldamage"  ,
            "Battle damage super"  => "superdamage"   ,
            "Battle damage weak"   => "notverydamage" ,
            "Pkmn move learnt"     => "itemlevel"     ,
          }
        else
          @@audioNameHash = {}
        end
      end
      return @@audioNameHash.fetch(baseName, baseName)  
    end
  end
end