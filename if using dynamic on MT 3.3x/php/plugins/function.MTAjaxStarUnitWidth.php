<?php
function smarty_function_MTAjaxStarUnitWidth($args, &$ctx) {
	$blog_id = $ctx->stash("blog_id");
	$config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
	$unit_width = $config['unit_width'];
	if ($args['mult_by']) { $unit_width = $unit_width * $args['mult_by']; }
	return $unit_width;
}
?>
