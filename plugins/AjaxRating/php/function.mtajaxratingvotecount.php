<?php
function smarty_function_MTAjaxRatingVoteCount($args, &$ctx) {
    $args['show'] = 'vote_count';
    @require_once("function.mtajaxrating.php");
    $content = smarty_function_MTAjaxRating($args, $ctx);
    return $content;
}
?>
