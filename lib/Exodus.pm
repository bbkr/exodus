package Exodus;

use v5.10;
use strict;
use warnings;

use DBI;
use Clone;

=head1 NAME

Exodus

=head1 DESCRIPTION

Tool that allows to extract subtree of rows from relational database.

=head1 SYNOPSIS

    my $exodus = Exodus->new(
        'database' => $dbh,
        'root' => 'clients',
        'relations' => [ # optional
            {
                'nullable'      => 0,
                'parent_table'  => 'foo',
                'parent_column' => 'id'
                'child_table'   => 'bar',
                'child_column'  => 'foo_id',
            },
            { ... }
        ]
    );
    
    $exodus->extract( 'id' => 1 );

=head1 METHODS

=head3 new

Params

C<root> - Table that holds top record that every extracted data belongs to.

C<relations> - Helps to define relations between tables that are not declared in regular way.
For example MySQL partitioned tables or TokuDB tables do not support foreign keys.
If foreign key column can be NULL this should be marked as nullable.

=cut

sub new {
    my ($class, %params) = @_;
    
    # find all relations between tables
    # merge them with provided relations (if any)
    my $query_relations = q{
        SELECT IF(c.`is_nullable` = 'yes', true, false) AS nullable,
            kcu.`referenced_table_name` AS parent_table, kcu.`referenced_column_name` AS parent_column,
            kcu.`table_name` AS child_table, kcu.`column_name` AS child_column
        FROM `information_schema`.`key_column_usage` AS kcu
        JOIN `information_schema`.`columns` AS c
            ON kcu.`table_schema` = c.`table_schema`
            AND kcu.`table_name` = c.`table_name`
            AND kcu.`column_name` = c.`column_name`
        WHERE kcu.`table_schema` = DATABASE( )
            AND kcu.`referenced_table_schema` = DATABASE( )
            AND kcu.`constraint_schema` = DATABASE( )
    };
    my $statement_relations = $params{'database'}->prepare($query_relations);
    $statement_relations->execute();
    while (my $row_relation = $statement_relations->fetchrow_hashref()) {
        # TODO self-loop protection
        push @{$params{'relations'} //= []}, $row_relation;
    }
    
    # find best path to every table,
    # paths win first by nullability (not nullable is better)
    # and if there is a tie they win by length (shorter is better)
    my $subtree;
    $subtree = sub {
        my ( $table, @stack ) = @_;

        for my $relation (@{$params{'relations'}}) {

            # remove self-reference
            next if $relation->{'parent_table'} eq $relation->{'child_table'};

            # child relations are skipped
            next unless $relation->{'parent_table'} eq $table;

            # call recursively for all children and push current relation on stack
            $subtree->( $relation->{'child_table'}, @stack, $relation );
        }

        # register table if not already known
        $table = $params{'tables'}->{$table} //= {
            'name'  => $table,
            'level' => 0,
            'path'  => undef,
        };

        # bump table level to longest relation chain observed
        $table->{'level'} = int @stack if $table->{'level'} < int @stack;

        # path to table is already known
        # check if it is optimal compared to new stack
        if ( defined $table->{'path'} ) {

            # check if path and stack have NULL relation along the way
            my $is_nullable_path = ( grep { $_->{'nullable'} } @{ $table->{'path'} } ) ? 1 : 0;
            my $is_nullable_stack = ( grep { $_->{'nullable'} } @stack ) ? 1 : 0;

            # path and stack have the same NULL presence status so shorter one wins
            if ( not( $is_nullable_path xor $is_nullable_stack ) ) {
                $table->{'path'} = Clone::clone \@stack if int @stack < int @{ $table->{'path'} };
            }

            # stack without NULL wins with path with NULL,
            # length is less relevant and not important in this case
            elsif ( $is_nullable_path and not $is_nullable_stack ) {
                $table->{'path'} = Clone::clone \@stack;
            }
        }

        # path to table was not known
        # add current one
        else {
            $table->{'path'} = Clone::clone \@stack;
        }
    };
    $subtree->($params{'root'});
    
    return bless \%params, $class;
}

=head3 extract

Find all rows that belong to this one in root table.
Print queries for inserting those rows as single transaction.

=cut

sub extract {
    my ($self, $key, $value) = @_;

    printf '-- `%s`.`%s` = %s' . $/, $self->{'root'}, $key, $self->{'database'}->quote( $value );
    print 'BEGIN;', $/;
    
    for my $table ( sort { $a->{'level'} <=> $b->{'level'} } values %{ $self->{'tables'} } ) {

        my $query_select = sprintf q{SELECT `%s`.* FROM `%s`}, $table->{'name'}, $self->{'root'};
        for my $relation ( @{ $table->{'path'} } ) {
            $query_select .= sprintf q{ JOIN `%s` ON `%s`.`%s` = `%s`.`%s`},
                @{$relation}{ 'child_table', 'parent_table', 'parent_column', 'child_table', 'child_column' };
        }
        $query_select .= sprintf qq{ WHERE `%s`.`%s` = ?;}, $self->{'root'}, $key;
        print '-- ', $query_select, $/;
        
        my $statement_select = $self->{'database'}->prepare( $query_select );
        $statement_select->execute( $value );
        while (my $row_select = $statement_select->fetchrow_hashref()) {
            my ( @columns, @values );
            while ( my ( $column, $value ) = each %{$row_select} ) {
                next unless defined $value;
        
                push @columns, sprintf '`%s`', $column;
                push @values, $self->{'database'}->quote($value);
            }
        
            my $query_insert = sprintf qq{INSERT INTO `%s` (%s) VALUES (%s);}, $table->{'name'},
                join( ', ', @columns ), join( ', ', @values );
            print $query_insert, $/;
        }
    }

    print 'COMMIT;', $/;
}

=head1 AUTHORS

Pawel bbkr Pabian
@GetResponse.com

=head1 LICENCE

Released under Artistic License 2.0.

=cut

1;
