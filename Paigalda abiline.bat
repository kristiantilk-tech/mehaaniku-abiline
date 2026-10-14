@echo off
chcp 65001 >nul
setlocal
title Mehaaniku abiline - paigaldus tookoja arvutisse
rem Paigaldab (voi uuendab) abilise kausta %USERPROFILE%\MehaanikuAbiline.
rem Kui selle failiga samas kaustas on versioon.json (nt Google Drive), kasutatakse seda paketti,
rem muidu laetakse programm internetist (GitHub, kruepteeritud pakett - vaja on uuenduste votit).
set "ALLIKAS=%~dp0"
set "ALLIKAS=%ALLIKAS:~0,-1%"
set "SIHT=%USERPROFILE%\MehaanikuAbiline"
set "VEEB=https://raw.githubusercontent.com/kristiantilk-tech/mehaaniku-abiline/main"
set "TMPK=%TEMP%\abiline_paigaldus"
echo.
echo  ===== Mehaaniku abilise paigaldus =====
echo  Paigaldan kausta: %SIHT%
echo.
if exist "%TMPK%" rmdir /s /q "%TMPK%"
mkdir "%TMPK%"

rem --- 1) pakett: kohalik (Drive) voi internetist ---
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
  "if (Test-Path (Join-Path $env:ALLIKAS 'versioon.json')) { $m = Get-Content -Raw -Encoding UTF8 (Join-Path $env:ALLIKAS 'versioon.json') | ConvertFrom-Json; Copy-Item (Join-Path $env:ALLIKAS $m.fail) (Join-Path $env:TMPK $m.fail); Write-Host '  Allikas: see kaust' }" ^
  "else { $m = Invoke-RestMethod -UseBasicParsing ($env:VEEB + '/versioon.json'); Invoke-WebRequest -UseBasicParsing ($env:VEEB + '/' + $m.fail) -OutFile (Join-Path $env:TMPK $m.fail); if ($m.krupteeritud) { Invoke-WebRequest -UseBasicParsing ($env:VEEB + '/dekrupteeri.py') -OutFile (Join-Path $env:TMPK 'dekrupteeri.py') }; Write-Host '  Allikas: internet (GitHub)' }" ^
  "$f = Join-Path $env:TMPK $m.fail; if ($m.sha256 -and ((Get-FileHash $f -Algorithm SHA256).Hash.ToLower() -ne $m.sha256)) { throw 'Fail on vigane, proovi uuesti.' }" ^
  "if ($f.EndsWith('.krp')) { Move-Item $f (Join-Path $env:TMPK 'pakett.krp') } else { Move-Item $f (Join-Path $env:TMPK 'pakett.zip') };" ^
  "Set-Content -Encoding ASCII (Join-Path $env:TMPK 'versioon.txt') $m.versioon"
if errorlevel 1 goto viga

rem --- 2) kruepteeritud pakett: vaja Pythonit ja uuenduste votit ---
set "VOTI="
if exist "%SIHT%\uuendusvoti.txt" set /p VOTI=<"%SIHT%\uuendusvoti.txt"
if not defined VOTI if exist "%ALLIKAS%\uuendusvoti.txt" set /p VOTI=<"%ALLIKAS%\uuendusvoti.txt"
if not exist "%TMPK%\pakett.krp" goto paki_lahti
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY ( where python >nul 2>nul && python -c "import sys" >nul 2>nul && set "PY=python" )
if not defined PY goto paigalda_python
if not defined VOTI (
  echo  Sisesta uuenduste voti ^(64 margi pikkune, on sinu arvutis failis MehaanikuAbiline\uuendusvoti.txt^):
  set /p VOTI=  Voti: 
)
if not defined VOTI goto viga
%PY% "%TMPK%\dekrupteeri.py" dekrupteeri "%TMPK%\pakett.krp" "%TMPK%\pakett.zip" %VOTI%
if errorlevel 1 (
  echo  Vale voti voi rikutud fail.
  goto viga
)

:paki_lahti
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Expand-Archive -Path (Join-Path $env:TMPK 'pakett.zip') -DestinationPath (Join-Path $env:TMPK 'x') -Force;" ^
  "New-Item -ItemType Directory -Force $env:SIHT | Out-Null;" ^
  "Copy-Item (Join-Path $env:TMPK 'x\MehaanikuAbiline\*') $env:SIHT -Recurse -Force;" ^
  "Write-Host ('  Versioon ' + (Get-Content (Join-Path $env:TMPK 'versioon.txt')) + ' kopeeritud.')"
if errorlevel 1 goto viga
if defined VOTI if not exist "%SIHT%\uuendusvoti.txt" (echo %VOTI%)>"%SIHT%\uuendusvoti.txt"
rmdir /s /q "%TMPK%" 2>nul
echo.
if exist "%SIHT%\seaded.env" (
  echo  Seaded on juba olemas - jaavad alles. Kusimustele vajuta lihtsalt Enter.
) else (
  echo  Kui sul on seaded.env fail valmis ^(nt maluepulgal oma arvutist^), kopeeri see nuud
  echo  kausta %SIHT% ja vasta jargmistes kusimustes lihtsalt Enter.
)
echo.
pause
call "%SIHT%\install.bat"
echo.
choice /C JE /M "Kas kaivitada abiline automaatselt, kui arvuti sisse lulitatakse"
if errorlevel 2 goto lopp
call "%SIHT%\automaatne_kaivitus.bat"
:lopp
echo.
echo  Valmis! Toolaual on otsetee "Mehaaniku abiline". Edaspidi uueneb abiline ise.
pause
exit /b 0

:paigalda_python
echo  Pythonit ei leitud. Paigaldan Python 3.12...
winget install -e --id Python.Python.3.12 --scope user --accept-source-agreements --accept-package-agreements
echo.
echo  SULGE see aken ja kaivita "Paigalda abiline.bat" UUESTI.
pause
exit /b 0

:viga
echo.
echo  Paigaldus ebaonnestus. Kontrolli internetiuhendust ja proovi uuesti.
pause
exit /b 1
