(:~
 : --------------------------------
 : Xivid function module
 : --------------------------------
 :
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
 : @author Reino Wijnsma (rwijnsma@xs4all.nl)
 : @see    https://github.com/Reino17/xivid
 :)

xquery version "3.0-xidel";
module namespace xivid = "https://github.com/Reino17/xivid/";

(:~
 : --------------------------------
 : Helper functions
 : --------------------------------
 :)

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

declare function xivid:bbvms($url as string,$publ as string) as object()? {
  let $json:=json(
        extract(unparsed-text($url),"var opts = (.+);",1)
      ),
      $host:=$json/publicationData/defaultMediaAssetPath,
      $orig:=json($json/clipData/s3Info)/format
  return
  $json/clipData/(
    if (sourcetype="live") then {
      "name":$publ||": Livestream",
      "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json((assets)()/src)
    } else {
      "name":concat($publ,": ",title),
      "date":format-date(
        dateTime(publisheddate) + implicit-timezone(),
        "[D01]-[M01]-[Y]"
      ),
      "duration":length * duration("PT1S") + time("00:00:00"),
      "formats":[
        for $x at $i in (assets)()
        order by $x/bandwidth
        count $i
        return
        $x/{
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":concat(width,"x",height),
          "bitrate":bandwidth||"kbps",
          "url":resolve-uri(src,$host)
        },
        {
          "id":"pg-"||count((assets)()) + 1,
          "format":"mp4[h264+aac]",
          "resolution":concat(originalWidth,"x",originalHeight),
          "bitrate":round(
            tokenize($orig/bit_rate)[1] * 1024
          )||"kbps",
          "url":$orig/filename
        }[url]
      ]
    }
  )
};

(:~
 : --------------------------------
 : Extractors
 : --------------------------------
 :)

declare function xivid:npo($url as string) as object()? {
  let $prid:=extract($url,".+/([\w_]+)",1),
      $token:=x:request({
        "header":"X-Requested-With: XMLHttpRequest",
        "url":"https://www.npostart.nl/api/token"
      })/json/token,
      $token2:=x:request({
        "post":"_token="||$token,
        "url":"https://www.npostart.nl/player/"||$prid
      })/json,
      $info:=json(
        doc($token2/embedUrl)//script/extract(.,"var video =(.+);",1)[.]
      ),
      $stream:=json(
        concat(
          "https://start-player.npo.nl/video/",
          $prid,
          "/streams?profile=hls&amp;quality=npo&amp;tokenId=",
          $token2/token
        )
      )/stream[not(protection)]/src
  return {|
    if ($info) then $info/{
      "name":concat(
        franchiseTitle,
        if (contains(franchiseTitle,title)) then () else ": "||title
      ),
      "date":format-date(
        dateTime(broadcastDate) + implicit-timezone(),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        duration * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "start":if (startAt) then
        format-time(
          startAt * duration("PT1S"),
          "[H01]:[m01]:[s01]"
        )
      else
        (),
      "end":if (startAt) then
        format-time(
          (startAt + duration) * duration("PT1S"),
          "[H01]:[m01]:[s01]"
        )
      else
        ()
    } else
      doc("https://www.npostart.nl/"||$prid)/(
        let $info:=json(//script[@type="application/ld+json"]) return {
          "name"://npo-player-header/concat(
            @main-title,
            ": ",
            @share-title
          ),
          "date":format-date(
            dateTime($info/uploadDate),
            "[D01]-[M01]-[Y]"
          ),
          "duration":format-time(
            duration($info/duration),
            "[H01]:[m01]:[s01]"
          )
        }
      ),
    {
      "formats":[
        (
          if (not($info/(subtitles)()) and $info/parentId) then
            json(
              doc(
                x:request({
                  "post":"_token="||$token,
                  "url":"https://www.npostart.nl/player/"||$info/parentId
                })/json/embedUrl
              )//script/extract(.,"var video =(.+);",1)[.]
            )
          else
            $info
        )/(subtitles)()/{
          "id":"sub-1",
          "format":"vtt",
          "language":language,
          "label":label,
          "url":src
        },
        xivid:m3u8-to-json($stream)
      ]
    }
  |}
};

declare function xivid:rtl($url as string) as object()? {
  json(
    concat(
      "http://www.rtl.nl/system/s4m/vfd/version=2/uuid=",
      if (contains($url,"rtlnieuws.nl")) then
        doc($url)//@data-uuid
      else
        extract($url,".+/(.+)",1),
      "/fmt=adaptive/"
    )
  )[meta/nr_of_videos_total gt 0]/{
    "name":concat(
      .//station,": ",
      abstracts/name,
      " - ",
      if (.//classname="uitzending") then episodes/name else .//title
    ),
    "date":format-date(
      (material)()/original_date * duration("PT1S") +
      implicit-timezone() + date("1970-01-01"),
      "[D01]-[M01]-[Y]"
    ),
    "duration":format-time(
      time((material)()/duration) + duration("PT0.5S"),
      "[H01]:[m01]:[s01]"
    ),
    "expdate":format-dateTime(
      (.//ddr_timeframes)()[model="AVOD"]/stop * duration("PT1S") +
      implicit-timezone() + dateTime("1970-01-01T00:00:00"),
      "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
    ),
    "formats":xivid:m3u8-to-json(.//videohost||.//videopath)
  }
};

declare function xivid:kijk($url as string) as object()? {
  let $json:=json(doc($url)//script[@type="application/json"])/props,
      $info:=for $x in $json/(apolloState)()[starts-with(.,"Program:"||$json/pageProps/video/id)] return $json/(apolloState)($x)
  return {
    "name":"Kijk: "||$info[__typename="Program"]/(
      if (type="MOVIE") then
        title
      else
        concat(
          $json/pageProps/format/title,
          " S",
          seasonNumber ! (if (. lt 10) then "0"||. else .),
          "E",
          tvSeasonEpisodeNumber ! (if (. lt 10) then "0"||. else .)
        )
    ),
    "date":format-date(
      (
        $info[__typename="Program"]//media_datepublished,
        $info[__typename="Media"]/availableDate
      )[1] div 1000 * duration("PT1S") + implicit-timezone() + date("1970-01-01"),
      "[D01]-[M01]-[Y]"
    ),
    "duration":round($info[__typename="Program"]/duration) * duration("PT1S") + time("00:00:00"),
    "formats":[
      for $x at $i in (
        if ($info[type="webvtt"]) then
          $info[type="webvtt"]/file
        else
          $info[ends-with(sourceUrl,"vtt")]/sourceUrl
      )
      order by $x
      count $i
      return {
        "id":"sub-"||$i,
        "format":"vtt",
        "language":"nl",
        "label":if (contains($x,"OPE")) then
          "Doven en Slechthorenden"
        else
          "Nederlands",
        "url":$x
      },
      xivid:m3u8-to-json(
        (
          $info[type="m3u8" and not(drm)]/extract(file,".+m3u8"),
          $info[ends-with(sourceUrl,"m3u8")]/sourceUrl
        )[1]
      )
    ]
  }
};

declare function xivid:tvblik($url as string) as object()? {
  let $host:=extract(
    doc($url)//(
      div[@id="embed-player"]/(@data-episode,a/@href),
      div[@class="video_thumb"]//@onclick,
      iframe[@class="sbsEmbed"]/@src
    ),
    "(npo|rtl|kijk).+(?:/|video=)([\w-]+)",
    (1,2)
  ) return
  if ($host[1]="npo") then
    xivid:npo("https://www.npostart.nl/"||$host[2])
  else if ($host[1]="rtl") then
    xivid:rtl("https://www.rtlxl.nl/video/"||$host[2])
  else
    xivid:kijk("https://kijk.nl/video/"||$host[2])
};

declare function xivid:ofr($url as string) as object()? {
  xivid:bbvms(
    doc($url)/(
      .//script[@async]/resolve-uri(@src,$url),
      .//div[starts-with(@class,"bluebillywig")]/iframe/resolve-uri(
        substring-before(@data-src,"html")||"js",
        $url
      )
    ),
    "Omrop Fryslân"
  )
};

declare function xivid:nhnieuws($url as string) as object()? {
  doc($url)/(
    if (//article) then
      json(
        //script/substring-after(.,"INITIAL_PROPS__ = ")[.]
      )/pageData/{
        "name":let $info:=(blocks)()[type=("video","headerVideo")]/video return
        if ($info/caption) then
          $info/concat(author,": ",caption)
        else
          concat(media//author,": ",title),
        "date":format-date(
          updated * duration("PT1S") + implicit-timezone() + date("1970-01-01"),
          "[D01]-[M01]-[Y]"
        ),
        "formats":xivid:m3u8-to-json(.//stream/url)
      }
    else {
      "name":substring-after(//title,"Media - ")||": Livestream",
      "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json(
        json(
          //script/substring-after(.,"INIT_DATA__ = ")[.]
        )/videoStream
      )
    }
  )
};

declare function xivid:dumpert($url as string) {
  json(
    json(
      doc($url)//script/extract(.,"JSON\.parse\((.+)\)",1)[.]
    )
  )/items/item/item[(media)()[mediatype="VIDEO"]]/{
    "name":"Dumpert: "||title,
    "date":format-date(dateTime(date),"[D01]-[M01]-[Y]"),
    "duration":(media)()/duration * duration("PT1S") + time("00:00:00"),
    "formats":for $x at $i in ("mobile","tablet","720p","original")
    let $vid:=(.//variants)()[version=$x]/uri
    return {
      "id":"pg-"||$i,
      "format":"mp4[h264+aac]",
      "url":$vid
    }[url]
  }
};

declare function xivid:telegraaf($url as string) as object()? {
  json(
    concat(
      "https://content.tmgvideo.nl/playlist/item=",
      json(
        doc($url)//script/extract(.,"APOLLO_STATE__=(.+);",1)[.]
      )/(.//videoId)[1],
      "/playlist.json"
    )
  )/(items)()/{
    "name":"Telegraaf: "||title,
    "date":format-date(
      date(tokenize(publishedstart)[1]),
      "[D01]-[M01]-[Y]"
    ),
    "duration":format-time(
      duration * duration("PT1S"),
      "[H01]:[m01]:[s01]"
    ),
    "expdate":publishedend ! format-dateTime(
      dateTime(replace(.,"\s","T")),
      "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
    ),
    "formats":[
      locations/reverse((progressive)())/{
        "id":"pg-"||position(),
        "format":"mp4[h264+aac]",
        "resolution":concat(width,"x",height),
        "url":.//src
      },
      xivid:m3u8-to-json(
        locations/(adaptive)()[type="application/x-mpegURL"]/extract(src,".+m3u8")
      )
    ]
  }
};

declare function xivid:ad($url as string) as object()? {
  let $id:=extract($url,"~p(\d+)",1),
      $json:=json(
        concat(
          "https://embed.mychannels.video/sdk/production/",
          if ($id) then
            $id
          else
            x:request({
              "headers":"Cookie: authId=8ac8ac9f-3782-4ba2-a449-9dc1fcdacbd5",
              "url":$url
            })/doc/(
              if (//*[@class="mc-embed"]) then
                //*[@class="mc-embed"]/extract(@src,"\d+")
              else
                //div[@data-mychannels-type="video"]/@data-mychannels-id
            ),
          "?options=FUTFU_default"
        )
      )
  return
  $json/{|
    {
      "name":concat(
        "AD: ",
        (shows)()/title,
        " - ",
        (productions)()/title
      )
    },
    (productions)()/{
      "date":format-date(
        date(tokenize(publicationDate)[1]),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        duration * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":[
        for $x at $i in reverse((sources)()[type="video/mp4"]) return {
          "id":"pg-"||$i,
          "resolution":("640x360","1280x720")[$i],
          "format":"mp4[h264+aac]",
          "url":$x/src
        },
        xivid:m3u8-to-json((sources)(1)/src)
      ]
    }
  |}
};

declare function xivid:lc($url as string) as object()? {
  let $html:=x:request({
        "headers":"Cookie: ndc_consent={""permissions"":{""functional"":true}}",
        "url":$url
      })/doc,
      $id:=$html//div[@class="article-page__video-wrapper"]/div/substring-after(@id,"video-")
  return
  xivid:bbvms(
    substring-before(
      json($html//script/tokenize(.,",")[contains(.,$id)]),
      "html"
    )||"js",
    "LC"
  )
};
