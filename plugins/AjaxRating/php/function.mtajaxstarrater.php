<?php
function smarty_function_MTAjaxStarRater($args, &$ctx) {
    $args['rater_type'] = 'star';
    $html = $ctx->tag('AjaxRater', $args);
    return $html;
}
?>
