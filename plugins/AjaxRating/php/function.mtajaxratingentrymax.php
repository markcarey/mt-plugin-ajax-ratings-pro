<?php
function smarty_function_MTAjaxRatingEntryMax($args, &$ctx) {
    $blog_id = $ctx->stash("blog_id");
    $config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
    return $config['entry_max_points'];
}
?>
