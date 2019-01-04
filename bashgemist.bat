@ECHO off
SET PATH=D:\ffmpeg-windows-build-helpers-master\ffmpeg_local_builds\cygwin_local_install\bin;%PATH%
bash.exe -c "./bashgemist.sh %*"
