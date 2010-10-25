#include "platform.h"
#include <mysql.h>

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#include <string.h>
#import "flatSurface.h"
#import "rayTrace.h"
#import "ctTree.h"
#import "fragment.h"
#import "shapeSignatureX2.h"
#import "hitListItem.h"
#include <math.h> 
#import "libCURLUploader.h"
#import "libCURLDownloader.h"
#include <sys/ipc.h>
#include <sys/shm.h>

typedef struct  
{
	int ID ;
	double score ;
} quickHit ;


NSInteger fileNameCompare( id A, id B, void *ctxt ) ;

int quickHitCompare( void *, void * ) ;

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    // This is an all-in-one tool for generating and comparing next-generation 
	// Shape Signatures ("version X") . 
	
	// Note that I will not try to bundle surface generation with this. 
	
	enum parseStates { GETTOKEN, GETFLAG }  ;
	
	int parseState, flagType ;
	
	// The enumerated list below is evolving - in particular there will need to be more scoring options
	
	enum flagTypes { GRIDSPACING, NUMSEGMENTS, LENGTHDELTA, MEPDELTA, RANDOMIZATIONANGLE, 
							SEGMENTCULLING, RESTARTRATE, SEED, PRINTOPTION, ORIENTATION, 
							SKIPSELFINTERSECTION, SCALE, COMPARETAG, NUMBEROFHITS, MAXHITS, MAXSCORE, FRAGSCORE,
							SORTBYWEIGHTEDSCORE, MAXPERCENTQUERYUNMATCHED, MAXPERCENTTARGETUNMATCHED,
							CORRELATIONSCORING, KEYTYPE, KEYINCREMENT, NEIGHBORLOWERBOUNDTOEXCLUDE,
							MERGENEIGHBORRINGS, TARGETISDIRECTORY, TARGETISMYSQLIDS, TARGETISMEMORYRSRC, PERMITFRAGMENTGROUPING, BIGFRAGMENTSIZE,
							MAXBIGFRAGMENTCOUNT, XMLIN, XMLOUT, EXPLODEDB, RANGE, URLIN, URLOUT,
							COMPRESS, DECOMPRESS, ABBREVIATEDINFO, MYSQLTABLENAME, MYSQLUSERNAME, MYSQLPASSWORD,
							MYSQLDBNAME, MYSQLHOSTNAME } ;
							
	
	enum { CREATEMODE, COMPAREMODE, INFOMODE, MEMORYRESOURCEMODE, KEYSMODE, KMEANSMODE, CHECKMODE, CONVERTMODE, UNDEFINED } mode ;
	
	mode = UNDEFINED ;
	
	int seed = 12345676 ;
	int restartRate = 100000 ;
	
	BOOL insideTrace = YES ;
	
	BOOL targetIsFile = YES ;
	BOOL targetIsDirectory = NO ;
	BOOL targetIsMySQLIDs = NO ;
	BOOL targetIsMemoryRsrc = NO ;
	
	double lengthDelta = 0.5 ;
	double MEPDelta = 0.05 ;
	double randomA = 5.0 * acos(-1.0)/180. ;
	int numSegments = 100000 ;
	BOOL segmentCulling = NO ;
	BOOL skipSelfIntersection = NO ;
	BOOL mergeNeighborRings = NO ;
	double scaleFactor = 1.0 ;
	double gridSpacing = 0.5 ;
		
 	double maxScore = 2.0 ;
	int maxHits = 100 ;
	BOOL fragmentScoring = NO ;
	
	int bigFragSize = 20 ;
	int maxBigFragCount = -1 ; 
	int smallFragmentSize = 5 ;
	
	BOOL sortByFragmentWeightedScore = YES ;
	
	BOOL useCorrelationScoring = NO ;
	
	double maxPercentQueryUnmatched = 100. ;
	double maxPercentTargetUnmatched = 100. ;
	
	BOOL keysWithFragments = YES ;
	double keyIncrement = 0.05 ;
	BOOL doNeighbors = NO ;
	double neighborLowerBoundToExclude = 0.1 ;
	
	BOOL permitFragmentGrouping = NO ;
	
	int numKMeansClusters = 0 ;
	
	BOOL xmlIN = NO ;
	BOOL xmlOUT = NO ;
	
	BOOL compressDBs = NO ;
	BOOL decompressDBs = NO ;
	
	BOOL explodeDBs = NO ;
	
	BOOL outputToURL = NO ;
	BOOL inputFromURL = NO ;
	
	BOOL abbreviatedInfo = YES ;
	
	int selectRangeLo = 0 ;
	int selectRangeHi = -1 ;
	
	NSString *compareTag = @"1DHISTO" ;
	
	NSString *printOption = @"NoPrint" ;
		
	NSString *mol2Directory = nil ;
	
	NSString *errorDirectory = nil ;
	
	NSString *XDBDirectory = nil ;
	
	NSString *queryDB = nil ;
	NSString *targetDB = nil ;
	NSString *outputDB = nil ;
	NSString *resourceFile = nil ;
	NSMutableArray *inputDBs = nil ;
	NSString *hitsFile = nil ;
	
	NSString *createDB = nil ;
	
	NSString *MySQLDB = @"zinc" ;
	NSString *MySQLUSER = @"root" ;
	NSString *MySQLPASSWORD = @"vr9tr74m" ;
	NSString *MySQLHOST = @"localhost" ;
	NSString *MySQLTABLE = @"compressedShapeSignatures" ;
	
							
	// Calculation parameters
	
	// Note that we will accept for input a directory of mol2 files (NOT multimol), with each mol2 
	// file paired with a surface file (and potentially an atom site file)
	// File name format:
	//		<mol>.mol2
	//		<mol>.flats
	//		<mol>.site (optional)
	
	
	
	if( argc < 3 )
		{
			printf( "USAGE: shapeSigX -create [ flags ] <input directory> <output DB> \n" ) ;
			printf( "USAGE: shapeSigX -compare [ flags ] <query DB> <target DB/directory/ID file/memrsrc> <hits file> \n" ) ;
			printf( "USAGE: shapeSigX -convert [ flags ] <out DB/directory> <input 1> [<input 2>] ...\n" ) ;
			printf( "USAGE: shapeSigX -memr [ flags ] <input directory>  \n" ) ;
			printf( "USAGE: shapeSigX -info <query DB> \n" ) ;
			printf( "USAGE: shapeSigX -keys [ flags ] <input directory> \n" ) ;
			printf( "USAGE: shapeSigX -check [ flags ] <input directory> <output directory> \n" ) ;
			printf( "-create flags:\n" ) ;
			printf( "\t-numseg <number of raytrace segments; default = 100000>\n" ) ;
			printf( "\t-gridspace <grid spacing; default = 1.0>\n" ) ;
			printf( "\t-ldelta <histogram length bin size; default = 0.5>\n" ) ;
			printf( "\t-randang <reflection randomization angle; default = 5.0 deg>\n" ) ;
			printf( "\t-cull <segment culling (yes|no); default = NO>\n" ) ;
			printf( "\t-restart <restart rate; default = 100000 (no restart)>\n" ) ;
			printf( "\t-seed <random number seed; default = 12345678 >\n" ) ;
			printf( "\t-orient <orientation (inside|outside); default = IN>\n" ) ;
			printf( "\t-skipSelf <skip self intersecting surface (yes|no); default = YES>\n" ) ;
			printf( "\t-scale <scale factor for ray-trace; default = 1.0>\n" ) ;
			printf( "\t-mergeRings <merge rings separated by one bond (yes|no); default = NO >\n" ) ;
			printf( "\t-printon <enable print option (raytrace|histogram)> \n" ) ;
			printf( "\t-keyIncrement <key discretization increment; default = 0.05>\n" ) ;
			printf( "\t-xmlOut <output XML database format (yes|no) ; default = NO>\n" ) ;
			printf( "\t-explode <explode signatures into separate files (yes|no) ; default = NO>\n" ) ;
			printf( "\t-urlOut <send output signatures to URL (yes|no) ; default = NO ; sets xmlOut = YES >\n" ) ;
			printf( "\t-urlIn <pull input data tarball from URL (yes|no) ; default = NO >\n" ) ;
			printf( "\t-compress <compress XML signatures (yes|no) ; default = NO ; sets xmlOut = YES >\n" ) ;
			printf( "-compare flags:\n" ) ;
			printf( "\t-targetdir <target DB is a directory (yes|no); default = NO >\n" ) ;
			printf( "\t-targetmysqlIDs <target file holds molecule IDs for mysql database (yes|no); default = NO>\n" ) ;
			printf( "\t-targetmem <target points to memory resource; quick compare, abbreviated output (yes|no); default = NO>\n" ) ;
			printf( "\t-mysqlDB <mysql target database; default = 'ZINC'>\n" ) ;
			printf( "\t-mysqlHost <mysql host; default = 'localhost'>\n" ) ;
			printf( "\t-mysqlTableName <table name with shape sigs; default = 'compressedShapeSignatures'>\n" ) ;
			printf( "\t-mysqlUserName <user name for mysql; default = 'root'>\n" ) ;
			printf( "\t-mysqlPassword <passwd for mysql; default = (hidden)>\n" ) ;
			printf( "\t-tag <histogram tag to use; default = 1DShape> \n" ) ;
			printf( "\t-fragscore <use fragment-based scoring (yes|no); default = NO>\n" ) ;
			printf( "\t-fraggroup <use fragment grouping w/ fragment scoring (yes|no); default = NO>\n" ) ;
			printf( "\t-bigfragsize <size of a \"big\" fragment (heavy atom count); default = 20 \n" ) ;
			printf( "\t-maxbigfragcount <maximum number of \"big\" fragments to group; default = -1 (no limit) \n" ) ;
			printf( "\t-corrscore <use correlation scoring (yes|no); default = NO>\n" ) ;
			printf( "\t-maxhits <maximum number of hits to return; default = 100> \n" ) ;
			printf( "\t-maxscore <maximum shape signature score to return; default = 2.0> \n" ) ;
			printf( "\t-sortBy <how to sort signatures; (minFrag | weightedFrag); default = weightedFrag> \n" ) ;
			printf( "\t-maxQueryUnmatched <max. %% query unmatched ; default = 100. (no constraint)> \n" ) ;
			printf( "\t-maxTargetUnmatched <max. %% target unmatched ; default = 100. (no constraint)> \n" ) ;
			printf( "\t-xmlIn <input XML database format (yes|no) ; default = NO>\n" ) ;
			printf( "\t-decompress <decompress XML input signatures (yes|no) ; default = NO ; sets xmlIn = YES >\n" ) ;
			printf( "-convert flags:\n" ) ;
			printf( "\t-decompress <decompress input signatures (yes|no); default = NO>\n") ;
			printf( "\t-compress <compress output signatures (yes|no); default = NO ; sets xmlOUT = YES >\n") ;
			printf( "\t-xmlIn <input XML database format (yes|no) ; default = NO>\n" ) ;
			printf( "\t-xmlOut <output XML database format (yes|no) ; default = NO>\n" ) ;
			printf( "\t-explode <explode signatures into separate files (yes|no) ; default = NO>\n" ) ;
			//printf( "-keys flags:\n" ) ;
			//printf( "\t-probIncrement <division for discretizing; default = 0.05> \n" ) ;
			//printf( "\t-keyType <(g)lobal or (f)fragment histos; default = fragment> \n" ) ;
			//printf( "\t-neighbors <probability lower bound to exclude> \n" ) ;
			printf( "-memr (create memory resource) flags:\n" ) ;
			printf( "\t-xmlIn <input XML database format (yes|no) ; default = NO>\n" ) ;
			printf( "\t-decompress <decompress input signatures (yes|no); default = NO>\n") ;
			printf( "-info flags:\n" ) ;
			printf( "\t-xmlIn <input XML database format (yes|no) ; default = NO>\n" ) ;
			printf( "\t-decompress <decompress input signatures (yes|no); default = NO>\n") ;
			printf( "\t-keyIncrement <key discretization increment; default = 0.05>\n" ) ;
			printf( "\t-abbreviatedInfo <only report name and fragment keys (yes|no); default = YES>\n" ) ;
			
			exit(1) ;
		}
		
		
	// Collect arguments and options
	
	parseState = GETTOKEN ;
	int i ;
	
	for( i = 1 ; i < argc ; ++i )
		{
			if( parseState == GETTOKEN )
				{
					if( argv[i][0] == '-' )
						{
							parseState = GETFLAG ;
							
							if( strcasestr( &argv[i][1], "create" ) == &argv[i][1] )
								{
									mode = CREATEMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "compare" ) == &argv[i][1] )
								{
									mode = COMPAREMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "convert" ) == &argv[i][1] )
								{
									mode = CONVERTMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "memr" ) == &argv[i][1] )
								{
									mode = MEMORYRESOURCEMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "info" ) == &argv[i][1] )
								{
									mode = INFOMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "keys" ) == &argv[i][1] )
								{
									mode = KEYSMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "kmeans" ) == &argv[i][1] )
								{
									mode = KMEANSMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "check" ) == &argv[i][1] )
								{
									mode = CHECKMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "grid" ) == &argv[i][1] )
									{
										flagType = GRIDSPACING ;
									}
							else if( strcasestr( &argv[i][1], "num" ) == &argv[i][1] )
									{
										flagType = NUMSEGMENTS ;
									}
							else if( strcasestr( &argv[i][1], "ldel" ) == &argv[i][1] )
									{
										flagType = LENGTHDELTA ;
									}
							else if( strcasestr( &argv[i][1], "rand" ) == &argv[i][1] )
									{
										flagType = RANDOMIZATIONANGLE ;
									}
							else if( strcasestr( &argv[i][1], "cul" ) == &argv[i][1] )
									{
										flagType = SEGMENTCULLING ;
									}
							else if( strcasestr( &argv[i][1], "rest" ) == &argv[i][1] )
									{
										flagType = RESTARTRATE ;
									}
							else if( strcasestr( &argv[i][1], "ori" ) == &argv[i][1] )
									{
										flagType = ORIENTATION ;
									}
							else if( strcasestr( &argv[i][1], "see" ) == &argv[i][1] )
									{
										flagType = SEED ;
									}
							else if( strcasestr( &argv[i][1], "skips" ) == &argv[i][1] )
									{
										flagType = SKIPSELFINTERSECTION ;
									}
							else if( strcasestr( &argv[i][1], "scale" ) == &argv[i][1] )
									{
										flagType = SCALE ;
									}
							else if( strcasestr( &argv[i][1], "pri" ) == &argv[i][1] )
									{
										flagType = PRINTOPTION ;
									}
							else if( strcasestr( &argv[i][1], "tag" ) == &argv[i][1] )
									{
										flagType = COMPARETAG ;
									}
							else if( strcasestr( &argv[i][1], "maxhit" ) == &argv[i][1] )
									{
										flagType = MAXHITS ;
									}
							else if( strcasestr( &argv[i][1], "maxscore" ) == &argv[i][1] )
									{
										flagType = MAXSCORE ;
									}
							else if( strcasestr( &argv[i][1], "fragscore" ) == &argv[i][1] )
								{
									flagType = FRAGSCORE ;
								}
							else if( strcasestr( &argv[i][1], "fraggroup" ) == &argv[i][1] )
								{
									flagType = PERMITFRAGMENTGROUPING ;
								}
							else if( strcasestr( &argv[i][1], "bigfragsize" ) == &argv[i][1] )
								{
									flagType = BIGFRAGMENTSIZE ;
								}
							else if( strcasestr( &argv[i][1], "maxbigfrag" ) == &argv[i][1] )
								{
									flagType = MAXBIGFRAGMENTCOUNT ;
								}
							else if( strcasestr( &argv[i][1], "sortbyweight" ) == &argv[i][1] )
								{
									flagType = SORTBYWEIGHTEDSCORE ;
								}
							else if( strcasestr( &argv[i][1], "queryunma" ) == &argv[i][1] )
								{
									flagType = MAXPERCENTQUERYUNMATCHED ;
								}
							else if( strcasestr( &argv[i][1], "targetunma" ) == &argv[i][1] )
								{
									flagType = MAXPERCENTTARGETUNMATCHED ;
								}
							else if( strcasestr( &argv[i][1], "corr" ) == &argv[i][1] )
								{
									flagType = CORRELATIONSCORING ;
								}
							else if( strcasestr( &argv[i][1], "keyIncr" ) == &argv[i][1] )
								{
									flagType = KEYINCREMENT ;
								}
							else if( strcasestr( &argv[i][1], "keyt" ) == &argv[i][1] )
								{
									flagType = KEYTYPE ;
								}
							else if( strcasestr( &argv[i][1], "neigh" ) == &argv[i][1] )
								{
									flagType = NEIGHBORLOWERBOUNDTOEXCLUDE ;
								}
							else if( strcasestr( &argv[i][1], "mergeR" ) )
								{
									flagType = MERGENEIGHBORRINGS ;
								}
							else if( strcasestr( &argv[i][1], "targetdir" ) == &argv[i][1] )
								{
									flagType = TARGETISDIRECTORY ;
								}
							else if( strcasestr( &argv[i][1], "targetmysql" ) == &argv[i][1] )
								{
									flagType = TARGETISMYSQLIDS ;
								}
							else if( strcasestr( &argv[i][1], "targetmem" ) == &argv[i][1] )
								{
									flagType = TARGETISMEMORYRSRC ;
								}
							else if( strcasestr( &argv[i][1], "xmlin" ) == &argv[i][1] )
								{
									flagType = XMLIN ;
								}
							else if( strcasestr( &argv[i][1], "xmlout" ) == &argv[i][1] )
								{
									flagType = XMLOUT ;
								}
							else if( strcasestr( &argv[i][1], "urlOut" ) == &argv[i][1] )
								{
									flagType = URLOUT ;
								}
							else if( strcasestr( &argv[i][1], "urlIn" ) == &argv[i][1] )
								{
									flagType = URLIN ;
								}
							else if( strcasestr( &argv[i][1], "compress" ) == &argv[i][1] )
								{
									flagType = COMPRESS ;
								}
							else if( strcasestr( &argv[i][1], "decompress" ) == &argv[i][1] )
								{
									flagType = DECOMPRESS ;
								}						
							else if( strcasestr( &argv[i][1], "explode" ) == &argv[i][1] )
								{
									flagType = EXPLODEDB ;
								}
							else if( strcasestr( &argv[i][1], "abbrev" ) == &argv[i][1] )
								{
									flagType = ABBREVIATEDINFO ;
								}
							else if( strcasestr( &argv[i][1], "range" ) == &argv[i][1] )
								{
									flagType = RANGE ;
								}
							else if( strcasestr( &argv[i][1], "mysqltable" ) == &argv[i][1] )
								{
									flagType = MYSQLTABLENAME ;
								}
							else if( strcasestr( &argv[i][1], "mysqluser" ) == &argv[i][1] )
								{
									flagType = MYSQLUSERNAME ;
								}
							else if( strcasestr( &argv[i][1], "mysqlpass" ) == &argv[i][1] )
								{
									flagType = MYSQLPASSWORD ;
								}
							else if( strcasestr( &argv[i][1], "mysqlhost" ) == &argv[i][1] )
								{
									flagType = MYSQLHOSTNAME ;
								}
							else if( strcasestr( &argv[i][1], "mysqldb" ) == &argv[i][1] )
								{
									flagType = MYSQLDBNAME ;
								}
							else
								{
									printf( "CAN'T INTERPRET FLAG - Exit!\n" ) ;
									exit(1) ;
								}
									
								continue ;
						}
					else
						{
							if( mode == CREATEMODE )
								{
									if( ! mol2Directory )
										{
											mol2Directory = [ [ NSString stringWithCString:argv[i] ] retain ] ;
											
											
										}
									else if( ! createDB )
										{
											createDB = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else
										{	
											printf( "TOO MANY ARGUMENTS - Exit!\n" ) ;
											exit(1) ;
										}
								}
							else if( mode == COMPAREMODE )
								{
									if( ! queryDB )
										{
											queryDB = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else if( ! targetDB )
										{
											targetDB = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else if( ! hitsFile )
										{
											hitsFile = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else
										{	
											printf( "TOO MANY ARGUMENTS - Exit!\n" ) ;
											exit(1) ;
										}
								}
							else if( mode == CONVERTMODE )
								{
									if( ! outputDB )
										{
											outputDB = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else
										{
											if( ! inputDBs ) inputDBs = [ [ NSMutableArray alloc ] initWithCapacity:100 ] ;
											
											[ inputDBs addObject:[ NSString stringWithCString:argv[i] ] ] ;
										}
								}
							else if( mode == INFOMODE )	
								{
									if( ! queryDB )
										{
											queryDB = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else
										{	
											printf( "TOO MANY ARGUMENTS - Exit!\n" ) ;
											exit(1) ;
										}
								}
							else if( mode == MEMORYRESOURCEMODE )	
								{
									if( ! queryDB )
										{
											queryDB = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else if( ! resourceFile )
										{
											resourceFile = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else
										{	
											printf( "TOO MANY ARGUMENTS - Exit!\n" ) ;
											exit(1) ;
										}
								}
						
							else if( mode == KEYSMODE )
								{
									if( ! XDBDirectory )
										{
											XDBDirectory = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else
										{
											printf( "TOO MANY ARGUMENTS - Exit!\n" ) ;
											exit(1) ;
										}
								}
							else if( mode == KMEANSMODE )
								{
									if( ! XDBDirectory )
										{
											XDBDirectory = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else if( numKMeansClusters == 0 )
										{
											numKMeansClusters = atoi( argv[i] ) ;
										}
									else
										{
											printf( "TOO MANY ARGUMENTS - Exit!\n" ) ;
											exit(1) ;
										}
								}
							else if( mode == CHECKMODE )
								{
									if( ! XDBDirectory )
										{
											XDBDirectory = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else if( ! errorDirectory )
										{
											errorDirectory = [ [ NSString stringWithCString:argv[i] ] retain ] ;
										}
									else
										{
											printf( "TOO MANY ARGUMENTS - Exit!\n" ) ;
											exit(1) ;
										}
								}
							else
								{
									printf( "FLAG -create, -compare, -convert OR -info MUST APPEAR FIRST - Exit!\n" ) ;
									exit(1) ;
								}
								
							continue ;

						}
				}
			else
				{
					// In GETFLAG state 

					parseState = GETTOKEN ;
					
					switch( flagType )
						{
							case GRIDSPACING:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
									
								gridSpacing = atof( argv[i] ) ; ;
								break ;

							case NUMSEGMENTS:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								numSegments = atoi( argv[i] ) ;
								break ;
								
							case LENGTHDELTA:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								lengthDelta = atof( argv[i] ) ;
								break ;
							
							case RANDOMIZATIONANGLE:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								randomA = atof( argv[i] ) * acos(-1.)/180. ;
								break ;
								
							case NEIGHBORLOWERBOUNDTOEXCLUDE:
								if( mode != KEYSMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								neighborLowerBoundToExclude = atof( argv[i] )  ;
								doNeighbors = YES ;
								break ;
								
							case SEGMENTCULLING:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										segmentCulling = YES ;
									}
								else
									{
										segmentCulling = NO ;
									}
								
								break ;
								
							case XMLIN:
								if( mode != COMPAREMODE && mode != CONVERTMODE 
									&& mode != INFOMODE && mode != MEMORYRESOURCEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										xmlIN = YES ;
									}
								else
									{
										xmlIN = NO ;
									}
								
								break ;
								
							case XMLOUT:
								if( mode != CREATEMODE && mode != CONVERTMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										xmlOUT = YES ;
									}
								else
									{
										xmlOUT = NO ;
									}
								
								break ;
							
							case URLOUT:
							if( mode != CREATEMODE && mode != CONVERTMODE )
								{
								printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
								exit(1) ;
								}
							if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
								{
									outputToURL = YES ;
									xmlOUT = YES ;
									explodeDBs = NO ;
								}
							else
								{
									outputToURL = NO ;
								}
							
							break ;
							
							case URLIN:
							if( mode != CREATEMODE && mode != CONVERTMODE )
								{
								printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
								exit(1) ;
								}
							if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
								{
									inputFromURL = YES ;
								}
							else
								{
									inputFromURL = NO ;
								}
							
							break ;
							
							case COMPRESS :
							if( mode != CREATEMODE && mode != CONVERTMODE )
								{
								printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
								exit(1) ;
								}
							if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
								{
									compressDBs = YES ;
									xmlOUT = YES ;
								}
							else
								{
									compressDBs = NO ;
								}
							
							break ;
							
							case DECOMPRESS :
							if( mode != COMPAREMODE && mode != CONVERTMODE && mode != INFOMODE
										&& mode != MEMORYRESOURCEMODE )
								{
									printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
									exit(1) ;
								}
							if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
								{
									decompressDBs = YES ;
									xmlIN = YES ;
								}
							else
								{
									decompressDBs = NO ;
								}
							
							break ;
							
							
							case EXPLODEDB:
								if( mode != CREATEMODE && mode != CONVERTMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										explodeDBs = YES ;
									}
								else
									{
										explodeDBs = NO ;
									}
								
								break ;
							
							case ABBREVIATEDINFO:
							if( mode != INFOMODE  )
								{
									printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
									exit(1) ;
								}
							if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
								{
									abbreviatedInfo = YES ;
								}
							else
								{
									abbreviatedInfo = NO ;
								}
							
							break ;
							
							case RANGE:
								if( mode != CONVERTMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								
								char *token = strtok( argv[i], "-," ) ;
								
								if( token[0] == 'a' || token[0] == 'A' )
									{
										selectRangeLo = 0 ;
										selectRangeHi = -1 ;
									}
								else
									{
										selectRangeLo = atoi( token ) ;
										
										token = strtok(NULL, "-," ) ;
										
										if( token[0] == 'e' || token[0] == 'E' )
											{
												selectRangeHi = -1 ;
											}
										else
											{
												selectRangeHi = atoi( argv[i] ) ;
											}
									}
								
								break ;
								
							case TARGETISDIRECTORY:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										targetIsDirectory = YES ;
										targetIsMySQLIDs = NO ;
										targetIsMemoryRsrc = NO ;
										targetIsFile = NO ;
									}
								else
									{
										targetIsDirectory = NO ;
									}
								
								break ;
							
							case TARGETISMYSQLIDS:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										targetIsMySQLIDs = YES ;
										targetIsDirectory = NO ;
										targetIsMemoryRsrc = NO ;
										targetIsFile = NO ;
									}
								else
									{
										targetIsMySQLIDs = NO ;
									}
							
							break ;
							
							case TARGETISMEMORYRSRC:
							if( mode != COMPAREMODE )
								{
									printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
									exit(1) ;
								}
							
							if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
								{
									targetIsMemoryRsrc = YES ;
									targetIsMySQLIDs = NO ;
									targetIsDirectory = NO ;
									targetIsFile = NO ;
								}
							else
								{
									targetIsMemoryRsrc = NO ;
								}
							
							break ;
							
								
							case MERGENEIGHBORRINGS:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										mergeNeighborRings = YES ;
									}
								else
									{
										mergeNeighborRings = NO ;
									}
								
								break ;
								
							case RESTARTRATE:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								restartRate = atoi( argv[i] ) ;
								break ;

							case ORIENTATION:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'o' || argv[i][0] == 'O' )
									{
										insideTrace = NO ;
									}
								else
									{
										insideTrace = YES ;
									}
								
								break ;
								
							case SEED:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								seed = atoi( argv[i] ) ;
								break ;
		
							case SKIPSELFINTERSECTION:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										skipSelfIntersection = YES ;
									}
								else
									{
										skipSelfIntersection = NO ;
									}
								
								break ;
								
							case FRAGSCORE:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										fragmentScoring = YES ;
									}
								else
									{
										fragmentScoring = NO ;
									}
								
								break ;
								
							case PERMITFRAGMENTGROUPING:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										permitFragmentGrouping = YES ;
									}
								else
									{
										permitFragmentGrouping = NO ;
									}
								
								break ;
								
							case CORRELATIONSCORING:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'y' || argv[i][0] == 'Y' )
									{
										useCorrelationScoring = YES ;
									}
								else
									{
										useCorrelationScoring = NO ;
									}
								
								break ;
							
								
							case SORTBYWEIGHTEDSCORE:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'a' || argv[i][0] == 'A' )
									{
										sortByFragmentWeightedScore = YES ;
									}
								else
									{
										sortByFragmentWeightedScore = NO ;
									}
								
								break ;
								
							case BIGFRAGMENTSIZE:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								bigFragSize = atoi( argv[i] ) ;
								
								break ;
								
							case MAXBIGFRAGMENTCOUNT:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								maxBigFragCount = atoi( argv[i] ) ;
								
								break ;
								
							case MAXPERCENTQUERYUNMATCHED:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								maxPercentQueryUnmatched = atof( argv[i] ) ;
								
								break ;
								
							case MAXPERCENTTARGETUNMATCHED:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								maxPercentTargetUnmatched = atof( argv[i] ) ;
								
								break ;

								
							case SCALE:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								scaleFactor = atof( argv[i] ) ;
								break ;
								
							case KEYINCREMENT:
								if( mode != CREATEMODE && mode != INFOMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								keyIncrement = atof( argv[i] ) ;
								break ;
								
							case PRINTOPTION:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'r' || argv[i][0] == 'R' )
									{
										printOption = @"printRaytrace" ;
									}
								else if( argv[i][0] == 'h' || argv[i][0] == 'H' )
									{
										printOption = @"printHistogram" ;
									}
								else
									{
										printf( "ILLEGAL PRINTOPTION - Exit!\n" ) ;
										exit(1) ;
									}
									
								break ;
								
								case KEYTYPE:
								if( mode != KEYSMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								if( argv[i][0] == 'g' || argv[i][0] == 'G' )
									{
										keysWithFragments = NO ;
									}
								else if( argv[i][0] == 'f' || argv[i][0] == 'F' )
									{
										keysWithFragments = YES  ;
									}
								else
									{
										printf( "ILLEGAL KEYTYPE OPTION - Exit!\n" ) ;
										exit(1) ;
									}
								break ;
								
									
								case COMPARETAG:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
										
									compareTag = 
									[ [ NSString alloc ] 
										initWithString:[ [ NSString stringWithCString:argv[i] ] uppercaseString ] ] ;
									break ;
									
								case MAXHITS:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
									maxHits = atoi( argv[i] ) ;
									break ;
									
								case MAXSCORE:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
									maxScore = atof( argv[i] ) ;
									break ;
							
								case MYSQLTABLENAME:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
							
									MySQLTABLE = [ [ NSString alloc ] initWithCString:argv[i] ] ;
									break ;
							
								case MYSQLUSERNAME:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
									
									MySQLUSER = [ [ NSString alloc ] initWithCString:argv[i] ] ;
									break ;
							
								case MYSQLDBNAME:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
									
									MySQLDB = [ [ NSString alloc ] initWithCString:argv[i] ] ;
									break ;

								case MYSQLHOSTNAME:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
									
									MySQLHOST = [ [ NSString alloc ] initWithCString:argv[i] ] ;
									break ;
							
								case MYSQLPASSWORD:
									if( mode != COMPAREMODE )
										{
											printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
											exit(1) ;
										}
									
									MySQLPASSWORD = [ [ NSString alloc ] initWithCString:argv[i] ] ;
									break ;
							
									
						}
				}
				
		}
					
	histogramStyle style ;
	style.lengthDelta = lengthDelta ;
	style.MEPDelta = MEPDelta ;
							
	// Initialize random number seed 

	// This was not enabled initially
	
	srandom( (unsigned) seed ) ;
							
	// Work flow
	
	// Handle Create mode first
	
	if( mode == CREATEMODE )
		{
			// First step - collect all files from directory. We need mol2 files (*.mol2), flats files
			// (*.flats) and potentially atom site files (*.site) 
				
			NSFileManager *fileManager = [ NSFileManager defaultManager ] ;
			
			NSError *fileError ;
		
		// Make sure of trailing / for convenience ...
		
		if( inputFromURL == NO )
			{
				if( [ mol2Directory characterAtIndex:([ mol2Directory length ] - 1) ] != '/' )
					{
						// Add the final slash
					
						NSString *temp = mol2Directory ;
						
						mol2Directory = [ [ mol2Directory stringByAppendingString:@"/" ] retain ] ;
					
						[ temp release ] ;
					}
			}
		
			if( inputFromURL == YES )
				{
					// We will collect directory as tar file from URL. We will check for .Z or .gz extension
				
					// In this case, 'mol2Directory' is reallly a URL
				
					libCURLDownloader *downloader = [ [ libCURLDownloader alloc ] initWithURL:mol2Directory ] ;
				
					[ downloader download ] ;
				
					// If successful, we replace the mol2Directory with the result from the URL download
				
					if( ! downloader->outputDirectory )
						{
							printf( "UNKNOWN ERROR - COULD NOT DOWNLOAD URL - Exit!\n" ) ;
							exit(1) ;
						}
					else
						{
							NSString *temp = mol2Directory ;
							mol2Directory = [ downloader->outputDirectory retain ] ;
							[ temp release ] ;
						}
				
					[ downloader release ] ;
				}
			
			
#ifdef LINUX
			NSArray *files = [ fileManager directoryContentsAtPath:mol2Directory ] ;
#else
			NSArray *files = [ fileManager contentsOfDirectoryAtPath:mol2Directory error:&fileError ] ;
#endif
			
			if( ! files )
				{
					printf( "DIRECTORY DOES NOT EXIST - Exit!\n" ) ;
					exit(1) ;
				}
				
			if( [ files count ] == 0 )
				{
					printf( "EMPTY DIRECTORY - Exit!\n" ) ;
					exit(1) ;
				}
				
				
			// Collect all mol2 files, flats and site files
			
			// To support GNUStep I am going to back off using predicates
			
			//NSArray *mol2Files =  [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF endswith '.mol2'" ] ] ;
			//NSArray *flatsFiles = [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.flats'" ] ] ;
			//NSArray *siteFiles =  [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.site'" ] ] ;
			
			NSMutableArray *mol2Files = [ [ NSMutableArray alloc ] initWithCapacity:[ files count ] ] ;
			NSMutableArray *flatsFiles = [ [ NSMutableArray alloc ] initWithCapacity:[ files count ] ] ;
			NSMutableArray *siteFiles = [ [ NSMutableArray alloc ] initWithCapacity:[ files count ] ] ;
			
			//[ mol2Files retain ] ;
			//[ flatsFiles retain ] ;
			//[ siteFiles retain ] ;
			
			NSEnumerator *fileEnumerator = [ files objectEnumerator ] ;
			NSString *nextFile ;

			while( ( nextFile = [ fileEnumerator nextObject ] ) )
				{
					if( [ nextFile hasSuffix:@".mol2" ] == YES )
						{
							[ mol2Files addObject:nextFile ] ;
						}
					else if( [ nextFile hasSuffix:@".flats" ] == YES )
						{
								[ flatsFiles addObject:nextFile ] ;
						}
					 else if( [ nextFile hasSuffix:@".site" ] == YES )
						{
								[ siteFiles addObject:nextFile ] ;
						}
				}

			[ mol2Files sortUsingFunction:fileNameCompare context:nil ] ;
			[ flatsFiles sortUsingFunction:fileNameCompare context:nil ] ;
			[ siteFiles  sortUsingFunction:fileNameCompare context:nil ] ;
			
			// We can assume that mol2 files and their associated flats, sites files occur in the same 
			// order - I will not allow possibility of gaps
			
			int mol2Count = [ mol2Files count ] ;
			
			NSMutableArray *theSignatures ;
			
			if( explodeDBs == NO && outputToURL == NO )
				{
					theSignatures = [ [ NSMutableArray alloc ] initWithCapacity:mol2Count ] ;
				}
			
			if( outputToURL == NO )
				{
					printf( "\nCreate new database - Process %d mol2 files in directory %s ... \n",
						   mol2Count, [ mol2Directory cString ] ) ;
				}
			else
				{
					printf( "\nUpload signatures to target URL - Process %d mol2 files in directory %s ... \n",
						   mol2Count, [ mol2Directory cString ] ) ;
				}
			
			
			if( explodeDBs == YES )
				{
					if( ! createDB )
						{
							printf( "NO OUTPUT DIRECTORY SPECIFIED - Exit!\n" ) ;
							exit(1) ;
						}
						
					printf( "\nAttempt to create output directory database %s ...\n", [ outputDB cString ] ) ;
					
					if( [ fileManager fileExistsAtPath:createDB ] == YES )
						{
							printf( "FILE/DIRECTORY ALREADY EXISTS - Exit!\n" ) ;
							exit(1) ;
						}
						
					if( [ fileManager createDirectoryAtPath:createDB withIntermediateDirectories:NO 
						attributes:nil error:NULL ] == NO )
						{
							printf( "DIRECTORY CREATION FAILED - Exit!\n" ) ;
							exit(1) ;
						}
				}


			int flatsCount = [ flatsFiles count ] ;
			
			if( mol2Count != flatsCount )
				{
					printf( "ONLY HAVE %d FLATS FILES IN DIRECTORY - Aborting - No database created!\n",
						flatsCount ) ;
					exit(1) ;
				}
			
			BOOL useSites = NO ;
			
			int siteCount = [ siteFiles count ] ;
			
			if( siteCount == 0 )
				{
					if( insideTrace == YES )
						{
							printf( "\nNo sites files specified - OK, inside raytrace in use. \n" ) ;
						}
					else
						{
							printf( "\nWARNING: Using exterior raytrace, but no atom site files in place!\n" ) ;
						}
				}
			else if( siteCount != mol2Count )
				{
					printf( "\nERROR - wrong number ( %d ) of site files present, does not match mol2 files - Aborting - No database created!\n",
								siteCount ) ;
					exit(1) ;
				}
			else
				{
					useSites = YES ;
					printf( "\nAtom site files are present and will be applied to limit the raytrace.\n" ) ;
				}
			
			
			int mol2Index ;
			
			// Process the mol2 files
			
			for( mol2Index = 0 ; mol2Index < mol2Count ; ++mol2Index )		
				{
					// To make cross-platform comparisons more consistent, I will reset the seed for 
					// each input molecule
					
					srandom( (unsigned) seed ) ;
					
					NSString *nextMol2Name = [ mol2Files objectAtIndex:mol2Index ] ;
					NSString *nextMol2File = [ mol2Directory stringByAppendingString:nextMol2Name ] ;
					
					NSString *mol2Root = [ [ nextMol2Name componentsSeparatedByString:@"." ] objectAtIndex:0 ] ;
					
					ctTree *nextTree = [ [ ctTree alloc ] initTreeFromMOL2File:[ nextMol2File cString ] ] ;
					
					if( ! nextTree )
						{
							printf( "ERROR IMPORTING MOLECULE %s - Skipping!\n", [ nextMol2File cString ] ) ;
							continue ;
						}
						
					// Assign atoms to fragments
					
					[ nextTree assignNodesToFragmentsByMergingNeighborRings:mergeNeighborRings ] ;
						
					// Sites file?
					
					NSString *nextSiteFile = nil ;
					
					if( useSites == YES )
						{
							NSString *nextSiteName = [ siteFiles objectAtIndex:mol2Index ] ;
							nextSiteFile = [ mol2Directory stringByAppendingString:nextSiteName ] ;
							
							NSString *siteRoot = [ [ nextSiteName componentsSeparatedByString:@"." ] objectAtIndex:0 ] ;
							
							if( [ mol2Root isEqualToString:siteRoot ] == NO )
								{	
									printf( "WARNING: NAME OF NEXT SITE FILE %s UNEXPECTED - mol2 name = %s ...\n",
										[ siteRoot cString ], [ mol2Root cString ] ) ;
								}
						}
					
						
					// Surface - check that file name matches mol2 - warning if not
					
					NSString *nextSurfaceName = [ flatsFiles objectAtIndex:mol2Index ] ;
					NSString *nextSurfaceFile = [ mol2Directory stringByAppendingString:nextSurfaceName ] ;
					
					NSString *surfaceRoot = [ [ nextSurfaceName componentsSeparatedByString:@"." ] objectAtIndex:0 ] ;
					
					if( [ mol2Root isEqualToString:surfaceRoot ] == NO )
						{	
							printf( "WARNING: NAME OF NEXT SURFACE FILE %s UNEXPECTED - mol2 name = %s ...\n",
								[ surfaceRoot cString ], [ mol2Root cString ] ) ;
						}
					
					printf( "@mol:%s\n", [ mol2Root cString ] ) ;
										
					// Assume file name of form <name>.mol2 (obviously)
					
					nextSurfaceFile = [ mol2Directory stringByAppendingString:[ flatsFiles objectAtIndex:mol2Index ] ] ;
						
					flatSurface *nextSurface = [ [ flatSurface alloc ] initWithFlatFile:nextSurfaceFile andTree:nextTree
													andSiteFile:nextSiteFile andGridSpacing:gridSpacing ] ;
					
					if( ! nextSurface )
						{
							printf( "ERROR IMPORTING SURFACE %s - Skipping!\n", [ nextSurfaceFile cString ] ) ;
							[ nextTree release ] ;
							continue ;
						}
						
					// Create the raytrace
					
					printf( "Process %s %d frags\n", [ nextMol2File cString ], nextTree->nFragments ) ;
					
					rayTrace *nextRayTrace = [ [ rayTrace alloc ] initWithSurface:nextSurface andNumSegments:numSegments 
							cullingEnabled:segmentCulling skipSelfIntersectingSurface:skipSelfIntersection 
							insideTrace:insideTrace randomizationAngle:randomA ] ;						
					
					if( [ printOption isEqualToString:@"printRaytrace" ] == YES )
						{
							NSString *logFile = [ mol2Directory stringByAppendingString:mol2Root ] ;
							logFile = [ logFile stringByAppendingString:@".log" ] ;
							
							[ nextRayTrace printRaytraceToFile:logFile ] ;
						}
					
					
					// Next signature 
				
					X2Signature *nextSignature = [ [ X2Signature alloc ] initForAllTagsUsingTree:nextTree 
																andRayTrace:nextRayTrace withStyle:style ] ;
													
					if( outputToURL == YES )
						{
							// Pipe to the target URL
						
							NSArray *oneSignature = [ NSArray 
													 arrayWithObject:[ nextSignature propertyListDict ] ] ;
							
							NSString *error ;
							
							NSData *theData = [ NSPropertyListSerialization dataFromPropertyList:oneSignature
																						  format:NSPropertyListXMLFormat_v1_0
																				errorDescription:&error] ;
							if( compressDBs == YES )
								{
									theData = [ X2Signature compress:theData ] ;
								}
						
							// Flesh out the data so we can easly extract keys and name on server side
						
							//NSMutableString *keyString = [ [ nextSignature->histogramBundleForTag objectForKey:@"1DHISTO" ] 
							//							  		keyStringsForBundleWithIncrement:0.05 ]  ;
						
							//NSMutableString *frontString = [ NSMutableString stringWithCapacity:1000 ] ;
						
							//[ frontString appendString:@"name=" ] ;
							//[ frontString appendString:nextSignature->sourceTree->treeName ] ;
							//[ frontString appendString:@"?keys=" ] ;
							//[ frontString 
							//	 appendString:[ [ nextSignature->histogramBundleForTag objectForKey:@"1DHISTO" ] 
							//		keyStringsForBundleWithIncrement:0.05 ] ] ;
						
							//[ frontString replaceOccurrencesOfString:@"\n" withString:@";" 
							//								 options:NSLiteralSearch range: NSMakeRange(0, [frontString length]) ] ;
							//[ frontString appendString:@"compressedSignatureData=" ] ;
						
							//NSMutableData *upData = [ NSMutableData dataWithData:[ frontString dataUsingEncoding:NSASCIIStringEncoding ] ] ;
						
							//[ upData appendData:theData ] ;
						
							NSString *fName = [ NSString stringWithFormat:@"%s.xml",
									[ nextSignature->sourceTree->treeName cString ] ] ;
						
							libCURLUploader *theUploader = [ [libCURLUploader alloc] 
															 initWithURL:createDB
															 data:theData fileName:fName 
															];
						
							[ theUploader upload ] ;
						
							[ theUploader release ] ;
								
								
						}
					else
						{
						if( explodeDBs == NO )
							{
								if( xmlOUT == NO )
									{
										[ theSignatures addObject:nextSignature ] ;
									}
								else
									{
										[ theSignatures addObject:[ nextSignature propertyListDict ] ] ;
									}
							}
						else
							{
							// Use standard name <tree name>_X2DB or <tree name>_X2DB.xml
							
							if( xmlOUT == NO )
								{
									NSString *path = [ NSString stringWithFormat:@"%s/%s_X2DB",
													  [ createDB cString], [ nextSignature->sourceTree->treeName cString ] ] ;
									
									NSArray *oneSignature = [ NSArray arrayWithObject:nextSignature ] ;
									
									if( [ NSArchiver archiveRootObject:oneSignature toFile:path ] == NO )
										{
											printf( "CREATION OF SINGLE X2SIGNATURE ARCHIVE FAILED! \n" ) ;
											exit(1) ;
										}
								
								
								}
							else
								{
									NSString *path ;
									if( compressDBs == NO )
										{
											path = [ NSString stringWithFormat:@"%s/%s_X2DB.xml",
															  [ createDB cString], [ nextSignature->sourceTree->treeName cString ] ] ;
										}
									else
										{
											path = [ NSString stringWithFormat:@"%s/%s_X2DB.xml.Z",
															  [ createDB cString], [ nextSignature->sourceTree->treeName cString ] ] ;
										}
									
									
									NSArray *oneSignature = [ NSArray 
															 arrayWithObject:[ nextSignature propertyListDict ] ] ;
									
									NSString *error ;
									
									NSData *theData = [ NSPropertyListSerialization dataFromPropertyList:oneSignature
																								  format:NSPropertyListXMLFormat_v1_0
																									errorDescription:&error] ;
									if( compressDBs == YES )
										{
											theData = [ X2Signature compress:theData ] ;
										}
									
									
									if( [ fileManager createFileAtPath:path contents:theData attributes:nil ] == NO )
										{
											printf( "CREATION OF SINGLE X2SIGNATURE XML ARCHIVE FAILED! \n" ) ;
											exit(1) ;
										}
								
								
								}
							}
						
						}
											
														
					// For debugging
					
					//NSString *thePropList = [ nextSignature propertyList ] ;
					
					// Make it again
					
					//X2Signature *signatureCopy = [ [ X2Signature alloc ] 
					//	initWithPropertyList:thePropList ] ;
					
					// Print the fragment keys
					
					histogramBundle *keyBundle = [ nextSignature->histogramBundleForTag objectForKey:@"1DHISTO" ] ;
					
					NSString *keyString = [ keyBundle keyStringsForBundleWithIncrement:keyIncrement ] ;
					
					printf( "%s", [ keyString cString ] ) ;
					
					[ keyString release ] ;
					
					// This release should be OK - in the case of "exploded" directory, should trigger signature dealloc
					
					[ nextSignature release ] ;
					
					
					// Every molecules, clear autorelease pool
					
					//if( mol2Index % 100 == 0 )
					//	{
							[ pool drain ] ;
							pool = [[NSAutoreleasePool alloc] init] ;
					//	}
						
					// Always trash surface object and rayTrace object
					
					[ nextTree release ] ;
					[ nextRayTrace release ] ;
					[ nextSurface release ] ;
				}
				
			// Archive to output file 
			
			if( explodeDBs == NO && outputToURL == NO )
				{
					if( xmlOUT == NO )
						{
							if( [ NSArchiver archiveRootObject:theSignatures toFile:createDB ] == NO )
								{
									printf( "CREATION OF X2SIGNATURE ARCHIVE FAILED! \n" ) ;
									exit(1) ;
								}
						}
					else
						{
							NSString *error ;
		
							NSData *theData = [ NSPropertyListSerialization dataFromPropertyList:theSignatures
												format:NSPropertyListXMLFormat_v1_0
												errorDescription:&error] ;
						
							if( compressDBs == YES )
								{
									theData = [ X2Signature compress:theData ] ;
								}
												
							if( [ fileManager createFileAtPath:createDB contents:theData attributes:nil ] == NO )
								{
									printf( "CREATION OF X2SIGNATURE XML ARCHIVE FAILED! \n" ) ;
									exit(1) ;
								}
						}
				}
			
		}
	else if( mode == COMPAREMODE )
		{
			// Compare two databases of X2 signatures
			
			// We permit the option that the target may be a directory of X2 signatures - it must 
			// contain nothing but!
			
			if( ! queryDB || ! targetDB )
				{
					printf( "FATAL ERROR - Exit!\n" ) ;
					exit(1) ;
				}
		
			// Can't use correlation score with a 2D histo
		
			if( ([compareTag rangeOfString:@"2D"]).location == 0
					&& useCorrelationScoring == YES )
				{
					printf("CAN'T USE CORRELATION SCORING WITH 2D SIGNATURE - Exit!\n");
					exit(1) ;
				}
				
			// Do we have full or relative paths?
			
			NSString *currentDirectory = [ [ NSFileManager defaultManager ] currentDirectoryPath ] ;
			NSString *tempPath ;
			
			NSRange rangeOfSlash = [ queryDB rangeOfString:@"/" options:NSLiteralSearch ] ;
			
			if( rangeOfSlash.location != 0 )
				{
					tempPath = [ currentDirectory stringByAppendingString:@"/" ] ;
					
					queryDB = [ [ tempPath stringByAppendingString:queryDB ] retain ] ;
				}
				
			rangeOfSlash = [ targetDB rangeOfString:@"/" options:NSLiteralSearch ] ;
			
			if( rangeOfSlash.location != 0 )
				{
					tempPath = [ currentDirectory stringByAppendingString:@"/" ] ;
					
					targetDB = [ [ tempPath stringByAppendingString:targetDB ] retain ] ;
				}
				

			// Need to read in the query and target databases
			
			NSMutableArray *querySignatures ;
		
			// If target is a directory - 
		
			NSMutableArray *DBFiles = nil ;
			NSMutableArray *DBIDs = nil ;
			
			if( xmlIN == NO )
				{
					querySignatures = [ NSUnarchiver unarchiveObjectWithFile:queryDB ] ;
				}
			else
				{
					querySignatures = [ [ NSMutableArray alloc ] initWithCapacity:1000 ] ;
					
					NSData *theData = [ NSData dataWithContentsOfFile:queryDB ] ;
				
					if( decompressDBs == YES )
						{
							theData = [ X2Signature decompress:theData ] ;
						}
					
					NSString *errorString ;
					NSPropertyListFormat theFormat ;
					
					NSArray *sourceArray = [ NSPropertyListSerialization propertyListFromData:theData 
							mutabilityOption:0 format:&theFormat 
							errorDescription:&errorString ] ;
							
					NSEnumerator *sourceArrayEnumerator = [ sourceArray objectEnumerator ] ;
					
					NSDictionary *nextSignatureDict ;
					
					while( ( nextSignatureDict = [ sourceArrayEnumerator nextObject ] ) )
						{
							X2Signature *nextSignature = [ [ X2Signature alloc ] 
								initWithPropertyListDict:nextSignatureDict ] ;
								
							[ querySignatures addObject:nextSignature ] ;
							[ nextSignature release ] ;
						}
				}
			
			NSMutableArray *targetSignatures = nil ;
			
			if( targetIsFile == YES  )
				{
					if( xmlIN == NO )
						{
							targetSignatures = [ NSUnarchiver unarchiveObjectWithFile:targetDB ] ;
						}
					else
						{
							targetSignatures = [ [ NSMutableArray alloc ] initWithCapacity:1000 ] ;
					
							NSData *theData = [ NSData dataWithContentsOfFile:targetDB ] ;
						
							if( decompressDBs == YES )
								{
									theData = [ X2Signature decompress:theData ] ;
								}
							
							NSString *errorString ;
							NSPropertyListFormat theFormat ;
							
							NSArray *sourceArray = [ NSPropertyListSerialization propertyListFromData:theData 
									mutabilityOption:0 format:&theFormat 
									errorDescription:&errorString ] ;
									
							NSEnumerator *sourceArrayEnumerator = [ sourceArray objectEnumerator ] ;
							
							NSDictionary *nextSignatureDict ;
							
							while( ( nextSignatureDict = [ sourceArrayEnumerator nextObject ] ) )
								{
									X2Signature *nextSignature = [ [ X2Signature alloc ] 
										initWithPropertyListDict:nextSignatureDict ] ;
										
									[ targetSignatures addObject:nextSignature ] ;
									[ nextSignature release ] ;
								}
						}
				}
			else if( targetIsMySQLIDs == YES )
				{
					NSError *error = nil ;
				
					NSString *fileContent = [ NSString stringWithContentsOfFile:targetDB 
													encoding:NSASCIIStringEncoding error:&error ] ;
				
					if( error )
						{
							printf( "ERROR READING FILE OF TARGET IDs - Exit!\n" ) ;
							exit(1) ;
						}
				
					DBIDs = [ fileContent componentsSeparatedByString:@"\n" ] ;
				
					targetSignatures = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
				}
			else if( targetIsDirectory == YES )
				{
					NSFileManager *fileManager = [ NSFileManager defaultManager ] ;
			
					NSError *fileError ;
					
#ifdef LINUX
					NSArray *files = [ fileManager directoryContentsAtPath:targetDB ] ;
#else
					NSArray *files = [ fileManager contentsOfDirectoryAtPath:targetDB error:&fileError ] ;
#endif
					
					if( ! files )
						{
							printf( "DIRECTORY DOES NOT EXIST - Exit!\n" ) ;
							exit(1) ;
						}
						
					if( [ files count ] == 0 )
						{
							printf( "EMPTY DIRECTORY - Exit!\n" ) ;
							exit(1) ;
						}
				
				
					// Collect all target DB file names
					
					NSEnumerator *fileEnumerator ;
					NSString *nextFile ;
					
					DBFiles = [ [ NSMutableArray alloc ] initWithCapacity:[ files count ] ] ;
					
					fileEnumerator = [ files objectEnumerator ] ;
					
					if( xmlIN == NO )
						{
							while( ( nextFile = [ fileEnumerator nextObject ] ) )
								{
									if( [ nextFile hasSuffix:@"X2DB" ] == YES )
										{
											[ DBFiles addObject:nextFile ] ;
										}
								}
							//DBFiles =  [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF endswith 'DB'" ] ] ;
						}
					else
						{
							while( ( nextFile = [ fileEnumerator nextObject ] ) )
								{
									if( [ nextFile hasSuffix:@"DB.xml" ] == YES || 
										[ nextFile hasSuffix:@"DB.xml.Z" ] == YES )
										{
											[ DBFiles addObject:nextFile ] ;
										}
								}
							//DBFiles =  [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF endswith 'DB.xml'" ] ] ;
						}
					
					// Assume no more than 1000 per file 
				
					targetSignatures = [ [ NSMutableArray alloc ] initWithCapacity:1000 ] ;
					
					//fileEnumerator = [ DBFiles objectEnumerator ] ;
					
					//NSString *pathRoot = [ targetDB stringByAppendingString:@"/" ] ;
					/*
					while( ( nextFile = [ fileEnumerator nextObject ] ) )
						{
							NSString *nextPath = [ pathRoot stringByAppendingString:nextFile ] ;
							
							if( xmlIN == NO )
								{
									[ targetSignatures addObjectsFromArray:[ NSUnarchiver unarchiveObjectWithFile:nextPath ] ] ;
								}
							else
								{
									NSData *theData = [ NSData dataWithContentsOfFile:nextPath ] ;
								
									if( decompressDBs == YES )
										{
											theData = [ X2Signature decompress:theData ] ;
										}
									
									NSString *errorString ;
									NSPropertyListFormat theFormat ;
							
									NSArray *sourceArray = [ NSPropertyListSerialization propertyListFromData:theData 
											mutabilityOption:0 format:&theFormat 
											errorDescription:&errorString ] ;
											
									NSEnumerator *sourceArrayEnumerator = [ sourceArray objectEnumerator ] ;
									
									NSDictionary *nextSignatureDict ;
									
									while( ( nextSignatureDict = [ sourceArrayEnumerator nextObject ] ) )
										{
											X2Signature *nextSignature = [ [ X2Signature alloc ] 
												initWithPropertyListDict:nextSignatureDict ] ;
												
											[ targetSignatures addObject:nextSignature ] ;
											[ nextSignature release ] ;
										}
								}
						}
					 */
				}
			else if( targetIsMemoryRsrc == YES )
				{
					// The design here is a little weak - this section will be "standalone" as it implements
					// a very different approach to searching and scoring.
				
					// Basic strategy - fragment histos for all query molecules will be collected, and will
					// be quickly compared against the contents of the data in the target memory resource.
					// Score between query and target will be taken as the average of the best query fragment histo - vs
					// target fragment histo score. Overall score for a target will be the best (lowest) of these
					// average scores. Hits will be stored in a simple struct, and will be sorted at the end. maxHits
					// will be recorded in a file which can be used for detailed compaison in 'Mysql' mode
				
				
					int shmID ;
				
					key_t rsrcKey ;
					
					// Does the resource file exist?
					
					NSFileManager *fileManager = [ NSFileManager defaultManager ] ;
					
					if( [ fileManager fileExistsAtPath:targetDB ] == NO )
						{
							printf( "FILE FOR TARGET RESOURCE MISSING - Exit!\n" ) ;
							exit(1) ;
							
						}
				
					rsrcKey = ftok( [ targetDB cString ], 0 ) ;
						
					shmID = shmget( rsrcKey, 0, 0 ) ;
						
					if( shmID < 0 )
						{
							printf( "Resource for %s not found in memory - Exit!\n", 
						   		[ targetDB cString ] ) ;
							exit(1) ;
						}
					
					// Map memory to our space
				
					void *inMem = shmat( shmID, (void *)0, 0 ) ;
				
					if( inMem < (void *)0 )
						{
							printf( "ERROR - Could not map shared memory object based on file %s - Exit!\n",
						   		[ targetDB cString ] ) ;
							exit(1) ;
						}
				
					// Collect histos from query
				
					int histoAlloc = 100 ;
				
					double **queryHistoBins = (double **) malloc( histoAlloc * sizeof( double * ) ) ;
					int *queryHistoNBins = (int *) malloc( histoAlloc * sizeof( int  ) ) ;
													 
					int nQueryHistos = 0 ;
													 
					double currentBinWidth = 0. ;
				
					NSEnumerator *querySignatureEnumerator = [ querySignatures objectEnumerator ] ;
				
					X2Signature *nextQuery ;
					NSMutableString *key = [ [ NSMutableString alloc ] initWithCapacity:10 ] ;
				
					while( ( nextQuery = [ querySignatureEnumerator nextObject ] ) )
						{
							histogramBundle *nextBundle = [ nextQuery->histogramBundleForTag objectForKey:@"1DHISTO" ] ;
						
							if( currentBinWidth == 0. )
								{
									currentBinWidth = nextBundle->lengthDelta ;
								}
							else if( nextBundle->lengthDelta != currentBinWidth )
								{
									printf( "BIN WIDTH MISMATCH WHILE PROCESSING QUERY HISTOGRAMS - Exit!\n" ) ;
									exit(1) ;
								}
						
							int nFrags = nextBundle->sourceTree->nFragments ;
						
							int jFrag ;
						
							for( jFrag = 1 ; jFrag <= nFrags ; ++jFrag )
								{
									[ key setString:@"" ] ;
									[ key appendFormat:@"%d_%d",jFrag,jFrag ] ;
								
									histogram *nextHisto = 
										[ nextBundle->sortedFragmentsToHistogram objectForKey:key ] ;
								
									// Get nonpadded length of histogram
								
									double *nextHistoData = nextHisto->binProbs ;
									int actualLength = nextBundle->nLengthBins ;
								
									int jBin ;
								
									for( jBin = actualLength - 1; jBin >= 0 ; --jBin )
										{
											if ( nextHistoData[jBin] == 0. )
												{
													--actualLength ;
												}
											else
												{
													break ;
												}
										}
								
									if( actualLength > 0 )
										{
											// Add a histogram
										
											if( nQueryHistos == histoAlloc )
												{
													histoAlloc += 100 ;
													
													queryHistoBins = (double **) realloc( queryHistoBins, histoAlloc * sizeof( double * ) ) ;
													queryHistoNBins = (int *) realloc( queryHistoNBins, histoAlloc * sizeof( int  ) ) ;
												}
																					  
											queryHistoNBins[nQueryHistos] = actualLength ;
											
											queryHistoBins[nQueryHistos] = nextHisto->binProbs ;
										
											++nQueryHistos ;
										}
								}
						
						}
														  
					// Start parsing the memory resource
				
					double *resourceBinWidth = inMem ;
					int *numTargetSignatures = (int *)( inMem + sizeof( double ) ) ;
				
					// Have less than 100 target fragments per signature
					
					double minScoreByFragment[100] ;
					int segmentsByFragment[100] ;
					
					double nextTargetHistoProb[200] ;
					int nextTargetHistoCount[200] ;
					int nextNBin ;
				
					void *inMemPtr = inMem + sizeof( double ) + sizeof( int ) ;
				
					int iSig, jBin ;
				
					int hitAlloc = 2. * maxHits ;
				
					int numHits = 0 ;
				
					quickHit *hits = (quickHit *) malloc( hitAlloc * sizeof( quickHit ) ) ;
				
					unsigned int molID ;
					unsigned short numTargetFrags ;
					short numTargetBins ;
					short shortVal ;
					unsigned int intVal ;
				
					double nextQueryScore ;
					double minQueryScore ;
				
					double percentComplete = 0. ;
				
					printf( "Compare %d query fragment histograms against %d target fragments --- \n\n",
						   	nQueryHistos, *numTargetSignatures ) ;
				
					for( iSig = 0 ; iSig < *numTargetSignatures ; ++iSig )
						{
							// Scan next signature
						
							memcpy(&molID, inMemPtr, sizeof( unsigned int )  ) ;
							inMemPtr += sizeof( unsigned int ) ;
						
							memcpy(&numTargetFrags, inMemPtr, sizeof( unsigned short )  ) ;
							inMemPtr += sizeof( unsigned short ) ;
						
							int jFrag ;
						
							int totalSegmentsForSig = 0 ;
						
							for( jFrag = 0 ; jFrag < numTargetFrags ; ++jFrag )
								{
									segmentsByFragment[jFrag] = 0 ;
								
									memcpy(&numTargetBins, inMemPtr, sizeof( short )  ) ;
									inMemPtr += sizeof(  short ) ;
								
									for( jBin = 0 ; jBin < numTargetBins ; ++jBin )
										{
											memcpy(&shortVal, inMemPtr, sizeof( short )  ) ;
											inMemPtr += sizeof(  short ) ;
										
											if( shortVal == -1 )
												{
													memcpy(&intVal, inMemPtr, sizeof( unsigned int )  ) ;
													inMemPtr += sizeof(  unsigned int ) ;
												
													nextTargetHistoCount[jBin] = intVal ;
													segmentsByFragment[jFrag] += intVal ;
													totalSegmentsForSig += intVal ;
												}
											else
												{
													nextTargetHistoCount[jBin] = shortVal ;
													segmentsByFragment[jFrag] += shortVal ;
													totalSegmentsForSig += shortVal ;
												}
										}
								
									for( jBin = 0 ; jBin < numTargetBins ; ++jBin )
										{
											nextTargetHistoProb[jBin] = ((double)nextTargetHistoCount[jBin])/segmentsByFragment[jFrag] ;
										}
								
									minQueryScore = 2. ;
									int iQueryHisto ;
									int maxBins ;
								
									for( iQueryHisto = 0 ; iQueryHisto < nQueryHistos ; ++iQueryHisto )
										{
											nextQueryScore = 0. ;
										
											if( numTargetBins > queryHistoNBins[iQueryHisto] )
												{
													maxBins = numTargetBins ;
												}
											else
												{
													maxBins = queryHistoNBins[iQueryHisto] ;
												}
										
											for( jBin = 0 ; jBin < maxBins ; ++jBin )
												{
													if( jBin >= queryHistoNBins[iQueryHisto] )
														{
															nextQueryScore += nextTargetHistoProb[jBin] ;
														}
													else if( jBin >= numTargetBins )
														{
															nextQueryScore += queryHistoBins[iQueryHisto][jBin] ;
														}
													else
														{
															nextQueryScore += fabs( nextTargetHistoProb[jBin] - queryHistoBins[iQueryHisto][jBin] ) ;
														}
												}
										
											if( nextQueryScore < minQueryScore ) minQueryScore = nextQueryScore ;
											
										}
								
									minScoreByFragment[jFrag] = minQueryScore ;
								
									
								}
						
							// Compute overall score for this target signature
						
							double compositeScore = 0. ;
						
							for( jFrag = 0 ; jFrag < numTargetFrags ; ++jFrag )
								{
									compositeScore += (minScoreByFragment[jFrag] * segmentsByFragment[jFrag]) / totalSegmentsForSig ;
								}
						
							hits[numHits].ID = molID ;
							hits[numHits].score = compositeScore ;
						
							// Sort and cull if needed
						
							++numHits ;
							
							if( numHits == hitAlloc )
								{
									qsort(hits, hitAlloc, sizeof(quickHit), quickHitCompare ) ;
								
									numHits = maxHits ;
								}
							
							if( (((double)iSig)/ *numTargetSignatures)*100. > percentComplete + 10. )
								{
									percentComplete += 10. ;
									printf( "%5.1f %% complete, at mol ID = %d\n", percentComplete, molID ) ;
								}
						}
						
					// Now we have maxHits quick hits, write to output file. Format will be molID\tscore
				
					// Final sort
				
					qsort(hits, numHits, sizeof(quickHit), quickHitCompare ) ;
				
					if( numHits > maxHits ) numHits = maxHits ;
				
					FILE *hitFile = fopen( [ hitsFile cString ], "w" ) ;
				
					int iHit ;
				
					for( iHit = 0 ; iHit < numHits ; ++iHit )
						{
							fprintf( hitFile, "%d\t%f\n", hits[iHit].ID, hits[iHit].score ) ;
						}
				
					fclose(hitFile) ;
				
					// Premature exit!
				
					exit(0) ;
					
				
				}
			else
				{
					printf( "ILLEGAL TARGET SPECIFICATION - Exit!\n" ) ;
					exit(1) ;
				}
						
			NSString *queryDBName = [ [ [ queryDB pathComponents ] lastObject ] retain ] ;
			NSString *targetDBName = [ [ [ targetDB pathComponents ] lastObject ] retain ] ;
			
						
			// Open the hits file 
			
			FILE *hitFILE = fopen( [ hitsFile cString ], "w" ) ;
			
			if( ! hitFILE )
				{
					printf( "COULD NOT OPEN HIT FILE FOR WRITING - Exit!\n" ) ;
					exit(1) ;
				}
				
			
			if( fragmentScoring == NO )
				{
					//tagToUse = [ [ compareTag stringByAppendingString:@"GLOBAL" ] retain ] ;
					
					// Non-fragment looks like this:
					// <version string>
					// QUERY: <name of query DB>\t\tPATH: <path to query DB>
					// TAG: <tag>
					// DESCRIPTION: <tag annotation>
					// NUMBER OF TARGET DATABASES: <#; can be > 1 if merged>
					// TARGET: <name of target DB>\t\tPATH: <path to target DB>
					//	[ can repeat for multiple targets - used with merged hit lists ]
					// ****HITS FOR QUERY MOLECULE:<name>
					// RANK\tTARGET MOL\tTARGET DB\tSCORE
					//<#>\t<name>\t<db name>\t<score>
					//		(repeat for all hits for query, repeat for all queries)
					
					
					
					
					
				}
			else
				{
				
					// Fragment version looks like this:
					// <version string>
					// QUERY: <name of query DB>\t\tPATH: <path to query DB>
					// TAG: <tag>
					// DESCRIPTION: <tag annotation>
					// NUMBER OF TARGET DATABASES: <#; can be > 1 if merged>
					// TARGET: <name of target DB>\t\tPATH: <path to target DB>
					//	[ can repeat for multiple targets - used with merged hit lists ]
					// ****HITS FOR QUERY MOLECULE:<name>
					// RANK\tTARGET MOL\tTARGET DB\tWEIGHTED SCORE\tMIN SCORE\tMAX SCORE\t%UNMATCHED QUERY\t%UNMATCHED TARGET\tMAPPING
					
					//tagToUse = [ [ compareTag stringByAppendingString:@"FRAGMENT" ] retain ] ;
				}
				
			
			fprintf( hitFILE, "%s\n", [ [ X2Signature version ] cString ] ) ;
					
			fprintf( hitFILE, "QUERY:%s\tPATH:%s\n", [ queryDBName cString ], [ queryDB cString ] ) ;
			fprintf( hitFILE, "TAG:%s\n", [ compareTag cString ] ) ;
			
			if( fragmentScoring == YES )
				{
					fprintf( hitFILE, "FRAGMENTSCORING:YES\n" ) ;
				}
			else
				{
					fprintf( hitFILE, "FRAGMENTSCORING:NO\n" ) ;
				}
				
			fprintf( hitFILE, "DESCRIPTION:%s\n", [ [ histogram descriptionForTag:compareTag ] cString ] ) ;
			fprintf( hitFILE, "NUMBER OF TARGET DATABASES:1\n" ) ;
			fprintf( hitFILE, "TARGET:%s\tPATH:%s\n", [ targetDBName cString ], [ targetDB cString ] ) ;
			
			// Compare all the queries against signatures
			
			NSMutableArray *hits = [ [ NSMutableArray alloc ] initWithCapacity:maxHits ] ;
			
			NSEnumerator *queryEnumerator = [ querySignatures objectEnumerator ] ;
			
			X2Signature *nextQuery, *nextTarget ;
			
			while( ( nextQuery = [ queryEnumerator nextObject ] ) )
				{
					[ hits removeAllObjects ] ;
				
					if( targetIsDirectory == NO && targetIsMySQLIDs == NO  )
						{
							// Already collected signatures
						
							int count = 0 ;
							int totalCount = [ targetSignatures count ] ;
						
							double currentPercent = 0. ;
						
							NSEnumerator *targetEnumerator = [ targetSignatures objectEnumerator ] ;
						
						
							while( ( nextTarget = [ targetEnumerator nextObject ] ) )
								{
									NSAutoreleasePool * localPool = [[NSAutoreleasePool alloc] init];
							
									NSArray *queryHits = [ X2Signature scoreQuerySignature:nextQuery againstTarget:nextTarget
																		  usingTag:compareTag withCorrelation:useCorrelationScoring
																	  useFragments:fragmentScoring fragmentGrouping:permitFragmentGrouping
																   bigFragmentSize:bigFragSize maxBigFragmentCount:maxBigFragCount ] ;
								
									++count ;
							
									if( ( ((double)count)/totalCount ) * 100 - currentPercent > 5. )
										{
											currentPercent += 5. ;
											printf( "%f \% of targets - %s\n", currentPercent, 
												[ nextTarget->sourceTree->treeName cString ]   ) ;
										
										}
								
									// Merge into hit list
							
									[ hitListItem merge:queryHits intoHitList:hits withMaxScore:maxScore 
										maxPercentQueryUnmatched:maxPercentQueryUnmatched
										maxPercentTargetUnmatched:maxPercentTargetUnmatched ] ;
							
									[ queryHits release ] ;
							
									[ localPool drain ] ;
							
							
							
								}
						
						}
					else if( targetIsMySQLIDs == YES )
						{
							NSString *nextID ;
							NSEnumerator *IDEnumerator = [ DBIDs objectEnumerator ] ;
							int count = 0 ;
						
							// Make connection to database
						
							int totalCount = [ DBIDs count ] ;
						
							double currentPercent = 0. ;
						
							MYSQL *conn;
							MYSQL_RES *result;
							MYSQL_ROW row;
							int num_fields;
							char sqlBuffer[10000] ;
							
							conn = mysql_init(NULL) ;
							
							mysql_real_connect(conn, [ MySQLHOST cString ], 
											   [ MySQLUSER cString ], [ MySQLPASSWORD cString ], 
											   [ MySQLDB cString ], 0, NULL, 0) ;
						
						
							while( ( nextID = [ IDEnumerator nextObject ] ) )
								{
									NSAutoreleasePool * localPool = [ [ NSAutoreleasePool alloc ] init ];
								
									[ targetSignatures removeAllObjects ] ;
								
									// Check for blank
								
									NSString *useID = [ nextID stringByTrimmingCharactersInSet:
													   [NSCharacterSet whitespaceAndNewlineCharacterSet ] ];
									if ( [ useID length ] == 0 ) continue ;
								
									// Check for score after ID
								
									NSArray *words = [useID componentsSeparatedByString:@"\t" ] ;
								
									if( [ words count ] == 2 )
										{
											nextID = [ words objectAtIndex:0 ] ;
										}
								
									sprintf( sqlBuffer, "SELECT NAME, data FROM %s WHERE ID = %d",
											[ MySQLTABLE cString ], [ nextID intValue ] ) ;
																
									mysql_query(conn, sqlBuffer ) ;
									result = mysql_store_result(conn) ;
								
									if( mysql_num_rows(result) != 1 )
										{
											printf( "WARNING - could not retrieve target ID = %s | %d\n",
												   [nextID cString ], [ nextID intValue ] ) ;
											mysql_free_result(result);
											[ localPool drain ] ;
											continue ;
										}
									
									num_fields = mysql_num_fields(result) ;
								
									++count ;
								
									row = mysql_fetch_row( result ) ;
								
									unsigned long *lengths = mysql_fetch_lengths( result ) ;
								
									if( ( ((double)count)/totalCount ) * 100 - currentPercent > 5. )
										{
											currentPercent += 5. ;
											printf( "%f %% of target signatures : at - %s\n", currentPercent, row[0] ) ;
										
										}
									
									NSData *theData = [ NSData dataWithBytes:row[1] length:lengths[1] ] ;
								
									if( decompressDBs == YES )
										{
											theData = [ X2Signature decompress:theData ] ;
										}
									
									NSString *errorString ;
									NSPropertyListFormat theFormat ;
									
									NSArray *sourceArray = [ NSPropertyListSerialization propertyListFromData:theData 
																							 mutabilityOption:0 format:&theFormat 
																							 errorDescription:&errorString ] ;
									
									NSEnumerator *sourceArrayEnumerator = [ sourceArray objectEnumerator ] ;
									
									NSDictionary *nextSignatureDict ;
									
									while( ( nextSignatureDict = [ sourceArrayEnumerator nextObject ] ) )
										{
											X2Signature *nextSignature = [ [ X2Signature alloc ] 
																		  initWithPropertyListDict:nextSignatureDict ] ;
											
											[ targetSignatures addObject:nextSignature ] ;
											[ nextSignature release ] ;
										}
																			
									mysql_free_result(result);
								
									NSEnumerator *targetEnumerator = [ targetSignatures objectEnumerator ] ;
								
									while ( ( nextTarget = [ targetEnumerator nextObject ] ) )
										{
									
									
											NSArray *queryHits = [ X2Signature scoreQuerySignature:nextQuery againstTarget:nextTarget
																						  usingTag:compareTag withCorrelation:useCorrelationScoring
																					  useFragments:fragmentScoring fragmentGrouping:permitFragmentGrouping
																				   bigFragmentSize:bigFragSize maxBigFragmentCount:maxBigFragCount ] ;
									
											// Merge into hit list
									
											[ hitListItem merge:queryHits intoHitList:hits withMaxScore:maxScore 
												maxPercentQueryUnmatched:maxPercentQueryUnmatched
												maxPercentTargetUnmatched:maxPercentTargetUnmatched ] ;
									
											[ queryHits release ] ;
									
										}
										
									[ localPool drain ] ;
									
								}
							mysql_close(conn) ;
						}
					else
						{
							int count = 0 ;
							int totalCount = [ DBFiles count ] ;
							
							double currentPercent = 0. ;
						
							NSEnumerator *fileEnumerator = [ DBFiles objectEnumerator ] ;
							
							NSString *pathRoot = [ targetDB stringByAppendingString:@"/" ] ;
						
							NSString *nextFile ;
							
							while( ( nextFile = [ fileEnumerator nextObject ] ) )
								{
									NSAutoreleasePool * localPool = [ [ NSAutoreleasePool alloc ] init ];
									
									// Memory leak for testing
									//targetSignatures = [ [ NSMutableArray alloc ] initWithCapacity:2 ] ;
									[ targetSignatures removeAllObjects ] ;
								
									NSString *nextPath = [ pathRoot stringByAppendingString:nextFile ] ;
								
									if( xmlIN == NO )
										{
											[ targetSignatures addObjectsFromArray:[ NSUnarchiver unarchiveObjectWithFile:nextPath ] ] ;
										}
									else
										{
											NSData *theData = [ NSData dataWithContentsOfFile:nextPath ] ;
									
											if( decompressDBs == YES )
												{
													theData = [ X2Signature decompress:theData ] ;
												}
									
											NSString *errorString ;
											NSPropertyListFormat theFormat ;
									
											NSArray *sourceArray = [ NSPropertyListSerialization propertyListFromData:theData 
																							 mutabilityOption:0 format:&theFormat 
																							 errorDescription:&errorString ] ;
									
											NSEnumerator *sourceArrayEnumerator = [ sourceArray objectEnumerator ] ;
									
											NSDictionary *nextSignatureDict ;
									
											while( ( nextSignatureDict = [ sourceArrayEnumerator nextObject ] ) )
												{
													X2Signature *nextSignature = [ [ X2Signature alloc ] 
																	  initWithPropertyListDict:nextSignatureDict ] ;
										
													[ targetSignatures addObject:nextSignature ] ;
													[ nextSignature release ] ;
												}
										}
								
									NSEnumerator *targetEnumerator = [ targetSignatures objectEnumerator ] ;
								
									++count ;
								
									if( ( ((double)count)/totalCount ) * 100 - currentPercent > 5. )
										{
											currentPercent += 5. ;
											printf( "%f %% of target DB - %s\n", currentPercent, 
												[ nextPath cString ] ) ;
										
										}
								
									while ( ( nextTarget = [ targetEnumerator nextObject ] ) )
										{
											
									
											NSArray *queryHits = [ X2Signature scoreQuerySignature:nextQuery againstTarget:nextTarget
																						  usingTag:compareTag withCorrelation:useCorrelationScoring
																					  useFragments:fragmentScoring fragmentGrouping:permitFragmentGrouping
																				   bigFragmentSize:bigFragSize maxBigFragmentCount:maxBigFragCount ] ;
									
											// Merge into hit list
									
											[ hitListItem merge:queryHits intoHitList:hits withMaxScore:maxScore 
												maxPercentQueryUnmatched:maxPercentQueryUnmatched
												maxPercentTargetUnmatched:maxPercentTargetUnmatched ] ;
									
											[ queryHits release ] ;
									
											
									
									
									
										}
								
									[ localPool drain ] ;
								
								}						
						}
					
						
					// Final sort 
				
					[ hitListItem sortHits:hits useWeightedScore:sortByFragmentWeightedScore
							retainHits:maxHits  ] ;
							
					// Write out hits
					
					NSEnumerator *hitListEnumerator = [ hits objectEnumerator ] ;
					
					hitListItem *nextHit ;
					int count = 1 ;
				
					fprintf( hitFILE, "*****HITS FOR QUERY MOLECULE:%s DB:%s\n", [ nextQuery->sourceTree->treeName cString ],
						[ queryDBName cString ] ) ;
					
					while( ( nextHit = [ hitListEnumerator nextObject ] ) )
						{
							if( fragmentScoring == YES )
								{
									// Rank, target name, target DB, mean score, min score, max score, %query unmatched,
									//				%target unmatched
								
									fprintf( hitFILE, "%d\t%s\t%s\t%f\t%f\t%f\t%f\t%f\t", 
										count, [ nextHit->targetName cString ],
										[ targetDBName cString ], nextHit->weightedScore, nextHit->minimumScore, 
										nextHit->maximumScore, nextHit->percentQueryUnmatched, 
										nextHit->percentTargetUnmatched ) ;
									
										
									NSEnumerator *histoMatchEnumerator = [ nextHit->fragmentGroupPairs objectEnumerator ] ;
									
									NSArray *nextFragmentGroupPair ;
									
									while( ( nextFragmentGroupPair = [ histoMatchEnumerator nextObject ] ) )
										{
											// Histo-histo score should have been added as third element of the
											// histogram pair by call to scoreQuerySignature...
											
											NSArray *groupFragments1 = [ nextFragmentGroupPair objectAtIndex:0 ] ;
											NSArray *groupFragments2 = [ nextFragmentGroupPair objectAtIndex:1 ] ;
											double groupMatchScore = [ [ nextFragmentGroupPair objectAtIndex:2 ] doubleValue ] ;
											int qCount = [ [ nextFragmentGroupPair objectAtIndex:3 ] intValue ] ;
											int tCount = [ [ nextFragmentGroupPair objectAtIndex:4 ] intValue ] ;
											
											// If either group is empty, don't report this
											
											if( qCount == 0 || tCount == 0 ) continue ;
											
											fprintf(hitFILE,  "[(" ) ;
											
											int k ;
											
											for( k = 0 ; k < [ groupFragments1 count ] ; ++k )
												{
													fprintf( hitFILE, "%s", [ [ groupFragments1 objectAtIndex:k ] cString ] ) ;
													if( k < [ groupFragments1 count ] - 1 ) fprintf(hitFILE,  "," ) ;
												}
												
											fprintf( hitFILE, ")-(" ) ;
											
										
											for( k = 0 ; k < [ groupFragments2 count ] ; ++k )
												{
													fprintf( hitFILE, "%s", [ [ groupFragments2 objectAtIndex:k ] cString ] ) ;
													if( k < [ groupFragments2 count ] - 1 ) fprintf(hitFILE,  "," ) ;
												}
												
											fprintf( hitFILE, "):%f] ", groupMatchScore ) ;
											
										}
										
									fprintf( hitFILE, "\n" ) ;
								}
							else
								{
									// Rank, target name, target DB, mean score
									
									fprintf( hitFILE, "%d\t%s\t%s\t%f\n", 
										count, [ nextHit->targetName cString ],
										[ targetDBName cString ], nextHit->weightedScore ) ;
								}
								
							++count ;
						}
				
					
				}
				
			fclose( hitFILE ) ;
		
		}
	else if( mode == INFOMODE )
		{
			// Read the DB, and print information for each entry, specficically assignments of atoms to 
			// fragments and histograms. 
		
			// We always assume for now that the database is a single file (NOT a directory)

			// Need to read in the query database
		
			NSMutableArray *querySignatures ;
		
			if( xmlIN == NO )
				{
					querySignatures = [ NSUnarchiver unarchiveObjectWithFile:queryDB ] ;
				}
			else
				{
					querySignatures = [ [ NSMutableArray alloc ] initWithCapacity:1000 ] ;
					
					NSData *theData = [ NSData dataWithContentsOfFile:queryDB ] ;
					
					if( decompressDBs == YES )
						{
							theData = [ X2Signature decompress:theData ] ;
						}
					
					NSString *errorString ;
					NSPropertyListFormat theFormat ;
					
					NSArray *sourceArray = [ NSPropertyListSerialization propertyListFromData:theData 
																			 mutabilityOption:0 format:&theFormat 
																			 errorDescription:&errorString ] ;
					
					NSEnumerator *sourceArrayEnumerator = [ sourceArray objectEnumerator ] ;
					
					NSDictionary *nextSignatureDict ;
					
					while( ( nextSignatureDict = [ sourceArrayEnumerator nextObject ] ) )
						{
							X2Signature *nextSignature = [ [ X2Signature alloc ] 
														  initWithPropertyListDict:nextSignatureDict ] ;
							
							[ querySignatures addObject:nextSignature ] ;
							[ nextSignature release ] ;
						}
				}
		

			NSEnumerator *queryEnumerator = [ querySignatures objectEnumerator ] ;

			X2Signature *nextQuery ;

			while( ( nextQuery = [ queryEnumerator nextObject ] ) )
				{
					// First report name and atom fragment assignments

					printf( "@molecule:%s\n", [ nextQuery->sourceTree->treeName cString ] ) ;
				
					NSMutableString *keyString = [ [ nextQuery->histogramBundleForTag objectForKey:@"1DHISTO" ] 
												  keyStringsForBundleWithIncrement:keyIncrement ]  ;
				
					printf( "%s", [ keyString cString ] ) ;
				
					if( abbreviatedInfo == YES ) continue ;

					// Fragment assignments

					int j, k ;

					for( j = 1 ; j <= nextQuery->sourceTree->nFragments ; ++j )
						{
							printf( "\tFragment %d:\n\t", j ) ;

							for( k = 0 ; k < nextQuery->sourceTree->nNodes ; ++k )
								{
									if( nextQuery->sourceTree->nodes[k]->fragmentIndex == j )
										{
											printf( "%s ", 
												[ [ nextQuery->sourceTree->nodes[k] returnPropertyForKey:@"atomName" ] cString ] ) ;
										}
								}

							printf( "\n" ) ;

						}

					// Print out histograms

					printf( "\n\tTOTAL # SEGMENTS = %d\n",nextQuery->totalSegments ) ;
					
					// Do the 1DHISTOs
					
					histogramBundle *the1DBundle = [ nextQuery->histogramBundleForTag objectForKey:@"1DHISTO" ] ;

					printf( "\n\t--------GLOBAL HISTOGRAM\n" ) ;
					
					histogram *globalHisto = [ the1DBundle->sortedFragmentsToHistogram objectForKey:@"GLOBAL" ] ;
					
					printf( "\t#BINS = %d\n", globalHisto->hostBundle->nBins ) ;
							printf( "\t#LENGTH BINS = %d\n", globalHisto->hostBundle->nLengthBins ) ;
							printf( "\tLENGTH DELTA = %f\n", globalHisto->hostBundle->lengthDelta ) ;

					for( j = 0 ; j < globalHisto->hostBundle->nLengthBins ; ++j )
						{
							printf( "\t\t%f\t%d\t%f\n", j*globalHisto->hostBundle->lengthDelta, 
								globalHisto->binCounts[j],
								globalHisto->binProbs[j] ) ;
						}


					printf( "\n\t--------FRAGMENT HISTOGRAMS\n" ) ;

					NSEnumerator *fragmentTagEnumerator = [ [ the1DBundle->sortedFragmentsToHistogram allKeys ] objectEnumerator ] ;
					
					NSString *nextTag ;
					
					while( ( nextTag = [ fragmentTagEnumerator nextObject ] ) )
						{
							if( [ nextTag isEqualToString:@"GLOBAL" ] == YES ) continue ;
							
							printf( "\tHISTOGRAM: %s\n", [ nextTag cString ] ) ;
							
							histogram *fragmentHisto = [ the1DBundle->sortedFragmentsToHistogram objectForKey:nextTag ] ;

							printf( "\t#SEGMENTS = %d\n", fragmentHisto->segmentCount ) ;
							printf( "\t#BINS = %d\n", fragmentHisto->nBins ) ;
							printf( "\t#LENGTH BINS = %d\n", fragmentHisto->hostBundle->nLengthBins ) ;
							printf( "\tLENGTH DELTA = %f\n", fragmentHisto->hostBundle->lengthDelta ) ;

							for( j = 0 ; j < fragmentHisto->hostBundle->nLengthBins ; ++j )
								{
									printf( "\t\t%f\t%d\t%f\n", j*fragmentHisto->hostBundle->lengthDelta, 
										fragmentHisto->binCounts[j],
										fragmentHisto->binProbs[j] ) ;
								}
						}



				}
		}
	else if ( mode == MEMORYRESOURCEMODE )
		{
			int shmID ;
		
			key_t rsrcKey ;
		
			// Does the resource file already exist? If so, create the shared segment and exit
		
			NSFileManager *fileManager = [ NSFileManager defaultManager ] ;
		
			if( [ fileManager fileExistsAtPath:resourceFile ] == YES )
				{
					rsrcKey = ftok( [ resourceFile cString ], 0 ) ;
				
					// Resource already exists?
				
					shmID = shmget( rsrcKey, 0, 0 ) ;
				
					if( shmID >= 0 )
						{
							printf( "Resource for %s already exists - nothing done - Exit!\n", 
								   		[ resourceFile cString ] ) ;
							exit(0) ;
						}
				
					// Read the file and create resource for it
				
					NSData *fileContent = [ fileManager contentsAtPath:resourceFile ] ;
				
					void *inMem = (void *) [ fileContent bytes ] ;
				
					shmID = shmget( rsrcKey, [ fileContent length ], 0644 | IPC_CREAT) ;
				
					if( shmID < 0 )
						{
							printf( "ERROR - Could not create shared memory object based on file %s - Exit!\n",
								   [ resourceFile cString ] ) ;
							exit(1) ;
						}
				
					// Map memory to our space
				
					void *sharedMem = shmat( shmID, (void *)0, 0 ) ;
				
					if( sharedMem < (void *)0 )
						{
							printf( "ERROR - Could not map shared memory object based on file %s - Exit!\n",
							   [ resourceFile cString ] ) ;
							exit(1) ;
						}
				
					// Copy our data into shared memory 
				
					memcpy( sharedMem, (void *)inMem, [ fileContent length ] ) ;
				
					// Should be success!
				
					printf( "Finished creating shared memory segment - Bye!\n" ) ;
					exit(0) ;
					
					
				}
		
		
			// Create a memory resource using the "small" struct
		
			// Enumerate all the files in the directory, collect just the 1D sigs for the fragments, 
			// save in our in-memory struct
		
			NSError *error ;
		
			NSArray *files = [ fileManager contentsOfDirectoryAtPath:queryDB error:&error ] ;
		
			NSEnumerator *fileEnumerator = [ files objectEnumerator ] ;
		
			NSString *nextFile, *nextPath ;

		
			int count ;
			int numFiles = [ files count ] ;
			double percentComplete = 0. ;
		
			printf( "Begin import of %d files to create shared memory segment ...\n", numFiles ) ;
		
			int smallSigAlloc = 100000 ;
		
			void *inMem = (void *) malloc( smallSigAlloc ) ;
		
			void *inMemPtr = inMem ;
		
			// This is an incredibly stupid linear data structure - 
			// First 8 bytes - bin width (as a double)
			// Next 4 bytes - number of signatures (as unsigned int)
			// Followed by (numSignatures X ):
			// 		4 bytes (unsigned long) = Next mol ID
			//		2 bytes (unsigned short) = number of frags next molecule
			//		(num Frags X ):
			//			2 bytes (unsigned short) = number of bins next signature
			//			(num bins X):
			//				(unsigned short)
			//				if content = -1, use next 4 bytes (unsigned int), then switch back to original pattern
		
			double *binWidth = (double *)inMem ;
			unsigned int *numSignatures = (unsigned int *)( inMem + sizeof( double ) ) ;
			inMemPtr = inMem + sizeof( double ) + sizeof( unsigned int ) ;
		
			int smallSigUsed = sizeof( double ) + sizeof( unsigned int ) ;
		
			NSAutoreleasePool *localPool = [  [ NSAutoreleasePool alloc ] init ] ;
		
			*binWidth = 0. ;
		
			if( [ queryDB hasSuffix:@"/" ] == NO )
				{
					queryDB = [ [ queryDB stringByAppendingString:@"/" ] retain ] ;
				}
		
			count = 0 ;
		
			while( ( nextFile = [ fileEnumerator nextObject ] ) )
				{
					
					nextPath = [ queryDB stringByAppendingString:nextFile ] ;
					   	
				
					NSRange theRange = [ nextPath rangeOfString:@"X2DB" ] ;
				
					if( theRange.location == NSNotFound )
						{
							printf( "Warning - file %s not processed \n", [ nextPath cString ] ) ;
							continue ;
						}
				
				
					// Make sure legal suffix
					
					if( [ nextPath hasSuffix:@"X2DB" ] == NO &&
					   	[ nextPath hasSuffix:@".xml" ] == NO &&
					    [ nextPath hasSuffix:@".xml.Z" ] == NO )
						{
							continue ;
						}
		
					NSMutableArray *fileSignatures ;
								
					if( xmlIN == NO )
						{
							fileSignatures = [ NSUnarchiver unarchiveObjectWithFile:nextPath ] ;
						}
					else
						{
							fileSignatures = [ NSMutableArray arrayWithCapacity:1000 ] ;
					
							NSData *theData = [ NSData dataWithContentsOfFile:nextPath ] ;
					
							if( decompressDBs == YES )
								{
									theData = [ X2Signature decompress:theData ] ;
								}
					
							NSString *errorString ;
							NSPropertyListFormat theFormat ;
					
							NSArray *fileArray = [ NSPropertyListSerialization propertyListFromData:theData 
																			 mutabilityOption:0 format:&theFormat 
																			 errorDescription:&errorString ] ;
					
							NSEnumerator *fileArrayEnumerator = [ fileArray objectEnumerator ] ;
					
							NSDictionary *nextSignatureDict ;
					
							while( ( nextSignatureDict = [ fileArrayEnumerator nextObject ] ) )
								{
									X2Signature *nextSignature = [ [ X2Signature alloc ] 
													  initWithPropertyListDict:nextSignatureDict ] ;
						
									[ fileSignatures addObject:nextSignature ] ;
									[ nextSignature release ] ;
								}
						}
				
					// Process all signatures
				
					X2Signature *nextSignature ;
					NSEnumerator *signatureEnumerator = [ fileSignatures objectEnumerator ] ;
				
					short nBinsUsed[101] ;
					histogram *fragHistos[101] ;
					short minusOne = -1 ;
					unsigned int intValue ;
					short shortValue ;
				
					while( ( nextSignature = [ signatureEnumerator nextObject ] ) )
						{
							// We assume that ID is embedded in name - lame, but I do not feel like figuring out 
							// anything smarter right now.
						
							NSString *IDString = [ nextSignature->sourceTree->treeName 
												  	stringByTrimmingCharactersInSet:[ [ NSCharacterSet decimalDigitCharacterSet ] invertedSet ] ] ;
						
							// May have leading zeroes to deal with 
						
							char *ssID = [ IDString cString ] ;
						
							while( *ssID == '0' && *ssID != '\0' )
								{
									++ssID ;
								}
						
							if( *ssID == '\0' )
								{
									// ID is all zeroes
									--ssID ;
								}
						
							unsigned int molID = (unsigned int) atoi( ssID ) ;
						
							unsigned int nFrags = (unsigned int) nextSignature->sourceTree->nFragments ;
						
							if( nFrags > 100 )
								{
									printf( "WARNING: Molecule %s has %d fragments - must skip it!\n",
										   [ nextSignature->sourceTree->treeName cString ], (int)nFrags ) ;
									continue ;
								}
						
							int nFragsUsed  ;
						
							int jFrag ;
						
							histogramBundle *nextBundle = [ nextSignature->histogramBundleForTag objectForKey:@"1DHISTO" ] ;
						
							if( *binWidth == 0. )
								{
									*binWidth = nextBundle->lengthDelta ;
								}
							else if( *binWidth != nextBundle->lengthDelta )
								{
									printf( "ERROR - BIN WIDTH MISMATCH ENCOUNTERED - Exit!\n" ) ;
									exit(1) ;
								}
						
							for( jFrag = 1 ; jFrag <= nFrags ; ++jFrag )
								{
									nBinsUsed[jFrag] = -1 ;
								
									int fragmentIndex = jFrag - 1 ;
								
									fragment *nextFragment = (fragment *)[ nextBundle->sourceTree->treeFragments objectAtIndex:fragmentIndex ] ;
								
									int fragCount = [ nextFragment->fragmentNodes count ] ;
							
									NSString *keyString = [ NSString stringWithFormat:@"%d_%d",jFrag,jFrag ] ;
								
									fragHistos[jFrag] = 
										(histogram *)[ nextBundle->sortedFragmentsToHistogram objectForKey:keyString ] ;
									
									if( fragHistos[jFrag] == nil || fragCount < smallFragmentSize ) 
										{
											continue ;
										}
								
									// How many bins to use?
								
									nBinsUsed[jFrag] = fragHistos[jFrag]->nBins ;
								
									int jBin = fragHistos[jFrag]->nBins - 1 ;
								
									while( fragHistos[jFrag]->binCounts[jBin] == 0 && jBin >= 0 )
										{
											--jBin ;
											--nBinsUsed[jFrag] ;
										}
								
									if( jBin < 0 )
										{
											nBinsUsed[jFrag] = -1 ; 
											continue ;
										}
								
									
									
								}
						
							nFragsUsed = nFrags ;
							int totalBins = 0 ;
						
							for( jFrag = 1 ; jFrag <= nFrags ; ++jFrag )
								{
									if( nBinsUsed[jFrag] < 0 ) 
										{
											--nFragsUsed ;
										}
									else
										{
											totalBins += nBinsUsed[jFrag] ;
										}
								}
						
							// Worst case
						
							int addSize = sizeof( unsigned int ) + sizeof( unsigned short ) + 
								nFragsUsed * sizeof( unsigned short ) + 
								( totalBins * ( sizeof(short) + sizeof( unsigned int ) ) ) ;
						
							if( ( smallSigUsed + addSize  ) > smallSigAlloc )
								{
									smallSigAlloc += 100000 ;
									inMem = (void *) realloc( inMem, smallSigAlloc ) ;
									inMemPtr = inMem + smallSigUsed ;
									binWidth = (double *)inMem ;
									numSignatures = (unsigned int *)( inMem + sizeof( double ) ) ;
								
									
								
									if( ! inMem )
										{
											printf( "ERROR - COULD NOT EXPAND \"SMALL SIG\" DATA STRUCTURE - Exit!\n" ) ;
											exit(1) ;
										}
								}
						
							memcpy( inMemPtr, &molID, sizeof( unsigned int ) ) ;
							inMemPtr += sizeof( unsigned int ) ;
							smallSigUsed += sizeof( unsigned int ) ;
						
							memcpy( inMemPtr, &nFragsUsed, sizeof( unsigned short ) ) ;
							inMemPtr += sizeof( unsigned short ) ;
							smallSigUsed += sizeof( unsigned short ) ;
						
							for( jFrag = 1 ; jFrag <= nFrags ; ++jFrag )
								{
									if( nBinsUsed[jFrag] < 0 ) continue ;
								
									memcpy( inMemPtr, &nBinsUsed[jFrag], sizeof( short ) ) ;
									inMemPtr += sizeof( short ) ;
									smallSigUsed += sizeof( short ) ;
								
									int jBin ;
								
									for( jBin = 0 ; jBin < nBinsUsed[jFrag] ; ++jBin )
										{
											if( fragHistos[jFrag]->binCounts[jBin] <= 32767 )
												{
													shortValue = (short )fragHistos[jFrag]->binCounts[jBin] ;
													memcpy( inMemPtr, & shortValue, sizeof( short ) ) ;
													inMemPtr += sizeof( short ) ;
													smallSigUsed += sizeof( short ) ;
												}
											else
												{
													memcpy( inMemPtr, &minusOne, sizeof( short ) ) ;
													inMemPtr += sizeof( short ) ;
													intValue = (unsigned int) fragHistos[jFrag]->binCounts[jBin] ;
													memcpy( inMemPtr, & intValue, sizeof( unsigned int ) ) ;
													inMemPtr += sizeof( unsigned int ) ;
													smallSigUsed += sizeof( short ) + sizeof( unsigned int ) ;
												}
											
										}
								}
						
							++(*numSignatures) ;
						}
				
					// File count 
					++count ;
				
					if( ((double)count/numFiles)*100. > percentComplete + 10. )
						{
							percentComplete += 10. ;
							printf( "%5.2f complete - Finished %s\n", percentComplete, [ nextPath cString ] ) ;
							[ localPool release ] ;
							localPool = [  [ NSAutoreleasePool alloc ] init ] ;
						}
					
				}
		
			
			// Now create shared memory resource and copy our data to it
		
			// First, save to file
		
			[ fileManager createFileAtPath:resourceFile contents:[ NSData dataWithBytes:(const void *)inMem length:smallSigUsed ] attributes:nil  ] ;
		
			rsrcKey = ftok( [ resourceFile cString ], 0 ) ;
		
			shmID = shmget( rsrcKey, smallSigUsed, 0644 | IPC_CREAT) ;
		
			if( shmID < 0 )
				{
					printf( "COULD NOT CREATE SHARED RESOURCE - Exit!\n" ) ;
					exit(1) ;
				}
		
			void *shared_memory = shmat(shmID, (void *)0, 0);
		
			if( shared_memory == (void *)-1)
				{
					printf( "COULD NOT MAP TO SHARED RESOURCE - Exit!\n" ) ;
					exit(1) ;
				}
		
			printf( "Finished creating data structure, copy to shared resource ...\n" ) ;
		
			memcpy( shared_memory, inMem, smallSigUsed ) ;
		
			printf( "Finished!!\n" ) ;
		
			
	
		}
	else
		{
			printf( "SORRY, only create and compare modes supported right now!\n" ) ;
		}

    [pool drain];
    return 0;
}

NSInteger fileNameCompare( id A, id B, void *ctxt )
	{
		NSString *fA = (NSString *) A ;
                NSString *fB = (NSString *) B ;

		NSString *aName = [ [ fA componentsSeparatedByString:@"." ] objectAtIndex:0 ] ;
		NSString *bName = [ [ fB componentsSeparatedByString:@"." ] objectAtIndex:0 ] ;

		return (NSInteger) [ aName compare:bName ] ;
	}


int quickHitCompare( void *quick1, void *quick2 )
	{
		if( ( ( quickHit *)quick1 )->score < ( ( quickHit *)quick2 )->score )
			{
				return -1 ;
			}
		else if( ( ( quickHit *)quick1 )->score > ( ( quickHit *)quick2 )->score )
			{
				return 1 ;
			}
		else
			{
				return 0 ;
			}
	}
