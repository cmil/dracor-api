xquery version "3.1";

(:~
 : Module for calculating and updating corpus stats.
 :)
module namespace stats = "http://dracor.org/ns/exist/stats";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace config = "http://dracor.org/ns/exist/config" at "config.xqm";
import module namespace dutil = "http://dracor.org/ns/exist/util" at "util.xqm";

declare namespace trigger = "http://exist-db.org/xquery/trigger";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:get-stats-url($url as xs:string) as xs:string {
  replace($url, $config:data-root, $config:stats-root)
};

(:~
 : Calculate network metrics for single play
 :
 : @param $url URL of the TEI document
:)
declare function stats:get-network-metrics($url as xs:string) {
  let $parts := tokenize($url, '/')
  let $playname := tokenize($parts[last()], '\.')[1]
  let $corpusname := $parts[last() - 1]

  let $info := dutil:play-info($corpusname, $playname)
  let $payload := serialize(
    $info,
    <output:serialization-parameters>
      <output:method>json</output:method>
    </output:serialization-parameters>
  )

  let $response := httpclient:post(
    $config:metrics-server,
    $payload,
    false(),
    <headers>
      <header name="Content-Type" value="application/json"/>
    </headers>
  )
  let $json := util:base64-decode(
    $response//httpclient:body[@type="binary"]
    [@encoding="Base64Encoded"]/string(.)
  )
  let $metrics := parse-json($json)

  return
    <network>
      {for $k in map:keys($metrics) return element {$k} {$metrics($k)}}
    </network>
};

(:~
 : Calculate stats for single play
 :
 : @param $url URL of the TEI document
:)
declare function stats:calculate($url as xs:string) {
  let $separator := '\W+'
  let $doc := doc($url)
  let $text-count := count(tokenize($doc//tei:text, $separator))
  let $stage-count := count(tokenize(string-join($doc//tei:stage, ' '), $separator))
  let $sp-count := count(tokenize(string-join($doc//tei:sp, ' '), $separator))
  return <stats updated="{current-dateTime()}">
    <text>{$text-count}</text>
    <stage>{$stage-count}</stage>
    <sp>{$sp-count}</sp>
    {stats:get-network-metrics($url)}
  </stats>
};

(:~
 : Update stats for single play
 :
 : @param $url URL of the TEI document
:)
declare function stats:update($url as xs:string) {
  let $stats := stats:calculate($url)
  let $stats-url := local:get-stats-url($url)
  let $resource := tokenize($stats-url, '/')[last()]
  let $collection := replace($stats-url, '/[^/]+$', '')

  let $c := xdb:create-collection('/', $collection)
  let $log := util:log('info', ('Stats update: ', $stats-url))

  return xdb:store($collection, $resource, $stats)
};

declare function trigger:after-create-document($url as xs:anyURI) {
  stats:update($url)
};

declare function trigger:after-update-document($url as xs:anyURI) {
  stats:update($url)
};

declare function trigger:after-delete-document($url as xs:anyURI) {
  let $stats-url := local:get-stats-url($url)
  let $resource := tokenize($stats-url, '/')[last()]
  let $collection := replace($stats-url, '/[^/]+$', '')
  return xmldb:remove($collection, $resource)
};
