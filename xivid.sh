#!/bin/bash
# --------------------------------
# Xivid bash script
# --------------------------------
#
# Copyright (C) 2023 Reino Wijnsma
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Reino Wijnsma (rwijnsma@xs4all.nl)
# https://github.com/Reino17/xivid

help() {
  cat <<EOF
Xivid, een video-url extractie script.
Gebruik: ./xivid.sh [optie] url

  -f id[+id]    Toon specifiek formaat, of specifieke formaten.
                Met een id dat eindigt op een '$' wordt het formaat
                met het hoogste nummer getoond.
                Zonder optie wordt het formaat met de hoogste
                resolutie en/of bitrate getoond.
  -i            Toon video informatie, incl. een opsomming van alle
                beschikbare formaten.
  -j            Toon video informatie als JSON.

Ondersteunde websites:
  npostart.nl             omroepwest.nl       vimeo.com
  gemi.st                 rijnmond.nl         dailymotion.com
  radioplayer.npo.nl      rtvutrecht.nl       rumble.com
  nos.nl                  gld.nl              odysee.com
  tvblik.nl               omroepzeeland.nl    reddit.com
  uitzendinggemist.net    omroepbrabant.nl    redd.it
  rtl.nl                  l1.nl               twitch.tv
  rtlxl.nl                dumpert.nl          mixcloud.com
  rtlnieuws.nl            autojunk.nl         soundcloud.com
  kijk.nl                 abhd.nl             facebook.com
  omropfryslan.nl         autoblog.nl         fb.watch
  rtvnoord.nl             telegraaf.nl        instagram.com
  rtvdrenthe.nl           ad.nl               twitter.com
  nhnieuws.nl             lc.nl               pornhub.com
  at5.nl                  youtube.com         xhamster.com
  omroepflevoland.nl      youtu.be            youporn.com
  rtvoost.nl

Voorbeelden:
  ./xivid.sh https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
  ./xivid.sh -i https://www.rtlxl.nl/programma/rtl-nieuws/bf475894-02ce-3724-9a6f-91de543b8a4c
  ./xivid.sh -f hls-$+sub-1 https://kijk.nl/video/AgvoU4AJTpy
EOF
}

if command -v xidel >/dev/null; then
  if [[ $(xidel --version | xidel -s - -e 'extract($raw,"\d{8}")') -ge 20230503 ]]; then
    export XIDEL_OPTIONS="--silent --module=${0%/*}/xivid.xqm"
  else
    cat 1>&2 <<EOF
xivid: '$(command -v xidel)' gevonden, maar versie is te oud.
Installeer Xidel 0.9.9.8787 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
    exit 1
  fi
else
  cat 1>&2 <<EOF
xivid: 'xidel' niet gevonden!
Installeer Xidel 0.9.9.8787 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
  exit 1
fi

while true; do
  re='^https?://[-A-Za-z0-9\+&@#/%?=~_|!:,.;$]*[-A-Za-z0-9\+&@#/%=~_|]$'
  case $1 in
    -h)
      help
      exit
      ;;
    -f)
      if [[ $3 ]]; then
        if [[ $2 ]]; then
          f=$2
          shift
        else
          echo "xivid: formaat id ontbreekt." 1>&2
          exit 1
        fi
      elif [[ $2 ]]; then
        if [[ $2 =~ $re ]]; then
          echo "xivid: formaat id ontbreekt." 1>&2
          exit 1
        else
          echo "xivid: url ontbreekt." 1>&2
          exit 1
        fi
      else
        echo "xivid: formaat id en url ontbreken." 1>&2
        exit 1
      fi
      ;;
    -i)
      if [[ $2 ]]; then
        i=1
      else
        echo "xivid: url ontbreekt." 1>&2
        exit 1
      fi
      ;;
    -j)
      if [[ $2 ]]; then
        j=1
      else
        echo "xivid: url ontbreekt." 1>&2
        exit 1
      fi
      ;;
    -*)
      echo "xivid: optie '$1' ongeldig." 1>&2
      exit 1
      ;;
    *)
      if [[ -z $@ ]]; then
        echo "xivid: url ontbreekt." 1>&2
        echo "Typ -h voor een lijst met alle opties." 1>&2
        exit 1
      elif [[ $1 =~ $re ]]; then
        url=$1
      else
        echo "xivid: url ongeldig." 1>&2
        exit 1
      fi
      break
  esac
  shift
done

eval "$(
  xidel -e '
    let $extractors:={
          "npo":array{"npostart.nl","gemi.st","radioplayer.npo.nl"},
          "nos":array{"nos.nl"},
          "rtl":array{"rtl.nl","rtlxl.nl","rtlnieuws.nl"},
          "kijk":array{"kijk.nl"},
          "tvblik":array{"tvblik.nl","uitzendinggemist.net"},
          "regiogroei":array{
            "omropfryslan.nl","rtvnoord.nl","rtvdrenthe.nl",
            "rtvoost.nl","omroepwest.nl","rijnmond.nl",
            "rtvutrecht.nl","gld.nl","omroepzeeland.nl"
          },
          "obr":array{"omroepbrabant.nl"},
          "l1":array{"l1.nl"},
          "nhnieuws":array{"nhnieuws.nl","at5.nl"},
          "ofl":array{"omroepflevoland.nl"},
          "dumpert":array{"dumpert.nl"},
          "autojunk":array{"autojunk.nl"},
          "abhd":array{"abhd.nl"},
          "autoblog":array{"autoblog.nl"},
          "telegraaf":array{"telegraaf.nl"},
          "ad":array{"ad.nl"},
          "lc":array{"lc.nl"},
          "youtube":array{"youtube.com","youtu.be"},
          "vimeo":array{"vimeo.com"},
          "dailymotion":array{"dailymotion.com"},
          "rumble":array{"rumble.com"},
          "odysee":array{"odysee.com"},
          "reddit":array{"reddit.com","redd.it"},
          "twitch":array{"twitch.tv"},
          "mixcloud":array{"mixcloud.com"},
          "soundcloud":array{"soundcloud.com"},
          "facebook":array{"facebook.com","fb.watch"},
          "twitter":array{"twitter.com"},
          "instagram":array{"instagram.com"},
          "pornhub":array{"pornhub.com"},
          "xhamster":array{"xhamster.com"},
          "youporn":array{"youporn.com"}
        },
        $host:=request-decode("'$url'")/host
    for $x in $extractors() return
    if (matches($host,join($extractors($x)(),"|")))
    then (
      json:=eval(`xivid:{$x}("'$url'")`),
      extractor:=$x,
      fmts:=$json/(formats)()/id
    )
    else ()
  ' --output-format=bash
)"

if [[ ! $extractor ]]; then
  echo "xivid: url wordt niet ondersteund." 1>&2
  exit 1
fi
if [[ ! $json ]]; then
  echo "xivid: geen video(-informatie) beschikbaar." 1>&2
  exit 1
fi

if [[ $f ]]; then
  if [[ ${fmts[@]} ]]; then
    for a in ${f/+/ }; do
      if [[ ${a: -1} == \$ ]]; then
        if [[ ! ${fmts[@]} =~ ${a:0: -1} ]]; then
          echo "xivid: formaat id '$a' ongeldig." 1>&2
          exit 1
        fi
      else
        if [[ ! ${fmts[@]} =~ $a ]]; then
          echo "xivid: formaat id '$a' ongeldig." 1>&2
          exit 1
        fi
      fi
    done
    xidel -e '
      for $x in tokenize("'$f'","\+") return
      if (ends-with($x,"$")) then
        $json/(formats)()[starts-with(id,substring($x,1,string-length($x) - 1))][last()]/url
      else
        $json/(formats)()[id=$x]/url
    ' <<< $json
  else
    echo "xivid: geen video beschikbaar." 1>&2
    exit 1
  fi
elif [[ $i ]]; then
  xidel -e 'xivid:info($json)' <<< $json
elif [[ $j ]]; then
  xidel -e '$json' <<< $json
elif [[ ${fmts[@]} ]]; then
  xidel -e '$json/(formats)()[last()]/url' <<< $json
else
  echo "xivid: geen video beschikbaar." 1>&2
  exit 1
fi
exit
