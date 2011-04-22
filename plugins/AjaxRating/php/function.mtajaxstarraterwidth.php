<?php
function smarty_function_MTAjaxStarRaterWidth($args, &$ctx) {
    $obj_type = $args['type'] ? $args['type'] : 'entry';
    $blog_id = $ctx->stash("blog_id");
    $config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
    $unit_width = $config['unit_width'] ? $config['unit_width'] : 30;
    $units = $config[$obj_type.'_max_points'];
    if (!$units) { $units = $args['max_points'] ? $units = $args['max_points'] : 5; }
    $rater_length = $units * $unit_width;
    return $rater_length;
}
?>
