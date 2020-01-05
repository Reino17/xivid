xquery version "3.0-xidel";
module namespace xivid = "https://github.com/Reino17/xivid/";

declare function xivid:m3u8-to-json ($url as string?) as object()* {
  if ($url) then
    let $a:=x:request({
          "url":$url,
          "error-handling":"4xx=accept"
        })[doc],
        $b:=extract($a/doc,"(#EXT-X-(?:MEDIA|STREAM-INF).+?m3u8.*?$)",1,"ms*")
    return (
      $b[contains(.,"TYPE=SUBTITLES")] ! {
        "id":"sub-1",
        "format":"m3u8[vtt]",
        "language":extract(.,"LANGUAGE=&quot;(.+?)&quot;",1),
        "url":extract(.,"URI=&quot;(.+?)&quot;",1) ! (
          if (starts-with(.,"http")) then . else resolve-uri(.,$a/url)
        )
      },
      {
        "id":"hls-0",
        "format":"m3u8[manifest]",
        "url":if (string-length($a/url) < 512) then $a/url else $url
      }[url],
      for $x at $i in $b[contains(.,"STREAM-INF") or contains(.,"TYPE=AUDIO")]
      order by extract($x,"BANDWIDTH=(\d+)",1)
      count $i
      return {
        "id":"hls-"||$i,
        "format":if (not(contains($x,"CODECS")) or contains($x,"avc1")) then
          "m3u8[h264+aac]"
        else
          "m3u8[aac]",
        "resolution":let $a:=extract($x,"RESOLUTION=([\dx]+)",1)[.],
            $b:=extract($x,"(?:FRAME-RATE=|GROUP-ID.+p)([\d.]+)(?:\s|,|&quot;)",1)
        return
        if ($b) then concat($a,"@",round-half-to-even($b,3),"fps") else $a,
        "bitrate":let $a:=extract($x,"audio.*?=(\d+)(?:-video.*?=(\d+))?",(1,2)) return
        concat(
          if ($a[1]) then
            join(
              (round($a[2][.] div 1000),round($a[1] div 1000)),
              "|"
            )
          else
            (
              round(extract($x,"BANDWIDTH=(\d+)",1)[.] div 1000),
              extract($x,"GROUP-ID=.+?-(\d+)",1)[.]
            ),
          "kbps"
        ),
        "url":(
          extract($x,"URI=&quot;(.+?)&quot;",1),
          extract($x,".+m3u8.*?$","m")
        )[.][1] ! (
          if (starts-with(.,"http")) then . else resolve-uri(.,$a/url)
        )
      }
    )
  else
    ()
};

declare function xivid:txt-to-date ($txt as string) as string {
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
      if ($b[1] < 10) then "0"||$b[1] else $b[1],
      $a($b[2]),
      $b[3]
    ),
    "-"
  )
};

declare function xivid:shex-to-dec ($shex as string) as integer {
  let $a:=x:integer($shex),
      $b:=x:integer-to-base($a,2)
  return
  if (string-length($b) > 31) then
    $a - integer(math:pow(2,string-length($b)))
  else
    $a
};

declare function xivid:info ($json as object()) as string* {
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
        for $x in $c()[position() > 1] return
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
              if (position() = count($c()) and $i = count($d)) then
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
        ($f[1] - $f[1] mod 30) ! (if (. = 0) then () else " -ss "||.),
        " -i <url>",
        ($f[1] mod 30) ! (if (. = 0) then () else " -ss "||.),
        " -t ",
        $f[2],
        " [...]"
      )
    )
  )
};
