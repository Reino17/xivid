(:~
 : --------------------------------
 : Xivid function module
 : --------------------------------
 :
 : Copyright (C) 2023 Reino Wijnsma
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

xquery version "3.1-xidel";
module namespace xivid = "https://github.com/Reino17/xivid/";

(:~
 : --------------------------------
 : Helper functions
 : --------------------------------
 :)

declare function xivid:m3u8-to-json($url as string?) as array()? {
  let $src:=unparsed-text($url)[$url],
      $media:=extract($src,"#EXT-X-MEDIA.*URI=.+",0,"*"),
      $streams:=extract($src,"#EXT-X-STREAM-INF.+\r?\n.+",0,"*")
  return
  if (not(exists($streams)))
  then array{
    {"id":"hls-1","format":"m3u8[h264+aac]","url":$url}[url]
  }[exists(.())]
  else array{
    $media[contains(.,"TYPE=SUBTITLES")] ! {
      "id":"sub-1",
      "format":"m3u8[vtt]",
      "language":extract(.,"LANGUAGE=&quot;(.+?)&quot;",1),
      "label":extract(.,"NAME=&quot;(.+?)&quot;",1),
      "url":resolve-uri(extract(.,"URI=&quot;(.+?)&quot;",1),$url)
    },
    for $x at $i in $streams[contains(.,"PROGRESSIVE-URI")]
    let $br:=extract($x,"BANDWIDTH=(\d+)",1)
    order by $br
    count $i
    return {
      "id":"pg-"||$i,
      "format":"mp4[h264+aac]",
      "resolution":extract($x,"RESOLUTION=([\dx]+)",1),
      "bitrate":round($br div 1000)||"kbps",
      "url":extract($x,"URI=&quot;(.+?)&quot;",1)
    },
    {"id":"hls-0","format":"m3u8[manifest]","url":$url},
    $media[contains(.,"TYPE=AUDIO")] ! {
      "id":"hls-"||position(),
      "format":"m3u8[aac]",
      "bitrate"?:extract(.,"URI=&quot;.+?(\d+)_K.+?&quot;",1)[.] ! x"{.}kbps",
      "url":resolve-uri(extract(.,"URI=&quot;(.+?)&quot;",1),$url)
    },
    for $x at $i in $streams
    where if (exists($media[contains(.,"TYPE=AUDIO")]))
          then contains($x,"RESOLUTION")
          else $x
    group by $file:=x:lines($x)[last()]
    let $br:=extract($x[last()],"BANDWIDTH=(\d+)",1),
        $br2:=extract($file,"=(\d+)",1,"*")
    order by $br
    count $i
    return {
      "id":"hls-"||$i + count($media[contains(.,"TYPE=AUDIO")]),
      "format":if (contains($x[last()],"RESOLUTION"))
        then if (exists($media[contains(.,"TYPE=AUDIO")]))
          then "m3u8[h264]"
          else "m3u8[h264+aac]"
        else "m3u8[aac]",
      "resolution"?:concat(
        extract($x[last()],"RESOLUTION=([\dx]+)",1)[.],
        extract($x[last()],"FRAME-RATE=([\d\.]+)",1)[.] ! x"@{round-half-to-even(.,3)}fps"
      )[.],
      "bitrate"?:if ($br2[1])
        then join((round($br2[2] div 1000),round($br2[1] div 1000)),"|")||"kbps"
        else round($br div 1000)||"kbps",
      "url":resolve-uri($file,$url)
    }
  }
};

declare function xivid:mpd-to-json($mpd) as array() {
  array{
    {
      "id":"dash-0",
      "format":"mpd[manifest]",
      "url":$mpd[. instance of string]
    }[url],
    for $x at $i in (
      if ($mpd instance of node()) then $mpd else doc($mpd)
    )//Representation
    order by boolean($x/@width),$x/@bandwidth
    count $i
    return {
      "id":"dash-"||$i,
      "format":x"{substring-after($x/(.,..)/@mimeType,"/")}[{
        tokenize($x/@codecs,"\.")[1] ! (
          if (.="mp4a") then "aac" else
          if (.="avc1") then "h264" else .
        )
      }]",
      "resolution"?:$x/@width ! x"{.}x{$x/@height}@{
        round-half-to-even(
          eval(replace($x/@frameRate,"/"," div ")),3
        )
      }fps",
      "samplerate"?:$x/@audioSamplingRate ! x"{. div 1000}kHz",
      "bitrate":x"{round($x/@bandwidth div 1000)}kbps",
      "url":if ($mpd instance of string)
        then resolve-uri($x/BaseUrl,$mpd)
        else $x/BaseUrl
    }
  }
};

declare function xivid:adjust-dateTime-to-dst($arg as anyAtomicType) as dateTime {
  let $is-summertime:=function($arg as dateTime) as boolean {
    let $dst:=
      for $month in ("03","10")
      let $day:=(25 to 31)[
        days-from-duration(
          date(x"{year-from-dateTime($arg)}-{$month}-{.}") - date("0000-01-01")
        ) mod 7 eq 0
      ] return
      dateTime(x"{year-from-dateTime($arg)}-{$month}-{$day}T01:00:00Z")
    return
    $dst[1] le dateTime($arg) and dateTime($arg) lt $dst[2]
  }
  return
  adjust-dateTime-to-timezone(
    dateTime($arg),
    if ($is-summertime(current-dateTime())) then
      if ($is-summertime(dateTime($arg))) then
        implicit-timezone()
      else
        implicit-timezone() - duration("PT1H")
    else if ($is-summertime(dateTime($arg))) then
      implicit-timezone() + duration("PT1H")
    else
      implicit-timezone()
  )
};

declare function xivid:string-to-utc-dateTime($arg as string) as dateTime {
  let $month:={
        "jan":"01","feb":"02","mrt":"03","maart":"03","apr":"04",
        "mei":"05","jun":"06","jul":"07","aug":"08",
        "sep":"09","okt":"10","nov":"11","dec":"12"
      },
      $dt:=if ($arg castable as dateTime) then
        $arg
      else
        let $i:=tokenize($arg,"[\s-]") return
        concat(
          join(
            (
              $i[3],
              if ($i[2] castable as integer)
              then $i[2]
              else ($month($i[2]),$month(substring($i[2],1,3))),
              format-integer($i[1],"00")
            ),"-"
          ),
          "T",
          substring(
            join(
              tokenize($i[4],":") ! format-integer(.,"00"),":"
            )||":00",
            1,8
          )
        )
  return
  adjust-dateTime-to-timezone(
    xivid:adjust-dateTime-to-dst($dt),
    duration("PT0S")
  )
};

declare function xivid:bin-xor($a as integer,$b as integer) as integer {
  let $bin:=($a,$b) ! x:integer-to-base(.,2),
      $len:=max($bin ! string-length()),
      $val:=$bin ! format-integer(.,string-join((1 to $len) ! 0))
  return
  string-join(
    (1 to $len) ! (
      if (substring($val[1],.,1) eq substring($val[2],.,1)) then 0 else 1
    )
  ) ! x:integer(.,2)
};

declare function xivid:info($json as object()) as string* {
  let $lbl:={
        "name":"Naam:","date":"Datum:","duration":"Tijdsduur:",
        "start":"Begin:","end":"Einde:","expdate":"Gratis tot:",
        "formats":"Formaten:"
      },
      $len:=$json() ! string-length($lbl(.)),
      $fmts:=array{
        {
          "id":"id","format":"formaat",
          "language":"taal","resolution":"resolutie",
          "samplerate":"frequentie","bitrate":"bitrate"
        },
        $json/(formats)()
      },
      $f_lbl:=$fmts(1)() ! distinct-values(
        for $x in $fmts()[position() gt 1] return .[$x(.)]
      ),
      $f_len:=$f_lbl[position() lt last()] ! max(
        $fmts()(.) ! string-length()
      ),
      $dur:=$json[start]/(start,duration) ! (
        dayTimeDuration(.) div dayTimeDuration("PT1S")
      ),
      $ss:=($dur[1] - $dur[1] mod 30,$dur[1] mod 30)
  return (
    for $x at $i in $json() return
    concat(
      $lbl($x),
      string-join((1 to max($len) - $len[$i] + 1) ! " "),
      if ($x="formats") then
        join(
          $fmts() ! string-join(
            for $x at $i in $f_lbl return (
              if (position() eq count($fmts()) and $i eq count($f_lbl))
              then .($x)||" (best)"
              else .($x),
              (1 to $f_len[$i] - string-length(.($x)) + 2) ! " "
            )
          ),"&#10;"||(1 to max($len) + 1) ! " "
        )
      else if ($x=("date","expdate")) then
        format-dateTime(
          xivid:adjust-dateTime-to-dst($json($x)),
          "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
        )
      else if ($x=("duration","start","end")) then
        duration($json($x)) + time("00:00:00")
      else
        $json($x)
    ),
    concat(
      x"Download:{string-join((1 to max($len) - 9 + 1) ! " ")}ffmpeg ",
      $ss[1][. gt 0] ! x"-ss {.} ",
      "-i <url> ",
      $ss[2][. gt 0] ! x"-ss {.} ",
      x"-t {$dur[2]} -c copy <bestandsnaam>"
    )[exists($dur)]
  )
};

declare function xivid:bbvms(
  $url as string?,$publ as string?,$title as string?
) as object()? {
  json-doc($url)/(
    if (clipData/sourcetype="live") then {
      "name":x"{if ($publ) then $publ else publicationData/label}: Livestream",
      "date":adjust-dateTime-to-timezone(
        current-dateTime() + duration("PT0.5S"),
        duration("PT0S")
      ) ! substring(.,1,19)||"Z",
      "formats":xivid:m3u8-to-json(clipData/(assets)()/src)
    } else {
      "name":join(
        (
          if ($publ) then $publ else publicationData/label,
          if ($title) then $title else clipData/title
        ),": "
      ),
      "date":adjust-dateTime-to-timezone(
        dateTime(clipData/publisheddate) + duration("PT0.5S"),
        duration("PT0S")
      ) ! substring(.,1,19)||"Z",
      "duration"?:clipData/length * duration("PT1S"),
      "formats"?:let $host:=publicationData return
      clipData/array{
        (subtitles)()/{
          "id":"sub-1",
          "format":"srt",
          "language":isocode,
          "label":languagename,
          "url":x"{$host/baseurl}/subtitle/{id}.srt"
        },
        for $x at $i in (assets)()[not(ends-with(src,"m3u8"))]
        order by exists($x/isSource),$x/bandwidth
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":x"{$x/width}x{$x/height}",
          "bitrate":$x/bandwidth||"kbps",
          "url":resolve-uri($x/src,$host/defaultMediaAssetPath)
        },
        xivid:m3u8-to-json(
          resolve-uri(
            (assets)()[ends-with(src,"m3u8")]/src,
            $host/defaultMediaAssetPath
          )
        )(),
        let $org:=parse-json(s3Info) return {
          "id":"pg-"||count((assets)()[not(ends-with(src,"m3u8"))]) + 1,
          "format":($org/format/filename,src)[1] ! (
            if (ends-with(.,"mkv")) then "mkv[h264+opus]"
            else if (ends-with(.,"mxf")) then "mxf[mpeg2+pcm]"
            else "mp4[h264+aac]"
          ),
          "resolution":x"{originalWidth}x{originalHeight}",
          "bitrate"?:$org/format/x"{round(tokenize(bit_rate)[1] * 1024)}kbps",
          "url":(
            $org/format/filename,
            resolve-uri(
              .[not(src = (assets)()/src)]/src[.],
              $host/defaultMediaAssetPath
            )
          )[1]
        }[url]
      }[exists(.())]
    }
  )
};

(:~
 : --------------------------------
 : Extractors
 : --------------------------------
 :)

declare function xivid:npo($url as string) as object()? {
  let $prid:=if (matches($url,"https://www.npostart.nl/live/"))
        then doc($url)//npo-player/@media-id
        else if (matches($url,"https://radioplayer.npo.nl/"))
        then parse-json(
          doc($url)//script/substring-after(.,"window.config=")
        )/request-decode(embedVideoUrl)/params/mid
        else extract($url,"[A-Z\d_]+$"),
      $cookies:=x:request({
        "headers":"X-Requested-With: XMLHttpRequest",
        "url":"https://www.npostart.nl/api/token"
      })/extract(headers,"Set-Cookie: (.+?);",1,"*"),
      $token:=x:request({
        "method":"POST",
        "headers":(
          "X-Requested-With: XMLHttpRequest",
          replace(uri-decode($cookies[1]),"XSRF-TOKEN=","X-XSRF-TOKEN: "),
          "Cookie: "||$cookies[2]
        ),
        "url":"https://www.npostart.nl/player/"||$prid
      })/json
  return
  parse-json(
    extract(doc($token/embedUrl)[.//video]//script,"var video =(.+);",1)
  )/{
    "name":if (type="liveradio")
      then x"NPO: {title} Livestream"
      else concat(
        "NPO: ",franchiseTitle,
        if (exists(episodeNumber))
        then concat(
          " S",format-integer(seasonNumber,"00"),
          "E",format-integer(episodeNumber,"00")
        )
        else ": "||title
      ),
    "date":broadcastDate,
    "duration"?:duration * duration("PT1S"),
    "start"?:startAt * duration("PT1S"),
    "end"?:(startAt + duration) * duration("PT1S"),
    "formats":array{
      (
        if (not(exists((subtitles)())) and parentId)
        then x:request({
          "method":"POST",
          "headers":(
            "X-Requested-With: XMLHttpRequest",
            replace(uri-decode($cookies[1]),"XSRF-TOKEN=","X-XSRF-TOKEN: "),
            "Cookie: "||$cookies[2]
          ),
          "url":"https://www.npostart.nl/player/"||parentId
        })/parse-json(
          extract(doc(json/embedUrl)[.//video]//script,"var video =(.+);",1)
        )
        else .
      )/(subtitles)()/{
        "id":"sub-1",
        "format":"vtt",
        "language":language,
        "label":label,
        "url":src
      },
      xivid:m3u8-to-json(
        x:request({
          "method":"POST",
          "url":request-combine(
            x"https://start-player.npo.nl/video/{
              if (not(exists((subtitles)())) and parentId)
              then parentId
              else $prid
            }/streams",
            {"profile":"hls","quality":"npo","tokenId":$token/token}
          )/url
        })/json/stream[not(exists(protection))]/src
      )()
    }
  }[exists((formats)())]
};

declare function xivid:nos($url as string) as object()? {
  let $src:=parse-json(doc($url)//script[@type="application/json"])//data return
  $src/(video,(items)()[type="video"][1])/{
    "name":x"{$src/supplyChannelName}: {title}",
    "date":adjust-dateTime-to-timezone(
      dateTime(replace($src/publishedAt,"(.{22})(.{2})","$1:$2")),
      duration("PT0S")
    ),
    "duration":time(
      substring("00:00:00",1,8 - string-length(duration))||duration
    ) - time("00:00:00"),
    "formats":xivid:m3u8-to-json(
      x:request({"method":"HEAD","url":source/url})/url
    )
  }
};

declare function xivid:rtl($url as string) as object()? {
  json-doc(
    "https://api.rtl.nl/rtlxl/metadata/api/metadata/"||(
      if (contains($url,"rtlnieuws.nl"))
      then doc($url)//@data-uuid
      else extract($url,"[0-9a-z-]+$")
    )
  )/{
    "name":x"RTL: {series/title} - {title}",
    "date":broadcastDateTime,
    "duration":duration * duration("PT1S"),
    "formats":xivid:m3u8-to-json(
      x:request({
        "headers":"authorization: Bearer "||json-doc(
          "https://api.rtl.nl/rtlxl/token/api/2/token"
        )/accessToken,
        "url":(assets)()[type="Video"]/request-combine(
          url,{"device":"web","format":"hls"}
        )/url
      })/json/manifest
    )
  }
};

declare function xivid:kijk($url as string) as object()? {
  x:request({
    "headers":"Accept: application/json",
    "url":request-combine(
      "https://graph.kijk.nl/graphql",
      {
        "query":concat(
          "query{programs(guid:&quot;",
          extract($url,"\w+$"),
          "&quot;){items{__typename,type,guid,title,duration,",
          "tvSeasonEpisodeNumber,seriesEpisodeNumber,seasonNumber,",
          "media{mediaContent{assetTypes,sourceUrl,type},availableDate,",
          "expirationDate,availabilityState},series{guid,title}}}}"
        )
      }
    )/url
  })/(json//items)()/{
    "name":concat(
      "Kijk: ",
      join((series/title,title)," - "),
      .[exists(seasonNumber)]/concat(
        " S",
        format-integer(seasonNumber,"00"),
        "E",
        format-integer(tvSeasonEpisodeNumber,"00")
      )
    ),
    "date":.//availableDate div 1000 *
      duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
    "duration":round(duration) * duration("PT1S"),
    "expdate":.//expirationDate div 1000 *
      duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
    "formats":array{
      for $x at $i in (.//mediaContent)()[type="webvtt"]
      order by $x/sourceUrl
      count $i
      return
      $x/{
        "id":"sub-"||$i,
        "format":"vtt",
        "language":"nl",
        "label":substring((assetTypes)(),17),
        "url":sourceUrl
      },
      xivid:m3u8-to-json(
        (.//mediaContent)()[
          type="m3u8" and ends-with((assetTypes)(),"public")
        ]/sourceUrl
      )()
    }
  }
};

declare function xivid:tvblik($url as string) as object()? {
  let $host:=extract(
    doc($url)//(
      div[@id="embed-player"]/(@data-episode,a/@href),
      div[@class="video_thumb"]//@onclick,
      iframe[@class="sbsEmbed"]/@src
    ),
    "(npo|rtl|kijk).+(?:/|video=)([\w-]+)",(1,2)
  ) return
  if ($host[1]="npo") then
    xivid:npo("https://www.npostart.nl/"||$host[2])
  else if ($host[1]="rtl") then
    xivid:rtl("https://www.rtlxl.nl/video/"||$host[2])
  else
    xivid:kijk("https://kijk.nl/video/"||$host[2])
};

declare function xivid:regiogroei($url as string) as object()? {
  let $omroep:={
        "omropfryslan":{
          "livestreamId":3748627,
          "headerId":"friesland.fryslan",
          "bbvms":"https://omropfryslan.bbvms.com/p/regiogroei_fryslan_web_videoplayer/c"
        },
        "rtvnoord":{
          "livestreamId":3977713,
          "headerId":"groningen",
          "bbvms":"https://rtvnoord.bbvms.com/p/regiogroei_web_videoplayer/c"
        },
        "rtvdrenthe":{
          "livestreamId":3230738,
          "headerId":"drenthe",
          "bbvms":"https://rtvdrenthe.bbvms.com/p/regiogroei_drenthe_web_videoplayer/c"
        },
        "rtvoost":{
          "livestreamId":4198331,
          "headerId":"overijssel",
          "bbvms":"https://rtvoost.bbvms.com/p/regiogroei_oost_web_videoplayer/c"
        },
        "omroepwest":{
          "livestreamId":2054317,
          "headerId":"zh-west",
          "bbvms":"https://omroepwest.bbvms.com/p/regiogroei_west_web_videoplayer/c"
        },
        "rijnmond":{
          "livestreamId":1227908,
          "headerId":"zh-rijnmond",
          "bbvms":"https://rijnmond.bbvms.com/p/regiogroei_rijnmond_web_videoplayer/c"
        },
        "rtvutrecht":{
          "livestreamId":3742011,
          "headerId":"utrecht",
          "bbvms":"https://rtvutrecht.bbvms.com/p/regiogroei_utrecht_web_videoplayer/c"
        },
        "gld":{
          "livestreamId":3651657,
          "headerId":"gelderland",
          "bbvms":"https://omroepgelderland.bbvms.com/p/regiogroei_gelderland_web_videoplayer/c"
        },
        "omroepzeeland":{
          "livestreamId":3745936,
          "headerId":"zeeland",
          "bbvms":"https://omroepzeeland.bbvms.com/p/regiogroei_zeeland_web_videoplayer/c"
        }
      },
      $host:=extract($url,"www\.(.+)\.nl",1),
      $path:=tokenize($url,"/")
  return
  map:get($omroep,$host)/xivid:bbvms(
    x"{bbvms}/{
      if (ends-with($url,"live"))
      then livestreamId
      else x:request(
        map:merge((
          {
            "headers":(
              x"Accept: application/vnd.groei.{headerId}+json;v=3.0",
              "X-Groei-Platform: web","X-Groei-Layout: wide"
            )
          },
          request-combine(
            "https://api.regiogroei.cloud/page/episode/"||$path[last()],
            {"slug":$path[last() - 1],"origin":$path[last()]}
          )
        ))
      )/json/(components)(1)/sourceId
    }.json",
    if ($host = "omropfryslan") then "Omrop Frysl&#226;n" else (),
    if (ends-with($url,"live")) then ()
    else normalize-space(doc($url)//h1[@class="program-header_title"])
  )
};

declare function xivid:obr($url as string) as object()? {
  if ($url = "https://www.omroepbrabant.nl/tv")
  then xivid:bbvms("https://omroepbrabant.bbvms.com/p/default/c/1080520.json",(),())
  else xivid:bbvms(
    x"https://omroepbrabant.bbvms.com/p/default/c/sourceid_string:{
      extract("'$url'","\d+",0,"*")[last()]
    }.json",
    (),
    doc($url)//meta[@property="og:title"]/normalize-space(@content)
  )
};

declare function xivid:l1($url as string) as object()? {
  doc($url)/(
    if ($url = "https://l1.nl/live-l1-tv")
    then xivid:bbvms(//div[@class="bbwLive-player"]/script/@src||"on",(),())
    else xivid:bbvms(
      x"https://limburg.bbvms.com/p/L1_video/c/{
        //div[@class="bbw bbwVideo"]/@data-id
      }.json",
      (),
      //meta[@property="og:title"]/@content
    )
  )
};

declare function xivid:nhnieuws($url as string) as object()? {
  doc($url)/(
    if (//article) then
      parse-json(
        //script/substring-after(.,"INITIAL_PROPS__ = ")
      )/pageData/{
        "name":if (contains($url,"nhnieuws.nl"))
          then "NH Nieuws: "||title
          else "AT5: "||title,
        "date":created * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
        "formats":xivid:m3u8-to-json(
          (blocks)()[type=("video","headerVideo")]/video/stream/url
        )
      }
    else {
      "name":substring-after(//head/title,"Media - ")||": Livestream",
      "date":adjust-dateTime-to-timezone(
        current-dateTime() + duration("PT0.5S"),
        duration("PT0S")
      ) ! substring(.,1,19)||"Z",
      "formats":xivid:m3u8-to-json(
        parse-json(
          //script/substring-after(.,"INIT_DATA__ = ")
        )/videoStream
      )
    }
  )
};

declare function xivid:ofl($url as string) as object()? {
  let $src:=doc($url),
      $info:=$src//div[@class="fn-jw-player fn-videoplayer"]
  return
  if ($info/@data-page-type="home") then {
    "name":"Omroep Flevoland: Livestream",
    "date":adjust-dateTime-to-timezone(
      current-dateTime() + duration("PT0.5S"),
      duration("PT0S")
    ) ! substring(.,1,19)||"Z",
    "formats":xivid:m3u8-to-json($info/@data-file)
  } else {
    "name":"Omroep Flevoland: "||normalize-space($src//h2),
    "date":xivid:string-to-utc-dateTime(
      $src//header[@class="header"]/div/join(
        if (span/span[@class="d--block--sm"])
        then extract(
          span/span[@class="d--block--sm"],
          "(\d+ \w+ \d+) \| ([\d:]+)",(1,2)
        )
        else extract(span,"[\d:-]+",0,"*")
      )
    ),
    "formats":array{
      {
        "id":"pg-1",
        "format":"mp4[h264+aac]",
        "resolution":"960x540",
        "url":$info/@data-file
      }
    }
  }
};

declare function xivid:dumpert($url as string) as object()? {
  let $json:=parse-json(parse-json(
        doc($url)//script/extract(.,"JSON\.parse\((.+)\)",1)[.]
      ))/items/item/item[media_type="VIDEO"],
      $fmts:=$json//variants,
      $host:={
        "youtube":"https://youtu.be/",
        "twitter":"https://twitter.com/i/status/"
      }
  return
  if ($fmts()/version="embed" and not($fmts()/version="stream")) then
    let $uri:=tokenize($fmts()/uri,":") return
    eval(x"xivid:{$uri[1]}(&quot;{$host($uri[1])}{$uri[2]}&quot;)")
  else
    $json/{
      "name":"Dumpert: "||title,
      "date":adjust-dateTime-to-timezone(dateTime(date),duration("PT0S")),
      "duration":(media)()/duration * duration("PT1S"),
      "formats":array{
        for $x at $i in ("mobile","tablet","720p","original") return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "url":$fmts()[version=$x and ends-with(uri,"mp4")]/uri
        }[url],
        xivid:m3u8-to-json($fmts()[version="stream"]/uri)()
      }
    }
};

declare function xivid:autojunk($url as string) as object()? {
  doc($url)//div[@id="playerWrapper"]/(
    .[iframe]/xivid:youtube(iframe/@src),
    .[script]/{
      "name":"Autojunk: "||//meta[@property="og:title"]/@content,
      "date":xivid:string-to-utc-dateTime(
        join(extract(//span[@class="posted"]/text(),"[\d:-]+",0,"*"))
      ),
      "formats"?:array{
        let $id:=extract(//meta[@property="og:image"]/@content,"\d{4}/\d{4}/\d+")
        for $x at $i in (".mp4","_hq.mp4","_720p.mp4") !
          x"https://static.autojunk.nl/flv/{$id}{.}"
        where x:request({
          "method":"HEAD",
          "error-handling":"xxx=accept",
          "url":$x
        })/headers[1] = "HTTP/1.1 200 OK"
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":("640x360","852x480","1280x720")[$i],
          "bitrate":(600,1200,2000)[$i]||"kbps",
          "url":$x
        }
      }
    }
  )
};

declare function xivid:abhd($url as string) as object()? {
  doc($url)//div[@id="playerObject"]/map:merge((
    {
      "name":"ABHD: "||h1/a
    },
    parse-json(
      replace(
        extract(script,"clipData.assets = (.+\]);",1,"s")," //.+",""
      ),
      {"liberal":true()}
    )/{
      "date":dateTime(
        join(
          extract(.(1)/src,"(\d{4})/?(\d{2})(\d{2})",1 to 3),"-"
        )||"T00:00:00Z"
      ),
      "formats":array{
        for $x at $i in .()/src return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":if (ends-with($x,"hq.mp4")) then "852x480" else "1280x720",
          "bitrate":if (ends-with($x,"hq.mp4")) then "1200kbps" else "2000kbps",
          "url":if (matches($x,"\d{14}")) then
            replace($x,"(.+?\d{4})(\d{4})(.+)","$1/$2/$3")
          else
            $x
        }
      }
    }
  ))
};

declare function xivid:autoblog($url as string) as object()? {
  doc($url)/(
    //iframe[contains(@data-lazy-src,"bbvms")]/xivid:bbvms(
      resolve-uri(replace(@data-lazy-src,"html.+","json"),$url),(),()
    ),
    //iframe[contains(@data-lazy-src,"youtube")]/xivid:youtube(
      substring-before(@data-lazy-src,"?")
    )
  )
};

declare function xivid:telegraaf($url as string) as object()? {
  json-doc(
    x"https://content.tmgvideo.nl/playlist/item={
      parse-json(
        doc($url)//script/extract(.,"APOLLO_STATE__=(.+);",1)[.]
      )/(.//videoId)[1]
    }/playlist.json"
  )/(items)()/{
    "name":"Telegraaf: "||title,
    "date":xivid:string-to-utc-dateTime(
      replace(publishedstart,"\s","T")
    ),
    "duration":duration * duration("PT1S"),
    "expdate":publishedend ! xivid:string-to-utc-dateTime(
      replace(.,"\s","T")
    ),
    "formats":array{
      locations/reverse((progressive)())/{
        "id":"pg-"||position(),
        "format":"mp4[h264+aac]",
        "resolution":x"{width}x{height}",
        "url":.//src
      },
      xivid:m3u8-to-json(
        locations/(adaptive)()[type="application/x-mpegURL"]/extract(src,".+m3u8")
      )()
    }
  }
};

declare function xivid:ad($url as string) as object()? {
  let $id:=extract($url,"~p(\d+)",1),
      $json:=json-doc(
        x"https://embed.mychannels.video/sdk/production/{
          if ($id) then $id
          else x:request({
            "headers":"Cookie: authId=8ac8ac9f-3782-4ba2-a449-9dc1fcdacbd5",
            "url":$url
          })/doc/(
            if (//*[@class="mc-embed"])
            then //*[@class="mc-embed"]/extract(@src,"\d+")
            else //div[@data-mychannels-type="video"]/@data-mychannels-id
          )
        }?options=FUTFU_default"
      )
  return
  $json/map:merge((
    {
      "name":x"AD: {(shows)()/title} - {(productions)()/title}"
    },
    (productions)()/{
      "date":xivid:string-to-utc-dateTime(
        replace(publicationDate,"\s","T")
      ),
      "duration":duration * duration("PT1S"),
      "formats":array{
        for $x at $i in reverse((sources)()[type="video/mp4"]) return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":("640x360","1280x720")[$i],
          "url":$x/src
        },
        xivid:m3u8-to-json((sources)(1)/src)()
      }
    }
  ))
};

declare function xivid:lc($url as string) as object()? {
  doc($url)/map:merge((
    parse-json(//script[@type="application/ld+json"])/{
      "name":x"{.(3)/name}: {.(2)/name}",
      "date":replace(.(1)/datePublished,"\+0000","Z")
    },
    json-doc(
      x"https://content.tmgvideo.nl/playlist/item={
        //div[@class="video-player"]/substring-after(@id,"videoplayer-")
      }/playlist.json"
    )/(items)()/{
      "duration":duration * duration("PT1S"),
      "formats":locations/array{
        reverse((progressive)())/{
          "id":"pg-"||position(),
          "format":"mp4[h264+aac]",
          "resolution":x"{width}x{height}",
          "url":(sources)()/src
        },
        xivid:m3u8-to-json(
          (adaptive)()[type="application/x-mpegURL"]/src
        )()
      }
    }
  ))
};

declare function xivid:youtube($url as string) as object()? {
  x:request({
    "headers":(
      "Content-Type: application/json",
      "User-Agent: com.google.android.youtube/18.16.34"
    ),
    "post":serialize(
      {
        "context":{
          "client":{
            "clientName":"ANDROID",
            "clientVersion":"18.16.34",
            "androidSdkVersion":33
          }
        },
        "videoId":extract($url,"[A-Za-z0-9_-]+$")
      },
      {"method":"json"}
    ),
    "url":"https://www.youtube.com/youtubei/v1/player"
  })/json/{
    "name":videoDetails/title,
    "duration"?:videoDetails[not(isLive)]/lengthSeconds * duration("PT1S"),
    "formats":array{
      (.//captionTracks)()[languageCode=("nl","en")]/{
        "id":"sub-"||position(),
        "format":"ttml",
        "language":languageCode,
        "label":name//text,
        "url":baseUrl
      },
      for $x at $i in streamingData/(formats)()
      order by $x/width
      count $i
      return {
        "id":"pg-"||$i,
        "format":extract($x/mimeType,"video/(.+?);",1) ! (
          if (.="3gpp") then "3gpp[mp4v+aac]" else "mp4[h264+aac]"
        ),
        "resolution":x"{$x/width}x{$x/height}@{$x/fps}fps",
        "bitrate":round($x/bitrate div 1000)||"kbps",
        "url":$x/url
      },
      for $x at $i in streamingData[not(hlsManifestUrl)]/(adaptiveFormats)()
      order by boolean($x/width),$x/bitrate
      count $i
      return {
        "id":"dash-"||$i,
        "format":let $mt:=extract($x/mimeType,"/(.+?);.+&quot;(\w+)",(1,2)) return
        x"{$mt[1]}[{
          if ($mt[2]="avc1") then "h264"
          else if ($mt[2]="mp4a") then "aac"
          else $mt[2]
        }]",
        "resolution"?:$x/width ! x"{.}x{$x/height}@{$x/fps}fps",
        "samplerate"?:$x/audioSampleRate ! x"{. div 1000}kHz",
        "bitrate":round($x/bitrate div 1000)||"kbps",
        "url":$x/url
      },
      xivid:m3u8-to-json(streamingData/hlsManifestUrl)()
    }
  }
};

declare function xivid:vimeo($url as string) as object()? {
  json-doc(x"https://player.vimeo.com/video/{extract($url,"\d+")}/config")/{
    "name":video/x"{owner/name}: {title}",
    "date":adjust-dateTime-to-timezone(
      dateTime(replace(seo/upload_date,"\s","T")||"-05:00"),
      duration("PT0S")
    ),
    "duration":video/duration * duration("PT1S"),
    "formats":request/files/array{
      for $x at $i in (progressive)()
      order by $x/width
      count $i
      return
      $x/{
        "id":"pg-"||$i,
        "format":"mp4[h264+aac]",
        "resolution":x"{width}x{height}@{fps}fps",
        "url":url
      },
      xivid:m3u8-to-json((hls//url)[1])()
    }
  }
};

declare function xivid:dailymotion($url as string) as object()? {
  json-doc(
    "https://www.dailymotion.com/player/metadata/video/"||
    extract($url,"video/(x[0-9a-z]+)",1)
  )/{
    "name":"Dailymotion: "||title,
    "date":created_time * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
    "duration":duration * duration("PT1S"),
    "formats":xivid:m3u8-to-json(qualities//url)
  }
};

declare function xivid:rumble($url as string) as object()? {
  request-combine(
    "https://rumble.com/embedJS/u3/",
    {
      "request":"video",
      "ver":"2",
      "v":if (matches($url,"^v[0-9a-z]+")) then $url else (
        if (contains($url,"/embed/"))
        then $url
        else parse-json(
          doc($url)//script[@type="application/ld+json"]
        )(1)/embedUrl
      ) ! extract(.,"embed/(v[0-9a-z]+)",1)
    }
  )/json-doc(url)/{
    "name":x"{author/name}: {parse-html(title)}",
    "date":dateTime(pubDate),
    "duration"?:.[live=0]/duration * duration("PT1S"),
    "formats":array{
      cc/nl/{
        "id":"sub-1",
        "format":"vtt",
        "language":"nl",
        "label":language,
        "url":path
      },
      for $x at $i in ua/(mp4,webm)/*
      order by $x/meta/bitrate
      count $i
      return
      $x/{
        "id":"pg-"||$i,
        "format":if (ends-with(url,"webm"))
          then "webm[vp8+vorbis]"
          else "mp4[h264+aac]",
        "resolution":meta/x"{w}x{h}",
        "bitrate":meta/bitrate||"kbps",
        "url":url
      },
      xivid:m3u8-to-json(ua/hls/auto/url)()
    }
  }
};

declare function xivid:reddit($url as string) as object()? {
  json-doc(
    if (request-decode($url)/host = "v.redd.it")
    then x:request({"method":"HEAD","url":$url})/url||".json"
    else $url||".json"
  )(1)/data/(children)()/data/(
    if (is_reddit_media_domain) then {
      "name":x"{subreddit}: {title}",
      "date":created * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
      "duration":media/reddit_video/duration * duration("PT1S"),
      "formats":media/reddit_video/array{
        xivid:m3u8-to-json(string(parse-html(hls_url)))(),
        xivid:mpd-to-json(string(parse-html(dash_url)))()
      }
    }
    else
      xivid:youtube(request-decode(parse-html(url))/params/v)
  )
};

declare function xivid:twitch($url as string) as object()? {
  let $call_api:=function($query as object()) as object() {
        x:request({
          "headers":"Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko",
          "post":serialize($query,{"method":"json"}),
          "url":"https://gql.twitch.tv/gql"
        })/json/data/*
      },
      $path:=tokenize(
        request-decode($url)/substring-after(url,host),"/"
      )[.]
  return
  $call_api(
    {
      "operationName":"ComscoreStreamingQuery",
      "variables":{
        "channel":if ($path=("video","videos","clip")) then "" else $path[last()],
        "isLive":if ($path=("video","videos","clip")) then false() else true(),
        "isVodOrCollection":if ($path=("video","videos")) then true() else false(),
        "vodID":if ($path=("video","videos")) then $path[last()] else "",
        "isClip":if ($path="clip") then true() else false(),
        "clipSlug":if ($path="clip") then $path[last()] else ""
      },
      "extensions":{
        "persistedQuery":{
          "version":1,
          "sha256Hash":"e1edae8122517d013405f237ffcc124515dc6ded82480a88daef69c83b53ac01"
        }
      }
    }
  )/{
    "name":"Twitch: "||(
      .[__typename="Video"]/x"{owner/displayName} - {title}",
      .[__typename="Clip"]/x"{broadcaster/displayName} - {title}",
      .[__typename="User"]/x"{displayName}: {broadcastSettings/title}"
    ),
    "date":.//createdAt,
    "duration"?:(lengthSeconds,durationSeconds) * duration("PT1S"),
    "formats":if ($path="clip") then
      $call_api({
        "operationName":"VideoAccessToken_Clip",
        "variables":{"slug":$path[last()]},
        "extensions":{
          "persistedQuery":{
            "version":1,
            "sha256Hash":"36b89d2507fce29e5ca551df756d27c1cfe079e2609642b4390aa4c35796eb11"
          }
        }
      })/array{
        for $x at $i in (videoQualities)()
        order by $x/quality
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":("640x320","854x480","1280x720","1920x1080")[$i],
          "url":request-combine(
            $x/sourceURL,
            playbackAccessToken/{"sig":signature,"token":value}
          )/url
        }
      }
    else
      request-combine(
        concat(
          "https://usher.ttvnw.net/",
          if ($path=("video","videos"))
          then "vod/"
          else "api/channel/hls/",
          $path[last()],
          ".m3u8"
        ),
        $call_api({
          "query":concat(
            if ($path=("video","videos"))
            then "{videoPlaybackAccessToken(id:&quot;"
            else "{streamPlaybackAccessToken(channelName:&quot;",
            $path[last()],
            "&quot;,params:{platform:&quot;web&quot;,playerBackend:&quot;",
            "mediaplayer&quot;,playerType:&quot;site&quot;}){value,signature}}"
          )
        })/{
          "allow_source":true(),
          "allow_audio_only":true(),
          "allow_spectre":true(),
          "fast_bread"?:if ($path=("video","videos")) then () else true(),
          "p":(random-seed(),100000 + random(9900000)),
          "player_backend":"mediaplayer",
          "playlist_include_framerate":true(),
          "sig":signature,
          "token":value
        }
      )/xivid:m3u8-to-json(url)
  }
};

declare function xivid:mixcloud($url as string) as object()? {
  let $decrypt:=function($arg as string) as string {
        let $key:=x:cps(
          "IFYOUWANTTHEARTISTSTOGETPAIDDONOTDOWNLOADFROMMIXCLOUD"
        ) return
        string-join(
          x:cps(
            for $x at $i in x:cps(
              binary-to-string(base64Binary($arg))
            ) return
            xivid:bin-xor($x,$key[($i - 1) mod count($key) + 1])
          )
        )
      },
      $csrf:=x:request({"method":"HEAD","url":$url})/substring-before(
        substring-after(headers[contains(.,"csrftoken")],"="),";"
      ),
      $us:=tokenize(substring-after($url,"mixcloud.com/"),"/")
  return
  x:request({
    "headers":(
      "Content-Type: application/json",
      "Referer: "||$url,
      "X-CSRFToken: "||$csrf,
      "Cookie: csrftoken="||$csrf
    ),
    "post":serialize(
      {
        "query":concat(
          "{cloudcastLookup(lookup:{username:&quot;",
          $us[1],"&quot;,slug:&quot;",$us[2],
          "&quot;}){name,owner{displayName,url,username},",
          "publishDate,audioLength,streamInfo{hlsUrl,url}}}"
        )
      },
      {"method":"json"}
    ),
    "url":"https://www.mixcloud.com/graphql"
  })/json//cloudcastLookup/{
    "name":x"{owner/displayName} - {name}",
    "date":dateTime(publishDate),
    "duration":audioLength * duration("PT1S"),
    "formats":array{
      {
        "id":"pg-1",
        "format":"m4a[aac]",
        "url":$decrypt(streamInfo/url)
      },
      xivid:m3u8-to-json($decrypt(streamInfo/hlsUrl))()
    }
  }
};

declare function xivid:soundcloud($url as string) as object()? {
  parse-json(
    doc($url)//script/extract(.,"__sc_hydration = (.+);",1)
  )()[hydratable="sound"]/data/{
    "name":x"{user/(full_name,username)[.][1]} - {title}",
    "date":created_at,
    "duration":round(duration div 1000) * duration("PT1S"),
    "formats":media/transcodings/array{
      .()[format/protocol="progressive"]/map:merge((
        {
          "id":"pg-1",
          "format":substring-before(preset,"_")
        },
        request-combine(
          url,{"client_id":"RCfT93M4biAV6sjNiab6pMV1eYEgatjk"}
        )/json-doc(url)/{
          "bitrate":extract(url,"\.(\d+)\.",1)||"kbps",
          "url":url
        }
      )),
      for $x at $i in .()[format/protocol="hls"]
      let $a_url:=request-combine(
            $x/url,{"client_id":"RCfT93M4biAV6sjNiab6pMV1eYEgatjk"}
          )/json-doc(url)/url,
          $br:=extract($a_url,"\.(\d+)\.",1)
      order by $br
      count $i
      return {
        "id":"hls-"||$i,
        "format":x"m3u8[{substring-before($x/preset,"_")}]",
        "bitrate":$br||"kbps",
        "url":$a_url
      }
    }
  }
};

declare function xivid:facebook($url as string) as object()? {
  doc($url)/map:merge((
    {
      "name":"Facebook: "||//meta[@property="og:title"]/@content,
      "date":adjust-dateTime-to-timezone(
        dateTime(
          parse-json(
            //script[@type="application/ld+json"]
          )/substring(dateCreated,1,22)||":00"
        ),
        duration("PT0S")
      )
    },
    //script/extract(.,"ScheduledApplyEach,(.+?)\);",1)[.] !
    parse-json(.)[.//playable_url]//media/{
      "duration":round(playable_duration_in_ms div 1000) * duration("PT1S"),
      "formats":array{
        (video_available_captions_locales)()/{
          "id":"sub-1",
          "format":"srt",
          "language":locale,
          "label":localized_language,
          "url":captions_url
        }[url],
        (playable_url,playable_url_quality_hd) ! {
          "id":"pg-"||position(),
          "format":"mp4[h264+aac]",
          "url":.
        },
        xivid:mpd-to-json(parse-xml(dash_manifest))()
      }
    }
  ))
};

declare function xivid:twitter($url as string) as object()? {
  let $bearer_token:=concat(
        "Authorization: Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejR",
        "COuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"
      ),
      $guest_token:=x:request({
        "method":"POST",
        "headers":$bearer_token,
        "url":"https://api.twitter.com/1.1/guest/activate.json"
      })/json/guest_token,
      $call_api:=function($path as string,$query as object()?) as object() {
        x:request({
          "headers":($bearer_token,"x-guest-token: "||$guest_token),
          "url":if (empty($query)) then
            "https://api.twitter.com/1.1/"||$path
          else
            request-combine("https://api.twitter.com/1.1/"||$path,$query)/url
        })/json
      },
      $statuses:=$call_api(
        "statuses/show.json",
        {"id":extract($url,"\d+$"),"tweet_mode":"extended"}
      )
  return
  if (exists($statuses/extended_entities)) then
    $statuses/{
      "name":"Twitter: "||(.//title,full_text)[1],
      "date":parse-ietf-date(created_at),
      "duration":round(.//duration_millis div 1000) * duration("PT1S"),
      "formats":array{
        for $x at $i in (extended_entities//variants)()[content_type="video/mp4"]
        order by $x/bitrate
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":extract($x/url,"\d+x\d+"),
          "bitrate":$x/bitrate div 1000||"kbps",
          "url":$x/url
        },
        xivid:m3u8-to-json(
          (extended_entities//variants)()[content_type="application/x-mpegURL"]/url
        )()
      }
    }
  else
    let $id:=substring-after($statuses/entities//expanded_url,"broadcasts/") return
    $call_api("broadcasts/show.json",{"ids":$id})/(broadcasts)($id)/{
      "name":"Twitter: "||status,
      "date":round(start_ms div 1000) *
        duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
      "duration":round((end_ms - start_ms) div 1000) * duration("PT1S"),
      "formats":array{
        {
          "id":"hls-1",
          "format":"m3u8[h264+aac]",
          "resolution":x"{width}x{height}",
          "url":$call_api("live_video_stream/status/"||media_key,())//location
        }
      }
    }
};

declare function xivid:instagram($url as string) as object()? {
  parse-json(
    doc($url)//script/extract(.,"_sharedData = (.+);",1)[.]
  )//shortcode_media/{
    "name":"Instagram: "||edge_media_to_caption//text,
    "date":taken_at_timestamp * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
    "duration":round(video_duration) * duration("PT1S"),
    "formats":array{
      {
        "id":"pg-1",
        "format":"mp4[h264+aac]",
        "url":video_url
      }
    }
  }
};

declare function xivid:pornhub($url as string) as object()? {
  doc(
    if (contains($url,"/embed/"))
    then replace($url,"/embed/","/view_video.php?viewkey=")
    else $url
  )/map:put(
    if (exists(//script[@type="application/ld+json"])) then
      parse-json(//script[@type="application/ld+json"])/{
        "name":"Pornhub: "||parse-html(name),
        "date":dateTime(uploadDate),
        "duration":duration(duration)
      }
    else
      parse-json(
        extract(//div[@id="player"]/script[1],"flashvars_\d+ = (.+);",1)
      )/{
        "name":"Pornhub: "||video_title,
        "date":dateTime(
          date(replace(image_url,".+(\d{4})(\d{2})/(\d{2}).+","$1-$2-$3")),
          time("00:00:00Z")
        ),
        "duration":duration(video_duration * duration("PT1S"))
      },
    "formats",
    let $fmts:=tokenize(
      replace(//div[@id="player"]/script[1],"&quot; \+ &quot;|&quot;",""),
      "flashvars.+?;"
    )[contains(.,"var media_")][position() ge last() - 1] ! string-join(
      for $var in extract(.,"\*/(\w+)",1,"*") return
      substring-before(substring-after(.,$var||"="),";")
    ) return array{
      {
        "id":"sub-1",
        "format":"srt",
        "url":parse-json(
          extract(//div[@id="player"]/script[1],"flashvars_\d+ = (.+);",1)
        )/resolve-uri(closedCaptionsFile,$url)
      }[url],
      for $x at $i in json-doc($fmts[2])() return {
        "id":"pg-"||$i,
        "format":"mp4[h264+aac]",
        "resolution":("426x240","854x480","1280x720","1920x1080")[$i],
        "url":$x/videoUrl
      },
      xivid:m3u8-to-json($fmts[1])()
    }
  )
};

declare function xivid:xhamster($url as string) as object()? {
  parse-json(
    extract(doc($url)//script[@id="initials-script"],"\{.+\}")
  )/{
    "name":"xHamster: "||videoModel/title,
    "date":videoModel/created * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
    "duration":videoModel/duration * duration("PT1S"),
    "formats":xplayerSettings/sources/standard/mp4/array{
      .()[label != "auto"]/{
        "id":"pg-"||position(),
        "format":"mp4[h264+aac]",
        "resolution":{
          "144p":"256x144","240p":"426x240","480p":"854x480",
          "720p":"1280x720","1080p":"1920x1080","2160p":"3840x2160"
        }(quality),
        "url":url
      },
      xivid:m3u8-to-json(.()[label = "auto"]/url)()
    }
  }
};

declare function xivid:youporn($url as string) as object()? {
  doc($url)/map:put(
    parse-json((//script[@type="application/ld+json"])[1])/{
      "name":"YouPorn: "||name,
      "date":dateTime(uploadDate||"T00:00:00Z"),
      "duration":duration(duration)
    },
    "formats",
    array{
      for $x at $i in parse-json(
        extract(//script,"mediaDefinition: (.+),",1)
      )(1)/json-doc(resolve-uri(videoUrl,$url))()[format="mp4"]
      order by $x/quality
      count $i
      return {
        "id":"pg-"||$i,
        "format":"mp4[h264+aac]",
        "resolution":("426x240","854x480","1280x720","1920x1080")[$i],
        "url":$x/videoUrl
      }
    }
  )
};
