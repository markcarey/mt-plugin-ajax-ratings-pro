#########################################################
# Changes:
# 1.02 -- Fix for points="0" raters with MTAjaxRaterOnclickJS tag - thanks Arvind!
# 1.03 -- Added advanced use MTAjaxStarRaterAvergaeScoreWidth tag to output pixel width of current score
# 1.04 -- Added AjaxRatingAvgScore as alias for AjaxRatingAverageScore
# 1.05 -- Fix for Relative CGI Path in report comment email link
# 1.06 -- Fix listings with sort_order = "ascend"
# 1.1  -- MT4 Support
# 1.11 -- Bug fixes for tables not be installed and dynamic publishing issue with stars not showing
# 1.12 -- Bug fix for issue of settings not showing at the blog level in MT3.3x
# 1.13 -- Fix for warning about unitialized value in eq
# 1.14 -- Fix for tables not being installed on claen install on MT 4.01
# 1.15 -- New Pro feature - scheduled task for deleting recent votes on same object with same subnets (24.123.456)
# 1.17 -- fix for case where votes from the same IP were being allowed
# 1.25 -- added voter_id to vote table, when authed user votes, their id is recorded
# 1.26 -- fixes to refresh hot objects and object listing functions
# 1.261 -- added first/last vars to entry listing tags

package MT::Plugin::AjaxRating;
use base qw(MT::Plugin);
use strict;

use MT;
use AjaxRating;

use vars qw($VERSION);
$VERSION = '1.3';
my $plugin = new MT::Plugin::AjaxRating({
    name => "AJAX Rating Pro",
    description => "AJAX rating plugin for entries and comments and more. Pro version.",
    doc_link => "http://mt-hacks.com/ajaxrating.html",
    plugin_link => "http://mt-hacks.com/ajaxrating.html",
    author_name => "Mark Carey",
    author_link => "http://mt-hacks.com/",
    object_classes => [ 'AjaxRating::Vote','AjaxRating::VoteSummary','AjaxRating::HotObject' ],
    schema_version => "2",   # for plugin version 1.25
    version => $VERSION,
    blog_config_template => \&AjaxRating::template,
    system_config_template => \&AjaxRating::system_template,
    settings => new MT::PluginSettings([
        ['entry_mode', { Default => 0 }],
        ['entry_max_points', { Default => 5 }],
        ['comment_mode', { Default => 0 }],
        ['comment_max_points', { Default => '5' }],
        ['comment_threshold', { Default => 'all' }],
        ['unit_width', { Default => 30 }],
        ['rebuild', { Default => 0 }],
        ['ratingl', { Default => 0 }],
        ['hot_days', { Default => 7 }],
        ['enable_delete_fraud', { Default => 0 }],
        ['check_votes', { Default => 25 }],
    ]),
    tasks => {
        'refresh_hotobjects' => {
            name => "Refresh Hot Objects",
            frequency => 60 * 60,   # run every hour
            code => \&AjaxRating::refresh_hot
        },
        'delete_fraud_votes' => {
            name => "Delete Fraud Votes",
            frequency => 60 * 60,   # run every hour
            code => \&AjaxRating::delete_fraud
        },
    }
});
MT->add_plugin($plugin);

if (MT->version_number < 4.0) {
    require MT::Template::Context;
    MT::Template::Context->add_tag(AjaxRating => \&AjaxRating::ajax_rating);
    MT::Template::Context->add_tag(AjaxRatingAverageScore => \&AjaxRating::ajax_rating_avg_score);
    MT::Template::Context->add_tag(AjaxRatingAvgScore => \&AjaxRating::ajax_rating_avg_score);
    MT::Template::Context->add_tag(AjaxRatingTotalScore => \&AjaxRating::ajax_rating_total_score);
    MT::Template::Context->add_tag(AjaxRatingVoteCount => \&AjaxRating::ajax_rating_vote_count);

    MT::Template::Context->add_tag(AjaxRater => \&AjaxRating::rater);
    MT::Template::Context->add_tag(AjaxStarRater => \&AjaxRating::star_rater);
    MT::Template::Context->add_tag(AjaxThumbRater => \&AjaxRating::thumb_rater);
    MT::Template::Context->add_tag(AjaxRaterOnclickJS => \&AjaxRating::rater_onclick_js);

    MT::Template::Context->add_tag(AjaxRatingEntryMax => \&AjaxRating::entry_max);
    MT::Template::Context->add_tag(AjaxRatingCommentMax => \&AjaxRating::comment_max);
    MT::Template::Context->add_tag(AjaxStarRaterWidth => \&AjaxRating::star_rater_width);
    MT::Template::Context->add_tag(AjaxStarRaterAverageScoreWidth => \&AjaxRating::star_rater_avg_score_width);
    MT::Template::Context->add_tag(AjaxStarUnitWidth => \&AjaxRating::star_unit_width);
    MT::Template::Context->add_tag(AjaxRatingDefaultThreshold => \&AjaxRating::default_threshold);
    MT::Template::Context->add_conditional_tag(IfAjaxRatingBelowThreshold => \&AjaxRating::below_threshold);

    MT::Template::Context->add_container_tag(AjaxRatingList => \&AjaxRating::listing);
    MT::Template::Context->add_container_tag(AjaxRatingEntries => \&AjaxRating::listing_entries);
    MT::Template::Context->add_container_tag(AjaxRatingComments => \&AjaxRating::listing_comments);
    MT::Template::Context->add_container_tag(AjaxRatingPings => \&AjaxRating::listing_pings);
    MT::Template::Context->add_container_tag(AjaxRatingBlogs => \&AjaxRating::listing_blogs);
    MT::Template::Context->add_container_tag(AjaxRatingCategories => \&AjaxRating::listing_categories);
    MT::Template::Context->add_container_tag(AjaxRatingTags => \&AjaxRating::listing_tags);
    MT::Template::Context->add_container_tag(AjaxRatingAuthors => \&AjaxRating::listing_authors);

    ## special tag to refresh hot objects
    MT::Template::Context->add_tag(AjaxRatingRefreshHot => \&AjaxRating::refresh_hot);

    # Callbacks that remove VoteSummary records when objects get deleted
    MT::Entry->add_callback('pre_remove', 5, $plugin, \&AjaxRating::entry_delete_handler);
    MT::Comment->add_callback('pre_remove', 5, $plugin, \&AjaxRating::comment_delete_handler);
    MT::TBPing->add_callback('pre_remove', 5, $plugin, \&AjaxRating::trackback_delete_handler);
    MT::Category->add_callback('pre_remove', 5, $plugin, \&AjaxRating::category_delete_handler);
    MT::Blog->add_callback('pre_remove', 5, $plugin, \&AjaxRating::blog_delete_handler);
    MT::Author->add_callback('pre_remove', 5, $plugin, \&AjaxRating::author_delete_handler);
    MT::Tag->add_callback('pre_remove', 5, $plugin, \&AjaxRating::tag_delete_handler);

    # Callbacks that change the obj_type column when objects are published or unpublished
    MT::Entry->add_callback('post_save', 5, $plugin, \&AjaxRating::entry_post_save);
    MT::Comment->add_callback('post_save', 5, $plugin, \&AjaxRating::comment_post_save);
    MT::TBPing->add_callback('post_save', 5, $plugin, \&AjaxRating::tbping_post_save);
}

sub instance {
    return $plugin;
}

sub init_app {
    my $plugin = shift;
    my ($app) = @_;
    return unless $app->isa('MT::App::CMS');
    $app->add_methods(
        ajaxrating_install_templates => sub { AjaxRating::install_templates($plugin, @_); },
    );
}

## init_registry used only by MT4+ ##

sub init_registry {
    my $component = shift;
    my $reg = {
        'applications' => {
            'cms' => {
                'methods' => {
                    'ajaxrating_install_templates' => sub { AjaxRating::install_templates($plugin, @_); },
                }
            }
        },
        object_types => {
           'ajaxrating_vote' => 'AjaxRating::Vote',
           'ajaxrating_votesummary' => 'AjaxRating::VoteSummary',
           'ajaxrating_hotobject'   => 'AjaxRating::HotObject',
        },
        'callbacks' => {
            'MT::Entry::pre_remove' => \&AjaxRating::entry_delete_handler,
            'MT::Comment::pre_remove' => \&AjaxRating::comment_delete_handler,
            'MT::TBPing::pre_remove' => \&AjaxRating::trackback_delete_handler,
            'MT::Category::pre_remove' => \&AjaxRating::category_delete_handler,
            'MT::Blog::pre_remove' => \&AjaxRating::blog_delete_handler,
            'MT::Author::pre_remove' => \&AjaxRating::author_delete_handler,
            'MT::Tag::pre_remove' => \&AjaxRating::tag_delete_handler,
            'MT::Entry::post_save' => \&AjaxRating::entry_post_save,
            'MT::Comment::post_save' => \&AjaxRating::comment_post_save,
            'MT::TBPing::post_save' => \&AjaxRating::tbping_post_save,
        },
        tags => {
            function => {
               AjaxRating => \&AjaxRating::ajax_rating,
               AjaxRatingAverageScore => \&AjaxRating::ajax_rating_avg_score,
               AjaxRatingAvgScore => \&AjaxRating::ajax_rating_avg_score,
               AjaxRatingTotalScore => \&AjaxRating::ajax_rating_total_score,
               AjaxRatingVoteCount => \&AjaxRating::ajax_rating_vote_count,
               AjaxRater => \&AjaxRating::rater,
               AjaxStarRater => \&AjaxRating::star_rater,
               AjaxThumbRater => \&AjaxRating::thumb_rater,
               AjaxRaterOnclickJS => \&AjaxRating::rater_onclick_js,
               AjaxRatingEntryMax => \&AjaxRating::entry_max,
               AjaxRatingCommentMax => \&AjaxRating::comment_max,
               AjaxStarRaterWidth => \&AjaxRating::star_rater_width,
               AjaxStarRaterAverageScoreWidth => \&AjaxRating::star_rater_avg_score_width,
               AjaxStarUnitWidth => \&AjaxRating::star_unit_width,
               AjaxRatingDefaultThreshold => \&AjaxRating::default_threshold,
               AjaxRatingRefreshHot => \&AjaxRating::refresh_hot,
               AjaxRatingUserVoteCount => \&AjaxRating::ajax_rating_user_vote_count,
            },
            block => {
               'IfAjaxRatingBelowThreshold?' => \&AjaxRating::below_threshold,
               AjaxRatingList => \&AjaxRating::listing,
               AjaxRatingEntries => \&AjaxRating::listing_entries,
               AjaxRatingComments => \&AjaxRating::listing_comments,
               AjaxRatingPings => \&AjaxRating::listing_pings,
               AjaxRatingBlogs => \&AjaxRating::listing_blogs,
               AjaxRatingCategories => \&AjaxRating::listing_categories,
               AjaxRatingTags => \&AjaxRating::listing_tags,
               AjaxRatingAuthors => \&AjaxRating::listing_authors,
               AjaxRatingUserVotes => \&AjaxRating::listing_user_votes,
               AjaxRatingVoteDistribution => \&AjaxRating::listing_vote_distribution,
            },
        },
        tasks => {
            'refresh_hotobjects' => {
                name => "Refresh Hot Objects",
                frequency => 60 * 60,   # run every hour
                code => \&AjaxRating::refresh_hot
            },
            'delete_fraud_votes' => {
                name => "Delete Fraud Votes",
                frequency => 60 * 60,   # run every hour
                code => \&AjaxRating::delete_fraud
            },
        }
    };
    $component->registry($reg);
}


1;
