use strict; use warnings;
use YAML::Tiny;

my @docs;
{ open my $ef, '<:utf8', '_data/scripts.yaml' or die $!;
  @docs = Load(do { local $/; <$ef> });
}

my %oldmeta;
for (@{$docs[0]//[]}) {
    $oldmeta{$_->{filename}} = $_;
}

my %newmeta;
for my $file (<scripts/*.pl>) {
    my ($filename, $base) =
	$file =~ m,^scripts/((.*)\.pl)$,;
    my $info_file = "Test/$base/info.yml";
    my @cdoc;
    if (-f $info_file && open my $ef, '<:utf8', $info_file) {
	local $@;
	@cdoc = eval { Load(do { local $/; <$ef> }); };
	if ($@) {
	    print "ERROR $base: $@\n";
	    @cdoc=();
	}
    }
    if (@cdoc) {
	$newmeta{$filename} = $cdoc[0][0];
	for my $copykey (qw(modified version)) {
	    unless (defined $newmeta{$filename}{$copykey}) {
		$newmeta{$filename}{$copykey}
		    = $oldmeta{$filename}{$copykey}
			if defined $oldmeta{$filename}{$copykey};
	    }
	}
	$newmeta{$filename}{filename} = $filename;
	my $modules = delete $newmeta{$filename}{modules};
	$newmeta{$filename}{modules}
	    = join ' ', @$modules
		if 'ARRAY' eq ref $modules;
    }
    elsif (exists $oldmeta{$filename}) {
	print "META-INF FOR $base NOT FOUND\n";
	system "ls 'Test/$base/'*";
	$newmeta{$filename} = $oldmeta{$filename};
    }
    else {
	print "MISSING META FOR $base\n";
    }
}
my @newdoc = map { $newmeta{$_} } sort keys %newmeta;
{ open my $ef, '>:utf8', '_data/scripts.yaml' or die $!;
  print $ef Dump \@newdoc;
}

my @config;
if (open my $ef, '<:utf8', '_testing/config.yml') {
    @config = Load(do { local $/; <$ef> });
}
if (@config && @{$config[0]{whitelist}//[]}) {
    my $changed;
    my @wl;
    for my $sf (@{$config[0]{whitelist}}) {
	if (-s "Test/$sf:passed") {
	    $changed = 1;
	}
	else {
	    push @wl, $sf;
	}
    }
    if ($changed) {
	$config[0]{whitelist} = \@wl;
	{ open my $ef, '>:utf8', '_testing/config.yml' or die $!;
	  print $ef Dump @config;
        }
    }
}

if (exists $ENV{REPO_LOGIN_TOKEN} && exists $ENV{TRAVIS_REPO_SLUG}) {
    { open my $cred, '>', "$ENV{HOME}/.git-credentials" or die $!;
      print $cred "https://$ENV{REPO_LOGIN_TOKEN}:x-oauth-basic\@github.com\n";
    }
    system qq[
git config user.email "scripts\@irssi.org"
git config user.name "Irssi Scripts Helper"
git config credential.helper store
git config remote.origin.url https://github.com/$ENV{TRAVIS_REPO_SLUG}
git checkout '$ENV{TRAVIS_BRANCH}'
if [ "\$(git log -1 --format=%an)" != "\$(git config user.name)" -a \\
     "\$(git log -1 --format=%cn)" != "\$(git config user.name)" ]; then
    git add _data/scripts.yaml
    git commit -m 'automatic scripts database update for $ENV{TRAVIS_COMMIT}

[skip ci]'
    git config push.default simple
    git push origin
fi
];
}
