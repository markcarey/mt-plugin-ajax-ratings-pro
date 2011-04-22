<?
function smarty_block_MTAjaxRatingComments($args, $content, &$ctx, &$repeat) {
    $args['type'] = 'comment';
    @require_once("block.mtajaxratinglist.php");
    $content = smarty_block_MTAjaxRatingList($args, $content, $ctx, $repeat);
    return $content;
}

?>
