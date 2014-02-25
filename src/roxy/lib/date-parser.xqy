(:
Copyright 2011 MarkLogic Corporation

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

module namespace dateparser="http://marklogic.com/dateparser";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare variable $analyzeString := try { xdmp:function(xs:QName("fn:analyze-string")) } catch ($e) {};
declare variable $regexSupported := try { exists(xdmp:apply($analyzeString, " ", " ")) } catch ($e) { false() };

declare variable $dateparser:FORMATS as element(format)+ := (
  (: Thu Jul 07 2011 11:05:42 GMT-0700 (PDT) :)
  <format>
    <ignore>\w+</ignore>
    <whitespace/>
    <month>\w+</month>
    <whitespace/>
    <day>\d\d</day>
    <whitespace/>
    <year>\d\d\d\d</year>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <string>gmt</string>
    <timezone>-\d\d\d\d|\+\d\d\d\d</timezone>
    <whitespace/>
    <ignore>\(\w+\)</ignore>
  </format>,

  (: 2011:04:19 12:29:42 :)
  <format>
    <year>\d\d\d\d</year>
    <string>:</string>
    <month>\d\d</month>
    <string>:</string>
    <day>\d\d</day>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
  </format>,

  (: Sun Aug 15 19:42:00 2004 :)
  <format>
    <ignore>\w+</ignore>
    <whitespace/>
    <month>\w+</month>
    <whitespace/>
    <day>\d\d</day>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <year>\d\d\d\d</year>
  </format>,

  (: 25-Oct-2004 17:06:46 -0500 :)
  <format>
    <day>\d\d</day>
    <string>-</string>
    <month>\w+</month>
    <string>-</string>
    <year>\d\d\d\d</year>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <timezone>-\d\d\d\d|\+\d\d\d\d</timezone>
  </format>,

  (: Mon, 23 Sep 0102 23:14:26 +0900 :)
  <format>
    <ignore>\w+,</ignore>
    <whitespace/>
    <day>\d\d</day>
    <whitespace/>
    <month>\w+</month>
    <whitespace/>
    <year>\d\d\d\d</year>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <timezone>-\d\d\d\d|\+\d\d\d\d</timezone>
  </format>,

  (: 30 Jun 2006 09:39:08 -0500 :)
  <format>
    <day>\d\d</day>
    <whitespace/>
    <month>\w+</month>
    <whitespace/>
    <year>\d\d\d\d</year>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <timezone>-\d\d\d\d|\+\d\d\d\d</timezone>
  </format>,

  (: Apr 16 13:49:06 2003 +0200 :)
  <format>
    <month>\w+</month>
    <whitespace/>
    <day>\d\d</day>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <year>\d\d\d\d</year>
    <whitespace/>
    <timezone>-\d\d\d\d|\+\d\d\d\d</timezone>
  </format>,

  (: Aug 04 11:44:58 EDT 2003 :)
  <format>
    <month>\w+</month>
    <whitespace/>
    <day>\d\d</day>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <timezone>\w\w\w</timezone>
    <whitespace/>
    <year>\d\d\d\d</year>
  </format>,

  (: 4 Jan 98 0:41 EDT :)
  <format>
    <day>\d\d?</day>
    <whitespace/>
    <month>\w+</month>
    <whitespace/>
    <year>\d\d</year>
    <whitespace/>
    <hour>\d\d?</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <whitespace/>
    <timezone>\w\w\w</timezone>
  </format>,

  (: 08/20/2007 5:58:20 AM:)
  (: 08/20/07 5:58:20 AM:)
  <format>
    <month>\d\d?</month>
    <string>/</string>
    <day>\d\d?</day>
    <string>/</string>
    <year>\d\d\d\d|\d\d</year>
    <whitespace/>
    <hour>\d\d?</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <whitespace/>
    <meridiem/>
  </format>,


  (: 08-20-2007 :)
  (: 08-20-07 :)
  <format>
    <month>\d\d</month>
    <string>-</string>
    <day>\d\d</day>
    <string>-</string>
    <year>\d\d\d\d|\d\d</year>
  </format>,

  (: 2007/08/20 :)
  (: 07/08/20 :)
  <format>
    <year>\d\d\d\d|\d\d</year>
    <string>/</string>
    <month>\d\d</month>
    <string>/</string>
    <day>\d\d</day>
  </format>,

  (: 08/20/2007 :)
  (: 08/20/07 :)
  <format>
    <month>\d\d</month>
    <string>/</string>
    <day>\d\d</day>
    <string>/</string>
    <year>\d\d\d\d|\d\d</year>
  </format>,

  (: 20070920 :)
  <format>
    <year>\d\d\d\d</year>
    <month>\d\d</month>
    <day>\d\d</day>
  </format>,

  (: December 20th, 2005 :)
  <format>
    <month>\w+</month>
    <whitespace/>
    <day>\d\d|\d?\dth|1st|2nd|3rd</day>
    <string>,?</string>
    <whitespace/>
    <year>\d\d\d\d</year>
  </format>,

  (: 2009/04/15 14:26:51+12'00' :)
  <format>
    <year>\d\d\d\d</year>
    <string>/</string>
    <month>\d\d</month>
    <string>/</string>
    <day>\d\d</day>
    <whitespace/>
    <hour>\d\d</hour>
    <string>:</string>
    <minute>\d\d</minute>
    <string>:</string>
    <second>\d\d</second>
    <timezone>-\d\d'\d\d'|\+\d\d'\d\d'|\w+</timezone>
  </format>
);


declare function dateparser:isSupported(
) as xs:boolean
{
  $regexSupported
};

declare function dateparser:parse(
  $date as xs:string
)
{
  if($date castable as xs:dateTime) then
    xs:dateTime($date)
  else if($date castable as xs:date) then
    adjust-dateTime-to-timezone(xs:dateTime(concat($date, "T00:00:00")), implicit-timezone())
  else if($regexSupported) then
    let $date := normalize-space($date)
    for $format in $dateparser:FORMATS
    let $regex := dateparser:assembleFormat($format)
    where matches($date, $regex, "i")
    return dateparser:analyzedStringToDate(xdmp:apply($analyzeString, $date, $regex, "i"), $format)
  else ()
};


declare private function dateparser:assembleFormat(
  $format as element(format)
) as xs:string
{
  let $groups :=
    for $token in $format/*
    return
      if(local-name($token) = "whitespace") then
        "\s+"
      else if(local-name($token) = "string") then
        string($token)
      else if(local-name($token) = "meridiem") then
        "(am|pm|a\.m\.|p\.m\.)"
      else
        concat("(", string($token), ")")
  return concat("^", string-join($groups, ""), "$")
};

declare private function dateparser:analyzedStringToDate(
  $string as element(),
  $format as element(format)
) as xs:dateTime?
{
  let $yearPosition := dateparser:extractLocationFromAnalyzedString("year", $format)
  let $monthPosition := dateparser:extractLocationFromAnalyzedString("month", $format)
  let $dayPosition := dateparser:extractLocationFromAnalyzedString("day", $format)
  let $hourPosition := dateparser:extractLocationFromAnalyzedString("hour", $format)
  let $minutePosition := dateparser:extractLocationFromAnalyzedString("minute", $format)
  let $secondPosition := dateparser:extractLocationFromAnalyzedString("second", $format)
  let $timezonePosition := dateparser:extractLocationFromAnalyzedString("timezone", $format)
  let $meridiemPosition := dateparser:extractLocationFromAnalyzedString("meridiem", $format)
  let $year := dateparser:processYear(string($string//*:group[@nr = $yearPosition]))
  let $month := dateparser:processMonth(string($string//*:group[@nr = $monthPosition]))
  let $day := dateparser:processDay(string($string//*:group[@nr = $dayPosition]))
  let $hourString :=
    if($meridiemPosition) then
      dateparser:adjustHourForMeridiem(string($string//*:group[@nr = $hourPosition]), string($string//*:group[@nr = $meridiemPosition]))
    else
      string($string//*:group[@nr = $hourPosition])
  let $hour := dateparser:expandTwoDigits($hourString, "00")
  let $minute := dateparser:expandTwoDigits(string($string//*:group[@nr = $minutePosition]), "00")
  let $second := dateparser:expandTwoDigits(string($string//*:group[@nr = $secondPosition]), "00")
  let $timezone := dateparser:processZone(string($string//*:group[@nr = $timezonePosition]))

  let $possibleDate := concat($year, "-", $month, "-", $day, "T", $hour, ":", $minute, ":", $second, $timezone)
  where $possibleDate castable as xs:dateTime
  return
    if($timezone = "") then
      adjust-dateTime-to-timezone(xs:dateTime($possibleDate), implicit-timezone())
    else
      xs:dateTime($possibleDate)
};

declare private function dateparser:adjustHourForMeridiem(
  $hourString as xs:string,
  $meridiemString as xs:string
) as xs:string
{
  if (starts-with($meridiemString, "a") or starts-with($meridiemString, "A")) then
    if ($hourString eq "12") then
      "00"
    else
      $hourString
  else
    if ($hourString eq "12") then
      $hourString
    else
      xs:string(xs:integer($hourString) + 12)
};

declare private function dateparser:extractLocationFromAnalyzedString(
  $part as xs:string,
  $format as element(format)
) as xs:integer?
{
  let $element := $format/*[local-name(.) = $part]
  where exists($element)
  return count($element/preceding-sibling::*[not(local-name(.) = ("whitespace", "string"))]) + 1
};

declare private function dateparser:processYear(
  $year as xs:string?
) as xs:string?
{
  if ($year castable as xs:integer) then
    if (xs:integer($year) < 100) then
      if (xs:integer($year) > 50) then
        concat("19", xs:string(xs:integer($year)))
      else if (xs:integer($year) = 0) then
        "1900"
      else
        concat("20", dateparser:stringPad("0", 2 - string-length($year)), $year)
    else if (xs:integer($year) >= 100 and xs:integer($year) < 200) then
      (: 102 = 2002, thanks Java :)
      xs:string(1900 + xs:integer($year))
    else if (xs:integer($year) > 9999) then
      "9999"
    else
      $year
  else
    $year
};

(:
  Takes in a 'month' as a string and returns it as a number.  For example:
    "1" -> "01"
    "01" -> "01"
    "february" -> "02"
    "feb" -> "02"
:)
declare private function dateparser:processMonth(
  $month as xs:string?
) as xs:string
{
  let $month := lower-case($month)
  let $parsedMonth := (
    let $months := (
      "jan", "january", "enero", "janvier", "januar", "gennaio",
      "feb", "february", "febrero", "fevrier", "februar", "febbraio",
      "mar", "march", "marzo", "mars", "marz", "marzo",
      "apr", "april", "abril", "avril", "april", "aprile",
      "may", "may", "mayo", "mai", "mai", "maggio",
      "jun", "june", "junio", "juin", "juni", "giugno",
      "jul", "july", "julio", "juillet", "juli", "luglio",
      "aug", "august", "agosto", "aout", "august", "agosto",
      "sep", "september", "septiembre", "septembre", "september", "settembre",
      "oct", "october", "octubre", "octobre", "oktober", "ottobre",
      "nov", "november", "noviembre", "novembre", "november", "novembre",
      "dec", "december", "diciembre", "decembre", "dezember", "dicembre"
    )
    let $monthSansDiacritics := xdmp:diacritic-less($month)
    for $i at $pos in $months
    let $pos := ceiling($pos div 6)
    where $i = $monthSansDiacritics
    return concat(dateparser:stringPad("0", 2 - string-length(string($pos))), $pos)
  )[1]
  return
    if (exists($parsedMonth)) then
      $parsedMonth
    else
      dateparser:expandTwoDigits($month, "01")
};

declare private function dateparser:processDay(
  $day as xs:string?
) as xs:string
{
  dateparser:expandTwoDigits(
    if (matches($day, "^(\d?\d)(st|nd|rd|th)$")) then
      replace($day, "st|nd|rd|th", "")
    else
      $day,
    "01")
};

declare private function dateparser:processZone(
  $zone as xs:string?
) as xs:string
{
  let $zone := replace($zone, "'", "")
  return
    if(matches($zone, "[+-]\d\d\d\d")) then
      concat(substring($zone, 0, 4), ":", substring($zone, 4))
    else if(matches($zone, "\w\w\w")) then
      dateparser:timezoneLookup($zone)
    else
      ""
};

declare private function dateparser:stringPad(
  $string as xs:string,
  $count as xs:integer
) as xs:string
{
  string-join(for $i in (1 to $count) return $string, "")
};

declare private function dateparser:timezoneLookup(
  $tz as xs:string
) as xs:string
{
  let $tz := upper-case($tz)
  return
    if ($tz = "MIT") then "-11:00" else
    if ($tz = "HST") then "-10:00" else
    if ($tz = "AST") then "-09:00" else
    if ($tz = "PST") then "-08:00" else
    if ($tz = "MST") then "-07:00" else
    if ($tz = "PNT") then "-07:00" else
    if ($tz = "CST") then "-06:00" else
    if ($tz = "EST") then "-05:00" else
    if ($tz = "IET") then "-05:00" else
    if ($tz = "PRT") then "-04:00" else
    if ($tz = "CNT") then "-03:00" else
    if ($tz = "AGT") then "-03:00" else
    if ($tz = "BET") then "-03:00" else
    if ($tz = "GMT") then "+00:00" else
    if ($tz = "UCT") then "+00:00" else
    if ($tz = "UTC") then "+00:00" else
    if ($tz = "WET") then "+00:00" else
    if ($tz = "CET") then "+01:00" else
    if ($tz = "ECT") then "+01:00" else
    if ($tz = "MET") then "+01:00" else
    if ($tz = "ART") then "+02:00" else
    if ($tz = "CAT") then "+02:00" else
    if ($tz = "EET") then "+02:00" else
    if ($tz = "EAT") then "+03:00" else
    if ($tz = "NET") then "+04:00" else
    if ($tz = "PLT") then "+05:00" else
    if ($tz = "IST") then "+05:00" else
    if ($tz = "BST") then "+06:00" else
    if ($tz = "VST") then "+07:00" else
    if ($tz = "CTT") then "+08:00" else
    if ($tz = "PRC") then "+08:00" else
    if ($tz = "JST") then "+09:00" else
    if ($tz = "ROK") then "+09:00" else
    if ($tz = "ACT") then "+09:00" else
    if ($tz = "AET") then "+10:00" else
    if ($tz = "SST") then "+11:00" else
    if ($tz = "NST") then "+12:00" else
    if ($tz = "PDT") then "-07:00" else
    if ($tz = "MDT") then "-06:00" else
    if ($tz = "CDT") then "-05:00" else
    if ($tz = "EDT") then "-04:00" else
    ""
};

declare private function dateparser:expandTwoDigits(
  $num as xs:string?,
  $default as xs:string
) as xs:string
{
  (:
   : The first check is designed to see if the value is some bogus input, eg: 2007/foo/bar.
   : If $num is less than 0, isn't a number or is empty, return "01".
   : Else pad $num with 0's if need be.
   :)
  if (exists($num) and $num != "" and not($num castable as xs:integer)) then
    "NAN"
  else if (empty($num) or not($num castable as xs:integer) or xs:integer($num) <= 0) then
    $default
  else
    concat(dateparser:stringPad("0", 2 - string-length($num)), $num)
};