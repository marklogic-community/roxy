xquery version "1.0-ml";

module namespace rewriter = "http://marklogic.com/roxy/rewriter";

import module namespace conf = "http://marklogic.com/rest-api/endpoints/config"
  at "/MarkLogic/rest-api/endpoints/config.xqy";
import module namespace rest = "http://marklogic.com/appservices/rest"
  at "/MarkLogic/appservices/utils/rest.xqy";
import module namespace eput = "http://marklogic.com/rest-api/lib/endpoint-util"
  at "/MarkLogic/rest-api/lib/endpoint-util.xqy";

declare variable $RULE-SERVER-FIELD := "roxy:rewrite-rules";

(: This is a hack, but allows us to maintain one rule set endpoints and rewriter,
    while pushing the finer-grained error handling to the endpoint level. :)
declare function rewriter:rewrite-rules(
) as map:map
{
  let $old-rules := eput:get-rest-options()
  return
    if (exists($old-rules))
    then $old-rules
    else
      let $all-methods := ("GET","POST","PUT","DELETE","HEAD","OPTIONS")
      let $new-rules   := map:map()
      let $unsupported := map:map()
      let $rules :=
        let $r := xdmp:get-server-field($RULE-SERVER-FIELD)
        let $r :=
          if ($r) then
            $r
          else (
            xdmp:set-server-field($RULE-SERVER-FIELD,
              for $f in xdmp:functions()
              let $qname := fn:function-name($f)
              where fn:prefix-from-QName($qname) eq "conf" and fn:matches(fn:local-name-from-QName($qname), "get.*-rule.*")
              return xdmp:apply($f)
            ),
            xdmp:get-server-field($RULE-SERVER-FIELD)
          )
        return $r
      return (
        for $rule in $rules
        let $endpoint   := $rule/@endpoint/string(.)
        (: Note: depends on document order in rule :)
        let $uri-params := $rule/rest:uri-param/@name/string(.)
        let $methods    := $rule/rest:http/@method/tokenize(string(.)," ")
        for $match in $rule/@fast-match/tokenize(string(.), "\|")
        return (
          for $method in $methods
          return map:put($new-rules, $method||$match, ($endpoint,$uri-params)),

          let $candidates :=
            let $candidate-methods := map:get($unsupported,$match)
            return
              if (exists($candidate-methods))
              then $candidate-methods
              else $all-methods
          return map:put(
            $unsupported, $match, $candidates[not(. = $methods)]
          )
        ),

        for $match in map:keys($unsupported)
        for $method in map:get($unsupported,$match)
        return map:put(
          $new-rules,
          $method||$match,
          "/MarkLogic/rest-api/endpoints/unsupported-method.xqy"
        ),

        eput:set-rest-options($new-rules),
        $new-rules
      )
};

declare function rewriter:rewrite(
    $method   as xs:string,
    $uri      as xs:string,
    $old-path as xs:string
) as xs:string?
{
  let $rules      := rewriter:rewrite-rules()
  (: skip the empty step before the initial / :)
  let $raw-steps  := subsequence(tokenize($old-path,"/"), 2)
  let $raw-count  := count($raw-steps)
  (: check for an empty step after a trailing / :)
  let $extra-step := (subsequence($raw-steps,$raw-count,1) eq "")
  let $step-count :=
    if ($extra-step)
    then $raw-count - 1
    else $raw-count
  let $steps      :=
    if ($step-count eq 0)
    then ()
    else if ($extra-step)
    then subsequence($raw-steps, 1, $step-count)
    else $raw-steps
  (: generate the key for lookup in the rules map :)
  let $key        :=
    (: no rule :)
    if ($step-count eq 1)
    then ()
    (: default rule :)
    else if ($step-count eq 0)
    then ""
    else
      let $first-step := subsequence($steps,1,1)
      return
      (: as in /content/help :)
      if ($first-step eq "content")
      then ($first-step,"*")
      else if (not($first-step = ("v1","LATEST")))
      (: no rule :)
      then ()
      else
        let $second-step := subsequence($steps,2,1)
        return
        (: as in /v1/documents :)
        if ($step-count eq 2)
        then ("*",$second-step)
        else
          let $third-step := subsequence($steps,3,1)
          return
          if ($second-step = ("ext"))
          then
          ("*",$second-step,"**")
          else if ($second-step = ("config","alert","graphs")) then
            (: as in /v1/config/namespaces :)
            if ($step-count eq 3)
            then ("*", $second-step, $third-step)
            (: /v1/config/options/NAME or /v1/config/options/NAME/SUBNAME :)
            else if ($step-count le 5)
            then ("*", $second-step, $third-step, (4 to $step-count) ! "*")
            else ()
          (: as in /v1/transactions/TXID :)
          else if ($step-count eq 3)
          then ("*", $second-step, "*")
          (: catch all :)
          else if ($step-count le 5)
          then ("*", $second-step, $third-step, (4 to $step-count) ! "*")
          (: no rule :)
          else ()
  let $key-method :=
    if ($method eq "POST" and starts-with(
      head(xdmp:get-request-header("content-type")), "application/x-www-form-urlencoded"
      ))
    then "GET"
    else $method
  let $value :=
    if (empty($key)) then ()
    else map:get($rules, string-join(($key-method,$key), "/"))
  let $value-count := count($value)
  return
    (: fallback :)
    if ($value-count eq 0)
    then $uri
    else
      let $old-length := string-length($old-path)
      let $has-params := (string-length($uri) ne $old-length)
      let $new-path   :=
        (: append parameters to the rewritten path :)
        if ($has-params)
        then subsequence($value,1,1)||substring($uri,$old-length+1)
        else subsequence($value,1,1)
      return
        if ($value-count eq 1)
        then $new-path
        (: append parameters from rule to the rewritten path :)
        else string-join(
          (
            $new-path,
            let $step-names := subsequence($value,2)
            for $step-value at $i in
              for $j in 2 to count($key)
              let $place-holder := subsequence($key,$j,1)
              return
                if ($place-holder eq "*")
                then subsequence($steps,$j,1)
                else if ($place-holder eq "**")
                (: using raw-steps picks up trailing slash :)
                then string-join(subsequence($raw-steps,$j),"/")
                else ()

            return (
              if ($has-params or $i gt 1)
                then "&amp;"
                else "?",
              subsequence($step-names,$i,1),
              "=",
              $step-value
              )
            ),
          ""
          )
};
