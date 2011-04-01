#!/usr/bin/perl -w
#

use strict;
use Getopt::Long;

my($MT_DIR);
BEGIN {
   if ($0 =~ m!(.*[/\\])!) {
       $MT_DIR = $1;
   } else {
       $MT_DIR = '../../../';
   }
   unshift @INC, $MT_DIR . 'lib';
   unshift @INC, $MT_DIR . 'plugins/AjaxRating/lib';
   unshift @INC, $MT_DIR . 'extlib';
}

use MT;

my $mt = MT->new(Config => $MT_DIR . 'mt-config.cgi',
                Directory => $MT_DIR) || die MT->errstr;

my $days;

# assign command line arguements to variables.
GetOptions ('days' => \$days);

my $args;
$args->{days} = $days if $days;
use AjaxRating;
AjaxRating::refresh_hot($args);

1;

