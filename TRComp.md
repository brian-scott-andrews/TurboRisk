# TRComp TRP editor and compiler

TRComp is a desktop editor and routine tester for TurboRisk player (`.trp`) scripts. Its layout follows the legacy TRComp guide: a categorized TurboRisk API browser and a live procedure/function list at left, a Pascal editor in the center, and compiler messages at the bottom.

Build it with Lazarus:

```powershell
C:\lazarus\lazbuild.exe .\TRComp.lpi
```

Run `TRComp.exe`, open or write a `.trp` file, and select **Compile**. The results pane displays compiler errors and hints. A successful compile also checks that `ASSIGNMENT`, `PLACEMENT`, `ATTACK`, `OCCUPATION`, and `FORTIFICATION` are present and have the declarations expected by TurboRisk. Double-click an API name to insert it, or double-click a listed procedure/function to jump to its declaration.

Select a procedure/function and choose **Run** to test it. TRComp asks for a test context (players, territory owners and armies, player buffers, card rules, and message text), then prompts for the routine's parameters. Updated `var` parameters, a function return value, and captured `UMessage`, `ULog`, `UDialog`, and snapshot requests appear in the messages pane. Routine execution uses the game's registered API but does not start a full game simulation or write snapshot files.

The editor provides Pascal syntax highlighting, line numbers, undo/redo, and clipboard editing. Double-clicking a compiler message with a source line navigates to that line. TRComp reads and saves `FontSize`, `TabWidth`, and `LineNumbers` from the `[Edit]` section of `TRComp.ini` beside the executable, so the legacy editor settings file can be reused. Window dimensions and pane sizes are saved in the `[Windows]` section. **F1** opens `Doc/TurboRisk.chm` beside the executable.

For legacy player-script migration guidance and numbered territory maps, see
the [TRP conversion reference](Doc/README.md).
