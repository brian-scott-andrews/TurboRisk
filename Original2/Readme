TurboRisk notes for the developers
==================================

Comments in sparse order
------------------------

- In view of making the project open source, years ago I started translating the comments and the variable names 
from Italian into English. Unfortunately I never finished this job. With modern refactoring tools changing names
to the variables should be easy, fast and safe.
As for the comments... whenever you find a comment you don't understand and are not able to translate with online 
translators, just ask.

- The procedure Supervisor (unit Globals.pas) manages the turns and the phases of the games. 
The way the events manager of the Main window and the Supervisor pass each other the control of the application 
is a bit tricky :-)

- TR is made of many units and the source code is not trivial- though I think is well structured and commented. 

- To understand how TR handles the maps, read the topic "Making custom maps -> Creating the bitmaps -> Colors". 
To make the application multi-plataform we might need to change this architecture.

List of the units in the project
--------------------------------

About.pas	          The About window
Attack.pas	        The Attack window
Cards.pas	          The Cards turn in window
CheckUpd.pas	      Unit to check online updates
Computer.pas	      Handles the turn of TRPs
ExpSubr.pas	        Procedure and function used by the TRPs (API)
Globals.pas	        Subroutines of general use
History.pas	        The History window
Human.pas	          Handles the turn of a human player
Log.pas	            The Log window
Main.pas	          The Main window
Map.pas	            The Map choice window
Move.pas	          The Troops Move window
NewGame.pas	        The New Game window
Players.pas	        The Player's property window
Pref.pas	          The Preference window
Programs.pas	      The TRP choice window
Readme.pas	        The Readme window
Rules.pas	          The Rules customization window
Sim.pas	            *** part of the TRSim simulator
SimCPULog.pas	      *** part of the TRSim simulator
SimGameLog.pas      *** part of the TRSim simulator, ignore this unit
SimMap.pas	        *** part of the TRSim simulator, ignore this unit
SimRun.pas	        *** part of the TRSim simulator, ignore this unit
SplashScreen.pas    The initial splash screen
Stats.pas	          The Stats window
Territ.pas	        Routines to handle territories
TRPError.pas	      The TRP error reporting window
UDialog.pas	        The dialog window invoked by the API function UDialog

Planned/requested changes
-------------------------

- I planned to move the code from Delphi to Lazarus/Free Pascal, because the second is free, open source 
and multi-platform (Win, OSX, Linux and more). Not yet approached, but shouldn't be too difficult.

- I also planned to convert maps to vector graphics to make them scalable, thus more suitable for mobile devices.

- Most requested feature is multi-player.
