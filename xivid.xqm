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

xquery version "3.1-xidel";
module namespace xivid = "https://github.com/Reino17/xivid/";

(:~
 : --------------------------------
 : Helper functions
 : --------------------------------
 :)

declare function xivid:m3u8-to-json($url as string?) as array() {
  let $m3u8:=x:request(
        {"url":$url,"error-handling":"4xx=accept"}[url]
      )[raw[not(contains(.,"#EXT-X-SESSION-KEY:METHOD=SAMPLE-AES"))]],
      $m3u8Url:=if (string-length($m3u8/url) lt 512) then $m3u8/url else $url,
      $streams:=extract(
        $m3u8/raw,
        "#EXT-X-(?:MEDIA:TYPE=(?:AUDIO|VIDEO)|STREAM-INF).+?m3u8.*?$",
        0,"ms*"
      )
  return
  if (exists($m3u8) and not(exists($streams))) then array{
    {
      "id":"hls-1",
      "format":"m3u8[h264+aac]",
      "url":$m3u8Url
    }
  } else array{
    extract($m3u8/raw,"#EXT-X-MEDIA:TYPE=SUBTITLES.+")[.] ! {
      "id":"sub-1",
      "format":"m3u8[vtt]",
      "language":extract(.,"LANGUAGE=&quot;(.+?)&quot;",1),
      "url":resolve-uri(
        extract(.,"URI=&quot;(.+?)&quot;",1),
        $m3u8Url
      )
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
      "url":extract($x,"URI=&quot;(.+mp4)(?:#.+)?&quot;",1)
    },
    {
      "id":"hls-0",
      "format":"m3u8[manifest]",
      "url":$m3u8Url
    }[url],
    for $x at $i in $streams
    group by $path:=x:lines($x)[last()] ! (
      if (contains(.,"URI=")) then
        extract($x,"URI=&quot;(.+)&quot;",1)
      else
        replace(.,"#.+","")
    )
    let $br:=extract($x[last()],"BANDWIDTH=(\d+)",1),
        $br2:=extract($x,"GROUP-ID=.+?-(\d+)",1)[.],
        $br3:=extract($x,"audio.*?=(\d+)(?:-video.*?=(\d+))?",(1,2))[.]
    order by $br
    count $i
    return {
      "id":"hls-"||$i,
      "format":if (contains($x,"avc1") or contains($x,"RESOLUTION")) then
        "m3u8[h264+aac]"
      else
        "m3u8[aac]",
      "resolution":concat(
        extract($x,"RESOLUTION=([\dx]+)",1)[.],
        extract($x,"(?:FRAME-RATE=|GROUP-ID.+?\d{3}p)([\d\.]+)",1)[.] !
          concat("@",round-half-to-even(.,3),"fps")
      )[.],
      "bitrate":(
        if ($br3[1]) then
          join((round($br3[2] div 1000),round($br3[1] div 1000)),"|")
        else 
          ($br2,round($br[.] div 1000))[1]
      ) ! concat(.,"kbps"),
      "url":resolve-uri($path,$m3u8Url)
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
      "format":concat(
        substring-after($x/(.,..)/@mimeType,"/"),
        "[",
        tokenize($x/@codecs,"\.")[1] ! (
          if (.="mp4a") then "aac" else
          if (.="avc1") then "h264" else .
        ),
        "]"
      ),
      "resolution":$x/@width ! concat(
        .,"x",$x/@height,"@",eval(replace($x/@frameRate,"/"," div ")),"fps"
      ),
      "samplerate":$x/@audioSamplingRate ! concat(. div 1000,"kHz"),
      "bitrate":round($x/@bandwidth div 1000)||"kbps",
      "url":$x/BaseUrl
    }
  }
};

declare function xivid:adjust-dateTime-to-dst($arg as anyAtomicType) as dateTime {
  let $is-summertime:=function($arg as dateTime) as boolean {
        let $year:=year-from-dateTime($arg),
            $dst:=for $x in ("-03-","-10-") return
            dateTime(
              concat(
                $year,
                $x,
                (25 to 31)[
                  days-from-duration(
                    date(concat($year,$x,.)) - date("0000-01-01")
                  ) mod 7 eq 0
                ],
                "T01:00:00Z"
              )
            )
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
    else
      if ($is-summertime(dateTime($arg))) then
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
              if ($i[2] castable as integer) then
                $i[2]
              else
                ($month($i[2]),$month(substring($i[2],1,3))),
              format-integer($i[1],"00")
            ),
            "-"
          ),
          "T",
          substring(
            join(tokenize($i[4],":") ! format-integer(.,"00"),":")||":00",
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
        $a()[exists($json(.))] ! $a(.) ! string-length()
      ),
      $c:=array{
        {
          "id":"id",
          "format":"formaat",
          "language":"taal",
          "resolution":"resolutie",
          "samplerate":"frequentie",
          "bitrate":"bitrate"
        },
        $json/(formats)()
      },
      $d:=$c(1)() ! distinct-values(
        for $x in $c()[position() gt 1] return
        .[$x(.)]
      ),
      $e:=$d ! max($c()(.) ! string-length())
  return (
    $a()[exists($json(.))] ! concat(
      substring(
        $a(.)||string-join((1 to $b) ! " "),
        1,$b + 1
      ),
      if (.=$a()[last()]) then
        if (exists($c(2))) then
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

declare function xivid:bbvms(
  $url as string?,
  $publ as string?,
  $title as string?
) as object()? {
  let $json:=json-doc($url),
      $host:=$json/resolve-uri(
        publicationData/defaultMediaAssetPath,
        protocol
      ),
      $orig:=parse-json($json/clipData/s3Info)
  return
  $json/clipData/map:merge((
    {
      "name":join(
        (
          if ($publ) then $publ else $json/publicationData/label,
          if ($title) then $title else .[title]/title
        ),
        ": "
      )
    },
    if (
      sourcetype="live" or
      contains((assets)()[ends-with(src,"m3u8")]/src,"/live/") or
      ends-with((assets)()[ends-with(src,"m3u8")]/src,"hls.m3u8")
    ) then {
      "date":substring(
        adjust-dateTime-to-timezone(
          current-dateTime() + duration("PT0.5S"),
          duration("PT0S")
        ),
        1,19
      )||"Z"
    } else {
      "date":if (ends-with(publisheddate,"Z")) then
        publisheddate
      else
        adjust-dateTime-to-timezone(
          xivid:adjust-dateTime-to-dst(publisheddate),
          duration("PT0S")
        ),
      "duration":length * duration("PT1S")
    },
    {
      "formats":array{
        (subtitles)()/{
          "id":"sub-1",
          "format":"srt",
          "language":isocode,
          "label":languagename,
          "url":concat($json/publicationData/baseurl,"/subtitle/",id,".srt")
        },
        xivid:m3u8-to-json(
          (assets)()[ends-with(src,"m3u8")][1]/resolve-uri(src,$host)
        )(),
        for $x at $i in (assets)()[not(ends-with(src,"m3u8"))]
        order by exists($x/isSource),$x/bandwidth
        count $i
        return
        $x/{
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":.[width]/concat(width,"x",height),
          "bitrate":.[bandwidth]/concat(bandwidth,"kbps"),
          "url":resolve-uri(src,$host) ! (
            if (ends-with(.,"mp4")) then .
            else x:request({"method":"HEAD","url":.})/url
          )
        },
        {
          "id":"pg-"||count((assets)()[not(ends-with(src,"m3u8"))]) + 1,
          "format":extract(src,".+\.(.+)",1) ! concat(
            .,
            if ($orig/ContentType="video/mpeg2") then "[mpeg2+pcm]"
            else if (.="mkv") then "[h264+opus]"
            else "[h264+aac]"
          ),
          "resolution":concat(originalWidth,"x",originalHeight),
          "bitrate":$orig/format/concat(round(tokenize(bit_rate)[1] * 1024),"kbps"),
          "url":if (exists($orig)) then
            $orig/format/filename
          else
            resolve-uri(.[not((assets)()/src = src) and src != ""]/src,$host)
        }[url]
      }[exists(.())]
    }
  ))
};

(:~
 : --------------------------------
 : Extractors
 : --------------------------------
 :)

declare function xivid:npo($url as string) as object()? {
  let $prid:=if (contains($url,"/live/")) then
        doc($url)//npo-player/@media-id
      else
        extract($url,"[A-Z\d_]+$"),
      $token:=x:request({
        "header":"X-Requested-With: XMLHttpRequest",
        "url":"https://www.npostart.nl/api/token"
      })/json/token,
      $token2:=x:request({
        "post":"_token="||$token,
        "url":"https://www.npostart.nl/player/"||$prid
      })/json,
      $info:=parse-json(
        doc($token2/embedUrl)//script/extract(.,"var video =(.+);",1)[.]
      )
  return
  map:merge((
    if (exists($info)) then $info/{
      "name":if (type="livetv") then
        concat(title,": Livestream")
      else
        concat(
          franchiseTitle,
          if (contains(franchiseTitle,title)) then () else ": "||title
        ),
      "date":broadcastDate,
      "duration":duration * duration("PT1S"),
      "start":startAt,
      "end":startAt + duration
    } else
      doc("https://www.npostart.nl/"||$prid)/(
        let $info:=parse-json((//script[@type="application/ld+json"])[1]) return {
          "name"://npo-player-header/concat(@main-title,": ",@share-title),
          "date":adjust-dateTime-to-timezone(
            dateTime($info/uploadDate),duration("PT0S")
          ),
          "duration":$info/duration
        }
      ),
    {
      "formats":array{
        (
          if (not(exists($info/(subtitles)())) and $info/parentId) then
            parse-json(
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
        xivid:m3u8-to-json(
          json-doc(
            request-combine(
              x"https://start-player.npo.nl/video/{$prid}/streams",
              {"profile":"hls","quality":"npo","tokenId":$token2/token}
            )/url
          )/stream[not(exists(protection))]/src
        )()
      }[exists(.())]
    }
  ))
};

declare function xivid:nos($url as string) as object()? {
  parse-json(doc($url)//script[@type="application/json"])//video/{
    "name":"NOS: "||title,
    "date":adjust-dateTime-to-timezone(
      dateTime(substring(published_at,1,22)||":00"),
      duration("PT0S")
    ),
    "duration":duration * duration("PT1S"),
    "formats":array{
       {
         "id":"dash-0",
         "format":"mpd[manifest]",
         "url":x:request({
           "method":"HEAD",
           "url":aspect_ratios/(profiles)()[name="dash_unencrypted"]/url
         }[url])/url
       }[url],
       xivid:m3u8-to-json((formats)(1)/url/mp4)()
     }
  }
};

declare function xivid:rtl($url as string) as object()? {
  parse-json(
    doc(
      if (contains($url,"rtlnieuws.nl")) then
        doc($url)//div[@class="rtl-player__fallback-overlay"]/a/@href
      else
        $url
    )//script[@type="application/json"]
  )//video/{
    "name":concat("RTL: ",series/title," - ",title),
    "date":broadcastDateTime,
    "duration":duration * duration("PT1S"),
    "formats":xivid:m3u8-to-json(
      (assets)()[type="Video"]/json-doc(url||"?device=web&amp;format=hls")/manifest
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
          "&quot;){items{__typename,type,guid,title,duration,tvSeasonEpisodeNumber,",
          "seriesEpisodeNumber,seasonNumber,media{mediaContent{assetTypes,sourceUrl,",
          "type},availableDate,expirationDate,availabilityState},series{guid,title}}}}"
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
        (.//mediaContent)()[type="m3u8" and ends-with((assetTypes)(),"public")]/sourceUrl
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

declare function xivid:regio($url as string) as object()? {
  let $src:=doc($url),
      $script:=resolve-uri(
        if ($url="https://www.omroepgelderland.nl/tv") then
          extract(
            unparsed-text("https://web.omroepgelderland.nl/epg/tv_vanavond/data/html/script.js"),
            "bbw_media_config_url = &apos;(.+)&apos;",1
          )
        else
          $src/(
            //@data-media-url,
            //article/iframe/@src,
            //div[
              starts-with(@class,"bluebillywig") or
              starts-with(@class,"customhtml") or
              @class="bbwLive-player"
            ]/script/@src,
            //div[starts-with(@class,"inlinemedia")]/iframe/@src,
            //div[starts-with(@class,"bluebillywig")]/iframe/@data-src,
            parse-json(
              //script/extract(.,"playerInstance\.setup\((.+)\)",1,"s")[.],
              {"liberal":true()}
            )//file,
            parse-json(//script[@id="__NEXT_DATA__"])/props/pageProps/props/concat(
              "https://omroepbrabant.bbvms.com/p/default/",
              if (clip) then "c/"||integer(clip) else "q/sourceid_string:"||programId,
              ".json"
            ),
            //div[@class="bbw bbwVideo"]/concat(
              "https://limburg.bbvms.com/p/L1_video/c/",@data-id,".json"
            )
          ),
        $url
      ),
      $title:=$src/(
        //div[@class="media-details"]/h3,
        //div[@class="node-content-wrapper"]/header/normalize-space(h3),
        //h1[@class="title-KX" and not(contains(text(),"live"))],
        parse-json(
          //script/substring-after(.,"var msTag = ")[.],
          {"liberal":true()}
        )/data/(content)()
      )
  return
  if (ends-with($script,"mp4")) then
    {
      "name":$src/concat(
        //meta[@name="publisher"]/@content,
        ": ",
        //form[@name="quick_menu2"]//option[@selected]
      ),
      "date":dateTime(
        date(replace($script,".+?(\d+)/(\d+)/(\d+).+","$1-$2-$3")),
        time("00:00:00Z")
      ),
      "formats":array{
        {
          "id":"pg-1",
          "format":"mp4[h264+aac]",
          "url":x:request({"method":"HEAD","url":$script})/url
        }
      }
    }
  else
    xivid:bbvms(
      extract($script,".+\.")||"json",
      $src//meta[@name="publisher" or @property="og:site_name"]/@content,
      if ($title) then $title else "Livestream"
    )
};

declare function xivid:nhnieuws($url as string) as object()? {
  doc($url)/(
    if (//article) then
      parse-json(
        //script/substring-after(.,"INITIAL_PROPS__ = ")[.]
      )/pageData/{
        "name":let $info:=(blocks)()[type=("video","headerVideo")]/video return
        if ($info/caption) then
          $info/concat(author,": ",caption)
        else
          concat(media//author,": ",title),
        "date":updated * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
        "formats":xivid:m3u8-to-json(.//stream/url)
      }
    else {
      "name":substring-after(//title,"Media - ")||": Livestream",
      "date":substring(
        adjust-dateTime-to-timezone(
          current-dateTime() + duration("PT0.5S"),
          duration("PT0S")
        ),
        1,19
      )||"Z",
      "formats":xivid:m3u8-to-json(
        parse-json(
          //script/substring-after(.,"INIT_DATA__ = ")[.]
        )/videoStream
      )
    }
  )
};

declare function xivid:ofl($url as string) as object()? {
  doc($url)/(
    let $info:=//div[@class="fn-jw-player fn-videoplayer"] return
    if ($info/@data-has-streams) then {
      "name":"Omroep Flevoland: Livestream",
      "date":substring(
        adjust-dateTime-to-timezone(
          current-dateTime() + duration("PT0.5S"),
          duration("PT0S")
        ),
        1,19
      )||"Z",
      "formats":xivid:m3u8-to-json($info/@data-file)
    } else {
      "name":concat(
        "Omroep Flevoland: ",
        if ($info/normalize-space(@data-title)) then
          $info/@data-title
        else
          normalize-space(//h2)
      ),
      "date":xivid:string-to-utc-dateTime(
        //div[@class="card__info t--xsm"]/join(
          if (.//span[@class="d--block--sm"]) then
            extract(
              .//span[@class="d--block--sm"],
              "(\d+ \w+ \d+) \| ([\d:]+)",(1,2)
            )
          else
            span/extract(.,"[\d:-]+",0,"*")
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
  )
};

declare function xivid:dumpert($url as string) as object()? {
  parse-json(
    parse-json(
      doc($url)//script/extract(.,"JSON\.parse\((.+)\)",1)[.]
    )
  )/items/item/item[exists((media)()[mediatype="VIDEO"])]/{
    "name":"Dumpert: "||title,
    "date":adjust-dateTime-to-timezone(dateTime(date),duration("PT0S")),
    "duration":(media)()/duration * duration("PT1S"),
    "formats":array{
      for $x at $i in ("mobile","tablet","720p","original") return {
        "id":"pg-"||$i,
        "format":"mp4[h264+aac]",
        "url":(.//variants)()[version=$x]/uri
      }[url]
    }[exists(.())]
  }
};

declare function xivid:autojunk($url as string) as object()? {
  doc($url)/{
    "name":"Autojunk: "||//meta[@property="og:title"]/@content,
    "date":xivid:string-to-utc-dateTime(
      join(extract(//span[@class="posted"]/text(),"[\d:-]+",0,"*"))
    ),
    "formats":if (//div[@id="playerWrapper"]/script) then
      array{
        let $id:=extract(//meta[@property="og:image"]/@content,"\d{4}/\d{4}/\d+")
        for $x at $i in (".mp4","_hq.mp4","_720p.mp4") ! concat(
          "https://static.autojunk.nl/flv/",$id,.
        )
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
    else
      ()
  }
};

declare function xivid:abhd($url as string) as object()? {
  let $src:=doc($url)//div[@id="playerObject"],
      $info:=$src/script/parse-json(
        replace(
          extract(.,"clipData.assets = (.+\]);",1,"s"),
          " //.+",""
        ),
        {"liberal":true()}
      )
  return {
    "name":"ABHD: "||$src/h1/a,
    "date":dateTime(
      join(
        extract($info(1)/src,"(\d{4})/?(\d{2})(\d{2})",1 to 3),
        "-"
      )||"T00:00:00Z"
    ),
    "formats":array{
      for $x at $i in $info()/src return {
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
};

declare function xivid:autoblog($url as string) as object()? {
  doc($url)//iframe[starts-with(@data-lazy-src,"//autoblog.bbvms.com")]/xivid:bbvms(
    resolve-uri(replace(@data-lazy-src,"html.+","json"),$url),(),()
  )
};

declare function xivid:telegraaf($url as string) as object()? {
  json-doc(
    concat(
      "https://content.tmgvideo.nl/playlist/item=",
      parse-json(
        doc($url)//script/extract(.,"APOLLO_STATE__=(.+);",1)[.]
      )/(.//videoId)[1],
      "/playlist.json"
    )
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
        "resolution":concat(width,"x",height),
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
  $json/map:merge((
    {
      "name":concat(
        "AD: ",
        (shows)()/title,
        " - ",
        (productions)()/title
      )
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
  let $src:=x:request({
        "headers":"Cookie: ndc_consent="||uri-encode(
          serialize-json({"permissions":{"functional":true}})
        ),
        "url":$url
      })/doc,
      $id:=$src//div[@class="article-page__video-wrapper"]/div/substring-after(@id,"video-")
  return
  $src/xivid:bbvms(
    substring-before(
      parse-json(//script/tokenize(.,",")[contains(.,$id)]),
      "html"
    )||"json",
    //meta[@property="og:site_name"]/@content,
    ()
  )
};

declare function xivid:youtube($url as string) as object()? {
  let $json:=request-decode(
    "?"||unparsed-text(
      "https://www.youtube.com/get_video_info?video_id="||extract($url,"\w+$")
    )
  )/params/parse-json(player_response) return
  $json//playerMicroformatRenderer/(
    if (liveBroadcastDetails/isLiveNow) then {
      "name":title/simpleText,
      "date":substring(
        adjust-dateTime-to-timezone(
          current-dateTime() + duration("PT0.5S"),
          duration("PT0S")
        ),
        1,19
      )||"Z",
      "formats":xivid:m3u8-to-json($json/streamingData/hlsManifestUrl)
    } else {
      "name":title/simpleText,
      "date":dateTime(date(uploadDate),time("00:00:00"))||"Z",
      "duration":lengthSeconds * duration("PT1S"),
      "formats":array{
        ($json//captionTracks)()[languageCode=("nl","en")]/{
          "id":"sub-"||position(),
          "format":"ttml",
          "language":languageCode,
          "label":name/simpleText,
          "url":baseUrl
        },
        for $x at $i in $json/streamingData/(formats)()[url]
        order by $x/width
        count $i
        return {
          "id":"pg-"||$i,
          "format":let $mt:=tokenize($x/mimeType,";"),
              $c:=tokenize(
                extract($mt[2],"&quot;(.+)&quot;",1),
                ", "
              ) ! tokenize(.,"\.")[1]
          return
          concat(
            substring-after($mt[1],"/"),
            "[",
            if ($c[1]="avc1") then "h264" else $c[1],
            "+",
            if ($c[2]="mp4a") then "aac" else $c[2],
            "]"
          ),
          "resolution":concat($x/width,"x",$x/height,"@",$x/fps,"fps"),
          "bitrate":concat(round($x/bitrate div 1000),"kbps"),
          "url":$x/url
        },
        {
          "id":"dash-0",
          "format":"mpd[manifest]",
          "url":$json/streamingData/dashManifestUrl
        }[url]
      }
    }
  )
};

declare function xivid:vimeo($url as string) as object()? {
  let $id:=extract($url,"\d+$") return
  parse-json(
    doc("https://player.vimeo.com/video/"||$id)//script/extract(.,"config = (.+?);",1)[.]
  )/{
    "name":video/concat(owner/name,": ",title),
    "date":if (contains($url,"player.vimeo.com")) then
      ()
    else
      parse-json(
        doc($url)//script/extract(.,"clip_page_config = (.+);",1)[.]
      )/adjust-dateTime-to-timezone(
        dateTime(replace(clip/uploaded_on,"\s","T")||"-05:00"),
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
        "resolution":concat(width,"x",height,"@",fps,"fps"),
        "url":url
      },
      xivid:m3u8-to-json((hls//url)[1])()
    }
  }
};

declare function xivid:dailymotion($url as string) as object()? {
  json-doc(replace($url,"video","player/metadata/video"))/{
    "name":"Dailymotion: "||title,
    "date":created_time * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
    "duration":duration * duration("PT1S"),
    "formats":xivid:m3u8-to-json(qualities//url)
  }
};

declare function xivid:mixcloud($url as string) as object()? {
  let $key:=x:cps("IFYOUWANTTHEARTISTSTOGETPAIDDONOTDOWNLOADFROMMIXCLOUD"),
      $decrypt:=function($arg as string) as string {
        string-join(
          x:cps(
            for $x at $i in x:cps(binary-to-string(base64Binary($arg))) return
            xivid:bin-xor($x,$key[($i - 1) mod count($key) + 1])
          )
        )
      },
      $csrf:=x:request(
        {"method":"HEAD","url":$url}
      )/substring-before(substring-after(headers[contains(.,"csrftoken")],"="),";"),
      $us:=tokenize(substring-after($url,"mixcloud.com/"),"/")
  return
  x:request({
    "headers":(
      "Content-Type: application/json",
      "Referer: "||$url,
      "X-CSRFToken: "||$csrf,
      "Cookie: csrftoken="||$csrf
    ),
    "post":serialize-json({
      "query":concat(
        "{cloudcastLookup(lookup:{username:&quot;",
        $us[1],
        "&quot;,slug:&quot;",
        $us[2],
        "&quot;}){name,owner{displayName,url,username},",
        "publishDate,audioLength,streamInfo{hlsUrl,url}}}"
      )
    }),
    "url":"https://www.mixcloud.com/graphql"
  })/json//cloudcastLookup/{
    "name":concat(owner/displayName," - ",name),
    "date":dateTime(publishDate),
    "duration":audioLength * duration("PT1S"),
    "formats":array{
      {
        "id":"pg-1",
        "format":"m4a[aac]",
        "url":$decrypt(streamInfo/url)
      },
      xivid:m3u8-to-json(
        $decrypt(streamInfo/hlsUrl)
      )()
    }
  }
};

declare function xivid:soundcloud($url as string) as object()? {
  let $src:=doc($url),
      $cid:=substring(
        substring-after(
          unparsed-text($src//script[@crossorigin][last()]/@src),
          "client_id:"
        ),
        2,32
      ),
      $json:=parse-json($src//script/extract(.,"(\[\{.+)\)",1)[.])()[last()]/(data)(),
      $fmts:=($json//transcodings)()
  return
  $json/{
    "name":concat(user/(full_name,username)[.][1]," - ",title),
    "date":created_at,
    "duration":round(duration div 1000) * duration("PT1S"),
    "formats":array{
      $fmts[format/protocol="progressive"]/(
        let $url:=json-doc(concat(url,"?client_id=",$cid))/url return {
          "id":"pg-1",
          "format":substring-before(preset,"_"),
          "bitrate":extract($url,"\.(\d+)\.",1)||"kbps",
          "url":$url
        }
      ),
      for $x at $i in $fmts[format/protocol="hls"]
      order by $x/preset descending
      count $i
      let $url:=json-doc(concat($x/url,"?client_id=",$cid))/url
      return {
        "id":"hls-"||$i,
        "format":concat("m3u8[",substring-before($x/preset,"_"),"]"),
        "bitrate":extract($url,"\.(\d+)\.",1)||"kbps",
        "url":$url
      }
    }
  }
};

declare function xivid:facebook($url as string) as object()? {
  x:request({
    "headers":"User-Agent: Mozilla/5.0 Firefox/84.0",
    "url":$url
  })/doc/map:merge((
    parse-json(//script[@type="application/ld+json"])/{
      "name":join(
        reverse(tokenize(name," \| ")),
        ": "
      ),
      "date":adjust-dateTime-to-timezone(
        dateTime(uploadDate),
        duration("PT0S")
      ),
      "duration":duration("P"||duration)
    },
    parse-json(
      replace(
        //script/extract(.,"onPageletArrive\((.+?)\);",1)[contains(.,"videoData")],
        "\\x","\\u00"
      ),
      {"liberal":true()}
    )/(.//videoData)()/{
      "formats":array{
        {
          "id":"sub-1",
          "format":"srt",
          "url":subtitles_src
        }[url],
        (
          (sd_src_no_ratelimit,sd_src)[.][1],
          (hd_src_no_ratelimit,hd_src)[.][1]
        ) ! {
          "id":"pg-"||position(),
          "format":"mp4[h264+aac]",
          "url":.
        },
        xivid:mpd-to-json(parse-xml(dash_manifest))()
      }
    }
  ))
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
  let $src:=doc(
        if (contains($url,"/embed/")) then
          replace($url,"/embed/","/view_video.php?viewkey=")
        else
          $url
      ),
      $info:=parse-json($src//script[@type="application/ld+json"]),
      $fmts:=for $x in $src//div[@id="player"]/tokenize(
        replace(script,"&quot; \+ &quot;|&quot;",""),
        "flashvars.+?;"
      )[contains(.,"var media_")]
      return
      json-doc(
        string-join(
          extract($x,"\*/(\w+)",1,"*") ! substring-before(substring-after($x,.||"="),";")
        )
      )()
  return {
    "name":"Pornhub: "||$info/parse-html(name),
    "date":dateTime($info/uploadDate),
    "duration":duration($info/duration),
    "formats":array{
      {
        "id":"sub-1",
        "format":"srt",
        "url":parse-json(
          extract($src//div[@id="player"]/script,"flashvars.+?(\{.+\})",1)
        )/resolve-uri(closedCaptionsFile,$url)
      }[url],
      for $x at $i in $fmts[format="mp4"] return {
        "id":"pg-"||$i,
        "format":"mp4[h264+aac]",
        "resolution":("426x240","854x480","1280x720","1920x1080")[$i],
        "url":$x/videoUrl
      },
      xivid:m3u8-to-json($fmts[quality instance of array()]/videoUrl)()
    }
  }
};

declare function xivid:xhamster($url as string) as object()? {
  parse-json(
    extract(doc($url)//script[@id="initials-script"],"\{.+\}")
  )/{
    "name":"xHamster: "||videoModel/title,
    "date":videoModel/created * duration("PT1S") + dateTime("1970-01-01T00:00:00Z"),
    "duration":videoModel/duration * duration("PT1S"),
    "formats":xivid:m3u8-to-json(
      xplayerSettings/sources/hls/(url,fallback)[contains(.,"master.m3u8")]
    )
  }
};
