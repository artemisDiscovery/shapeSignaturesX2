#import <Cocoa/Cocoa.h>
#include <string.h>
#import "flatSurface.h"
#import "rayTrace.h"
#import "ctTree.h"
#import "shapeSignatureX2.h"
//#import "hitListItem.h"
#include <math.h> 

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    // This is an all-in-one tool for generating and comparing next-generation 
	// Shape Signatures ("version X") . 
	
	// Note that I will not try to bundle surface generation with this. 
	
	enum parseStates { GETTOKEN, GETFLAG }  ;
	
	int parseState, flagType ;
	
	// The enumerated list below is evolving - in particular there will need to be more scoring options
	
	enum flagTypes { CREATE, COMPARE, GRIDSPACING, NUMSEGMENTS, LENGTHDELTA, MEPDELTA, RANDOMIZATIONANGLE, 
							SEGMENTCULLING, RESTARTRATE, SEED, PRINTOPTION, ORIENTATION, 
							SKIPSELFINTERSECTION, SCALE, COMPARETAG, NUMBEROFHITS, MAXHITS, MAXSCORE, FRAGSCORE,
							SORTBYWEIGHTEDSCORE, MAXPERCENTQUERYUNMATCHED, MAXPERCENTTARGETUNMATCHED,
							CORRELATIONSCORING, PROBABILITYINCREMENT, KEYTYPE, NEIGHBORLOWERBOUNDTOEXCLUDE } ;
							
	
	enum { CREATEMODE, COMPAREMODE, INFOMODE, KEYSMODE, KMEANSMODE, CHECKMODE, UNDEFINED } mode ;
	
	mode = UNDEFINED ;
	
	int seed = 12345676 ;
	int restartRate = 100000 ;
	
	BOOL insideTrace = YES ;
	
	double lengthDelta = 0.5 ;
	double MEPDelta = 0.05 ;
	double randomA = 5.0 * acos(-1.0)/180. ;
	int numSegments = 100000 ;
	BOOL segmentCulling = NO ;
	BOOL skipSelfIntersection = NO ;
	double scaleFactor = 1.0 ;
	double gridSpacing = 0.5 ;
		
 	double maxScore = 2.0 ;
	int maxHits = 100 ;
	BOOL fragmentScoring = NO ;
	
	BOOL sortByFragmentWeightedScore = YES ;
	
	BOOL useCorrelationScoring = NO ;
	
	double maxPercentQueryUnmatched = 100. ;
	double maxPercentTargetUnmatched = 100. ;
	
	BOOL keysWithFragments = YES ;
	double probabilityIncrement = 0.05 ;
	BOOL doNeighbors = NO ;
	double neighborLowerBoundToExclude = 0.1 ;
	
	int numKMeansClusters = 0 ;
	
	NSString *compareTag = @"1DHISTO" ;
	
	NSString *printOption = @"NoPrint" ;
		
	NSString *mol2Directory = nil ;
	
	NSString *errorDirectory = nil ;
	
	NSString *XDBDirectory = nil ;
	
	NSString *queryDB = nil ;
	NSString *targetDB = nil ;
	NSString *hitsFile = nil ;
	
	NSString *createDB = nil ;
	
							
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
			printf( "USAGE: shapeSigX -compare [ flags ] <query DB> <target DB> <hits file> \n" ) ;
			printf( "USAGE: shapeSigX -info <query DB> \n" ) ;
			printf( "USAGE: shapeSigX -keys [ flags ] <input directory> \n" ) ;
			printf( "USAGE: shapeSigX -check [ flags ] <input directory> <output directory> \n" ) ;
			printf( "USAGE: shapeSigX -kmeans [ flags ] <input directory> <#clusters> \n" ) ;
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
			printf( "\t-printon <enable print option (raytrace|histogram)> \n" ) ;
			printf( "-compare flags:\n" ) ;
			printf( "\t-tag <histogram tag to use; default = 1DShape> \n" ) ;
			printf( "\t-fragscore <use fragment-based scoring (yes|no); default = NO>\n" ) ;
			printf( "\t-corrscore <use correlation scoring (yes|no); default = NO>\n" ) ;
			printf( "\t-maxhits <maximum number of hits to return; default = 100> \n" ) ;
			printf( "\t-maxscore <maximum shape signature score to return; default = 2.0> \n" ) ;
			printf( "\t-sortBy <how to sort signatures; (minFrag | weightedFrag); default = weightedFrag> \n" ) ;
			printf( "\t-maxQueryUnmatched <max. %% query unmatched ; default = 100. (no constraint)> \n" ) ;
			printf( "\t-maxTargetUnmatched <max. %% target unmatched ; default = 100. (no constraint)> \n" ) ;
			printf( "-keys flags:\n" ) ;
			printf( "\t-probIncrement <division for discretizing; default = 0.05> \n" ) ;
			printf( "\t-keyType <(g)lobal or (f)fragment histos; default = fragment> \n" ) ;
			printf( "\t-neighbors <probability lower bound to exclude> \n" ) ;
			printf( "-info :\n" ) ;
			printf( "\t<provide information on atom assignment to fragments, and print all histograms>\n" ) ;
			
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
							
							if( strcasestr( &argv[i][1], "create" ) )
								{
									mode = CREATEMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "comp" ) )
								{
									mode = COMPAREMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "info" ) )
								{
									mode = INFOMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "keys" ) )
								{
									mode = KEYSMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "kmeans" ) )
								{
									mode = KMEANSMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "check" ) )
								{
									mode = CHECKMODE ;
									parseState = GETTOKEN ;
								}
							else if( strcasestr( &argv[i][1], "grid" ) )
									{
										flagType = GRIDSPACING ;
									}
							else if( strcasestr( &argv[i][1], "num" ) )
									{
										flagType = NUMSEGMENTS ;
									}
							else if( strcasestr( &argv[i][1], "ldel" ) )
									{
										flagType = LENGTHDELTA ;
									}
							else if( strcasestr( &argv[i][1], "rand" ) )
									{
										flagType = RANDOMIZATIONANGLE ;
									}
							else if( strcasestr( &argv[i][1], "cul" ) )
									{
										flagType = SEGMENTCULLING ;
									}
							else if( strcasestr( &argv[i][1], "rest" ) )
									{
										flagType = RESTARTRATE ;
									}
							else if( strcasestr( &argv[i][1], "ori" ) )
									{
										flagType = ORIENTATION ;
									}
							else if( strcasestr( &argv[i][1], "see" ) )
									{
										flagType = SEED ;
									}
							else if( strcasestr( &argv[i][1], "skips" ) )
									{
										flagType = SKIPSELFINTERSECTION ;
									}
							else if( strcasestr( &argv[i][1], "scale" ) )
									{
										flagType = SCALE ;
									}
							else if( strcasestr( &argv[i][1], "pri" ) )
									{
										flagType = PRINTOPTION ;
									}
							else if( strcasestr( &argv[i][1], "tag" ) )
									{
										flagType = COMPARETAG ;
									}
							else if( strcasestr( &argv[i][1], "maxhit" ) )
									{
										flagType = MAXHITS ;
									}
							else if( strcasestr( &argv[i][1], "maxscore" ) )
									{
										flagType = MAXSCORE ;
									}
							else if( strcasestr( &argv[i][1], "fragscore" ) )
								{
									flagType = FRAGSCORE ;
								}
							else if( strcasestr( &argv[i][1], "sortbyweight" ) )
								{
									flagType = SORTBYWEIGHTEDSCORE ;
								}
							else if( strcasestr( &argv[i][1], "queryunma" ) )
								{
									flagType = MAXPERCENTQUERYUNMATCHED ;
								}
							else if( strcasestr( &argv[i][1], "targetunma" ) )
								{
									flagType = MAXPERCENTTARGETUNMATCHED ;
								}
							else if( strcasestr( &argv[i][1], "corr" ) )
								{
									flagType = CORRELATIONSCORING ;
								}
							else if( strcasestr( &argv[i][1], "probIncre" ) )
								{
									flagType = PROBABILITYINCREMENT ;
								}
							else if( strcasestr( &argv[i][1], "keyt" ) )
								{
									flagType = KEYTYPE ;
								}
							else if( strcasestr( &argv[i][1], "neigh" ) )
								{
									flagType = NEIGHBORLOWERBOUNDTOEXCLUDE ;
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
											
											// Make sure of trailing / for convenience ...
											
											if( [ mol2Directory characterAtIndex:([ mol2Directory length ] - 1) ] != '/' )
												{
													// Add the final slash
													
													mol2Directory = [ [ mol2Directory stringByAppendingString:@"/" ] retain ] ;
												}
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
									printf( "FLAG -create, -compare OR -info MUST APPEAR FIRST - Exit!\n" ) ;
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
								
							case MAXPERCENTQUERYUNMATCHED:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								maxPercentQueryUnmatched = atoi( argv[i] ) ;
								
								break ;
								
							case MAXPERCENTTARGETUNMATCHED:
								if( mode != COMPAREMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								maxPercentTargetUnmatched = atoi( argv[i] ) ;
								
								break ;

								
							case SCALE:
								if( mode != CREATEMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								scaleFactor = atof( argv[i] ) ;
								break ;
								
							case PROBABILITYINCREMENT:
								if( mode != KEYSMODE )
									{
										printf( "ILLEGAL OPTION FOR SELECTED MODE - Exit!\n" ) ;
										exit(1) ;
									}
								probabilityIncrement = atof( argv[i] ) ;
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
			
			NSArray *files = [ fileManager contentsOfDirectoryAtPath:mol2Directory error:&fileError ] ;
			
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
			
			NSArray *mol2Files =  [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF endswith '.mol2'" ] ] ;
			NSArray *flatsFiles = [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.flats'" ] ] ;
			NSArray *siteFiles =  [ files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.site'" ] ] ;
			
			[ mol2Files retain ] ;
			[ flatsFiles retain ] ;
			[ siteFiles retain ] ;
			
			// We can assume that mol2 files and their associated flats, sites files occur in the same 
			// order - I will not allow possibility of gaps
			
			int mol2Count = [ mol2Files count ] ;
			
			NSMutableArray *theSignatures = [ [ NSMutableArray alloc ] initWithCapacity:mol2Count ] ;
			
			printf( "\nCreate new database - Process %d mol2 files in directory %s ... \n",
				mol2Count, [ mol2Directory cString ] ) ;
				
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
					NSString *nextMol2Name = [ mol2Files objectAtIndex:mol2Index ] ;
					NSString *nextMol2File = [ mol2Directory stringByAppendingString:nextMol2Name ] ;
					
					NSString *mol2Root = [ [ nextMol2Name componentsSeparatedByString:@"." ] objectAtIndex:0 ] ;
					
					ctTree *nextTree = [ [ ctTree alloc ] initTreeFromMOL2File:[ nextMol2File cString ] ] ;
					
					if( ! nextTree )
						{
							printf( "ERROR IMPORTING MOLECULE %s - Exit!\n", [ nextMol2File cString ] ) ;
							exit(1) ;
						}
						
					// Assign atoms to fragments
					
					[ nextTree assignNodesToFragments ] ;
						
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
					
					
					// Assume file name of form <name>.mol2 (obviously)
					
					nextSurfaceFile = [ mol2Directory stringByAppendingString:[ flatsFiles objectAtIndex:mol2Index ] ] ;
						
					flatSurface *nextSurface = [ [ flatSurface alloc ] initWithFlatFile:nextSurfaceFile andTree:nextTree
													andSiteFile:nextSiteFile andGridSpacing:gridSpacing ] ;
					
					if( ! nextSurface )
						{
							printf( "ERROR IMPORTING SURFACE %s - Exit!\n", [ nextSurfaceFile cString ] ) ;
							exit(1) ;
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
					
					
					// Next signature - for testing we just use 1DHisto
					
					//XSignature *nextSignature = [ [ XSignature alloc ] initUsingTree:nextTree 
					//		forTagRoot:@"1DHISTO" andRayTrace:nextRayTrace 
					//		withStyle:style  ] ;
				
					X2Signature *nextSignature = [ [ X2Signature alloc ] initForAllTagsUsingTree:nextTree 
																andRayTrace:nextRayTrace withStyle:style ] ;
														
					[ theSignatures addObject:nextSignature ] ;
					
					
					// Every 100 molecules, clear autorelease pool
					
					if( mol2Index % 100 == 0 )
						{
							[ pool drain ] ;
							pool = [[NSAutoreleasePool alloc] init] ;
						}
						
					// Always trash surface object and rayTrace object
					
					[ nextRayTrace release ] ;
					[ nextSurface release ] ;
				}
				
			// Archive to output file 
			
			if( [ NSArchiver archiveRootObject:theSignatures toFile:createDB ] == NO )
				{
					printf( "CREATION OF X2SIGNATURE ARCHIVE FAILED! \n" ) ;
					exit(1) ;
				}
			
		}
	else if( mode == COMPAREMODE )
		{
			// Compare two databases of X2 signatures
			
			
		
		}

    [pool drain];
    return 0;
}
