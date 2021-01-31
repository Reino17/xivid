#!/bin/bash
# --------------------------------
# Xivid bash script
# --------------------------------
#
# Copyright (C) 2020 Reino Wijnsma
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

  -f ID[+ID]    Selecteer specifiek formaat, of specifieke formaten.
                Met een ID dat eindigt op een '#' wordt het formaat
                met het hoogste nummer geselecteerd.
                Zonder opgave wordt het formaat met de hoogste
                resolutie en/of bitrate geselecteerd.
  -i            Toon video informatie, incl. een opsomming van alle
                beschikbare formaten.
  -j            Toon video informatie als JSON.

Ondersteunde websites:
  npostart.nl             omropfryslan.nl       omroepwest.nl
  gemi.st                 rtvnoord.nl           rijnmond.nl
  nos.nl                  rtvdrenthe.nl         rtvutrecht.nl
  tvblik.nl               nhnieuws.nl           omroepgelderland.nl
  uitzendinggemist.net    at5.nl                omroepzeeland.nl
  rtlxl.nl                omroepflevoland.nl    omroepbrabant.nl
  kijk.nl                 rtvoost.nl            l1.nl

  dumpert.nl              vimeo.com             twitter.com
  autojunk.nl             dailymotion.com       pornhub.com
  telegraaf.nl            twitch.tv
  ad.nl                   mixcloud.com
  lc.nl                   soundcloud.com
  youtube.com             facebook.com
  youtu.be                fb.watch

Voorbeelden:
  ./xivid.sh https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
  ./xivid.sh -i https://www.rtlxl.nl/programma/rtl-nieuws/bf475894-02ce-3724-9a6f-91de543b8a4c
  ./xivid.sh -f hls-#+sub-1 https://kijk.nl/video/AgvoU4AJTpy
EOF
}

nos() {
  eval "$(xidel "$1" -e '
    let $a:=json(
      //script[ends-with(@data-ssr-name,"VideoPlayer") or @data-ssr-name="pages/Article/Article"]
    )/(.//video,.)[1] return
    json:=if (//video/@data-type="livestream") then {
      "name":concat(
        "NOS: ",
        //h1[ends-with(@class,"__title")],
        " Livestream"
      ),
      "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json(//@data-stream)
    } else {
      "name":"NOS: "||$a/title,
      "date":format-date(
        dateTime(
          replace(
            ($a/published_at,//@datetime)[1],
            "(.+)(\d{2})",
            "$1:$2"
          )
        ),
        "[D01]-[M01]-[Y]"
      ),
      "duration":$a/duration * duration("PT1S") + time("00:00:00"),
      "formats":xivid:m3u8-to-json($a/(formats)(1)/url/mp4)
    }
  ' --output-format=bash)"
}

twitch() {
  eval "$(xidel "$1" --xquery '
    declare variable $id:=extract($url,".+/(.+)",1);
    declare variable $cid:="kimne78kx3ncx6brgo4mv6wki5h1ko";
    json:=if ($id castable as integer) then
      let $a:=x:request({
            "headers":"Client-ID: "||$cid,
            "url":"https://api.twitch.tv/kraken/videos/"||$id
          })/json,
          $b:=x:request({
            "headers":"Client-ID: "||$cid,
            "url":concat("http://api.twitch.tv/api/vods/",$id,"/access_token")
          })/json
      return {
        "name":"Twitch: "||$a/title,
        "date":format-date(
          dateTime($a/published_at),
          "[D01]-[M01]-[Y]"
        ),
        "duration":format-time(
          $a/length * duration("PT1S"),
          "[H01]:[m01]:[s01]"
        ),
        "formats":xivid:m3u8-to-json(
          concat(
            "https://usher.ttvnw.net/vod/",
            $id,
            ".m3u8?allow_source=true&amp;allow_audio_only=true&amp;allow_spectre=true&amp;player=twitchweb&amp;sig=",
            $b/sig,
            "&amp;token=",
            uri-encode($b/token)
          )
        )
      }
    else
      let $a:=x:request({
            "headers":"Client-ID: "||$cid,
            "url":concat("http://api.twitch.tv/kraken/streams/",$id,"?stream_type=all")
          })/json,
          $b:=x:request({
            "headers":"Client-ID: "||$cid,
            "url":concat("http://api.twitch.tv/api/channels/",$id,"/access_token")
          })/json
      return {
        "name":"Twitch: "||$a//status,
        "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
        "formats":xivid:m3u8-to-json(
          concat(
            "https://usher.ttvnw.net/api/channel/hls/",
            $id,
            ".m3u8?allow_source=true&amp;allow_audio_only=true&amp;allow_spectre=true&amp;p=",
            random-seed(),
            random(1000000),
            "&amp;player=twitchweb&amp;segment_preference=4&amp;sig=",
            $b/sig,
            "&amp;token=",
            uri-encode($b/token)
          )
        )
      }
  ' --output-format=bash)"
}

twitter() {
  eval "$(xidel "$1" -e '
    declare variable $head:="Authorization: Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw";
    let $a:=x:request({
          "method":"POST",
          "headers":$head,
          "url":"https://api.twitter.com/1.1/guest/activate.json"
        })/json/guest_token,
        $b:=x:request({
          "headers":($head,"x-guest-token: "||$a),
          "url":"https://api.twitter.com/1.1/"||(
            if (//@data-supports-broadcast-player) then
              concat("broadcasts/show.json?ids=",extract(//@data-expanded-url,".+/(.+)",1))
            else
              concat("videos/tweet/config/",//@data-associated-tweet-id,".json")
          )
        })/json
    return
    json:={
      "name"://title,
      "date":format-date(
        //div[@class="permalink-header"]//@data-time * duration("PT1S") +
        implicit-timezone() + date("1970-01-01"),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        round(($b//durationMs,$b//end_ms - $b//start_ms) div 1000) * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":array{
        if ($b/broadcasts) then
          {
            "id":"hls-1",
            "format":"m3u8[h264+aac]",
            "resolution":concat($b//width,"x",$b//height),
            "url":x:request({
              "headers":($head,"x-guest-token: "||$a),
              "url":"https://api.twitter.com/1.1/live_video_stream/status/"||$b//media_key
            })//location
          }
        else
          xivid:m3u8-to-json($b//playbackUrl)
      }
    }
  ' --output-format=bash)"
}

if command -v xidel >/dev/null; then
  if [[ $(xidel --version | xidel - -se 'extract($raw,"\d{8}")') -ge 20200726 ]]; then
    export XIDEL_OPTIONS="--silent --module=${0%/*}/xivid.xqm"
  else
    cat 1>&2 <<EOF
xivid: '$(command -v xidel)' gevonden, maar versie is te oud.
Installeer Xidel 0.9.9.7433 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
    exit 1
  fi
else
  cat 1>&2 <<EOF
xivid: 'xidel' niet gevonden!
Installeer Xidel 0.9.9.7433 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
  exit 1
fi

while true; do
  re='^https?://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
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

if [[ $url =~ (npostart.nl|gemi.st) ]]; then
  if [[ $url =~ npostart.nl/live ]]; then
    echo "xivid: url wordt niet ondersteund." 1>&2
    exit 1
  fi
  eval "$(xidel -e 'json:=xivid:npo("'$url'")' --output-format=bash)"
elif [[ $url =~ nos.nl ]]; then
  nos "$url"
elif [[ $url =~ (tvblik.nl|uitzendinggemist.net) ]]; then
  eval "$(xidel -e 'json:=xivid:tvblik("'$url'")' --output-format=bash)"
elif [[ $url =~ rtlxl.nl|rtlnieuws.nl ]]; then
  eval "$(xidel -e 'json:=xivid:rtl("'$url'")' --output-format=bash)"
elif [[ $url =~ kijk.nl ]]; then
  eval "$(xidel -e 'json:=xivid:kijk("'$url'")' --output-format=bash)"
elif [[ $url =~ (omropfryslan.nl|rtvnoord.nl|rtvdrenthe.nl|rtvoost.nl|omroepwest.nl|rijnmond.nl|rtvutrecht.nl|omroepgelderland.nl|omroepzeeland.nl|omroepbrabant.nl|l1.nl) ]]; then
  eval "$(xidel -e 'json:=xivid:regio("'$url'")' --output-format=bash)"
elif [[ $url =~ (nhnieuws.nl|at5.nl) ]]; then
  eval "$(xidel -e 'json:=xivid:nhnieuws("'$url'")' --output-format=bash)"
elif [[ $url =~ omroepflevoland.nl ]]; then
  eval "$(xidel -e 'json:=xivid:ofl("'$url'")' --output-format=bash)"
elif [[ $url =~ dumpert.nl ]]; then
  eval "$(xidel -e 'json:=xivid:dumpert("'$url'")' --output-format=bash)"
elif [[ $url =~ autojunk.nl ]]; then
  eval "$(xidel -e 'json:=xivid:autojunk("'$url'")' --output-format=bash)"
elif [[ $url =~ telegraaf.nl ]]; then
  eval "$(xidel -e 'json:=xivid:telegraaf("'$url'")' --output-format=bash)"
elif [[ $url =~ ad.nl ]]; then
  eval "$(xidel -e 'json:=xivid:ad("'$url'")' --output-format=bash)"
elif [[ $url =~ lc.nl ]]; then
  eval "$(xidel -e 'json:=xivid:lc("'$url'")' --output-format=bash)"
elif [[ $url =~ (youtube.com|youtu.be) ]]; then
  eval "$(xidel -e 'json:=xivid:youtube("'$url'")' --output-format=bash)"
elif [[ $url =~ vimeo.com ]]; then
  eval "$(xidel -e 'json:=xivid:vimeo("'$url'")' --output-format=bash)"
elif [[ $url =~ dailymotion.com ]]; then
  eval "$(xidel -e 'json:=xivid:dailymotion("'$url'")' --output-format=bash)"
elif [[ $url =~ twitch.tv ]]; then
  twitch "$url"
elif [[ $url =~ mixcloud.com ]]; then
  eval "$(xidel -e 'json:=xivid:mixcloud("'$url'")' --output-format=bash)"
elif [[ $url =~ soundcloud.com ]]; then
  eval "$(xidel -e 'json:=xivid:soundcloud("'$url'")' --output-format=bash)"
elif [[ $url =~ facebook.com|fb.watch ]]; then
  eval "$(xidel -e 'json:=xivid:facebook("'$url'")' --output-format=bash)"
elif [[ $url =~ twitter.com ]]; then
  twitter "$url"
elif [[ $url =~ instagram.com ]]; then
  eval "$(xidel -e 'json:=xivid:instagram("'$url'")' --output-format=bash)"
elif [[ $url =~ pornhub.com ]]; then
  eval "$(xidel -e 'json:=xivid:pornhub("'$url'")' --output-format=bash)"
else
  echo "xivid: url wordt niet ondersteund." 1>&2
  exit 1
fi

if [[ $json ]]; then
  fmts=($(xidel - -e 'join($json/(formats)()/id)' <<< $json))
else
  echo "xivid: geen video(-informatie) beschikbaar." 1>&2
  exit 1
fi
if [[ $f ]]; then
  if [[ ${fmts[@]} ]]; then
    for a in ${f/+/ }; do
      if [[ ${a: -1} == \# ]]; then
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
    xidel - -e '
      for $x in tokenize("'$f'","\+") return
      if (ends-with($x,"#")) then
        $json/(formats)()[starts-with(id,substring($x,1,string-length($x) - 1))][last()]/url
      else
        $json/(formats)()[id=$x]/url
    ' <<< $json
  else
    echo "xivid: geen video beschikbaar." 1>&2
    exit 1
  fi
elif [[ $i ]]; then
  xidel - -e 'xivid:info($json)' <<< $json
elif [[ $j ]]; then
  xidel - -e '$json' <<< $json
elif [[ ${fmts[@]} ]]; then
  xidel - -e '$json/(formats)()[last()]/url' <<< $json
else
  echo "xivid: geen video beschikbaar." 1>&2
  exit 1
fi
exit
