package Tratten::Monitored;

use strict;
use warnings;
use Tratten::Throttle;
use base 'Exporter';
our @EXPORT = qw(get_monitored);

sub get_monitored {
  my $filename = "changedetection.account";
  open my $F, $filename or die "Could not open file '$filename': $!";

  chomp(my $email = <$F>);
  chomp(my $password = <$F>);
  die("Need email & password each on its own line, in the changedetection.account file. Quitting.") unless $email and $password;

  my $args = "-# --sslv3 --cookie-jar cookies";
  my $form = "-F 'email=$email' -F 'frompage=http://www.changedetection.com/monitors.html' -F 'login=log in' -F 'op=login' -F 'pw=$password'";

  `curl $args --url https://www.changedetection.com/index.html`;
  $_ = `curl $args --cookie cookies $form -L --url https://www.changedetection.com/login.html`;

  my %ret;

  do {
    while (/<a href="(\/log\/[^"]+)" title="([^ ]+)\s+([^"]+)".+?href="([^"]+)"/g) {
      print STDERR "Warning: Reference number $2 is not unique!\n" if $ret{$2};
      $ret{$2} = ["http://www.changedetection.com$1", $3, $4];
    }
  } while (/<a href='(\/monitors\.html\?rclstart=\d+)'>next<\/a>/
           and ($_ = `curl $args --cookie cookies --url https://www.changedetection.com$1`, 1));

  return \%ret;
}

1;
