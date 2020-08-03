#!/bin/bash
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
# https://github.com/Reino17/xivid
# door Reino Wijnsma (rwijnsma@xs4all.nl)

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

  dumpert.nl              vimeo.com             pornhub.com
  autojunk.nl             dailymotion.com
  telegraaf.nl            twitch.tv
  ad.nl                   mixcloud.com
  lc.nl                   soundcloud.com
  youtube.com             facebook.com
  youtu.be                twitter.com

Voorbeelden:
  ./xivid.sh https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
  ./xivid.sh -i https://www.rtlxl.nl/programma/rtl-nieuws/bf475894-02ce-3724-9a6f-91de543b8a4c
  ./xivid.sh -f hls-#+sub-1 https://kijk.nl/video/AgvoU4AJTpy
EOF
}

npo() {
  eval "$(xidel -e '
    let $a:=x:request({
          "header":"X-Requested-With: XMLHttpRequest",
          "url":"https://www.npostart.nl/api/token"
        })/json,
        $b:=x:request({
          "post":"_token="||$a/token,
          "url":"https://www.npostart.nl/player/'$1'"
        })/json,
        $c:=json(
          doc($b/embedUrl)//script/extract(.,"var video =(.+);",1)[.]
        ),
        $d:=json(
          concat(
            "https://start-player.npo.nl/video/'$1'",
            "/streams?profile=hls&quality=npo&tokenId=",
            $b/token
          )
        )/stream[not(protection)]/src
    return
    json:={|
      if ($c) then $c/{
        "name":concat(
          franchiseTitle,
          if (contains(franchiseTitle,title)) then () else ": "||title
        ),
        "date":format-date(
          dateTime(broadcastDate),
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
            (duration + startAt) * duration("PT1S"),
            "[H01]:[m01]:[s01]"
          )
        else
          ()
      } else
        doc("https://www.npostart.nl/'$1'")/{
          "name":.//div[@class="npo-header-episode-content"]/concat(
            normalize-space(h1),
            ": ",
            .//h2
          ),
          "date":.//npo-player/extract(@current-url,"(\d+-\d+-\d+)",1),
          "duration":format-time(
            .//@duration * duration("PT1S"),
            "[H01]:[m01]:[s01]"
          )
        },
      {
        "formats":[
          (
            if (not($c/(subtitles)()) and $c/parentId) then
              json(
                doc(
                  x:request({
                    "post":"_token="||$a/token,
                    "url":"https://www.npostart.nl/player/"||$c/parentId
                  })/json/embedUrl
                )//script/extract(.,"var video =(.+);",1)[.]
              )
            else
              $c
          )/(subtitles)()/{
            "id":"sub-1",
            "format":"vtt",
            "language":language,
            "label":label,
            "url":src
          },
          xivid:m3u8-to-json($d)
        ]
      }
    |}
  ' --output-format=bash)"
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

rtl() {
  eval "$(xidel "http://www.rtl.nl/system/s4m/vfd/version=2/uuid=$1/fmt=adaptive/" -e '
    json:=$json[meta/nr_of_videos_total gt 0]/{
      "name":concat(
        .//station,
        ": ",
        abstracts/name,
        " - ",
        if (.//classname="uitzending") then episodes/name else .//title
      ),
      "date":format-date(
        (material)()/original_date * duration("PT1S") +
        (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + date("1970-01-01"),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        time((material)()/duration) + duration("PT0.5S"),
        "[H01]:[m01]:[s01]"
      ),
      "expdate":format-dateTime(
        (.//ddr_timeframes)()[model="AVOD"]/stop * duration("PT1S") +
        (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + dateTime("1970-01-01T00:00:00"),
        "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
      ),
      "formats":xivid:m3u8-to-json(.//videohost||.//videopath)
    }
  ' --output-format=bash)"
}

kijk() {
  eval "$(xidel --xquery '
    json:=try {
      json(
        doc("https://embed.kijk.nl/video/'${1: -11}'")//script/extract(.,"playerConfig = (.+);",1)[.]
      )/(playlist)()/{
        "name":concat(
          upper-case(.//c_media_station),
          ": ",
          normalize-space(title),
          if (description) then
            " - "||description
          else
            ()
        ),
        "date":replace(
          .//c_sko_dt,
          "(\d{4})(\d{2})(\d{2})",
          "$3-$2-$1"
        ),
        "duration":.//c_sko_cl * duration("PT1S") + time("00:00:00"),
        "expdate":format-dateTime(
          .//c_media_dateexpires * duration("PT1S") +
          (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + dateTime("1970-01-01T00:00:00"),
          "[D01]-[M01]-[Y] [H01]:[m01]:[s01]"
        ),
        "formats":[
          (tracks)()[kind="captions"]/{
            "id":"sub-"||position(),
            "format":"vtt",
            "language":"nl",
            "label":label,
            "url":file
          },
          xivid:m3u8-to-json((sources)()[not(drm) and type="m3u8"][1]/file)
        ]
      }
    } catch err:FODC0002 {
      x:request({
        "headers":concat(
          "Cookie: OPTOUTMULTI=0:0%7Cc5:0%7Cc1:0%7Cc4:0%7Cc3:0%7Cc2:0; TN_UUID=",
          random-seed(),
          string-join((1 to 32) ! x:integer-to-base(random(16),16))
        ),
        "url":"'$1'"
      })/json(
        doc//script[@type="application/json"]
      )//pageProps/{
        "name":"Kijk: "||(
          if (patheThuis) then
            video/title
          else
            concat(
              format/title,
              " S",
              video/seasonNumber ! (if (. lt 10) then "0"||. else .),
              "E",
              video/tvSeasonEpisodeNumber ! (if (. lt 10) then "0"||. else .)
            )
        ),
        "date":format-date(
          substring(video//availableDate,1,10) * duration("PT1S") +
          (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + dateTime("1970-01-01T00:00:00"),
          "[D01]-[M01]-[Y]"
        ),
        "duration":video/round(duration) * duration("PT1S") + time("00:00:00"),
        "formats":[
          (.//sourceUrl)[ends-with(.,"vtt")] ! {
            "id":"sub-"||position(),
            "format":"vtt",
            "language":"nl",
            "label":if (contains(.,"OPE")) then
              "Doven en Slechthorenden"
            else
              "Nederlands",
            "url":.
          },
          xivid:m3u8-to-json((.//sourceUrl)[ends-with(.,"m3u8")])
        ]
      }
    }
  ' --output-format=bash)"
}

regio_frl() {
  eval "$(xidel "$1" --xquery '
    let $a:=//meta[@itemprop="embedURL"]/extract(
          @content,
          "defaultMediaAssetPath=(.+?)&amp;.+clipXmlUrl=(.+?)&amp;",
          (1,2)
        ),
        $b:=doc($a[2])
    return
    json:=if ($b//@sourcetype="live") then {
      "name"://meta[@itemprop="name"]/@content||": Livestream",
      "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json($b//asset/@src)
    } else {
      "name":"Omrop Fryslân: "||normalize-space(//h1),
      "date":replace(
        //meta[@itemprop="dateModified"]/@content,
        "(\d+)-(\d+)-(\d+).+",
        "$3-$2-$1"
      ),
      "duration":duration(
        "P"||//meta[@itemprop="duration"]/@content
      ) + time("00:00:00"),
      "formats":[
        for $x at $i in $b//asset
        order by $x/@bandwidth
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":concat($x/@width,"x",$x/@height),
          "bitrate":$x/@bandwidth||"kbps",
          "url":resolve-uri($x/@src,$a[1])
        }
      ]
    }
  ' --output-format=bash)"
}

regio_nh() {
  eval "$(xidel "$1" -e '
    let $a:=json(
      //script/extract(.,"INITIAL_PROPS__ = (.+)",1)[.]
    )/pageData return
    json:={
      "name":if ($a) then
        if ($a/(media)(1)/title) then
          $a/(media)(1)/concat(source,": ",title)
        else
          concat($a/(media)(1)/source,": ",$a/title)
      else
        substring-after(//title,"- ")||": Livestream",
      "date":if ($a) then
        format-date(
          $a/updated * duration("PT1S") +
          (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + date("1970-01-01"),
          "[D01]-[M01]-[Y]"
        )
      else
        format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json(
        if ($a) then
          $a/(media)()/videoUrl
        else
          json(
            //script/extract(.,"INIT_DATA__ = (.+)",1)[.]
          )/videoStream
      )
    }
  ' --output-format=bash)"
}

regio_fll() {
  eval "$(xidel "$1" -e '
    let $a:=//div[ends-with(@class,"videoplayer")] return
    json:=if ($a/@data-page-type="home") then {
      "name":"Omroep Flevoland: Livestream",
      "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json($a/@data-file)
    } else {
      "name":"Omroep Flevoland: "||normalize-space(//h2),
      "date":if ($a/@data-page-type="missed") then
        substring(
          normalize-space(//span[starts-with(@class,"t--red")]),
          4
        )
      else
        xivid:txt-to-date(//span[@class="d--block--sm"]),
      "formats":[
        {
          "id":"pg-1",
          "format":"mp4[h264+aac]",
          "url"://div[ends-with(@class,"videoplayer")]/@data-file
        }
      ]
    }
  ' --output-format=bash)"
}

regio_utr() {
  eval "$(xidel "$1" -e '
    json:=if (//script[@async]) then
      json(
        extract(unparsed-text(//script[@async]/@src),"var opts = (.+);",1)
      )/{
        "name":publicationData/label||": Livestream",
        "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
        "formats":xivid:m3u8-to-json(clipData/(assets)()[mediatype="MP4_HLS"]/src)
      }
    else
      let $a:=json(
        //script/extract(.,"setup\((.+)\)",1,"s")[.]
      )//file return {
        "name":concat(
          //meta[@name="publisher"]/@content,
          ": ",
          (
            substring-before(
              normalize-space(//h3[@class="article-title"]),
              " -"
            )[.],
            normalize-space(//h1[@class="article-title"])
          )[1]
        ),
        "date":replace($a,".+?(\d+)/(\d+)/(\d+).+","$3-$2-$1"),
        "formats":[
          {
            "id":"pg-1",
            "format":"mp4[h264+aac]",
            "url":$a
          }
        ]
      }
  ' --output-format=bash)"
}

regio() {
  eval "$(xidel "$1" --xquery '
    let $a:=doc(
          parse-html(
            //div[starts-with(@class,"inlinemedia")]/@data-accept
          )//@src
        ),
        $b:=x:request({
          "url":(
            (.,$a)//@data-media-url,
            //div[@class="bbwLive-player"]//@src,
            resolve-uri(doc(//iframe/@src)//@src),
            //div[@class="bbw bbwVideo"]/concat(
              "https://l1.bbvms.com/p/video/c/",
              @data-id,
              ".json"
            )
          )
        })/(
          .[json]/json,
          .[doc]/json(
            extract(raw,"var opts = (.+);",1)
          )
        ),
        $c:=$b/clipData/(assets)(1)[ends-with(src,"m3u8")]/(
          if (starts-with(src,"//")) then
            $b/protocol||substring-after(src,"//")
          else
            resolve-uri(src,$b/publicationData/defaultMediaAssetPath)
        )
    return
    json:=if ($c) then {
      "name":$b/publicationData/label||": Livestream",
      "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json($c)
    } else {
      "name":concat(
        $b/publicationData/label,
        ": ",
        normalize-space(
          (
            //div[@class="media-details"]/h3,
            (.,$a)//div[@class="video-title"],
            replace(//div[@class="overlay"]/h1,"(.+) -.+","$1")
          )
        )
      ),
      "date":format-date(
        dateTime($b/clipData/publisheddate),
        "[D01]-[M01]-[Y]"
      ),
      "duration":$b/clipData/(
        (assets)(1)/length,
        length
      )[.][1] * duration("PT1S") + time("00:00:00"),
      "formats":[
        for $x at $i in $b/clipData/(assets)()
        order by $x/bandwidth
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":concat($x/width,"x",$x/height),
          "bitrate":$x/bandwidth||"kbps",
          "url":resolve-uri(
            $x/src,
            $b/protocol||substring-after($b/publicationData/defaultMediaAssetPath,"//")
          )
        }
      ]
    }
  ' --output-format=bash)"
}

dumpert() {
  eval "$(xidel -H "Cookie: nsfw=1;cpc=10" "$1" --xquery '
    json:=json(
      json(
        //script/extract(.,"JSON\.parse\((.+)\)",1)[.]
      )
    )/items/item/item[(media)()[mediatype="VIDEO"]]/(
      if ((.//variants)()/version="embed") then
        replace((.//variants)()/uri,"youtube:","https://youtu.be/")
      else
        {
          "name":"Dumpert: "||title,
          "date":format-date(dateTime(date),"[D01]-[M01]-[Y]"),
          "duration":(media)()/duration * duration("PT1S") + time("00:00:00"),
          "formats":for $x at $i in ("mobile","tablet","720p","original")
          let $a:=(.//variants)()[version=$x]/uri
          return {
            "id":"pg-"||$i,
            "format":"mp4[h264+aac]",
            "url":$a
          }[url]
        }
    )
  ' --output-format=bash)"
  if [[ $json =~ youtu.be ]]; then
    youtube "$json"
  fi
}

autojunk() {
  eval "$(xidel "$1" --xquery '
    let $a:=//div[@id="playerWrapper"]/script[1] return
    json:={
      "name":"Autojunk: "||extract($a,"clipData.title=&quot;(.+)&quot;",1),
      "date":extract(//span[@class="posted"],"([\d-]+)",1),
      "duration":format-time(
        extract($a,"clipData\[&quot;length&quot;\].+?(\d+)",1) * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":[
        for $x at $i in json(
          replace(
            extract($a,"clipData.assets = (.+\]);",1,"s"),
            " //.+",
            ""
          )
        )()[src]
        order by $x/bandwidth
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":concat($x/width,"x",$x/height),
          "bitrate":$x/bandwidth||"kbps",
          "url":$x/src
        }
      ]
    }
  ' --output-format=bash)"
}

telegraaf() {
  eval "$(xidel "$1" -e '
    let $a:=json(
      concat(
        "https://content.tmgvideo.nl/playlist/item=",
        json(
          //script/extract(.,"APOLLO_STATE__=(.+);",1)[.]
        )/(.//videoId)[1],
        "/playlist.json"
      )
    ) return
    json:={
      "name":"Telegraaf: "||$a//title,
      "date":replace(
        $a//datecreated,
        "(\d+)-(\d+)-(\d+).+",
        "$3-$2-$1"
      ),
      "duration":format-time(
        $a//duration * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":[
        $a//locations/reverse((progressive)())/{
          "id":"pg-"||position(),
          "format":"mp4[h264+aac]",
          "resolution":concat(width,"x",height),
          "url":.//src
        },
        xivid:m3u8-to-json(
          $a//locations/(adaptive)()[ends-with(type,"x-mpegURL")]/extract(src,"(.+m3u8)",1)
        )
      ]
    }
  ' --output-format=bash)"
}

ad() {
  eval "$(xidel -H "Cookie: pwv=2;pws=functional" "$1" --xquery '
    json:=json(
      (
        doc(
          (
            extract(
              unparsed-text(//script[@class="mc-embed"]/@src),
              "embed_uri = &apos;(.+)&apos;;",
              1
            ),
            //iframe[@class="mc-embed"]/@src
          )[.]
        ),
        .
      )//script[@data-mc-object-type="production"]
    )/{
      "name":"AD: "||title,
      "date":replace(
        publicationDate,
        "(\d+)-(\d+)-(\d+).+",
        "$3-$2-$1"
      ),
      "duration":format-time(
        duration * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":xivid:m3u8-to-json((sources)()/src)
    }
  ' --output-format=bash)"
}

lc() {
  eval "$(xidel "$1" --xquery '
    json:=json(
      extract(
        unparsed-text(//figure[@class="video"]//@src),
        "var opts = (.+);",
        1
      )
    )/{
      "name":concat("LC: ",clipData/title),
      "date":format-date(
        dateTime(clipData/publisheddate),
        "[D01]-[M01]-[Y]"
      ),
      "duration":clipData/length * duration("PT1S") + time("00:00:00"),
      "formats":[
        for $x at $i in clipData/(assets)()
        order by $x/bandwidth
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":concat($x/width,"x",$x/height),
          "bitrate":$x/bandwidth||"kbps",
          "url":resolve-uri(
            $x/src,
            publicationData/defaultMediaAssetPath
          )
        }
      ]
    }
  ' --output-format=bash)"
}

youtube() {
  eval "$(xidel "$1" --xquery '
    let $a:=if (//meta[@property="og:restrictions:age"]) then
          {|
            for $x in tokenize(
              unparsed-text(
                concat(
                  "https://www.youtube.com/get_video_info?video_id=",
                  //meta[@itemprop="videoId"]/@content,
                  "&amp;eurl=",
                  uri-encode("https://youtube.googleapis.com/v/"||//meta[@itemprop="videoId"]/@content),
                  "&amp;sts=",
                  json(
                    doc(
                      "https://www.youtube.com/embed/"||//meta[@itemprop="videoId"]/@content
                    )//script/extract(.,"setConfig\((.+?)\)",1,"*")[3]
                  )//sts
                )
              ),
              "&amp;"
            )
            let $a:=tokenize($x,"=") return {$a[1]:uri-decode($a[2])}
          |}
        else
          json(
            //script/extract(.,"ytplayer.config = (.+?\});",1)[.]
          )/args,
        $b:=$a/json(player_response),
        $c:=for $x at $i in tokenize($a/url_encoded_fmt_stream_map,",") return {|
          let $a:=extract(
            tokenize($a/fmt_list,",")[$i],
            "/(\d+)x(\d+)",
            (1,2)
          ) return ({"width":$a[1]},{"height":$a[2]}),
          for $y in tokenize($x,"&amp;")
          let $a:=tokenize($y,"=")
          return
          {if ($a[1]="type") then "mimeType" else $a[1]:uri-decode($a[2])}
        |},
        $d:=tokenize($a/adaptive_fmts,",") ! {|
          for $x in tokenize(.,"&amp;")
          let $a:=tokenize($x,"=")
          return
          if ($a[1]="size") then
            let $a:=tokenize($a[2],"x") return ({"width":$a[1]},{"height":$a[2]})
          else {
            if ($a[1]="type") then
              "mimeType"
            else if ($a[1]="audio_sample_rate") then
              "audioSampleRate"
            else
              $a[1]:uri-decode($a[2])
          }
        |}
    return
    json:=if ($b/videoDetails/isLive) then {
      "name"://meta[@property="og:title"]/@content,
      "date":format-date(current-date(),"[D01]-[M01]-[Y]"),
      "formats":xivid:m3u8-to-json($b/streamingData/hlsManifestUrl)
    } else {
      "name"://meta[@property="og:title"]/@content,
      "date":format-date(
        date(//meta[@itemprop="datePublished"]/@content),
        "[D01]-[M01]-[Y]"
      ),
      "duration":duration(//meta[@itemprop="duration"]/@content) + time("00:00:00"),
      "formats":[
        ($b//captionTracks)()[languageCode="nl"]/{
          "id":"sub-1",
          "format":"ttml",
          "language":"nl",
          "label":name/simpleText,
          "url":baseUrl
        },
        for $x at $i in if ($b/streamingData/formats) then $b/streamingData/(formats)()[url] else reverse($c[not(s)])
        order by $x/width
        count $i
        return {
          "id":"pg-"||$i,
          "format":let $a:=extract(
            $x/mimeType,
            "/(.+);.+&quot;(\w+)\..+ (\w+)(?:\.|&quot;)",
            (1 to 3)
          ) return
          concat(
            if ($a[1]="3gpp") then "3gp" else $a[1],
            "[",
            if ($a[2]="avc1") then "h264" else $a[2],
            "+",
            if ($a[3]="mp4a") then "aac" else $a[3],
            "]"
          ),
          "resolution":concat($x/width,"x",$x/height),
          "bitrate":$x[itag ne 43]/bitrate ! concat(round(. div 1000),"kbps"),
          "url":$x/url
        },
        for $x at $i in if ($b/streamingData/adaptiveFormats) then $b/streamingData/(adaptiveFormats)()[url] else $d[not(s)]
        order by $x/boolean(width),$x/bitrate
        count $i
        return {
          "id":"dash-"||$i,
          "format":let $a:=extract(
            $x/mimeType,
            "/(.+);.+&quot;(\w+)",
            (1,2)
          ) return
          concat(
            $a[1],
            "[",
            if ($a[2]="avc1") then "h264" else if ($a[2]="mp4a") then "aac" else $a[2],
            "]"
          ),
          "resolution":$x/width ! concat(.,"x",$x/height,"@",$x/fps,"fps"),
          "samplerate":$x/audioSampleRate ! concat(. div 1000,"kHz"),
          "bitrate":round($x/bitrate div 1000)||"kbps",
          "url":$x/url
        }
      ]
    }
  ' --output-format=bash)"
}

vimeo() {
  eval "$(xidel "$1" --xquery '
    json:=json(
      //script/extract(.,"clip_page_config = (.+);",1)[.]
    )/{
      "name":clip/title,
      "date":replace(
        clip/uploaded_on,
        "(\d+)-(\d+)-(\d+).+",
        "$3-$2-$1"
      ),
      "duration":clip/duration/raw * duration("PT1S") + time("00:00:00"),
      "formats":player/json(config_url)//files/(
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
        xivid:m3u8-to-json((hls//url)[1])
      )
    }
  ' --output-format=bash)"
}

dailymotion() {
  eval "$(xidel "https://www.dailymotion.com/player/metadata/video/$1" -e '
    json:=$json/{
      "name":"Dailymotion: "||title,
      "date":format-date(
        created_time * duration("PT1S") +
        (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + date("1970-01-01"),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        duration * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":xivid:m3u8-to-json(qualities//url)
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

mixcloud() {
  eval "$(xidel "$1" -e '
    declare variable $decryption_key:="IFYOUWANTTHEARTISTSTOGETPAIDDONOTDOWNLOADFROMMIXCLOUD";
    declare function local:decrypt($a as base64Binary) as string {
      let $url:=x:cps(binary-to-string($a)),
          $key:=x:cps(
            substring(
              string-join((1 to ceiling(count($url) div string-length($decryption_key))) ! $decryption_key),
              1,count($url)
            )
          )
      return
      string-join(
        x:cps(
          for $x at $i in $url return
          xivid:bin-xor($x,$key[$i])
        )
      )
    };
    let $csrf:=substring-before(substring-after($headers[contains(.,"csrftoken")],"="),";"),
        $us:=tokenize(substring-after("'$url'","mixcloud.com/"),"/")
    return
    json:=x:request(
      {
        "headers":(
          "Content-Type: application/json",
          "Referer: '$1'",
          "X-CSRFToken: "||$csrf,
          "Cookie: csrftoken="||$csrf
        ),
        "post":concat(
          "{""query"":""{cloudcastLookup(lookup:{username:\""",
          $us[1],
          "\"",slug:\""",
          $us[2],
          "\""}){name,owner{displayName,url,username},publishDate,audioLength,streamInfo{hlsUrl,url}}}""}"
        ),
        "url":"https://www.mixcloud.com/graphql"
      }
    )/json//cloudcastLookup/{
      "name":concat(owner/displayName," - ",name),
      "date":format-date(dateTime(publishDate),"[D01]-[M01]-[Y]"),
      "duration":format-time(
        audioLength * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":[
        {
          "id":"pg-1",
          "format":"m4a[aac]",
          "url":local:decrypt(base64Binary(streamInfo/url))
        },
        xivid:m3u8-to-json(
          local:decrypt(
            base64Binary(streamInfo/hlsUrl)
          )
        )
      ]
    }
  ' --output-format=bash)"
}

soundcloud() {
  eval "$(xidel "$1" --xquery '
    let $cid:=substring(
          substring-after(
            unparsed-text(//script[@crossorigin][last()]/@src),
            "client_id:"
          ),
          2,32
        ),
        $a:=json(//script/extract(.,"(\[\{.+)\)",1)[.])()[.//media]/(data)(),
        $b:=($a//transcodings)()
    return
    json:=$a/{
      "name":concat(user/(full_name,username)[.][1]," - ",title),
      "date":format-date(dateTime(created_at),"[D01]-[M01]-[Y]"),
      "duration":format-time(
        round(duration div 1000) * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":[
        $b[format/protocol="progressive"]/(
          let $url:=json(concat(url,"?client_id=",$cid))/url return {
            "id":"pg-1",
            "format":substring-before(preset,"_"),
            "bitrate":extract($url,"\.(\d+)\.",1)||"kbps",
            "url":$url
          }
        ),
        for $x at $i in $b
        where $x/format/protocol="hls"
        order by $x/preset descending
        count $i
        let $url:=json(concat($x/url,"?client_id=",$cid))/url
        return {
          "id":"hls-"||$i,
          "format":concat("m3u8[",substring-before($x/preset,"_"),"]"),
          "bitrate":extract($url,"\.(\d+)\.",1)||"kbps",
          "url":$url
        }
      ]
    }
  ' --output-format=bash)"
}

facebook() {
  eval "$(xidel --user-agent="$XIDEL_UA" "$1" --xquery '
    let $a:=(//script/substring-before(substring-after(.,"onPageletArrive("),");}));")[.])[2] ! json(
      replace(.,"\\\x","\\\u00")
    )/(.//videoData)() return
    json:={
      "name":replace(//title,"(.+) \| (.+)","$2: $1"),
      "date":format-date(
        //code/comment() ! parse-html(.)//@data-utime * duration("PT1S") +
        (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + date("1970-01-01"),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        duration($a/parse-xml(dash_manifest)//@mediaPresentationDuration) + duration("PT0.5S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":[
        {
          "id":"sub-1",
          "format":"srt",
          "url":$a/subtitles_src
        }[url],
        $a/(
          (sd_src_no_ratelimit,sd_src)[.][1],
          (hd_src_no_ratelimit,hd_src)[.][1]
        ) ! {
          "id":"pg-"||position(),
          "format":"mp4[h264+aac]",
          "url":uri-decode(.)
        },
        for $x at $i in $a/parse-xml(dash_manifest)//Representation
        order by $x/boolean(@width),$x/@bandwidth
        count $i
        return {
          "id":"dash-"||$i,
          "format":concat(
            substring-after($x/@mimeType,"/"),
            "[",
            extract($x/@codecs,"(^[\w]+)",1) ! (
              if (.="avc1") then "h264" else if (.="mp4a") then "aac" else .
            ),
            "]"
          ),
          "resolution":$x/@width ! concat(.,"x",$x/@height),
          "samplerate":$x/@audioSamplingRate ! concat(. div 1000,"kHz"),
          "bitrate":round($x/@bandwidth div 1000)||"kbps",
          "url":$x/uri-decode(BaseUrl)
        }
      ]
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
        (time("00:00:00") - time("00:00:00'$(date +%:z)'")) + date("1970-01-01"),
        "[D01]-[M01]-[Y]"
      ),
      "duration":format-time(
        round(($b//durationMs,$b//end_ms - $b//start_ms) div 1000) * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":if ($b/broadcasts) then
        [{
          "id":"hls-1",
          "format":"m3u8[h264+aac]",
          "resolution":concat($b//width,"x",$b//height),
          "url":x:request({
            "headers":($head,"x-guest-token: "||$a),
            "url":"https://api.twitter.com/1.1/live_video_stream/status/"||$b//media_key
          })//location
        }]
      else
        xivid:m3u8-to-json($b//playbackUrl)
    }
  ' --output-format=bash)"
}

pornhub() {
  eval "$(xidel "$1" --xquery '
    let $a:=json(//script/extract(.,"flashvars_\d+ = (.+);",1)[.]) return
    json:={
      "name":"Pornhub: "||$a/video_title,
      "date":replace(
        $a/image_url,
        ".+?(\d{4})(\d{2})/(\d{2}).+",
        "$3-$2-$1"
      ),
      "duration":format-time(
        $a/video_duration * duration("PT1S"),
        "[H01]:[m01]:[s01]"
      ),
      "formats":[
        for $x in //script/extract(.,"(var ra.+?quality.+?)flashvars",1,"*") !
        replace(.,"&quot; \+ &quot;|&quot;","")
        group by $q:=extract($x,"quality_(\d+)p=",1)
        count $i
        return {
          "id":"pg-"||$i,
          "format":"mp4[h264+aac]",
          "resolution":("426x240","854x480","1280x720","1920x1080")[$i],
          "url":string-join(
            extract($x,"\*/(\w+)",1,"*") ! substring-before(substring-after($x,.||"="),";")
          )
        }
      ]
    }
  ' --output-format=bash)"
}

if command -v xidel >/dev/null; then
  ver=$(xidel --version | xidel - -se 'substring-before(substring-after($raw,"("),".")')
  if [[ $ver -ge 20180421 ]]; then
    if [[ $ver -ge 20200201 ]]; then
      export XIDEL_OPTIONS="--silent --module=xivid.xqm --json-mode=deprecated"
    else
      export XIDEL_OPTIONS="--silent --module=xivid.xqm"
    fi
    XIDEL_UA="Mozilla/5.0 Firefox/70.0"
  else
    cat 1>&2 <<EOF
xivid: '$(command -v xidel)' gevonden, maar versie is te oud.
Installeer Xidel 0.9.8 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
Ga naar http://videlibri.sourceforge.net/xidel.html.
EOF
    exit 1
  fi
else
  cat 1>&2 <<EOF
xivid: 'xidel' niet gevonden!
Installeer Xidel 0.9.8 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
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
  npo "$(xidel -e 'extract("'$url'",".+/([\w_]+)",1)')"
elif [[ $url =~ nos.nl ]]; then
  nos "$url"
elif [[ $url =~ (tvblik.nl|uitzendinggemist.net) ]]; then
  eval "$(xidel "$url" -e '
    join(
      extract(
        (
          //div[@id="embed-player"]/(@data-episode,.//@href),
          //a[@rel="nofollow"]/@onclick,
          //iframe[@class="sbsEmbed"]/@src
        ),
        "(npo|rtl|kijk).+(?:/|video=)([\w-]+)",
        (1,2)
      )
    )
  ')"
elif [[ $url =~ rtlxl.nl ]]; then
  rtl "$(xidel -e 'extract("'$url'",".+/(.+)",1)')"
elif [[ $url =~ rtlnieuws.nl ]]; then
  rtl "$(xidel "$url" -e '//@data-uuid')"
elif [[ $url =~ kijk.nl ]]; then
  kijk "$url"
elif [[ $url =~ omropfryslan.nl ]]; then
  regio_frl "$url"
elif [[ $url =~ (nhnieuws.nl|at5.nl) ]]; then
  regio_nh "$url"
elif [[ $url =~ omroepflevoland.nl ]]; then
  regio_fll "$url"
elif [[ $url =~ rtvutrecht.nl ]]; then
  regio_utr "$url"
elif [[ $url =~ (rtvnoord.nl|rtvdrenthe.nl|rtvoost.nl|omroepgelderland.nl|omroepwest.nl|rijnmond.nl|omroepzeeland.nl|omroepbrabant.nl|l1.nl) ]]; then
  regio "$url"
elif [[ $url =~ dumpert.nl ]]; then
  dumpert "$url"
elif [[ $url =~ autojunk.nl ]]; then
  autojunk "$url"
elif [[ $url =~ telegraaf.nl ]]; then
  telegraaf "$url"
elif [[ $url =~ ad.nl ]]; then
  ad "$url"
elif [[ $url =~ lc.nl ]]; then
  lc "$url"
elif [[ $url =~ (youtube.com|youtu.be) ]]; then
  youtube "$url"
elif [[ $url =~ vimeo.com ]]; then
  vimeo "$url"
elif [[ $url =~ dailymotion.com ]]; then
  dailymotion "$(xidel -e 'extract("'$url'",".+/(.+)",1)')"
elif [[ $url =~ twitch.tv ]]; then
  twitch "$url"
elif [[ $url =~ mixcloud.com ]]; then
  mixcloud "$url"
elif [[ $url =~ soundcloud.com ]]; then
  soundcloud "$url"
elif [[ $url =~ facebook.com ]]; then
  facebook "$url"
elif [[ $url =~ twitter.com ]]; then
  twitter "$url"
elif [[ $url =~ pornhub.com ]]; then
  pornhub "$url"
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
