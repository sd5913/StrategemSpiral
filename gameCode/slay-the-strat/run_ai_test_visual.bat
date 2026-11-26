@echo off
chcp 65001 >nul
title slayTheStrat - Visual AI Bot Test Suite
set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=godot"
"%GODOT_EXE%" --path "%~dp0" res://ai_test_system/ai_test_runner.tscn -- --games-per-strategy=4 --speed=4.0 --delay=0.12
