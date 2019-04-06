BashGemist, een video-url extractie script.

- [Download](#download)
- [Xidel](#xidel)
- [Gebruik en opties](#gebruik-en-opties)
- [Voorbeelden](#voorbeelden)
- [Video rechtstreeks bekijken](#video-rechtstreeks-bekijken)
- [Video downloaden](#video-downloaden)
- [Videofragment downloaden](#videofragment-downloaden)
- [Youtube video downloaden](#youtube-video-downloaden)
- [Disclaimer](#disclaimer)

# Download
```sh
git clone https://github.com/Reino17/bashgemist.git
```
Of download de [tarball](https://github.com/Reino17/bashgemist/archive/master.zip).

# Xidel
BashGemist heeft [Xidel](http://videlibri.sourceforge.net/xidel.html) nodig om te kunnen functioneren.  
Minimale vereiste is revisie `5651` `(xidel-0.9.7.20170825.5651.23300832bcbe)`.

## Linux
Download de Xidel [Linux binary](http://videlibri.sourceforge.net/xidel.html#downloads) en installeer Xidel in `/usr/bin`.  
Installeer vervolgens `openssl`, `openssl-dev` en `libcrypto` zodat Xidel beveiligde https-urls kan openen.

## Windows
BashGemist is een Linux Bash script, maar m.b.v. [Cygwin](https://www.cygwin.com/) is dit script ook in Windows te gebruiken.  
In Windows 10 zou het zelfs zonder Cygwin kunnen door gebruik te maken van Windows Subsystem for Linux (WSL). Ik zelf maak nog geen gebruik van Windows 10, dus informatie hieromtrent is altijd welkom.

Download en installeer [Cygwin](https://cygwin.com/install.html) en download de Xidel [Windows binary](http://videlibri.sourceforge.net/xidel.html#downloads).

Stel je hebt Cygwin geïnstalleerd in `C:\Cygwin\`, dan is het in principe genoeg om `xidel.exe` in `C:\Cygwin\bin` uit te pakken zodat BashGemist er gebruik van kan maken.  
Bewaar je `xidel.exe` liever ergens anders, omdat je er misschien zelf ook gebruik van wilt maken, dan kun je ook gebruik maken van een soort snelkoppeling die naar `xidel.exe` op die andere locatie verwijst.  
Stel `xidel.exe` bevindt zich in `D:\Software\Binaries\`, start dan `C:\Cygwin\Cygwin.bat` om de Bash terminal te openen en voer vervolgens het volgende in:
```sh
cat > /usr/bin/xidel <<EOF
#!/bin/bash
"$(cygpath "D:\Storage\Binaries\xidel.exe")" "\$@"
EOF
```
In `/usr/bin` (of `C:\Cygwin\bin`) is hierdoor het bestand `xidel` aangemaakt, met de volgende inhoud:
```sh
#!/bin/bash
"/cygdrive/d/Storage/Binaries/xidel.exe" "$@"
```
Deze snelkoppeling, dit bestand `xidel`, kun je nu voortaan gebruiken om Xidel te starten.  
Echter, als je dat nu de eerste keer probeert te doen, dan zul je het volgende zien:
```sh
xidel
bash: /usr/bin/xidel: Permission denied
```
`xidel` heeft nog geen uitvoerrechten. Voer het volgende in om dat te bewerkstelligen en je bent klaar:
```sh
chmod +x /usr/bin/xidel
```

## Windows XP
Voor Windows XP gelden een aantal extra instructies.

Download en installeer [deze Cygwin](http://cygwin-xp.portfolis.net/setup/setup-x86.exe). Dit is, voor zover ik weet, de laatst werkende versie voor Windows XP.

Download de Xidel (**openssl**) [Windows binary](http://videlibri.sourceforge.net/xidel.html#downloads).  
Steeds meer websites maken gebruik van TLS 1.2 encryptie/versleuteling. In Windows XP gaat de ondersteuning hiervoor niet verder dan TLS 1.0. Http**s**-urls openen met de standaard Xidel Windows binary gaat in Windows XP daarom niet lukken. Met deze speciale Xidel binary omzeil je dit probleem door gebruik te maken van een andere beveiligingsbibliotheek (OpenSSL i.p.v. Windows's SChannel).  
Deze `xidel.exe` vereist de dll-bestanden `libeay32.dll` en `ssleay32.dll` uit de OpenSSL **1.0.2** reeks. Deze heb ik zelf gecompileerd en kun je op [mijn website](http://rwijnsma.home.xs4all.nl/files/other/) downloaden.

# Gebruik en opties
```sh
Gebruik: ./bashgemist.sh [optie] url

  -h, --help              Toon deze hulppagina.
  -f, --format FORMAAT    Formaat code. Zonder opgave wordt het best
                          beschikbare formaat gekozen.
  -i, --info              Toon video informatie, incl. een opsomming
                          van alle beschikbare formaten.
  -j, --json              Toon video informatie als JSON.
  -d, --debug             Toon bash debug informatie.
```
Gebruik `-h` of `--help` voor een actueel overzicht van ondersteunde websites.

## Linux
Start de Bash terminal, ga naar de map met `bashgemist.sh` en je kunt van start.

## Windows
Start de Bash terminal (`C:\Cygwin\Cygwin.bat`), ga naar de map met `bashgemist.sh` (in mijn geval `cd /cygdrive/d/Storage/Binaries/`) en ook hier kun je dan van start.

Als alternatief heb ik `bashgemist.bat` toegevoegd, waardoor je niet per se de Bash terminal hoeft te gebruiken. Hiermee worden Bash en `bashgemist.sh` op de achtergrond uitgevoerd.  
Start de Windows Command Prompt (`cmd.exe`) en ga naar de map met `bashgemist.bat` en `bashgemist.sh` (in mijn geval `D:` en `cd Storage\Binaries`).  
Het gebruik is dan vervolgens: `bashgemist.bat [optie] url`.

**\[Belangrijk\]** `bashgemist.bat`:
```bat
@ECHO off
SET PATH=C:\Cygwin\bin;%PATH%
bash.exe -c "./bashgemist.sh %*"
```
Standaard verwijst `bashgemist.bat` naar `C:\Cygwin\bin` voor alle Cygwin programma's. Verander dit eerst als je Cygwin ergens anders hebt geïnstalleerd!

# Voorbeelden
We nemen `https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558`, het NOS Journaal van 28 februari 2017 20:00u, als voorbeeld:
```sh
./bashgemist.sh https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
https://pedgewarea28b.video.kpnstreaming.nl/session/7225c984-4daf-11e9-9f58-9cb654975bc0/u7df45/hls/vod/nponep/vod/npo/usp/npo/hls_unencrypted/POW_03375558/POW_03375558_v4.ism/POW_03375558_v4-audio=128000-video=1109000.m3u8
```
Zonder optie/parameter geeft BashGemist de video-url van het beste formaat terug.

Heb je liever een ander formaat, dan zul je er eerst achter moeten komen welke formaten er allemaal beschikbaar zijn. Daar is de optie/parameter `-i` of `--info` voor:
```sh
./bashgemist.sh -i https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
Naam:          NOS Journaal 20.00 uur
Datum:         28-02-2017
Tijdsduur:     00:25:37
Ondertiteling: webvtt
Formaten:      formaat  container       resolutie  bitrate
               hls-0    m3u8[manifest]
               hls-1    m3u8[aac]                  64kbps
               hls-2    m3u8[aac]                  128kbps
               hls-3    m3u8[h264+aac]  480x270    203|64kbps
               hls-4    m3u8[h264+aac]  640x360    506|128kbps
               hls-5    m3u8[h264+aac]  768x432    707|128kbps
               hls-6    m3u8[h264+aac]  1024x576   1109|128kbps  (best)
```
Zonder optie/parameter wordt het formaat `hls-6` gekozen. Als bijv. formaat `hls-4` voor jou ook voldoende is, dan kun je dat met `-f` of `--format` opgeven:
```sh
./bashgemist.sh -f hls-4 https://www.npostart.nl/POW_03375558
https://pedgewarea28b.video.kpnstreaming.nl/session/7225c984-4daf-11e9-9f58-9cb654975bc0/u7df45/hls/vod/nponep/vod/npo/usp/npo/hls_unencrypted/POW_03375558/POW_03375558_v4.ism/POW_03375558_v4-audio=128000-video=506000.m3u8
```
(BashGemist accepteert ook verkorte NPO programma-urls: `https://www.npostart.nl/<PRID>`)

Ik heb in dit geval het NOS Journaal van een paar jaar geleden als voorbeeld genomen, omdat dit het laatste onversleutelde NOS Journaal is. Alle uitzendingen daarna (en waarschijnlijk alle video's op npostart.nl vanaf 01-03-2017) zijn versleuteld en beveiligd met DRM (Digital Rights Manangement) en zijn daardoor niet te downloaden.

# Video rechtstreeks bekijken
## Linux
We nemen `https://www.npostart.nl/live/npo-1`, de livestream van NPO 1, en [VLC media player](https://www.videolan.org/) als voorbeeld:
```sh
vlc $(./bashgemist.sh https://www.npostart.nl/live/npo-1)
```

## Windows
We nemen `https://www.npostart.nl/live/npo-1`, de livestream van NPO 1, en [Media Player Classic - Home Cinema](https://github.com/clsid2/mpc-hc/releases) (welke in `C:\Program Files\Media\MPC-HC` is geïnstalleerd) als voorbeeld.
#### Bash:
```sh
/cygdrive/c/Program\ Files/Media/MPC-HC/mpc-hc.exe $(./bashgemist.sh https://www.npostart.nl/live/npo-1)
```
#### CMD:
```bat
FOR /F %A IN ('bashgemist.bat https://www.npostart.nl/live/npo-1') DO "C:\Program Files\Media\MPC-HC\mpc-hc.exe" %A
```
Of natuurlijk...
```bat
bashgemist.bat https://www.npostart.nl/live/npo-1 | clip
```
...en MPC-HC handmatig starten, waarbij `clip` de video-url naar het klembord kopieert.

# Video downloaden
Progressieve videostreams (`pg-#`) kun je zo met je browser downloaden.  
Dynamische (of adaptieve) videostreams (`hls-#` / `dash-#`) zijn strikt gezien afspeellijsten, en dus tekstbestanden, die verwijzen naar de video opgedeeld in allerlei fragmenten van 5 tot 10 seconden. Voor deze videostreams heb je [FFmpeg](https://ffmpeg.org/) nodig om ze te kunnen downloaden.  
Toch zou ik adviseren om ook de progressieve videostreams met FFMpeg te downloaden. Ten eerste omdat sommige smart tv's niet alle gedownloade mp4-bestanden goed af kunnen spelen en ten tweede vanwege '[overhead](https://nl.wikipedia.org/wiki/Overhead_%28informatica%29)'. Dit kan wel tot een 7% kleinere bestandsgrootte leiden.

We nemen `https://www.rtl.nl/video/f2068013-ce22-34aa-94cb-1b1aaec8d1bd`, het RTL Nieuws van 1 januari 2019 19:30u, als voorbeeld.

## Linux
Download en installeer [FFmpeg](https://johnvansickle.com/ffmpeg/). Vervolgens:
```sh
ffmpeg -i $(./bashgemist.sh https://www.rtl.nl/video/f2068013-ce22-34aa-94cb-1b1aaec8d1bd) -c copy bestandsnaam.mp4
```

## Windows
Download [FFmpeg](http://ffmpeg.zeranoe.com/builds/).  
#### Bash:
```sh
./ffmpeg.exe -i $(./bashgemist.sh https://www.rtl.nl/video/f2068013-ce22-34aa-94cb-1b1aaec8d1bd) -c copy bestandsnaam.mp4
```
#### CMD:
```bat
FOR /F %A IN ('bashgemist.bat https://www.rtl.nl/video/f2068013-ce22-34aa-94cb-1b1aaec8d1bd') DO ffmpeg.exe -i %A -c copy bestandsnaam.mp4
```

## Windows XP
Wat voor Xidel geldt, geldt ook voor FFmpeg. Als FFmpeg niet is gecompileerd met een andere beveiligingsbibliotheek, dan kun je geen https-urls met TLS 1.2 encryptie/versleuteling openen. Daarnaast wordt Windows XP officieel ook niet meer ondersteund door FFmpeg. Sinds voorjaar 2017 ben ik daarom zelf FFmpeg gaan compileren. Mijn binaries zijn gecompileerd met [mbedTLS](https://tls.mbed.org/), zijn Windows XP compatible én werken op oude cpu's zonder SSE2 ondersteuning.
- Github repo: https://github.com/Reino17/ffmpeg-windows-build-helpers
- Zeranoe forum thread: https://ffmpeg.zeranoe.com/forum/viewtopic.php?t=3572
- Te downloaden van mijn eigen website: http://rwijnsma.home.xs4all.nl/files/ffmpeg

De download commando's blijven gewoon hetzelfde.

# Videofragment downloaden
We nemen `https://www.npostart.nl/rotterdam-wil-verborgen-armoede-in-kaart-brengen/17-02-2017/POMS_NOS_7332481`, een videofragment uit het NOS Journaal van 17-02-2017, als voorbeeld:
```sh
./bashgemist.sh -i https://www.npostart.nl/rotterdam-wil-verborgen-armoede-in-kaart-brengen/17-02-2017/POMS_NOS_7332481
Naam:          NOS Journaal: Rotterdam wil verborgen armoede in kaart brengen
Datum:         17-02-2017
Tijdsduur:     00:01:14
Begin:         00:06:28
Einde:         00:07:42
Ondertiteling: webvtt
Formaten:      formaat  container       resolutie  bitrate
               hls-0    m3u8[manifest]
               hls-1    m3u8[aac]                  64kbps
               hls-2    m3u8[aac]                  128kbps
               hls-3    m3u8[h264+aac]  480x270    202|64kbps
               hls-4    m3u8[h264+aac]  640x360    502|128kbps
               hls-5    m3u8[h264+aac]  768x432    702|128kbps
               hls-6    m3u8[h264+aac]  1024x576   1004|128kbps  (best)

Download:      ffmpeg -ss 00:06:00 -i <url> -ss 28 -t 00:01:14 [...]
```
Als je deze video op npostart.nl bekijkt, dan zie je een videofragment van een dikke minuut lang die begint op 6½ minuut vanaf het begin. De video-urls (van alle formaten) echter zijn die van de hele aflevering. Gelukkig kun je met FFmpeg een begintijd en een tijdsduur opgeven om op die manier een videofragment eruit te knippen.  
In dit geval willen we ook de ondertiteling graag meenemen **in** het videobestand en deze de voorgestelde naam + datum geven.

BashGemist is een video-url extractie script en geeft (al dan niet met `-f` of `--format`) alleen de video-url terug. Toch zijn er met de optie/parameter `-j` of `--json` meer mogelijkheden. De video informatie hierboven wordt hiermee teruggegeven als [JSON](https://nl.wikipedia.org/wiki/JSON); het formaat waarin BashGemist ook alles verwerkt (hieronder iets ingekort):
```sh
./bashgemist.sh -j https://www.npostart.nl/POMS_NOS_7332481
{
  "name": "NOS Journaal: Rotterdam wil verborgen armoede in kaart brengen",
  "date": "17-02-2017",
  "duration": "00:01:14",
  "start": "00:06:28",
  "end": "00:07:42",
  "subtitle": {
    "format": "webvtt",
    "url": "https://rs.poms.omroep.nl/v1/api/subtitles/POW_03372926/nl_NL/CAPTION.vtt"
  },
  "formats": [
    {
      "format": "hls-0",
      "container": "m3u8[manifest]",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTM1NTkxMDYsInVyaSI6Ilwvdm9kXC9ucG9cL3VzcFwvbnBvXC9obHNfdW5lbmNyeXB0ZWRcL1BPV18wMzM3MjkyNlwvUE9XXzAzMzcyOTI2X3Y0LmlzbSIsImNsaWVudF9pcCI6IjgwLjEwMS40OS41In0.MusH2x9u7kI47-yXgM6YKBW6F9Y0uvfAbxhPwFm_iQU/vod/npo/usp/npo/hls_unencrypted/POW_03372926/POW_03372926_v4.ism/playlist.m3u8"
    },
    {
      "format": "hls-1",
      "container": "m3u8[aac]",
      "resolution": null,
      "bitrate": "64kbps",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTM1NTkxMDYsInVyaSI6Ilwvdm9kXC9ucG9cL3VzcFwvbnBvXC9obHNfdW5lbmNyeXB0ZWRcL1BPV18wMzM3MjkyNlwvUE9XXzAzMzcyOTI2X3Y0LmlzbSIsImNsaWVudF9pcCI6IjgwLjEwMS40OS41In0.MusH2x9u7kI47-yXgM6YKBW6F9Y0uvfAbxhPwFm_iQU/vod/npo/usp/npo/hls_unencrypted/POW_03372926/POW_03372926_v4.ism/POW_03372926_v4-audio=64000.m3u8"
    },
    {
      "format": "hls-2",
      "container": "m3u8[aac]",
      "resolution": null,
      "bitrate": "128kbps",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTM1NTkxMDYsInVyaSI6Ilwvdm9kXC9ucG9cL3VzcFwvbnBvXC9obHNfdW5lbmNyeXB0ZWRcL1BPV18wMzM3MjkyNlwvUE9XXzAzMzcyOTI2X3Y0LmlzbSIsImNsaWVudF9pcCI6IjgwLjEwMS40OS41In0.MusH2x9u7kI47-yXgM6YKBW6F9Y0uvfAbxhPwFm_iQU/vod/npo/usp/npo/hls_unencrypted/POW_03372926/POW_03372926_v4.ism/POW_03372926_v4-audio=128000.m3u8"
    },
    {
      "format": "hls-3",
      "container": "m3u8[h264+aac]",
      "resolution": "480x270",
      "bitrate": "202|64kbps",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTM1NTkxMDYsInVyaSI6Ilwvdm9kXC9ucG9cL3VzcFwvbnBvXC9obHNfdW5lbmNyeXB0ZWRcL1BPV18wMzM3MjkyNlwvUE9XXzAzMzcyOTI2X3Y0LmlzbSIsImNsaWVudF9pcCI6IjgwLjEwMS40OS41In0.MusH2x9u7kI47-yXgM6YKBW6F9Y0uvfAbxhPwFm_iQU/vod/npo/usp/npo/hls_unencrypted/POW_03372926/POW_03372926_v4.ism/POW_03372926_v4-audio=64000-video=202000.m3u8"
    },
    [...]
    {
      "format": "hls-6",
      "container": "m3u8[h264+aac]",
      "resolution": "1024x576",
      "bitrate": "1004|128kbps",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTM1NTkxMDYsInVyaSI6Ilwvdm9kXC9ucG9cL3VzcFwvbnBvXC9obHNfdW5lbmNyeXB0ZWRcL1BPV18wMzM3MjkyNlwvUE9XXzAzMzcyOTI2X3Y0LmlzbSIsImNsaWVudF9pcCI6IjgwLjEwMS40OS41In0.MusH2x9u7kI47-yXgM6YKBW6F9Y0uvfAbxhPwFm_iQU/vod/npo/usp/npo/hls_unencrypted/POW_03372926/POW_03372926_v4.ism/POW_03372926_v4-audio=128000-video=1004000.m3u8"
    }
  ]
}
```

Dit is waar je Xidel heel goed voor kunt gebruiken.

## Linux
De door BashGemist gegenereerde JSON 'pipen' we naar Xidel en deze geeft alle informatie terug van de JSON attributen die we opgeven:
```sh
./bashgemist.sh -j https://www.npostart.nl/POMS_NOS_7332481 | xidel -s - -e '
  $json/(
    name,
    date,
    duration,
    start,
    subtitle/url,
    (formats)()[format="hls-6"]/url
  )
'
NOS Journaal: Rotterdam wil verborgen armoede in kaart brengen
17-02-2017
00:01:14
00:06:28
https://rs.poms.omroep.nl/v1/api/subtitles/POW_03372926/nl_NL/CAPTION.vtt
https://nl-ams-p6-am5.cdn.streamgate.nl/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTM1NTkxMDYsInVyaSI6Ilwvdm9kXC9ucG9cL3VzcFwvbnBvXC9obHNfdW5lbmNyeXB0ZWRcL1BPV18wMzM3MjkyNlwvUE9XXzAzMzcyOTI2X3Y0LmlzbSIsImNsaWVudF9pcCI6IjgwLjEwMS40OS41In0.MusH2x9u7kI47-yXgM6YKBW6F9Y0uvfAbxhPwFm_iQU/vod/npo/usp/npo/hls_unencrypted/POW_03372926/POW_03372926_v4.ism/POW_03372926_v4-audio=128000-video=1004000.m3u8
```
In een bestandsnaam mag geen `:` voorkomen, dus die vervangen we voor een `-`. Daar plakken we de datum achter met haakjes er omheen, maar zonder streepjes. Vervolgens splitten we de begintijd nog in tweeën; de begintijd afgerond op 30 seconden en de resterende seconden. (Met de `-ss 00:06:00` vóór FFmpeg's input `-i <url>` slaat FFmpeg de eerste 6 minuten over en begint dan met lezen. Met de `-ss 00:00:28` (of `28`) daarna zoekt FFmpeg de resterende 28 seconden **nauwkeurig** naar het juiste beginpunt. Met `-t 00:01:14` zal FFmpeg na 1 minuut en 14 seconden stoppen met lezen/verwerken.)
```sh
./bashgemist.sh -j https://www.npostart.nl/POMS_NOS_7332481 | xidel -s - -e '
  $json/(
    concat(
      replace(
        name,
        ":",
        "-"
      ),
      " (",
      replace(
        date,
        "-",
        ""
      ),
      ")"
    ),
    duration,
    time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration("PT1S")),
    seconds-from-time(start) mod 30,
    subtitle/url,
    (formats)()[format="hls-6"]/url
  )
'
NOS Journaal- Rotterdam wil verborgen armoede in kaart brengen (17022017)
00:01:14
00:06:00
28
https://rs.poms.omroep.nl/v1/api/subtitles/POW_03372926/nl_NL/CAPTION.vtt
https://nl-ams-p6-am5.cdn.streamgate.nl/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTM1NTkxMDYsInVyaSI6Ilwvdm9kXC9ucG9cL3VzcFwvbnBvXC9obHNfdW5lbmNyeXB0ZWRcL1BPV18wMzM3MjkyNlwvUE9XXzAzMzcyOTI2X3Y0LmlzbSIsImNsaWVudF9pcCI6IjgwLjEwMS40OS41In0.MusH2x9u7kI47-yXgM6YKBW6F9Y0uvfAbxhPwFm_iQU/vod/npo/usp/npo/hls_unencrypted/POW_03372926/POW_03372926_v4.ism/POW_03372926_v4-audio=128000-video=1004000.m3u8
```
Met deze informatie kun je nu een FFmpeg commando samenstellen. Dit kan op 3 manieren:
- Exporteer de informatie als variabelen en raadpleeg die daarna in een aparte FFmpeg commando:
```sh
eval "$(./bashgemist.sh -j https://www.npostart.nl/POMS_NOS_7332481 | xidel -s - -e '
  $json/(
    name:=concat(
      replace(
        name,
        ":",
        "-"
      ),
      " (",
      replace(
        date,
        "-",
        ""
      ),
      ")"
    ),
    t:=duration,
    ss1:=time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration("PT1S")),
    ss2:=seconds-from-time(start) mod 30,
    sub:=subtitle/url,
    url:=(formats)()[format="hls-6"]/url
  )
' --output-format=bash)"

ffmpeg \
-ss $ss1 -i $url \
-ss $ss1 -i $sub \
-ss $ss2 -t $t \
-c copy \
-c:s srt -metadata:s:s language=dut \
"$name.mkv"
```
---
De FFmpeg commando vertaalt dus naar:
```sh
ffmpeg \
-ss 00:06:00 -i https://nl-ams-p6-am5.cdn.streamgate.nl/[...]/POW_03372926_v4-audio=128000-video=1004000.m3u8 \
-ss 00:06:00 -i https://rs.poms.omroep.nl/v1/api/subtitles/POW_03372926/nl_NL/CAPTION.vtt \
-ss 28 -t 00:01:14 \
-c copy \
-c:s srt -metadata:s:s language=dut \
"NOS Journaal- Rotterdam wil verborgen armoede in kaart brengen (17022017).mkv"
```
FFmpeg opent de video-url en de ondertiteling-url en slaat de eerste 6 minuten en 28 seconden over. Na 1 minuut en 14 seconden gaat weer de schaar erin. De audio- en videostream worden gekopieerd. De ondertiteling wordt geconverteerd van webvtt naar subrip en wordt gelabeld als Nederlands. Ten slotte wordt alles in een mkv-container gestopt.

---
- Gebruik interne variabelen en gebruik Xidel's `system()` om FFmpeg vanuit Xidel aan te roepen:
```sh
./bashgemist.sh -j https://www.npostart.nl/POMS_NOS_7332481 | xidel -s - -e '
  $json/(
    let $name:=concat(
          replace(
            name,
            ":",
            "-"
          ),
          " (",
          replace(
            date,
            "-",
            ""
          ),
          ")"
        ),
        $t:=duration,
        $ss1:=time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration("PT1S")),
        $ss2:=seconds-from-time(start) mod 30,
        $sub:=subtitle/url,
        $url:=(formats)()[format="hls-6"]/url
    return
    system(
      x"bash -c ""ffmpeg \
        -ss {$ss1} -i {$url} \
        -ss {$ss1} -i {$sub} \
        -ss {$ss2} -t {$t} \
        -c copy \
        -c:s srt -metadata:s:s language=dut \
        """"{$name}.mkv"""" \
      """
    )
  )
'
```
- Gebruik Xidel's `system()` om FFmpeg vanuit Xidel aan te roepen met alle informatie rechtstreeks uit de JSON:
```sh
./bashgemist.sh -j https://www.npostart.nl/POMS_NOS_7332481 | xidel -s - -e '
  $json/(
    system(
      x"bash -c ""ffmpeg \
        -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration("PT1S"))} \
        -i  {(formats)()[format="hls-6"]/url} \
        -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration("PT1S"))} \
        -i  {subtitle/url} \
        -ss {seconds-from-time(start) mod 30} \
        -t  {duration} \
        -c copy \
        -c:s srt -metadata:s:s language=dut \
        """"{
          concat(
            replace(
              name,
              ":",
              "-"
            ),
            " (",
            replace(
              date,
              "-",
              ""
            ),
            ")"
          )
        }.mkv"""" \
      """
    )
  )
'
```

## Windows
- Exporteer de informatie als variabelen en raadpleeg die daarna in een aparte FFmpeg commando:
```bat
FOR /F "delims=" %A IN ('bashgemist.bat -j https://www.npostart.nl/POMS_NOS_7332481 ^| xidel.exe -s - -e ^"
  $json/^(
    name:^=concat^(
      replace^(
        name^,
        ':'^,
        '-'
      ^)^,
      ' ^('^,
      replace^(
        date^,
        '-'^,
        ''
      ^)^,
      '^)'
    ^)^,
    t:^=duration^,
    ss1:^=time^(start^) - ^(seconds-from-time^(start^) mod 30 * dayTimeDuration^('PT1S'^)^)^,
    ss2:^=seconds-from-time^(start^) mod 30^,
    sub:^=subtitle/url^,
    url:^=^(formats^)^(^)[format^='hls-6']/url
  ^)
^" --output-format^=cmd') DO %A

ffmpeg.exe ^
-ss %ss1% -i %url% ^
-ss %ss1% -i %sub% ^
-ss %ss2% -t %t% ^
-c copy ^
-c:s srt -metadata:s:s language=dut ^
"%name%.mkv"
```
- Gebruik interne variabelen en gebruik Xidel's `system()` om FFmpeg vanuit Xidel aan te roepen:
```bat
bashgemist.bat -j https://www.npostart.nl/POMS_NOS_7332481 | xidel.exe -s - -e ^" ^
  $json/( ^
    let $name:=concat( ^
          replace( ^
            name, ^
            ':', ^
            '-' ^
          ), ^
          ' (', ^
          replace( ^
            date, ^
            '-', ^
            '' ^
          ), ^
          ')' ^
        ), ^
        $t:=duration, ^
        $ss1:=time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration('PT1S')), ^
        $ss2:=seconds-from-time(start) mod 30, ^
        $sub:=subtitle/url, ^
        $url:=(formats)()[format='hls-6']/url ^
    return ^
    system( ^
      x'ffmpeg.exe ^
      -ss {$ss1} -i {$url} ^
      -ss {$ss1} -i {$sub} ^
      -ss {$ss2} -t {$t} ^
      -c copy ^
      -c:s srt -metadata:s:s language=dut ^
      \"{$name}.mkv\"' ^
    ) ^
  ) ^
"
```
- Gebruik Xidel's `system()` om FFmpeg vanuit Xidel aan te roepen met alle informatie rechtstreeks uit de JSON:
```bat
bashgemist.bat -j https://www.npostart.nl/POMS_NOS_7332481 | xidel.exe -s - -e ^" ^
  $json/( ^
    system( ^
      x'ffmpeg.exe ^
      -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration('PT1S'))} ^
      -i  {(formats)()[format='hls-6']/url} ^
      -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration('PT1S'))} ^
      -i  {subtitle/url} ^
      -ss {seconds-from-time(start) mod 30} ^
      -t  {duration} ^
      -c copy ^
      -c:s srt -metadata:s:s language=dut ^
      \^"{ ^
        concat( ^
          replace( ^
            name, ^
            ':', ^
            '-' ^
          ), ^
          ' (', ^
          replace( ^
            date, ^
            '-', ^
            '' ^
          ), ^
          ')' ^
        ) ^
      }.mkv\^"' ^
    ) ^
  ) ^
"
```

# Youtube video downloaden
We nemen `https://www.youtube.com/watch?v=GuoxLggqI_g`, een documentaire, als voorbeeld:
```sh
./bashgemist.sh -i https://www.youtube.com/watch?v=GuoxLggqI_g
Naam:          The Uncertainty Has Settled (Full film)
Datum:         08-11-2018
Tijdsduur:     01:28:26
Ondertiteling: ttml
Formaten:      formaat  container         resolutie        frequentie  bitrate
               pg-1     mp4[h264+aac]     640x360                      452kbps
               pg-2     webm[vp8+vorbis]  640x360
               pg-3     mp4[h264+aac]     1280x720                     825kbps
               dash-1   webm[opus]                         48kHz       91kbps
               dash-2   webm[opus]                         48kHz       109kbps
               dash-3   mp4[aac]                           44.1kHz     135kbps
               dash-4   webm[vorbis]                       44.1kHz     145kbps
               dash-5   webm[opus]                         48kHz       176kbps
               dash-6   webm[vp9]         256x144@25fps                102kbps
               dash-7   mp4[h264]         256x144@25fps                115kbps
               dash-8   webm[vp9]         426x240@25fps                233kbps
               dash-9   mp4[h264]         426x240@25fps                337kbps
               dash-10  webm[vp9]         640x360@25fps                431kbps
               dash-11  mp4[h264]         640x360@25fps                740kbps
               dash-12  webm[vp9]         854x480@25fps                776kbps
               dash-13  mp4[h264]         854x480@25fps                1357kbps
               dash-14  webm[vp9]         1280x720@25fps               1619kbps
               dash-15  mp4[h264]         1280x720@25fps               2402kbps
               dash-16  webm[vp9]         1920x1080@25fps              2882kbps
               dash-17  mp4[h264]         1920x1080@25fps              4826kbps  (best)
```
I.t.t. bij vele andere websites zijn bij Youtube de DASH audio- en videostreams gescheiden van elkaar. Tenzij je genoegen neemt met de `pg-#` videostreams zul je ze dus moeten combineren. We willen de 1080p H.264 videostream graag combineren met de AAC audiostream.  
De documentaire is nederlands-, duits- en engelstalig en heeft geen "hardsubs" (ondertiteling als onderdeel van het videobeeld zelf), maar wel "softsubs" (een aparte ondertitelingstream). Deze pakken we dus ook mee.

De ondertiteling is in dit geval van het type [TTML](https://en.wikipedia.org/wiki/Timed_Text_Markup_Language). FFmpeg ondersteunt dit op XML gebaseerde formaat (nog) niet. Xidel daarentegen is hier bij uitstek geschikt voor. Waar Youtube-dl hier flink wat regels aan code voor nodig heeft is het voor Xidel en een simpele query zo gepiept om deze ondertiteling te converteren naar het meest gangbare [SRT](https://nl.wikipedia.org/wiki/SubRip) formaat. Voordat we de audio- en videostream erbij pakken moet dit dus eerst.  
Om BashGemist maar één keer aan te hoeven roepen wijzen we een variabele toe aan de gegenereerde JSON:
```sh
bg_json=$(./bashgemist.sh -j https://www.youtube.com/watch?v=GuoxLggqI_g)
```
We '[pipen](https://en.wikipedia.org/wiki/Pipeline_%28Unix%29)' deze JSON naar Xidel. Xidel opent de TTML ondertiteling-url en converteert deze naar SRT. Xidel's uitvoer slaan we op als `ondertiteling.srt`:
```sh
printf '%s' $bg_json | xidel -s - --xquery '
  for $x at $i in $json/subtitle/doc(url)//text
  return (
    $i,
    concat(
      format-time(
        $x/@start * duration("PT1S"),
        "[H01]:[m01]:[s01],[f001]"
      ),
      " --> ",
      format-time(
        $x/(@start + @dur) * duration("PT1S"),
        "[H01]:[m01]:[s01],[f001]"
      )
    ),
    parse-xml($x),
    ""
  )
' > ondertiteling.srt
```
Als alternatief kun je ook een here-string en Xidel's `file:write-text-lines()`-functie gebruiken:
```sh
<<< $bg_json xidel -s - --xquery '
  file:write-text-lines(
    "ondertiteling.srt",
    for $x [...]
  )
'
```
We 'pipen' de JSON weer naar Xidel en exporteren vervolgens de naam en de gewenste video- en audio-url als variabelen:
```sh
eval "$(printf '%s' $bg_json | xidel -s - -e '
  name:=$json/name,
  v_url:=$json/(formats)()[format="dash-17"]/url,
  a_url:=$json/(formats)()[format="dash-3"]/url
' --output-format=bash)"
```
Als laatste roepen we FFmpeg aan. We openen de video- en audio-url én de zojuist geconverteerde `ondertiteling.srt`. De ondertiteling wordt gelabeld als "Dutch". Met `-c copy` voeren we een zogenaamde [stream-copy](https://ffmpeg.org/ffmpeg.html#Stream-copy) uit waarbij geen kwaliteitsverlies optreedt. Met `"$name.mkv"` als uitvoer zal `The Uncertainty Has Settled (Full film).mkv` het resultaat zijn:
```sh
ffmpeg -i $v_url -i $a_url -i ondertiteling.srt -c copy -metadata:s:s language=dut "$name.mkv"
```

# Disclaimer
Omdat ik een Windows gebruiker ben kan het zijn dat de informatie hierboven omtrent Linux niet allemaal klopt, of niet volledig is. Laat het me gerust weten mocht dat het geval zijn.
