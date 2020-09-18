@GOTO :start
:: --------------------------------
:: Xivid batch script
:: --------------------------------
::
:: Copyright (C) 2020 Reino Wijnsma
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
:: Reino Wijnsma (rwijnsma@xs4all.nl)
:: https://github.com/Reino17/xivid

:help
ECHO Xivid, een video-url extractie script.
ECHO Gebruik: xivid.bat [optie] url
ECHO.
ECHO   -f ID[+ID]    Selecteer specifiek formaat, of specifieke formaten.
ECHO                 Met een ID dat eindigt op een '#' wordt het formaat
ECHO                 met het hoogste nummer geselecteerd.
ECHO                 Zonder opgave wordt het formaat met de hoogste
ECHO                 resolutie en/of bitrate geselecteerd.
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
ECHO   rtlxl.nl                omroepflevoland.nl    omroepbrabant.nl
ECHO   kijk.nl                 rtvoost.nl            l1.nl
ECHO.
ECHO   dumpert.nl              vimeo.com             pornhub.com
ECHO   autojunk.nl             dailymotion.com
ECHO   telegraaf.nl            twitch.tv
ECHO   ad.nl                   mixcloud.com
ECHO   lc.nl                   soundcloud.com
ECHO   youtube.com             facebook.com
ECHO   youtu.be                twitter.com
ECHO.
ECHO Voorbeelden:
ECHO   xivid.bat https://www.npostart.nl/nos-journaal/28-02-2017/POW_03375558
ECHO   xivid.bat -i https://www.rtlxl.nl/programma/rtl-nieuws/bf475894-02ce-3724-9a6f-91de543b8a4c
ECHO   xivid.bat -f hls-#+sub-1 https://kijk.nl/video/AgvoU4AJTpy
EXIT /B

:nos
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  let $a:^=json^(
    //script[ends-with^(@data-ssr-name^,'VideoPlayer'^) or @data-ssr-name^='pages/Article/Article']
  ^)/^(.//video^,.^)[1] return
  json:^=if ^(//video/@data-type^='livestream'^) then {
    'name':concat^(
      'NOS: '^,
      //h1[ends-with^(@class^,'__title'^)]^,
      ' Livestream'
    ^)^,
    'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
    'formats':xivid:m3u8-to-json^(//@data-stream^)
  } else {
    'name':'NOS: '^|^|$a/title^,
    'date':format-date^(
      dateTime^(
        replace^(
          ^($a/published_at^,//@datetime^)[1]^,
          '^(.+^)^(\d{2}^)'^,
          '$1:$2'
        ^)
      ^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':$a/duration * duration^('PT1S'^) + time^('00:00:00'^)^,
    'formats':xivid:m3u8-to-json^($a/^(formats^)^(1^)/url/mp4^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:regio_nh
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  let $a:^=json^(
    //script/extract^(.^,'INITIAL_PROPS__ ^= ^(.+^)'^,1^)[.]
  ^)/pageData return
  json:^={
    'name':if ^($a^) then
      if ^($a/^(media^)^(1^)/title^) then
        $a/^(media^)^(1^)/concat^(source^,': '^,title^)
      else
        concat^($a/^(media^)^(1^)/source^,': '^,$a/title^)
    else
      substring-after^(//title^,'- '^)^|^|': Livestream'^,
    'date':if ^($a^) then
      format-date^(
        $a/updated * duration^('PT1S'^) + 
        implicit-timezone^(^) + date^('1970-01-01'^)^,
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
        'id':'pg-1'^,
        'format':'mp4[h264+aac]'^,
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
          'id':'pg-1'^,
          'format':'mp4[h264+aac]'^,
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
        'id':'pg-'^|^|$i^,
        'format':'mp4[h264+aac]'^,
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

:autojunk
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  let $a:^=//div[@id^='playerWrapper']/script[1] return
  json:^={
    'name':'Autojunk: '^|^|extract^($a^,'clipData.title^=^&quot^;^(.+^)^&quot^;'^,1^)^,
    'date':extract^(//span[@class^='posted']^,'^([\d-]+^)'^,1^)^,
    'duration':format-time^(
      extract^($a^,'clipData\[^&quot^;length^&quot^;\].+?^(\d+^)'^,1^) * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':[
      for $x at $i in json^(
        replace^(
          extract^($a^,'clipData.assets ^= ^(.+\]^)^;'^,1^,'s'^)^,
          ' //.+'^,
          ''
        ^)
      ^)^(^)[src]
      order by $x/bandwidth
      count $i
      return {
        'id':'pg-'^|^|$i^,
        'format':'mp4[h264+aac]'^,
        'resolution':concat^($x/width^,'x'^,$x/height^)^,
        'bitrate':$x/bandwidth^|^|'kbps'^,
        'url':$x/src
      }
    ]
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
                uri-encode('https://youtube.googleapis.com/v/'^|^|//meta[@itemprop='videoId']/@content),^
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
          let $a:=tokenize($x,'=') return {$a[1]:uri-decode($a[2])}^
        ^|}^
      else^
        json(^
          //script/extract(.,'ytplayer.config = (.+?\});',1)[.]^
        )/args,^
      $b:=$a/json(player_response),^
      $c:=for $x at $i in tokenize($a/url_encoded_fmt_stream_map,',') return {^|^
        let $a:=extract(^
          tokenize($a/fmt_list,',')[$i],^
          '/(\d+)x(\d+)',^
          (1,2)^
        ) return ({'width':$a[1]},{'height':$a[2]}),^
        for $y in tokenize($x,'^&amp;')^
        let $a:=tokenize($y,'=')^
        return^
        {if ($a[1]='type') then 'mimeType' else $a[1]:uri-decode($a[2])}^
      ^|},^
      $d:=tokenize($a/adaptive_fmts,',') ! {^|^
        for $x in tokenize(.,'^&amp;')^
        let $a:=tokenize($x,'=')^
        return^
        if ($a[1]='size') then^
          let $a:=tokenize($a[2],'x') return ({'width':$a[1]},{'height':$a[2]})^
        else {^
          if ($a[1]='type') then^
            'mimeType'^
          else if ($a[1]='audio_sample_rate') then^
            'audioSampleRate'^
          else^
            $a[1]:uri-decode($a[2])^
        }^
      ^|}^
  return^
  if ($b/videoDetails/isLive) then {^
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
    'formats':[^
      ($b//captionTracks)()[languageCode='nl']/{^
        'id':'sub-1',^
        'format':'ttml',^
        'language':'nl',^
        'label':name/simpleText,^
        'url':baseUrl^
      },^
      for $x at $i in if ($b/streamingData/formats) then $b/streamingData/(formats)()[url] else reverse($c[not(s)])^
      order by $x/width^
      count $i^
      return {^
        'id':'pg-'^|^|$i,^
        'format':let $a:=extract(^
          $x/mimeType,^
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
        'resolution':concat($x/width,'x',$x/height),^
        'bitrate':$x[itag ne 43]/bitrate ! concat(round(. div 1000),'kbps'),^
        'url':$x/url^
      },^
      for $x at $i in if ($b/streamingData/adaptiveFormats) then $b/streamingData/(adaptiveFormats)()[url] else $d[not(s)]^
      order by $x/boolean(width),$x/bitrate^
      count $i^
      return {^
        'id':'dash-'^|^|$i,^
        'format':let $a:=extract(^
          $x/mimeType,^
          '/(.+);.+^&quot;(\w+)',^
          (1,2)^
        ) return^
        concat(^
          $a[1],^
          '[',^
          if ($a[2]='avc1') then 'h264' else if ($a[2]='mp4a') then 'aac' else $a[2],^
          ']'^
        ),^
        'resolution':$x/width ! concat(.,'x',$x/height,'@',$x/fps,'fps'),^
        'samplerate':$x/audioSampleRate ! concat(. div 1000,'kHz'),^
        'bitrate':round($x/bitrate div 1000)^|^|'kbps',^
        'url':$x/url^
      }^
    ]^
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
        'id':'pg-'^|^|$i^,
        'format':'mp4[h264+aac]'^,
        'resolution':concat^(width^,'x'^,height^,'@'^,fps^,'fps'^)^,
        'url':url
      }^,
      xivid:m3u8-to-json^(^(hls//url^)[1]^)
    ^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:dailymotion
FOR /F "delims=" %%A IN ('xidel "https://www.dailymotion.com/player/metadata/video/%~1" -e ^"
  json:^=$json/{
    'name':'Dailymotion: '^|^|title^,
    'date':format-date^(
      created_time * duration^('PT1S'^) +
      implicit-timezone^(^) + date^('1970-01-01'^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':format-time^(
      duration * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':xivid:m3u8-to-json^(qualities//url^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:twitch
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  declare variable $id:^=extract^($url^,'.+/^(.+^)'^,1^)^;
  declare variable $cid:^='kimne78kx3ncx6brgo4mv6wki5h1ko'^;
  json:^=if ^($id castable as integer^) then
    let $a:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':'https://api.twitch.tv/kraken/videos/'^|^|$id
        }^)/json^,
        $b:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':concat^('http://api.twitch.tv/api/vods/'^,$id^,'/access_token'^)
        }^)/json
    return {
      'name':'Twitch: '^|^|$a/title^,
      'date':format-date^(
        dateTime^($a/published_at^)^,
        '[D01]-[M01]-[Y]'
      ^)^,
      'duration':format-time^(
        $a/length * duration^('PT1S'^)^,
        '[H01]:[m01]:[s01]'
      ^)^,
      'formats':xivid:m3u8-to-json^(
        concat^(
          'https://usher.ttvnw.net/vod/'^,
          $id^,
          '.m3u8?allow_source^=true^&amp^;allow_audio_only^=true^&amp^;allow_spectre^=true^&amp^;player^=twitchweb^&amp^;sig^='^,
          $b/sig^,
          '^&amp^;token^='^,
          uri-encode^($b/token^)
        ^)
      ^)
    }
  else
    let $a:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':concat^('http://api.twitch.tv/kraken/streams/'^,$id^,'?stream_type^=all'^)
        }^)/json^,
        $b:^=x:request^({
          'headers':'Client-ID: '^|^|$cid^,
          'url':concat^('http://api.twitch.tv/api/channels/'^,$id^,'/access_token'^)
        }^)/json
    return {
      'name':'Twitch: '^|^|$a//status^,
      'date':format-date^(current-date^(^)^,'[D01]-[M01]-[Y]'^)^,
      'formats':xivid:m3u8-to-json^(
        concat^(
          'https://usher.ttvnw.net/api/channel/hls/'^,
          $id^,
          '.m3u8?allow_source^=true^&amp^;allow_audio_only^=true^&amp^;allow_spectre^=true^&amp^;p^='^,
          random-seed^(^)^,
          random^(1000000^)^,
          '^&amp^;player^=twitchweb^&amp^;segment_preference^=4^&amp^;sig^='^,
          $b/sig^,
          '^&amp^;token^='^,
          uri-encode^($b/token^)
        ^)
      ^)
    }
^" --output-format^=cmd') DO %%A
EXIT /B

:mixcloud
FOR /F "delims=" %%A IN ('xidel "%~1" -e ^"
  declare variable $decryption_key:^='IFYOUWANTTHEARTISTSTOGETPAIDDONOTDOWNLOADFROMMIXCLOUD'^;
  declare function local:decrypt^($a as base64Binary^) as string {
    let $url:^=x:cps^(binary-to-string^($a^)^)^,
        $key:^=x:cps^(
          substring^(
            string-join^(^(1 to ceiling^(count^($url^) div string-length^($decryption_key^)^)^) ! $decryption_key^)^,
            1^,count^($url^)
          ^)
        ^)
    return
    string-join^(
      x:cps^(
        for $x at $i in $url return
        xivid:bin-xor^($x^,$key[$i]^)
      ^)
    ^)
  }^;
  let $csrf:^=substring-before^(substring-after^($headers[contains^(.^,'csrftoken'^)]^,'^='^)^,'^;'^)^,
      $us:^=tokenize^(substring-after^('%~1'^,'mixcloud.com/'^)^,'/'^)
  return
  json:^=x:request^(
    {
      'headers':^(
        'Content-Type: application/json'^,
        'Referer: %~1'^,
        'X-CSRFToken: '^|^|$csrf^,
        'Cookie: csrftoken^='^|^|$csrf
      ^)^,
      'post':concat^(
        '{\^"query\^":\"{cloudcastLookup^(lookup:{username:\\\^"'^,
        $us[1]^,
        '\\\^"^,slug:\\\^"'^,
        $us[2]^,
        '\\\^"}^){name^,owner{displayName^,url^,username}^,publishDate^,audioLength^,streamInfo{hlsUrl^,url}}}\^"}'
      ^)^,
      'url':'https://www.mixcloud.com/graphql'
    }
  ^)/json//cloudcastLookup/{
    'name':concat^(owner/displayName^,' - '^,name^)^,
    'date':format-date^(dateTime^(publishDate^)^,'[D01]-[M01]-[Y]'^)^,
    'duration':format-time^(
      audioLength * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':[
      {
        'id':'pg-1'^,
        'format':'m4a[aac]'^,
        'url':local:decrypt^(base64Binary^(streamInfo/url^)^)
      }^,
      xivid:m3u8-to-json^(
        local:decrypt^(
          base64Binary^(streamInfo/hlsUrl^)
        ^)
      ^)
    ]
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:soundcloud
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  let $cid:^=substring^(
        substring-after^(
          unparsed-text^(//script[@crossorigin][last^(^)]/@src^)^,
          'client_id:'
        ^)^,
        2^,32
      ^)^,
      $a:^=json^(//script/extract^(.^,'^(\[\{.+^)\^)'^,1^)[.]^)^(^)[.//media]/^(data^)^(^)^,
      $b:^=^($a//transcodings^)^(^)
  return
  json:^=$a/{
    'name':concat^(user/^(full_name^,username^)[.][1]^,' - '^,title^)^,
    'date':format-date^(dateTime^(created_at^)^,'[D01]-[M01]-[Y]'^)^,
    'duration':format-time^(
      round^(duration div 1000^) * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':[
      $b[format/protocol^='progressive']/^(
        let $url:^=json^(concat^(url^,'?client_id^='^,$cid^)^)/url return {
          'id':'pg-1'^,
          'format':substring-before^(preset^,'_'^)^,
          'bitrate':extract^($url^,'\.^(\d+^)\.'^,1^)^|^|'kbps'^,
          'url':$url
        }
      ^)^,
      for $x at $i in $b
      where $x/format/protocol^='hls'
      order by $x/preset descending
      count $i
      let $url:^=json^(concat^($x/url^,'?client_id^='^,$cid^)^)/url
      return {
        'id':'hls-'^|^|$i^,
        'format':concat^('m3u8['^,substring-before^($x/preset^,'_'^)^,']'^)^,
        'bitrate':extract^($url^,'\.^(\d+^)\.'^,1^)^|^|'kbps'^,
        'url':$url
      }
    ]
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:facebook
FOR /F "delims=" %%A IN ('xidel --user-agent="%XIDEL_UA%" "%~1" --xquery ^"
  let $a:^=^(//script/substring-before^(substring-after^(.^,'onPageletArrive^('^)^,'^)^;}^)^)^;'^)[.]^)[2] ! json^(
    replace^(.^,'\\x'^,'\\u00'^)
  ^)/^(.//videoData^)^(^) return
  json:^={
    'name':replace^(//title^,'^(.+^) \^| ^(.+^)'^,'$2: $1'^)^,
    'date':format-date^(
      //code/comment^(^) ! parse-html^(.^)//@data-utime * duration^('PT1S'^) +
      implicit-timezone^(^) + date^('1970-01-01'^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':format-time^(
      duration^($a/parse-xml^(dash_manifest^)//@mediaPresentationDuration^) + duration^('PT0.5S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':[
      {
        'id':'sub-1'^,
        'format':'srt'^,
        'language':'en'^,
        'url':$a/subtitles_src
      }[url]^,
      $a/^(
        ^(sd_src_no_ratelimit^,sd_src^)[.][1]^,
        ^(hd_src_no_ratelimit^,hd_src^)[.][1]
      ^) ! {
        'id':'pg-'^|^|position^(^)^,
        'format':'mp4[h264+aac]'^,
        'url':uri-decode^(.^)
      }^,
      for $x at $i in $a/parse-xml^(dash_manifest^)//Representation
      order by $x/boolean^(@width^)^,$x/@bandwidth
      count $i
      return {
        'id':'dash-'^|^|$i^,
        'format':concat^(
          substring-after^($x/@mimeType^,'/'^)^,
          '['^,
          extract^($x/@codecs^,'^(^^[\w]+^)'^,1^) ! ^(
            if ^(.^='avc1'^) then 'h264' else if ^(.^='mp4a'^) then 'aac' else .
          ^)^,
          ']'
        ^)^,
        'resolution':$x/@width ! concat^(.^,'x'^,$x/@height^)^,
        'samplerate':$x/@audioSamplingRate ! concat^(. div 1000^,'kHz'^)^,
        'bitrate':round^($x/@bandwidth div 1000^)^|^|'kbps'^,
        'url':$x/uri-decode^(BaseUrl^)
      }
    ]
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:twitter
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  declare variable $head:^='Authorization: Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%%2F40K4moUkGsoc%%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw'^;
  let $a:^=x:request^({
        'method':'POST'^,
        'headers':$head^,
        'url':'https://api.twitter.com/1.1/guest/activate.json'
      }^)/json/guest_token^,
      $b:^=x:request^({
        'headers':^($head^,'x-guest-token: '^|^|$a^)^,
        'url':'https://api.twitter.com/1.1/'^|^|^(
          if ^(//@data-supports-broadcast-player^) then
            concat^('broadcasts/show.json?ids^='^,extract^(//@data-expanded-url^,'.+/^(.+^)'^,1^)^)
          else
            concat^('videos/tweet/config/'^,//@data-associated-tweet-id^,'.json'^)
        ^)
      }^)/json
  return
  json:^={
    'name'://title^,
    'date':format-date^(
      //div[@class^='permalink-header']//@data-time * duration^('PT1S'^) +
      implicit-timezone^(^) + date^('1970-01-01'^)^,
      '[D01]-[M01]-[Y]'
    ^)^,
    'duration':format-time^(
      round^(^($b//durationMs^,$b//end_ms - $b//start_ms^) div 1000^) * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':if ^($b/broadcasts^) then
      [{
        'id':'hls-1'^,
        'format':'m3u8[h264+aac]'^,
        'resolution':concat^($b//width^,'x'^,$b//height^)^,
        'url':x:request^({
          'headers':^($head^,'x-guest-token: '^|^|$a^)^,
          'url':'https://api.twitter.com/1.1/live_video_stream/status/'^|^|$b//media_key
        }^)//location
      }]
    else
      xivid:m3u8-to-json^($b//playbackUrl^)
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:pornhub
FOR /F "delims=" %%A IN ('xidel "%~1" --xquery ^"
  let $a:^=json^(//script/extract^(.^,'flashvars_\d+ ^= ^(.+^)^;'^,1^)[.]^) return
  json:^={
    'name':'Pornhub: '^|^|$a/video_title^,
    'date':replace^(
      $a/image_url^,
      '.+?^(\d{4}^)^(\d{2}^)/^(\d{2}^).+'^,
      '$3-$2-$1'
    ^)^,
    'duration':format-time^(
      $a/video_duration * duration^('PT1S'^)^,
      '[H01]:[m01]:[s01]'
    ^)^,
    'formats':[
      for $x in //script/extract^(.^,'^(var ra.+?quality.+?^)flashvars'^,1^,'*'^) !
      replace^(.^,'^&quot^; \+ ^&quot^;^|^&quot^;'^,''^)
      group by $q:^=extract^($x^,'quality_^(\d+^)p^='^,1^)
      count $i
      return {
        'id':'pg-'^|^|$i^,
        'format':'mp4[h264+aac]'^,
        'resolution':^('426x240'^,'854x480'^,'1280x720'^,'1920x1080'^)[$i]^,
        'url':string-join^(
          extract^($x^,'\*/^(\w+^)'^,1^,'*'^) ! substring-before^(substring-after^($x^,.^|^|'^='^)^,'^;'^)
        ^)
      }
    ]
  }
^" --output-format^=cmd') DO %%A
EXIT /B

:start
@ECHO off
SETLOCAL DISABLEDELAYEDEXPANSION
SET "PATH=%PATH%;%~dp0"
FOR %%A IN (xidel.exe) DO IF EXIST "%%~$PATH:A" (
  FOR /F "delims=(." %%B IN ('xidel --version ^| FIND "("') DO (
    IF %%B GEQ 20200726 (
      SET "XIDEL_OPTIONS=--silent --module=%~dp0xivid.xqm --json-mode=deprecated"
      SET "XIDEL_UA=Mozilla/5.0 Firefox/70.0"
    ) ELSE (
      ECHO xivid: '%%~$PATH:A' gevonden, maar versie is te oud.
      ECHO Installeer Xidel 0.9.9.7433 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
      ECHO Ga naar http://videlibri.sourceforge.net/xidel.html.
      EXIT /B 1
    )
  )
) ELSE (
  ECHO xivid: 'xidel.exe' niet gevonden!
  ECHO Installeer Xidel 0.9.9.7433 of nieuwer a.u.b. om Xivid te kunnen gebruiken.
  ECHO Ga naar http://videlibri.sourceforge.net/xidel.html.
  EXIT /B 1
)

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
        ECHO xivid: formaat id ontbreekt.
        EXIT /B 1
      )
    ) ELSE IF NOT "%~2"=="" (
      FOR /F "delims=" %%A IN ('xidel -e "matches('%~2','^https?://[-A-Za-z0-9\+&@#/%%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%%=~_|]$')"') DO (
        IF "%%A"=="true" (
          ECHO xivid: formaat id ontbreekt.
          EXIT /B 1
        ) ELSE (
          ECHO xivid: url ontbreekt.
          EXIT /B 1
        )
      )
    ) ELSE (
      ECHO xivid: formaat id en url ontbreken.
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
    ECHO xivid: url wordt niet ondersteund.
    EXIT /B 1
  )
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:npo('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:nos.nl=%"=="%url%" (
  CALL :nos "%url%"
) ELSE IF NOT "%url:tvblik.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:tvblik('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:uitzendinggemist.net=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:tvblik('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtlxl.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:rtl('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:rtlnieuws.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:rtl('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:kijk.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:kijk('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:omropfryslan.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:ofr('%url%')" --output-format^=cmd') DO %%A
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
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:dumpert('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:autojunk.nl=%"=="%url%" (
  CALL :autojunk "%url%"
) ELSE IF NOT "%url:telegraaf.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:telegraaf('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:ad.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:ad('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:lc.nl=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "json:=xivid:lc('%url%')" --output-format^=cmd') DO %%A
) ELSE IF NOT "%url:youtube.com=%"=="%url%" (
  CALL :youtube "%url%"
) ELSE IF NOT "%url:youtu.be=%"=="%url%" (
  CALL :youtube "%url%"
) ELSE IF NOT "%url:vimeo.com=%"=="%url%" (
  CALL :vimeo "%url%"
) ELSE IF NOT "%url:dailymotion.com=%"=="%url%" (
  FOR /F "delims=" %%A IN ('xidel -e "extract('%url%','.+/(.+)',1)"') DO CALL :dailymotion %%A
) ELSE IF NOT "%url:twitch.tv=%"=="%url%" (
  CALL :twitch "%url%"
) ELSE IF NOT "%url:mixcloud.com=%"=="%url%" (
  CALL :mixcloud "%url%"
) ELSE IF NOT "%url:soundcloud.com=%"=="%url%" (
  CALL :soundcloud "%url%"
) ELSE IF NOT "%url:facebook.com=%"=="%url%" (
  CALL :facebook "%url%"
) ELSE IF NOT "%url:twitter.com=%"=="%url%" (
  CALL :twitter "%url%"
) ELSE IF NOT "%url:pornhub.com=%"=="%url%" (
  CALL :pornhub "%url%"
) ELSE (
  ECHO xivid: url wordt niet ondersteund.
  EXIT /B 1
)

IF EXIST xivid.json (
  FOR /F "delims=" %%A IN ('xidel xivid.json -e "fmts:=join($json/(formats)()/id)" --output-format^=cmd') DO %%A
) ELSE IF DEFINED json (
  FOR /F "delims=" %%A IN ('ECHO %json% ^| xidel - -e "fmts:=join($json/(formats)()/id)" --output-format^=cmd') DO %%A
) ELSE (
  ECHO xivid: geen video^(-informatie^) beschikbaar.
  EXIT /B 1
)
IF DEFINED f (
  IF DEFINED fmts (
    SETLOCAL ENABLEDELAYEDEXPANSION
    FOR %%A IN (%f:+= %) DO (
      SET _f=%%A
      IF "!_f:~-1!"=="#" (
        CALL SET _fmts=%%fmts:!_f:~0,-1!=%%
        IF "%fmts%"=="!_fmts!" (
          ECHO xivid: formaat id '!_f!' ongeldig.
          EXIT /B 1
        )
      ) ELSE (
        CALL SET _fmts=%%fmts:!_f!=%%
        IF "%fmts%"=="!_fmts!" (
          ECHO xivid: formaat id '!_f!' ongeldig.
          EXIT /B 1
        )
      )
    )
    IF EXIST xivid.json (
      xidel xivid.json -e ^"^
        for $x in tokenize^('%f%'^,'\+'^) return^
        if ^(ends-with^($x^,'#'^)^) then^
          $json/^(formats^)^(^)[starts-with^(id^,substring^($x^,1^,string-length^($x^) - 1^)^)][last^(^)]/url^
        else^
          $json/^(formats^)^(^)[id^=$x]/url^
      "
    ) ELSE (
      ECHO !json! | xidel - -e ^"^
        for $x in tokenize^('%f%'^,'\+'^) return^
        if ^(ends-with^($x^,'#'^)^) then^
          $json/^(formats^)^(^)[starts-with^(id^,substring^($x^,1^,string-length^($x^) - 1^)^)][last^(^)]/url^
        else^
          $json/^(formats^)^(^)[id^=$x]/url^
      "
    )
  ) ELSE (
    ECHO xivid: geen video beschikbaar.
    IF EXIST xivid.json DEL xivid.json
    EXIT /B 1
  )
) ELSE IF DEFINED i (
  IF EXIST xivid.json (
    xidel xivid.json -e "xivid:info($json)"
  ) ELSE (
    ECHO %json% | xidel - -e "xivid:info($json)"
  )
) ELSE IF DEFINED j (
  IF EXIST xivid.json (
    xidel xivid.json -e "$json"
  ) ELSE (
    ECHO %json% | xidel - -e "$json"
  )
) ELSE IF DEFINED fmts (
  IF EXIST xivid.json (
    xidel xivid.json -e "$json/(formats)()[last()]/url"
  ) ELSE (
    ECHO %json% | xidel - -e "$json/(formats)()[last()]/url"
  )
) ELSE (
  ECHO xivid: geen video beschikbaar.
  IF EXIST xivid.json DEL xivid.json
  EXIT /B 1
)
IF EXIST xivid.json DEL xivid.json
EXIT /B 0
