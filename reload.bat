@echo off
set arg0 =%1
odin build game -out:./build/game.dll -debug -build-mode:shared -show-timings
copy NUL > build/building_dll_finished.txt
REM odin build code -out:./build/scripts.dll -debug -build-mode:shared
