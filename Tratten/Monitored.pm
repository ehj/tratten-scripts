package Tratten::Monitored;

use strict;
use warnings;
use Tratten::Cache;
use Tratten::Dossier;

our %uri;
our %refnum;

sub dossier {
  my $monitor = (ref $_[0] && $_[0]) || $uri{$_[0]} || $refnum{$_[0]} || die;
  unless ($monitor->{uri} =~ m(^http://www\.europarl\.europa\.eu/oeil/file\.jsp\?id=\d+$)) {
    print STDERR "WARNING: Not a dossier $monitor->{uri}\n";
    return undef;
  }
  my $page_content = &Tratten::Cache::URI($monitor->{uri},
    expire_if => sub { $_[0]->{CD_last_notified} ne $monitor->{last_notified} },
    meta => { CD_last_notified => $monitor->{last_notified} },
  );
  my $dossier = Tratten::Dossier::parse($page_content);
  $dossier->{monitor} = $monitor;
  return $dossier;
}

my $email;
my $password;

{
  &_load_account_info;
  my $key = "monitors:$email";
  my $cached = &Tratten::Cache::get($key);
  if ($cached) {
    print STDERR "Loading changedetection data from cache...\n";
    %uri = %{ $cached };
    for (keys %uri) { $refnum{$uri{$_}->{refnum}} = $uri{$_} if $uri{$_}->{refnum} }
  } else {
    print STDERR "Logging in to changedetection...\n";
    &_fetch_monitors;
    &Tratten::Cache::set($key, \%uri, "1 day");
  }
  my $number_monitored = keys %uri;
  print STDERR "$number_monitored pages are monitored.\n";
}

sub _load_account_info {
  my $filename = "changedetection.account";
  open my $F, $filename or die "Could not open file '$filename': $!";

  chomp($email = <$F>);
  chomp($password = <$F>);
  die("Need email & password each on its own line, in the changedetection.account file. Quitting.") unless $email and $password;
}

sub _fetch_monitors {
  my $args = "-# --sslv3 --cookie-jar cookies";
  my $form = "-F 'email=$email' -F 'frompage=http://www.changedetection.com/monitors.html' -F 'login=log in' -F 'op=login' -F 'pw=$password'";

  `curl $args --url https://www.changedetection.com/index.html`;
  $_ = `curl $args --cookie cookies $form -L --url https://www.changedetection.com/login.html`;

  do {
    while (/<input\s.+?<td\s.+?>(.*?)<\/td>.+?<a href="(\/log\/[^"]+)" title="([^"]+)".+?href="([^"]+)"/g) {
      my %x = (
        log => "http://www.changedetection.com$2",
        name => $3,
        uri => $4,
        last_notified => $1,
      );
      if ($x{name} =~ /^([^ ]+)\s+(.+)$/) {
        $x{refnum} = $1; $x{desc} = $2;
        print STDERR "WARNING: Reference number $x{refnum} is not unique!\n" if $refnum{$x{refnum}};
        $refnum{$x{refnum}} = \%x;
      }
      print STDERR "WARNING: Monitored URI is not unique: $x{uri}!\n" if $uri{$x{uri}};
      $uri{$x{uri}} = \%x;
    }
  } while (/<a href='(\/monitors\.html\?rclstart=\d+)'>next<\/a>/
           and ($_ = `curl $args --cookie cookies --url https://www.changedetection.com$1`, 1));
}

1;
