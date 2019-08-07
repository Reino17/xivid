@GOTO :start
::
:: Copyright (C) 2019 Reino Wijnsma
::
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.
::
:: This program is distributed in the hope that it will be useful,
:: but WITHOUT ANY WARRANTY; without even the implied warranty of
:: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
:: GNU General Public License for more details.
::
:: You should have received a copy of the GNU General Public License
:: along with this program.  If not, see <http://www.gnu.org/licenses/>.
::
:: https://github.com/Reino17/bashgemist
:: door Reino Wijnsma (rwijnsma@xs4all.nl)

:help
ECHO Xivid, een video-url extractie script.
ECHO Gebruik: xivid.bat [optie] url
ECHO.
ECHO   -f FORMAAT    Forceer specifiek formaat. Zonder opgave wordt het
ECHO                 best beschikbare formaat gekozen.
ECHO   -i            Toon video informatie, incl. een opsomming van alle
ECHO                 beschikbare formaten.
ECHO   -j            Toon video informatie als JSON.
ECHO.
ECHO Ondersteunde websites:
ECHO   npostart.nl             omropfryslan.nl       omroepwest.nl
ECHO   gemi.st                 rtvnoord.nl           rijnmond.nl
ECHO   nos.nl                  rtvdrenthe.nl         rtvutrecht.nl
ECHO   tvblik.nl               nhnieuws.nl           omroepgelderland.nl
ECHO   uitzendinggemist.net    at5.nl                omroepzeeland.nl
ECHO   rtl.nl                  omroepflevoland.nl    omroepbrabant.nl
ECHO   kijk.nl                 rtvoost.nl            l1.nl
ECHO.
ECHO   dumpert.nl
ECHO   telegraaf.nl
ECHO   youtube.com
ECHO   youtu.be
ECHO   vimeo.com
ECHO.
ECHO Voorbeelden:
ECHO   xivid.bat https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
ECHO   xivid.bat -i https://www.rtl.nl/video/26862f08-13c0-31d2-9789-49a3b286552d
ECHO   xivid.bat -f hls-6 https://www.kijk.nl/video/jCimXJk75RP
EXIT /B

:npo
FOR /F "delims=" %%A IN ('xidel -e ^"
  let $a:^=x:request^({
        'header':'X-Requested-With: XMLHttpRequest'^,
        'url':'https://www.npostart.nl/api/token'
      }^)/json/x:request^({
        'post':'_token^='^|^|token^,
        'url':'https://www.npostart.nl/player/%~1'
      }^)/json^,
      $b:^=json^(
        doc^($a/embedUrl^)//script/extract^(.^,'var video ^=^(.+^)^;'^,1^)[.]
      ^)^,
      $c:^=json^(
        concat^(
          'https://start-player.npo.nl/video/%~1'^,
          '/streams?profile^=hls^&amp^;quality^=npo^&amp^;tokenId^='^,
          $a/token
        ^)
      ^)/stream[not^(protection^)]/src
  return json:^={
    'name':$b/concat^(
      franchiseTitle^,
      if ^(contains^(franchiseTitle^,title^)^) then ^(^) else ': '^|^|title
    ^)^,
    'date':format-date^(
      dateTime^($b/broadcastDate^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':format-time^(
      $b/duration * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'start':format-time^(
      $b[startAt]/startAt * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'end':format-time^(
      $b[startAt]/^(duration + startAt^) * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'subtitle':{
      'type':'webvtt'^,
      'url':if ^($b/parentId^) then
        x:request^({
          'url':concat^(
            'https://rs.poms.omroep.nl/v1/api/subtitles/'^,
            $b/parentId^,
            '/nl_NL/CAPTION.vtt'
          ^)
        }^)[contains^(headers[1]^,'200'^)]/url
      else
        $b/^(subtitles^)^(^)/src
    }[url]^,
    'formats':xivid:m3u8-to-json^($c^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:nos
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  json:^={
    'name':concat^(
      'NOS: '^,
      //h1[ends-with^(@class^,'__title'^)]^,
      if ^(//video/@data-type^='livestream'^) then ' Livestream' else ^(^)
    ^)^,
    'date':if ^(//video/@data-type^='livestream'^) then
      format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)
    else
      replace^(//@datetime^,'^(\d+^)-^(\d+^)-^(\d+^).+'^,'$3-$2-$1'^)^,
    'formats':xivid:m3u8-to-json^(//video/^(.//@src^,@data-stream^)^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:rtl
CALL :timezone
FOR /F "delims=" %%A IN ('xidel "http://www.rtl.nl/system/s4m/vfd/version=2/uuid=%~1/fmt=adaptive/" -e ^"
  json:^=$json[meta/nr_of_videos_total ^> 0]/{
    'name':concat^(
      .//station^,
      ': '^,
      abstracts/name^,
      ' - '^,
      if ^(.//classname^='uitzending'^) then episodes/name else .//title
    ^)^,
    'date':format-date^(
      ^(material^)^(^)/original_date * duration^('PT1S'^) + duration^('%tz%'^) + date^('1970-01-01'^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':format-time^(
      time^(^(material^)^(^)/duration^) + duration^('PT0.5S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'expdate':format-dateTime^(
      ^(.//ddr_timeframes^)^(^)[model^='AVOD']/stop * duration^('PT1S'^) + duration^('%tz%'^) + dateTime^('1970-01-01T00:00:00'^)^,
      '[D01]-[M01]-[Y] [H01]:[m01]:[s01]'
    ^)^,
    'formats':xivid:m3u8-to-json^(.//videohost^|^|.//videopath^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:kijk
CALL :timezone
FOR /F "delims=" %%A IN ('xidel "https://embed.kijk.nl/video/%~1" -e ^"
  json:^=if ^(//video^) then
    x:request^({
      'headers':'Accept: application/json^;pk^='^|^|extract^(
        unparsed-text^(//script[contains^(@src^,//@data-account^)]/@src^)^,
        'policyKey:^&quot^;^(.+?^)^&quot^;'^,
        1
      ^)^,
      'url':concat^(
        'https://edge.api.brightcove.com/playback/v1/accounts/'^,
        //@data-account^,
        '/videos/'^,
        //@data-video-id
      ^)
    }^)/json/{
      'name':concat^(
        upper-case^(custom_fields/sbs_station^)^,
        ': '^,
        name^,
        if ^(custom_fields/sbs_episode^) then ' '^|^|custom_fields/sbs_episode else ^(^)
      ^)^,
      'date':replace^(custom_fields/sko_dt^,'^(\d{4}^)^(\d{2}^)^(\d{2}^)'^,'$3-$2-$1'^)^,
      'duration':round^(duration div 1000^) * duration^('PT1S'^) + time^('00:00:00'^)^,
      'expdate':replace^(
        json^('http://api.kijk.nl/v1/default/entitlement/%~1'^)//enddate/date^,
        '^(\d+^)-^(\d+^)-^(\d+^) ^([\d:]+^).*'^,
        '$3-$2-$1 $4'
      ^)^,
      'formats':[
        for $x at $i in ^(sources^)^(^)[stream_name]
        order by $x/size
        count $i
        return
        $x/{
          'format':'pg-'^|^|$i^,
          'container':'mp4[h264+aac]'^,
          'resolution':concat^(width^,'x'^,height^)^,
          'bitrate':round^(avg_bitrate div 1000^)^|^|'kbps'^,
          'url':replace^(stream_name^,'mp4:'^,extract^($a^,'^(.+?nl/^)'^,1^)^)
        }^,
        xivid:m3u8-to-json^(^(sources^)^(^)[size ^= 0]/src^)
      ]
    }
  else
    json^(
      //script/extract^(.^,'playerConfig ^= ^(.+^)^;'^,1^)[.]
    ^)/^(playlist^)^(^)/{
      'name':TAQ/concat^(
        upper-case^(customLayer/c_media_station^)^,
        ': '^,
        customLayer/c_media_ispartof^,
        if ^(dataLayer/media_program_season !^= 0 and dataLayer/media_program_episodenumber ^<^= 99^) then
          concat^(
            ' S'^,
            dataLayer/media_program_season ! ^(if ^(. ^< 10^) then '0'^|^|. else .^)^,
            'E'^,
            dataLayer/media_program_episodenumber ! ^(if ^(. ^< 10^) then '0'^|^|. else .^)
          ^)
        else
          ^(^)
      ^)^,
      'date':replace^(TAQ/customLayer/c_sko_dt^,'^(\d{4}^)^(\d{2}^)^(\d{2}^)'^,'$3-$2-$1'^)^,
      'duration':TAQ/customLayer/c_sko_cl * duration^('PT1S'^) + time^('00:00:00'^)^,
      'expdate':format-dateTime^(
        TAQ/customLayer/c_media_dateexpires * duration^('PT1S'^) + duration^('%tz%'^) + dateTime^('1970-01-01T00:00:00'^)^,
        '[D01]-[M01]-[Y] [H01]:[m01]:[s01]'
      ^)^,
      'subtitle':{
        'type':'webvtt'^,
        'url':^(tracks^)^(^)[label^=' Nederlands']/file
      }[url]^,
      'formats':xivid:m3u8-to-json^(^(sources^)^(^)[not^(drm^) and type^='m3u8'][1]/file^)
    }
^" --output-format^=cmd') DO %%A
EXIT /B

:tvblik
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  'CALL :'^|^|join^(
    extract^(
      ^(
        //div[@id^='embed-player']/^(@data-episode^,.//@href^)^,
        //a[@rel^='nofollow']/@onclick^,
        //iframe[@class^='sbsEmbed']/@src
      ^)^,
      '^(npo^|rtl^|kijk^).+^(?:/^|video^=^)^([\w-]+^)'^,
      ^(1^,2^)
    ^)
  ^)
^"') DO %%A
EXIT /B

:regio_frl
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  let $a:^=//meta[@itemprop^='embedURL']/extract^(
        @content^,
        'defaultMediaAssetPath^=^(.+?^)^&amp^;.+clipXmlUrl^=^(.+?^)^&amp^;'^,
        ^(1^,2^)
      ^)^,
      $b:^=doc^($a[2]^)
  return
  json:^=if ^($b//@sourcetype^='live'^) then {
    'name'://meta[@itemprop^='name']/@content^|^|': Livestream'^,
    'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
    'formats':xivid:m3u8-to-json^($b//asset/@src^)
  } else {
    'name':'Omrop Fryslân: '^|^|normalize-space^(//h1^)^,
    'date':replace^(
      //meta[@itemprop^='dateModified']/@content^,
      '^(\d+^)-^(\d+^)-^(\d+^).+'^,
      '$3-$2-$1'
    ^)^,
    'duration':duration^(
      'P'^|^|//meta[@itemprop^='duration']/@content
    ^) + time^('00:00:00'^)^,
    'formats':^(
      for $x at $i in $b//asset
      order by $x/@bandwidth
      count $i
      return {
        'format':'pg-'^|^|$i^,
        'container':'mp4[h264+aac]'^,
        'resolution':concat^($x/@width^,'x'^,$x/@height^)^,
        'bitrate':$x/@bandwidth^|^|'kbps'^,
        'url':resolve-uri^($x/@src^,$a[1]^)
      }
    ^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:regio_nh
CALL :timezone
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  let $a:^=json^(
    //script/extract^(.^,'INITIAL_PROPS__ ^= ^(.+^)'^,1^)[.]
  ^)/pageData
  return json:^={
    'name':if ^($a^) then
      if ^($a/^(media^)^(1^)/title^) then
        $a/^(media^)^(1^)/concat^(source^,': '^,title^)
      else
        concat^($a/^(media^)^(1^)/source^,': '^,$a/title^)
    else
      substring-after^(//title^,'- '^)^|^|': Livestream'^,
    'date':if ^($a^) then
      format-date^(
        $a/updated * duration^('PT1S'^) + duration^('%tz%'^) + date^('1970-01-01'^)^,
        '[D01]-[M01]-[Y]'
      ^)
    else
      format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
    'formats':xivid:m3u8-to-json^(
      if ^($a^) then
        $a/^(media^)^(^)/videoUrl
      else
        json^(
          //script/extract^(.^,'INIT_DATA__ ^= ^(.+^)'^,1^)[.]
        ^)/videoStream
    ^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:regio_fll
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  let $a:^=//div[ends-with^(@class^,'videoplayer'^)] return
  json:^=if ^($a/@data-page-type^='home'^) then {
    'name':'Omroep Flevoland: Livestream'^,
    'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
    'formats':xivid:m3u8-to-json^($a/@data-file^)
  } else {
    'name':'Omroep Flevoland: '^|^|normalize-space^(//h2^)^,
    'date':if ^($a/@data-page-type^='missed'^) then
      substring^(
        normalize-space^(//span[starts-with^(@class^,'t--red'^)]^)^,
        4
      ^)
    else
      xivid:txt-to-date^(//span[@class^='d--block--sm']^)^,
    'formats':[
      {
        'format':'pg-1'^,
        'container':'mp4[h264+aac]'^,
        'url'://div[ends-with^(@class^,'videoplayer'^)]/@data-file
      }
    ]
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:regio_utr
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  json:^=if ^(//script[@async]^) then
    json^(
      extract^(unparsed-text^(//script[@async]/@src^)^,'var opts ^= ^(.+^)^;'^,1^)
    ^)/{
      'name':publicationData/label^|^|': Livestream'^,
      'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
      'formats':xivid:m3u8-to-json^(clipData/^(assets^)^(^)[mediatype^='MP4_HLS']/src^)
    }
  else
    let $a:^=json^(
      //script/extract^(.^,'setup\^(^(.+^)\^)'^,1^,'s'^)[.]
    ^)//file return {
      'name':concat^(
        //meta[@name^='publisher']/@content^,
        ': '^,
        ^(
          substring-before^(
            normalize-space^(//h3[@class^='article-title']^)^,
            ' -'
          ^)[.]^,
          normalize-space^(//h1[@class^='article-title']^)
        ^)[1]
      ^)^,
      'date':replace^($a^,'.+?^(\d+^)/^(\d+^)/^(\d+^).+'^,'$3-$2-$1'^)^,
      'formats':[
        {
          'format':'pg-1'^,
          'container':'mp4[h264+aac]'^,
          'url':$a
        }
      ]
    }
^" --output-format^=cmd') DO %%A
EXIT /B

:regio
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  let $a:^=doc^(
        parse-html^(
          //div[starts-with^(@class^,'inlinemedia'^)]/@data-accept
        ^)//@src
      ^)^,
      $b:^=x:request^({
        'url':^(
          ^(.^,$a^)//@data-media-url^,
          //div[@class^='bbwLive-player']//@src^,
          resolve-uri^(doc^(//iframe/@src^)//@src^)^,
          //div[@class^='bbw bbwVideo']/concat^(
            'https://l1.bbvms.com/p/video/c/'^,
            @data-id^,
            '.json'
          ^)
        ^)
      }^)/^(
        .[json]/json^,
        .[doc]/json^(
          extract^(raw^,'var opts ^= ^(.+^)^;'^,1^)
        ^)
      ^)^,
      $c:^=$b/clipData/^(assets^)^(1^)[ends-with^(src^,'m3u8'^)]/^(
        if ^(starts-with^(src^,'//'^)^) then
          $b/protocol^|^|substring-after^(src^,'//'^)
        else
          resolve-uri^(src^,$b/publicationData/defaultMediaAssetPath^)
      ^)
  return
  json:^=if ^($c^) then {
    'name':$b/publicationData/label^|^|': Livestream'^,
    'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
    'formats':xivid:m3u8-to-json^($c^)
  } else {
    'name':concat^(
      $b/publicationData/label^,
      ': '^,
      normalize-space^(
        ^(
          //div[@class^='media-details']/h3^,
          ^(.^,$a^)//div[@class^='video-title']^,
          replace^(//div[@class^='overlay']/h1^,'^(.+^) -.+'^,'$1'^)
        ^)
      ^)
    ^)^,
    'date':format-date^(
      dateTime^($b/clipData/publisheddate^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':$b/clipData/^(
      ^(assets^)^(1^)/length^,
      length
    ^)[.][1] * duration^('PT1S'^) + time^('00:00:00'^)^,
    'formats':[
      for $x at $i in $b/clipData/^(assets^)^(^)
      order by $x/bandwidth
      count $i
      return {
        'format':'pg-'^|^|$i^,
        'container':'mp4[h264+aac]'^,
        'resolution':concat^($x/width^,'x'^,$x/height^)^,
        'bitrate':$x/bandwidth^|^|'kbps'^,
        'url':resolve-uri^(
          $x/src^,
          $b/protocol^|^|substring-after^($b/publicationData/defaultMediaAssetPath^,'//'^)
        ^)
      }
    ]
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:dumpert
FOR /F "delims=" %%A IN ('xidel -H "Cookie: nsfw=1;cpc=10" "%~1" --xquery ^"
  json:^=^(
    if ^(//body[@id^='embed']^) then doc^(//meta[@property^='og:url']/@content^) else .
  ^)/^(
    if ^(//iframe^) then
      replace^(//iframe/@src^,'.+/^(.+^)\?.+'^,'https://youtu.be/$1'^)
    else {
      'name':'Dumpert: '^|^|//div[@class^='dump-desc']/normalize-space^(h1^)^,
      'date':xivid:txt-to-date^(//p[@class^='dump-pub']^)^,
      'formats':let $a:^=json^(
        binary-to-string^(base64Binary^(//@data-files^)^)
      ^)
      for $x at $i in ^('flv'^,'mobile'^,'tablet'^,'720p'^) ! $a^(.^)
      return {
        'format':'pg-'^|^|$i^,
        'container':extract^($x^,'.+\.^(.+^)'^,1^)^|^|'[h264+aac]'^,
        'url':$x
      }
    }
  ^)
^" --output-format^=cmd') DO %%A
SETLOCAL ENABLEDELAYEDEXPANSION
IF NOT "!json:youtu.be=!"=="!json!" (
  ENDLOCAL
  CALL :youtube %json%
)
ENDLOCAL
EXIT /B

:telegraaf
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  let $a:^=json^(
    concat^(
      'https://content.tmgvideo.nl/playlist/item^='^,
      json^(
        //script/extract^(.^,'APOLLO_STATE__^=^(.+^)^;'^,1^)[.]
      ^)/^(.//videoId^)[1]^,
      '/playlist.json'
    ^)
  ^) return json:^={
    'name':'Telegraaf: '^|^|$a//title^,
    'date':replace^(
      $a//datecreated^,
      '^(\d+^)-^(\d+^)-^(\d+^).+'^,
      '$3-$2-$1'
    ^)^,
    'duration':format-time^(
      $a//duration * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':(
      $a//locations/reverse^(^(progressive^)^(^)^)/{
        'format':'pg-'^|^|position^(^)^,
        'container':'mp4[h264+aac]'^,
        'resolution':concat^(width^,'x'^,height^)^,
        'url':.//src
      }^,
      xivid:m3u8-to-json^(
        $a//locations/^(adaptive^)^(^)[ends-with^(type^,'x-mpegURL'^)]/extract^(src^,'^(.+m3u8^)'^,1^)
      )
    )
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:youtube
xidel "%~1" --xquery ^"^
  let $a:=if (//meta[@property='og:restrictions:age']) then^
        {^|^
          for $x in tokenize(^
            unparsed-text(^
              concat(^
                'https://www.youtube.com/get_video_info?video_id=',^
                //meta[@itemprop='videoId']/@content,^
                '^&amp;eurl=',^
                uri-encode(^
                  'https://youtube.googleapis.com/v/'^|^|//meta[@itemprop='videoId']/@content^
                ),^
                '^&amp;sts=',^
                json(^
                  doc(^
                    'https://www.youtube.com/embed/'^|^|//meta[@itemprop='videoId']/@content^
                  )//script/extract(.,'setConfig\((.+?)\)',1,'*')[3]^
                )//sts^
              )^
            ),^
            '^&amp;'^
          )^
          let $a:=tokenize($x,'=')^
          return {^
            $a[1]:uri-decode($a[2])^
          }^
        ^|}^
      else^
        json(^
          //script/extract(.,'ytplayer.config = (.+?\});',1)[.]^
        )/args,^
      $b:=$a/(^
        url_encoded_fmt_stream_map,^
        adaptive_fmts^
      ) ! tokenize(.,',') ! {^|^
        for $x in tokenize(.,'^&amp;')^
        let $a:=tokenize($x,'=')^
        return {^
          $a[1]:uri-decode($a[2])^
        }^
      ^|}^
  return^
  json:=if ($a/livestream='1') then {^
    'name'://meta[@property='og:title']/@content,^
    'date':format-date(current-date(),'[D01]-[M01]-[Y]'),^
    'formats':xivid:m3u8-to-json($b/streamingData/hlsManifestUrl)^
  } else {^
    'name'://meta[@property='og:title']/@content,^
    'date':format-date(^
      date(//meta[@itemprop='datePublished']/@content),^
      '[D01]-[M01]-[Y]'^
    ),^
    'duration':duration(//meta[@itemprop='duration']/@content) + time('00:00:00'),^
    'subtitle':{^
      'type':'ttml',^
      'url':$a/(json(player_response)//captionTracks)()[languageCode='nl']/baseUrl^
    }[url],^
    'formats':(^
      for $x at $i in reverse($b[quality]) return {^
        'format':'pg-'^|^|$i,^
        'container':let $a:=extract(^
          $x/type,^
          '/(.+);.+^&quot;(\w+)\..+ (\w+)(?:\.^|^&quot;)',^
          (1 to 3)^
        ) return^
        concat(^
          if ($a[1]='3gpp') then '3gp' else $a[1],^
          '[',^
          if ($a[2]='avc1') then 'h264' else $a[2],^
          '+',^
          if ($a[3]='mp4a') then 'aac' else $a[3],^
          ']'^
        ),^
        'resolution':reverse(^
          tokenize($a/fmt_list,',') ! substring-after(.,'/')^
        )[$i],^
        'url':$x/url^
      },^
      for $x at $i in $b[index]^
      order by $x/boolean(size),$x/bitrate^
      count $i^
      return {^
        'format':'dash-'^|^|$i,^
        'container':let $a:=extract(^
          $x/type,^
          '/(.+);.+^&quot;(\w+)(?:\.^|^&quot;)',^
          (1,2)^
        ) return^
        concat(^
          if ($a[1]='3gpp') then '3gp' else $a[1],^
          '[',^
          if ($a[2]='avc1') then 'h264'^
          else if ($a[2]='mp4a') then 'aac' else $a[2],^
          ']'^
        ),^
        'resolution':$x/size ! concat(.,'@',$x/fps,'fps'),^
        'samplerate':$x/audio_sample_rate ! concat(. div 1000,'kHz'),^
        'bitrate':round($x/bitrate div 1000)^|^|'kbps',^
        'url':$x/url^
      }^
    )^
  }^
" > xivid.json
REM CMD's commandline buffer is 8KB (8192 bytes) groot. De gegenereerde JSON
REM hier heeft makkelijk meer dan 20000 tekens en gaat daar dus ver overheen.
REM De enige manier om zo'n JSON toch te verwerken is door gebruik te maken
REM van een tijdelijk bestand.
EXIT /B

:vimeo
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  json:^=json^(
    //script/extract^(.^,'clip_page_config ^= ^(.+^)^;'^,1^)[.]
  ^)/{
    'name':clip/title^,
    'date':replace^(
      clip/uploaded_on^,
      '^(\d+^)-^(\d+^)-^(\d+^).+'^,
      '$3-$2-$1'
    ^)^,
    'duration':clip/duration/raw * duration^('PT1S'^) + time^('00:00:00'^)^,
    'formats':player/json^(config_url^)//files/^(
      for $x at $i in ^(progressive^)^(^)
      order by $x/width
      count $i
      return
      $x/{
        'format':'pg-'^|^|$i^,
        'container':'mp4[h264+aac]'^,
        'resolution':concat^(width^,'x'^,height^,'@'^,fps^,'fps'^)^,
        'url':url
      }^,
      xivid:m3u8-to-json^(^(hls//url^)[1]^)
    ^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:info
xidel --xquery ^"^
  let $json:=json(^
        if (file:exists('xivid.json')) then^
          file:read-text('xivid.json')^
        else^
          replace(environment-variable('json'),'\^^','')^
      ),^
      $a:={^
        'name':'Naam:',^
        'date':'Datum:',^
        'duration':'Tijdsduur:',^
        'start':'Begin:',^
        'end':'Einde:',^
        'expdate':'Gratis tot:',^
        'subtitle':'Ondertiteling:'^
      },^
      $b:=$json()[.!='formats'] ! .[$json(.)[.]],^
      $c:=max(^
        $b ! $a(.) ! string-length(.)^
      ) ! (if (. ^> 9) then . else 9),^
      $d:=string-join((1 to $c + 1) ! ' '),^
      $e:=[^
        {^
          'format':'formaat',^
          'container':'container',^
          'resolution':'resolutie',^
          'samplerate':'frequentie',^
          'bitrate':'bitrate'^
        },^
        $json/(formats)()^
      ],^
      $f:=for $x in $e(1)() return^
      distinct-values(^
        $json/(formats)()()[.!='url']^
      )[contains(.,$x)],^
      $g:=$f ! max($e()(.) ! string-length(.)),^
      $h:=string-join((1 to sum($g)) ! ' ')^
  return (^
    $b ! concat(^
      substring($a(.)^|^|$d,1,$c + 1),^
      if ($json(.) instance of string) then $json(.) else $json(.)/type^
    ),^
    if ($e(2)) then^
      for $x at $i in $e() return^
      concat(^
        if ($i = 1) then substring('Formaten:'^|^|$d,1,$c + 1) else $d,^
        string-join(^
          for $y at $i in $f return^
          substring($x($y)[.]^|^|$h,1,$g[$i] + 2)^
        ),^
        if ($i = count($e())) then '(best)' else ()^
      )^
    else^
      substring('Formaten:'^|^|$d,1,$c + 1)^|^|'-',^
    $json[start]/(^
      let $i:=(start,duration) ! ((time(.) - time('00:00:00')) div dayTimeDuration('PT1S'))^
      return (^
        '',^
        concat(^
          substring('Download:'^|^|$d,1,$c + 1),^
          'ffmpeg',^
          ($i[1] - $i[1] mod 30) ! (if (. = 0) then () else ' -ss '^|^|.),^
          ' -i ^<url^>',^
          ($i[1] mod 30) ! (if (. = 0) then () else ' -ss '^|^|.),^
          ' -t ',^
          $i[2],^
          ' [...]'^
        )^
      )^
    )^
  )^
"
ENDLOCAL
EXIT /B

:timezone
FOR /F "skip=4 tokens=3" %%A IN ('REG QUERY HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v ActiveTimeBias') DO (
  FOR /F "delims=" %%B IN ('xidel -e "tz:=xivid:shex-to-dec('%%A') * duration('-PT1M')" --output-format^=cmd') DO %%B
)
EXIT /B

:start
@ECHO off
SETLOCAL DISABLEDELAYEDEXPANSION
FOR %%A IN (xidel.exe) DO IF EXIST "%%~$PATH:A" (
  FOR /F "tokens=2-4 delims=. " %%B IN ('xidel --version ^| FIND "Xidel"') DO IF %%C%%D LSS 98 (
    ECHO xivid: '%%~$PATH:A' gevonden, maar versie is te oud.
    ECHO Installeer Xidel 0.9.8 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
    ECHO Ga naar http://videlibri.sourceforge.net/xidel.html.
    EXIT /B 1
  )
) ELSE (
  ECHO xivid: 'xidel.exe' niet gevonden!
  ECHO Installeer Xidel 0.9.8 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
  ECHO Ga naar http://videlibri.sourceforge.net/xidel.html.
  EXIT /B 1
)
SET "XIDEL_OPTIONS=--silent --module=xivid.xq"
SET "user_agent=Mozilla/5.0 Firefox/68.0"

:options
SET "prm1=%~1"
IF NOT "%~1"=="" (
  IF "%~1"=="-h" (
    CALL :help
    EXIT /B 0
  ) ELSE IF "%~1"=="-f" (
    IF NOT "%~3"=="" (
      IF NOT "%~2"=="" (
        SET "f=%~2"
        SHIFT /2
      ) ELSE (
        ECHO xivid: formaat code ontbreekt.
        EXIT /B 1
      )
    ) ELSE IF NOT "%~2"=="" (
      FOR /F "delims=" %%A IN ('xidel -e "matches('%~2','^https?://[-A-Za-z0-9\+&@#/%%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%%=~_|]$')"') DO (
        IF "%%A"=="true" (
          ECHO xivid: formaat code ontbreekt.
          EXIT /B 1
        ) ELSE (
          ECHO xivid: url ontbreekt.
          EXIT /B 1
        )
      )
    ) ELSE (
      ECHO xivid: formaat code en url ontbreken.
      EXIT /B 1
    )
  ) ELSE IF "%~1"=="-i" (
    IF NOT "%~2"=="" (
      SET i=1
    ) ELSE (
      ECHO xivid: url ontbreekt.
      EXIT /B 1
    )
  ) ELSE IF "%~1"=="-j" (
    IF NOT "%~2"=="" (
      SET j=1
    ) ELSE (
      ECHO xivid: url ontbreekt.
      EXIT /B 1
    )
  ) ELSE IF "%prm1:~0,1%"=="-" (
    ECHO xivid: optie '%~1' ongeldig.
    EXIT /B 1
  ) ELSE (
    FOR /F "delims=" %%A IN ('xidel -e "matches('%~1','^https?://[-A-Za-z0-9\+&@#/%%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%%=~_|]$')"') DO (
      IF "%%A"=="true" (
        SET "url=%~1"
      ) ELSE (
        ECHO xivid: url ongeldig.
        EXIT /B 1
      )
    )
  )
  SHIFT
  GOTO :options
) ELSE IF NOT DEFINED url (
  ECHO xivid: url ontbreekt.
  ECHO Typ -h voor een lijst met alle opties.
  EXIT /B 1
)

IF NOT "%url:npostart.nl=%"=="%url%" (
  IF NOT "%url:npostart.nl/live=%"=="%url%" (
    ECHO xivid: url niet ondersteund.
    EXIT /B 1
  )
  FOR /F "delims=" %%A IN ('xidel -e "extract('%url%','.+/([\w_]+)',1)"') DO CALL :npo %%A
) ELSE IF NOT "%url:nos.nl=%"=="%url%" (
  CALL :nos "%url%"
) ELSE IF NOT "%url:tvblik.nl=%"=="%url%" (
  CALL :tvblik "%url%"
) ELSE IF NOT "%url:uitzendinggemist.net=%"=="%url%" (
  CALL :tvblik "%url%"
) ELSE IF NOT "%url:rtl.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "extract('%url%','video/([\w-]+)',1)"') DO CALL :rtl %%A
) ELSE IF NOT "%url:rtlnieuws.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel "%url%" -e "//@data-uuid"') DO CALL :rtl %%A
) ELSE IF NOT "%url:kijk.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "extract('%url%','(?:video|videos)/(\w+)',1)"') DO CALL :kijk %%A
) ELSE IF NOT "%url:omropfryslan.nl=%"=="%url%" (
  CALL :regio_frl "%url%"
) ELSE IF NOT "%url:nhnieuws.nl=%"=="%url%" (
  CALL :regio_nh "%url%"
) ELSE IF NOT "%url:at5.nl=%"=="%url%" (
  CALL :regio_nh "%url%"
) ELSE IF NOT "%url:omroepflevoland.nl=%"=="%url%" (
  CALL :regio_fll "%url%"
) ELSE IF NOT "%url:rtvutrecht.nl=%"=="%url%" (
  CALL :regio_utr "%url%"
) ELSE IF NOT "%url:rtvnoord.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:rtvdrenthe.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:rtvoost.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:omroepgelderland.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:omroepwest.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:rijnmond.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:omroepzeeland.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:omroepbrabant.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:l1.nl=%"=="%url%" (
  CALL :regio "%url%"
) ELSE IF NOT "%url:dumpert.nl=%"=="%url%" (
  CALL :dumpert "%url%"
) ELSE IF NOT "%url:telegraaf.nl=%"=="%url%" (
  CALL :telegraaf "%url%"
) ELSE IF NOT "%url:youtube.com=%"=="%url%" (
  CALL :youtube "%url%"
) ELSE IF NOT "%url:youtu.be=%"=="%url%" (
  CALL :youtube "%url%"
) ELSE IF NOT "%url:vimeo.com=%"=="%url%" (
  CALL :vimeo "%url%"
) ELSE (
  ECHO xivid: url niet ondersteund.
  EXIT /B 1
)

IF DEFINED json (
  FOR /F "delims=" %%A IN ('ECHO %json% ^| xidel - -e "fmts:=string-join($json/(formats)()/format)" --output-format^=cmd') DO %%A
) ELSE IF EXIST xivid.json (
  FOR /F "delims=" %%A IN ('xidel xivid.json -e "fmts:=string-join($json/(formats)()/format)" --output-format^=cmd') DO %%A
) ELSE (
  ECHO xivid: geen video^(-informatie^) beschikbaar.
  EXIT /B 1
)
IF DEFINED f (
  IF DEFINED fmts (
    SETLOCAL ENABLEDELAYEDEXPANSION
    IF NOT "!fmts:%f%=!"=="!fmts!" (
      IF DEFINED json (
        ECHO %json% | xidel - -e "$json/(formats)()[format='%f%']/url"
      ) ELSE IF EXIST xivid.json (
        xidel xivid.json -e "$json/(formats)()[format='%f%']/url"
      )
    ) ELSE (
      ECHO xivid: formaat code ongeldig.
      IF EXIST xivid.json DEL xivid.json
      EXIT /B 1
    )
  ) ELSE (
    ECHO xivid: geen video beschikbaar.
    IF EXIST xivid.json DEL xivid.json
    EXIT /B 1
  )
) ELSE IF DEFINED i (
  CALL :info
) ELSE IF DEFINED j (
  IF DEFINED json (
    ECHO %json% | xidel - -e "$json"
  ) ELSE IF EXIST xivid.json (
    xidel xivid.json -e "$json"
  )
) ELSE IF DEFINED fmts (
  IF DEFINED json (
    ECHO %json% | xidel - -e "$json/(formats)()[last()]/url"
  ) ELSE IF EXIST xivid.json (
    xidel xivid.json -e "$json/(formats)()[last()]/url"
  )
) ELSE (
  ECHO xivid: geen video beschikbaar.
  IF EXIST xivid.json DEL xivid.json
  EXIT /B 1
)
IF EXIST xivid.json DEL xivid.json
EXIT /B 0
