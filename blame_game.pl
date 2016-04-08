#!/usr/bin/perl
#
# Find out who has been naughty in svn
# Copyright (C) 2009 Joel
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use warnings;
use strict;
use Term::ANSIColor;
use Getopt::Long;
use Pod::Usage;

# Start configuration section

# Location of your svn binary
my $svn_binary = '/usr/bin/svn';

# the diff command to use
my $diff_command = $svn_binary . ' diff --config-dir=/tmp -r';

# the svn log command to use
my $log_command = $svn_binary . ' log';

#  End configuration section

# Set a default direction to parse logs
my $log_parse_direction = 'new';

my $help;

# Find out which direction they want to search svn
my $results = GetOptions("direction=s" => \$log_parse_direction, 'help|?' => \$help);

# Check to see if they want help
if ($help)
{
	pod2usage(1);
}

# Make sure they pass in enough arguments
if (@ARGV < 2)
{
	pod2usage("$0: missing arguments");
}

# input, a file to look for where code changed, and the code we're looking for
my $file = $ARGV[0];
my $code = $ARGV[1];

# make sure they pass a file
unless (-e $file)
{
	die("File: '$file' doesn't seem to exist\n");
}

# let's get a list of revisions
my $raw_data = `$log_command -q $file`;

# let's drop that into an array
my @raw_revisions = split("\n", $raw_data);

# We'll use this var to store the revision numbers to do a diff against
my @revisions;

# Find each rev and push it to our array to use later
foreach my $possible_revision (@raw_revisions)
{
	if ($possible_revision =~ /^r(\d{1,})\s*\|/)
	{
		push(@revisions, $1);
	}
}

unless ($log_parse_direction eq 'old')
{
	my @reversed_revisions = reverse(@revisions);
	@revisions = @reversed_revisions;
}

# used to keep track of where we are in the diff
my $left_revision = pop(@revisions);
my $right_revision;

# loop through and diff every revision against it's neighbor
while ($right_revision = pop(@revisions))
{
	# Store the diff
	my $diff_output;
	
	if ($log_parse_direction eq 'old') 
	{
		$diff_output = `$diff_command $left_revision:$right_revision $file`;
	}
	else
	{
		$diff_output = `$diff_command $right_revision:$left_revision $file`;
	}

	# Store each section of the diff, if we get a match we only want to print 
	# the relevant section
	my @diffs = split(/@@/, $diff_output);

	# Have we printed the header or not?
	my $print_header = 0;

	# if we find the code snippet, print where we found it, and what we found
	my $color_code = color("red") . $code . color("reset");

	foreach my $position (0..scalar(@diffs))
	{	
		my $diff = $diffs[$position];

		# Only print a diff chunk if it contains our code
		if ($diff && $diff =~ /^[+-].*?\Q$code\E/m)
		{
			if ($print_header == 0)
			{
				print color("green") . "Code found at $diff_command $left_revision:$right_revision $file\n" . color("reset");
				print "$diffs[0]\n\n";
				$print_header++;
			}
			$diff =~ s/^([+-].*?)$code/$1$color_code/mg;
			print $diffs[$position - 1] . "\n";
			print "$diff\n";

			print color("green") . "Log message:\n" . color("reset");
			print `$log_command -vr $left_revision`;	

			# Give the user time to review the diff
			print STDERR "Press enter to continue\n";
			<STDIN>;
			print STDERR "Searching....\n\n";
		}
	}
	$left_revision = $right_revision;
}

__END__

=head1 NAME

bame_game.pl

=head1 SYNOPSIS

blame_game.pl [options] <file> <code>

Options: 
	-help: 		brief help message
	-d:		pass the value of old if you want to search old to new

=head1 OPTIONS

=over 8

=item B<-help>
Print a brief help message

=item B<-d>
Takes a single value, "old", to start searching oldest revisions first

=back

=head1 DESCRIPTION

B<blame_game.pl> will search SVN for differences which contain the code you specified

=cut 
