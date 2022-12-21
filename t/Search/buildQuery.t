#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More;
use t::lib::Mocks;

use Module::Load::Conditional qw/check_install/;

BEGIN {
    if ( check_install( module => 'Test::DBIx::Class' ) ) {
        plan tests => 10;
    } else {
        plan skip_all => "Need Test::DBIx::Class"
    }
}

# Mock the DB connection and C4::Context
use Test::DBIx::Class;

use_ok('C4::Search', qw( buildQuery ));
can_ok('C4::Search',
    qw/buildQuery/);
use_ok("Net::Z3950::ZOOM");

#FIXME: would it be better to use our real ccl.properties file?
sub _get_ccl_properties {
    my $config = q(
        kw 1=1016
        wrdl 4=6
        rtrn 5=1
        right-Truncation rtrn
        rk 2=102
        ti 1=4
        title ti
        ext 4=1 6=3
        Title-cover 1=36
        r1 9=32
        r2 9=28
        r3 9=26
        r4 9=24
        r5 9=22
        r6 9=20
        r7 9=18
        r8 9=16
        r9 9=14
        phr 4=1
        fuzzy 5=103
        ccode 1=8009
    );
    return $config;
}

#FIXME: We should add QueryFuzzy and QueryStemming preferences to expand test permutations

subtest "test weighted autotruncated" => sub {
    plan tests => 13;

    t::lib::Mocks::mock_preference('QueryWeightFields', '1');
    t::lib::Mocks::mock_preference('QueryAutoTruncate', '1');

    my $config = _get_ccl_properties();
    my $operators = [""];
    my $operands = ["test"];
    my $indexes = [""];
    my $limits = [""];
    my $sort_by = [""];
    my ($scan,$lang);

    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) =
        C4::Search::buildQuery($operators,$operands,$indexes,$limits,$sort_by,$scan,$lang);
    is($error,undef,"Error is correct");
    is($query,'(rk=(kw,wrdl,rtrn=test )) ','Query is correct with auto truncation');
    is($simple_query,'test',"Simple query is correct");
    is($query_cgi,'idx=kw&q=test','Query cgi is correct');
    is($query_desc,'kw,wrdl: test','Query desc is correct');
    is($limit,'',"Limit is correct");
    is($limit_cgi,'',"Limit cgi is correct");
    is($limit_desc,'',"Limit desc is correct");
    is($query_type,undef,"Query type is correct");
    my $q = Net::Z3950::ZOOM::query_create();
    my ($ccl_errcode, $ccl_errstr, $ccl_errpos) = (0,"",0);
    my $res = Net::Z3950::ZOOM::query_ccl2rpn($q, $query, $config,
        $ccl_errcode, $ccl_errstr, $ccl_errpos
    );
    is($res,0,"created CCL2RPN query");
    is($ccl_errcode,0);
    is($ccl_errstr,"");
    is($ccl_errpos,0);
    Net::Z3950::ZOOM::query_destroy($q);

};

subtest "test* weighted autotruncated" => sub {
    plan tests => 13;

    t::lib::Mocks::mock_preference('QueryWeightFields', '1');
    t::lib::Mocks::mock_preference('QueryAutoTruncate', '1');

    my $config = _get_ccl_properties();
    my $operators = [""];
    my $operands = ["test*"];
    my $indexes = [""];
    my $limits = [""];
    my $sort_by = [""];
    my ($scan,$lang);

    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) =
        C4::Search::buildQuery($operators,$operands,$indexes,$limits,$sort_by,$scan,$lang);
    is($error,undef,"Error is correct");
    is($query,'(rk=(kw,wrdl,rtrn=test )) ','Query is correct with manual truncation');
    is($simple_query,'test*',"Simple query is correct");
    is($query_cgi,'idx=kw&q=test%2A','Query cgi is correct');
    is($query_desc,'kw,wrdl: test*','Query desc is correct');
    is($limit,'',"Limit is correct");
    is($limit_cgi,'',"Limit cgi is correct");
    is($limit_desc,'',"Limit desc is correct");
    is($query_type,undef,"Query type is correct");
    my $q = Net::Z3950::ZOOM::query_create();
    my ($ccl_errcode, $ccl_errstr, $ccl_errpos) = (0,"",0);
    my $res = Net::Z3950::ZOOM::query_ccl2rpn($q, $query, $config,
        $ccl_errcode, $ccl_errstr, $ccl_errpos
    );
    is($res,0,"created CCL2RPN query");
    is($ccl_errcode,0);
    is($ccl_errstr,"");
    is($ccl_errpos,0);
    Net::Z3950::ZOOM::query_destroy($q);
};

subtest "test weighted not-autotruncated" => sub {
    plan tests => 13;

    t::lib::Mocks::mock_preference('QueryWeightFields', '1');
    t::lib::Mocks::mock_preference('QueryAutoTruncate', '0');

    my $config = _get_ccl_properties();
    my $operators = [""];
    my $operands = ["test"];
    my $indexes = [""];
    my $limits = [""];
    my $sort_by = [""];
    my ($scan,$lang);

    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) =
        C4::Search::buildQuery($operators,$operands,$indexes,$limits,$sort_by,$scan,$lang);
    is($error,undef,"Error is correct");
    is($query,'(rk=(Title-cover,ext,r1="test" or ti,ext,r2="test" or Title-cover,phr,r3="test" or ti,wrdl,r4="test" or wrdl,fuzzy,r8="test" or wrdl,right-Truncation,r9="test" or wrdl,r9="test")) ','Query is correct with weighted fields');
    is($simple_query,'test',"Simple query is correct");
    is($query_cgi,'idx=kw&q=test','Query cgi is correct');
    is($query_desc,'kw,wrdl: test','Query desc is correct');
    is($limit,'',"Limit is correct");
    is($limit_cgi,'',"Limit cgi is correct");
    is($limit_desc,'',"Limit desc is correct");
    is($query_type,undef,"Query type is correct");
    my $q = Net::Z3950::ZOOM::query_create();
    my ($ccl_errcode, $ccl_errstr, $ccl_errpos) = (0,"",0);
    my $res = Net::Z3950::ZOOM::query_ccl2rpn($q, $query, $config,
        $ccl_errcode, $ccl_errstr, $ccl_errpos
    );
    is($res,0,"created CCL2RPN query");
    is($ccl_errcode,0);
    is($ccl_errstr,"");
    is($ccl_errpos,0);
    Net::Z3950::ZOOM::query_destroy($q);
};


subtest "test ccode:REF weighted autotruncated" => sub {
    plan tests => 13;

    t::lib::Mocks::mock_preference('QueryWeightFields', '1');
    t::lib::Mocks::mock_preference('QueryAutoTruncate', '1');

    my $config = _get_ccl_properties();
    my $operators = [""];
    my $operands = ["test"];
    my $indexes = [""];
    my $limits = ["ccode:REF"];
    my $sort_by = [""];
    my ($scan,$lang);

    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) =
        C4::Search::buildQuery($operators,$operands,$indexes,$limits,$sort_by,$scan,$lang);
    is($error,undef,"Error is correct");
    is($query,'(rk=(kw,wrdl,rtrn=test )) and ccode=REF','Query is correct with auto truncation and limits');
    is($simple_query,'test',"Simple query is correct");
    is($query_cgi,'idx=kw&q=test','Query cgi is correct');
    is($query_desc,'kw,wrdl: test','Query desc is correct');
    is($limit,'and ccode=REF',"Limit is correct");
    is($limit_cgi,'&limit=ccode%3AREF',"Limit cgi is correct");
    is($limit_desc,'ccode:REF',"Limit desc is correct");
    is($query_type,undef,"Query type is correct");
    my $q = Net::Z3950::ZOOM::query_create();
    my ($ccl_errcode, $ccl_errstr, $ccl_errpos) = (0,"",0);
    my $res = Net::Z3950::ZOOM::query_ccl2rpn($q, $query, $config,
        $ccl_errcode, $ccl_errstr, $ccl_errpos
    );
    is($res,0,"created CCL2RPN query");
    is($ccl_errcode,0);
    is($ccl_errstr,"");
    is($ccl_errpos,0);
    Net::Z3950::ZOOM::query_destroy($q);
};

subtest "test ccode:REF weighted not-autotruncated" => sub {
    plan tests => 13;

    t::lib::Mocks::mock_preference('QueryWeightFields', '1');
    t::lib::Mocks::mock_preference('QueryAutoTruncate', '0');

    my $config = _get_ccl_properties();
    my $operators = [""];
    my $operands = ["test"];
    my $indexes = [""];
    my $limits = ["ccode:REF"];
    my $sort_by = [""];
    my ($scan,$lang);

    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) =
        C4::Search::buildQuery($operators,$operands,$indexes,$limits,$sort_by,$scan,$lang);
    is($error,undef,"Error is correct");
    is($query,'(rk=(Title-cover,ext,r1="test" or ti,ext,r2="test" or Title-cover,phr,r3="test" or ti,wrdl,r4="test" or wrdl,fuzzy,r8="test" or wrdl,right-Truncation,r9="test" or wrdl,r9="test")) and ccode=REF','Query is correct with weighted fields and limits');
    is($simple_query,'test',"Simple query is correct");
    is($query_cgi,'idx=kw&q=test','Query cgi is correct');
    is($query_desc,'kw,wrdl: test','Query desc is correct');
    is($limit,'and ccode=REF',"Limit is correct");
    is($limit_cgi,'&limit=ccode%3AREF',"Limit cgi is correct");
    is($limit_desc,'ccode:REF',"Limit desc is correct");
    is($query_type,undef,"Query type is correct");
    my $q = Net::Z3950::ZOOM::query_create();
    my ($ccl_errcode, $ccl_errstr, $ccl_errpos) = (0,"",0);
    my $res = Net::Z3950::ZOOM::query_ccl2rpn($q, $query, $config,
        $ccl_errcode, $ccl_errstr, $ccl_errpos
    );
    is($res,0,"created CCL2RPN query");
    is($ccl_errcode,0);
    is($ccl_errstr,"");
    is($ccl_errpos,0);
    Net::Z3950::ZOOM::query_destroy($q);
};

subtest "kw:one and title:two ccode:REF weighted autotruncated" => sub {
    plan tests => 13;

    t::lib::Mocks::mock_preference('QueryWeightFields', '1');
    t::lib::Mocks::mock_preference('QueryAutoTruncate', '1');

    my $config = _get_ccl_properties();
    my $operators = ["and"];
    my $operands = ["one","two"];
    my $indexes = ["kw","title"];
    my $limits = ["ccode:REF"];
    my $sort_by = [""];
    my ($scan,$lang);

    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) =
        C4::Search::buildQuery($operators,$operands,$indexes,$limits,$sort_by,$scan,$lang);
    is($error,undef,"Error is correct");
    is($query,'(rk=(kw,wrdl,rtrn=one )) and (rk=(title,wrdl,rtrn=two )) and ccode=REF','Query is correct with auto truncation, limits, and using indexes and operators');
    is($simple_query,'one',"Simple query is correct?");
    is($query_cgi,'idx=kw&q=one&op=and&idx=title&q=two','Query cgi is correct');
    is($query_desc,'kw,wrdl: one and title,wrdl: two','Query desc is correct');
    is($limit,'and ccode=REF',"Limit is correct");
    is($limit_cgi,'&limit=ccode%3AREF',"Limit cgi is correct");
    is($limit_desc,'ccode:REF',"Limit desc is correct");
    is($query_type,undef,"Query type is correct");
    my $q = Net::Z3950::ZOOM::query_create();
    my ($ccl_errcode, $ccl_errstr, $ccl_errpos) = (0,"",0);
    my $res = Net::Z3950::ZOOM::query_ccl2rpn($q, $query, $config,
        $ccl_errcode, $ccl_errstr, $ccl_errpos
    );
    is($res,0,"created CCL2RPN query");
    is($ccl_errcode,0);
    is($ccl_errstr,"");
    is($ccl_errpos,0);
    Net::Z3950::ZOOM::query_destroy($q);
};

subtest "one and two weighted autotruncated" => sub {
    plan tests => 13;

    t::lib::Mocks::mock_preference('QueryWeightFields', '1');
    t::lib::Mocks::mock_preference('QueryAutoTruncate', '1');

    my $config = _get_ccl_properties();
    my $operators = [""];
    my $operands = ["one and two"];
    my $indexes = [""];
    my $limits = [""];
    my $sort_by = [""];
    my ($scan,$lang);

    my ($error,$query,$simple_query,$query_cgi,$query_desc,$limit,$limit_cgi,$limit_desc,$query_type) =
        C4::Search::buildQuery($operators,$operands,$indexes,$limits,$sort_by,$scan,$lang);
    is($error,undef,"Error is correct");
    is($query,'(rk=(kw,wrdl,rtrn=one and two )) ','Query is correct with auto truncation and unstructured query');
    is($simple_query,'one and two',"Simple query is correct");
    is($query_cgi,'idx=kw&q=one%20and%20two','Query cgi is correct');
    is($query_desc,'kw,wrdl: one and two','Query desc is correct');
    is($limit,'',"Limit is correct");
    is($limit_cgi,'',"Limit cgi is correct");
    is($limit_desc,'',"Limit desc is correct");
    is($query_type,undef,"Query type is correct");
    my $q = Net::Z3950::ZOOM::query_create();
    my ($ccl_errcode, $ccl_errstr, $ccl_errpos) = (0,"",0);
    my $res = Net::Z3950::ZOOM::query_ccl2rpn($q, $query, $config,
        $ccl_errcode, $ccl_errstr, $ccl_errpos
    );
    is($res,0,"created CCL2RPN query");
    is($ccl_errcode,0);
    is($ccl_errstr,"");
    is($ccl_errpos,0);
    Net::Z3950::ZOOM::query_destroy($q);
};
