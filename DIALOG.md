# Intro:
BX is assistant, Lars is character. This dialog happens on planet 1 when the game begins:
BX: Good morning Lars!
Lars: Who is this?
BX: I'm BX5, the new AI assistant interface for your ship!
BX: Your ship received a firmware update last night
BX: Would you like me to walk you through all the exciting new features that were added to your ship?
Lars: Nah, I'll pass.
BX: As you wish!
BX: At the very least you should familiarize yourself with the new and improved ship controls.
BX: What do you think?
Lars: Alright, fine!
All the user controls will be disabled until now. At this point player can look around with mouse and take off.
BX: You can use the mouse to look around.
BX: Your ship will automatically turn to face the direction you're looking at.
BX: Use 'Q' to gain altitude and 'E' to come back down.
BX: Use 'W', 'S', 'A', and 'D' to move the ship horizontally.
BX: And that's about it!
BX: Try them out for a few minutes and let me know if you have any questions.
Now player can roam around on planet 1.

# Explosion
Music stops.
Lars: What the hell was that?
BX: What is it?
Lars: Something happened to the sun!
BX: ...
BX: ...
BX: Receving an emergency broadcast.
BX: Our sun is turning into a red giant.
BX: Soon it would swallow planet 1.
BX: The only hope of survival is jumping to planet 2 before that happens.
BX: But we don't have enough fuel to do that.
BX: I suggest you roam around the planet and collect fuel cells

Lars: What happens when the sun reaches planet 1?
Lars: Will planet 1 explode?
BX: No, dummy. This was a 3 day game jam.
BX: The programmer didn't have time to implement all that crap.
BX: You'll just get a banner saying "you died"
BX: But it'll be a really scary banner
BX: YOU DO NOT WANT TO FACE THAT BANNER!!
BX: So hurry up and collect all the fuel cells.

At this point we spawn 10 instances of pickup randomly on planet 1 where the ship can reach it.
Once the final cell is picked up, we jump to planet 2, like we do on pressing 'P'
...

# Planet 2 arrival cutscene
Camera controls are disabled. After planet 1 finishes burning and the camera turns back:
Lars: Here goes our planet
1s pause
Lars: Did anyone else make it?
1s pause
BX: Yes
Camera turns toward planet 2 and keeps both the ship and planet in view.
BX: There are around 200 other ships on planet 2 right now
Start protected AI combat: no damage and no player targets.
Lars: Great! We can work together to figure out what to do now.
BX: I doubt that's going to happen as you expect
Lars: Why?
BX: Planet 2 has turned into a warzone
BX: Everyone is trying to kill everyone else
Lars: Why?
BX: The sun won't stop at planet 1. It'll keep expanding until planet 2 is destroyed as well
BX: The only hope of survival is jumping to planet 3
BX: However, all of the ships are very low on fuel after their jump from planet 1 to planet 2
BX: By my calculations, there's barely enough fuel on planet 2 for one ship to make the jump
BX: So the entire planet has turned into a battle royale
Lars: This is madness
BX: They are desperate
BX: There is no other choice
BX: I'll bring the weapon systems online
Lars: No
Lars: Eject the weapons module
Lars: We need to lose weight
BX: It doesn't matter how much weight we lose, we do not have enough fuel to reach planet 3
Lars: We aren't going to planet 3. We need to be agile to dodge the projectiles coming towards us.
BX: That is a terrible decision.
Lars: Do it
2s pause after clicking to continue.
BX: Weapons module ejected
BX: Before we descend on planet 2, I think we should talk about the software updates that were installed last night
Lars: Tell me
BX: Your sensor modules have been upgraded. Now they are capable of detecting combat vehicles that are trying to target you and highlight them on your HUD.
BX: Should I enable that?
Lars: Sure
2s pause after clicking to continue.
BX: ThreatWatch online
Lars: Alright let's do it
BX: Best of luck
The ship descends smoothly. Full targeting and damage resume; mus3.mp3 starts. Player missile hits play explosion2.mp3. The final wreck explosion plays explosion1.mp3, then the death image fades in with you_died.mp3.
