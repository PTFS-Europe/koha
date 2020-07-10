#!/usr/bin/perl -w

use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);

my $q = new CGI;
my $ip = $ENV{'REMOTE_ADDR'};

my $showJS = 1;

my %listOfIPs = (
		"147.197.31.634" => 'sg13abk'
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
                        \$('#topLinks ul.customLinks:eq(1)').prepend('<li class="ng-scope" ng-repeat="link in links.links" bindonce=""><a class="customColorsSiteLink ng-scope" target="_blank" tabindex="0" ng-if="link.href" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl"><span class="ng-binding ng-scope" ng-bind-html="link.label" ng-if="!link.image">Request items not held at UH</span></a></li>');
                        \$('#topLinks ul.customLinks:eq(1)').prepend('<li class="ng-scope" ng-repeat="link in links.links" bindonce=""><a class="customColorsSiteLink ng-scope" target="_blank" tabindex="0" ng-if="link.href" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl"><span class="ng-binding ng-scope" ng-bind-html="link.label" ng-if="!link.image">Library Account</span></a></li>');
                        \$('#topLinks ul.customLinks:eq(1)').prepend('<li class="ng-scope" ng-repeat="link in links.links" bindonce=""><a class="customColorsSiteLink ng-scope" target="_blank" tabindex="0" ng-if="link.href" ng-href="http://www.librarysearch.herts.ac.uk" href="http://www.librarysearch.herts.ac.uk"><span class="ng-binding ng-scope" ng-bind-html="link.label" ng-if="!link.image">Studynet Online Library</span></a></li>');
                        \$('#topLinks ul.customLinks:eq(1)').prepend('<li class="ng-scope" ng-repeat="link in links.links" bindonce=""><a class="customColorsSiteLink ng-scope" target="_blank" tabindex="0" ng-if="link.href" ng-href="http://libraryadmin.herts.ac.uk/newbooks/" href="http://libraryadmin.herts.ac.uk/newbooks/"><span class="ng-binding ng-scope" ng-bind-html="link.label" ng-if="!link.image">New Books</span></a></li>');
			\$('.siteLinks .list-unstyled:eq(1)').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl" class="customColorsSiteLink ng-scope" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">Request items not held at UH</span></a></li>');
			\$('.siteLinks .list-unstyled:eq(1)').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl" class="customColorsSiteLink ng-scope" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">Library Account</span></a></li>');
			\$('.siteLinks .list-unstyled:eq(1)').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="http://www.librarysearch.herts.ac.uk" class="customColorsSiteLink ng-scope" href="http://www.librarysearch.herts.ac.uk"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">Studynet Online Library</span></a></li>');
			\$('.siteLinks .list-unstyled:eq(1)').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="http://libraryadmin.herts.ac.uk/newbooks/" class="customColorsSiteLink ng-scope" href="http://libraryadmin.herts.ac.uk/newbooks/"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">New Books</span></a></li>');
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
                        \$('#topLinks ul.customLinks').prepend('<li class="ng-scope" ng-repeat="link in ::links.links" ><a class="customColorsSiteLink ng-scope btn-link" role="button" target="_blank" tabindex="0" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl"><span class="ng-binding ng-scope" ng-bind-html="::link.label" ng-if="!link.image">Request items not held at UH</span></a></li>');
                        \$('#topLinks ul.customLinks').prepend('<li class="ng-scope" ng-repeat="link in links.links" bindonce=""><a class="customColorsSiteLink ng-scope" target="_blank" tabindex="0" ng-if="link.href" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl"><span class="ng-binding ng-scope" ng-bind-html="link.label" ng-if="!link.image">Library Account</span></a></li>');
                        \$('#topLinks ul.customLinks').prepend('<li class="ng-scope" ng-repeat="link in links.links" bindonce=""><a class="customColorsSiteLink ng-scope" target="_blank" tabindex="0" ng-if="link.href" ng-href="http://www.librarysearch.herts.ac.uk" href="http://www.librarysearch.herts.ac.uk"><span class="ng-binding ng-scope" ng-bind-html="link.label" ng-if="!link.image">Studynet Online Library</span></a></li>');
                        \$('#topLinks ul.customLinks').prepend('<li class="ng-scope" ng-repeat="link in links.links" bindonce=""><a class="customColorsSiteLink ng-scope" target="_blank" tabindex="0" ng-if="link.href" ng-href="http://libraryadmin.herts.ac.uk/newbooks/" href="http://libraryadmin.herts.ac.uk/newbooks/"><span class="ng-binding ng-scope" ng-bind-html="link.label" ng-if="!link.image">New Books</span></a></li>');
			\$('.siteLinks ul.list-unstyled  ul.customLinks').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl" class="customColorsSiteLink ng-scope" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-illrequests.pl"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">Request items not held at UH</span></a></li>');
			\$('.siteLinks .list-unstyled:eq(1)').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl" class="customColorsSiteLink ng-scope" href="https://library.herts.ac.uk/Shibboleth.sso/Login?target=https://library.herts.ac.uk/cgi-bin/koha/opac-user.pl"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">Library Account</span></a></li>');
			\$('.siteLinks .list-unstyled:eq(1)').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="http://www.librarysearch.herts.ac.uk" class="customColorsSiteLink ng-scope" href="http://www.librarysearch.herts.ac.uk"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">Studynet Online Library</span></a></li>');
			\$('.siteLinks .list-unstyled:eq(1)').prepend('<li ng-repeat="link in links.links" bindonce="" class="ng-scope"><a target="_blank" tabindex="0" ng-if="link.href" ng-href="http://libraryadmin.herts.ac.uk/newbooks/" class="customColorsSiteLink ng-scope" href="http://libraryadmin.herts.ac.uk/newbooks/"><span ng-bind-html="link.label" ng-if="!link.image" class="ng-binding ng-scope">New Books</span></a></li>');
        }, 1000);
}

ENDOFJS
;

	} else {
	}
	}
}
