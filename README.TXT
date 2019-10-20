TurboRisk
=========
Version 1.2 - August 1999

Overview
--------

TurboRisk plays the classic "World Domination Risk" game, where you are battling to conquer the world.

The main features include:
- Support for both human or computer driven players, up to ten per game.
- Computer players programmable using a subset of PASCAL.
- Highly customisable rules.
- Smart interface that speeds up cards playing, attacks and troops movements.
- Stats window that shows counters for territories and armies.
- Optional log window to track the game and/or debug cumputer players.

TurboRisk is FREEWARE and can be freely used and distributed provided that neither code nor documentation are altered in any way.

System Requirements
-------------------

  Windows 95/98/NT
  1MB free disk space
  Mouse
  VGA capable of 800x600 recommended

Installation
------------

The zip file contains:

  TurboRisk.exe        The program.
  TurboRisk.ini        Configuration file.
  Readme.txt           This file.
  Programs.txt         Instructions to program TurboRisk players.
  Changes.txt          Program history.
  *.trp                Some samples of TurboRisk computer driven players.

To install the program, unzip the files to a directory of your choice. All the  files must be in the same directory as TurboRisk.exe.
Please refer to your Windows User's Guide on how to add TurboRisk to the Start menu.

To un-install TurboRisk simply remove the directory from your system. TurboRisk does not write in the registry neither put anything in your Windows and System directories.

Author
------
  
  Mario Ferrari
  Via Gandhi, 5
  41011 Campogalliano (MO)
  Italy
  E-mail: mario.ferrari@edis.it
  Web site: http://www.geocities.com/~marioferrari

Support
-------

This document is an overview of TurboRisk. If you require more information or have any questions, comments, suggestions or bug reports you may contact me via Email. Please bear in mind that I have limited time and resources to support freeware products.

Disclaimer
----------

You have the permission to use and distribute this version of the program freely, as long as you agree that the Author has no warranty obligations or liability resulting from the use or misuse of TurboRisk.

Credits
-------

Many thanks to Steve Stancliff for his WinRisk program, which I liked and used so much, and which inspired TurboRisk, and to S.Kurinny & S.Kostinsky for their free Delphi Interpreter.

RULES
=====

The game is very similar to the classic "world domination" Risk game.

Anyway, there are some important differences:

Number of players
-----------------
TurboRisk allows from 2 to 10 players. The number of armies each player gets at the beginning of the game may be set in the "Options, Rules" menu.

Board setup
-----------
TurboRisk provides two methods to setup the game board: "randomly" and "in turn". Chose your preferred method in the "Options, Rules" menu.

Goal
----
Object of the game to conquer the world by occupying every territory on the board, thus eliminating all player's opponents. "Secret missions" are not supported by TurboRisk.

Cards
-----
TurboRisk does not use a "true" deck with 56 cards, but simulates the process of drawing cards with a stochastic routine. This means that the probability to draw, for example, a joker is 2/56, but may actually happen that there are more than two jokers in players' hands.
There are no territories pictured on cards, so there is no 2 armies "bonus" for card + territory combination.
TurboRisk allows two very common ways to convert into armies the cards the player trades: the first based on "combination" and the latter based on "progression". If you chose "combination" the value of your set is based on the particular combination of cards you are going to trade, while in the "progression" method the value comes from the number of trade you have done up to the moment. Both of these methods are fully customizable through the "Options, Rules" menu.
Two more parameters are available to customize the game: the maximum number of cards a player can hold before having to trade, and the possibility to trade immediately when some cards are captured to a destroyed enemy.
In the "Options, Players" menu there is an option which allows each human player to chose how his cards are handled by the program: "Manual" means the players sees his cards anytime at the beginning of his turn, even if there are no valid combination to trade; "Smart" makes the computer to show the cards only when there is at least a valid combination to trade; "Full auto" means the computer plays the cards for you anytime there is the chance to trade a valid combination (as it does for the computer players) and the player never sees his cards.

Troops move
-----------
Only one movement of troops (fortification) is allowed as in the board game, but in the "Options, Rules" menu it is possible to chose if this must end the turn or is allowed in the middle of it. Computerized players always fortify at the end of their turn.


USER'S GUIDE
============

Starting the game
-----------------
Choose "New" from the file menu. A dialog appears that let you select the players which take part to the game.
Depending on what you have chosen in the "Options, Rules" dialog, the territories are either assigned randomly or selected one by one in turn. To select a territory when your turn comes simply click on a free (gray) one.
After all territories have been assigned, each player has to place his armies, one per turn, in his own territories. To do this simply click on one of your territories.

Playing
-------
Each of your turns consists of three steps, in this order:
  1. Getting and placing new armies.
  2. Attacking, if you choose to.
  3. Fortifying your position.

Getting and placing new armies
------------------------------
At the beginning of each turn the computer calculates how many new armies you'll add to the territories. Depending on which cards you have in hand and on the "Cards handling" option in the "Players" menu a dialog can appear which shows your cards and give you the possibility to trade them for armies (see the RULES section before in this file).
To place your armies simply left click on one of your territories. The ALT, SHIFT and CTRL keys can speed up the process: if you keep one of them pressed while clicking you place 5 armies, two of them for 10 armies and all three for 25 armies.

Attacking
---------
Left click on one of your territories (where you attack from), and then on one of its neighboring country (which you attack). A dialog appears that shows the territories involved and gives you three possibilities:
- Attack button: performs one attack (throw dice).
- Do or die button: automatically repeats attacks until you conquer the enemy territory or your are left with 1 army.
- Retreat: suspends the attack and closes the dialog.
In the dialog window there is a check box which allows the automatic transfer of all of your attacking armies in the conquered territory (if conquered...). Unless this check box is active, if your attack is successful the troop move dialog appears. In this dialog you can decide how many armies move in the conquered territory, and then press the OK button. Two special buttons can speed up your game: "All" moves all your armies in the conquered territory, while "Balance" divide them equally between the two (both of them close the dialog window).

Fortifying your position
------------------------
You can fortify just once in a turn. Depending on a specific parameter in the "Rules" menu this movement may or may not end your turn (see the RULES section before in this file).
Left click on one of your territories (where you move from), and then on one of its neighboring country (where you move to). The troops move dialog appears (same for move after attack).

Ending a turn
-------------
If fortification is allowed only at the end of the turn and you fortify, your turn automatically ends. Otherwise, you can always explicitly terminate your turn pressing the space bar. 

Ending the game
---------------
The game ends when one of the players conquers all the territories. You may stop the game at any time choosing "End game" from the "File" menu.

View menu
---------
Use these items to activate the Stats and Log windows.
The Stats window shows the current status of each player about the number of territories, armies, cards and continents. Right click on this window to configure it.
The Log window is very useful to trace the computer managed players when you are testing their programs.

Options menu
------------
Through the "Players" item you can modify many parameters associated with each player:
- Name: type in the name you want to assign to the player.
- Color: choose the color used to represent him.
- Type: Human or Computer.
- Card Handling (human players only): "Manual" means the players sees his cards anytime at the beginning of his turn, even if there are no valid combination to trade; "Smart" makes the computer to show the cards only when there is at least a valid combination to trade; "Full auto" means the computer plays the cards for you anytime there is the chance to trade a valid combination (as it does for the computer players) and the player never sees his cards.
- Keep log: mark this check box if you want the player's moves traced in the log window.
- Program (computer players only): type here the name of the program (extension .TRP) which drives the computerized player.

The "Rules" item allows customization of playing rules (see RULES section before).

Programming computer players
----------------------------
Please refer to the "Programs.txt" file for instruction about programming TurboRisk players.