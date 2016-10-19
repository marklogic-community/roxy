xquery version "1.0-ml";

module namespace frm = "http://marklogic.com/roxy/test/framework";

declare option xdmp:mapping "false";

(: Wrapper so that we can have an amp, allowing the default user to run this
 : test without getting extra privileges.
 :)
declare function frm:http-head($url, $options)
{
  xdmp:http-head($url, $options)
};

(: Wrapper so that we can have an amp, allowing the default user to run this
 : test without getting extra privileges.
 :)
declare function frm:http-delete($url, $options)
{
  xdmp:http-delete($url, $options)
};

(: Wrapper so that we can have an amp, allowing the default user to run this
 : test without getting extra privileges.
 :)
declare function frm:http-post($url, $options)
{
  xdmp:http-post($url, $options)
};

(: Wrapper so that we can have an amp, allowing the default user to run this
 : test without getting extra privileges.
 :)
declare function frm:http-put($url, $options)
{
  xdmp:http-put($url, $options)
};
