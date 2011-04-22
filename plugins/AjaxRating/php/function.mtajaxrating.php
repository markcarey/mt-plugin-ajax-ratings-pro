<?php
function smarty_function_MTAjaxRating($args, &$ctx) {
    $obj_type = $args['type'] ? $args['type'] : $ctx->stash('obj_type');
    if (!$obj_type) {
        if ($ctx->stash('comment')) {
            $obj_type = 'comment';
        } else {
            $obj_type = 'entry';
        }
    }
    $object = $ctx->stash($obj_type);

    $show = $args['show'] ? $args['show'] : 'total_score';

    if ($obj[$show]) {
        $rating = $object[$show];
    } else {
        $rating = $ctx->mt->db->get_var("SELECT ajaxrating_votesummary_".$show." FROM mt_ajaxrating_votesummary WHERE ajaxrating_votesummary_obj_id='".$object[$obj_type.'_id']."' AND ajaxrating_votesummary_obj_type='".$obj_type."'");
    }
    if (!$rating) {
        return 0;
    }
    return $rating;
}
?>
