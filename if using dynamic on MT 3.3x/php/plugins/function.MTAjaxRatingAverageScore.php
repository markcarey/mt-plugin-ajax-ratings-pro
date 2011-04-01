<?php
function smarty_function_MTAjaxRatingAverageScore($args, &$ctx) {
	$args['show'] = 'avg_score';
	@require_once("function.MTAjaxRating.php");
	$content = smarty_function_MTAjaxRating($args, $ctx);
	return $content;
}
?>
