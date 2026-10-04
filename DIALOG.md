# Intro:
BX is assistant, Lars is character. This dialog happens on planet 1 when the game begins:
BX: Good morning, Lars!
Lars: Who is this?
BX: I am BX5, your ship's new AI assistant interface.
BX: Your ship received a firmware update last night.
BX: Would you like an overview of all the exciting new features added to your ship?
Lars: Nah, I'll pass.
BX: As you wish.
BX: At the very least, you should familiarize yourself with the new and improved ship controls.
BX: What do you think?
Lars: All right, fine.
All the user controls will be disabled until now. At this point player can look around with mouse and take off.
BX: You can use the mouse to look around.
BX: Your ship will automatically turn to face the direction in which you're looking.
BX: Use 'Q' to gain altitude and 'E' to come back down.
BX: Use 'W', 'S', 'A', and 'D' to move horizontally.
BX: That covers the basics.
BX: Try them out for a few minutes and let me know if you have any questions.
Now player can roam around on planet 1.

# Explosion
Music stops.
Lars: What the hell was that?
BX: What is it?
Lars: Something happened to the sun!
BX: ...
BX: ...
BX: Receiving an emergency broadcast.
BX: Our sun is turning into a red giant.
BX: It will soon swallow planet 1.
BX: Our only hope of survival is to reach planet 2 before that happens.
BX: But we don't have enough fuel to do that.
BX: I recommend searching the planet for fuel cells.

Lars: What happens when the sun reaches planet 1?
Lars: Will planet 1 explode?
BX: No, dummy. This was a three-day game jam.
BX: The programmer didn't have time to implement all that crap.
BX: You'll just get a banner that says, "you died".
BX: However, it will be a truly terrifying banner.
BX: YOU DO NOT WANT TO FACE THAT BANNER!
BX: So please hurry and collect all the fuel cells.

At this point we spawn 10 instances of pickup randomly on planet 1 where the ship can reach it.
Once the final cell is picked up, we jump to planet 2, like we do on pressing 'P'
...

# Planet 2 arrival cutscene
Camera controls are disabled. After planet 1 finishes burning and the camera turns back:
Lars: There goes our planet.
1s pause
Lars: Did anyone else make it?
1s pause
BX: Yes.
Camera turns toward planet 2 and keeps both the ship and planet in view.
BX: Approximately 200 other ships are currently on planet 2.
Start protected AI combat: no damage and no player targets.
Lars: Great! We can work together and figure out what to do.
BX: I doubt it will work out as you expect.
Lars: Why?
BX: Planet 2 has become a war zone.
BX: Every ship is trying to kill every other ship.
Lars: Why?
BX: The sun will not stop at planet 1. It will continue expanding until it destroys planet 2 as well.
BX: Our only hope of survival is to reach planet 3.
BX: However, all the ships are running low on fuel after the jump from planet 1 to planet 2.
BX: By my calculations, there is barely enough fuel on planet 2 for one ship to make the jump.
BX: As a result, the entire planet has become a battle royale.
Lars: This is madness.
BX: They are desperate.
BX: There is no other choice.
BX: I will bring the weapons systems online.
Lars: No.
Lars: Eject the weapons module.
Lars: We need to shed some weight.
BX: It does not matter how much weight we lose; we still do not have enough fuel to reach planet 3.
Lars: We're not going to planet 3. We need to be agile enough to dodge the incoming projectiles.
BX: That is a terrible decision.
Lars: Do it.
2s pause after clicking to continue.
BX: Weapons module ejected.
BX: Before we descend to planet 2, we should discuss the software updates installed last night.
Lars: Go on.
BX: Your sensor modules have been upgraded. They can now detect combat vehicles targeting you and highlight them on your HUD.
BX: Should I enable that?
Lars: Sure.
2s pause after clicking to continue.
BX: ThreatWatch online.
Lars: All right, let's do it.
BX: Best of luck.
The ship descends smoothly. Full targeting and damage resume; mus3.ogg starts. Player missile hits play explosion2.mp3. The final wreck explosion plays explosion1.mp3, then the death image fades in with you_died.mp3.
