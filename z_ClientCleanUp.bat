@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo  CleanUp Modes
echo  {normal}                 : 프로젝트 빌드/캐시/OS별·플러그인 생성물 삭제
echo   --deep                  : {normal} + 전역 캐시(%USERPROFILE%\.pub-cache, %USERPROFILE%\.gradle) 삭제
echo   --wipe-local-properties : android\local.properties 삭제
echo ===============================================
echo.

REM 기본 옵션
set "DEEP=false"
set "WIPE_LOCAL_PROPERTIES=false"

REM 옵션 파싱
:parse_args
if "%~1"=="" goto args_done
if "%~1"=="--deep" set "DEEP=true"
if "%~1"=="--wipe-local-properties" set "WIPE_LOCAL_PROPERTIES=true"
shift
goto parse_args
:args_done

echo 🔧 Clean Up Start (deep=%DEEP%, wipe_local_properties=%WIPE_LOCAL_PROPERTIES%)

REM ---- 함수형 흉내: 안전 삭제 ----
:rm_safe
if exist "%~1" (
    rmdir /s /q "%~1" 2>nul || del /f /q "%~1" 2>nul
    echo   🗑  removed: %~1
)
goto :eof

REM ---- Flutter/Project 캐시 ----
call :rm_safe build
call :rm_safe .dart_tool
call :rm_safe .packages
call :rm_safe pubspec.lock

REM ---- iOS/macOS ----
call :rm_safe ios\Pods
call :rm_safe ios\Flutter\App.framework
call :rm_safe ios\Flutter\Flutter.framework
call :rm_safe ios\DerivedData
call :rm_safe ios\.symlinks
call :rm_safe ios\Podfile.lock
call :rm_safe macos\Pods
call :rm_safe macos\Flutter\FlutterMacOS.framework
call :rm_safe macos\Podfile.lock

REM ---- Android ----
call :rm_safe android\.gradle
call :rm_safe android\app\build
if "%WIPE_LOCAL_PROPERTIES%"=="true" (
    call :rm_safe android\local.properties
) else (
    if exist android\local.properties (
        echo   🔒 kept: android\local.properties (SDK 경로/키 보존)
    )
)
call :rm_safe android\.idea

REM ---- Web ----
call :rm_safe web\.dart_tool
call :rm_safe web\.generated
call :rm_safe web\generated

REM ---- Linux ----
call :rm_safe linux\flutter\ephemeral
call :rm_safe linux\.generated
call :rm_safe linux\generated

REM ---- Windows ----
call :rm_safe windows\flutter\ephemeral
call :rm_safe windows\.generated
call :rm_safe windows\generated

REM ---- Firebase Functions ----
call :rm_safe firebase\functions\node_modules

REM ---- 플러그인/패키지 생성물 (화이트리스트) ----
call :rm_safe .generated
call :rm_safe generated
call :rm_safe ios\.generated
call :rm_safe android\.generated
call :rm_safe macos\.generated
call :rm_safe linux\.generated
call :rm_safe windows\.generated
call :rm_safe web\.generated

REM ---- 전역 캐시 (--deep) ----
if "%DEEP%"=="true" (
    call :rm_safe "%USERPROFILE%\.pub-cache"
    call :rm_safe "%USERPROFILE%\.gradle"
    call :rm_safe android\.gradle
)

REM ---- flutter clean ----
where flutter >nul 2>nul
if %ERRORLEVEL%==0 (
    echo 🚿 flutter clean …
    flutter clean
    echo   ✅ flutter clean done
) else (
    echo   ⚠️  flutter 명령을 찾지 못해 flutter clean 생략
)

echo ✅ Clean Up Completed (deep=%DEEP%, wipe_local_properties=%WIPE_LOCAL_PROPERTIES%)
endlocal

