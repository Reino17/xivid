module namespace xivid = "https://github.com/Reino17/xivid/";

declare function xivid:m3u8-to-json ($url as xs:string?) as item()* {
  if ($url) then
    let $a:=x:request({
      "url":$url,
      "error-handling":"4xx=accept"
    }) return
    $a[doc]/(
      {
        "format":"hls-0",
        "container":"m3u8[manifest]",
        "url":if (string-length($a/url) < 512) then $a/url else $url
      },
      for $x at $i in tokenize($a/doc,"#EXT-X-")[matches(.,"^STREAM-INF:.+m3u8","ms")]
      order by extract($x,"BANDWIDTH=(\d+)",1)
      count $i
      return {
        "format":"hls-"||$i,
        "container":if (not(contains($x,"CODECS")) or contains($x,"avc1")) then
          "m3u8[h264+aac]"
        else
          "m3u8[aac]",
        "resolution":let $a:=extract($x,"FRAME-RATE=([\d.]+)",1) return
        extract($x,"RESOLUTION=([\dx]+)",1)[.] ! (
          if ($a) then concat(.,"@",round-half-to-even($a,3),"fps") else .
        ),
        "bitrate":let $a:=extract($x,"audio(?:_.+?)?=(\d+)(?:-video.+?(\d+))?",(1,2)),
            $b:=round(extract($x,"BANDWIDTH=(\d+)",1) div 1000)
        return
        concat(
          if ($a[1]) then 
            join(
              (round($a[2][.] div 1000),round($a[1] div 1000)),
              "|"
            )
          else
            $b,
          "kbps"
        ),
        "url":extract($x,".+m3u8(?:.+|)") ! (
          if (starts-with(.,"http")) then . else resolve-uri(.,$a/url)
        )
      }
    )
  else
    ()
};

declare function xivid:txt-to-date ($txt as xs:string) as xs:string {
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

declare function xivid:shex-to-dec ($shex as xs:string) as xs:integer {
  let $a:=x:integer($shex),
      $b:=x:integer-to-base($a,2)
  return
  if (string-length($b) > 31) then
    $a - integer(math:pow(2,string-length($b)))
  else
    $a
};
