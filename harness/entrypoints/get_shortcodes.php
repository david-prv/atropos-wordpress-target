<?php

ini_set('display_errors','Off');
ini_set('error_reporting', E_ALL );

include('/var/www/html/wp-load.php');

$exclude = [
	"wp_caption",
	"caption",
	"gallery",
	"playlist",
	"audio",
	"video",
	"embed"
];

foreach ($shortcode_tags as $k => $v) {
        if(!in_array($k, $exclude)) echo $k . "\n";
}
