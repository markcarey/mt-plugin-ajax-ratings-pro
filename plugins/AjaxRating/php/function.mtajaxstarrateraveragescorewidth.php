<?php
function smarty_function_MTAjaxStarRaterAverageScoreWidth($args, &$ctx) {
    $obj_type = $args['type'] ? $args['type'] : 'entry';
    $blog_id = $ctx->stash("blog_id");
    $config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
    $unit_width = $config['unit_width'];
    $units = $config[$obj_type.'_max_points'];
    if (!$units) { $units = $args['max_points'] ? $units = $args['max_points'] : 5; }
    $args['show'] = 'avg_score';
    @require_once("function.mtajaxrating.php");
    $avg_score = smarty_function_MTAjaxRating($args, $ctx);
    $avg_score_width = ($avg_score / $units) * ($unit_width * $units);
    return $avg_score_width;
}
?>
