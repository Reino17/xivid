@GOTO :start
:: --------------------------------
:: Xivid batch script
:: --------------------------------
::
:: Copyright (C) 2020 Reino Wijnsma
::
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.
::
:: This program is distributed in the hope that it will be useful,
:: but WITHOUT ANY WARRANTY; without even the implied warranty of
:: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
:: GNU General Public License for more details.
::
:: You should have received a copy of the GNU General Public License
:: along with this program.  If not, see <http://www.gnu.org/licenses/>.
::
:: Reino Wijnsma (rwijnsma@xs4all.nl)
:: https://github.com/Reino17/xivid

:help
ECHO Xivid, een video-url extractie script.
ECHO Gebruik: xivid.bat [optie] url
ECHO.
ECHO   -f ID[+ID]    Selecteer specifiek formaat, of specifieke formaten.
ECHO                 Met een ID dat eindigt op een '#' wordt het formaat
ECHO                 met het hoogste nummer geselecteerd.
ECHO                 Zonder opgave wordt het formaat met de hoogste
ECHO                 resolutie en/of bitrate geselecteerd.
ECHO   -i            Toon video informatie, incl. een opsomming van alle
ECHO                 beschikbare formaten.
ECHO   -j            Toon video informatie als JSON.
ECHO.
ECHO Ondersteunde websites:
ECHO   npostart.nl             omropfryslan.nl       omroepwest.nl
ECHO   gemi.st                 rtvnoord.nl           rijnmond.nl
ECHO   nos.nl                  rtvdrenthe.nl         rtvutrecht.nl
ECHO   tvblik.nl               nhnieuws.nl           omroepgelderland.nl
ECHO   uitzendinggemist.net    at5.nl                omroepzeeland.nl
ECHO   rtlxl.nl                omroepflevoland.nl    omroepbrabant.nl
ECHO   kijk.nl                 rtvoost.nl            l1.nl
ECHO.
ECHO   dumpert.nl              vimeo.com             twitter.com
ECHO   autojunk.nl             dailymotion.com       pornhub.com
ECHO   telegraaf.nl            twitch.tv
ECHO   ad.nl                   mixcloud.com
ECHO   lc.nl                   soundcloud.com
ECHO   youtube.com             facebook.com
ECHO   youtu.be                fb.watch
ECHO.
ECHO Voorbeelden:
ECHO   xivid.bat https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
ECHO   xivid.bat -i https://www.rtlxl.nl/programma/rtl-nieuws/bf475894-02ce-3724-9a6f-91de543b8a4c
ECHO   xivid.bat -f hls-#+sub-1 https://kijk.nl/video/AgvoU4AJTpy
EXIT /B

:nos
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  let $a:^=json^(
    //script[ends-with^(@data-ssr-name^,'VideoPlayer'^) or @data-ssr-name^='pages/Article/Article']
  ^)/^(.//video^,.^)[1] return
  json:^=if ^(//video/@data-type^='livestream'^) then {
    'name':concat^(
      'NOS: '^,
      //h1[ends-with^(@class^,'__title'^)]^,
      ' Livestream'
    ^)^,
    'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
    'formats':xivid:m3u8-to-json^(//@data-stream^)
  } else {
    'name':'NOS: '^|^|$a/title^,
    'date':format-date^(
      dateTime^(
        replace^(
          ^($a/published_at^,//@datetime^)[1]^,
          '^(.+^)^(\d{2}^)'^,
          '$1:$2'
        ^)
      ^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':$a/duration * duration^('PT1S'^) + time^('00:00:00'^)^,
    'formats':xivid:m3u8-to-json^($a/^(formats^)^(1^)/url/mp4^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:twitch
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  declare variable $id:^=extract^($url^,'.+/^(.+^)'^,1^)^;
  declare variable $cid:^='kimne78kx3ncx6brgo4mv6wki5h1ko'^;
  json:^=if ^($id castable as integer^) then
    let $a:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':'https://api.twitch.tv/kraken/videos/'^|^|$id
        }^)/json^,
        $b:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':concat^('http://api.twitch.tv/api/vods/'^,$id^,'/access_token'^)
        }^)/json
    return {
      'name':'Twitch: '^|^|$a/title^,
      'date':format-date^(
        dateTime^($a/published_at^)^,
        '[D01]-[M01]-[Y]'
      ^)^,
      'duration':format-time^(
        $a/length * duration^('PT1S'^)^,
        '[H01]:[m01]:[s01]'
      ^)^,
      'formats':xivid:m3u8-to-json^(
        concat^(
          'https://usher.ttvnw.net/vod/'^,
          $id^,
          '.m3u8?allow_source^=true^&amp^;allow_audio_only^=true^&amp^;allow_spectre^=true^&amp^;player^=twitchweb^&amp^;sig^='^,
          $b/sig^,
          '^&amp^;token^='^,
          uri-encode^($b/token^)
        ^)
      ^)
    }
  else
    let $a:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':concat^('http://api.twitch.tv/kraken/streams/'^,$id^,'?stream_type^=all'^)
        }^)/json^,
        $b:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':concat^('http://api.twitch.tv/api/channels/'^,$id^,'/access_token'^)
        }^)/json
    return {
      'name':'Twitch: '^|^|$a//status^,
      'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
      'formats':xivid:m3u8-to-json^(
        concat^(
          'https://usher.ttvnw.net/api/channel/hls/'^,
          $id^,
          '.m3u8?allow_source^=true^&amp^;allow_audio_only^=true^&amp^;allow_spectre^=true^&amp^;p^='^,
          random-seed^(^)^,
          random^(1000000^)^,
          '^&amp^;player^=twitchweb^&amp^;segment_preference^=4^&amp^;sig^='^,
          $b/sig^,
          '^&amp^;token^='^,
          uri-encode^($b/token^)
        ^)
      ^)
    }
^" --output-format^=cmd') DO %%A
EXIT /B

:twitter
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  declare variable $head:^='Authorization: Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%%2F40K4moUkGsoc%%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw'^;
  let $a:^=x:request^({
        'method':'POST'^,
        'headers':$head^,
        'url':'https://api.twitter.com/1.1/guest/activate.json'
      }^)/json/guest_token^,
      $b:^=x:request^({
        'headers':^($head^,'x-guest-token: '^|^|$a^)^,
        'url':'https://api.twitter.com/1.1/'^|^|^(
          if ^(//@data-supports-broadcast-player^) then
            concat^('broadcasts/show.json?ids^='^,extract^(//@data-expanded-url^,'.+/^(.+^)'^,1^)^)
          else
            concat^('videos/tweet/config/'^,//@data-associated-tweet-id^,'.json'^)
        ^)
      }^)/json
  return
  json:^={
    'name'://title^,
    'date':format-date^(
      //div[@class^='permalink-header']//@data-time * duration^('PT1S'^) +
      implicit-timezone^(^) + date^('1970-01-01'^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':format-time^(
      round^(^($b//durationMs^,$b//end_ms - $b//start_ms^) div 1000^) * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':array{
      if ^($b/broadcasts^) then
        {
          'id':'hls-1'^,
          'format':'m3u8[h264+aac]'^,
          'resolution':concat^($b//width^,'x'^,$b//height^)^,
          'url':x:request^({
            'headers':^($head^,'x-guest-token: '^|^|$a^)^,
            'url':'https://api.twitter.com/1.1/live_video_stream/status/'^|^|$b//media_key
          }^)//location
        }
      else
        xivid:m3u8-to-json^($b//playbackUrl^)
    }
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:start
@ECHO off
SETLOCAL DISABLEDELAYEDEXPANSION
SET "PATH=%PATH%;%~dp0"
FOR %%A IN (xidel.exe) DO IF EXIST "%%~$PATH:A" (
  FOR /F "delims=" %%B IN ('xidel --version ^| xidel - -se "extract($raw,'\d{8}')"') DO (
    IF %%B GEQ 20200726 (
      SET "XIDEL_OPTIONS=--silent --module=%~dp0xivid.xqm"
    ) ELSE (
      ECHO xivid: '%%~$PATH:A' gevonden, maar versie is te oud.
      ECHO Installeer Xidel 0.9.9.7433 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
      ECHO Ga naar http://videlibri.sourceforge.net/xidel.html.
      EXIT /B 1
    )
  )
) ELSE (
  ECHO xivid: 'xidel.exe' niet gevonden!
  ECHO Installeer Xidel 0.9.9.7433 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
  ECHO Ga naar http://videlibri.sourceforge.net/xidel.html.
  EXIT /B 1
)

:options
SET "prm1=%~1"
IF NOT "%~1"=="" (
  IF "%~1"=="-h" (
    CALL :help
    EXIT /B 0
  ) ELSE IF "%~1"=="-f" (
    IF NOT "%~3"=="" (
      IF NOT "%~2"=="" (
        SET "f=%~2"
        SHIFT /2
      ) ELSE (
        ECHO xivid: formaat id ontbreekt.
        EXIT /B 1
      )
    ) ELSE IF NOT "%~2"=="" (
      FOR /F "delims=" %%A IN ('xidel -e "matches('%~2','^https?://[-A-Za-z0-9\+&@#/%%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%%=~_|]$')"') DO (
        IF "%%A"=="true" (
          ECHO xivid: formaat id ontbreekt.
          EXIT /B 1
        ) ELSE (
          ECHO xivid: url ontbreekt.
          EXIT /B 1
        )
      )
    ) ELSE (
      ECHO xivid: formaat id en url ontbreken.
      EXIT /B 1
    )
  ) ELSE IF "%~1"=="-i" (
    IF NOT "%~2"=="" (
      SET i=1
    ) ELSE (
      ECHO xivid: url ontbreekt.
      EXIT /B 1
    )
  ) ELSE IF "%~1"=="-j" (
    IF NOT "%~2"=="" (
      SET j=1
    ) ELSE (
      ECHO xivid: url ontbreekt.
      EXIT /B 1
    )
  ) ELSE IF "%prm1:~0,1%"=="-" (
    ECHO xivid: optie '%~1' ongeldig.
    EXIT /B 1
  ) ELSE (
    FOR /F "delims=" %%A IN ('xidel -e "matches('%~1','^https?://[-A-Za-z0-9\+&@#/%%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%%=~_|]$')"') DO (
      IF "%%A"=="true" (
        SET "url=%~1"
      ) ELSE (
        ECHO xivid: url ongeldig.
        EXIT /B 1
      )
    )
  )
  SHIFT
  GOTO :options
) ELSE IF NOT DEFINED url (
  ECHO xivid: url ontbreekt.
  ECHO Typ -h voor een lijst met alle opties.
  EXIT /B 1
)

IF NOT "%url:npostart.nl=%"=="%url%" (
  IF NOT "%url:npostart.nl/live=%"=="%url%" (
    ECHO xivid: url wordt niet ondersteund.
    EXIT /B 1
  )
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:npo('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:nos.nl=%"=="%url%" (
  CALL :nos "%url%"
) ELSE IF NOT "%url:tvblik.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:tvblik('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:uitzendinggemist.net=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:tvblik('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtlxl.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:rtl('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtlnieuws.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:rtl('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:kijk.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:kijk('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:omropfryslan.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtvnoord.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtvdrenthe.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtvoost.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:omroepwest.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rijnmond.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtvutrecht.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:omroepgelderland.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:omroepzeeland.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:omroepbrabant.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:l1.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:regio('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:nhnieuws.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:nhnieuws('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:at5.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:nhnieuws('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:omroepflevoland.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:ofl('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:dumpert.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:dumpert('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:autojunk.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:autojunk('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:telegraaf.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:telegraaf('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:ad.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:ad('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:lc.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:lc('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:youtube.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:youtube('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:youtu.be=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:youtube('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:vimeo.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:vimeo('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:dailymotion.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:dailymotion('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:twitch.tv=%"=="%url%" (
  CALL :twitch "%url%"
) ELSE IF NOT "%url:mixcloud.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:mixcloud('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:soundcloud.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:soundcloud('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:facebook.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:facebook('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:fb.watch=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:facebook('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:twitter.com=%"=="%url%" (
  CALL :twitter "%url%"
) ELSE IF NOT "%url:instagram.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:instagram('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:pornhub.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:pornhub('%url%')" --output-format^=cmd') DO %%A
) ELSE (
  ECHO xivid: url wordt niet ondersteund.
  EXIT /B 1
)

IF DEFINED json (
  FOR /F "delims=" %%A IN ('ECHO %json% ^| xidel - -e "fmts:=join($json/(formats)()/id)" --output-format^=cmd') DO %%A
) ELSE (
  ECHO xivid: geen video^(-informatie^) beschikbaar.
  EXIT /B 1
)
IF DEFINED f (
  IF DEFINED fmts (
    SETLOCAL ENABLEDELAYEDEXPANSION
    FOR %%A IN (%f:+= %) DO (
      SET _f=%%A
      IF "!_f:~-1!"=="#" (
        CALL SET _fmts=%%fmts:!_f:~0,-1!=%%
        IF "%fmts%"=="!_fmts!" (
          ECHO xivid: formaat id '!_f!' ongeldig.
          EXIT /B 1
        )
      ) ELSE (
        CALL SET _fmts=%%fmts:!_f!=%%
        IF "%fmts%"=="!_fmts!" (
          ECHO xivid: formaat id '!_f!' ongeldig.
          EXIT /B 1
        )
      )
    )
    ECHO !json! | xidel - -e ^"^
      for $x in tokenize^('%f%'^,'\+'^) return^
      if ^(ends-with^($x^,'#'^)^) then^
        $json/^(formats^)^(^)[starts-with^(id^,substring^($x^,1^,string-length^($x^) - 1^)^)][last^(^)]/url^
      else^
        $json/^(formats^)^(^)[id^=$x]/url^
    "
  ) ELSE (
    ECHO xivid: geen video beschikbaar.
    EXIT /B 1
  )
) ELSE IF DEFINED i (
  ECHO %json% | xidel - -e "xivid:info($json)"
) ELSE IF DEFINED j (
  ECHO %json% | xidel - -e "$json"
) ELSE IF DEFINED fmts (
  ECHO %json% | xidel - -e "$json/(formats)()[last()]/url"
) ELSE (
  ECHO xivid: geen video beschikbaar.
  EXIT /B 1
)
EXIT /B 0
