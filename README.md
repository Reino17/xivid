# Xivid
Xivid, *'xivid.xqm'*, is een XQuery Module voor het commandoregel programma `xidel` en bevat functies om de url van een video op verscheidene websites te kunnen achterhalen.  
Voor gemakkelijk gebruik zijn er ook twee commandoregel-scripts: *'xivid.bat'* voor Windows `cmd` en *'xivid.sh'* voor Linux `bash`.

In deze readme lees je wat er voor nodig is om de scripts te kunnen gebruiken.  
Raadpleeg de [**wiki**](https://github.com/Reino17/xivid/wiki) voor gebruiks voorbeelden van zowel de scripts als de XQuery Module met `xidel`.

## Download
```
git clone https://github.com/Reino17/xivid.git
```
Of download de [tarball](https://github.com/Reino17/xivid/archive/master.zip).

## Vereiste
[Xidel](http://videlibri.sourceforge.net/xidel.html) is een commandoregel programma en een waar Zwitsers zakmes voor het downloaden en informatie onttrekken van HTML/XML pagina's, JSON-APIs en lokale bestanden door gebruik te maken van XPath 3.1, XQuery 3.1, JSONiq, CSS, of pattern templates.

Beide scripts maken veelvuldig gebruik van `xidel` (i.c.m. `xivid.xqm`) en is dus essentieel. Minimale vereiste versie is `xidel 0.9.9-7941`. Op Xidel's website vind je onder het kopje "Downloads" een url voor deze "0.9.9 development" reeks.

Als alternatief kun je Xidel Windows binaries ook op [mijn website](https://rwijnsma.home.xs4all.nl/files/xidel) vinden. Deze zijn meer dan 3 keer zo klein omdat ik, i.t.t de originele binaries, de voor normaal gebruik overbodige "[debug symbols](https://en.wikipedia.org/wiki/Debug_symbol)" heb verwijderd.

### Windows

Plaats `xidel.exe` in dezelfde map als `xivid.bat`, `C:\Windows\system32`, of ergens anders in `%PATH%`. 

Pak je `xidel.exe` liever ergens anders uit, maar staat deze map niet in `%PATH%`, dan kun je deze map tijdelijk aan de `%PATH%` variabele toevoegen door `xivid.bat` in een tekstverwerker te openen en `SET "PATH=%PATH%;%~dp0"` te veranderen in `SET "PATH=%PATH%;X:\<andere-map>"`.  
Op Windows Vista en nieuwer kun je ook een [symbolic link](https://en.wikipedia.org/wiki/Symbolic_link#Microsoft_Windows) aanmaken zodat `xidel.exe` toch gevonden kan worden:
```
mklink -s X:\<andere-map>\xidel.exe C:\Windows\system32\xidel.exe
```
---

Ondersteuning voor het [TLS encryptie-protocol](https://nl.wikipedia.org/wiki/Transport_Layer_Security) gaat in Windows XP niet verder dan versie 1.0, terwijl bijna alle websites tegenwoordig minimaal gebruik maken van TLS 1.2. Hierdoor gaat het openen van http**s**-urls met de standaard Xidel Windows binary in Windows XP niet lukken.

Er is ook een speciale Xidel Windows binary die voor https-urls, net als de Linux binary, gebruik maakt van de [OpenSSL](https://www.openssl.org) beveiligingsbibliotheek, welke wel de nieuwste TLS encryptie-protocollen ondersteund. Ideaal voor Windows XP gebruikers.  
Deze Xidel Windows OpenSSL binary kan echter ook uitkomst bieden voor gebruikers van nieuwere Windows versies. Op Windows 7 heb ik al eens ondervonden dat de gewone Xidel Windows binary (gebruik makend van de Windows [SChannel](https://docs.microsoft.com/en-us/windows/win32/secauthn/secure-channel) beveiligingsbibliotheek) bepaalde urls niet kon openen, maar de OpenSSL variant wel.

Deze `xidel.exe` heeft OpenSSL niet geïntegreerd en vereist daarom een aantal OpenSSL dll-bestanden in dezelfde map, `C:\Windows\system32`, of ergens in `%PATH%`:
- `libcrypto-1_1.dll` en `libssl-1_1.dll` uit de OpenSSL 1.1.1 reeks.
- of `libeay32.dll` en `ssleay32.dll` uit de verouderde OpenSSL 1.0.2 reeks.

Je kunt deze OpenSSL dll-bestanden [hier](https://wiki.openssl.org/index.php/Binaries) vinden, of op [mijn website](https://rwijnsma.home.xs4all.nl/files/openssl) (zelf gecompileerd).

### Linux

Plaats `xidel` in `/usr/bin`, of ergens anders in `$PATH`. Installeer vervolgens `openssl`, `openssl-dev` en `libcrypto` zodat Xidel beveiligde http**s**-urls kan openen.

Installeer je `xidel` liever ergens anders, maak dan een [symlink](https://en.wikipedia.org/wiki/Symbolic_link#POSIX_and_Unix-like_operating_systems) aan zodat `xidel` toch gevonden kan worden:
```
ln -s /<andere-map>/xidel /usr/bin/xidel
```

## Opties
```
Gebruik (Windows): xivid.bat [optie] url
Gebruik (Linux):  ./xivid.sh [optie] url

-f id[+id]    Toon specifiek formaat, of specifieke formaten.
              Met een id dat eindigt op een '$' wordt het formaat
              met het hoogste nummer getoond.
              Zonder optie wordt het formaat met de hoogste
              resolutie en/of bitrate getoond.
-i            Toon video informatie, incl. een opsomming van alle
              beschikbare formaten.
-j            Toon video informatie als JSON.
```
Deze websites worden op dit moment ondersteund:
```
npostart.nl             omroepwest.nl          vimeo.com
gemi.st                 rijnmond.nl            dailymotion.com
nos.nl                  rtvutrecht.nl          rumble.com
tvblik.nl               omroepgelderland.nl    reddit.com
uitzendinggemist.net    omroepzeeland.nl       redd.it
rtl.nl                  omroepbrabant.nl       twitch.tv
rtlxl.nl                l1.nl                  mixcloud.com
rtlnieuws.nl            dumpert.nl             soundcloud.com
kijk.nl                 autojunk.nl            facebook.com
omropfryslan.nl         abhd.nl                fb.watch
rtvnoord.nl             autoblog.nl            instagram.com
rtvdrenthe.nl           telegraaf.nl           twitter.com
nhnieuws.nl             ad.nl                  pornhub.com
at5.nl                  lc.nl                  xhamster.com
omroepflevoland.nl      youtube.com            youporn.com
rtvoost.nl              youtu.be
```
Xivid is een hobbyproject en is constant in ontwikkeling. Houd er daarom rekening mee dat per website niet alle type urls altijd ondersteund worden.  
De video-urls van beveiligde video's (met DRM (Digital Rights Manangement), of anderzijds) worden niet weergegeven.

Voor bug reports en verzoeken ga naar https://github.com/Reino17/xivid/issues. Geen garanties.

## Disclaimer
Omdat ik een Windows gebruiker ben kan het zijn dat de informatie hier omtrent Linux niet allemaal klopt, of niet volledig is. Mocht dat het geval zijn, laat het me dan gerust weten.
