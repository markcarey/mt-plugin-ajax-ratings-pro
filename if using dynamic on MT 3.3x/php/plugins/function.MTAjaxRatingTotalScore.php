<?php
function smarty_function_MTAjaxRatingTotalScore($args, &$ctx) {
	@require_once("function.MTAjaxRating.php");
	$content = smarty_function_MTAjaxRating($args, $ctx);
	return $content;
}
?>
