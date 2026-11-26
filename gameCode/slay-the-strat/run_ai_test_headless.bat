@echo off
chcp 65001 >nul
title slayTheStrat - Headless AI Bot Test Suite
set "GODOT_CONSOLE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_CONSOLE%" set "GODOT_CONSOLE=godot"
"%GODOT_CONSOLE%" --headless --path "%~dp0" res://ai_test_system/ai_test_runner.tscn -- --games-per-strategy=10 --speed=8.0 --auto-quit
echo.
echo Reports exported to: %~dp0ai_test_system\reports\
pause
