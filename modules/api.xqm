xquery version "3.1";

module namespace api = "http://dracor.org/ns/exist/api";

import module namespace config = "http://dracor.org/ns/exist/config" at "config.xqm";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace repo = "http://exist-db.org/xquery/repo";
declare namespace expath = "http://expath.org/ns/pkg";
declare namespace json = "http://www.w3.org/2013/XSL/json";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $api:base-collection := "/db/data/dracor";

declare
  %rest:GET
  %rest:path("/dracor")
  %rest:produces("application/json")
  %output:media-type("application/json")
  %output:method("json")
function api:darcor() {
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return
      <info>
        <x>
          <y>kfmsldk</y>
          <y>ksld</y>
        </x>
        <name>{$expath/expath:title/string()}</name>
        <version>{$expath/@version/string()}</version>
        <status>{$repo/repo:status/string()}</status>
      </info>
};

declare
  %rest:GET
  %rest:path("/info.xml")
  %rest:produces("application/xml")
function api:info-xml() {
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return
      <info>
        <name>{$expath/expath:title/string()}</name>
        <version>{$expath/@version/string()}</version>
        <status>{$repo/repo:status/string()}</status>
      </info>
};

declare
  %rest:GET
  %rest:path("/resources")
  %rest:produces("application/xml", "text/xml")
function api:resources() {
  rest:resource-functions()
};

declare function local:get-index-keys ($collection as xs:string, $elem as xs:string) {
  <terms element="{$elem}" collection="{$collection}">
    {
      util:index-keys(
        collection($collection)//tei:*[name() eq $elem], "",
        function($key, $count) {
          <term name="{$key}" count="{$count[1]}"docs="{$count[2]}" pos="{$count[3]}"/>
        },
        -1,
        "lucene-index"
      )
    }
  </terms>
};

declare
  %rest:GET
  %rest:path("/dracor/{$corpus}/word-frequencies/{$elem}")
  %rest:produces("application/xml", "text/xml")
function api:word-frequencies-xml($corpus, $elem) {
  let $collection := concat($api:base-collection, "/", $corpus)
  let $terms := local:get-index-keys($collection, $elem)
  return $terms
};

declare
  %rest:GET
  %rest:path("/dracor/{$corpus}/word-frequencies/{$elem}")
  %rest:produces("text/csv", "text/plain")
  %output:media-type("text/csv")
  %output:method("text")
function api:word-frequencies-csv($corpus, $elem) {
  let $collection := concat($api:base-collection, "/", $corpus)
  let $terms := local:get-index-keys($collection, $elem)
  for $t in $terms/term
  order by number($t/@count) descending
  return concat($t/@name, ", ", $t/@count, ", ", $t/@docs, "&#10;")
};
