#!perl

# sap_person.pl
# based on banner4person.pl
# Apply changes to AccMan person table based on data in sap_import
#
# Revision log
# 2004-05-17  1 ARG  Initial version.
# 2004-06-14  2 ARG  Correctly update age in wait_for_new_sap_data.
# 2004-09-20  3 ARG  Restrict import to MANDT = 200.
# 2004-10-05  4 ARG  Allow grace login period of one calendar month and set to 'absent'. Incident 679.
# 2005-07-20  5 ARG  Add 'expected' person_state based on start_date. Incident 1273.
# 2005-09-18  6 ARG  Add table-driven title parsing (incident 1388).
# 2005-10-04  7 ARG  Ignore dots in source title.
# 2006-09-21  8 ARG  Add unencrypted date of birth (CR 2091).
# 2007-01-15  9 ARG  Reject zero PERNR (incident 2451).
# 2007-01-15 10 ARG  Make 'missing' people 'left' after a month (incident 2450).
# 2008-08-29 11 ARG  Reject zero PERNR differently (incident 2451), and don't print headers if nothing to reject.
# 2010-06-10 12 APB  Add more logging
# 2011-08-25 13 AJJ  added update janus user details transaction on update person record
# 2012-04-11 14 AJJ  added update cmis lecturer details and update ad fields transactions on update person record

use warnings;
use strict;
use DBI;

use lib ('lib', '../lib');
require 'connect.pl';
require 'generateTransaction.pl';

#APB 2010-06-16
# define logfile and its logging subs
our ($logfile);
require 'trLogging.pl';



my ($DB, $usernameDB, $passwordDB);

my $DEV;
if (defined $ARGV[0] and ($ARGV[0] =~ m/DEV|-D/i)) {
  $DEV = shift;
  ($DB, $usernameDB, $passwordDB) = ('TestMail', 'alan', 'huc8er');
} else {
  ($DB, $usernameDB, $passwordDB) = ('Mail', 'personimport', 'banner-SAP');
}


#APB 2010-06-10
my $apb_logfile = "D:/accman/logs/sap_import.pl.log";


my ($sapdbh, $sapselh);
my ($dbh, $sth, $insh, $selsh, $rollh, $selh, $inph, $uprh, $updh, $rejh, $logh, $addh, $exth, $mish, $upmh);
my ($sapcount, $incount, $upcount, $addcount, $rejcount, $dupcount, $dupupcount, $badcount) = (0, 0, 0, 0, 0, 0, 0, 0);
my ($reject, $change);
my $importID;
my %depthash;

# following must be our and not my to make them global for logreject and logchange to work properly
our ($initials, $realname, $rollnumber, $dept_code, $forenames, $person_state, $title, $preferredName, $start_date, $end_date, $secret, $multi_post, $b_date);
our ($db_personID, $db_initials, $db_realname, $db_rollnumber, $db_dept_code, $db_forenames, $db_person_state, $db_importID, $db_title, $db_preferredName, $db_start_date, $db_end_date, $db_secret, $db_multi_post, $db_b_date);
our ($PERNR, $INITS, $SURNAME, $FORENAME, $TITLE, $PREFNAME, $MIDNAME, $DEPT, $SDATE, $EDATE, $DOB, $SECRET, $STATUS, $MULTIPOST, $TIMESTAMP);

my $ID;

my %pstate = (
  A => 'present',
  W => 'left',
);

my %titlemap;
my $graceDate;
my $today = datenow();



#APB 2010-06-10
apb_logactivity_tofile( $apb_logfile, "APB sap_import.pl - about to connect to databases" );



connect_accman ();
connect_sap ();
prepare_sap_select ();
wait_for_new_sap_data ();
empty_sap_import_table ();
copy_from_sap ();
disconnect_sap ();
generateImportID ();
prepareSQL ();
getTitleHash ();
getDeptHash ();
getGraceDate ();
importStaff ();
disconnect_accman ();


#APB 2010-06-10
apb_logactivity_tofile( $apb_logfile, "APB sap_import.pl - disconnected from databases" );



sub importStaff {
  open (REJECT, ">invalid_data_P.txt") || die "Cannot open file : $!";

  $selsh -> execute;

  while (($PERNR, $INITS, $SURNAME, $FORENAME, $TITLE, $PREFNAME, $MIDNAME, $DEPT, $SDATE, $EDATE, $DOB, $SECRET, $STATUS, $MULTIPOST, $TIMESTAMP) = $selsh -> fetchrow_array) {
    updateStaff ();
    $incount++;
    print "$incount\r";
  }

  print "$incount records processed including $dupcount duplicates\n";
  print "$upcount records updated including $dupupcount duplicates\n";
  print "$addcount records added\n";
  print "$rejcount records contain invalid data\n";
  print "$badcount records rejected with an invalid personnel number\n" if $badcount;

  close (REJECT) || die "Cannot close file : $!";

  completeImport () if $incount;
}


sub updateStaff {

  # parse the record - variable names MUST match database column names

  my $badpernr = 0;
  $reject = 0;
  my $dept_change = 0;
  # validate the data

  # logreject only logs data when person_state is 'present',
  # so forge person_state to ensure we always reject an invalid PERNR or surname
  $person_state = 'present';

  # extract surname
  $realname = $SURNAME;
  $realname =~ s/^ +//;     # remove extra spaces at start
  $realname =~ s/ +$//;     # remove extra spaces at end
  $realname =~ s/  / /g;    # remove extra spaces in middle

  # translate accented characters - add as we find them! NB CMD console shows DOS charset, but is a Windows app.
  # Following mapping works for Banner, but not SAP.
  # $realname =~ tr (ŠŽšžŸÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ)
  #                 (SZszYAAAAAACEEEEIIIIDNOOOOOOUUUUYYaaaaaaaceeeeiiiidnoooooouuuuyyy);
  $realname =~ tr/Ô/a/;

  # validate the PERNR and generate rollmap.ID
  # do this after generating surname in case we need to reject either
  if ($PERNR =~ m/^\d{8}$/) {
    $ID = $PERNR;
  } else {
    $ID = $PERNR;
    $ID =~ s/\D//g;     # Remove all non-digits
    $ID = 0 if $ID !~ m/\d+/;
    logreject ('PERNR');
    $badpernr = 1;
  }

  # There's no point importing with an invalid personnel number
  if ($badpernr) {
    $rejcount++;
    $badcount++;
    return 1;
  }

  # check surname
  logreject ('SURNAME') unless $realname =~ m/^[A-Z][-\s'A-Z]*$/i;

  # now generate correct person_state

  # get start date
  if ($SDATE > 0) {
    $start_date = join '-', reverse unpack 'a2a2a4', $SDATE;
  } else {
    $start_date = undef;
  }

  # get end date
  if ($EDATE > 0) {
    $end_date = join '-', reverse unpack 'a2a2a4', $EDATE;
  } else {
    $end_date = undef;
  }

  # get birth date
  if ($DOB > 0) {
    $b_date = join '-', reverse unpack 'a2a2a4', $DOB;
  } else {
    $b_date = undef;
  }

  # flag a problem if start date is later than end date
  if (defined $start_date and defined $end_date and $end_date lt $start_date) {
    logreject ('SDATE');
    logreject ('EDATE');
  }

  # get active/withdrawn status and calculate person_state
  if (defined $start_date and $start_date gt $today) {
    $person_state = 'expected'
  } else {
    my $newpstate = $pstate {$STATUS};
    if (defined $newpstate) {
      $person_state = $newpstate;
    } else {
      logreject ('STATUS');
      $person_state = 'left';
    }
    # if person has left within the last month, treat as still present
    $person_state = 'absent' if $person_state eq 'left' and $end_date gt $graceDate;
  }

  # check forenames
  $forenames = $FORENAME . ' ' . $MIDNAME;
  $forenames =~ s/\./ /g;    # replace all dots by spaces
  $forenames =~ s/^ +//;     # remove extra spaces at start
  $forenames =~ s/ +$//;     # remove extra spaces at end
  $forenames =~ s/  / /g;    # remove extra spaces in middle
  # translate accented characters
  $forenames =~ tr/Ô/a/;
  logreject ('forenames') unless $forenames =~ m/^[A-Z][-\s'A-Z]*$/i;

  # check initials
  $initials = $INITS;
  # SAP may store spaces in its initials
  $initials =~ tr/[a-z]/[A-Z]/;   # uppercase
  $initials =~ s/[^A-Z\s]//g;     # delete all non-letters and spaces
  logreject ('INITS') unless $INITS eq $initials;
  $initials =~ s/ //g;            # delete all spaces

  # extract preferred name
  $preferredName = $PREFNAME ne '' ? $PREFNAME : $FORENAME;
  $preferredName =~ s/^ +//;     # remove extra spaces at start
  $preferredName =~ s/ +$//;     # remove extra spaces at end
  $preferredName =~ s/  / /g;    # remove extra spaces in middle
  # translate accented characters
  $preferredName =~ tr/Ô/a/;
  logreject ('PREFNAME') unless $PREFNAME eq '' or $preferredName =~ m/^[A-Z][-\s'A-Z]*$/i;

  # map long title in SAP to short title
  my $undotted = $TITLE;
  $undotted =~ s/\.//g;          # remove dots
  $title = $titlemap {$undotted};
  unless (defined $title) {
    $title = '';
    logreject ('TITLE');
  }

  # translate SAP dept_code to valid AccMan dept_code and check
  my $newdept = $depthash {$DEPT};
  if (defined $newdept) {
    $dept_code = $newdept;
  } else {
    $dept_code = 'ZZ';
    logreject ('DEPT');
  }

  # secret
  $secret = $SECRET;

  # multi-post
  if ($MULTIPOST =~ m/[NY]/) {
    $multi_post = $MULTIPOST;
  } else {
    $multi_post = 'N';
    logreject ('MULTIPOST');
  }

  # if any of the checked data are invalid, we could decide not to update the database,
  # but it's better to accept everything and inform Personnel of the problems.
  $rejcount++ if $reject;

  # (Try to) get matching record from person table joined on rollnumber in rollmap table

  # variable names MUST be same as before, preceded by db_

  $selh -> execute ($ID);
  unless (($db_personID, $db_initials, $db_realname, $db_rollnumber, $db_dept_code, $db_forenames, $db_person_state, $db_importID, $db_title, $db_preferredName, $db_start_date, $db_end_date, $db_secret, $db_multi_post, $db_b_date) = $selh -> fetchrow_array) {

    # no existing record found with given rollnumber

    addperson ();
    $addcount++;

  } else {

    if ($db_importID == $importID) {

      # two records for same personnel number in the current import - can this actually happen?

      logreject ('DUPLICATE_RECORD');
      $dupcount++;
      $rejcount++;

      # previous one was present, or current one isn't, so ignore this one
      return 2 if $db_person_state eq 'present' or $person_state ne 'present';

      # current record probably better than previous, so update it
      $dupupcount++;
    }

    # if we reach here, we're updating the record

    # do we already know that the person has left?
    # if the the person isn't here, preserve an 'extended' or 'deleted' state (set outside the import process)
    my $alreadyleft = ($person_state =~ m/left/ and $db_person_state =~ m/left|extended|deleted/) or ($person_state =~ m/absent/ and $db_person_state =~ m/absent|extended|deleted/);
    $person_state = $db_person_state if $alreadyleft;

    # log the changes

    $change = 0;

    logchange ('initials') if $db_initials ne $initials;

    logchange ('realname') if $db_realname ne $realname;

    if ($db_dept_code ne $dept_code)
    {
        logchange ('dept_code');
        $dept_change = 1;
    }
    logchange ('forenames') if not defined $db_forenames or $db_forenames ne $forenames;

    logchange ('person_state') if $db_person_state ne $person_state;

    logchange ('title') if not defined $db_title or ($db_title ne $title and $db_title ne '');

    logchange ('preferredName') if $db_preferredName ne $preferredName;

    logchange ('start_date') if (defined $db_start_date and not defined $start_date) or (not defined $db_start_date and defined $start_date) or (defined $db_start_date and defined $start_date and $db_start_date ne $start_date);

    logchange ('end_date') if (defined $db_end_date and not defined $end_date) or (not defined $db_end_date and defined $end_date) or (defined $db_end_date and defined $end_date and $db_end_date ne $end_date);

    logchange ('b_date') if (defined $db_b_date and not defined $b_date) or (not defined $db_b_date and defined $b_date) or (defined $db_b_date and defined $b_date and $db_b_date ne $b_date);

    logchange ('secret') if $db_secret ne $secret;

    logchange ('multi_post') if $db_multi_post ne $multi_post;

    # now update the database

    # but don't bother if we know the user has already left and nothing else has changed
    # this will give us an idea of when the person actually left
    # but we do need to keep track of 'extended' users
    return 2 if $alreadyleft and $person_state ne 'extended' and not $change;

    # check for pre-extended newly left or absent person
    if ($person_state =~ m/left|absent/ and not $alreadyleft) {
      $exth -> execute ($db_personID);
      $person_state = 'extended' if $exth -> fetchrow_array;
    }

    $updh -> execute ($initials, $realname, $dept_code, $DEPT, $forenames, $person_state, $title, $preferredName, $start_date, $end_date, $secret, $multi_post, $b_date, $db_personID);
    if ($change) {
	  # create janus update transaction
	  my %transactionParams = (
		'ROLLNUMBER' => $db_rollnumber,
		'SOURCE' => 'sap_import.pl',
	  );
	  my $childTrID;
	  return 0 unless $childTrID = generateTransaction ($dbh, 97, $db_personID, %transactionParams);
	  if ($dept_change)
      {
        return 0 unless $childTrID = generateTransaction ($dbh, 121, $db_personID, %transactionParams);
      }
	  return 0 unless $childTrID = generateTransaction ($dbh, 122, $db_personID, %transactionParams);
	}
	$upcount++;
  }
  return 0;
}


sub wait_for_new_sap_data {
  # timestamp in ZACCMAN must be newer than last one in sap_import; otherwise sleep
  # data in ZACCMAN should be at least 4 minutes old (just in case it's not all there)
  my $minAge = 4;
  my $acctsh = $dbh -> prepare ('select max(TIMESTAMP) from sap_import');
  my $saptsh = $sapdbh -> prepare ('select max(TIMESTAMP) from ZACCMAN');
  my $sapddh = $sapdbh -> prepare ('select datediff(minute, ?, getdate())');
  $acctsh -> execute;
  my ($old) = $acctsh -> fetchrow_array;
  print "Old timestamp is $old\n" if defined $old;
  $saptsh -> execute;
  my ($new) = $saptsh -> fetchrow_array;
  print "New timestamp is $new\n";
  if (defined $old) {
    while ($new le $old) {
      print "Waiting for 60 seconds...\n";
      sleep 60;
      $saptsh -> execute;
      ($new) = $saptsh -> fetchrow_array;
      print "New timestamp is $new\n";
    }
  }
  my $ts = reformatTimestamp ($new);
  # print "The timestamp is $ts\n";
  $sapddh -> execute ($ts);
  my ($age) = $sapddh -> fetchrow_array;
  print "The new data is approx $age minutes old\n";
  while ($age < $minAge) {
    my $wait = $minAge - $age;
    print "It needs to be at least $minAge minutes. Waiting for $wait minutes...\n";
    sleep 60 * $wait;
    $saptsh -> execute;
    ($new) = $saptsh -> fetchrow_array;
    print "New timestamp is $new\n";
    $ts = reformatTimestamp ($new);
    # print "The timestamp is $ts\n";
    $sapddh -> execute ($ts);
    ($age) = $sapddh -> fetchrow_array;
    print "The new data is approx $age minutes old\n";
  }
  finishDB ($dbh, $acctsh);
  finishDB ($sapdbh, $saptsh, $sapddh);
}


sub reformatTimestamp {
  my ($TIMESTAMP) = @_;
  my ($datepart, $timepart) = unpack 'a8a6', $TIMESTAMP;
  return join (' ', join ('-', unpack ('a4a2a2', $datepart)), join (':', unpack ('a2a2a2', $timepart)));
}

sub empty_sap_import_table {
  $dbh -> do ('delete from sap_import') ||  die $dbh -> errstr;
}


sub prepare_sap_select {
  # prepare SQL statement to select from ZACCMAN table in SAP DB (use handle $sapselh)
  my $selection =
    q{select PERNR, INITS, SURNAME, FORENAME, TITLE, PREFNAME, MIDNAME, DEPT,
      SDATE, EDATE, DOB, STATUS, MULTIPOST, TIMESTAMP from ZACCMAN where MANDT = 200 and PERNR != '00000000'};
   ## SDATE, EDATE, DOB, STATUS, MULTIPOST, TIMESTAMP from ZACCMAN};
  $sapselh = $sapdbh -> prepare ($selection);

  # prepare SQL statement to insert into sap_import table (use handle $insh)
  $insh = $dbh -> prepare (qq{insert into sap_import values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, encrypt(?, ?), ?, ?, ?)}) || die $insh -> errstr;

}


sub copy_from_sap {

  $sapselh -> execute || die $sapselh -> errstr;
  print "Staff records selected; starting import\n";

  while (my ($PERNR, $INITS, $SURNAME, $FORENAME, $TITLE, $PREFNAME, $MIDNAME, $DEPT, $SDATE, $EDATE, $DOB, $STATUS, $MULTIPOST, $TIMESTAMP) = $sapselh -> fetchrow_array) {
    $sapcount++;
    # encrypt date of birth with salt that doesn't change too often
    # add 'zZ' in case string is less than 2 chars
    my $salt = substr ($FORENAME . 'zZ', 0, 2);
    $insh -> execute ($PERNR, $INITS, $SURNAME, $FORENAME, $TITLE, $PREFNAME, $MIDNAME, $DEPT, $SDATE, $EDATE, $DOB, $DOB, $salt, $STATUS, $MULTIPOST, $TIMESTAMP) or die $insh -> errstr;
    print "$sapcount\r";
  }
  print "\n$sapcount records imported\n\n";
}


sub prepareSQL {

  # prepare SQL statement to select from sap_import table (use handle $selsh)
  $selsh = $dbh -> prepare (qq{select PERNR, INITS, SURNAME, FORENAME, TITLE, PREFNAME, MIDNAME, DEPT, SDATE, EDATE, DOB, SECRET, STATUS, MULTIPOST, TIMESTAMP from sap_import}) || die $selsh -> errstr;

  # prepare SQL statement to select from person table joined on rollnumber in rollmap table (use handle $selh)

  $selh = $dbh -> prepare (qq{select personID, initials, realname, p.rollnumber, dept_code, forenames, person_state, importID, title, preferredName, start_date, end_date, secret, multi_post, b_date from person p, rollmap r where p.rollnumber = r.rollnumber and r.source_code = 'P' and r.ID = ?}) || die $selh -> errstr;

  # prepare SQL statement to insert into person table (use handle $inph)
  # source_code is 'P' for Personnel, person_status_code is 'S' for Staff
  $inph = $dbh -> prepare (qq{insert into person (initials, realname, source_code, person_status_code, dept_code, forenames, person_state, importID, first_importID, title, preferredName, start_date, end_date, secret, multi_post, b_date) values (?, ?, 'P', 'S', ?, ?, ?, $importID, $importID, ?, ?, ?, ?, ?, ?, ?)}) ||  die $inph -> errstr;

  # prepare SQL statement to insert into rollmap table (use handle $rollh)
  $rollh = $dbh -> prepare (qq{insert into rollmap (rollnumber, ID, source_code) values (?, ?, 'P')}) ||  die $rollh -> errstr;

  # prepare SQL statement to update rollnumber in new person table record (use handle $uprh)
  $uprh = $dbh -> prepare (qq{update person set rollnumber = ? where personID = ?}) ||  die $uprh -> errstr;

  # prepare SQL statement to update person table (use handle $updh)

  
  # prepare SQL statement to update person table (use handle $updh) (new sap_dept_code table)
  $updh = $dbh -> prepare (qq{update person set importID = $importID, source_code = 'P', person_status_code = 'S', initials = ?, realname = ?, dept_code = ?, sap_dept_code = ?, forenames = ?, person_state = ?, title = ?, preferredName = ?, start_date = ?, end_date = ?, secret = ?, multi_post = ?, b_date = ? where personID = ?}) ||  die $updh -> errstr;  

  # prepare SQL statement to insert into sap_rejected_data (use handle $rejh)
  $rejh = $dbh -> prepare (qq{insert into sap_rejected_data (importID, ID, field_name, bad_field_value) values ($importID, ?, ?, ?)}) || die $rejh -> errstr;

  # prepare SQL statement to insert into person_change (use handle $logh)
  $logh = $dbh -> prepare (qq{insert into person_change (importID, personID, field_name, old_field_value, new_field_value) values ($importID, ?, ?, ?, ?)}) || die $logh -> errstr;

  # prepare SQL statement to insert into person_add (use handle $addh)
  $addh = $dbh -> prepare (qq{insert into person_add (importID, rollnumber) values ($importID, ?)}) || die $addh -> errstr;

  # prepare SQL statement to select personID from extension table (use handle $exth)
  $exth = $dbh -> prepare (qq{select personID from extension where personID = ?}) || die $exth -> errstr;

  # prepare SQL statement to select missing persons from this import (use handle $mish)
  $mish = $dbh -> prepare (qq{select personID, PERNR, realname, rollnumber, person_state, importID, import_time, non_importID, non_import_time from missing_staff}) || die $mish -> errstr;

  # prepare SQL statement to update missing person_state (use handle $upmh)
  $upmh = $dbh -> prepare (qq{update person set person_state = ? where personID = ?}) || die $upmh -> errstr;
}


sub addperson {
  # add person record, generate rollnumber and add rollmap record
  #
  # insert a new record in the person table
  $inph -> execute ($initials, $realname, $dept_code, $forenames, $person_state, $title, $preferredName, $start_date, $end_date, $secret, $multi_post, $b_date);
  # get the personID of the newly inserted record
  my $personID = $inph -> {mysql_insertid} ||  die $inph -> errstr;
  # convert it to a rollnumber in the staff range by adding 2 0000 0000
  $rollnumber = $personID + 200000000;
  # insert this rollnumber and ID in the rollmap table
  $rollh -> execute ($rollnumber, $ID);
  # update the person record with the new rollnumber
  $uprh -> execute ($rollnumber, $personID);
  # log the new addition to the person_add table
  $addh -> execute ($rollnumber);
}


sub logreject {
  # log rejected data if person is present, otherwise don't bother
  return if $person_state ne 'present';
  my $name = shift;
  $reject = 1;
  # this clever/dirty trick works provided variable name is same as field name;
  no strict 'refs';
  my $value = (defined $$name ? qq{$$name} : '  (NULL)');
  use strict 'refs';
  # log rejected data using handle $rejh;
  $rejh -> execute ($ID, $name, $value);
  print REJECT qq{PERNR\tSURNAME\tPROPERTY\tINVALID VALUE\n} if $rejcount == 0;
  print REJECT qq{$PERNR\t$realname\t$name\t$value\n};
}


sub logchange {
  # log changed data using handle $logh;
  my $name = shift;
  $change = 1;
  # this clever/dirty trick works provided variable names match field names;
  # long-winded defined check to ensure proper DBI parsing
  no strict 'refs';
  my $db_name = qq{db_$name};
  my $value = (defined $$name ? qq{$$name} : '  (NULL)');
  my $db_value = (defined $$db_name ? qq{$$db_name} : undef);
  use strict 'refs';
  ##  print qq{CHANGE: $name old=};
  ##  $db_value = 'NULL' unless defined $db_value;
  ##  print $db_value;
  ##  print qq{ new=$value\n};
  $logh -> execute ($db_personID, $name, $db_value, $value);
}


sub generateImportID {
  $sth = $dbh -> prepare (qq{insert into person_import (source_code) values ('P')}) ||  die $sth -> errstr;
  $sth -> execute ||  die $sth -> errstr;
  $importID = $sth -> {mysql_insertid} ||  die $sth -> errstr;
  print "importID = $importID\n";
}


sub completeImport {
  $sth = $dbh -> prepare (qq{update person_import set completed = 'Y' where importID = $importID}) ||  die $sth -> errstr;
  $sth -> execute ||  die $sth -> errstr;
  # if import completed successfully, look for any that were present but are missing from the current import
  flagMissing ();
}


sub flagMissing {
  $dbh -> do ('delete from missing_staff') ||  die $dbh -> errstr;
  my $missing = $dbh -> do (qq{insert into missing_staff select p.personID, r.ID, p.realname, p.rollnumber, p.person_state, p.importID, i.import_time, $importID, now() from person p, rollmap r, person_import i where p.rollnumber = r.rollnumber and p.importID = i.importID and r.source_code = 'P' and p.source_code = 'P' and p.person_state in ('present', 'missing') and p.importID < $importID}) or  die $dbh -> errstr;
  if ($missing > 0) {
    open (MISSING, ">missing_data_P.txt") || die "Cannot open file : $!";
    print "$missing missing staff records detected.\n";
    print MISSING "personID\tPERNR\trealname\trollnumber\tperson_state\timportID\timport_time\tnon_importID\tnon_import_time\n";
    $mish -> execute;
    while (my ($personID, $PERNR, $realname, $rollnumber, $person_state, $importID, $import_time, $non_importID, $non_import_time) = $mish -> fetchrow_array) {
      # report current details
      print MISSING "$personID\t$PERNR\t$realname\t$rollnumber\t$person_state\t$importID\t$import_time\t$non_importID\t$non_import_time\n";
      # update person_state to 'missing' (or 'left' if missing for over a month)
      my $newstate = $import_time lt $graceDate ? 'left' : 'missing';
      $upmh -> execute ($newstate, $personID);
      # and log the change
      $logh -> execute ($personID, 'person_state', $person_state, $newstate) if $newstate ne $person_state;
    }
    close (MISSING) || die "Cannot close file : $!";
  }
}


sub getTitleHash {
  # set up titlemap hash to determine person.title from input title
  %titlemap = ();
  $sth = $dbh -> prepare ('select title, source_title from titleMap') or die $sth -> errstr;
  $sth -> execute;
  while (my ($title, $source_title) = $sth -> fetchrow_array) {
    $titlemap {$source_title} = $title;
  }
}


sub getDeptHash {
  # set up department hash to map SAP dept codes to current ISD codes
  %depthash = ();
  $sth = $dbh -> prepare('select DEPT, dept_code from sap_dept') || die $sth -> errstr;
  $sth -> execute;
  while (my ($sapdept, $isddept) = $sth -> fetchrow_array) {
    $depthash {$sapdept} = $isddept;
  }
}


sub getGraceDate {
  # get last possible date for leavers to have a chance to return
  $sth = $dbh -> prepare('select date_sub(curdate(), interval 1 month)') || die $sth -> errstr;
  $sth -> execute;
  ($graceDate) = $sth -> fetchrow_array;
}


sub connect_accman {
  $dbh = connectDB ($usernameDB, $passwordDB, $DB);
}


sub disconnect_accman {
  disconnectDB ($dbh, $sth, $insh, $selsh, $rollh, $selh, $inph, $uprh, $updh, $addh, $rejh, $logh, $exth, $mish, $upmh);
}


sub connect_sap {
  my ($username, $password) = ('ACCMAN', 'ACC2004man');
  $sapdbh = connectDB ($username, $password, 'sapexport', '', 'ODBC');
}


sub disconnect_sap {
  disconnectDB ($sapdbh, $sapselh);
}
