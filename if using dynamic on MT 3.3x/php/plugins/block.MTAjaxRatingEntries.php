<?
function smarty_block_MTAjaxRatingEntries($args, $content, &$ctx, &$repeat) {
	$args['type'] = 'entry';
	@require_once("block.MTAjaxRatingList.php");
	$content = smarty_block_MTAjaxRatingList($args, $content, $ctx, $repeat);
	return $content;
}

?>
