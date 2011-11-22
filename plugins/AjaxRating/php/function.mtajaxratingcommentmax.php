<?php
function smarty_function_MTAjaxRatingCommentMax($args, &$ctx) {
    $blog_id = $ctx->stash("blog_id");
    $config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
    return $config['comment_max_points'];
}
?>
