#!/usr/bin/env perl
use strict;
use warnings;
use File::Path qw(make_path);

my @header = (0xFF, 0xFB, 0x90, 0x64);
my @side_info = (0x00) x 32;
$side_info[9]  = 0x02;
$side_info[17] = 0x40;
$side_info[24] = 0x08;
$side_info[31] = 0x01;
my @main_data = (0x00) x 381;
my $frame = pack("C*", @header, @side_info, @main_data);

my $base = "/Users/amangupta/Projects/instructor";
my %assets = (
    "app/assets/audio/ambient/rain.mp3"         => 192,
    "app/assets/audio/ambient/forest.mp3"        => 192,
    "app/assets/audio/ambient/ocean.mp3"         => 192,
    "app/assets/audio/ambient/white_noise.mp3"   => 192,
    "app/assets/audio/ambient/tibetan_bowls.mp3" => 192,
    "app/assets/audio/effects/bell.mp3"          => 38,
    "app/assets/audio/effects/chime.mp3"         => 38,
    "app/assets/audio/effects/gong.mp3"          => 38,
    "app/assets/audio/silence/silence.mp3"       => 38,
);

for my $rel (sort keys %assets) {
    my $path = "$base/$rel";
    if (-f $path && -s $path > 0) { print "SKIP: $rel\n"; next; }
    my $dir = $path;
    $dir =~ s|/[^/]+$||;
    make_path($dir);
    open(my $fh, ">:raw", $path) or die "Cannot write $path: $!";
    print $fh $frame x $assets{$rel};
    close $fh;
    my $size = -s $path;
    printf "Created %-50s (%d bytes)\n", $rel, $size;
}
print "Done.\n";
