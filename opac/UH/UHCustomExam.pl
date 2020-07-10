#!/usr/bin/perl -w

use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);

my $q = new CGI;
my $ip = $ENV{'REMOTE_ADDR'};

my $showJS = 1;

my %listOfIPs = (
		"147.197.31.635" => 'sg13abk'
);

my %infoPointList = (

	"147.197.173.253" => 'CL-InfoPt-1C02',
	"147.197.173.254" => 'CL-InfoPt-1C06',
	"147.197.172.253" => 'CL-InfoPt-1S20',
	"147.197.172.254" => 'CL-InfoPt-1S22',
	"147.197.175.252" => 'CL-InfoPt-2C03',
	"147.197.174.252" => 'CL-InfoPt-2S12',
	"147.197.174.251" => 'CL-InfoPt-2S16',
	"147.197.170.251" => 'CL-InfoPt-GC08',
	"147.197.170.252" => 'CL-InfoPt-GC09',
	"147.197.170.209" => 'CL-InfoPt-GC14',
	"147.197.171.68" => 'CL-InfoPt-GC22',
	"147.197.170.213" => 'CL-InfoPt-GW105',
	"147.197.171.133" => 'CL-Infopt-GC00',
	"147.197.175.253" => 'CL-infopt-2C05',
	"147.197.171.211" => 'cl-ip-lrcg-01ip',
	"147.197.170.221" => 'cl-ip-lrcg-02ip',
	"147.197.209.254" => 'dh-ip-001',
	"147.197.210.253" => 'dh-ip-002',
	"147.197.210.254" => 'dh-ip-003',
	"147.197.212.253" => 'dh-ip-101',
	"147.197.212.254" => 'dh-ip-102',
	"147.197.212.252" => 'dh-ip-103',
	"147.197.214.253" => 'dh-ip-201',
	"147.197.214.254" => 'dh-ip-202',
	"147.197.214.252" => 'dh-ip-203',
);

print "Content-type: application/javascript\n\n";

if (exists $listOfIPs{$ip}) {
	# for testing/admins

print<<ENDOFJS

	angular.module('summonApp').run([ '\$templateCache', function (templateCache) {
		var searchInfo = "/assets/resultsFeed/searchInfo.html";
		var v = templateCache.get(searchInfo);
		v = v.replace(/<div class="holdingsOnly col hidden-tablet hidden-phone" ng-show="search.showHoldingsOnlyToggle">/,"<div class='holdingsOnly col hidden-tablet hidden-phone' ng-show='search.showHoldingsOnlyToggle' style='display:none'");
		templateCache.put(searchInfo, v);

		var docSummary = "/assets/documentSummary.html";
		var ds = templateCache.get(docSummary);
		ds = ds.replace(/<div permalink class="permalinkContainer" ng-if="document.bookmark">/,"<div permalink class='permalinkContainer' ng-if='document.bookmark' style='display:none'>");
		templateCache.put(docSummary, ds);

		var siteHelp = "/assets/help.html";
		var sh = templateCache.get(siteHelp);
		//sh = sh.replace(/links.localizedHelpTemplate/,"");
		//templateCache.put(siteHelp, sh);

		var libMyScope = '';

		\$(document).ready(function() {
			setTimeout(function() {
				libMyScope = angular.element('html').scope();
			}, 1000);

        // AND DO SOME OTHER STUFF JUST THE ONCE...
        libInitPage( );
});

	}]);

function libInitPage( ) {

        // OK, WE CAN'T ADD THE EXTRA LINKS IMMEDIATELY (15/OCT/2014)
        setTimeout(function() {
			\$('.languageSwitcher').css('display','none');
                        \$('.siteLinks').prepend('<div title="Request Items not held at UH" id="ill-link" text="Request Items not held at UH"><a href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-ill.pl">Request items not held at UH</a></div>');
                        \$('.siteLinks').prepend('<div title="Library Account" id="lib-link" text="Library Account"><a href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl">Library Account</a></div>');
                        \$('.siteLinks').prepend('<div title="Back to online library area in Studynet" id="ls-link" text="Back to online library area in Studynet"><a href="http://www.librarysearch.herts.ac.uk">Studynet Online Library</a></div>');
                        \$('.siteLinks').prepend('<div title="Exam Papers" id="exam-link" text="Exam Papers"><a href="http://libraryadmin.herts.ac.uk/exampapers/"><font size="4" color="red">Exam Papers</font></a></div>');
        }, 1000);
}


ENDOFJS
;

} else {

	if(exists($infoPointList{$ip})) {
		# do nothing at the moment
	} else {

	# for everyone to see
	if ($showJS) {

print<<ENDOFJS
var libMyScope = '';

\$(document).ready(function() {
        setTimeout(function() {
                libMyScope = angular.element('html').scope();
                // libInitWithScope( );
        }, 1000);

        // AND DO SOME OTHER STUFF JUST THE ONCE...
        libInitPage( );
});

function libInitPage( ) {

        // OK, WE CAN'T ADD THE EXTRA LINKS IMMEDIATELY (15/OCT/2014)
        setTimeout(function() {

			\$('.languageSwitcher').css('display','none');
                        \$('.siteLinks').prepend('<div title="Request Items not held at UH" id="ill-link" text="Request Items not held at UH"><a href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-ill.pl">Request items not held at UH</a></div>');
                        \$('.siteLinks').prepend('<div title="Library Account" id="lib-link" text="Library Account"><a href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl">Library Account</a></div>');
                        \$('.siteLinks').prepend('<div title="Back to online library area in Studynet" id="ls-link" text="Back to online library area in Studynet"><a href="http://www.librarysearch.herts.ac.uk">Studynet Online Library</a></div>');
                        \$('.siteLinks').prepend('<div title="Exam Papers" id="exam-link" text="Exam Papers"><a href="http://libraryadmin.herts.ac.uk/exampapers/"><font size="4" color="red">Exam Papers</font></a></div>');
        }, 1000);
}

ENDOFJS
;

	} else {
	}
	}
}
