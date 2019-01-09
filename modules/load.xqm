xquery version "3.1";

(:~
 : Module providing function to load files from zip archives.
 :)
module namespace load = "http://dracor.org/ns/exist/load";

import module namespace config = "http://dracor.org/ns/exist/config"
  at "config.xqm";
import module namespace drdf = "http://dracor.org/ns/exist/rdf" at "rdf.xqm";
declare namespace compression = "http://exist-db.org/xquery/compression";
declare namespace util = "http://exist-db.org/xquery/util";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:entry-data(
  $path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*
) as item()? {
  if($data) then
    let $collection := $param[1]
    let $name := tokenize($path, "/")[last()]
    let $res := xmldb:store($collection, $name, $data)
    return $res
  else
    ()
};

declare function local:entry-filter(
  $path as xs:anyURI, $type as xs:string, $param as item()*
) as xs:boolean {
  (: filter paths using only files in the "tei" subdirectory  :)
  if ($type eq "resource" and contains($path, "/tei/"))
  then
    true()
  else
    false()
};

(:~
 : Load corpus from ZIP archive
 :
 : @param $name The name of the corpus
:)
declare function load:load-corpus($name as xs:string) {
  let $corpus := $config:corpora//corpus[name = $name]
  return if ($corpus) then
    <loaded>
    {
      for $doc in load:load-archive($corpus/name, $corpus/archive)
      return <doc>{$doc}</doc>
    }
    </loaded>
  else
    ()
};

(:~
 : Load XML files from ZIP archive
 :
 : @param $name The name of the sub collection to create
 : @param $archive-url The URL of a ZIP archive containing XML files
:)
declare function load:load-archive($name as xs:string, $archive-url as xs:string) {
  let $collection := xmldb:create-collection($config:data-root, $name)
  (: returns empty sequence when collection already available. so we set again: :)
  let $collection := $config:data-root || "/" || $name
  let $removals := for $res in xmldb:get-child-resources($collection)
                   return xmldb:remove($collection, $res)
  let $gitRepo := httpclient:get($archive-url, false(), ())
  let $zip := xs:base64Binary(
    $gitRepo//httpclient:body[@mimetype="application/zip"][@type="binary"]
    [@encoding="Base64Encoded"]/string(.)
  )

  return (
    compression:unzip(
      $zip,
      util:function(xs:QName("local:entry-filter"), 3),
      (),
      util:function(xs:QName("local:entry-data"), 4),
      ($collection)
    )
  )
};

(:~ Generates an RDF-Dump of the data; stores file in $config:rdf-root
  @author Ingo Börner
:)
declare function load:generateRDF() {
  let $rdf-collection := $config:data-root || "/rdf"

  let $plays := collection($config:data-root)//tei:TEI

  for $play in $plays return drdf:play-to-rdf($play)
    (: xmldb:store($rdf-collection, $rdf-filename, $rdf-data) :)
};
