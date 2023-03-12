@GOTO :start
:: --------------------------------
:: Xivid batch script
:: --------------------------------
::
:: Copyright (C) 2023 Reino Wijnsma
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
ECHO   -f id[+id]    Toon specifiek formaat, of specifieke formaten.
ECHO                 Met een id dat eindigt op een '$' wordt het formaat
ECHO                 met het hoogste nummer getoond.
ECHO                 Zonder optie wordt het formaat met de hoogste
ECHO                 resolutie en/of bitrate getoond.
ECHO   -i            Toon video informatie, incl. een opsomming van alle
ECHO                 beschikbare formaten.
ECHO   -j            Toon video informatie als JSON.
ECHO.
ECHO Ondersteunde websites:
ECHO   npostart.nl             rtvoost.nl          youtu.be
ECHO   gemi.st                 omroepwest.nl       vimeo.com
ECHO   radioplayer.npo.nl      rijnmond.nl         dailymotion.com
ECHO   nos.nl                  rtvutrecht.nl       rumble.com
ECHO   tvblik.nl               gld.nl              reddit.com
ECHO   uitzendinggemist.net    omroepzeeland.nl    redd.it
ECHO   rtl.nl                  omroepbrabant.nl    twitch.tv
ECHO   rtlxl.nl                l1.nl               mixcloud.com
ECHO   rtlnieuws.nl            dumpert.nl          soundcloud.com
ECHO   kijk.nl                 autojunk.nl         facebook.com
ECHO   omropfryslan.nl         abhd.nl             fb.watch
ECHO   rtvnoord.nl             autoblog.nl         instagram.com
ECHO   rtvdrenthe.nl           telegraaf.nl        twitter.com
ECHO   nhnieuws.nl             ad.nl               pornhub.com
ECHO   at5.nl                  lc.nl               xhamster.com
ECHO   omroepflevoland.nl      youtube.com         youporn.com
ECHO.
ECHO Voorbeelden:
ECHO   xivid.bat https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
ECHO   xivid.bat -i https://www.rtlxl.nl/programma/rtl-nieuws/bf475894-02ce-3724-9a6f-91de543b8a4c
ECHO   xivid.bat -f hls-$+sub-1 https://kijk.nl/video/AgvoU4AJTpy
EXIT /B

:start
@ECHO off
SETLOCAL DISABLEDELAYEDEXPANSION
SET "PATH=%PATH%;%~dp0"
FOR %%A IN (xidel.exe) DO IF EXIST "%%~$PATH:A" (
  FOR /F "delims=" %%B IN ('
    xidel --version ^| xidel -s - -e "extract($raw,'\d{8}')"
  ') DO IF %%B GEQ 20210708 (
    SET "XIDEL_OPTIONS=--silent --module=%~dp0xivid.xqm"
  ) ELSE (
    ECHO xivid: '%%~$PATH:A' gevonden, maar versie is te oud.
    ECHO Installeer Xidel 0.9.9.7941 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
    ECHO Ga naar http://videlibri.sourceforge.net/xidel.html.
    EXIT /B 1
  )
) ELSE (
  ECHO xivid: 'xidel.exe' niet gevonden!
  ECHO Installeer Xidel 0.9.9.7941 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
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

FOR /F "delims=" %%A IN ('xidel -e ^"
  let $extractors:^={
        'npo':array{'npostart.nl'^,'gemi.st'^,'radioplayer.npo.nl'}^,
        'nos':array{'nos.nl'}^,
        'rtl':array{'rtl.nl'^,'rtlxl.nl'^,'rtlnieuws.nl'}^,
        'kijk':array{'kijk.nl'}^,
        'tvblik':array{'tvblik.nl'^,'uitzendinggemist.net'}^,
        'regiogroei':array{
          'omropfryslan.nl'^,'rtvnoord.nl'^,'rtvdrenthe.nl'^,
          'rtvoost.nl'^,'omroepwest.nl'^,'rijnmond.nl'^,
          'rtvutrecht.nl'^,'gld.nl'^,'omroepzeeland.nl'
        }^,
        'obr':array{'omroepbrabant.nl'}^,
        'l1':array{'l1.nl'}^,
        'nhnieuws':array{'nhnieuws.nl'^,'at5.nl'}^,
        'ofl':array{'omroepflevoland.nl'}^,
        'dumpert':array{'dumpert.nl'}^,
        'autojunk':array{'autojunk.nl'}^,
        'abhd':array{'abhd.nl'}^,
        'autoblog':array{'autoblog.nl'}^,
        'telegraaf':array{'telegraaf.nl'}^,
        'ad':array{'ad.nl'}^,
        'lc':array{'lc.nl'}^,
        'vimeo':array{'vimeo.com'}^,
        'dailymotion':array{'dailymotion.com'}^,
        'rumble':array{'rumble.com'}^,
        'reddit':array{'reddit.com'^,'redd.it'}^,
        'twitch':array{'twitch.tv'}^,
        'mixcloud':array{'mixcloud.com'}^,
        'soundcloud':array{'soundcloud.com'}^,
        'facebook':array{'facebook.com'^,'fb.watch'}^,
        'twitter':array{'twitter.com'}^,
        'instagram':array{'instagram.com'}^,
        'pornhub':array{'pornhub.com'}^,
        'xhamster':array{'xhamster.com'}^,
        'youporn':array{'youporn.com'}
      }^,
      $host:^=request-decode^(environment-variable^('url'^)^)/host
  for $x in $extractors^(^) return
  if ^(matches^($host^,join^($extractors^($x^)^(^)^,'^|'^)^)^)
  then ^(
    json:^=eval^(x'xivid:{$x}^(''{environment-variable^('url'^)}''^)'^)^,
    extractor:^=$x^,
    fmts:^=join^($json/^(formats^)^(^)/id^)
  ^)
  else ^(^)
^" --output-format^=cmd') DO %%A

IF NOT "%url:youtube.com=%"=="%url%" SET extractor=youtube
IF NOT "%url:youtu.be=%"=="%url%" SET extractor=youtube
IF "%extractor%"=="youtube" (
  xidel -e "file:write('xivid_yt.json',xivid:youtube('%url%'),{'method':'json'})"
  FOR /F "delims=" %%A IN ('xidel xivid_yt.json -e "fmts:=join($json/(formats)()/id)" --output-format^=cmd') DO %%A
)

IF NOT DEFINED extractor (
  ECHO xivid: url wordt niet ondersteund.
  EXIT /B 1
)
IF NOT DEFINED json IF NOT EXIST xivid_yt.json (
  ECHO xivid: geen video^(-informatie^) beschikbaar.
  EXIT /B 1
)

IF DEFINED f (
  IF DEFINED fmts (
    SETLOCAL ENABLEDELAYEDEXPANSION
    FOR %%A IN (%f:+= %) DO (
      SET _f=%%A
      IF "!_f:~-1!"=="$" (
        CALL SET _fmts=%%fmts:!_f:~0,-1!=%%
        IF "%fmts%"=="!_fmts!" (
          ECHO xivid: formaat id '!_f!' ongeldig.
          IF EXIST xivid_yt.json DEL xivid_yt.json
          EXIT /B 1
        )
      ) ELSE (
        CALL SET _fmts=%%fmts:!_f!=%%
        IF "%fmts%"=="!_fmts!" (
          ECHO xivid: formaat id '!_f!' ongeldig.
          IF EXIST xivid_yt.json DEL xivid_yt.json
          EXIT /B 1
        )
      )
    )
    (^ IF EXIST xivid_yt.json (TYPE xivid_yt.json^) ELSE (ECHO !json!^)) | xidel -e ^"^
      for $x in tokenize^('%f%'^,'\+'^) return^
      if ^(ends-with^($x^,'$'^)^) then^
        $json/^(formats^)^(^)[starts-with^(id^,substring^($x^,1^,string-length^($x^) - 1^)^)][last^(^)]/url^
      else^
        $json/^(formats^)^(^)[id^=$x]/url^
    "
  ) ELSE (
    ECHO xivid: geen video beschikbaar.
    IF EXIST xivid_yt.json DEL xivid_yt.json
    EXIT /B 1
  )
) ELSE IF DEFINED i (
  (^ IF EXIST xivid_yt.json (TYPE xivid_yt.json^) ELSE (ECHO %json%^)) | xidel -e "xivid:info($json)"
) ELSE IF DEFINED j (
  (^ IF EXIST xivid_yt.json (TYPE xivid_yt.json^) ELSE (ECHO %json%^)) | xidel -e "$json"
) ELSE IF DEFINED fmts (
  (^ IF EXIST xivid_yt.json (TYPE xivid_yt.json^) ELSE (ECHO %json%^)) | xidel -e "$json/(formats)()[last()]/url"
) ELSE (
  ECHO xivid: geen video beschikbaar.
  IF EXIST xivid_yt.json DEL xivid_yt.json
  EXIT /B 1
)
IF EXIST xivid_yt.json DEL xivid_yt.json
EXIT /B 0
