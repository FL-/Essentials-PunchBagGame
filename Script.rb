#===============================================================================
# * Punch Bag Game - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. The player select a pokémon for a 
# simple minigame where the player get points the most near the center the
# cursor was when the button was pressed.
#
#===============================================================================
#
# To this script works, put it above main, put a 512x288 background for this
# screen in "Graphics/Pictures/punchBagField" location, a 104x256 punchbag at 
# "Graphics/Pictures/punchBag", a 262x20 bar at "Graphics/Pictures/punchBagBar",
# a 48x40 star for display points at "Graphics/Pictures/punchBagStar". May
# works with other image sizes.
#  
# To call this script, use the script command 'pbPunchBag(X, Y, Z)' where X
# is the number of hits, Y is a true/false if the player can cancel the pokémon
# selection (default is true) and Z is a true/false if only unfainted pokémon
# is allowed (default is true). This method will return the player score.
#
#===============================================================================

class PunchBagScene
  # Size of the valid bar points between the left and the center
  BARLEFTSIZE = 128 
  ARROWSPEED = 16
  MAXSCORE = 5
  MINSCORE = 1
    
  BAGSPEEDARRAY=[2,4,8]
  BAGANGLESARRAY=[0,16,32,64]
  POKEMONSPEED=16
  POKEMONDISTANCE=64
  WAITANIMATIONFRAME=8
  
  def update
    pbUpdateSpriteHash(@sprites)
  end
  
  def pbStartScene(pkmn,rounds)
    @sprites={} 
    @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z=99999
    @sprites["field"]=IconSprite.new(0,0,@viewport)
    @sprites["field"].setBitmap("Graphics/Pictures/punchBagField")
    @sprites["field"].y=-48
    # An extra background. Used because the first one haven't the screen size, 
    # so a small part can be seen below window.
    @sprites["fieldBack"]=IconSprite.new(0,0,@viewport)
    @sprites["fieldBack"].setBitmap("Graphics/Pictures/punchBagField")
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
    @sprites["punchbag"].setBitmap("Graphics/Pictures/punchBag")
    @sprites["punchbag"].x=Graphics.width/2
    # The bag center is the rope
    @sprites["punchbag"].ox=@sprites["punchbag"].bitmap.width/2 
    @sprites["punchbag"].y=-38
    @sprites["pokemonback"]=PokemonSprite.new(@viewport)
    @sprites["pokemonback"].setPokemonBitmap(pkmn,true) 
    @sprites["pokemonback"].setOffset(PictureOrigin::Bottom)    
    @sprites["pokemonback"].x+= @sprites["punchbag"].x-56-POKEMONDISTANCE
    @sprites["pokemonback"].y+= 228
    @sprites["pokemonback"].z=1
    @sprites["bar"]=IconSprite.new(0,0,@viewport)
    @sprites["bar"].setBitmap("Graphics/Pictures/punchBagBar")
    @sprites["bar"].x=@sprites["barbox"].x+(
        @sprites["barbox"].width-@sprites["bar"].bitmap.width)/2
    @sprites["bar"].y=@sprites["barbox"].y+44
    arrow=AnimatedBitmap.new("Graphics/Pictures/Arrow")
    @sprites["bar"].z=3
    @sprites["arrow"]=BitmapSprite.new(
        arrow.bitmap.width/2,arrow.bitmap.height/2,@viewport)
    @sprites["arrow"].bitmap.blt(0,0,arrow.bitmap,Rect.new(
        0,@sprites["arrow"].bitmap.height,@sprites["arrow"].bitmap.width,
        @sprites["arrow"].bitmap.height))
    @sprites["arrow"].z=3
    @arrowXMiddle = (@sprites["bar"].x-@sprites["arrow"].bitmap.width/2+
        4+BARLEFTSIZE)
    @sprites["arrow"].x = @arrowXMiddle-BARLEFTSIZE
    @sprites["arrow"].y = @sprites["bar"].y-28
    for i in 0...5
      @sprites["star#{i}"]=IconSprite.new(0,0,@viewport)
      @sprites["star#{i}"].setBitmap("Graphics/Pictures/punchBagStar")
      @sprites["star#{i}"].x=32+(@sprites["star#{i}"].bitmap.width+52)*i
      @sprites["star#{i}"].y=@sprites["starbox"].y+12
      @sprites["star#{i}"].z=3
    end
    @rounds = rounds
    pbMakeAllStarsInvisible
    @sprites["overlay"]=BitmapSprite.new(
        Graphics.width,Graphics.height,@viewport)
    @moving=true
    @right=false
    @score = 0
    @lastScore = 0
    @shoots = 0
    @endGame=false
    @nextAngle=0
    @bagAnimating=false
    @bagWaitFrame=0
    @pokemonAnimating=false
    @pokemonWaitFrame=0
    @animating=false
    pbSetSystemFont(@sprites["overlay"].bitmap)
    pbDrawText
    pbFadeInAndShow(@sprites) { update }
  end

  def pbDrawText
    @sprites["scorebox"].text=_INTL("Score: {1} \nHits: {2}/{3}",
        @score,@shoots,@rounds)
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

  def pbMain
    @frameCount=-1
    loop do
      Graphics.update
      Input.update
      self.update
      @frameCount+=1
      if @endGame
        return @score if !@animating
      else  
        if Input.trigger?(Input::B) && $DEBUG
          pbPlayCursorSE
          break
        end
        arrowX = @sprites["arrow"].x
        if Input.trigger?(Input::C) && @lastScore==0
          @lastScore = BARLEFTSIZE-(arrowX>@arrowXMiddle ? 
              arrowX-@arrowXMiddle : @arrowXMiddle-arrowX)
          @lastScore=[(@lastScore-BARLEFTSIZE)/ARROWSPEED+MAXSCORE,MINSCORE].max
          @sprites["arrow"].visible = false
        end
        if @moving
          if arrowX==@arrowXMiddle-BARLEFTSIZE || 
              arrowX==@arrowXMiddle+BARLEFTSIZE
            @right = !@right
          end
          @sprites["arrow"].x+= @right ? ARROWSPEED : -ARROWSPEED
        end
      end
      updateAnimation
    end
    return nil
  end
  
  def computeScore
    # Computes the score at a certain point at the animation.
    # When the bag stops at air for the first time at that punch
    @shoots+=1
    @endGame = true if @shoots==@rounds
    @score+=@lastScore
    pbSEPlay("Pkmn move learnt") if @lastScore==MAXSCORE
    pbDrawText
    pbDrawStars(@lastScore)
    @lastScore = 0
    @scoreComputed = true
    @sprites["arrow"].visible = true
  end  
  
  def setAnimation
    lastScoreFromMax = @lastScore-MAXSCORE
    @nextAngle = case lastScoreFromMax
    when 0;  BAGANGLESARRAY[3] # Perfect hit
    when -1; BAGANGLESARRAY[2]
    when -2; BAGANGLESARRAY[1]
    else;    BAGANGLESARRAY[0]
    end
    lastScoreFromMax==0 ? 64 : 32
    @bagSpeedIndex = lastScoreFromMax==0 ? 2 : 0
    @pokemonAnimating=true
    @pokemonSpeed=POKEMONSPEED
    @pokemonDestiny=@sprites["pokemonback"].x+POKEMONDISTANCE
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
    return if @bagWaitFrame>@frameCount
    angle=@sprites["punchbag"].angle
    if(angle==@nextAngle)
      if(@nextAngle==0)
        if @bagSpeedIndex>0 # Max Score
          @nextAngle=-BAGANGLESARRAY[-2]
        else
          @bagAnimating=false
        end  
      else  
        if (@nextAngle<0) # Reverse direction
          @nextAngle=BAGANGLESARRAY[-3]
        else
          @nextAngle=0
        end
        @bagWaitFrame=@frameCount+WAITANIMATIONFRAME
        computeScore if !@scoreComputed 
      end  
    else
      # Cut the speed to half every time that bag reach at middle
      @bagSpeedIndex-=1 if angle==0 && @bagSpeedIndex!=0 
      speed=BAGSPEEDARRAY[@bagSpeedIndex]
      direction = @nextAngle>angle ? 1 : -1
      @sprites["punchbag"].angle+=speed*direction
    end
  end  
  
  def updateAnimationPokemon
    return if @pokemonWaitFrame>@frameCount
    @sprites["pokemonback"].x+=@pokemonSpeed
    if @sprites["pokemonback"].x==@pokemonDestiny
      if @pokemonSpeed>0 # Set thing to move backward
        lastScoreFromMax = @lastScore-MAXSCORE
        # SE for hit the bag
        case lastScoreFromMax
          when -1,0;  pbSEPlay("Battle damage super")
          when -2;    pbSEPlay("Battle damage normal")
          else;       pbSEPlay("Battle damage weak")
        end
        if @nextAngle==0 # If there's no bag animation, compute now
          computeScore
        else
          @bagAnimating=true
        end
        @pokemonSpeed/=-2
        @pokemonDestiny=@sprites["pokemonback"].x-POKEMONDISTANCE
        @pokemonWaitFrame=@frameCount+WAITANIMATIONFRAME
      else
        @pokemonAnimating=false
      end
    end  
  end  
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

class PunchBagScreen
  def initialize(scene)
    @scene=scene
  end

  def pbStartScreen(pokemon,rounds)
    @scene.pbStartScene(pokemon,rounds)
    ret=@scene.pbMain
    @scene.pbEndScene
    return ret
  end
end

def pbPunchBag(rounds, canCancel=true, onlyAblePokemon=true)
  ret = nil
  pbFadeOutIn(99999){
    pokemonSelected = nil
    loop do
      onlyAblePokemon ? pbChooseAblePokemon(1,3) : pbChooseNonEggPokemon(1,3)
      pokemonSelected = $Trainer.party[pbGet(1)] if pbGet(1)!=-1
      break if pokemonSelected || canCancel
    end
    if pokemonSelected
        scene=PunchBagScene.new
        screen=PunchBagScreen.new(scene)
        ret=screen.pbStartScreen(pokemonSelected,rounds)
    end
  }
  return ret
end