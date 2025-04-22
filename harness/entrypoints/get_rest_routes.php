<?php

ini_set('display_errors','Off');
ini_set('error_reporting', E_ALL );

include('/var/www/html/wp-load.php');

function startswith($text, $prefix ) {
  return strpos($text, $prefix) === 0;
}

$exclude = [
	"/wp-block-editor/v1",
	"/wp-block-editor/v1/url-details",
	"/wp-block-editor/v1/export",
	"/wp-block-editor/v1/navigation-fallback"
];

foreach (rest_get_server()->get_routes() as $key=>$handlers) {
	if (
			$key == '/' ||
			startswith($key, "/batch/") ||
			startswith($key, "/oembed/") ||
			startswith($key, "/wp/") ||
			startswith($key, "/wp-site-health/")) {
		continue;
	}
	foreach($handlers as $handler_key => $handler) {
		if(!in_array($key, $exclude)) echo $key . "@" . $handler_key . "\n";
	}
}
