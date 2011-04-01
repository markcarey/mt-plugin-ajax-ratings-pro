<?php
function smarty_function_MTAjaxRatingDefaultThreshold($args, &$ctx) {
   $blog_id = $ctx->stash("blog_id");
   $config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
   $threshold = $config['comment_threshold'];
   if ($threshold == 'all') { $threshold = -9999; }
   return $threshold;
}
?>
