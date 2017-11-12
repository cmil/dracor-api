xquery version "3.1";

module namespace api = "http://dracor.org/ns/exist/api";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace config = "http://dracor.org/ns/exist/config" at "config.xqm";
import module namespace dutil = "http://dracor.org/ns/exist/util" at "util.xqm";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace repo = "http://exist-db.org/xquery/repo";
declare namespace expath = "http://expath.org/ns/pkg";
declare namespace json = "http://www.w3.org/2013/XSL/json";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace jsn="http://www.json.org";

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
  %rest:path("/dracor/{$corpus}/index")
  %rest:produces("application/json")
  %output:media-type("application/json")
  %output:method("json")
function api:index($corpus) {
  let $corpora := xdb:document("/db/apps/dracor/corpora.xml")
  let $title := $corpora//corpus[name=$corpus]/title/text()
  let $collection := concat($config:data-root, "/", $corpus)
  return
  <index>
    {
      for $tei in collection($collection)//tei:TEI
      let $filename := tokenize(base-uri($tei), "/")[last()]
      let $id := tokenize($filename, "\.")[1]
      let $subtitle := $tei//tei:titleStmt/tei:title[@type='sub'][1]/normalize-space()
      return
        <dramas json:array="true">
          <id>{$id}</id>
          <title>
            {$tei//tei:titleStmt/tei:title[1]/normalize-space() }
          </title>
          {if ($subtitle) then <subtitle>{$subtitle}</subtitle> else ''}
          <author key="{$tei//tei:titleStmt/tei:author/@key}">
            <name>{$tei//tei:titleStmt/tei:author/string()}</name>
          </author>
          <source>
            {$tei//tei:sourceDesc/tei:bibl[@type="digitalSource"]/tei:name/string()}
          </source>
        </dramas>
    }
    <title>{$title}</title>
  </index>
};

declare
  %rest:GET
  %rest:path("/dracor/{$corpus}/{$drama}/info")
  %rest:produces("application/json")
  %output:media-type("application/json")
  %output:method("json")
function api:drama-info($corpus, $drama) {
  let $collection := concat($config:data-root, "/", $corpus)
  let $file := concat($config:data-root, "/", $corpus, "/", $drama, ".xml")
  let $doc := xdb:document($file)
  let $tei := $doc//tei:TEI
  let $subtitle := $tei//tei:titleStmt/tei:title[@type='sub'][1]/normalize-space()
  let $cast := dutil:distinct-speakers($doc//tei:body)
  return
    <info>
      <id>{$drama}</id>
      <corpus>{$corpus}</corpus>
      <file>{$file}</file>
      <title>
        {$tei//tei:titleStmt/tei:title[1]/normalize-space()}
      </title>
      {if ($subtitle) then <subtitle>{$subtitle}</subtitle> else ''}
      <author key="{$tei//tei:titleStmt/tei:author/@key}">
        <name>{$tei//tei:titleStmt/tei:author/string()}</name>
      </author>
      {
        for $id in $cast
        let $name := $doc//tei:particDesc//(
          tei:person[@xml:id=$id]/tei:persName[1] |
          tei:persName[@xml:id=$id]
        )/text()
        return
        <persons  json:array="true">
          <id>{$id}</id>
          {if($name) then <name>{$name}</name> else ()}
        </persons>
      }
      {
        for $segment in $tei//tei:div[tei:sp]
        let $heads := $segment/(ancestor::tei:div/tei:head|tei:head)
        return
        <segments json:array="true">
          <type>{$segment/@type/string()}</type>
          {if ($heads) then <title>{string-join($heads, ' | ')}</title> else ()}
          {
            for $sp in dutil:distinct-speakers($segment)
            return
            <speakers json:array="true">{$sp}</speakers>
          }
        </segments>
      }
    </info>
};

declare
  %rest:GET
  %rest:path("/dracor/{$corpus}/word-frequencies/{$elem}")
  %rest:produces("application/xml", "text/xml")
function api:word-frequencies-xml($corpus, $elem) {
  let $collection := concat($config:data-root, "/", $corpus)
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
  let $collection := concat($config:data-root, "/", $corpus)
  let $terms := local:get-index-keys($collection, $elem)
  for $t in $terms/term
  order by number($t/@count) descending
  return concat($t/@name, ", ", $t/@count, ", ", $t/@docs, "&#10;")
};
