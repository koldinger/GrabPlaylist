# GrabPlaylist.pm by Eric Koldinger (kolding@yahoo.com) October, 2004
#
# This code is derived from code with the following copyright message:
#
# SlimServer Copyright (C) 2001 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
use strict;

###########################################
### Section 1. Change these as required ###
###########################################

package Plugins::GrabPlaylist;

use Slim::Utils::Strings qw (string);
use Slim::Utils::Misc;
use Slim::Player::Player;
use Slim::Player::Client;

# Export the version to the server
use vars qw($VERSION);
$VERSION = "0.2";

sub getDisplayName() { return "PLUGIN_GRABPLAYLIST_NAME" };

sub strings() {
    local $/ = undef;
    <DATA>;
};

##################################################
### Section 2. Your variables and code go here ###
##################################################

my %positions = ();
my %clientLists = ();
my %numClients = ();

sub setMode {
	my $client = shift;
	$positions {$client} = 0 if (!defined $positions{$client});
	my @clients = otherClients($client);
        $clientLists{$client} = \@clients;
	$numClients{$client} = $#clients + 1;
	$::d_plugins && msg("Setting mode for " . $client->name() . ": $numClients{$client} clients\n");
	$client->lines(\&lines);
}

sub enabled { 
    my $client = shift;
# $::d_plugins && msg("Checking enabled\n");
    my $numClients = Slim::Player::Client::clientCount();
	# make sure there's more than one
	return ($numClients > 1);
}

my %functions = (
	'up' => sub { 
		my $client = shift;
                my $newPos = Slim::Buttons::Common::scroll
				($client, -1, $numClients{$client},
				$positions{$client});
                $positions{$client} = $newPos;
		$client->update();
	},
        'down' => sub  {
                my $client = shift;
                my $newPos = Slim::Buttons::Common::scroll
				($client, +1, $numClients{$client},
				$positions{$client});
                $positions{$client} = $newPos;
		$client->update();
	},
	'left' => sub {
		my $client = shift;
		Slim::Buttons::Common::popModeRight($client);
	},
	'right' => sub {
		my $client = shift;
		$client->bumpRight();
	},
	'play' => sub {
		my $client = shift;
		my ($line1, $line2);
		$line1 = string('PLUGIN_GRABPLAYLIST_NAME');
		$line2 = string('PLUGIN_GRABPLAYLIST_COPYING') . " " .
			 Slim::Player::Client::name(clientAt($client, $positions{$client}));
		# Slim::Control::Command::execute($client, \@pargs, undef, undef);
		my $other = clientAt($client, $positions{$client});
		Slim::Control::Command::execute($client, ['stop']);
		$client->showBriefly($line1, $line2);
		Slim::Player::Playlist::copyPlaylist($client, $other);
		Slim::Control::Command::execute($other, ['stop']);
		Slim::Control::Command::execute($client, ['play']);
		# $other->execute("stop");
	}
);

sub clientAt {
    my $client = shift;
    my $pos = shift;
    return undef if ($pos < 0 || $pos >= $numClients{$client});
    return @{$clientLists{$client}}[$pos];
}

sub otherClients {
    my $client = shift;
    my @clients = ();
    $::d_plugins && msg("Generating Clients list for " . $client->name() . "\n");
    foreach my $i (Slim::Player::Client::clients()) 
    {
	if ($i != $client) {
	    $::d_plugins && msg("   " . $i->name() . "\n");
	    push @clients, $i;
	}
    }
    $::d_plugins && msg("Got " . ($#clients + 1) . " clients\n");
    return @clients;
}

sub lines {
	my $client = shift;
	my ($line1, $line2);
	#$::d_plugins && msg("Generating lines for " . $client->name() . ": $positions{$client}\n");
	#$::d_plugins && msg("ClientAt($positions{$client}): " . clientAt($client, $positions{$client}) . "\n");
	$line1 = string('PLUGIN_GRABPLAYLIST_SELECT_PLAYER');
	$line2 = Slim::Player::Client::name(clientAt($client, $positions{$client}));
	return ($line1, $line2);
}

sub initPlugin {
    $::d_plugins && msg(string('PLUGIN_GRABPLAYLIST_STARTING'));
}

sub shutdownPlugin {
    $::d_plugins && msg(string('PLUGIN_GRABPLAYLIST_STOPPING'));
}
	
################################################
### End of Section 2.                        ###
################################################

sub getFunctions() {
	return \%functions;
}

1;

__DATA__

PLUGIN_GRABPLAYLIST_NAME
	EN	Grab Playlist

PLUGIN_GRABPLAYLIST_SELECT_PLAYER
	EN	Select Player.  Press PLAY to copy.

PLUGIN_GRABPLAYLIST_COPYING
	EN	Copying playlist from player

PLUGIN_GRABPLAYLIST_STARTING
	EN	Grab Playlist Starting

PLUGIN_GRABPLAYLIST_STOPPING
	EN	Grab Playlist Shutting Down
