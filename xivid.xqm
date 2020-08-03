(:~
 : Copyright (C) 2020 Reino Wijnsma
 :
 : This program is free software: you can redistribute it and/or modify
 : it under the terms of the GNU General Public License as published by
 : the Free Software Foundation, either version 3 of the License, or
 : (at your option) any later version.
 :
 : This program is distributed in the hope that it will be useful,
 : but WITHOUT ANY WARRANTY; without even the implied warranty of
 : MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 : GNU General Public License for more details.
 :
 : You should have received a copy of the GNU General Public License
 : along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :
 : https://github.com/Reino17/xivid
 : door Reino Wijnsma (rwijnsma@xs4all.nl)
 :)

xquery version "3.0-xidel";
module namespace xivid = "https://github.com/Reino17/xivid/";

declare function xivid:m3u8-to-json($url as string?) as object()* {
  let $m3u8:=x:request(
        {"url":$url,"error-handling":"4xx=accept"}[url]
      )[doc[not(contains(.,"#EXT-X-SESSION-KEY:METHOD=SAMPLE-AES"))]],
      $m3u8Url:=if (string-length($m3u8/url) lt 512) then $m3u8/url else $url,
      $streams:=extract(
        $m3u8/doc,
        "#EXT-X-(?:MEDIA:TYPE=(?:AUDIO|VIDEO)|STREAM-INF).+?m3u8.*?$",
        0,"ms*"
      )
  return (
    extract($m3u8/doc,"#EXT-X-MEDIA:TYPE=SUBTITLES.+")[.] ! {
      "id":"sub-1",
      "format":"m3u8[vtt]",
      "language":extract(.,"LANGUAGE=&quot;(.+?)&quot;",1),
      "url":resolve-uri(
        extract(.,"URI=&quot;(.+?)&quot;",1),
        $m3u8Url
      )
    },
    for $x at $i in $streams[contains(.,"PROGRESSIVE-URI")]
    let $br:=extract($x[1],"BANDWIDTH=(\d+)",1)
    group by $br
    count $i
    return {
      "id":"pg-"||$i,
      "format":"mp4[h264+aac]",
      "resolution":extract($x[1],"RESOLUTION=([\dx]+)",1),
      "bitrate":round($br div 1000)||"kbps",
      "url":extract($x[1],"URI=&quot;(.+mp4)(?:#.+)?&quot;",1)
    },
    {
      "id":"hls-0",
      "format":"m3u8[manifest]",
      "url":$m3u8Url
    }[url],
    for $x at $i in $streams
    let $br:=extract($x[1],"BANDWIDTH=(\d+)",1)
    group by $br
    count $i
    return {
      "id":"hls-"||$i,
      "format":if (contains($x[1],"avc1")) then
        "m3u8[h264+aac]"
      else
        "m3u8[aac]",
      "resolution":concat(
        extract($x[1],"RESOLUTION=([\dx]+)",1)[.],
        extract($x[1],"(?:FRAME-RATE=|GROUP-ID.+p)([\d\.]+)",1)[.] !
          concat("@",round-half-to-even(.,3),"fps")
      )[.],
      "bitrate":let $a:=extract($x[1],"audio.*?=(\d+)(?:-video.*?=(\d+))?",(1,2)) return
      concat(
        if ($a[1]) then
          join((round($a[2][.] div 1000),round($a[1] div 1000)),"|")
        else
          (
            round($br[.] div 1000),
            extract($x[1],"GROUP-ID=.+?-(\d+)",1)[.]
          ),
        "kbps"
      ),
      "url":resolve-uri(
        extract($x[1],"(?:.+URI=&quot;)?(.+m3u8(?:\?.+?$)?)",1,"m"),
        $m3u8Url
      )
    }
  )
};

declare function xivid:txt-to-date($txt as string) as string {
  let $a:={
        "januari":"01","februari":"02","maart":"03",
        "april":"04","mei":"05","juni":"06",
        "juli":"07","augustus":"08","september":"09",
        "oktober":"10","november":"11","december":"12"
      },
      $b:=extract($txt,"(\d+)\s+([a-z]+)\s+(\d{4})",(1 to 3))
  return
  join(
    (
      if ($b[1] lt 10) then "0"||$b[1] else $b[1],
      $a($b[2]),
      $b[3]
    ),
    "-"
  )
};

declare function xivid:bin-xor($a as integer,$b as integer) as integer {
  let $bin:=($a,$b) ! x:integer-to-base(.,2),
      $len:=max($bin ! string-length()),
      $val:=$bin ! concat(
        string-join((1 to $len - string-length()) ! 0),
        .
      ),
      $v1:=$val[1],
      $v2:=$val[2]
  return
  x:integer(
    string-join(
      for $x in 1 to $len return
      if (substring($v1,$x,1) eq substring($v2,$x,1)) then 0 else 1
    ),
    2
  )
};

declare function xivid:info($json as object()) as string* {
  let $a:={
        "name":"Naam:",
        "date":"Datum:",
        "duration":"Tijdsduur:",
        "start":"Begin:",
        "end":"Einde:",
        "expdate":"Gratis tot:",
        "formats":"Formaten:"
      },
      $b:=max(
        $a()[$json(.)] ! $a(.) ! string-length()
      ),
      $c:=[
        {
          "id":"id",
          "format":"formaat",
          "language":"taal",
          "resolution":"resolutie",
          "samplerate":"frequentie",
          "bitrate":"bitrate"
        },
        $json/(formats)()
      ],
      $d:=$c(1)() ! distinct-values(
        for $x in $c()[position() gt 1] return
        .[$x(.)]
      ),
      $e:=$d ! max($c()(.) ! string-length())
  return (
    $a()[$json(.)] ! concat(
      substring(
        $a(.)||string-join((1 to $b) ! " "),
        1,$b + 1
      ),
      if (.=$a()[last()]) then
        if ($c(2)) then
          join(
            $c() ! string-join(
              for $x at $i in $d return
              if (position() eq count($c()) and $i eq count($d)) then
                .($x)||" (best)"
              else
                substring(
                  .($x)||string-join((1 to $e[$i] + 2) ! " "),
                  1,$e[$i] + 2
                )
            ),
            "&#10;"||string-join((1 to $b + 1) ! " ")
          )
        else
          "-"
      else
        $json(.)
    ),
    $json[start]/(
      "",
      let $f:=(start,duration) ! (
        (time(.) - time("00:00:00")) div dayTimeDuration("PT1S")
      ) return
      concat(
        substring(
          "Download:"||string-join((1 to $b) ! " "),
          1,$b + 1
        ),
        "ffmpeg",
        ($f[1] - $f[1] mod 30) ! (if (. eq 0) then () else " -ss "||.),
        " -i <url>",
        ($f[1] mod 30) ! (if (. eq 0) then () else " -ss "||.),
        " -t ",
        $f[2],
        " [...]"
      )
    )
  )
};
