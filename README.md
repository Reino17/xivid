BashGemist, een video extractie script.

- [Download](#download)
- [Xidel](#xidel)
- [Gebruik en opties](#gebruik-en-opties)
- [Voorbeelden](#voorbeelden)
- [Video rechtstreeks bekijken](#video-rechtstreeks-bekijken)
- [Video downloaden](#video-downloaden)
- [Videofragment downloaden](#videofragment-downloaden)
- [Disclaimer](#disclaimer)

# Download
```sh
git clone https://github.com/Reino17/bashgemist.git
```
Of download de [tarball](https://github.com/Reino17/bashgemist/archive/master.zip).

# Xidel
BashGemist heeft [Xidel](http://videlibri.sourceforge.net/xidel.html) nodig om te kunnen functioneren.<br>
Minimale vereiste is revisie `5651` `(xidel-0.9.7.20170825.5651.23300832bcbe)`.

## Linux
Download de Xidel [Linux binary](http://videlibri.sourceforge.net/xidel.html#downloads) en installeer Xidel in `/usr/bin`.<br>
Installeer vervolgens `openssl`, `openssl-dev` en `libcrypto` zodat Xidel beveiligde https-urls kan openen.

## Windows
BashGemist is een Linux Bash script, maar m.b.v. [Cygwin](https://www.cygwin.com/) is dit script ook in Windows te gebruiken.

Download en installeer [Cygwin](https://cygwin.com/install.html) en download de Xidel [Windows binary](http://videlibri.sourceforge.net/xidel.html#downloads).

Stel je hebt Cygwin geïnstalleerd in `C:\Cygwin\`, dan is het in principe genoeg om `xidel.exe` in `C:\Cygwin\bin` uit te pakken zodat BashGemist er gebruik van kan maken.<br>
Bewaar je `xidel.exe` liever ergens anders, omdat je er misschien zelf ook gebruik van wilt maken, dan kun je ook gebruik maken van een soort snelkoppeling die naar `xidel.exe` op die andere locatie verwijst.<br>
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
Deze snelkoppeling, dit bestand `xidel`, kun je nu voortaan gebruiken om Xidel te starten.<br>
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

Download de Xidel (**openssl**) [Windows binary](http://videlibri.sourceforge.net/xidel.html#downloads).<br>
Steeds meer websites maken gebruik van TLS 1.2 encryptie/versleuteling. In Windows XP gaat de ondersteuning hiervoor niet verder dan TLS 1.0. Http**s**-urls openen met de standaard Xidel Windows binary gaat in Windows XP daarom niet lukken. Met deze speciale Xidel binary omzeil je dit probleem door gebruik te maken van een andere beveiligingsbibliotheek (OpenSSL i.p.v. Windows's SChannel).<br>
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
(Gebruik `-h` of `--help` voor een actueel overzicht van ondersteunde websites.
)
## Linux
Start de Bash terminal, ga naar de map met `bashgemist.sh` en je kunt van start.

## Windows
Start de Bash terminal (`C:\Cygwin\Cygwin.bat`), ga naar de map met `bashgemist.sh` (in mijn geval `cd /cygdrive/d/Storage/Binaries/`) en ook hier kun je dan van start.

Als alternatief heb ik `bashgemist.bat` toegevoegd, waardoor je niet per se de Bash terminal hoeft te gebruiken. Hiermee worden Bash en `bashgemist.sh` op de achtergrond uitgevoerd.<br>
Start de Windows Command Prompt (`cmd.exe`) en ga naar de map met `bashgemist.bat` en `bashgemist.sh` (in mijn geval `D:` en `cd Storage\Binaries`).<br>
Het gebruik is dan vervolgens: `bashgemist.bat [optie] url`.

**\[Belangrijk\]** `bashgemist.bat`:
```bat
@ECHO off
SET PATH=C:\Cygwin\bin;%PATH%
bash.exe -c "./bashgemist.sh %*"
```
Standaard verwijst `bashgemist.bat` naar `C:\Cygwin\bin` voor alle Cygwin programma's. Verander dit eerst als je Cygwin ergens anders hebt geïnstalleerd!

# Voorbeelden
We nemen `https://www.npostart.nl/nos-journaal/01-01-2019/POW_04059321`, het NOS Journaal van 1 januari 2019 20:00u, als voorbeeld:
```sh
./bashgemist.sh https://www.npostart.nl/nos-journaal/01-01-2019/POW_04059321
https://adaptive-e50c3b.npostreaming.nl/urishieldv2/l27m4ed46ff85cb0a64d005c30a3ee000000.65560b094905392c010612d533fbae00/p/2a/10/10/5e/POW_04059321/POW_04059321.ism/POW_04059321-audio=192000-video=1790000.m3u8
```
Zonder optie/parameter geeft BashGemist de video-url van het beste formaat terug.

Heb je liever een ander formaat, dan zul je er eerst achter moeten komen welke formaten er allemaal beschikbaar zijn. Daar is de optie/parameter `-i` of `--info` voor:
```sh
./bashgemist.sh -i https://www.npostart.nl/nos-journaal/01-01-2019/POW_04059321
Naam:          NOS: NOS Journaal
Datum:         01-01-2019
Tijdsduur:     00:16:06
Gratis tot:    01-01-2101 00:59:00
Ondertiteling: http://tt888.omroep.nl/tt888/POW_04059321
Formaten:      formaat  extensie  resolutie  bitrate
               pg-1     m4v
               pg-2     m4v
               pg-3     m4v
               hls-0    m3u8      manifest
               hls-1    m3u8      480x270    v:200k   a:96k
               hls-2    m3u8      480x270    v:200k   a:128k
               hls-3    m3u8      480x270    v:200k   a:192k
               hls-4    m3u8      640x360    v:499k   a:96k
               hls-5    m3u8      640x360    v:499k   a:128k
               hls-6    m3u8      640x360    v:499k   a:192k
               hls-7    m3u8      1024x576   v:1094k  a:96k
               hls-8    m3u8      1024x576   v:1094k  a:128k
               hls-9    m3u8      1024x576   v:1094k  a:192k
               hls-10   m3u8      1024x576   v:1790k  a:96k
               hls-11   m3u8      1024x576   v:1790k  a:128k
               hls-12   m3u8      1024x576   v:1790k  a:192k  (best)
```
Zonder optie/parameter wordt het formaat `hls-12` gekozen. Als bijv. formaat `hls-8` voor jou ook voldoende is, dan kun je dat met `-f` of `--format` opgeven:
```sh
./bashgemist.sh -f hls-8 https://www.npostart.nl/POW_04059321
https://adaptive-e50c3b.npostreaming.nl/urishieldv2/l27m4ed46ff85cb0a64d005c30a3ee000000.65560b094905392c010612d533fbae00/p/2a/10/10/5e/POW_04059321/POW_04059321.ism/POW_04059321-audio=128000-video=1094000.m3u8
```
(BashGemist accepteert ook verkorte NPO programma-urls: `https://www.npostart.nl/[PRID]`)

# Video rechtstreeks bekijken
## Linux
We nemen `https://www.npostart.nl/live/npo-1`, de livestream van NPO 1, en [VLC media player](https://www.videolan.org/) als voorbeeld:
```sh
vlc $(./bashgemist.sh https://www.npostart.nl/live/npo-1)
```

## Windows
We nemen `https://www.npostart.nl/live/npo-1`, de livestream van NPO 1, en [Media Player Classic - Home Cinema](https://github.com/clsid2/mpc-hc/releases) (welke in `C:\Program Files\Media\MPC-HC` is geïnstalleerd) als voorbeeld.<br>
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
De progressieve videostreams (de formaten `pg-#` hierboven) kun je zo met je browser downloaden.<br>
Voor de dynamische (of adaptieve) videostreams (de formaten `hls-#` hierboven) heb je [FFmpeg](https://ffmpeg.org/) nodig om ze te kunnen downloaden.<br>
Toch zou ik adviseren om alle video's met FFMpeg te downloaden. Ten eerste omdat sommige smart tv's niet alle m4v/mp4-bestanden goed af kunnen spelen en ten tweede vanwege '[overhead](https://nl.wikipedia.org/wiki/Overhead_%28informatica%29)'. Dit kan wel tot een 7% kleinere bestandsgrootte leiden.

We nemen `https://www.rtl.nl/video/f2068013-ce22-34aa-94cb-1b1aaec8d1bd`, het RTL Nieuws van 1 januari 2019 19:30u, als voorbeeld.

## Linux
Download en installeer [FFmpeg](https://johnvansickle.com/ffmpeg/). Vervolgens:
```sh
ffmpeg -i $(./bashgemist.sh https://www.rtl.nl/video/f2068013-ce22-34aa-94cb-1b1aaec8d1bd) -c copy bestandsnaam.mp4
```

## Windows
Download [FFmpeg](http://ffmpeg.zeranoe.com/builds/).<br>
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
We nemen `https://www.npostart.nl/de-laatste-minuten/17-12-2018/POMS_AT_15009224`, een videofragment uit de laatste aflevering van het 3e seizoen van Hunted, als voorbeeld:
```sh
./bashgemist.sh -i https://www.npostart.nl/de-laatste-minuten/17-12-2018/POMS_AT_15009224
Naam:          AVROTROS: Hunted - De laatste minuten...
Datum:         17-12-2018
Tijdsduur:     00:01:59
Begin:         00:55:06
Einde:         00:57:05
Gratis tot:    01-01-2101 00:59:00
Ondertiteling: http://tt888.omroep.nl/tt888/AT_2105785
Formaten:      formaat  extensie  resolutie  bitrate
               pg-1     m4v
               pg-2     m4v
               pg-3     m4v
               hls-0    m3u8      manifest
               hls-1    m3u8      480x270    v:202k   a:96k
               hls-2    m3u8      480x270    v:202k   a:128k
               hls-3    m3u8      480x270    v:202k   a:192k
               hls-4    m3u8      640x360    v:504k   a:96k
               hls-5    m3u8      640x360    v:504k   a:128k
               hls-6    m3u8      640x360    v:504k   a:192k
               hls-7    m3u8      1024x576   v:1109k  a:96k
               hls-8    m3u8      1024x576   v:1109k  a:128k
               hls-9    m3u8      1024x576   v:1109k  a:192k
               hls-10   m3u8      1024x576   v:1813k  a:96k
               hls-11   m3u8      1024x576   v:1813k  a:128k
               hls-12   m3u8      1024x576   v:1813k  a:192k  (best)

Download:      ffmpeg -ss 00:55:00 -i [url] -ss 00:00:06 -t 00:01:59 [...]
```
Als je deze video op npostart.nl terugkijkt, dan bekijk je een videofragment van bijna 2 minuten lang die begint op iets meer dan 55 minuten vanaf het begin. Echter, de video-urls (van alle formaten) zijn die van de hele aflevering. Gelukkig kun je met FFmpeg een begintijd en een tijdsduur opgeven om op die manier een videofragment eruit te knippen.<br>
In dit geval willen we ook de ondertiteling graag meenemen **in** het videobestand en deze de voorgestelde naam + datum geven.

BashGemist is een video extractie script en geeft (al dan niet met `-f` of `--format`) alleen de video-url terug. Toch zijn er met de optie/parameter `-j` of `--json` meer mogelijkheden. De video informatie hierboven wordt hiermee teruggegeven als [JSON](https://nl.wikipedia.org/wiki/JSON); het formaat waarin BashGemist ook alles verwerkt (hieronder iets ingekort):
```sh
./bashgemist.sh -j https://www.npostart.nl/POMS_AT_15009224
{
  "name": "AVROTROS: Hunted - De laatste minuten...",
  "date": "17-12-2018",
  "duration": "00:01:59",
  "start": "00:55:06",
  "end": "00:57:05",
  "expdate": "01-01-2101 00:59:00",
  "subtitle": "http://tt888.omroep.nl/tt888/AT_2105785",
  "formats": [
    {
      "format": "pg-1",
      "extension": "m4v",
      "url": "https://content10c4b.omroep.nl/urishieldv2/l27m6c2ec29c3fcf372e005c276570000000.b055f6717fc4e0b8ea2ae9042d1291e2/ceresodi/h264/p/06/10/10/f7/sb_AT_2105785.m4v"
    },
    {
      "format": "pg-2",
      "extension": "m4v",
      "url": "https://content10c4c.omroep.nl/urishieldv2/l27m34ec48023fb78477005c276570000000.171fddf89df4a5190ac631f86a056b63/ceresodi/h264/p/06/10/10/f7/bb_AT_2105785.m4v"
    },
    {
      "format": "pg-3",
      "extension": "m4v",
      "url": "https://content10c4a.omroep.nl/urishieldv2/l27m3187fe3c262e9d50005c276570000000.d1015a8a55fc8f98ef42e675570af912/ceresodi/h264/p/06/10/10/f7/std_AT_2105785.m4v"
    },
    {
      "format": "hls-0",
      "extension": "m3u8",
      "resolution": "manifest",
      "url": "https://adaptive-e10c4a.npostreaming.nl/urishieldv2/l27m1f18e65b7d86dd64005c276570000000.3ef7e652a756367aa5d38a4933f1a866/p/06/10/10/5d/AT_2105785/AT_2105785.ism/AT_2105785.m3u8"
    },
    [...],
    {
      "format": "hls-12",
      "extension": "m3u8",
      "resolution": "1024x576",
      "vbitrate": "v:1813k",
      "abitrate": "a:192k",
      "url": "https://adaptive-e10c4a.npostreaming.nl/urishieldv2/l27m1f18e65b7d86dd64005c276570000000.3ef7e652a756367aa5d38a4933f1a866/p/06/10/10/5d/AT_2105785/AT_2105785.ism/AT_2105785-audio=192000-video=1813000.m3u8"
    }
  ]
}
```

Dit is waar je Xidel heel goed voor kunt gebruiken.

## Linux
De door BashGemist gegenereerde JSON 'pipen' we naar Xidel en deze geeft alle informatie terug van de JSON attributen die we opgeven:
```sh
xidel -s - -e '
  $json/(
    name,
    date,
    duration,
    start,
    subtitle,
    (formats)()[format="hls-12"]/url
  )' <<< $(./bashgemist.sh -j https://www.npostart.nl/POMS_AT_15009224)
AVROTROS: Hunted - De laatste minuten...
17-12-2018
00:01:59
00:55:06
http://tt888.omroep.nl/tt888/AT_2105785
https://adaptive-e10c4a.npostreaming.nl/urishieldv2/l27m1f18e65b7d86dd64005c276570000000.3ef7e652a756367aa5d38a4933f1a866/p/06/10/10/5d/AT_2105785/AT_2105785.ism/AT_2105785-audio=192000-video=1813000.m3u8
```
In een bestandsnaam mag geen `:` voorkomen, dus die vervangen we voor een `-`. Daar plakken we de datum achter met haakjes er omheen, maar zonder streepjes. Vervolgens splitten we de begintijd nog in tweeën; de begintijd afgerond op 30 seconden en de resterende seconden. (Met de `00:55:00` vóór FFmpeg's input `-i [url]` slaat FFmpeg de eerste 55 minuten **snel** over. Met de `00:00:06` (of `6`) daarna zoekt FFmpeg de resterende 6 seconden **nauwkeurig** naar het juiste punt.)
```sh
xidel -s - -e '
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
    subtitle,
    (formats)()[format="hls-12"]/url
  )' <<< $(./bashgemist.sh -j https://www.npostart.nl/POMS_AT_15009224)
AVROTROS- Hunted - De laatste minuten... (17122018)
00:01:59
00:55:00
6
http://tt888.omroep.nl/tt888/AT_2105785
https://adaptive-e10c4a.npostreaming.nl/urishieldv2/l27m1f18e65b7d86dd64005c276570000000.3ef7e652a756367aa5d38a4933f1a866/p/06/10/10/5d/AT_2105785/AT_2105785.ism/AT_2105785-audio=192000-video=1813000.m3u8
```
Met deze informatie kun je nu een FFmpeg commando samenstellen. Dit kan op 3 manieren:
- Exporteer de informatie als variabelen en raadpleeg die daarna in een aparte FFmpeg commando:
```sh
eval "$(xidel -s - -e '
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
    sub:=subtitle,
    url:=(formats)()[format="hls-12"]/url
  )' --output-format=bash <<< $(./bashgemist.sh -j https://www.npostart.nl/POMS_AT_15009224)
)"

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
-ss 00:55:00 -i https://adaptive-e10c4a.npostreaming.nl/urishieldv2/[...].m3u8 \
-ss 00:55:00 -i http://tt888.omroep.nl/tt888/AT_2105785 \
-ss 6 -t 00:01:59 \
-c copy \
-c:s srt -metadata:s:s language=dut \
"AVROTROS- Hunted - De laatste minuten... (17122018).mkv"
```
FFmpeg opent de video-url en de ondertiteling-url en slaat de eerste 55 minuten en 6 seconden over. Na 1 minuut en 59 seconden gaat weer de schaar erin. De audio- en videostream worden gekopieerd. De ondertiteling wordt geconverteerd van webvtt naar subrip en wordt gelabeld als Nederlands. Ten slotte wordt alles in een mkv-container gestopt.

---
- Gebruik interne variabelen en gebruik Xidel's `system()` om FFmpeg vanuit Xidel aan te roepen:
```sh
xidel -s - -e '
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
        $sub:=subtitle,
        $url:=(formats)()[format="hls-12"]/url
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
  )' <<< $(./bashgemist.sh -j https://www.npostart.nl/POMS_AT_15009224)
```
- Gebruik Xidel's `system()` om FFmpeg vanuit Xidel aan te roepen met alle informatie rechtstreeks uit de JSON:
```sh
xidel -s - -e '
  $json/(
    system(
      x"bash -c ""ffmpeg \
        -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration("PT1S"))} \
        -i  {(formats)()[format="hls-12"]/url} \
        -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration("PT1S"))} \
        -i  {subtitle} \
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
  )' <<< $(./bashgemist.sh -j https://www.npostart.nl/POMS_AT_15009224)
```

## Windows
- Exporteer de informatie als variabelen en raadpleeg die daarna in een aparte FFmpeg commando:
```bat
FOR /F "delims=" %A IN ('bashgemist.bat -j https://www.npostart.nl/POMS_AT_15009224 ^| xidel.exe -s - -e ^"
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
    sub:^=subtitle^,
    url:^=^(formats^)^(^)[format^='hls-12']/url
  ^)^" --output-format^=cmd
') DO %A

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
bashgemist.bat -j https://www.npostart.nl/POMS_AT_15009224 | xidel.exe -s - -e ^" ^
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
        $sub:=subtitle, ^
        $url:=(formats)()[format='hls-12']/url ^
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
  )^"
```
- Gebruik Xidel's `system()` om FFmpeg vanuit Xidel aan te roepen met alle informatie rechtstreeks uit de JSON:
```sh
bashgemist.bat -j https://www.npostart.nl/POMS_AT_15009224 | xidel.exe -s - -e ^" ^
  $json/( ^
    system( ^
      x'ffmpeg.exe ^
      -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration('PT1S'))} ^
      -i  {(formats)()[format='hls-12']/url} ^
      -ss {time(start) - (seconds-from-time(start) mod 30 * dayTimeDuration('PT1S'))} ^
      -i  {subtitle} ^
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
  )^"
```

# Disclaimer
Omdat ik een Windows gebruiker ben kan het zijn dat niet alle informatie hierboven omtrent Linux klopt, of niet volledig is. Laat me dat gerust weten mocht dat het geval zijn.