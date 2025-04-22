<?php

ini_set('display_errors','Off');
ini_set('error_reporting', E_ALL );

foreach(explode("; ", getenv("HTTP_COOKIE")) as $cookie) {
    $key = explode("=", $cookie)[0];
    $value = explode("=", $cookie)[1];
    $_COOKIE[$key] = str_replace("%7C", "|", $value);
}

define('WP_ADMIN', true);

include('/var/www/html/wp-load.php');
include('/var/www/html/wp-admin/includes/admin.php');
include('/var/www/html/wp-admin/menu.php');

$exclude = [
	"settings_page_redis-cache"
];

foreach($_registered_pages as $key => $value) {
    if(!in_array($key, $exclude)) echo $key . "\n";
}
