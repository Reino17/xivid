#!/bin/bash
#
# Copyright (C) 2019 Reino Wijnsma
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
BashGemist, een video extractie script.
Gebruik: ./bashgemist.sh [optie] url

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
  youtube.com
  youtu.be
  vimeo.com

Voorbeelden:
  ./bashgemist.sh -f hls-11 https://www.npostart.nl/nos-journaal/01-01-2019/POW_04059321
  ./bashgemist.sh https://www.rtl.nl/video/f2068013-ce22-34aa-94cb-1b1aaec8d1bd
  ./bashgemist.sh -i https://www.kijk.nl/video/nHD4my1HMKu
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
                else if (
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
          format-date(
            date(gidsdatum),
            "[D01]-[M01]-[Y]"
          )
        else if (
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
        format-dateTime(
          dateTime(publicatie_eind),
          "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
        )
      else
        (),
      "subtitle":if (tt888="ja") then
        "http://tt888.omroep.nl/tt888/"||prid
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
              "container":"m4v[h264+aac]",
              "url":.
            },
            {
              "format":"hls-0",
              "container":"m3u8[manifest]",
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
              "container":if (
                contains(
                  $x,
                  "avc1"
                )
              ) then
                "m3u8[h264+aac]"
              else
                "m3u8[aac]",
              "resolution":extract(
                $x,
                "RESOLUTION=([\dx]+)",
                1
              )[.],
              "bitrate":let $a:=extract(
                $x,
                "audio.+?(\d+)\d{3}(?:-video=(\d+)\d{3})?",
                (1,2)
              ) return
              join(
                (
                  $a[2][.],
                  $a[1]
                ),
                "|"
              )||"kbps",
              "url":resolve-uri(
                extract(
                  $x,
                  "(.+m3u8)",
                  1
                ),
                $b
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
              "container":extract(
                .,
                ".+\.(.+)",
                1
              )||"[h264+aac]",
              "url":.
            }
          ]
      return
      if ($c()) then
        $c
      else
        ()
    }
  ' --output-format=bash)"
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
      "date":format-date(
        (material)()/original_date * duration("PT1S") + date("1970-01-01"),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        time((material)()/duration) + duration("PT0.5S"),
        "[H01]:[m01]:[s01]"
      ),
      "expdate":if ((.//ddr_timeframes)()[model="AVOD"]/stop) then
        format-dateTime(
          (.//ddr_timeframes)()[model="AVOD"]/stop * duration("PT1S") + dateTime("1970-01-01T01:00:00"),
          "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
        )
      else
        (),
      "formats":let $a:=.//videohost||.//videopath return [
        {
          "format":"hls-0",
          "container":"m3u8[manifest]",
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
          "container":if (
            contains(
              $x,
              "avc1"
            )
          ) then
            "m3u8[h264+aac]"
          else
            "m3u8[aac]",
          "resolution":extract(
            $x,
            "RESOLUTION=([\dx]+)",
            1
          )[.],
          "bitrate":let $a:=extract(
            $x,
            "audio=(\d+)(?:-video=(\d+)\d{3})?",
            (1,2)
          ) return
          join(
            (
              $a[2][.],
              round(
                $a[1] div 1000
              )
            ),
            "|"
          )||"kbps",
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
              $b,
              $a
            )
        }
      ]
    }
  ' --output-format=bash)"
}

kijk() {
  eval "$(xidel "https://embed.kijk.nl/video/$1" --xquery '
    json:=if (//video) then
      x:request(
        {
          "headers":"Accept: application/json;pk="||extract(
            unparsed-text(
              //script[
                contains(
                  @src,
                  //@data-account
                )
              ]/@src
            ),
            "policyKey:""(.+?)""",
            1
          ),
          "url":concat(
            "https://edge.api.brightcove.com/playback/v1/accounts/",
            //@data-account,
            "/videos/",
            //@data-video-id
          )
        }
      )/json/{
        "name":concat(
          upper-case(custom_fields/sbs_station),
          ": ",
          name,
          if (custom_fields/sbs_episode) then
            " "||custom_fields/sbs_episode
          else
            ()
        ),
        "date":replace(
          custom_fields/sko_dt,
          "(\d{4})(\d{2})(\d{2})",
          "$3-$2-$1"
        ),
        "duration":round(
          duration div 1000
        ) * duration("PT1S") + time("00:00:00"),
        "expdate":replace(
          json("http://api.kijk.nl/v1/default/entitlement/'$1'")//enddate/date,
          "(\d+)-(\d+)-(\d+) ([\d:]+).*",
          "$3-$2-$1 $4"
        ),
        "formats":let $a:=(sources)()[size=0]/src return [
          for $x at $i in (sources)()[stream_name]
          order by $x/size
          count $i
          return
          $x/{
            "format":"pg-"||$i,
            "container":"mp4[h264+aac]",
            "resolution":concat(
              width,
              "x",
              height
            ),
            "bitrate":round(
              avg_bitrate div 1000
            )||"kbps",
            "url":replace(
              stream_name,
              "mp4:",
              extract(
                $a,
                "(.+?nl/)",
                1
              )
            )
          },{
            "format":"hls-0",
            "container":"m3u8[manifest]",
            "url":$a
          }[url],
          tail(
            tokenize(
              unparsed-text($a),
              "#EXT-X-STREAM-INF:"
            )
          ) ! {
            "format":"hls-"||position(),
            "container":if (
              contains(
                .,
                "avc1"
              )
            ) then
              "m3u8[h264+aac]"
            else
              "m3u8[aac]",
            "resolution":extract(
              .,
              "RESOLUTION=([\dx]+)",
              1
            ),
            "bitrate":round(
              extract(
                .,
                "BANDWIDTH=(\d+)",
                1
              ) div 1000
            )||"kbps",
            "url":resolve-uri(
              extract(
                .,
                "(.+m3u8)",
                1
              ),
              $a
            )
          }
        ]
      }
    else
      json(
        //script/extract(
          .,
          "playerConfig = (.+);",
          1
        )[.]
      )/(playlist)()/{
        "name":TAQ/concat(
          upper-case(customLayer/c_media_station),
          ": ",
          customLayer/c_media_ispartof,
          if (dataLayer/media_program_season!=0 and dataLayer/media_program_episodenumber<=99) then
            concat(
              " S",
              dataLayer/media_program_season ! (
                if (.<10) then
                  "0"||.
                else
                  .
              ),
              "E",
              dataLayer/media_program_episodenumber ! (
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
          TAQ/customLayer/c_sko_dt,
          "(\d{4})(\d{2})(\d{2})",
          "$3-$2-$1"
        ),
        "duration":TAQ/customLayer/c_sko_cl * duration("PT1S") + time("00:00:00"),
        "expdate":format-dateTime(
          TAQ/customLayer/c_media_dateexpires * duration("PT1S") + dateTime("1970-01-01T01:00:00"),
          "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
        ),
        "subtitle":(tracks)()[label=" Nederlands"]/file,
        "formats":[
          (sources)()[not(drm) and type="m3u8"][1]/x:request(
            {
              "url":file,
              "error-handling":"xxx=accept"
            }
          )[
            contains(
              headers[1],
              "200"
            )
          ]/(
            {
              "format":"hls-0",
              "container":"m3u8[manifest]",
              "url":url
            },
            for $x at $i in tail(
              tokenize(
                extract(
                  doc,
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
              "container":if (
                contains(
                  $x,
                  "avc1"
                )
              ) then
                "m3u8[h264+aac]"
              else
                "m3u8[aac]",
              "resolution":extract(
                $x,
                "RESOLUTION=([\dx]+)",
                1
              )[.],
              "bitrate":let $a:=extract(
                $x,
                "audio.+?(\d+)\d{3}(?:-video=(\d+)\d{3})?",
                (1,2)
              ) return
              join(
                (
                  $a[2][.],
                  $a[1]
                ),
                "|"
              )||"kbps",
              "url":resolve-uri(
                extract(
                  $x,
                  "(.+m3u8)",
                  1
                ),
                url
              )
            }
          )
        ]
      }
  ' --output-format=bash)"
}

youtube() {
  eval "$(xidel "$1" --xquery '
    json:=json(
      if (//meta[@property="og:restrictions:age"]) then
        let $a:=concat(
          "https://www.youtube.com/get_video_info?video_id=",
          //meta[@itemprop="videoId"]/@content,
          "&amp;eurl=",
          uri-encode(
            "https://youtube.googleapis.com/v/"||//meta[@itemprop="videoId"]/@content
          ),
          "&amp;sts=",
          json(
            doc(
              "https://www.youtube.com/embed/"||//meta[@itemprop="videoId"]/@content
            )//script/extract(
              .,
              "setConfig\((.+?)\)",
              1,"*"
            )[3]
          )//sts
        ) return
        tokenize(
          uri-decode(
            doc($a)
          ),
          "&amp;"
        ) ! extract(
          .,
          "player_response=(.+)",
          1
        )[.]
      else
        json(
          //script/extract(
            .,
            "ytplayer.config = (.+?\});",
            1
          )[.]
        )/args/player_response
    )/{
      "name":videoDetails/title,
      "date":format-date(
        round(
          min(streamingData//lastModified) div 1000000
        ) * duration("PT1S") + dateTime("1970-01-01T01:00:00"),
        "[D01]-[M01]-[Y]"
      ),
      "duration":videoDetails/lengthSeconds * duration("PT1S") + time("00:00:00"),
      "formats":streamingData/[
        for $x at $i in (formats)()
        order by $x/contentLength
        count $i
        return
        $x/{
          "format":"pg-"||$i,
          "container":let $a:=extract(
            mimeType,
            "/(.+);.+?(\w+)\..+ (\w+)(?:\.|"")",
            (1 to 3)
          ) return
          concat(
            if ($a[1]="3gpp") then
              "3gp"
            else
              $a[1],
            "[",
            if ($a[2]="avc1") then
              "h264"
            else
              $a[2],
            "+",
            if ($a[3]="mp4a") then
              "aac"
            else
              $a[3],
            "]"
          ),
          "resolution":concat(
            width,
            "x",
            height
          ),
          "bitrate":if (.[itag="43"]) then
            ()
          else
            round(
              bitrate div 1000
            )||"kbps",
          "url":url
        },
        if (dashManifestUrl) then
          for $x at $i in doc(
            dashManifestUrl||"/disable_polymer/true"
          )//Representation
          order by $x/boolean(@width),
                   $x/@bandwidth
          count $i
          return
          $x/{
            "format":"dash-"||$i,
            "container":concat(
              substring-after(
                ../@mimeType,
                "/"
              ),
              "[",
              substring-before(
                @codecs,
                "."
              ) ! (
                if (.="mp4a") then
                  "aac"
                else if (.="avc1") then
                  "h264"
                else
                  .
              ),
              "]"
            ),
            "resolution":if (@width) then
              concat(
                @width,
                "x",
                @height,
                "@",
                @frameRate,
                "fps"
              )
            else
              (),
            "samplerate":if (@audioSamplingRate) then
              (@audioSamplingRate div 1000)||"kHz"
            else
              (),
            "bitrate":round(
              @bandwidth div 1000
            )||"kbps",
            "url":BaseUrl
          }
        else
          for $x at $i in (adaptiveFormats)()
          order by $x/boolean(width),
                   $x/bitrate
          count $i
          return
          $x/{
            "format":"dash-"||$i,
            "container":let $a:=extract(
              mimeType,
              "/(.+);.+?(\w+)(?:\.|"")",
              (1,2)
            ) return
            concat(
              $a[1],
              "[",
              if ($a[2]="mp4a") then
                "aac"
              else if ($a[2]="avc1") then
                "h264"
              else
                $a[2],
              "]"
            ),
            "resolution":if (width) then
              concat(
                width,
                "x",
                height,
                "@",
                fps,
                "fps"
              )
            else
              (),
            "samplerate":if (audioSampleRate) then
              (audioSampleRate div 1000)||"kHz"
            else
              (),
            "bitrate":round(
              bitrate div 1000
            )||"kbps",
            "url":url
          }
      ]
    }
  ' --output-format=bash)"
}

vimeo() {
  eval "$(xidel "$1" --xquery '
    json:=json(
      //script/extract(
        .,
        "clip_page_config = (.+);",
        1
      )[.]
    )/{
      "name":clip/title,
      "date":replace(
        clip/uploaded_on,
        "(\d+)-(\d+)-(\d+).+",
        "$3-$2-$1"
      ),
      "duration":clip/duration/formatted,
      "formats":player/json(config_url)//files/(
        let $a:=hls/(.//url)[1] return [
          for $x at $i in (progressive)()
          order by $x/width
          count $i
          return
          $x/{
            "format":"pg-"||$i,
            "container":"mp4[h264+aac]",
            "resolution":concat(
              width,
              "x",
              height,
              "@",
              fps,
              "fps"
            ),
            "url":url
          },{
            "format":"hls-0",
            "container":"m3u8[manifest]",
            "url":$a
          },
          tail(
            tokenize(
              unparsed-text($a),
              "#EXT-X-STREAM-INF:"
            )
          ) ! {
            "format":"hls-"||position(),
            "container":"m3u8[h264+aac]",
            "resolution":concat(
              extract(
                .,
                "RESOLUTION=([\dx]+)",
                1
              ),
              "@",
              round(
                number(
                  extract(
                    .,
                    "FRAME-RATE=([\d.]+)",
                    1
                  )
                )
              ),
              "fps"
            ),
            "bitrate":round(
              extract(
                .,
                "BANDWIDTH=(\d+)",
                1
              ) div 1000
            )||"kbps",
            "url":resolve-uri(
              extract(
                .,
                "(.+m3u8)",
                1
              ),
              $a
            )
          }
        ]
      )
    }
  ' --output-format=bash)"
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
        $b:=$json()[.!="formats"] ! .[$json(.)[.]],
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
            "container":"container",
            "resolution":"resolutie",
            "samplerate":"frequentie",
            "bitrate":"bitrate"
          },
          $json/(formats)()
        ],
        $f:=$e(1)() ! .[
          contains(
            [
              distinct-values(
                $json/(formats)()()[.!="url"]
              )
            ],
            .
          )
        ],
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
      if (start) then (
        "",
        concat(
          substring(
            "Download:"||$d,
            1,
            $c+1
          ),
          "ffmpeg -ss ",
          time(start) - (
            seconds-from-time(start) mod 30 * duration("PT1S")
          ),
          " -i [url] -ss ",
          seconds-from-time(start) mod 30,
          " -t ",
          duration,
          " [...]"
        )
      ) else
        ()
    )
  ' <<< $1
}

if ! command -v xidel >/dev/null; then
  cat 1>&2 <<EOF
BashGemist, een video extractie script.
Fout: Xidel niet gevonden!
Installeer Xidel a.u.b. om dit script te kunnen gebruiken.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
  exit 1
elif [[ $(xidel --version | grep -oP "\.\K\d{4}") -le 5651 ]]; then
  cat 1>&2 <<EOF
BashGemist, een video extractie script.
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
BashGemist, een video extractie script.
Gebruik: ./bashgemist.sh [optie] url
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
elif [[ $url =~ (tvblik.nl|uitzendinggemist.net) ]]; then
  eval "$(xidel "$url" -e '
    join(
      extract(
        (
          //div[@id="embed-player"]/(
            @data-episode,
            .//@href
          ),
          //a[@rel="nofollow"]/@onclick,
          //iframe[@class="sbsEmbed"]/@src
        ),
        "(npo|rtl|kijk).+(?:/|video=)([\w-]+)",
        (1,2)
      )
    )
  ')"
elif [[ $url =~ rtl.nl ]]; then
  rtl "$(xidel -e 'extract("'$url'","video/([\w-]+)",1)')"
elif [[ $url =~ kijk.nl ]]; then
  kijk "$(xidel -e 'extract("'$url'","(?:video|videos)/(\w+)",1)')"
elif [[ $url =~ (youtube.com|youtu.be) ]]; then
  youtube "$url"
elif [[ $url =~ vimeo.com ]]; then
  vimeo "$url"
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
