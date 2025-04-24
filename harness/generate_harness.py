import os
import subprocess
import json

TEMPLATE_AJAX_ACTIONS = """<?php

if(!isset($_GET["fuzz_ajax_action"])) exit(1);

/* dynamic content here */

function process_input() {
    define('DOING_AJAX', true);
    define('WP_ADMIN', true);

    include('/var/www/html/wp-load.php');
    include('/var/www/html/wp-admin/includes/admin.php');

    $_SERVER['SCRIPT_FILENAME'] = "/var/www/html/wp-admin/admin-ajax.php";
    do_action("admin_init");
    do_action($_GET["fuzz_ajax_action"]);
}
"""

TEMPLATE_SHORTCODES = """<?php

if(!isset($_GET["fuzz_shortcode"])) exit(1);

/* dynamic content here */

function process_input() {
    include('/var/www/html/wp-load.php');
    global $shortcode_tags;
    echo call_user_func($shortcode_tags[$_GET["fuzz_shortcode"]]);
}
"""

TEMPLATE_REST_ROUTE = """<?php

if(!isset($_GET["fuzz_rest_route"])) exit(1);

/* dynamic content here */

function process_input() {
    $route = explode("@", $_GET["fuzz_rest_route"] ?? '');

    // this has to be here, AFTER we store the route above!
    include('/var/www/html/wp-load.php');

    function user_has_permission($result) {
        if ($result instanceof WP_Error) {
            return false;
        }

        return $result;
    }

    foreach (rest_get_server()->get_routes() as $key => $handlers) {
	if ((string) $key != $route[0]) {
   	    continue;
	}

	unset($_GET["fuzz_rest_route"]);
    	ksort($_GET);

    	foreach($handlers as $handler_key => $handler) {
	    	if ((string) $handler_key != $route[1]) {
		    	continue;
    		}

	    	$request = new WP_REST_Request($key);

		foreach($_GET as $arg_key => $arg_value) {
                    $request->set_param($arg_key, $arg_value);
                }

		if (
                    (!array_key_exists('permission_callback', $handler)) ||
                    (user_has_permission(call_user_func($handler['permission_callback'], $request)))) {
                    call_user_func($handler['callback'], $request);
	    	}
        }
    }
}
"""

TEMPLATE_MENU_ACTIONS = """<?php

if(!isset($_GET["fuzz_menu_action"])) exit(1);

/* dynamic content here */

function process_input() {
    define('WP_USE_THEMES', false);
    define('WP_ADMIN', true);

    include('/var/www/html/wp-load.php');
    include('/var/www/html/wp-admin/includes/admin.php');

    do_action('init');
    do_action('admin_init');
    do_action('admin_menu');

    do_action($_GET["fuzz_menu_action"]);
}
"""

ENTRYPOINTS = {
    "get_ajax_actions.php": {
        "output": "do_ajax_action.php",
        "type": "action",
    },
    "get_shortcodes.php": {
        "output": "do_shortcode.php",
        "type": "shortcode",
    },
    "get_rest_routes.php": {
        "output": "do_rest_route.php",
        "type": "rest",
    },
    "get_menu_actions.php": {
        "output": "do_menu_action.php",
        "type": "menu",
    },
}

HARNESS_DIR = "/var/www/html/wp-content/plugins/harness"
ENTRYPOINTS_DIR = os.path.join(HARNESS_DIR, "entrypoints")
BROWSER_DATA_PATH = os.path.join(HARNESS_DIR, "browser_data.json")

def load_browser_data():
    try:
        with open(BROWSER_DATA_PATH, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading browser data: {e}")
        return {"SERVER": {}, "COOKIE": {}}

browser_data = load_browser_data()

def get_items_from_php(script_path):
    try:
        env = os.environ.copy()

        cookie_header = "; ".join(f"{k}={v}" for k, v in browser_data.get("COOKIE", {}).items())
        env["HTTP_COOKIE"] = cookie_header

        for k, v in browser_data.get("SERVER", {}).items():
            env_var = f"HTTP_{k}" if not k.startswith("HTTP_") and k not in env else k
            if isinstance(v, (int, float)):
                v = str(v)
            env[env_var] = v

        output = subprocess.check_output(["php", script_path], env=env, text=True)
        print(output)
        items = [line.strip() for line in output.splitlines() if line.strip()]
        return items
    except subprocess.CalledProcessError as e:
        print(f"Error running PHP script {script_path}: {e}")
        return []


def generate_action_file(actions, output_path):
    dynamic_code = ""
    for action in actions:
        dynamic_code += f"""if ($_GET["fuzz_ajax_action"] == "{action}") {{
    process_input();
    return;
}}

"""
    php_code = TEMPLATE_AJAX_ACTIONS.replace("/* dynamic content here */", dynamic_code.strip())
    with open(output_path, "w") as f:
        f.write(php_code)
    print(f"Generated {output_path}")


def generate_shortcode_file(shortcodes, output_path):
    dynamic_code = ""
    for shortcode in shortcodes:
        dynamic_code += f"""if ($_GET["fuzz_shortcode"] == "{shortcode}") {{
    process_input();
    return;
}}

"""
    php_code = TEMPLATE_SHORTCODES.replace("/* dynamic content here */", dynamic_code.strip())
    with open(output_path, "w") as f:
        f.write(php_code)
    print(f"Generated {output_path}")


def generate_rest_file(routes, output_path):
    dynamic_code = ""
    for route in routes:
        dynamic_code += f"""if ($_GET["fuzz_rest_route"] == "{route}") {{
    process_input();
    return;
}}

"""
    php_code = TEMPLATE_REST_ROUTE.replace("/* dynamic content here */", dynamic_code.strip())
    with open(output_path, "w") as f:
        f.write(php_code)
    print(f"Generated {output_path}")


def generate_menu_action_file(actions, output_path):
    dynamic_code = ""
    for action in actions:
        dynamic_code += f"""if ($_GET["fuzz_menu_action"] == "{action}") {{
    process_input();
    return;
}}

"""
    php_code = TEMPLATE_MENU_ACTIONS.replace("/* dynamic content here */", dynamic_code.strip())
    with open(output_path, "w") as f:
        f.write(php_code)
    print(f"Generated {output_path}")


def main():
    for entrypoint_script, meta in ENTRYPOINTS.items():
        script_path = os.path.join(ENTRYPOINTS_DIR, entrypoint_script)
        output_path = os.path.join(HARNESS_DIR, meta["output"])
        item_type = meta["type"]

        items = get_items_from_php(script_path)
        if not items:
            print(f"No items found in {script_path}, skipping.")
            continue

        if item_type == "action":
            generate_action_file(items, output_path)
        elif item_type == "shortcode":
            generate_shortcode_file(items, output_path)
        elif item_type == "rest":
            generate_rest_file(items, output_path)
        elif item_type == "menu":
            generate_menu_action_file(items, output_path)
        else:
            print(f"Unknown type '{item_type}' for {entrypoint_script}")


if __name__ == "__main__":
    main()
