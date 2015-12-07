###############################################################################
# 
# Developed with Kate
#
#  (c) 2015 Copyright: Marko Oldenburg (leongaultier at gmail dot com)
#  All rights reserved
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id$
#
###############################################################################


package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

use HttpUtils;

my $version = "0.1.30";




sub HOMBOT_Initialize($) {

    my ($hash) = @_;

    $hash->{SetFn}	= "HOMBOT_Set";
    $hash->{DefFn}	= "HOMBOT_Define";
    $hash->{UndefFn}	= "HOMBOT_Undef";
    $hash->{AttrFn}	= "HOMBOT_Attr";
    
    $hash->{AttrList} 	= "interval ".
			  "disable:1 ".
			  $readingFnAttributes;



    foreach my $d(sort keys %{$modules{HOMBOT}{defptr}}) {
	my $hash = $modules{HOMBOT}{defptr}{$d};
	$hash->{VERSION} 	= $version;
    }
}

sub HOMBOT_Define($$) {

    my ( $hash, $def ) = @_;
    
    my @a = split( "[ \t][ \t]*", $def );

    return "too few parameters: define <name> HOMBOT <HOST>" if( @a != 3 );

    my $name    	= $a[0];
    my $host    	= $a[2];
    my $port		= 6260;
    my $interval  	= 120;

    $hash->{HOST} 	= $host;
    $hash->{PORT} 	= $port;
    $hash->{INTERVAL} 	= $interval;
    $hash->{VERSION} 	= $version;
    $hash->{helper}{infoErrorCounter} = 0;
    $hash->{helper}{setCmdErrorCounter} = 0;


    Log3 $name, 3, "HOMBOT ($name) - defined with host $hash->{HOST} on port $hash->{PORT} and interval $hash->{INTERVAL} (sec)";

    $attr{$name}{room} = "HOMBOT" if( !defined( $attr{$name}{room} ) );    # sorgt für Diskussion, überlegen ob nötig
    readingsSingleUpdate ( $hash, "state", "initialized", 1 );

    HOMBOT_Get_stateRequestLocal( $hash );      # zu Testzwecken mal eingebaut
    InternalTimer( gettimeofday()+$hash->{INTERVAL}, "HOMBOT_Get_stateRequest", $hash, 0 );
    
    $modules{HOMBOT}{defptr}{$hash->{HOST}} = $hash;

    return undef;
}

sub HOMBOT_Undef($$) {

    my ( $hash, $arg ) = @_;
    
    my $host = $hash->{HOST};
    my $name = $hash->{NAME};
    
    delete $modules{HOMBOT}{defptr}{$hash->{HOST}};
    RemoveInternalTimer( $hash );
    
    return undef;
}

sub HOMBOT_Attr(@) {

    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    my $hash = $defs{$name};

    if( $attrName eq "disable" ) {
	if( $cmd eq "set" ) {
	    if( $attrVal eq "0" ) {
		RemoveInternalTimer( $hash );
		InternalTimer( gettimeofday()+2, "HOMBOT_Get_stateRequest", $hash, 0 ) if( ReadingsVal( $hash->{NAME}, "state", 0 ) eq "disabled" );
		readingsSingleUpdate ( $hash, "state", "active", 1 );
		Log3 $name, 3, "HOMBOT ($name) - enabled";
	    } else {
		readingsSingleUpdate ( $hash, "state", "disabled", 1 );
		RemoveInternalTimer( $hash );
		Log3 $name, 3, "HOMBOT ($name) - disabled";
	    }
	}
	elsif( $cmd eq "del" ) {
	    RemoveInternalTimer( $hash );
	    InternalTimer( gettimeofday()+2, "HOMBOT_Get_stateRequest", $hash, 0 ) if( ReadingsVal( $hash->{NAME}, "state", 0 ) eq "disabled" );
	    readingsSingleUpdate ( $hash, "state", "active", 1 );
	    Log3 $name, 3, "HOMBOT ($name) - enabled";

	} else {
	    if($cmd eq "set") {
		$attr{$name}{$attrName} = $attrVal;
		Log3 $name, 3, "HOMBOT ($name) - $attrName : $attrVal";
	    }
	    elsif( $cmd eq "del" ) {
	    }
	}
    }
    
    if( $attrName eq "interval" ) {
	if( $cmd eq "set" ) {
	    if( $attrVal < 60 ) {
		Log3 $name, 3, "HOMBOT ($name) - interval too small, please use something > 60 (sec), default is 180 (sec)";
		return "interval too small, please use something > 60 (sec), default is 180 (sec)";
	    } else {
		$hash->{INTERVAL} = $attrVal;
		Log3 $name, 3, "HOMBOT ($name) - set interval to $attrVal";
	    }
	}
	elsif( $cmd eq "del" ) {
	    $hash->{INTERVAL} = 180;
	    Log3 $name, 3, "HOMBOT ($name) - set interval to default";
	
	} else {
	    if( $cmd eq "set" ) {
		$attr{$name}{$attrName} = $attrVal;
		Log3 $name, 3, "HOMBOT ($name) - $attrName : $attrVal";
	    }
	    elsif( $cmd eq "del" ) {
	    }
	}
    }
    
    return undef;
}

sub HOMBOT_Get_stateRequestLocal($) {

my ( $hash ) = @_;
    my $name = $hash->{NAME};

    HOMBOT_RetrieveHomebotInfomations( $hash ) if( AttrVal( $name, "disable", 0 ) ne "1" );  ##ReadingsVal( $hash->{NAME}, "state", 0 ) ne "initialized" && 
    
    return 0;
}

sub HOMBOT_Get_stateRequest($) {

    my ( $hash ) = @_;
    my $name = $hash->{NAME};
 
    HOMBOT_RetrieveHomebotInfomations( $hash ) if( ReadingsVal( $name, "hombotState", "OFFLINE" ) ne "OFFLINE" && AttrVal( $name, "disable", 0 ) ne "1" );
  
    InternalTimer( gettimeofday()+$hash->{INTERVAL}, "HOMBOT_Get_stateRequest", $hash, 1 );
    Log3 $name, 4, "HOMBOT ($name) - Call HOMBOT_Get_stateRequest";

    return 1;
}

sub HOMBOT_RetrieveHomebotInfomations($) {
    my ( $hash ) = @_;
    my $name = $hash->{NAME};
    
    HOMBOT_getStatusTXT( $hash );
    HOMBOT_getSchedule( $hash ) if( ReadingsVal( "$name","hombotState","CHARGING" ) eq "CHARGING" || ReadingsVal( "$name","hombotState","CHARGING" ) eq "STANDBY" );
    HOMBOT_getStatisticHTML( $hash ) if( ReadingsVal( "$name","hombotState","CHARGING" ) eq "CHARGING" || ReadingsVal( "$name","hombotState","CHARGING" ) eq "STANDBY" );
    
    return undef;
}

sub HOMBOT_getStatusTXT($) {

    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $host = $hash->{HOST};
    my $port = $hash->{PORT};

    
    my $url = "http://" . $host . ":" . $port . "/status.txt";


    HttpUtils_NonblockingGet(
	{
	    url		=> $url,
	    timeout	=> 10,
	    hash	=> $hash,
	    method	=> "GET",
	    doTrigger	=> 1,
	    callback	=> \&HOMBOT_RetrieveHomebotInfoFinished,
	    id          => "statustxt",
	}
    );
    Log3 $name, 4, "HOMBOT ($name) - NonblockingGet get URL";
    Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Retrieve status.txt Information: calling Host: $host";
}

sub HOMBOT_getStatisticHTML($) {

    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $host = $hash->{HOST};
    my $port = $hash->{PORT};

    
    my $url = "http://" . $host . ":" . $port . "/sites/statistic.html";


    HttpUtils_NonblockingGet(
	{
	    url		=> $url,
	    timeout	=> 10,
	    hash	=> $hash,
	    method	=> "GET",
	    doTrigger	=> 1,
	    callback	=> \&HOMBOT_RetrieveHomebotInfoFinished,
	    id          => "statistichtml",
	}
    );
    Log3 $name, 4, "HOMBOT ($name) - NonblockingGet get URL";
    Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Retrieve statistic.html Information: calling Host: $host";
}

sub HOMBOT_getSchedule($) {

    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $host = $hash->{HOST};
    my $port = $hash->{PORT};

    
    my $url = "http://" . $host . ":" . $port . "/sites/schedule.html";


    HttpUtils_NonblockingGet(
	{
	    url		=> $url,
	    timeout	=> 10,
	    hash	=> $hash,
	    method	=> "GET",
	    doTrigger	=> 1,
	    callback	=> \&HOMBOT_RetrieveHomebotInfoFinished,
	    id          => "schedule",
	}
    );
    Log3 $name, 4, "HOMBOT ($name) - NonblockingGet get URL";
    Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Retrieve Schedule Information: calling Host: $host";
}

sub HOMBOT_RetrieveHomebotInfoFinished($$$) {

    my ( $param, $err, $data ) = @_;
    my $hash = $param->{hash};
    my $parsid = $param->{id};
    my $doTrigger = $param->{doTrigger};
    my $name = $hash->{NAME};
    my $host = $hash->{HOST};

    Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Response Infomations: processed response data";



    ### Begin Error Handling
    if( $hash->{helper}{infoErrorCounter} > 2 ) {
	readingsBeginUpdate( $hash );
	readingsBulkUpdate( $hash, "lastStatusRequestState", "statusRequest_error" );
	
	if( $hash->{helper}{infoErrorCounter} > 4 && $hash->{helper}{setCmdErrorCounter} > 3 ) {
	    readingsBulkUpdate( $hash, "lastStatusRequestError", "unknown error, please contact the developer" );
	    
	    Log3 $name, 4, "HOMBOT ($name) - UNKNOWN ERROR, PLEASE CONTACT THE DEVELOPER, DEVICE DISABLED";
	    
	    $attr{$name}{disable} = 1;
	    readingsBulkUpdate ( $hash, "state", "Unknown Error, device disabled");
	    
	    $hash->{helper}{infoErrorCounter} = 0;
	    $hash->{helper}{setCmdErrorCounter} = 0;
	    
	    return;
	}
	
	if( $hash->{helper}{infoErrorCounter} > 2 && $hash->{helper}{setCmdErrorCounter} == 0 ) {
	    readingsBulkUpdate( $hash, "lastStatusRequestError", "Homebot is offline" );
	    
	    Log3 $name, 4, "HOMBOT ($name) - Homebot is offline";
	    
	    readingsBulkUpdate ( $hash, "hombotState", "OFFLINE");
	    readingsBulkUpdate ( $hash, "state", "Homebot offline");
	    
	    $hash->{helper}{infoErrorCounter} = 0;
	    $hash->{helper}{setCmdErrorCounter} = 0;
	    
	    return;
	}

	elsif( $hash->{helper}{infoErrorCounter} > 2 && $hash->{helper}{setCmdErrorCounter} > 0 ) {
	    readingsBulkUpdate( $hash, "lastStatusRequestError", "to many errors, check your network configuration" );
	    
	    Log3 $name, 4, "HOMBOT ($name) - To many Errors please check your Network Configuration";

	    readingsBulkUpdate ( $hash, "homebotState", "offline");
	    readingsBulkUpdate ( $hash, "state", "To many Errors");
	    $hash->{helper}{infoErrorCounter} = 0;
	}
	readingsEndUpdate( $hash, 1 );
    }
    
    if( defined( $err ) && $err ne "" ) {
    
        readingsBeginUpdate( $hash );
        readingsBulkUpdate ( $hash, "state", "$err") if( ReadingsVal( $name, "state", 1 ) ne "initialized" );
        $hash->{helper}{infoErrorCounter} = ( $hash->{helper}{infoErrorCounter} + 1 );

        readingsBulkUpdate( $hash, "lastStatusRequestState", "statusRequest_error" );
        readingsBulkUpdate($hash, "lastStatusRequestError", $err );

	readingsEndUpdate( $hash, 1 );
	
	Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Parse_HomebotInfomations: error while request: $err";
	return;
    }

    if( $data eq "" and exists( $param->{code} ) ) {
	readingsBeginUpdate( $hash );
	readingsBulkUpdate ( $hash, "state", $param->{code} ) if( ReadingsVal( $name, "state", 1 ) ne "initialized" );
	$hash->{helper}{infoErrorCounter} = ( $hash->{helper}{infoErrorCounter} + 1 );
    
	readingsBulkUpdate( $hash, "lastStatusRequestState", "statusRequest_error" );
    
	if( $param->{code} ne 200 ) {
	    readingsBulkUpdate( $hash," lastStatusRequestError", "http Error ".$param->{code} );
	}
	
	readingsBulkUpdate( $hash, "lastStatusRequestError", "empty response" );
	readingsEndUpdate( $hash, 1 );
    
	Log3 $name, 4, "HOMBOT ($name) - HOMBOT_RetrieveHomebotInfomationsFinished: received http code ".$param->{code}." without any data after requesting HOMBOT Device";

	return;
    }

    if( ( $data =~ /Error/i ) and exists( $param->{code} ) ) {    
	readingsBeginUpdate( $hash );
	readingsBulkUpdate( $hash, "state", $param->{code} ) if( ReadingsVal( $name, "state" ,0) ne "initialized" );
	$hash->{helper}{infoErrorCounter} = ( $hash->{helper}{infoErrorCounter} + 1 );

	readingsBulkUpdate( $hash, "lastStatusRequestState", "statusRequest_error" );
    
        if( $param->{code} eq 404 ) {
            readingsBulkUpdate( $hash, "lastStatusRequestError", "HTTP Server at Homebot offline" );
        } else {
            readingsBulkUpdate( $hash, "lastStatusRequestError", "http error ".$param->{code} );
        }
	
	readingsEndUpdate( $hash, 1 );
    
	Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Parse_HomebotInfomations: received http code ".$param->{code}." receive Error after requesting HOMBOT";

	return;
    }

    ### End Error Handling

    $hash->{helper}{infoErrorCounter} = 0;
 
    ### Begin Parse Processing
    readingsSingleUpdate( $hash, "state", "active", 1) if( ReadingsVal( $name, "state", 0 ) ne "initialized" or ReadingsVal( $name, "state", 0 ) ne "active" );
    

    readingsBeginUpdate( $hash );
    
    
    my $t;      # fuer Readins Name
    my $v;      # fuer Radings Value
    
    if( $parsid eq "statustxt" ) {
    
        Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Parse_status.txt";
    
        my @valuestring = split( '\R',  $data );
        my %buffer;
    
        foreach( @valuestring ) {
    
            my @values = split( '="' , $_ );
            $buffer{$values[0]} = $values[1];
        }
    
        while( ( $t, $v ) = each %buffer ) {
    
            $v =~ tr/"//d;
            $t =~ s/CPU_IDLE/cpu_IDLE/g;
            $t =~ s/CPU_USER/cpu_USER/g;
            $t =~ s/CPU_SYS/cpu_SYS/g;
            $t =~ s/CPU_NICE/cpu_NICE/g;
            $t =~ s/JSON_MODE/cleanMode/g;
            $t =~ s/JSON_NICKNAME/nickname/g;
            $t =~ s/JSON_REPEAT/repeat/g;
            $t =~ s/JSON_TURBO/turbo/g;
            $t =~ s/JSON_ROBOT_STATE/hombotState/g;
            $t =~ s/CLREC_CURRENTBUMPING/currentBumping/g;
            $t =~ s/CLREC_LAST_CLEAN/lastClean/g;
            $t =~ s/JSON_BATTPERC/batteryPercent/g;
            $t =~ s/JSON_VERSION/firmware/g;
            $t =~ s/LGSRV_VERSION/luigiSrvVersion/g;
            
            readingsBulkUpdate( $hash, $t, $v ) if( $t =~ m/[a-z]/s && defined( $t ) && defined( $v ) );
        }
        
        readingsBulkUpdate( $hash, "hombotState", "UNKNOWN" ) if( ReadingsVal( $name, "hombotState", "" ) eq "" );
    }
    
    elsif( $parsid eq "statistichtml" ) {
    
        Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Parse_statistic.html";
        
        while( $data =~ m/<th>(.*?):<\/th>\s*<td>(.*?)<\/td>/g ) {
            $t = $1 if( defined( $1 ) );
            $v = $2 if( defined( $2 ) );
            
            $t =~ s/NUM START ZZ/numZZ_Begin/g;
            $t =~ s/NUM FINISH ZZ/numZZ_Ende/g;
            $t =~ s/NUM START SB/numSB_Begin/g;
            $t =~ s/NUM FINISH SB/numSB_Ende/g;
            $t =~ s/NUM START SPOT/numSPOT_Begin/g;
            $t =~ s/NUM FINISH SPOT/numSPOT_Ende/g;
            
            readingsBulkUpdate( $hash, $t, $v ) if( $t =~ m/num/s );
        }
    }
    
    elsif ( $parsid eq "schedule" ) {
    
        Log3 $name, 4, "HOMBOT ($name) - HOMBOT_Parse_schedule.html";
        
        my $i = 0;
        
        while( $data =~ m/name="(.*?)"\s*size="20" maxlength="20" value="(.*?)"/g ) {
            $t = $1 if( defined( $1 ) );
            $v = $2 if( defined( $2 ) );

            readingsBulkUpdate( $hash, "at_".$i."_".$t, $v );
            $i = ++$i;
        }
    }


    readingsBulkUpdate( $hash, "lastStatusRequestState", "statusRequest_done" );
    
    $hash->{helper}{infoErrorCounter} = 0;
    ### End Response Processing
    
    readingsBulkUpdate( $hash, "state", "active" ) if( ReadingsVal( $name, "state", 0 ) eq "initialized" );
    readingsEndUpdate( $hash, 1 );

    return undef;
}

sub HOMBOT_Set($$@) {
    
    my ( $hash, $name, $cmd, @val ) = @_;


	my $list = "";
	$list .= "cleanStart:noArg ";
	$list .= "homing:noArg ";
	$list .= "pause:noArg ";
	$list .= "statusRequest:noArg ";
	$list .= "cleanMode:SB,ZZ,SPOT ";
	$list .= "repeat:true,false ";
	$list .= "turbo:true,false ";
	$list .= "nickname " ;
	$list .= "schedule " ;
	

	if( lc $cmd eq 'cleanstart'
	    || lc $cmd eq 'homing'
	    || lc $cmd eq 'pause'
	    || lc $cmd eq 'statusrequest'
	    || lc $cmd eq 'cleanmode'
	    || lc $cmd eq 'repeat'
	    || lc $cmd eq 'turbo' 
	    || lc $cmd eq 'nickname'
	    || lc $cmd eq 'schedule' ) {

	    Log3 $name, 5, "HOMBOT ($name) - set $name $cmd ".join(" ", @val);


	    my $val = join( " ", @val );
	    my $wordlenght = length($val);

	    return "set command only works if state not equal initialized, please wait for next interval run" if( ReadingsVal( $hash->{NAME}, "state", 0 ) eq "initialized");
	    return "to many bla bla for Nickname" if(( $wordlenght < 2 || $wordlenght > 16 ) && lc $cmd eq 'nickname' );

	    return HOMBOT_SelectSetCmd( $hash, $cmd, @val ) if( ( @val ) || lc $cmd eq 'statusrequest' || lc $cmd eq 'cleanstart'|| lc $cmd eq 'homing' || lc $cmd eq 'pause' );
	}

	return "Unknown argument $cmd, bearword as argument or wrong parameter(s), choose one of $list";
}

sub HOMBOT_SelectSetCmd($$@) {

    my ( $hash, $cmd, @data ) = @_;
    my $name = $hash->{NAME};
    my $host = $hash->{HOST};
    my $port = $hash->{PORT};

    if( lc $cmd eq 'cleanstart' ) {
	
	my $url = "http://" . $host . ":" . $port . "/json.cgi?%7b%22COMMAND%22:%22CLEAN_START%22%7d";

	Log3 $name, 4, "HOMBOT ($name) - Homebot start cleaning";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }
    
    elsif( lc $cmd eq 'homing' ) {
	
	my $url = "http://" . $host . ":" . $port . "/json.cgi?%7b%22COMMAND%22:%22HOMING%22%7d";

	Log3 $name, 4, "HOMBOT ($name) - Homebot come home";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }
    
    elsif( lc $cmd eq 'pause' ) {
	
	my $url = "http://" . $host . ":" . $port . "/json.cgi?%7b%22COMMAND%22:%22PAUSE%22%7d";

	Log3 $name, 4, "HOMBOT ($name) - Homebot paused";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }
    
    elsif( lc $cmd eq 'cleanmode' ) {
        my $mode = join( " ", @data );
	
	my $url = "http://" . $host . ":" . $port . "/json.cgi?%7b%22COMMAND%22:%7b%22CLEAN_MODE%22:%22CLEAN_".$mode."%22%7d%7d";

	Log3 $name, 4, "HOMBOT ($name) - set Cleanmode to $mode";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }
    
    elsif( lc $cmd eq 'statusrequest' ) {
	HOMBOT_Get_stateRequestLocal( $hash );
	return undef;
    }
    
    elsif( lc $cmd eq 'repeat' ) {
        my $repeat = join( " ", @data );
	
	my $url = "http://" . $host . ":" . $port . "/json.cgi?%7b%22COMMAND%22:%7b%22REPEAT%22:%22".$repeat."%22%7d%7d";

	Log3 $name, 4, "HOMBOT ($name) - set Repeat to $repeat";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }
    
    elsif( lc $cmd eq 'turbo' ) {
        my $turbo = join( " ", @data );
	
	my $url = "http://" . $host . ":" . $port . "/json.cgi?%7b%22COMMAND%22:%7b%22TURBO%22:%22".$turbo."%22%7d%7d";

	Log3 $name, 4, "HOMBOT ($name) - set Turbo to $turbo";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }
    
    elsif( lc $cmd eq 'nickname' ) {
        my $nick = join( " ", @data );
	
	my $url = "http://" . $host . ":" . $port . "/json.cgi?%7b%22NICKNAME%22:%7b%22SET%22:%22".$nick."%22%7d%7d";

	Log3 $name, 4, "HOMBOT ($name) - set Nickname to $nick";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }
    
    elsif( lc $cmd eq 'schedule' ) {

        #my $mo = $data[0];
        $data[0] =~ s/Mo/MONDAY/g;
        #my $tu = $data[1];
        $data[1] =~ s/Di/TUESDAY/g;
        #my $we = $data[2];
        $data[2] =~ s/Mi/WEDNESDAY/g;
        #my $th = $data[3];
        $data[3] =~ s/Do/THURSDAY/g;
        #my $fr = $data[4];
        $data[4] =~ s/Fr/FRIDAY/g;
        #my $sa = $data[5];
        $data[5] =~ s/Sa/SATURDAY/g;
        #my $su = $data[6];
        $data[6] =~ s/So/SUNDAY/g;
	
	#my $url = "http://" . $host . ":" . $port . "/sites/schedule.html?".$mo."&".$tu."&".$we."&".$th."&".$fr."&".$sa."&".$su."&SEND=Save";
	my $url = "http://" . $host . ":" . $port . "/sites/schedule.html?".$data[0]."&".$data[1]."&".$data[2]."&".$data[3]."&".$data[4]."&".$data[5]."&".$data[6]."&SEND=Save";

	Log3 $name, 4, "HOMBOT ($name) - set schedule to $data[0],$data[1],$data[2],$data[3],$data[4],$data[5],$data[6]";
	    
	return HOMBOT_HTTP_POST( $hash,$url );
    }

    return undef;
}

sub HOMBOT_HTTP_POST($$) {

    my ( $hash, $url ) = @_;
    my $name = $hash->{NAME};
    
    my $state = ReadingsVal( $name, "state", 0 );
    
    readingsSingleUpdate( $hash, "state", "Send HTTP POST", 1 );
    
    HttpUtils_NonblockingGet(
	{
	    url		=> $url,
	    timeout	=> 10,
	    hash	=> $hash,
	    method	=> "GET",
	    doTrigger	=> 1,
	    callback	=> \&HOMBOT_HTTP_POSTerrorHandling,
	}
    );
    Log3 $name, 4, "HOMBOT ($name) - Send HTTP POST with URL $url";

    readingsSingleUpdate( $hash, "state", $state, 1 );

    return undef;
}

sub HOMBOT_HTTP_POSTerrorHandling($$$) {

    my ( $param, $err, $data ) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
    

    ### Begin Error Handling
    if( $hash->{helper}{setCmdErrorCounter} > 2 ) {
	readingsBeginUpdate( $hash );
	readingsBulkUpdate( $hash, "lastSetCommandState", "statusRequest_error" );
	
	if( $hash->{helper}{infoErrorCounter} > 9 && $hash->{helper}{setCmdErrorCounter} > 4 ) {
	    readingsBulkUpdate($hash, "lastSetCommandError", "unknown error, please contact the developer" );
	    
	    Log3 $name, 4, "HOMBOT ($name) - UNKNOWN ERROR, PLEASE CONTACT THE DEVELOPER, DEVICE DISABLED";
	    
	    $attr{$name}{disable} = 1;
	    readingsBulkUpdate( $hash, "state", "Unknown Error" );
	    $hash->{helper}{infoErrorCounter} = 0;
	    $hash->{helper}{setCmdErrorCounter} = 0;
	    
	    return;
	}

	elsif( $hash->{helper}{setCmdErrorCounter} > 4 ){
	    readingsBulkUpdate( $hash, "lastSetCommandError", "HTTP Server at Homebot offline" );
	    
	    Log3 $name, 4, "HOMBOT ($name) - Please check HTTP Server at Homebot";
	} 
	elsif( $hash->{helper}{setCmdErrorCounter} > 9 ) {
	    readingsBulkUpdate( $hash, "lastSetCommandError", "to many errors, check your network or device configuration" );
	    
	    Log3 $name, 4, "HOMBOT ($name) - To many Errors please check your Network or Device Configuration";

	    readingsBulkUpdate( $hash, "state", "To many Errors" );
	    $hash->{helper}{setCmdErrorCounter} = 0;
	}
	readingsEndUpdate( $hash, 1 );
    }
    
    if( defined( $err ) && $err ne "" ) {
	
        readingsBeginUpdate( $hash );
        readingsBulkUpdate( $hash, "state", $err ) if( ReadingsVal( $name, "state", 0 ) ne "initialized" );
        $hash->{helper}{setCmdErrorCounter} = ($hash->{helper}{setCmdErrorCounter} + 1);
	  
        readingsBulkUpdate( $hash, "lastSetCommandState", "cmd_error" );
        readingsBulkUpdate( $hash, "lastSetCommandError", "$err" );
          
        readingsEndUpdate( $hash, 1 );
	  
        Log3 $name, 5, "HOMBOT ($name) - HOMBOT_HTTP_POST: error while POST Command: $err";
	  
        return;
    }
 
    if( $data eq "" and exists( $param->{code} ) && $param->{code} ne 200 ) {
	readingsBeginUpdate( $hash );
	readingsBulkUpdate( $hash, "state", $param->{code} ) if( ReadingsVal( $hash, "state", 0 ) ne "initialized" );
	
	$hash->{helper}{setCmdErrorCounter} = ( $hash->{helper}{setCmdErrorCounter} + 1 );

	readingsBulkUpdate($hash, "lastSetCommandState", "cmd_error" );
	readingsBulkUpdate($hash, "lastSetCommandError", "http Error ".$param->{code} );
	readingsEndUpdate( $hash, 1 );
    
	Log3 $name, 5, "HOMBOT ($name) - HOMBOT_HTTP_POST: received http code ".$param->{code};

	return;
    }
        
    if( ( $data =~ /Error/i ) and exists( $param->{code} ) ) {
	readingsBeginUpdate( $hash );
	readingsBulkUpdate( $hash, "state", $param->{code} ) if( ReadingsVal( $name, "state", 0 ) ne "initialized" );
	
	$hash->{helper}{setCmdErrorCounter} = ( $hash->{helper}{setCmdErrorCounter} + 1 );

	readingsBulkUpdate( $hash, "lastSetCommandState", "cmd_error" );
    
	    if( $param->{code} eq 404 ) {
		readingsBulkUpdate( $hash, "lastSetCommandError", "HTTP Server at Homebot is offline!" );
	    } else {
		readingsBulkUpdate( $hash, "lastSetCommandError", "http error ".$param->{code} );
	    }
	
	return;
    }
    
    ### End Error Handling
    
    readingsSingleUpdate( $hash, "lastSetCommandState", "cmd_done", 1 );
    $hash->{helper}{setCmdErrorCounter} = 0;
    
    HOMBOT_Get_stateRequestLocal( $hash );
    
    return undef;
}



1;

=pod
=begin html

<a name="HOMBOT"></a>
<h3>HOMBOT</h3>
<ul>

</ul>

=end html
=begin html_DE

<a name="HOMBOT"></a>
<h3>HOMBOT</h3>
<ul>

</ul>

=end html_DE
=cut