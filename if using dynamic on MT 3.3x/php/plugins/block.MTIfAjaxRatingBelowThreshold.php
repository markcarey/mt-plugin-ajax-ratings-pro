<?php
function smarty_block_MTIfAjaxRatingBelowThreshold($args, $content, &$ctx, &$repeat) {
    if (!isset($content)) {
		$object = $ctx->stash('comment');
		$obj_type = 'comment';
		$blog_id = $ctx->stash("blog_id");
		$config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
		$comment_mode = $config['comment_mode'];
		if ($comment_mode == 1) {
			$show = 'total_score';
		} elseif ($comment_mode == 2) {
			$show = 'avg_score';
		}	else {
			$show = 'total_score';
			$obj_type = 'commentratingsturnedoff';
		}
		$rating = $ctx->mt->db->get_var("SELECT ajaxrating_votesummary_".$show." FROM mt_ajaxrating_votesummary WHERE ajaxrating_votesummary_obj_id='".$object[$obj_type.'_id']."' AND ajaxrating_votesummary_obj_type='".$obj_type."'");
		if (!$rating) {
       		$rating = 999999999;	
		}
		$default_threshold = $config['comment_threshold'];
		if ($default_threshold == 'all') { $rating = 999999999; }
        return $ctx->_hdlr_if($args, $content, $ctx, $repeat, $rating < $default_threshold);
    } else {
        return $ctx->_hdlr_if($args, $content, $ctx, $repeat);
    }
}
?>
