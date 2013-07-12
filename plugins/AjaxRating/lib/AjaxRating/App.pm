package AjaxRating::App;

use strict;
use warnings;
use MT::App;
@AjaxRating::App::ISA = qw( MT::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;

    if ( my $mode = $app->can('default_mode') ) {
        $app->add_methods( default => $mode );
    }

    $app->{default_mode} = 'default';
    $app->{charset} = $app->{cfg}->PublishCharset;
    $app;
}

sub _send_error {
    my ( $app, $format, $msg ) = @_;
    if ($format eq 'json') {
        return _send_json_response( $app,
            { status => "ERR", 
              message => $msg,
            } );
    } else {
        return "ERR||" . $msg;
    }
}

sub _send_json_response {
    my ( $app, $result ) = @_;
    require JSON;
    my $json = JSON::objToJson($result);
    $app->send_http_header("");
    $app->print($json);
    return $app->{no_print_body} = 1;
    return undef;
}

1;
