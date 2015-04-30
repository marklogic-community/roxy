(:
Copyright 2012-2015 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)
xquery version "1.0-ml";

module namespace u = "http://marklogic.com/roxy/util";

import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";

declare option xdmp:mapping "false";

(:~
 : Builds a uri from a base and a suffix
 : Handles properly concatenating with slashes
 :
 : @param $base - the base of the uri
 : @param $suffix - the suffix of the uri
 :)
declare function u:build-uri(
  $base as xs:string,
  $suffix as xs:string) as xs:string
{
  fn:string-join(
    (fn:replace($base, "(.*)/$", "$1"),
     fn:replace($suffix, "^/(.*)", "$1")),
    "/")
};

declare function u:string-pad (
  $padString as xs:string?,
  $padCount as xs:integer) as xs:string
{
   fn:string-join((for $i in 1 to $padCount return $padString), "")
};

declare function u:lead-zero($int as xs:string, $size as xs:integer) as xs:string
{
  let $length := fn:string-length($int)
  return
    if ($length lt $size) then
      fn:concat(u:string-pad("0", $size - $length), $int)
    else
      $int
};

(:~
 : Converts xs:dateTime to POSIX time - the number of elapsed seconds since Jan 1, 1970
 :
 : @param $time - the dateTime to convert
 : @return - the number of seconds since Jan 1, 1970
 :)
declare function u:time-to-posix($time as xs:dateTime) as xs:decimal
{
  ($time - xs:dateTime('1970-01-01T00:00:00Z')) div xs:dayTimeDuration('PT1S') * 1000
};

declare function u:pluralize($string as xs:string, $count as xs:int) as xs:string
{
  if ($count > 1) then
    fn:concat($string, "s")
  else
    $string
};

declare function u:pluralize($count as xs:int, $singular as xs:string, $plural as xs:string) as xs:string
{
  if ($count > 1) then
    $plural
  else
    $singular
};

declare function u:camel-case($string as xs:string)
{
  fn:string-join(
    for $t in fn:tokenize($string, " ")
    return
      fn:concat(fn:upper-case(fn:substring($t, 1, 1)), fn:lower-case(fn:substring($t, 2))),
    " ")
};

(:
 : 0 <-> 29 secs                                                             # => less than a minute
 : 30 secs <-> 1 min, 29 secs                                                # => 1 minute
 : 1 min, 30 secs <-> 44 mins, 29 secs                                       # => [2..44] minutes
 : 44 mins, 30 secs <-> 89 mins, 29 secs                                     # => about 1 hour
 : 89 mins, 30 secs <-> 23 hrs, 59 mins, 29 secs                             # => about [2..24] hours
 : 23 hrs, 59 mins, 30 secs <-> 41 hrs, 59 mins, 29 secs                     # => 1 day
 : 41 hrs, 59 mins, 30 secs  <-> 29 days, 23 hrs, 59 mins, 29 secs           # => [2..29] days
 : 29 days, 23 hrs, 59 mins, 30 secs <-> 59 days, 23 hrs, 59 mins, 29 secs   # => about 1 month
 : 59 days, 23 hrs, 59 mins, 30 secs <-> 1 yr minus 1 sec                    # => [2..12] months
 : 1 yr <-> 1 yr, 3 months                                                   # => about 1 year
 : 1 yr, 3 months <-> 1 yr, 9 months                                         # => over 1 year
 : 1 yr, 9 months <-> 2 yr minus 1 sec                                       # => almost 2 years
 : 2 yrs <-> max time or date                                                # => (same rules as 1 yr)
 :)
declare function u:distance-of-time($time as xs:dateTime)
{
  let $now := fn:current-dateTime()
  let $distance := $now - $time

  let $minutes := fn:round(functx:total-minutes-from-duration($distance))

  return
    if ($minutes ge 0 and $minutes le 1) then
      "less than a minute"
(:
      let $seconds := functx:total-seconds-from-duration($distance)
      return
        if ($seconds ge 0 and $seconds le 4) then
          "less than 5 seconds"
        else if ($seconds ge 5 and $seconds le 9) then
          "less than 10 seconds"
        else if ($seconds ge 10 and $seconds le 19) then
          "less than 20 seconds"
        else if ($seconds ge 20 and $seconds le 39) then
          "half a minute"
        else if ($seconds ge 40 and $seconds le 59) then
          "less than a minute"
        else
          "1 minute"
:)
    else if ($minutes ge 2 and $minutes le 44) then
      fn:concat($minutes, " minutes")
    else if ($minutes ge 45 and $minutes le 89) then
      "about 1 hour"
    else if ($minutes ge 90 and $minutes le 1439) then
      fn:concat(fn:round(functx:total-hours-from-duration($distance)), " hours")
    else if ($minutes ge 1440 and $minutes le 2519) then
      "1 day"
    else if ($minutes ge 2520 and $minutes le 43199) then
      fn:concat(fn:round(functx:total-days-from-duration($distance)), " days")
    else if ($minutes ge 43200 and $minutes le 86399) then
      "1 month"
    else if ($minutes ge 86400 and $minutes le 525599) then
      fn:concat(fn:round($distance div xs:dayTimeDuration("P30D")), " months")
    else
      let $years := fn:round(functx:total-days-from-duration($distance) div 365)
      return
        fn:string-join(($years, u:pluralize("year", $years)), " ")
};