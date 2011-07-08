package MT::Object::LegacyFactory;

use strict;
use warnings;
use Carp qw( croak );
use UNIVERSAL::require;
use Storable qw( dclone );
use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect ); my $logger ||= MT::Log::Log4perl->new(); $logger->trace();

=head1 NAME

  MT::Object::LegacyFactory - Data migration for MT::Object subclasses

=head1 SYNOPSIS

  require MT::Object::LegacyFactory;
  my $props = MT::Object::LegacyFactory->init_class(
      'MyModule::Legacy' =>
      {
          datasource        => 'mymodule_datasource_is_too_long',
          replaced_by_class => 'MyModule',
      },
  );

  defined( my $migrated_count = MyModule::Legacy->migrate_data() )
      or return $app->error( 'Migration error: '
                            . MyModule::Legacy->errstr );

  MyModule::Legacy->remove_datasource
    or return $app->error( 'Error removing table: '
                          . MyModule::Legacy->errstr );

=head1 DESCRIPTION

This package is intended for use by upgrade scripts to assist in what should
be the simple process of changing the datasource property of an MT::Object
subclass which is necessary when you initially choose poorly (e.g. a name that
is too long, in conflict with another or annoyingly ambiguous).

This is, however, not a simple process because the datasource is used as to
namespace not only the database table but also all columns, indexes and
sequences, thwarting the most obvious route of issuing a single C<ALTER TABLE
table RENAME TO>. SQLite's lack of awesomeness also hnders this
straightforward approach.

Hence, this class makes the alternate approach simple.  That approach entails:

=over 4

=item 1. B<Modifying the datasource property> of the MT::Object subclass.

This will be seen by MT::Upgrade as a core schema inconsistency which it will
immediately rectify by automatically creating the new table.

=item 2. B<Creating a one-time use "legacy class"> based on the original class
but pointing to the old datasource. 

This is necessary if, in fact, you would like to be able to access your
existing data. It's important though that this class not be instantiated
*after* the migration since (as in step 1) it would be automatically
recreated.

=item 3. B<Data migration from the legacy table to the new table>

Made significantly easier by use of this class

=back

=cut

#############################################################################

=head1 METHODS

=head2 MT::Object::LegacyFactory->init_class( $legacy_class, \%properties )

This method is responsible for dynamically creating and initializing the
legacy class you use to access your existing data. This class inherits from
the current/"new" class and makes only the following changes:

=over 4

=item * Modifies the datasource to match the previous, legacy value

=item * Undefines the C<get_driver> property which was initialized by the new
class and points to the new datasource. The property can then be properly
initialized to work with the legacy datasource.

=item * Adds three methods to the legacy class: C<clone_as>, C<migrate_data>
and C<remove_datasource>

=cut
sub init_class {
    my $self              = shift;
    my ( $class, $props ) = @_;
    my $new_class         = $props->{replaced_by_class};
    $new_class->require or die $@;

    {
        no strict 'refs';
        @{ $class.'::ISA' } = ( $new_class );
        *{ $class."::$_" }  = $self->can( $_ )
            foreach qw( clone_as  migrate_data  remove_datasource );
    }

    no warnings 'once';
    $Storable::Deparse = $Storable::Eval = 1;
    my $superprops_copy = dclone( $new_class->properties() );
    $props->{get_driver} ||= undef;     # Reset this to get legacy driver
    $props = { %$superprops_copy, %$props };

    $class->install_properties( $props );
    $class->properties();
}

=head2 Class->migrate_data( $new_class )

This legacy class method initiates the migration of data from its datasource
to the new datasource, the latter of which can be specified by passing the new
class as an argument. In lieu of that, the method will look for the
C<replaced_by_class> property value of the legacy class set through this
class' C<init_class> method.

=cut
sub migrate_data {
    my $pkg     = shift;
    my $cnt     = $pkg->count() or return 0;
    my $new_pkg = shift || $pkg->properties->{replaced_by_class}
        or return $pkg->error('No replaced_by_class specified for '.$pkg);
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    ###l4p $logger->info( "Updating $pkg to $new_pkg. Count of objects: ".$pkg->count() );

    # Iterate over each record in legacy table
    # and save cloned record to new table
    my $iter = $pkg->load_iter()
        or return $pkg->error("Could not get object iterator for $pkg: "
                                .($pkg->errstr||'Unknown error'));
    while ( my $obj = $iter->() ) {
    # my @objs = $pkg->load();
    # foreach my $obj (@objs) {

        use Data::Dumper;
        ###l4p $logger->info("Cloning the object: " .Dumper($obj) );

        # Clone the object as the new class and save
        my $new = $obj->clone_as( $new_pkg );

        $new->save or return $pkg->error( sprintf(
            "Failed saving %s clone of %s object ID %d: %s", 
                $new_pkg, $pkg, $obj->id, $new->errstr
        ));

        # Remove old object
        $obj->remove or return $pkg->error(
            'Failed removing legacy object:'.$obj->errstr );

        ###l4p $logger->debug(sprintf('Saved %s object to new table %s',
        ###l4p                        $pkg, $new_pkg->table_name));
    }
    return $cnt;
}

=head2 $obj->clone_as( $new_class )

This instance method clones an object's data and reblesses the object into the
class specified it's only argument.

=cut
sub clone_as {
    my $self = shift;
    my $class = shift or croak "No class specified";
    my $new = $self->clone_all();
    bless $new, $class;
}

=head2 Class->remove_datasource()

This legacy class method causes the removal of the class' datasource. DANGER:
There is no check for existing records nor any niceties. Make sure you
actually want to call this method before you even type it into your text
editor.

=cut
sub remove_datasource {
    my $pkg = shift;
    croak 'remove_datasource is a class method' if ref $pkg;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    my $driver  = $pkg->dbi_driver;
    my $ddl     = $driver->dbd->ddl_class;
    my $dropsql = $ddl->drop_table_sql( $pkg );
    ###l4p $logger->info('DROP TABLE SQL: ', $dropsql);

    $driver->sql( [ $dropsql ])
        or return $pkg->error('Failed removing table: '.$driver->errstr);
    1;
}

1;

__END__
