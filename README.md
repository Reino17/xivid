##### Xivid, een Windows en Linux video-url extractie commandoregel-script.

- [Download](#download)
- [Gebruik en opties](#gebruik-en-opties)
- [Xidel](#xidel)
- [Video rechtstreeks bekijken](#video-rechtstreeks-bekijken)
- [Video downloaden](#video-downloaden)
- [Videofragment downloaden](#videofragment-downloaden)
- [Youtube video downloaden](#youtube-video-downloaden)
- [Disclaimer](#disclaimer)

# Download
```
git clone https://github.com/Reino17/xivid.git
```
Of download de [tarball](https://github.com/Reino17/xivid/archive/master.zip).

# Gebruik en opties
```
Gebruik (Windows): xivid.bat [optie] url
Gebruik (Linux): ./xivid.sh [optie] url

  -f ID    Forceer specifiek formaat. Zonder opgave wordt het best
           beschikbare formaat gekozen.
  -i       Toon video informatie, incl. een opsomming van alle
           beschikbare formaten.
  -j       Toon video informatie als JSON.
```
Deze websites worden op dit moment ondersteund:
```
  npostart.nl             omropfryslan.nl       omroepwest.nl
  gemi.st                 rtvnoord.nl           rijnmond.nl
  nos.nl                  rtvdrenthe.nl         rtvutrecht.nl
  tvblik.nl               nhnieuws.nl           omroepgelderland.nl
  uitzendinggemist.net    at5.nl                omroepzeeland.nl
  rtl.nl                  omroepflevoland.nl    omroepbrabant.nl
  kijk.nl                 rtvoost.nl            l1.nl

  dumpert.nl              vimeo.com
  autojunk.nl             twitch.tv
  telegraaf.nl            facebook.com
  ad.nl                   twitter.com
  lc.nl                   pornhub.com
  youtube.com
  youtu.be
```
Xivid is een hobbyproject en is constant in ontwikkeling. Houd er daarom rekening mee dat per website niet alle type urls altijd ondersteund worden.  
De video-urls van beveiligde video's (met DRM (Digital Rights Manangement), of anderzijds) worden niet weergegeven.

## Voorbeelden
Zonder optie geeft Xivid de video-url van het "beste" formaat:
```
xivid.bat https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
https://pedgewarea28b.video.kpnstreaming.nl/session/7225c984-4daf-11e9-9f58-9cb654975bc0/u7df45/hls/vod/nponep/vod/npo/usp/npo/hls_unencrypted/POW_03375558/POW_03375558_v4.ism/POW_03375558_v4-audio=128000-video=1109000.m3u8
```
```
./xivid.sh -i https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
Naam:      NOS Journaal 20.00 uur
Datum:     28-02-2017
Tijdsduur: 00:25:37
Formaten:  id     formaat         taal  resolutie  bitrate
           sub-1  vtt             nl
           hls-0  m3u8[manifest]
           hls-1  m3u8[aac]                        64kbps
           hls-2  m3u8[aac]                        128kbps
           hls-3  m3u8[h264+aac]        480x270    203|64kbps
           hls-4  m3u8[h264+aac]        640x360    506|128kbps
           hls-5  m3u8[h264+aac]        768x432    707|128kbps
           hls-6  m3u8[h264+aac]        1024x576   1109|128kbps (best)
```
Gebruik `-f` voor een ander gewenst formaat:
```
xivid.bat -f hls-4 https://www.npostart.nl/POW_03375558
https://pedgewarea28b.video.kpnstreaming.nl/session/7225c984-4daf-11e9-9f58-9cb654975bc0/u7df45/hls/vod/nponep/vod/npo/usp/npo/hls_unencrypted/POW_03375558/POW_03375558_v4.ism/POW_03375558_v4-audio=128000-video=506000.m3u8
```
(Het 20:00u NOS Journaal van 28-02-2017 in dit voorbeeld is het laatste onversleutelde NOS Journaal. Alle uitzendingen daarna (en waarschijnlijk alle video's op npostart.nl vanaf 01-03-2017) zijn versleuteld en beveiligd met DRM en zijn daardoor niet te downloaden.)

# Xidel
[Xidel](http://videlibri.sourceforge.net/xidel.html) is een commandoregel programma voor het downloaden en informatie onttrekken van HTML/XML pagina's, JSON-APIs en lokale bestanden door gebruik te maken van CSS, XPath 3.0, XQuery 3.0, JSONiq, of pattern templates.

Xivid maakt veelvuldig gebruik van Xidel en kan niet functioneren zonder. Xidel is dus essentieel. Minimale vereiste versie is `0.9.8`. Nieuwere (beta) versies zouden in principe ook moeten werken.

## Linux
Download de Xidel [Linux binary](http://videlibri.sourceforge.net/xidel.html#downloads) en installeer deze in `/usr/bin`, of ergens anders in `$PATH`.  
Installeer vervolgens `openssl`, `openssl-dev` en `libcrypto` zodat Xidel beveiligde http**s**-urls kan openen.

Installeer je Xidel liever ergens anders, maak dan een [symlink](https://en.wikipedia.org/wiki/Symbolic_link#POSIX_and_Unix-like_operating_systems) aan zodat Xidel toch gevonden kan worden:
```sh
ln -s /<andere-map>/xidel /usr/bin/xidel
```

## Windows
Download de Xidel [Windows binary](http://videlibri.sourceforge.net/xidel.html#downloads) en installeer deze in `C:\Windows\SysWOW64`, of ergens anders in `%PATH%`. 

Installeer je Xidel liever ergens anders, maak dan een [symlink](https://en.wikipedia.org/wiki/Symbolic_link#Microsoft_Windows) aan zodat Xidel toch gevonden kan worden:
```bat
mklink -s X:\<andere-map>\xidel.exe C:\Windows\SysWOW64\xidel.exe
```

## Windows XP
Steeds meer websites maken gebruik van TLS 1.2 encryptie/versleuteling. In Windows XP gaat de ondersteuning hiervoor niet verder dan TLS 1.0, waardoor het openen van http**s**-urls met de standaard Xidel Windows binary niet gaat lukken.  
Xidel heeft ook een speciale Windows binary die voor https-connecties niet gebruik maakt van Windows's SChannel, maar van [OpenSSL](https://www.openssl.org), een andere beveiligingsbibliotheek.

Download de Xidel (OpenSSL) [Windows binary](http://videlibri.sourceforge.net/xidel.html#downloads) en installeer deze in `C:\Windows\System32`, of ergens anders in `%PATH%`.

Installeer je Xidel liever ergens anders, dan kun je m.b.v. `SET "PATH=%PATH%;X:\<andere-map>"` deze map tijdelijk aan de `%PATH%` variabele toevoegen, waardoor Xidel toch gevonden kan worden. Dit kan op twee manieren:
- Vóór het gebruik van `xivid.bat` voer je deze commando iedere keer in.
- Voor een permanentere oplossing open je `xivid.bat` in een tekstverwerker en voeg je deze commando als nieuwe regel toe vóór `FOR %%A IN (xidel.exe) DO IF EXIST "%%~$PATH:A" (`. 

Deze `xidel.exe` heeft OpenSSL niet geïntegreerd en vereist daarom een aantal OpenSSL dll-bestanden in dezelfde map, `C:\Windows\System32`, of ergens in `%PATH%`:
- `libcrypto-1_1.dll` en `libssl-1_1.dll` uit de OpenSSL 1.1.1 reeks.
- of `libeay32.dll` en `ssleay32.dll` uit de verouderde OpenSSL 1.0.2 reeks.

Deze OpenSSL dll-bestanden heb ik zelf gecompileerd en kun je op [mijn website](http://rwijnsma.home.xs4all.nl/files/other/) vinden.

# Video rechtstreeks bekijken
## Linux
```sh
vlc $(./xivid.sh <url>)
```

## Windows
```bat
FOR /F %A IN ('xivid.bat <url>') DO vlc.exe %A
```

# Video downloaden
Ik raad aan om [FFmpeg](https://ffmpeg.org) te gebruiken voor het downloaden van audio- en video-bestanden. Voor dynamische (of adaptive) videostreams (`hls-#` / `dash-#`) heb je FFmpeg sowieso nodig, maar ook voor progressieve (of progressive/muxed) videostreams (`pg-#`) raad ik het aan, omdat sommige smart tv's niet alle gedownloade mp4-bestanden goed af kunnen spelen en vanwege '[overhead](https://nl.wikipedia.org/wiki/Overhead_%28informatica%29)'. Mp4-bestanden gedownload met FFmpeg kunnen een tot wel 7% kleinere bestandsgrootte hebben en smart tv's hebben er nagenoeg geen problemen mee.

- Linux binaries: https://johnvansickle.com/ffmpeg.
- Windows binaries: http://ffmpeg.zeranoe.com/builds.
- Windows XP:  

  Wat voor Xidel geldt, geldt ook voor FFmpeg. Als het geen andere beveiligingsbibliotheek aan boord heeft, dan kun je geen https-urls met TLS 1.2 encryptie/versleuteling openen. Daarnaast wordt Windows XP officieel ook niet meer ondersteund door FFmpeg.

  Sinds voorjaar 2017 ben ik daarom zelf FFmpeg gaan compileren. Mijn binaries zijn gecompileerd met de [mbedTLS](https://tls.mbed.org/) beveiligingsbibliotheek (volledig geïntegreerd), zijn Windows XP compatible én werken op oude cpu's zonder SSE2 instructies.
  - Windows XP binaries: http://rwijnsma.home.xs4all.nl/files/ffmpeg.
  - Github repo: https://github.com/Reino17/ffmpeg-windows-build-helpers.
  - Zeranoe forum thread: https://ffmpeg.zeranoe.com/forum/viewtopic.php?t=6930.

## Linux
```sh
ffmpeg -i $(./xivid.sh <url>) -c copy <bestandsnaam>
```

## Windows
```bat
FOR /F %A IN ('xivid.bat <url>') DO ffmpeg.exe -i %A -c copy <bestandsnaam>
```

# Videofragment downloaden
```
./xivid.sh -i https://www.npostart.nl/POMS_NOS_7332477
Naam:      NOS Journaal: STOP! Verkeerslicht voor telefoonverslaafde
Datum:     14-02-2017
Tijdsduur: 00:01:05
Begin:     00:09:02
Einde:     00:10:07
Formaten:  id     formaat         taal  resolutie  bitrate
           sub-1  vtt             nl
           hls-0  m3u8[manifest]
           hls-1  m3u8[aac]                        64kbps
           hls-2  m3u8[aac]                        128kbps
           hls-3  m3u8[h264+aac]        480x270    209|64kbps
           hls-4  m3u8[h264+aac]        640x360    517|128kbps
           hls-5  m3u8[h264+aac]        768x432    721|128kbps
           hls-6  m3u8[h264+aac]        1024x576   1027|128kbps (best)

Download:  ffmpeg -ss 540 -i <url> -ss 2 -t 65 [...]
```
Dit een voorbeeld van een speciaal soort videofragment. De video-urls (van alle formaten) zijn die van de hele aflevering. Als je dit videofragment op npostart.nl bekijkt, dan krijg je keurig een video van iets langer dan een minuut te zien. Als je 't echter wilt downloaden, dan zul je 't zelf op de juiste momenten uit moeten knippen. Gelukkig kan dit prima met FFmpeg en Xivid geeft je in dit geval de commando waarmee je dit kunt doen.

Als je de ondertiteling in dit geval ook wilt meenemen, dan kan dat, maar omdat Xivid geen directe optie heeft voor de ondertiteling, zul je de optie `-j` moeten gebruiken. Je krijgt de video-informatie dan als [JSON](https://nl.wikipedia.org/wiki/JSON) (hier iets ingekort):
```sh
./bashgemist.sh -j https://www.npostart.nl/POMS_NOS_7332477
{
  "name": "NOS Journaal: STOP! Verkeerslicht voor telefoonverslaafde",
  "date": "14-02-2017",
  "duration": "00:01:05",
  "start": "00:09:02",
  "end": "00:10:07",
  "formats": [
    {
      "id": "sub-1",
      "format": "vtt",
      "language": "nl",
      "label": "Nederlands",
      "url": "https://rs.poms.omroep.nl/v1/api/subtitles/POW_03373320/nl_NL/CAPTION.vtt"
    },
    {
      "id": "hls-0",
      "format": "m3u8[manifest]",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/[...]/vod/npo/usp/npo/hls_unencrypted/POW_03373320/POW_03373320_v4.ism/playlist.m3u8"
    },
    {
      "id": "hls-1",
      "format": "m3u8[aac]",
      "resolution": null,
      "bitrate": "64kbps",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/[...]/vod/npo/usp/npo/hls_unencrypted/POW_03373320/POW_03373320_v4.ism/POW_03373320_v4-audio=64000.m3u8"
    },
    [...]
    {
      "id": "hls-6",
      "format": "m3u8[h264+aac]",
      "resolution": "1024x576",
      "bitrate": "1027|128kbps",
      "url": "https://nl-ams-p6-am5.cdn.streamgate.nl/[...]/vod/npo/usp/npo/hls_unencrypted/POW_03373320/POW_03373320_v4.ism/POW_03373320_v4-audio=128000-video=1027000.m3u8"
    }
  ]
}
```
Met Xidel, of elk ander programma dat goed met JSONs overweg kan, kun je hier zo de ondertiteling-url uit halen.  
De uiteindelijke FFmpeg commando wordt dan:
```
ffmpeg -ss 540 -i <video-url> -ss 540 -i <ondertiteling-url> -ss 2 -t 65 -c copy -c:s srt -metadata:s:s language=dut <bestandsnaam>.mkv
```
Van de video- en ondertiteling-url wordt de eerste 9 minuten (540 seconden) overgeslagen. Daarna de resterende 2 seconden op iets nauwkeurigere wijze. Na 65 seconden gaat de schaar erin. De audio- en videostream worden (zonder kwaliteitsverlies) gekopieerd. De ondertiteling wordt geconverteerd van webvtt naar subrip en krijgt het label "Dutch". Ten slotte wordt alles in een mkv-container gestopt.

# Disclaimer
Omdat ik een Windows gebruiker ben kan het zijn dat de informatie hier omtrent Linux niet allemaal klopt, of niet volledig is. Mocht dat het geval zijn, laat het me dan gerust weten.
