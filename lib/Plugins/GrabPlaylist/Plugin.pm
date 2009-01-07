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

package Plugins::GrabPlaylist::Plugin;

use base qw(Slim::Plugin::Base);

use Slim::Utils::Strings qw (string);
use Slim::Utils::Misc;
use Slim::Utils::Log;
use Slim::Player::Player;
use Slim::Player::Client;

my $log = Slim::Utils::Log->addLogCategory({
	'category' => 'plugin.grabplaylist',
	'defaultLevel' => 'INFO',
	'description' => 'PLUGIN_GRABPLAYLIST_NAME'
});

sub getDisplayName() {
	return 'PLUGIN_GRABPLAYLIST_NAME';
}

##################################################
### Section 2. Your variables and code go here ###
##################################################

my %positions = ();
my %clientLists = ();
my %numClients = ();

sub setMode {
	my $class = shift;
	my $client = shift;

	$positions {$client} = 0 unless defined $positions{$client};

	my @clients = otherClients($client);
	$clientLists{$client} = \@clients;
	$numClients{$client} = $#clients + 1;
	$log->debug("Setting mode for " . $client->name() . ": $numClients{$client} clients");
	$client->lines(\&lines);
}

my %functions = (
	'up' => sub { 
		my $client = shift;
		if ($numClients{$client} == 1) {
			#noClientsError($client);
			$client->bumpUp();
			return;
		}
		my $newPos = Slim::Buttons::Common::scroll ($client,
													-1,
													$numClients{$client},
													$positions{$client});
		$positions{$client} = $newPos;
		$client->update();
	},
		'down' => sub  {
				my $client = shift;
		if ($numClients{$client} == 1) {
			# noClientsError($client);
			$client->bumpDown();
			return;
		}
		my $newPos = Slim::Buttons::Common::scroll ($client,
													+1,
													$numClients{$client},
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
		$client->showBriefly({'line1' => $line1, 'line2' => $line2});
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
		$client->showBriefly({'line1' => $line1, 'line2' => $line2});
		transferPlaylist($other, $client);
	},
);

sub transferPlaylist {
	my $dest = shift;
	my $source = shift;

	$log->debug("transferPlaylist: " . $dest->name() . " " . $source->name());

	Slim::Control::Request::executeRequest($dest, ['stop']);

	my $offset = Slim::Player::Source::songTime($source);

	Slim::Player::Playlist::copyPlaylist($dest, $source);
	Slim::Control::Request::executeRequest($source, ['stop']);
	Slim::Control::Request::executeRequest($dest, ['play']);
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
	$log->debug("Generating Clients list for " . $client->name());
	foreach my $i (Slim::Player::Client::clients()) 
	{
		if ($i != $client) {
			$log->debug("   " . $i->name());
			push @clients, $i;
		}
	}
	$log->debug("Got " . ($#clients + 1) . " clients");
	return @clients;
}

sub lines {
	my $client = shift;
	my ($line1, $line2);
	$log->debug("Generating lines for " . $client->name() . ": $positions{$client}: " .
			$numClients{$client});
	$line1 = string('PLUGIN_GRABPLAYLIST_SELECT_PLAYER');
	if ($numClients{$client} == 0)
	{
		$log->debug($client->name() . ":: " .  string('PLUGIN_GRABPLAYLIST_NONE'));
		$line2 = string('PLUGIN_GRABPLAYLIST_NONE');
	} else {
		$log->debug("ClientAt($positions{$client}): " . clientAt($client, $positions{$client})->name());
		$line2 = Slim::Player::Client::name(clientAt($client, $positions{$client}));
	}
	return { 'line1' => $line1, 'line2' => $line2 };
}

sub noClientsError {
	my $client = shift;
	my ($line1, $line2);
	$line1 = string('PLUGIN_GRABPLAYLIST_NAME');
	$line2 = string('PLUGIN_GRABPLAYLIST_NO_OTHERS');
	$client->showBriefly({ 'line1' => $line1, 'line2' => $line2 });
}

sub initPlugin {
	my $class = shift;
	$class->SUPER::initPlugin(@_);

	$log->info(string('PLUGIN_GRABPLAYLIST_STARTING'));

    Slim::Control::Request::addDispatch(['gbTop'],[1, 1, 0, \&gbTop]);
    Slim::Control::Request::addDispatch(['gbTransfer'],[1, 1, 1, \&gbTransfer]);
 
    my @menu = ({
        text   => string('PLUGIN_GRABPLAYLIST_NAME'),
        id     => 'pluginGrabplaylist',
        weight => 1,
        actions => {
            go => {
                player  => 0,
                cmd     => [ 'gbTop' ],
            }
        },
    });
    Slim::Control::Jive::registerPluginMenu(\@menu, 'extras');
}


#sub shutdownPlugin {
	#$log->info(string('PLUGIN_GRABPLAYLIST_STOPPING') . ");
#}
	
################################################
### End of Section 2.						###
################################################

sub getFunctions() {
	return \%functions;
}

################################################
### Section 3.  Jive Menus                   ###
################################################

sub gbTop {
    my $request = shift;
    my $client = $request->client();
    $log->debug("gbTop called " . $client->name());
    my @menu = ();

    my @clients = otherClients($client);
    foreach my $other (@clients) {
		$log->debug("Adding " . $other->name);
        push @menu, {
            text	=> $other->name(),
            window  => { menuStyle => 'album' },
            actions => {
                do  => {
                    player  => 0,
                    cmd     => [ 'gbTransfer' ],
                    params  => {
                        menu    => 'gbTransfer',
                        source  => $other->id(),
                        dest    => $client->id(),
                    },
                },
                play => {
                    player  => 0,
                    cmd     => [ 'gbTransfer' ],
                    params  => {
                        menu    => 'gbTransfer',
                        source  => $other->id(),
                        dest    => $client->id(),
                    },
				},
                add => {
                    player  => 0,
                    cmd     => [ 'gbTransfer' ],
                    params  => {
                        menu    => 'gbTransfer',
                        source  => $client->id(),
                        dest    => $other->id(),
                    },
				},
            },
        };
    }

    packageResponse($request, \@menu);

    $request->setStatusDone();
}

sub gbTransfer {
    my $request = shift;
	my $source = $request->getParam('source');
	my $dest   = $request->getParam('dest');
    $log->debug("gbTransfer called " . $request->client()->name() . " " . $source . " to " . $dest);

	transferPlaylist(Slim::Player::Client::getClient($dest), Slim::Player::Client::getClient($source));

    $request->setStatusDone();
}

sub packageResponse {
    my $request = shift;
    my $menu    = shift;
    my $numitems = scalar(@$menu);

    $log->debug("packageResponse: $numitems");
 
    $request->addResult("count", $numitems);
    $request->addResult("offset", 0);
    my $cnt = 0;
	my $end = $numitems - 1;

	for my $eachmenu (@$menu[0..$end]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachmenu);
		$cnt++;
	}
}

1;
