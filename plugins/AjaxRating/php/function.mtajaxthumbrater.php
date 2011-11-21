<?php
function smarty_function_MTAjaxThumbRater($args, &$ctx) {
    $args['rater_type'] = 'thumb';
    $html = $ctx->tag('AjaxRater', $args);
    return $html;
}
?>
