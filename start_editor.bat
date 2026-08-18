@echo off

cd /d "%~dp0"

start "" http://localhost:8080/assets/index.html

py server.py