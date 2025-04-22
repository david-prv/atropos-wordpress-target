<?php

ini_set('display_errors','Off');
ini_set('error_reporting', E_ALL );

include('/var/www/html/wp-load.php');

$exclude = [
        // Builtin WordPress
        "wp_ajax_save-widget",
        "wp_ajax_widgets-order",
        "wp_ajax_add-category",
        "wp_ajax_add-post_tag",
        "wp_ajax_add-nav_menu",
        "wp_ajax_add-link_category",
        "wp_ajax_add-post_format",
        "wp_ajax_add-wp_theme",
        "wp_ajax_add-wp_template_part_area",
        "wp_ajax_add-wp_pattern_category",

        // Redis Object Cache
        "wp_ajax_roc_dismiss_notice",
        "wp_ajax_roc_flush_cache"
];

foreach ($GLOBALS['wp_filter'] as $k => $v) {
        if ((substr($k, 0, 8) == "wp_ajax_") && (!in_array($k, $exclude))) echo $k . "\n";
}
