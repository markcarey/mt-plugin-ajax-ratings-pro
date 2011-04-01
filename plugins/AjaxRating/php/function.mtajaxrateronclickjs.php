<?php
function smarty_function_MTAjaxRaterOnclickJS($args, &$ctx) {
	$args['rater_type'] = 'onclick_js';
    $html = $ctx->tag('AjaxRater', $args);
	return $html;
}
?>
