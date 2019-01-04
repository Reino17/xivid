#!/bin/bash
#
# Copyright (C) 2018 Reino Wijnsma
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
# https://github.com/Reino17/bashgemist
# door Reino Wijnsma (rwijnsma@xs4all.nl)

show_help() {
  cat <<EOF
BashGemist, een video-url extractie script.
Gebruik: bashgemist.sh [optie] url

  -h, --help              Toon deze hulppagina.
  -f, --format FORMAAT    Formaat code. Zonder opgave wordt het best
                          beschikbare formaat gekozen.
  -i, --info              Toon video informatie, incl. een opsomming
                          van alle beschikbare formaten.
  -j, --json              Toon video informatie als JSON.
  -d, --debug             Toon bash debug informatie.

Ondersteunde websites:
  npostart.nl
  gemi.st
  rtl.nl
  kijk.nl
EOF
}

npo() {
  eval "$(xidel "http://e.omroep.nl/metadata/$1" --xquery '
    json:=json(
      extract(
        $raw,
        "\((.+)\)",
        1
      )
    )[not(error)]/{
      "name":if (medium="live") then
        titel||": Livestream"
      else
        replace(
          concat(
            if (count(.//naam)=1) then
              .//naam
            else
              join(
                .//naam,
                " en "
              ),
            ": ",
            if (ptype="episode") then
              if (aflevering_titel) then
                if (
                  contains(
                    titel,
                    aflevering_titel
                  )
                ) then
                  titel
                else
                  if (
                    contains(
                      aflevering_titel,
                      titel
                    )
                  ) then
                    aflevering_titel
                  else
                    concat(
                      titel,
                      " - ",
                      aflevering_titel
                    )
              else
                titel
            else
              concat(
                .//serie_titel,
                " - ",
                titel
              )
          ),
          "[&quot;&apos;]",
          "'\'\''"
        ),
      "date":if (medium="live") then
        "'$(date "+%d-%m-%Y")'"
      else (
        if (gidsdatum) then
          replace(
            gidsdatum,
            "(\d+)-(\d+)-(\d+)",
            "$3-$2-$1"
          )
        else
          if (
            matches(
              "'$url'",
              "\d{2}-\d{2}-\d{4}"
            )
          ) then
            extract(
              "'$url'",
              ".+/([\d-]+)",
              1
            )
          else
            extract(
              x:request(
                {
                  "url":"https://www.npostart.nl/'$1'",
                  "method":"HEAD"
                }
              )/url,
              ".+/([\d-]+)",
              1
            )
      ),
      "duration":if (tijdsduur) then
        tijdsduur
      else
        (),
      "start":start,
      "end":eind,
      "expdate":if (publicatie_eind) then
        replace(
          publicatie_eind,
          "(\d+)-(\d+)-(\d+)T([\d:]+).+",
          "$3-$2-$1 $4"
        )
      else
        (),
      "subtitle":if (tt888="ja") then
        "http://tt888.omroep.nl/tt888/'$1'"
      else
        (),
      "formats":let $a:=x:request(
            {
              "url":"http://ida.omroep.nl/app.php/'$1'?token="||json(
                "http://ida.omroep.nl/app.php/auth"
              )/token,
              "error-handling":"4xx=accept"
            }
          )[
            contains(
              headers[1],
              "200"
            )
          ]/json/(items)()(),
          $b:=$a[format="hls"]/x:request(
            {
              "url":replace(
                url,
                "jsonp",
                "json"
              ),
              "error-handling":"4xx=accept"
            }
          )[
            contains(
              headers[1],
              "200"
            )
          ]/(
            if (json instance of string) then
              json
            else
              json/url
          ),
          $c:=[
            reverse(
              $a[contentType="odi"][format="mp4"]
            )/x:request(
              {
                "url":replace(
                  url,
                  "jsonp",
                  "json"
                ),
                "error-handling":"4xx=accept"
              }
            )[
              contains(
                headers[1],
                "200"
              )
            ]/json/substring-before(
              url,
              "?"
            ) ! {
              "format":"pg-"||position(),
              "extension":"m4v",
              "url":.
            },
            {
              "format":"hls-0",
              "extension":"m3u8",
              "resolution":"manifest",
              "url":$b
            }[url],
            for $x at $i in tail(
              tokenize(
                extract(
                  unparsed-text($b),
                  "(#EXT-X-STREAM-INF.+m3u8$)",
                  1,"ms"
                ),
                "#EXT-X-STREAM-INF:"
              )
            ) order by extract(
              $x,
              "BANDWIDTH=(\d+)",
              1
            ) count $i
            return {
              "format":"hls-"||$i,
              "extension":"m3u8",
              "resolution":extract(
                $x,
                "RESOLUTION=([\dx]+)",
                1
              ) ! (
                if (.) then
                  .
                else
                  "audiospoor"
              ),
              "vbitrate":extract(
                $x,
                "video=(\d+)\d{3}",
                1
              ) ! (
                if (.) then
                  concat(
                    "v:",
                    .,
                    "k"
                  )
                else
                  ""
              ),
              "abitrate":replace(
                $x,
                ".+audio.+?(\d+)\d{3}.+",
                "a:$1k","s"
              ),
              "url":resolve-uri(
                ".",
                $b
              )||extract(
                $x,
                "(.+m3u8)",
                1
              )
            },
            reverse(
              $a[contentType="url"][format="mp4"]
            )/x:request(
              {
                "url":url,
                "method":"HEAD",
                "error-handling":"xxx=accept"
              }
            )[
              some $x in ("200","302") satisfies contains(
                headers[1],
                $x
              )
            ]/(
              if (
                contains(
                  url,
                  "content-ip"
                )
              ) then
                x:request(
                  {
                    "url":"https://ipv4-api.nos.nl/resolve.php/video?url="||uri-encode(url),
                    "method":"HEAD"
                  }
                )/url
              else
                url
            ) ! {
              "format":"mp4-"||position(),
              "extension":extract(
                .,
                ".+\.(.+)",
                1
              ),
              "url":.
            }
          ]
      return
      if ($c()) then
        $c
      else
        ()
    }' --output-format=bash
  )"
}

rtl() {
  eval "$(xidel "http://www.rtl.nl/system/s4m/vfd/version=2/uuid=$1/fmt=adaptive/" --xquery '
    json:=$json[
      not(
        meta/nr_of_videos_total=0
      )
    ]/{
      "name":replace(
        concat(
          .//station,
          ": ",
          abstracts/name,
          " - ",
          if (.//classname="uitzending") then
            episodes/name
          else
            .//title
        ),
        "[&quot;&apos;]",
        "'\'\''"
      ),
      "date":replace(
        (material)()/original_date * duration("PT1S") + date("1970-01-01"),
        "(\d+)-(\d+)-(\d+)",
        "$3-$2-$1"
      ),
      "duration":format-time(
        time((material)()/duration) + duration("PT0.5S"),
        "[H01]:[m01]:[s01]"
      ),
      "expdate":if ((.//ddr_timeframes)()[model="AVOD"]/stop) then
        replace(
          (.//ddr_timeframes)()[model="AVOD"]/stop * duration("PT1S") + dateTime("1970-01-01T00:00:00"),
          "(\d+)-(\d+)-(\d+)T(.+)",
          "$3-$2-$1 $4"
        )
      else
        (),
      "formats":let $a:=.//videohost||.//videopath return [
        {
          "format":"hls-0",
          "extension":"m3u8",
          "resolution":"manifest",
          "url":$a
        },
        for $x at $i in tail(
          tokenize(
            unparsed-text($a),
            "#EXT-X-STREAM-INF:"
          )
        ) order by extract(
          $x,
          "BANDWIDTH=(\d+)",
          1
        ) count $i
        return {
          "format":"hls-"||$i,
          "extension":"m3u8",
          "resolution":extract(
            $x,
            "RESOLUTION=([\dx]+)",
            1
          ) ! (
            if (.) then
              .
            else
              "audiospoor"
          ),
          "vbitrate":extract(
            $x,
            "video=(\d+)\d{3}",
            1
          ) ! (
            if (.) then
              concat(
                "v:",
                .,
                "k"
              )
            else
              ""
          ),
          "abitrate":replace(
            $x,
            ".+audio.+?(\d+)\d{3}.+",
            "a:$1k","s"
          ),
          "url":let $b:=extract(
            $x,
            "(.+m3u8)",
            1
          ) return
          if (
            starts-with(
              $b,
              "http"
            )
          ) then
            $b
          else
            resolve-uri(
              ".",
              $a
            )||$b
        }
      ]
    }' --output-format=bash
  )"
}

kijk() {
  eval "$(xidel "https://embed.kijk.nl/video/$1" --xquery '
    json:=json(
      //script/extract(
        .,
        "playerOptionsObj = (.+);",
        1
      )[.]
    )/(playlist)()/{
      "name":TAQ/dataLayer/concat(
        upper-case(media_owner),
        ": ",
        media_program_name,
        if (sbs_season!=0 and media_program_episodenumber<=99) then
          concat(
            " S",
            sbs_season ! (
              if (.<10) then
                "0"||.
              else
                .
            ),
            "E",
            media_program_episodenumber ! (
              if (.<10) then
                "0"||.
              else
                .
            )
          )
        else
          ()
      ),
      "date":replace(
        TAQ/dataLayer/sko_dt,
        "(\d{4})(\d{2})(\d{2})",
        "$3-$2-$1"
      ),
      "duration":TAQ/dataLayer/media_duration * dayTimeDuration("PT1S") + time("00:00:00"),
      "expdate":replace(
        TAQ/dataLayer/media_dateexpires,
        "(\d+)-(\d+)-(\d+)T([\d:]+).+",
        "$3-$2-$1 $4"
      ),
      "subtitle":(tracks)()[label=" Nederlands"]/file,
      "formats":[
        (sources)()[type="m3u8"][1]/x:request(
          {
            "url":file,
            "method":"HEAD"
          }
        )/(
          {
            "format":"hls-0",
            "extension":"m3u8",
            "resolution":"manifest",
            "url":url
          },
          for $x at $i in tail(
            tokenize(
              extract(
                unparsed-text(url),
                "(#EXT-X-STREAM-INF.+m3u8$)",
                1,"ms"
              ),
              "#EXT-X-STREAM-INF:"
            )
          ) order by extract(
            $x,
            "BANDWIDTH=(\d+)",
            1
          ) count $i
          return {
            "format":"hls-"||$i,
            "extension":"m3u8",
            "resolution":extract(
              $x,
              "RESOLUTION=([\dx]+)",
              1
            ) ! (
              if (.) then
                .
              else
                "audiospoor"
            ),
            "vbitrate":extract(
              $x,
              "video=(\d+)\d{3}",
              1
            ) ! (
              if (.) then
                concat(
                  "v:",
                  .,
                  "k"
                )
              else
                ""
            ),
            "abitrate":replace(
              $x,
              ".+audio.+?(\d+)\d{3}.+",
              "a:$1k","s"
            ),
            "url":resolve-uri(
              ".",
              url
            )||extract(
              $x,
              "(.+m3u8)",
              1
            )
          }
        ),
        x:request(
          {
            "url":concat(
              "https://embed.kijk.nl/api/playlist/",
              "'$1'",
              "_dbzyr6.m3u8?base_url=https%3A//emp-prod-acc-we.ebsd.ericsson.net/sbsgroup"
            ),
            "method":"HEAD",
          "error-handling":"xxx=accept"
          }
        )[
          contains(
            headers[1],
            "200 OK"
          )
        ]/(
          {
            "format":"hls-0_hd",
            "extension":"m3u8",
            "resolution":"manifest",
            "url":url
          }[url],
          tail(
            tokenize(
              unparsed-text(url),
              "#EXT-X-STREAM-INF:"
            )
          ) ! {
            "format":concat(
              "hls-",
              position(),
              "_hd"
            ),
            "extension":"m3u8",
            "resolution":extract(
              .,
              "RESOLUTION=([\dx]+)",
              1
            ),
            "vbitrate":extract(
              .,
              "BANDWIDTH=(\d+)\d{3}",
              1
            )||"k",
            "url":extract(
              .,
              "(.+m3u8)",
              1
            )
          }
        )
      ]
    }' --output-format=bash
  )"
}

info() {
  xidel - --xquery '
    let $a:={
          "name":"Naam:",
          "date":"Datum:",
          "duration":"Tijdsduur:",
          "start":"Begin:",
          "end":"Einde:",
          "expdate":"Gratis tot:",
          "subtitle":"Ondertiteling:"
        },
        $b:=$json()[
          position()<count($json())
        ] ! .[$json(.)[.]],
        $c:=max(
          $b ! $a(.) ! string-length(.)
        ) ! (
          if (.>9) then
            .
          else
            9
        ),
        $d:=string-join(
          (1 to $c+1) ! " "
        ),
        $e:=[
          {
            "format":"formaat",
            "extension":"extensie",
            "resolution":"resolutie",
            "vbitrate":"bitrate"
          },
          $json/(formats)()
        ],
        $f:=(
          "format",
          "extension",
          "resolution",
          "vbitrate",
          "abitrate"
        ),
        $g:=$f ! max(
          $e()(.) ! string-length(.)
        ),
        $h:=string-join(
          (1 to sum($g)) ! " "
        )
    return (
      $b ! concat(
        substring(
          $a(.)||$d,
          1,
          $c+1
        ),
        $json(.)
      ),
      if ($e(2)) then
        for $x at $i in $e() return
        concat(
          if ($i=1) then
            substring(
              "Formaten:"||$d,
              1,
              $c+1
            )
          else
            $d,
          string-join(
            for $y at $i in $f return
            substring(
              $x($y)||$h,
              1,
              $g[$i]+2
            )
          ),
          if ($i=count($e())) then
            "(best)"
          else
            ()
        )
      else
        substring(
          "Formaten:"||$d,
          1,
          $c+1
        )||"-",
      if (start) then
        let $a:=seconds-from-time(start) mod 30 * dayTimeDuration("PT1S") return (
          "",
          concat(
            substring(
              "Download:"||$d,
              1,
              $c+1
            ),
            "ffmpeg -ss ",
            time(start) - $a,
            " -i [url] -ss ",
            $a + time("00:00:00"),
            " -t ",
            duration,
            " [...]"
          )
        )
      else
        ()
    )' <<< $1
}

if ! command -v xidel >/dev/null; then
  cat 1>&2 <<EOF
BashGemist, een video-url extractie script.
Fout: Xidel niet gevonden!
Installeer Xidel a.u.b. om dit script te kunnen gebruiken.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
  exit 1
elif [ $(xidel --version | grep -oP "\.\K\d{4}") -le 5651 ]; then
  cat 1>&2 <<EOF
BashGemist, een video-url extractie script.
Fout: Xidel gevonden, maar versie is te oud!
Installeer Xidel 0.9.7.5651 of nieuwer a.u.b.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
  exit 1
fi
export XIDEL_OPTIONS="--silent"
user_agent="Mozilla/5.0 Firefox/64.0"

if [[ -z "$@" ]]; then
  cat 1>&2 <<EOF
BashGemist, een video-url extractie script.
Gebruik: bashgemist.sh [optie] url
Typ -h of --help voor een lijst van alle opties.
EOF
  exit 1
fi

while true; do
  re='^https?://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
  case $1 in
    -h|--help)
      show_help
      exit
      ;;
    -f|--format)
      if [[ $3 ]]; then
        format=$2
        shift
      else
        if [[ $2 =~ $re ]]; then
          echo "bashgemist: ontbrekende formaat code." 1>&2
          exit 1
        else
          echo "bashgemist: ontbrekende url." 1>&2
          exit 1
        fi
      fi
      ;;
    -i|--info)
      info=1
      ;;
    -j|--json)
      dump_json=1
      ;;
    -d|--debug)
      set -x
      ;;
    -|-?*)
      echo "bashgemist: ongeldige optie: '$1'." 1>&2
      exit 1
      ;;
    *)
      if [[ $1 ]]; then
        if [[ $1 =~ $re ]]; then
          url=$1
        else
          echo "bashgemist: ongeldige url." 1>&2
          exit 1
        fi
      else
        echo "bashgemist: ontbrekende url." 1>&2
        exit 1
      fi
      break
  esac
  shift
done

if [[ $url =~ npostart.nl/live ]]; then
  npo "$(xidel "$url" -e '//npo-player/@media-id')"
elif [[ $url =~ (npostart.nl|gemi.st) ]]; then
  npo "$(xidel -e 'extract("'$url'",".+/([\w_]+)",1)')"
elif [[ $url =~ rtl.nl ]]; then
  rtl "$(xidel -e 'extract("'$url'","video/([\w-]+)",1)')"
elif [[ $url =~ kijk.nl ]]; then
  kijk "$(xidel -e 'extract("'$url'","(?:video|videos)/(\w+)",1)')"
else
  echo "bashgemist: niet ondersteunde url." 1>&2
  exit 1
fi

if [[ $format ]]; then
  if [[ -n $(xidel - -e '$json/(formats)()' <<< $json) ]]; then
    if [[ $(xidel - -e '$json/(formats)()/format' <<< $json) =~ $format ]]; then
      xidel - -e '$json/(formats)()[format="'$format'"]/url' <<< $json
    else
      echo "bashgemist: ongeldige formaat code." 1>&2
      exit 1
    fi
  else
    echo "bashgemist: geen video's beschikbaar." 1>&2
    exit 1
  fi
elif [[ $info ]]; then
  info "$json"
elif [[ $dump_json ]]; then
  xidel - -e '$json' <<< $json
else
  if [[ -n $(xidel - -e '$json/(formats)()' <<< $json) ]]; then
    xidel - -e '$json/(formats)()[last()]/url' <<< $json
  else
    echo "bashgemist: geen video's beschikbaar." 1>&2
    exit 1
  fi
fi

exit
