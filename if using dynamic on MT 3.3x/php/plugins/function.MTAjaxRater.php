<?php
function smarty_function_MTAjaxRater($args, &$ctx) {
	$rater_type = $args['rater_type'] ? $args['rater_type'] : 'star';
	$obj_type = $args['type'] ? $args['type'] : $ctx->stash('obj_type');
	if (!$obj_type) {
		if ($ctx->stash('comment')) {
			$obj_type = 'comment';
		} else {
			$obj_type = 'entry';
		}
	}
	if ($obj_type == 'trackback') { $obj_type = 'ping'; }
	$object = $ctx->stash($obj_type);

	if ($obj_type == 'comment') {
		$author_id = $object['commenter_id'] ? $object['commenter_id'] : 0;
	} elseif ($obj_type == 'entry') {
		$author_id = $object['author_id'];
	} else {
		$author_id = 0;
	}

	$blog_id = $ctx->stash("blog_id");
	$avg_score = 0;
	$total_score = 0;
	$vote_count = 0;
	if ($obj_type == 'ping') {
		$obj_id = $object['tbping_id'];
	} else {
		$obj_id = $object[$obj_type.'_id'];
	}
	if ($args['id']) { $obj_id = $args['id']; }
	$vote_args['obj_type'] = $obj_type;
	$vote_args['obj_id'] = $obj_id;
	list($votesummary) = $ctx->mt->db->load('ajaxrating_votesummary',$vote_args);
	if ($votesummary) {
		$avg_score = $votesummary['ajaxrating_votesummary_avg_score'];
		$vote_count = $votesummary['ajaxrating_votesummary_vote_count'];
		$total_score = $votesummary['ajaxrating_votesummary_total_score'];
	}
	if ($rater_type == 'star') {
		$config = $ctx->mt->db->fetch_plugin_config('Ajax Rating Pro', 'blog:' . $blog_id);
		$unit_width = $config['unit_width'];
		$units = $config[$obj_type.'_max_points'];
		if (!$units) { $units = $args['max_points'] ? $units = $args['max_points'] : 5; }
		$rater_length = $units * $unit_width;
		$star_width = number_format(($avg_score / $units * $rater_length),0);
		$html = <<<HTML
<div id="rater$obj_type$obj_id">
			<ul id="rater_ul$obj_type$obj_id" class="unit-rating" style="width:{$rater_length}px;">
		<li class="current-rating" id="rater_li$obj_type$obj_id" style="width:{$star_width}px;">Currently $avg_score/$units</li>
HTML;
		for($star = 1; $star <= $units; $star++) {
			$html .= <<<HTML
		<li><a href="#" title="$star out of $units" class="r$star-unit rater" onclick="pushRating('$obj_type',$obj_id,$star,$blog_id,$total_score,$vote_count,$author_id); return(false);">$star</a></li>
HTML;
		}
		$html .= <<<HTML
		</ul>
<span class="thanks" id="thanks$obj_type$obj_id"></span>
</div>
HTML;
	} elseif ($rater_type == 'onclick_js') {
		$points = $args['points'] ? $args['points'] : 1;
		$html = "pushRating('$obj_type',$obj_id,$points,$blog_id,$total_score,$vote_count,$author_id); return(false);";
	} else {
		$static_path = $ctx->tag('StaticWebPath', $args);
		$report_icon = '';
		if ($args['report_icon']) {
			$report_icon = <<<HTML
			<a href="#" title="Report this comment" onclick="reportComment($obj_id); return(false);"><img src="{$static_path}plugins/AjaxRating/images/report.gif" alt="Report this comment" /></a>
HTML;
		}
		$html = <<<HTML
<span id="thumb$obj_type$obj_id">
<a href="#" title="Vote up" onclick="pushRating('$obj_type',$obj_id,1,$blog_id,$total_score,$vote_count,$author_id); return(false);"><img src="{$static_path}plugins/AjaxRating/images/up.gif" alt="Vote up" /></a> <a href="#" title="Vote down" onclick="pushRating('$obj_type',$obj_id,-1,$blog_id,$total_score,$vote_count,$author_id); return(false);"><img src="{$static_path}plugins/AjaxRating/images/down.gif" alt="Vote down" /></a> $report_icon
</span><span class="thanks" id="thanks$obj_type$obj_id"></span>
HTML;
	}
	return $html;
}
?>
