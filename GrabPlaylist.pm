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
$VERSION = "0.5";

sub getDisplayName() {
	return substr ($::VERSION, 0, 1) >= 6 ? 'PLUGIN_GRABPLAYLIST_NAME' : string('PLUGIN_GRABPLAYLIST_NAME');
}

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
    return 1;
}

my %functions = (
	'up' => sub { 
		my $client = shift;
		if ($numClients{$client} == 0) {
		    #noClientsError($client);
		    $client->bumpUp();
		    return;
		}
                my $newPos = Slim::Buttons::Common::scroll
				($client, -1, $numClients{$client},
				$positions{$client});
                $positions{$client} = $newPos;
		$client->update();
	},
        'down' => sub  {
                my $client = shift;
		if ($numClients{$client} == 0) {
		    # noClientsError($client);
		    $client->bumpDown();
		    return;
		}
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
		# Make sure there's someplace to put it
		if ($numClients{$client} == 0) {
		    noClientsError($client);
		    return;
		}
		my $other = clientAt($client, $positions{$client});
		my $line1 = string('PLUGIN_GRABPLAYLIST_NAME');
		my $line2 = string('PLUGIN_GRABPLAYLIST_COPYING_FROM') . " " .  Slim::Player::Client::name($other);
		$client->showBriefly($line1, $line2);
		transferPlaylist($client, $other);
	},
	'add' => sub {
		my $client = shift;
		# Make sure there's someplace to put it
		if ($numClients{$client} == 0) {
		    noClientsError($client);
		    return;
		}
		my $other = clientAt($client, $positions{$client});
		my $line1 = string('PLUGIN_GRABPLAYLIST_NAME');
		my $line2 = string('PLUGIN_GRABPLAYLIST_SENDING_TO') . " " .  Slim::Player::Client::name($other);
		$client->showBriefly($line1, $line2);
		transferPlaylist($other, $client);
	},
);

sub transferPlaylist {
    my $dest = shift;
    my $source = shift;

    Slim::Control::Command::execute($dest, ['stop']);

    my $offset = Slim::Player::Source::songTime($source);

    Slim::Player::Playlist::copyPlaylist($dest, $source);
    Slim::Control::Command::execute($source, ['stop']);
    Slim::Control::Command::execute($dest, ['play']);
    Slim::Player::Source::gototime($dest, $offset, 1);
}

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
	if ($numClients{$client} == 0)
	{
	    $line2 = string('PLUGIN_GRABPLAYLIST_NONE');
	} else {
	    $line2 = Slim::Player::Client::name(clientAt($client, $positions{$client}));
	}
	return ($line1, $line2);
}

sub noClientsError {
    my $client = shift;
    my ($line1, $line2);
    $line1 = string('PLUGIN_GRABPLAYLIST_NAME');
    $line2 = string('PLUGIN_GRABPLAYLIST_NO_OTHERS');
    $client->showBriefly($line1, $line2);
}

sub initPlugin {
    $::d_plugins && msg(string('PLUGIN_GRABPLAYLIST_STARTING') . " -- $VERSION\n");
}

sub shutdownPlugin {
    $::d_plugins && msg(string('PLUGIN_GRABPLAYLIST_STOPPING') . " -- $VERSION\n");
}
	
################################################
### End of Section 2.                        ###
################################################

sub getFunctions() {
	return \%functions;
}

sub strings() {
    return "
PLUGIN_GRABPLAYLIST_NAME
	EN	Grab Playlist

PLUGIN_GRABPLAYLIST_SELECT_PLAYER
	EN	Select Player.  Press PLAY to copy.

PLUGIN_GRABPLAYLIST_COPYING_FROM
	EN	Copying playlist from player

PLUGIN_GRABPLAYLIST_SENDING_TO
	EN	Sending playlist to player

PLUGIN_GRABPLAYLIST_NO_OTHERS
	EN	No other players available

PLUGIN_GRABPLAYLIST_NONE
	EN	Nothing Available

PLUGIN_GRABPLAYLIST_STARTING
	EN	Grab Playlist Starting

PLUGIN_GRABPLAYLIST_STOPPING
	EN	Grab Playlist Shutting Down
";
}

1;
