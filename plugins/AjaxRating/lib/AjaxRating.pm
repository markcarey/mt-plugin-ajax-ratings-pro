#########################################################

package AjaxRating;

use strict;
use warnings;

use MT;
use MT::Plugin;
use AjaxRating::Vote;
use AjaxRating::VoteSummary;

use YAML::Tiny;

sub listing {
    my $ctx = shift;
    my $args = shift;
    my $res = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my %list_terms = ();
    my %list_args = ();
    my $blog_id = $ctx->stash('blog_id');

    # Pick which blog(s) to select from
    if (defined($args->{blogs})) {
        if ($args->{blogs} ne 'all') {
            $list_terms{'blog_id'} = $args->{blog_id};
        }
    } else {
        $list_terms{'blog_id'} = $ctx->stash('blog_id');
    }

    # Pick which field to use:
    $list_args{'start_val'} = 0;
    $list_args{'sort'} = 'total_score';
    if (defined($args->{sort_by})) {
        if ($args->{sort_by} eq 'votes') {
            $list_args{'sort'} = 'vote_count';
        } elsif ($args->{sort_by} eq 'average') {
            $list_args{'sort'} = 'avg_score';
            $list_args{'start_val'} = 0;
        }
    }

    # Pick Sort Direction
    $list_args{'direction'} = 'descend';
    if (defined($args->{sort_order})) {
        if ($args->{sort_order} eq 'ascend') {
            $list_args{'direction'} = 'ascend';
        }
    }

    # Limiting Number
    $list_args{'limit'} = 10;
    if (defined($args->{show_n})) {
        $list_args{'limit'} = $args->{show_n};
    }

    my $obj_type = $args->{type};
    if ($obj_type eq 'trackback') { $obj_type = 'ping'; }
    $list_terms{'obj_type'} = $obj_type;
    my $class;
    if ($obj_type eq 'ping') {
        $class = "MT::TBPing";
    } else {
        $class = "MT::\u$obj_type";
    }

    my $rating_class = "AjaxRating::VoteSummary";
    if ($args->{hot}) { $rating_class = "AjaxRating::HotObject"; }

    my @obj = $rating_class->load(\%list_terms, \%list_args);
    my $i = 0;
    my $n = $list_args{'limit'};
    my $vars = $ctx->{__stash}{vars} ||= {};
    foreach (@obj) {
        if (my $temp_obj = $class->load($_->obj_id)) {
            $i++;
            my $last;
            $last = 1 if $n && ($i >= $n);
            $last = 1 unless defined $obj[$i];
            $ctx->stash($obj_type, $temp_obj);
            my $blog = MT->model('blog')->load($temp_obj->blog_id);
            $ctx->stash('blog_id', $blog->id);
            $ctx->stash('blog', $blog);
            local $vars->{__first__} = $i == 1;
            local $vars->{__last__} = $last;
            local $vars->{__odd__} = ($i % 2) == 1;
            local $vars->{__even__} = ($i % 2) == 0;
            local $vars->{__counter__} = $i;
            defined(my $out = $builder->build($ctx, $tokens))
                or return $ctx->error($builder->errstr);
            $res .= $out;
        } else {
            $_->remove;
        }
    }
    $res;
}

sub listing_entries {
    my $ctx = shift;
    my $args = shift;
    $args->{type} = 'entry';
    listing($ctx, $args);
}

sub listing_comments {
    my $ctx = shift;
    my $args = shift;
    $args->{type} = 'comment';
    listing($ctx, $args);
}

sub listing_pings {
    my $ctx = shift;
    my $args = shift;
    $args->{type} = 'trackback';
    listing($ctx, $args);
}

sub listing_categories {
    my $ctx = shift;
    my $args = shift;
    $args->{type} = 'category';
    listing($ctx, $args);
}

sub listing_blogs {
    my $ctx = shift;
    my $args = shift;
    $args->{type} = 'blog';
    listing($ctx, $args);
}

sub listing_authors {
    my $ctx = shift;
    my $args = shift;
    $args->{type} = 'author';
    listing($ctx, $args);
}

sub listing_tags {
    my $ctx = shift;
    my $args = shift;
    $args->{type} = 'tag';
    listing($ctx, $args);
}

# Return the number of votes for each score number on an object.
sub listing_vote_distribution {
    my ( $ctx, $args, $cond ) = @_;

    # Get the object type and object ID (if not supplied through arguments).
    my $obj_type = $args->{type};
    if (!$obj_type) {
        if ($ctx->stash('comment')) {
            $obj_type = 'comment';
        } else {
            $obj_type = 'entry';
        }
    }
    if ($obj_type eq 'trackback') { $obj_type = 'ping'; }
    my $obj = $ctx->stash($obj_type);
    my $obj_id = $obj->id if $obj;
    if ($args->{id}) { $obj_id = $args->{id}; }

    # Load the summary for this object.
    my $votesummary = AjaxRating::VoteSummary->load({
        obj_type => $obj_type,
        obj_id   => $obj_id,
    });

    return '' if !$votesummary;

    # Read the saved YAML vote_distribution, and convert it into a hash.
    my $yaml = YAML::Tiny->read_string( $votesummary->vote_dist );
    
    # If there is no vote_distribution data, we need to create it. This should
    # have been done during the upgrade already.
    $yaml = _create_vote_distribution_data($votesummary) if !$yaml;

    # Load the entry_max_points or comment_max_points config setting 
    # (depending upon the object type), or just fall back to the value 10. 
    # 10 is used as a fallback elsewhere for the max points, so it's a safe
    # guess that it's good to use.
    my $plugin = MT->component('ajaxrating');
    my $max_points = $plugin->get_config_value(
        $votesummary->obj_type.'_max_points',
        'blog:'.$votesummary->blog_id
    ) || '10';
    
    # Make sure that all possible scores have been marked--at least with a 0.
    # The default value is set here (as opposed to in the foreach that outputs 
    # the values) so that different types of raters (which may have positive
    # or negative values) don't get confused.
    my $count = 1;
    while ( $count <= $max_points ) {
        $yaml->[0]->{$count} = '0' if !$yaml->[0]->{$count};
        $count++;
    }

    my $out = '';
    my $vars = $ctx->{__stash}{vars};
    $count = 0;

    # Put together the variables that can be used inside this loop.
    # <mt:Var name="score"> and <mt:Var name="vote"> are the important ones.
    foreach my $score ( sort keys %{$yaml->[0]} ) {
        local $vars->{'score'}       = $score;
        local $vars->{'vote'}        = $yaml->[0]->{$score};
        local $vars->{'__first__'}   = ( $count++ == 0 );
        local $vars->{'__last__'}    = ( $count == $yaml->[0] );
        local $vars->{'__odd__'}     = ($count % 2) == 1;
        local $vars->{'__even__'}    = ($count % 2) == 0;
        local $vars->{'__counter__'} = $count;

        defined( $out .= $ctx->slurp( $args, $cond ) ) or return;
    }
    return $out;
}

sub _create_vote_distribution_data {
    my ($votesummary) = @_;

    # Use the Vote Summary object to load the vote data for this object id 
    # and type.
    my $iter = MT->model('ajaxrating_vote')->load_iter({
        obj_id => $votesummary->obj_id,
        obj_type => $votesummary->obj_type,
    });

    # Build the hash of votes by stepping through each vote.
    my $yaml = YAML::Tiny->new;
    while ( my $vote = $iter->() ) {
        $yaml->[0]->{$vote->score} += 1;
    }

    # Convert the hash to a string and save the vote summary.
    $votesummary->vote_dist( $yaml->write_string() );
    $votesummary->save or die $votesummary->errstr;

    # Return the $yaml hash so that the vote distribution tag can continue
    # to process.
    return $yaml;
}


sub ajax_rating {
    my $ctx = shift;
    my $args = shift;

    my $obj_type = $args->{type};
    if (!$obj_type) {
        if ($ctx->stash('comment')) {
            $obj_type = 'comment';
        } else {
            $obj_type = 'entry';
        }
    }
    if ($obj_type eq 'trackback') { $obj_type = 'ping'; }
    my $obj = $ctx->stash($obj_type);
    my $obj_id = $obj->id if $obj;
    if ($args->{id}) { $obj_id = $args->{id}; }

    my $votesummary = AjaxRating::VoteSummary->load({ obj_type => $obj_type, obj_id => $obj_id });
    if ($votesummary) {
        my $show = defined($args->{show}) ? $args->{show} : 'total_score';
        if ($show eq 'avg_score') {
            return ($votesummary->avg_score);
        } elsif ($show eq 'vote_count') {
            return ($votesummary->vote_count);
        } else {
            return ($votesummary->total_score);
        }
    } else {
        return 0;
    }
}

sub ajax_rating_avg_score {
    my $ctx = shift;
    my $args = shift;
    $args->{show} = 'avg_score';
    ajax_rating($ctx, $args);
}

sub ajax_rating_vote_count {
    my $ctx = shift;
    my $args = shift;
    $args->{show} = 'vote_count';
    ajax_rating($ctx, $args);
}

sub ajax_rating_total_score {
    my $ctx = shift;
    my $args = shift;
    ajax_rating($ctx, $args);
}

sub ajax_rating_user_vote_count {
    my $ctx = shift;
    my $args = shift;
    my $author_id = $args->{author_id} || $args->{voter_id} || $args->{user_id};
    my $author;
    if ($author_id) {
        $author = MT->model('author')->load($author_id);
    } else {
        $author = $ctx->stash('author');
    }
    return $ctx->error("Need author context for AjaxRatingUserVoteCount") 
        if !$author;
    my $obj_type = $args->{obj_type} || 'entry';
    my $count = MT->model('ajaxrating_vote')->count({ voter_id => $author->id, obj_type => $obj_type });
    return $count;
}

sub listing_user_votes {
    my ($ctx, $args, $cond) = @_;
    my $author_id = $args->{author_id} || $args->{voter_id} || $args->{user_id};
    my $author;
    if ($author_id) {
        $author = MT->model('author')->load($author_id);
    } else {
        $author = $ctx->stash('author');
    }
    return $ctx->error("Need author context for AjaxRatingUserVoteCount") 
        if !$author;
    my $obj_type = $args->{obj_type} || 'entry';
    my $lastn = $args->{lastn} || 10;
    my $sort_by = $args->{sort_by} || 'authored_on';
    my $direction = $args->{direction} || 'descend';
    my $offset = $args->{offset} || 0;
    my $blog_id = $args->{blog_id};
    my @votes = MT->model('ajaxrating_vote')->load({ 
                    voter_id => $author->id, 
                    obj_type => $obj_type,
                    ($blog_id ? (blog_id => $blog_id) : ()),
                     }, {
                    limit => $lastn, 
                    offset => $offset, 
                    sort => 'created_on', 
                    direction => $direction });
    if (!@votes) {
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
    
    my $old_way = 0;
    if ($old_way) {
        my @obj_ids;
        foreach my $vote (@votes) {
            push @obj_ids, $vote->obj_id;
        }
        my @objects = MT->model($obj_type)->load({ id => \@obj_ids }, { sort => $sort_by, direction => $direction });
        # support only entries for now
        foreach my $args_key ('category', 'categories', 'tag', 'tags', 'author', 'id', 'days', 'recently_commented_on', 'include_subcategories', 'offset') {
            delete $args->{$args_key};
        }
        $args->{sort_by} = $sort_by;
        $args->{direction} = $direction;
        $args->{lastn} = $lastn;
        $ctx->stash('entries',\@objects);
        return MT::Template::Context::_hdlr_entries($ctx, $args, $cond);
    } else {
        my $res = '';
        my $tok = $ctx->stash('tokens');
        my $builder = $ctx->stash('builder');
        my $i = 0;
        my $glue = $args->{glue};
        my $vars = $ctx->{__stash}{vars} ||= {};
        foreach my $vote (@votes) {
            my $e = MT->model($obj_type)->load($vote->obj_id) or next;
            local $vars->{__first__} = !$i;
            local $vars->{__last__} = !defined $votes[$i+1];
            local $vars->{__odd__} = ($i % 2) == 0; # 0-based $i
            local $vars->{__even__} = ($i % 2) == 1;
            local $vars->{__counter__} = $i+1;
            local $ctx->{__stash}{blog} = $e->blog;
            local $ctx->{__stash}{blog_id} = $e->blog_id;
            local $ctx->{__stash}{entry} = $e;
            local $ctx->{current_timestamp} = $e->authored_on;
            local $ctx->{current_timestamp_end} = $e->authored_on;
            local $ctx->{modification_timestamp} = $e->modified_on;
            my $out = $builder->build($ctx, $tok);
            return $ctx->error( $builder->errstr ) unless defined $out;
            $res .= $glue if defined $glue && $i && length($res) && length($out);
            $res .= $out;
            $i++;
        }
        return $res;
    }
}


sub rater {
    my $ctx = shift;
    my $args = shift;
    my $rater_type = $args->{rater_type} || 'star';
    my $blog = $ctx->stash('blog');

    my $obj_type = $args->{type};
    if (!$obj_type) {
        if ($ctx->stash('comment')) {
            $obj_type = 'comment';
        } else {
            $obj_type = 'entry';
        }
    }

    if ($obj_type eq 'trackback') { $obj_type = 'ping'; }
    my $obj = $ctx->stash($obj_type);
        #   or return $ctx->error("Unknown object type");
    my $obj_id = $obj->id if $obj;
    my $blog_id = $blog->id;
    if ($args->{id}) { $obj_id = $args->{id}; }

    my $author_id = 0;
    if ($obj_type eq 'comment') {
        $author_id = $obj->commenter_id || 0;
    } elsif ($obj_type eq 'entry') {
        $author_id = $obj->author_id;
    }

    my $avg_score = 0;
    my $total_score = 0;
    my $vote_count = 0;
    my $votesummary = AjaxRating::VoteSummary->load({ obj_type => $obj_type, obj_id => $obj_id });
    if ($votesummary) {
        $avg_score = $votesummary->avg_score;
        $vote_count = $votesummary->vote_count;
        $total_score = $votesummary->total_score;
    }

    my $html;

    if ($rater_type eq 'star') {
        my $plugin = MT->component('ajaxrating');
        my $config = $plugin->get_config_hash('blog:'.$blog->id);
        my $unit_width = $config->{unit_width};
        my $max_setting = $obj_type . '_max_points';
        my $units = $config->{$max_setting} || $args->{max_points} || 5;
        my $rater_length = ($units * $unit_width);
        my $star_width = (sprintf("%.1f",$avg_score / $units * $rater_length)) . "px";
        $rater_length .= 'px';
        my $ratingl = '';
        if ($config->{ratingl}) { $ratingl = "      <!-- AJAX Rating powered by MT Hacks http://mt-hacks.com/ajaxrating.html -->"; }
        $html = <<HTML;
<div id="rater$obj_type$obj_id">
            <ul id="rater_ul$obj_type$obj_id" class="unit-rating" style="width:$rater_length;">
        <li class="current-rating" id="rater_li$obj_type$obj_id" style="width:$star_width;">Currently $avg_score/$units</li>
HTML
        for(my $star=1;$star<=$units;$star++) {
            $html .= <<HTML;
        <li><a title="$star out of $units" href="#" class="r$star-unit rater" onclick="pushRating('$obj_type',$obj_id,$star,$blog_id,$total_score,$vote_count,$author_id); return(false);">$star</a></li>
HTML
        }
        $html .= <<HTML;
        </ul> $ratingl
<span class="thanks" id="thanks$obj_type$obj_id"></span>
</div>
HTML
    } elsif ($rater_type eq 'onclick_js') {
        my $points = defined ($args->{points}) ? $args->{points} : 1;
        $html = <<HTML; 
pushRating('$obj_type',$obj_id,$points,$blog_id,$total_score,$vote_count,$author_id); return(false);
HTML
    } else {
        my $static_path = MT->instance->static_path . "plugins/AjaxRating/images";
        my $report_icon = '';
        if ($args->{report_icon}) { 
            $report_icon = <<HTML;
            <a href="#" title="Report this comment" onclick="reportComment($obj_id); return(false);"><img src="$static_path/report.gif" alt="Report this comment" /></a>
HTML
        }
        $html = <<HTML;
<span id="thumb$obj_type$obj_id">
<a href="#" title="Vote up" onclick="pushRating('$obj_type',$obj_id,1,$blog_id,$total_score,$vote_count,$author_id); return(false);"><img src="$static_path/up.gif" alt="Vote up" /></a> <a href="#" title="Vote down" onclick="pushRating('$obj_type',$obj_id,-1,$blog_id,$total_score,$vote_count,$author_id); return(false);"><img src="$static_path/down.gif" alt="Vote down" /></a> $report_icon
</span><span class="thanks" id="thanks$obj_type$obj_id"></span>
HTML
    }
    return $html;
}

sub star_rater {
    my $ctx = shift;
    my $args = shift;
    $args->{rater_type} = 'star';
    rater($ctx, $args);
}

sub thumb_rater {
    my $ctx = shift;
    my $args = shift;
    $args->{rater_type} = 'thumb';
    rater($ctx, $args);
}

sub rater_onclick_js {
    my $ctx = shift;
    my $args = shift;
    $args->{rater_type} = 'onclick_js';
    rater($ctx, $args);
}

sub entry_max {
    my $ctx = shift;
    my $args = shift;
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog->id);
    $config->{entry_max_points};
}

sub comment_max {
    my $ctx = shift;
    my $args = shift;
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog->id);
    $config->{comment_max_points};
}


sub star_rater_width {
    my $ctx = shift;
    my $args = shift;
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog->id);
    my $obj_type = $args->{type} || 'entry';
    my $max_setting = $obj_type . '_max_points';
    my $rater_width = $config->{$max_setting} * $config->{unit_width};
}

sub star_rater_avg_score_width {
    my $ctx = shift;
    my $args = shift;
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog->id);
    my $total_width = star_rater_width($ctx,$args);
    my $avg_score = ajax_rating_avg_score($ctx,$args);
    my $obj_type = $args->{type} || 'entry';
    my $max_setting = $obj_type . '_max_points';
    my $avg_score_width = ($avg_score / $config->{$max_setting}) * $total_width;
}

sub star_unit_width {
    my $ctx = shift;
    my $args = shift;
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog->id);
    my $unit_width = $config->{unit_width};
    if ($args->{mult_by}) { $unit_width = $unit_width * $args->{mult_by}; }
    return $unit_width;
}

sub default_threshold {
    my $ctx = shift;
    my $args = shift;
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog->id);
    my $threshold = $config->{comment_threshold};
    if ($threshold eq 'all') { $threshold = -9999; }
    return $threshold;
}


sub below_threshold {
    my $ctx = shift;
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('blog:'.$blog->id);
    my $comment = $ctx->stash('comment');
    my $votesummary = AjaxRating::VoteSummary->load({ obj_type => 'comment', obj_id => $comment->id });
    if (!$votesummary || $config->{comment_threshold} eq 'all' || $config->{comment_mode} == 0) { return 0; }
    my $score;
    if ($config->{comment_mode} == 1) {
        $score = $votesummary->total_score;
    } else {
        $score = $votesummary->avg_score;
    }   
    if ($votesummary->total_score < $config->{comment_threshold}) {
        return 1;
    } else {
        return 0;
    }
}


sub refresh_hot {
    my $ctx = shift;
    my $args = shift;
    my %vs_terms = ();
    my %vs_args = ();
    my $start_refresh = time;
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('system');
    my $days = $args->{days} || $config->{hot_days} || 7;
    my @ago = gmtime(time - 3600 * 24 * $days);
    my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
        $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
    $vs_terms{modified_on} = [ $ago ];
    $vs_args{range_incl}{modified_on} = 1;
    my $obj_iter = AjaxRating::VoteSummary->load_iter(\%vs_terms, \%vs_args);
    my $hot_total_score;
    my $hot_vote_count;
    use AjaxRating::HotObject;
    AjaxRating::HotObject->remove_all();
    while (my $object = $obj_iter->()) {
        $hot_total_score = 0;
        $hot_vote_count = 1;
        $vs_terms{'obj_type'} = $object->obj_type;
        $vs_terms{'obj_id'} = $object->obj_id;
        my $votes_iter = AjaxRating::Vote->load_iter(\%vs_terms, \%vs_args);
        while (my $vote = $votes_iter->()) {
            $hot_total_score += $vote->score;
            $hot_vote_count++;
        }
        my $hot = AjaxRating::HotObject->load({ obj_id => $object->obj_id, obj_type => $object->obj_type });
        unless ($hot) {
            $hot = AjaxRating::HotObject->new;
        }
#       $hot->id($object->id);
        $hot->obj_type($object->obj_type);
        $hot->obj_id($object->obj_id);
        $hot->blog_id($object->blog_id);
        $hot->author_id($object->author_id);
        $hot->vote_count($hot_vote_count);
        $hot->total_score($hot_total_score);
        $hot->avg_score(sprintf("%.1f",$hot_total_score / $hot_vote_count));    
        $hot->save; 
    }
    my $refresh_time = time - $start_refresh;
    MT->log({
       message => "Ajax Ratings Plugin has refreshed the hot objects list (" . $refresh_time . " seconds)",
       metadata => $refresh_time,
       class => 'MT::Log::System'
    });
    return '';
}

sub delete_fraud {
    my $ctx = shift;
    my $args = shift;
    my %vs_terms = ();
    my %vs_args = ();
    my $start_task = time;
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('system');
    if (!$config->{enable_delete_fraud}) {
        return '';
    }
    my $check_votes = $args->{check_votes} || $config->{check_votes} || 25;
    my @ago = gmtime(time - 3600 * 3);   # checks objects rated in the past 6 hours
    my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
        $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
    $vs_terms{modified_on} = [ $ago ];
    $vs_args{range_incl}{modified_on} = 1;
    my $obj_iter = AjaxRating::VoteSummary->load_iter(\%vs_terms, \%vs_args);
    my $deleted_votes = 0;
    while (my $object = $obj_iter->()) {
        my @recent_votes = AjaxRating::Vote->load({ obj_type => $object->obj_type, obj_id => $object->obj_id },
                                                     { limit => $check_votes, direction => 'descend' });
        my $num_votes = @recent_votes;
        my $start = 1;
        VOTE: for my $vote (@recent_votes) {
            for (my $count=$start; $count<$num_votes; $count++) {
                # MT->log('vote ' . $vote->subnet . ' versus ' . $recent_votes[$count]->subnet);
                if ($vote->subnet eq $recent_votes[$count]->subnet) {
                    $object->vote_count($object->vote_count - 1);
                    $object->total_score($object->total_score - $vote->score);
                    $object->avg_score(sprintf("%.1f",$object->total_score / $object->vote_count)); 
                    $object->save;
                    $vote->remove;
                    MT->log('Ajax Ratings has deleted vote ' . $vote->id . ' with duplicate subnet ' . $vote->subnet . ' on ' . $vote->obj_type . ' ' . $vote->obj_id);
                    $deleted_votes++;
                    last VOTE;
                }
            }
        }
    }
    my $task_time = time - $start_task;
    MT->log({
       message => "Ajax Ratings Plugin has deleted $deleted_votes votes (" . $task_time . " seconds)",
       metadata => $task_time,
       class => 'MT::Log::System'
    });
    return '';
}

sub migrate_community_votes {
    my $start_migrate = time;
    my $plugin = MT->component('ajaxrating');
    my $config = $plugin->get_config_hash('system');
    if ($config->{migrate}) {
        my $count = 0;
        my $iter = MT->model('objectscore')->load_iter({namespace => 'community_pack_recommend'});
        while ( my $fav = $iter->() ) {
            my $vote = AjaxRating::Vote->load({
                voter_id => $fav->author_id,
                obj_type => $fav->object_ds,
                obj_id => $fav->object_id,
            });
            if (!$vote) {
                $vote = AjaxRating::Vote->new;
                $vote->voter_id($fav->author_id);
                $vote->obj_type($fav->object_ds);
                $vote->obj_id($fav->object_id);
                $vote->score($fav->score);
                $vote->ip($fav->ip);
                my $obj = MT->model($fav->object_ds)->load($fav->object_id);
                if ($obj && $obj->can('blog_id')) {
                    $vote->blog_id($obj->blog_id);
                }
                $vote->created_on($fav->created_on);
                $vote->modified_on($fav->modified_on);
                $vote->save;
                
                # Update the Vote Summary. The summary is used because it will let 
                # publishing happen faster (loading one summary row to publish results
                # is faster than loading many AjaxRating::Vote records).
                my $votesummary = AjaxRating::VoteSummary->load({
                    obj_type => $vote->obj_type,
                    obj_id   => $vote->obj_id,
                });

                # If no VoteSummary was found for this object, create one and populate 
                # it with "getting started" values.
                if (!$votesummary) {
                    $votesummary = AjaxRating::VoteSummary->new;
                    $votesummary->obj_type($vote->obj_type);
                    $votesummary->obj_id($vote->obj_id);
                    $votesummary->blog_id($vote->blog_id);
                    if ($obj && $obj->can('author_id')) {
                        $votesummary->author_id($obj->author_id);
                    }
                    $votesummary->vote_count(0);
                    $votesummary->total_score(0);
                }

                # Update the VoteSummary with details of this vote.
                $votesummary->vote_count($votesummary->vote_count + 1);
                $votesummary->total_score($votesummary->total_score + $vote->score);
                $votesummary->avg_score(
                    sprintf("%.1f",$votesummary->total_score / $votesummary->vote_count)
                );

                # Update the voting distribution, which makes it easy to output 
                # "X Stars has received Y votes"
                my $yaml = YAML::Tiny->read_string( $votesummary->vote_dist );
                $yaml = YAML::Tiny->new if !$yaml; # No previously-saved data.

                # Increase the vote tally for this score by 1.
                $yaml->[0]->{$vote->score} += 1;

                $votesummary->vote_dist( $yaml->write_string() );
                $votesummary->save or die $votesummary->errstr;
                $count++;
            }
            $plugin->set_config_value('migrate', 0, 'system');
        }
        
        my $migrate_time = time - $start_migrate;
        MT->log({
           message => "Ajax Ratings Plugin has migrated " . $count . " Community Pack votes (" . $migrate_time . " seconds)",
           metadata => $migrate_time,
           class => 'MT::Log::System'
        });
    }
    return '';
}

sub entry_delete_handler {
    my ($cb, $object) = @_;
    my $obj_type = 'entry';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
    $votesummary->remove if $votesummary;
}

sub comment_delete_handler {
    my ($cb, $object) = @_;
    my $obj_type = 'comment';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
    $votesummary->remove if $votesummary;
}

sub trackback_delete_handler {
    my ($cb, $object) = @_;
    my $obj_type = 'trackback';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
    $votesummary->remove if $votesummary;
}

sub category_delete_handler {
    my ($cb, $object) = @_;
    my $obj_type = 'category';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
    $votesummary->remove if $votesummary;
}

sub blog_delete_handler {
    my ($cb, $object) = @_;
    my $obj_type = 'blog';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
    $votesummary->remove if $votesummary;
}

sub author_delete_handler {
    my ($cb, $object) = @_;
    my $obj_type = 'author';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
    $votesummary->remove if $votesummary;
}

sub tag_delete_handler {
    my ($cb, $object) = @_;
    my $obj_type = 'tag';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
    $votesummary->remove if $votesummary;
}

sub entry_post_save {
    my ($cb, $entry) = @_;
    my $votesummary;
    if ($entry->status != 2) {
        if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'entry', obj_id => $entry->id })) {
            $votesummary->obj_type('entry0');
            $votesummary->save;
        }
    } else {
        if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'entry0', obj_id => $entry->id })) {
            $votesummary->obj_type('entry');
            $votesummary->save;
        }
    }
}

sub comment_post_save {
    my ($cb, $comment) = @_;
    my $votesummary;
    if ($comment->visible == 0) {
        if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'comment', obj_id => $comment->id })) {
            $votesummary->obj_type('comment0');
            $votesummary->save;
        }
    } else {
        if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'comment0', obj_id => $comment->id })) {
            $votesummary->obj_type('comment');
            $votesummary->save;
        }
    }
}

sub tbping_post_save {
    my ($cb, $ping) = @_;
    my $votesummary;
    if ($ping->visible == 0) {
        if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'trackback', obj_id => $ping->id })) {
            $votesummary->obj_type('trackback0');
            $votesummary->save;
        }
    } else {
        if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'trackback0', obj_id => $ping->id })) {
            $votesummary->obj_type('trackback');
            $votesummary->save;
        }
    }
}

sub session_state {
    my ($cb, $app, $c, $commenter) = @_;
    my $q = $app->param if $app->can('param');
    my $blog_id = $q->param('blog_id') if $q;
    my @votes = MT->model('ajaxrating_vote')->load({ 
                    voter_id => $commenter->id, 
                    obj_type => 'entry',
                    ($blog_id ? (blog_id => $blog_id) : ()),
    });
    my $data = {};
    foreach my $vote (@votes) {
        my $obj_id = $vote->obj_id;
        my $score = $vote->score;
        $data->{$obj_id} = $score;
    }
    $c->{user_votes} = $data if $data;
    return ($c, $commenter);
}

sub install_templates {
    my $plugin = shift;
    my ($app) = @_;
    my $q = $app->{query};
    my $blog_id = $app->{query}->param('blog_id');
    my $param = { };

    my $perms = $app->{perms};
    return $app->error("Insufficient permissions for modifying templates for this weblog.")
        unless $perms->can_edit_templates() || $perms->can_administer_blog ||
               $app->{author}->is_superuser();

    require MT::Template;

    my $templates = [
             {
               'outfile' => 'ajaxrating.js',
               'name' => 'Ajax Rating Javascript',
               'type' => 'index',
             'rebuild_me' => '0'
              },
             {
               'outfile' => 'ajaxrating.css',
               'name' => 'Ajax Rating Styles',
               'type' => 'index',
             'rebuild_me' => '0'
              },
             {
               'name' => 'Widget: Ajax Rating',
               'type' => 'custom',
             'rebuild_me' => '0'
              },
            ];

    use MT::Util qw(dirify);

    require MT;
    use File::Spec;
    my $path = 'plugins/AjaxRating/tmpl';
    local (*FIN, $/);
    $/ = undef;
    my $data;
    foreach my $tmpl (@$templates) {
        my $file = File::Spec->catfile($path, dirify($tmpl->{name}).'.tmpl');
       if ((-e $file) && (-r $file)) {
          open FIN, "<$file"; $data = <FIN>; close FIN;
          $tmpl->{text} = $data;
      }
    }

    my $tmpl_list = $templates;
    my $tmpl;

    foreach my $val (@$tmpl_list) {
            $val->{name} = $app->translate($val->{name});
            $val->{text} = $app->translate_templatized($val->{text});

        my $terms = {};
        $terms->{blog_id} = $blog_id;
        $terms->{type} = $val->{type};
        $terms->{name} = $val->{name};
            
        $tmpl = MT::Template->load($terms);

        if ($tmpl) {
            return $app->error("Template already exists. To reinstall the default template, first delete or rename the existing template.': " . $tmpl->errstr);
        } else {
            $tmpl = new MT::Template;
            $tmpl->build_dynamic(0);
            $tmpl->set_values($val);
            $tmpl->blog_id($blog_id);
            $tmpl->save or return $app->error("Error creating new template: " . $tmpl->errstr);
            $app->rebuild_indexes( BlogID => $blog_id, Template => $tmpl, Force => 1 );
        }
    }
    $app->redirect($app->uri('mode' => 'cfg_plugins', args => { 'blog_id' => $blog_id } ));
}

sub template {
    my ($plugin, $param) = @_;
    my $app = MT->instance;
    my $blog_id = $app->{query}->param('blog_id');
    my $tmpl;

    rebuild_ar_templates($app);
    
    # If the Template Installer plugin is installed, show the "Install 
    # Templates" link.
    if ( eval { MT->component('TemplateInstaller') } ) {
        $tmpl = <<HTML;
<mtapp:setting
    id="install_ajaxrating_templates"
    label="<__trans phrase="Install Ajax Rating Templates">"
    hint=""
    class="actions-bar"
    show_hint="0">

    <div class="actions-bar-inner pkg actions">
        <a href="javascript:void(0)" onclick="return openDialog(false, 'install_blog_templates','template_path=plugins/AjaxRating/default_templates&amp;set=ajax_rating_templates&amp;blog_id=$blog_id&amp;return_args=__mode%3Dcfg_plugins%26%26blog_id%3D$blog_id')" class="primary-button"><__trans phrase="Install Templates"></a>
    </div>

</mtapp:setting>
HTML
    }

    $tmpl .= <<MT40;
<mtapp:setting
    id="entry_mode"
    label="<__trans phrase="Entry Mode">"
    hint=""
    show_hint="0">
            <select name="entry_mode">
                <option value="0"<TMPL_IF NAME=ENTRY_MODE_0> selected="selected"</TMPL_IF>>Off</option>
                <option value="1"<TMPL_IF NAME=ENTRY_MODE_1> selected="selected"</TMPL_IF>>Thumbs Up/Down</option>
                <option value="2"<TMPL_IF NAME=ENTRY_MODE_2> selected="selected"</TMPL_IF>>Star/Point Rating</option>
            </select>
            <p>Choose the mode to use for rating entries.</p>
</mtapp:setting>

<mtapp:setting
    id="entry_max_points"
    label="<__trans phrase="Entry Max Points">"
    hint=""
    show_hint="0">
            <select name="entry_max_points">
                <option value="1"<TMPL_IF NAME=ENTRY_MAX_POINTS_1> selected="selected"</TMPL_IF>>1</option>
                <option value="2"<TMPL_IF NAME=ENTRY_MAX_POINTS_2> selected="selected"</TMPL_IF>>2</option>
                <option value="3"<TMPL_IF NAME=ENTRY_MAX_POINTS_3> selected="selected"</TMPL_IF>>3</option>
                <option value="4"<TMPL_IF NAME=ENTRY_MAX_POINTS_4> selected="selected"</TMPL_IF>>4</option>
                <option value="5"<TMPL_IF NAME=ENTRY_MAX_POINTS_5> selected="selected"</TMPL_IF>>5</option>
                <option value="6"<TMPL_IF NAME=ENTRY_MAX_POINTS_6> selected="selected"</TMPL_IF>>6</option>
                <option value="7"<TMPL_IF NAME=ENTRY_MAX_POINTS_7> selected="selected"</TMPL_IF>>7</option>
                <option value="8"<TMPL_IF NAME=ENTRY_MAX_POINTS_8> selected="selected"</TMPL_IF>>8</option>
                <option value="9"<TMPL_IF NAME=ENTRY_MAX_POINTS_9> selected="selected"</TMPL_IF>>9</option>
                <option value="10"<TMPL_IF NAME=ENTRY_MAX_POINTS_10> selected="selected"</TMPL_IF>>10</option>
            </select>
            <p>Choose the maximum number of points or stars when rating entries.</p>
</mtapp:setting>
<TMPL_IF NAME=RATINGL_0>
<mtapp:setting
    id="comment_mode"
    label="<__trans phrase="Comment Mode">"
    hint=""
    show_hint="0">
            <select name="comment_mode">
                <option value="0"<TMPL_IF NAME=COMMENT_MODE_0> selected="selected"</TMPL_IF>>Off</option>
                <option value="1"<TMPL_IF NAME=COMMENT_MODE_1> selected="selected"</TMPL_IF>>Thumbs Up/Down</option>
                <option value="2"<TMPL_IF NAME=COMMENT_MODE_2> selected="selected"</TMPL_IF>>Star/Point Rating</option>
            </select>
            <p>Choose the mode to use for rating comments.</p>
</mtapp:setting>

<mtapp:setting
    id="comment_max_points"
    label="<__trans phrase="Comment Max Points">"
    hint=""
    show_hint="0">
            <select name="comment_max_points">
                <option value="1"<TMPL_IF NAME=COMMENT_MAX_POINTS_1> selected="selected"</TMPL_IF>>1</option>
                <option value="2"<TMPL_IF NAME=COMMENT_MAX_POINTS_2> selected="selected"</TMPL_IF>>2</option>
                <option value="3"<TMPL_IF NAME=COMMENT_MAX_POINTS_3> selected="selected"</TMPL_IF>>3</option>
                <option value="4"<TMPL_IF NAME=COMMENT_MAX_POINTS_4> selected="selected"</TMPL_IF>>4</option>
                <option value="5"<TMPL_IF NAME=COMMENT_MAX_POINTS_5> selected="selected"</TMPL_IF>>5</option>
                <option value="6"<TMPL_IF NAME=COMMENT_MAX_POINTS_6> selected="selected"</TMPL_IF>>6</option>
                <option value="7"<TMPL_IF NAME=COMMENT_MAX_POINTS_7> selected="selected"</TMPL_IF>>7</option>
                <option value="8"<TMPL_IF NAME=COMMENT_MAX_POINTS_8> selected="selected"</TMPL_IF>>8</option>
                <option value="9"<TMPL_IF NAME=COMMENT_MAX_POINTS_9> selected="selected"</TMPL_IF>>9</option>
                <option value="10"<TMPL_IF NAME=COMMENT_MAX_POINTS_10> selected="selected"</TMPL_IF>>10</option>
            </select>
            <p>Choose the maximum number of points or stars when rating entries.</p>
</mtapp:setting>

<mtapp:setting
    id="default_comment_threshold"
    label="<__trans phrase="Default Comment Threshold">"
    hint=""
    show_hint="0">
            <input name="comment_threshold" type="text" size="3" value="<TMPL_VAR NAME=COMMENT_THRESHOLD>"></input>&nbsp;
            <p>Advanced feature: choose the default rating or total score threshold for comments to be displayed.</p>
</mtapp:setting>
</TMPL_IF>
<mtapp:setting
    id="star_icon_width"
    label="<__trans phrase="Star Icon Width">"
    hint=""
    show_hint="0">
            <input name="unit_width" type="text" value="<TMPL_VAR NAME=UNIT_WIDTH>"></input>&nbsp;
            <p>Advanced feature: choose the width of the star icon. Default is 30.</p>
</mtapp:setting>
<mtapp:setting
    id="rebuild_after_vote"
    label="<__trans phrase="Rebuild After a Vote">"
    hint=""
    show_hint="0">
            <select name="rebuild">
                <option value="0"<TMPL_IF NAME=REBUILD_0> selected="selected"</TMPL_IF>>No Rebuilds</option>
                <option value="1"<TMPL_IF NAME=REBUILD_1> selected="selected"</TMPL_IF>>Rebuild Entry Only</option>
                <option value="2"<TMPL_IF NAME=REBUILD_2> selected="selected"</TMPL_IF>>Rebuild Entry, Archives, Indexes</option>
                <option value="3"<TMPL_IF NAME=REBUILD_3> selected="selected"</TMPL_IF>>Rebuild Indexes Only</option>
            </select>
            <p>Choose an option to rebuild pages after a vote is registered. You should only rebuild those pages where you are displaying ratings. WARNING: Rebuilding can affect performance on high-traffic sites with a lot of active voting.</p>
</mtapp:setting>
        <input name="ratingl" type="hidden" value="<TMPL_VAR NAME=RATINGL>"></input>
MT40

    return $tmpl;
}

sub system_template {
    my ($plugin, $param) = @_;
    my $tmpl = <<MT40;
<mtapp:setting
    id="hot_days"
    label="<__trans phrase="Days for Hot Lists">"
    hint="Advanced feature: choose the numbers of days to used to determine which items are &ldquo;hot.&rdquo; For example, if you choose 7 days, then only votes from the past 7 days will be tallied."
    show_hint="1">
    <input name="hot_days" type="text" size="3" value="<mt:Var name="hot_days">" />
</mtapp:setting>

<mtapp:setting
    id="enable_delete_fraud"
    label="<__trans phrase="Enable Fraud Checker">"
    hint="Advanced feature: enabling the fraud checker will hourly check for recent votes on the same object that are from the same subnet. For example, if the checker found two recents votes on an entry from 123.456.789.111 and 123.456.789.222, it would delete the most recent of the two votes."
    show_hint="1">
            <input name="enable_delete_fraud" type="checkbox"<mt:If name="enable_delete_fraud">checked</mt:If> />
</mtapp:setting>

<mtapp:setting
    id="check_votes"
    label="<__trans phrase="Number of Votes">"
    hint="If the fraud checker is enabled, it will scan this number of recent votes on each object that has recently been voted on. For performance reasons, don't set this too high."
    show_hint="1">
            <input name="check_votes" type="text" size="3" value="<mt:Var name="check_votes">" />
</mtapp:setting>

<mtapp:setting
    id="enable_ip_checking"
    label="<__trans phrase="Enable IP Checking">"
    hint="Normally, votes are restricted by IP address: 1 vote for 1 IP address per rated object. In a live environment this is often fine, but during development it makes things a bear. You may also want to disable this feature if ratings are used internally, where all users may have the same IP address."
    show_hint="1">
            <input type="checkbox" name="enable_ip_checking" <mt:If name="enable_ip_checking">checked</mt:If> />
</mtapp:setting>

<mtapp:setting
    id="migrate"
    label="<__trans phrase="Migrate Community Pack Votes">"
    hint="(Advanced) Check this box to migrate all system wide votes made via the MT Community Pack favoriting system. This will copy those votes and convert them to Ajax Rating votes. Useful if you plan to migrate from using Community Pack to Ajax Rating and you want to keep the pre-existing vote data. Note that the migrate will happen during the next scheduled task run (usually via cron) and once complete, a message will be posted to the System Activity Log and this setting will become unchecked."
    show_hint="1">
            <input type="checkbox" name="migrate" <mt:If name="migrate">checked</mt:If> />
</mtapp:setting>
MT40

    return $tmpl;
}

sub rebuild_ar_templates {
    my ($app) = @_;
    my $blog_id = $app->param('blog_id');
    use MT::Template;
    my @tmpls = ("Ajax Rating Styles","Ajax Rating Javascript");
    foreach my $tmpl_name (@tmpls) {
        my $tmpl = MT::Template->load({ blog_id => $blog_id, name => $tmpl_name, type => 'index', rebuild_me => 0 });
        if ($tmpl) { 
            $app->rebuild_indexes( BlogID => $blog_id, Template => $tmpl, Force => 1 )
                or MT->log($app->errstr);
        }
    }
}

# When upgrading to schema_version 3, vote distribution data needs to be 
# calculated.
sub upgrade_add_vote_distribution {
    my ($obj) = @_;

    _create_vote_distribution_data( $obj );
}

# schema_version 4 reflects the move to the config.yaml style plugin. Plugin
# data was previously saved with the name "AJAX Rating Pro" which isn't easily
# accessible, so update it to use "ajaxrating."
sub upgrade_migrate_plugin_data {
    my ($pdata) = @_;

    if ($pdata->plugin eq 'AJAX Rating Pro') {
        $pdata->plugin('ajaxrating');
        $pdata->save or die $pdata->errstr;
    }
}

1;
