#!/usr/bin/perl
use strict;
use warnings;
use LWP::Simple;
use Getopt::Long;
use File::Path;
use File::Copy;
use Archive::Extract;
use Cwd;

my $download_dir = 'downloads';
my $target_dir = 'target';
my $src_dir = 'src';
my $workdir = getcwd;
my $clean = '';

my %mvn = (
	name => 'maven repository',
	url => 'http://maven.repository.redhat.com/techpreview/eap6/6.1.0/jboss-eap-6.1.0-maven-repository.zip',
	file => 'jboss-eap-6.1.0-maven-repository.zip',
	folder => 'jboss-eap-6.1.0.GA-maven-repository'
);
my %src = (
	name => 'jboss eap src',
	url => 'http://ftp.redhat.com/redhat/jbeap/6.1.0/en/source/jboss-eap-6.1.0-src.zip',
	file => 'jboss-eap-6.1.0-src.zip',
	folder => 'jboss-eap-6.1-src'
);
####################

exit 3 unless GetOptions(
	'clean' => \$clean
);

####################
print "### SETUP SECTION\n";
print "working in $workdir\n";

# cleanup
if($clean) {
	print "cleaning target dir = $target_dir\n";
        rmtree $target_dir;
}

# create
unless(-e $download_dir) {
	print "creating download dir = $download_dir\n";
	mkdir($download_dir, 0775);
}
unless(-e $target_dir) {
        print "creating target dir = $target_dir\n";
        mkdir($target_dir, 0775);
}

#################################################
for my $hash ((\%mvn, \%src)) {
	my ($name, $url, $file, $folder) = ($hash->{name}, $hash->{url}, $hash->{file}, $hash->{folder});

	print "############# $name SECTION #############\n";
	print "processing $file\n";
	my $archive = "$download_dir/$file";
	if(-e $archive) {
		print "SKIPPED DOWNLOAD - $archive already exists\n";
	} else {
		print "downloading $file from $url\n";
		getstore($url, $archive);
	}

	# UNZIP
	my $unzipTarget = "$target_dir/$folder";
	my $usePatch = '1';
	if(-e $unzipTarget) {
		print "SKIPPED EXTRACT - target $unzipTarget already exists\n";
		$usePatch = '';
	} else {
		print "unzipping $file to $unzipTarget\n";
		my $ae = Archive::Extract->new( archive => $archive );
		$ae->extract( to => $target_dir ) or die $!;
	}
	
	# PATCH
	if($usePatch) {
		my $patch_file = "$src_dir/$folder.patch";
		if(-e $patch_file) {
			print "applying patch file $patch_file\n";
			chdir $unzipTarget;
			print "workdir is ", getcwd, "\n";
			my $cmd = "patch -p 1 < ../../$patch_file";
			print "executing: $cmd\n";
			print `$cmd`;
			die "patch failed" unless $? == 0;
			print "patch applied\n";
			chdir $workdir;
		} else {
			print "SKIPPED PATCH - file $patch_file not found\n"
		}
	} else {
		print "SKIPPED PATCH - maybe not working on a clean copy\n";
	}
}

print "############# BUILD SECTION #############\n";
my $repo = "file://$workdir/$target_dir/$mvn{folder}/";
print "eap repo: $repo\n";

my $settings = "$src_dir/settings.xml";
my $settings_target = "$target_dir/$src{folder}/tools/maven/conf/";
print "copy $settings to $settings_target\n";
copy($settings, $settings_target);

$ENV{EAP_REPO_URL}=$repo;
chdir "$target_dir/$src{folder}";
print "workdir is ", getcwd, "\n";
my $build_cmd = "./build.sh -DskipTests -Drelease=true";
open(BUILD, "$build_cmd |") or die "starting build failed: $!";
while(<BUILD>) {
	print $_;
}
close(BUILD);
exit 0;
