//
//  histogram.m
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "histogram.h"
#import "rayTrace.h"
#import "histogramBundle.h"

static NSArray *recognizedTags ;
static NSArray *classByRecognizedTag ;
static NSArray *tagDescriptions ;

@implementation histogram

+ (void) initialize
	{
		recognizedTags = [ [ NSArray alloc ] 
			initWithObjects:@"1DHISTO",@"2DMEPHISTO",@"2DMEPREDUCEDHISTO",
				@"2DMEPREDUCEDINVERTEDHISTO", nil ] ;
				
		tagDescriptions = [ [ NSArray alloc ] 
			initWithObjects:@"Shape-only comparison",
							@"Shape + detailed electrostatic comparison",
							@"Shape + simple electrostatic comparison, molecule",
							@"Shape + simple electrostatic receptor-based comparison", nil ] ;
							
							
							
							
		classByRecognizedTag = [ [ NSArray alloc ] 
			initWithObjects:[ NSNumber numberWithInt:(int)ONE_DIMENSIONAL ],
							[ NSNumber numberWithInt:(int)TWO_DIMENSIONAL ],
							[ NSNumber numberWithInt:(int)TWO_DIMENSIONAL ],
							[ NSNumber numberWithInt:(int)TWO_DIMENSIONAL ], nil ] ;
		
		return ;
	}
/*	
- (id) initWithRayTrace:(rayTrace *)rt tag:(NSString *)tg style:(histogramStyle)st fragment:(int)frag
	{
		self = [ super init ] ;
		
		connectToHistos = [ [ NSMutableSet alloc ] initWithCapacity:5 ] ;
		
		lengthDelta = st.lengthDelta ;
		MEPDelta = st.MEPDelta ;
		 
		// We will use the tag to adjust the class
		
		if( [ recognizedTags containsObject:tg ] == NO )
			{
				printf( "ERROR - UNRECOGNIZED HISTOGRAM TAG\n" ) ;
				return nil ;
			}
			
		tag = [ [ NSString alloc ] initWithString:tg ] ;
			
		int histoTagIndex = [ recognizedTags indexOfObject:tg ] ;
		
		type = (histogramClass) [ [ classByRecognizedTag objectAtIndex:histoTagIndex ] intValue ] ;
		
		// Length bins - 
		
		if( type == TWO_DIMENSIONAL_PARTITION || type == TWO_DIMENSIONAL_GLOBAL )
			{
				nLengthBins = ( (int) floor( rt->maxTwoSegmentLength / lengthDelta ) ) + 1 ;
			}
		else
			{
				nLengthBins = ( (int) floor( rt->maxSegmentLength / lengthDelta ) ) + 1 ;
			}
		
		if( type == TWO_DIMENSIONAL_PARTITION || type == TWO_DIMENSIONAL_GLOBAL )
			{
				if( ([tg rangeOfString:@"REDUCED"]).location == NSNotFound )
					{
						// Make minMEP a multiple of MEPDelta
						
						if( rt->minMEP < 0. )
							{
								minMEP = (((int) floor( rt->minMEP / MEPDelta )))*MEPDelta ;
							}
						else
							{
								minMEP = (((int) floor( rt->minMEP / MEPDelta )) - 1)*MEPDelta ; 
							}
							
						nMEPBins = ( (int) floor( ( rt->maxMEP - minMEP ) / MEPDelta ) ) + 1  ;
					}
				else
					{
						// minMEP doesn't matter
						
						nMEPBins = 2 ;
					}
				
			}
		else
			{
				// All length bins belong to the same MEP bin
				
				nMEPBins = 1 ;
			}
			
		// Size the count structures
		
		nBins = nLengthBins * nMEPBins ;
		
		binCounts = (int *) malloc( nBins * sizeof( int ) ) ;
		binProbs = (double *) malloc( nBins * sizeof( double ) ) ;
		
		int iBin ;
		
		for( iBin = 0 ; iBin < nBins ; ++iBin )
			{
				binCounts[iBin] = 0 ;
				binProbs[iBin] = 0. ;
			}
			
		segmentCount = 0 ;
		
		partition = -1 ;
		
		// Do we use fragment information?
		
		if( type == ONE_DIMENSIONAL_PARTITION || type == TWO_DIMENSIONAL_PARTITION )
			{
				if( frag < 0 || frag > rt->theSurface->theTree->nFragments )
					{
						printf("ILLEGAL FRAGMENT IN HISTOGRAM CREATION!\n" ) ;
						return nil ;
					}
					
				partition = frag ;
			}
				
		int iReflect ;
		
		double *xCoord = rt->reflectX ;
		double *yCoord = rt->reflectY ;
		double *zCoord = rt->reflectZ ;
		
		double *mep = rt->reflectMEP ;
		
		BOOL *start = rt->reflectAtStart ;
		
		int *part = rt->reflectPartition ;
		
		// Separate handling for each tag type
		
		
		if( ([ tg rangeOfString:@"1DHISTO" ]).location == 0 )
			{
				// Simple shape-only histogram
				
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 1 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						
						if( partition >= 0 )
							{
								if( part[iReflect] != partition || part[iReflect + 1] != partition )
									{
										continue ;
									}
							}
									
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						
						iBin = (int) floor( d / lengthDelta ) ;
					
						if( iBin < 0 || iBin >= nBins )
							{
							
								printf("ERROR - ILLEGAL BIN IN 1D\n");
							}
					
						++binCounts[iBin] ;
						
						++segmentCount ;
								
					}
					
				// Get normalized probs
				
				for( iBin = 0 ; iBin < nBins ; ++iBin )
					{
						binProbs[iBin] = ((double) binCounts[iBin]) / segmentCount ;
					}
					
				return self ;
			}
		else if( ([ tg rangeOfString:@"2DMEPHISTO" ]).location == 0 )
			{
				// Have a basic 2D MEP-based histogram
				
				// To have a contribution to a global histogram, must have a chain of two segments that includes
				// no internal starts
				
				// To have a contribution to a fragment, must satisfy "no start" condition, AND all reflections 
				// must belong to the same fragment
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 2 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						if( start[iReflect + 2] == YES ) continue ;
						
						if( partition >= 0 )
							{
								if( part[iReflect] != partition || part[iReflect + 1] != partition
										|| part[iReflect + 2] != partition )
									{
										continue ;
									}
							}
									
						// Do this the inefficient but simple and safe way
						
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d1 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						dx = xCoord[iReflect + 2] - xCoord[iReflect + 1] ;
						dy = yCoord[iReflect + 2] - yCoord[iReflect + 1] ;
						dz = zCoord[iReflect + 2] - zCoord[iReflect + 1] ;
						
						double d2 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						int lenBin = (int) floor( ( d1 + d2 ) / lengthDelta ) ;
						int MEPBin = (int) floor( ( mep[iReflect + 1] - minMEP ) / MEPDelta ) ;
						
						iBin = ( MEPBin * nLengthBins ) + lenBin ;
					
						if( iBin < 0 || iBin >= nBins )
							{
							
								printf("ERROR - ILLEGAL BIN IN 2DMEP\n");
							}
						
						++binCounts[iBin] ;
						
						++segmentCount ;
								
					}
		
				
				// Get normalized probs
				
				for( iBin = 0 ; iBin < nBins ; ++iBin )
					{
						binProbs[iBin] = ((double) binCounts[iBin]) / segmentCount ;
					}
					
				return self ;
			}
		else if( ([ tg rangeOfString:@"2DMEPREDUCEDHISTO" ]).location == 0 )
			{
				// Have a reduced 2D MEP-based histogram (only two classes of
				// potential, negative (0) and positive (1)
				
				// To have a contribution to a global histogram, must have a chain of two segments that includes
				// no internal starts
				
				// To have a contribution to a fragment, must satisfy "no start" condition, AND all reflections 
				// must belong to the same fragment
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 2 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						if( start[iReflect + 2] == YES ) continue ;
						
						if( partition >= 0 )
							{
								if( part[iReflect] != partition || part[iReflect + 1] != partition
								   || part[iReflect + 2] != partition )
									{
										continue ;
									}
							}
						
						// Do this the inefficient but simple and safe way
						
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d1 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						dx = xCoord[iReflect + 2] - xCoord[iReflect + 1] ;
						dy = yCoord[iReflect + 2] - yCoord[iReflect + 1] ;
						dz = zCoord[iReflect + 2] - zCoord[iReflect + 1] ;
						
						double d2 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						int lenBin = (int) floor( ( d1 + d2 ) / lengthDelta ) ;
						
						int MEPBin ;
						
						if( mep[iReflect + 1] < 0 )
							{
								MEPBin = 0 ;
							}
						else 
							{
								MEPBin = 1 ;
							}
						
						iBin = ( MEPBin * nLengthBins ) + lenBin ;
					
						if( iBin < 0 || iBin >= nBins )
							{
							
								printf("ERROR - ILLEGAL BIN IN 2DMEPREDUCED\n");
							}
						
						++binCounts[iBin] ;
						
						++segmentCount ;
						
					}
			
			
			// Get normalized probs
			
			for( iBin = 0 ; iBin < nBins ; ++iBin )
				{
					binProbs[iBin] = ((double) binCounts[iBin]) / segmentCount ;
				}
			
				return self ;
			}
		else if( ([ tg rangeOfString:@"2DMEPREDUCEDINVERTEDHISTO" ]).location == 0 )
			{
				// Have an inverted reduced 2D MEP-based histogram
				
				// Negative potential contributions go in bin 1, positive
				// in 0 ; this is the inverse of the regular reduced case,
				// and is intended for receptor-based queries. 
				
				// To have a contribution to a global histogram, must have a chain of two segments that includes
				// no internal starts
				
				// To have a contribution to a fragment, must satisfy "no start" condition, AND all reflections 
				// must belong to the same fragment
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 2 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						if( start[iReflect + 2] == YES ) continue ;
						
						if( partition >= 0 )
							{
								if( part[iReflect] != partition || part[iReflect + 1] != partition
								   || part[iReflect + 2] != partition )
									{
										continue ;
									}
							}
						
						// Do this the inefficient but simple and safe way
						
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d1 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						dx = xCoord[iReflect + 2] - xCoord[iReflect + 1] ;
						dy = yCoord[iReflect + 2] - yCoord[iReflect + 1] ;
						dz = zCoord[iReflect + 2] - zCoord[iReflect + 1] ;
						
						double d2 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						int lenBin = (int) floor( ( d1 + d2 ) / lengthDelta ) ;
						
						int MEPBin ;
						
						if( mep[iReflect + 1] < 0 )
							{
								MEPBin = 1 ;
							}
						else 
							{
								MEPBin = 0 ;
							}
						
						iBin = ( MEPBin * nLengthBins ) + lenBin ;
					
						if( iBin < 0 || iBin >= nBins )
							{
							
								printf("ERROR - ILLEGAL BIN IN 2DMEPREDUCEDINVERTED\n");
							}
						
						++binCounts[iBin] ;
						
						++segmentCount ;
					
					}
				
				
				// Get normalized probs
				
				for( iBin = 0 ; iBin < nBins ; ++iBin )
					{
					binProbs[iBin] = ((double) binCounts[iBin]) / segmentCount ;
					}
				
				return self ;
			}
	
				
							
		// I don't know how to make anything else!
		
		printf( "HEY I CAN'T MAKE THAT YET!\n" ) ;
		
		return nil ;
	}
*/

		
- (id) initWithBundle:(histogramBundle *)bndl fragmentIndices:(int []) indices 
	{
		self = [ super init ] ;
		
		hostBundle = bndl ;
		
		//connections = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		
		nBins = hostBundle->nBins ;		// Need to local copy of this for coding, decoding
		
		binCounts = (int *) malloc( nBins * sizeof( int ) ) ;
		binProbs = (double *) malloc( nBins * sizeof( double ) ) ;
		
		int iBin ;
		
		for( iBin = 0 ; iBin < nBins ; ++iBin )
			{
				binCounts[iBin] = 0 ;
				binProbs[iBin] = 0. ;
			}
			
		segmentCount = 0 ;
		segmentPairCount = 0 ;
		
		sortedFragmentKey = nil ;
		
		if( indices )
			{
				if( hostBundle->type == ONE_DIMENSIONAL )
					{
						fragments[0] = indices[0] ;
						fragments[1] = indices[1] ;
						fragments[2] = 0 ;
					}
				else
					{
						fragments[0] = indices[0] ;
						fragments[1] = indices[1] ;
						fragments[2] = indices[2] ;
					}
					
				nFragments = hostBundle->sourceTree->nFragments ;
			}
		else
			{
				fragments[0] = 0 ;
				fragments[1] = 0 ;
				fragments[2] = 0 ;
				
				nFragments = 0 ;
			}
			
		int nFrags = hostBundle->sourceTree->nFragments ;
		
		return self ;
	}
		
- (void) dealloc
	{
		free( binCounts ) ;
		free( binProbs ) ;
		
		if( sortedFragmentKey ) [ sortedFragmentKey release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}
	
- (void) add2DSegmentPairAtLengthBin:(int)lenBin MEPBin:(int)MEPBin
	{
		int iBin = ( MEPBin * hostBundle->nLengthBins ) + lenBin ;
		
		++binCounts[iBin] ;
		
		++segmentPairCount ;
		
		return ;
	}
		
		
- (void) add1DSegmentAtLengthBin:(int)iBin 
	{
		++binCounts[iBin] ;
		
		++segmentCount ;
		
		return ;
	}
	
- (void) normalize
	{
		int iBin ;
		
		int denom ;
		
		if( hostBundle->type == ONE_DIMENSIONAL )
			{
				denom = segmentCount ;
			}
		else
			{
				denom = segmentPairCount ;
			}
		
		for( iBin = 0 ; iBin < nBins ; ++iBin )
			{
				binProbs[iBin] = (double)binCounts[iBin] / denom ;
			}
			
		return ;
	}
	
- (void) setSortedFragmentKey:(NSString *)key
	{
		if( sortedFragmentKey ) [ sortedFragmentKey release ] ;
		
		sortedFragmentKey = [ [ NSString alloc ] initWithString:key ] ;
		
		return ;
	}

- (double) scoreWithHistogram:(histogram *)target useCorrelation:(BOOL)useCorr
	{
		// Always tricky to do this, especially if we admit different "minMep" value for the second dimension.
		
		// For a 1D histo, with Q[i], T[j], Max i = I, Max j = J 
		//
		// Score = 0. ;
		// 
		//	for( k = 0 ; k <= MAX( I, J ) )
		//		{
		//			if( k <= I && k <= J )
		//				{
		//					Score += abs( Q[k] - T[k] ) ;
		//				}
		//			else if( k <= I )
		//				{
		//					Score += abs( Q[k] )
		//				}
		//			else
		//				{
		//					Score += abs( T[k] )
		//				}
		// 
		//
		// For a 2D Histo, with Q, T, Max Q = BQ, Max T = BT
		// nLengthBins : LQ, LT
		// nMEPBins: MQ, MT
		//
		// We will use "signed" implicit bins for the MEP for making comparisons, so we can have
		// a unified bin scheme for the overlapping histos
		//
		// Define	minMEPBinQ = round( minMEPQ / deltaMEP ) (typically these are < 0 )
		//			minMEPBinT = round( minMEPT / deltaMEP )
		//			maxMEPBinQ = minMEPBinQ + nMEPBinsQ
		//			maxMEPBinT = minMEPBinT + nMEPBinsT
		//
		// for( m = MIN(minMEPBinQ,minMEPBinT) ; m <= MAX( maxMEPBinQ, maxMEPBinT ) )
		//	{
		//		Entry points for Q and T:
		//		eQ = (m - minMEPBinQ)*LQ
		//		eT = (m - minMEPBinT)*LT
		//
		//		if( m >= minMEPBinQ && m <= maxMEPBinQ )
		//			MEPINQ = TRUE
		//		else
		//			MEPINQ = FALSE 
		//
		//		if( m >= minMEPBinT && m <= maxMEPBinT )
		//			MEPINT = TRUE
		//		else
		//			MEPINT = FALSE 
		
		//
		//
		//		if( MEPINQ && MEPINT  )
		//			{
		//				in mep range of Q AND T
		//
		//						for( l = 0 ; l <= MAX(LQ,LT) )
		//							{
		//								if( l <= LQ && l <= LT )
		//									{
		//										bQ = eQ + l ;
		//										bT = eT + l ;
		//										Score += abs( Q[bQ] - T[bT] ) 
		//									}
		//								else if( l <= LQ )
		//									{
		//										Score += Q[bQ] 
		//									}
		//								else
		//									{
		//										Score += T[bT]
		//									}
		//							}
		//		else if( MEPINQ && !MEPINT )
		//			{
		//						for( l = 0 ; l <= LQ )
		//							{
		//								bQ = eQ + l
		//								Score += Q[bQ] 
		//							}
		//			}
		//		else if( !MEPINQ && MEPINT )
		//			{
		//						for( l = 0 ; l <= LT )
		//							{
		//								bT = eT + l
		//								Score +=  T[bQ] 
		//							}
		//			}
		//		else (both out of MEP range)
		//			{
		//			} (NO SCORE CONTRIBUTION)
		//					
		//	
		
		double Score = 0. ;
		
		double *TProb = target->binProbs ;
		double *QProb = binProbs ;
		
		// To match my spiel above:
		
		int LQ = hostBundle->nLengthBins - 1 ;
		int BQ = nBins - 1 ;
		
		int LT = target->hostBundle->nLengthBins - 1 ;
		int BT = target->nBins - 1 ;
		
		int L = LQ > LT ? LQ : LT ;
		
		int l ;
		
		// Note that this object is defined as the "query"
		
		histogramClass type = hostBundle->type ;
		
		if( type == TWO_DIMENSIONAL )
			{
				// Do the hard one first
				
				int minMEPBinQ = (int) round( hostBundle->minMEP / hostBundle->MEPDelta ) ;
				int minMEPBinT = (int) round( target->hostBundle->minMEP / target->hostBundle->MEPDelta ) ;
				
				int MQ = hostBundle->nMEPBins  ;
				int MT = target->hostBundle->nMEPBins  ;
				
				int maxMEPBinQ = minMEPBinQ + MQ - 1 ;
				int maxMEPBinT = minMEPBinT + MT - 1 ;
				
				int maxMEPBin = maxMEPBinQ > maxMEPBinT ? maxMEPBinQ : maxMEPBinT ;
				int minMEPBin = minMEPBinQ < minMEPBinT ? minMEPBinQ : minMEPBinT ;
				
				int m ;
				
				for( m = minMEPBin ; m <= maxMEPBin ; ++m )
					{
						int eQ = (m - minMEPBinQ)*LQ ;
						int eT = (m - minMEPBinT)*LT ;
						
						int bQ, bT ;
						
						BOOL MEPINQ, MEPINT ;
						
						if( m >= minMEPBinQ && m <= maxMEPBinQ )
							MEPINQ = YES ;
						else
							MEPINQ = NO ; 
							
						if( m >= minMEPBinT && m <= maxMEPBinT )
							MEPINT = YES ;
						else
							MEPINT = NO ;
							
						if( MEPINQ && MEPINT )
							{
								for( l = 0 ; l <= L ; ++l )
									{
										bQ = eQ + l ;
										bT = eT + l ;
										
										if( l <= LQ && l <= LT )
											{
												Score += fabs( QProb[bQ] - TProb[bT] ) ;
											}
										else if( l <= LQ )
											{
												Score += QProb[bQ] ;
											}
										else
											{
												Score += TProb[bT] ;
											}
									}
							}
						else if( MEPINQ && !MEPINT )
							{
								for( l = 0 ; l <= LQ ; ++l )
									{
										bQ = eQ + l ;
										Score += QProb[bQ] ;
									}
							}
						else if( !MEPINQ && MEPINT )
							{
								for( l = 0 ; l <= LT ; ++l )
									{
										bT = eT + l ;
										Score += TProb[bT] ;
									}
							}
						else
							{
								// This is possible if rare - do nothing (no score contribution)
								// No overlap between histograms
							}
					}
			}
		else
			{
				// Easy 1D case!
				
				if( useCorr == NO )
					{
						for( l = 0 ; l <= L ; ++l )
							{
								if( l <= LQ && l <= LT )
									{
										Score += fabs( QProb[l] - TProb[l] ) ;
									}
								else if( l <= LQ )
									{
										Score += QProb[l] ;
									}
								else
									{
										Score += TProb[l] ;
									}
							}
					}
				else
					{
						// Do correlation scoring
						
						// Adjust LQ and LT to be highest non-zero bin, L to be 
						// max of those
						
						while( QProb[LQ] == 0. )
							{
								--LQ ;
							}
							
						while( TProb[LT] == 0. )
							{
								--LT ;
							}
							
						L = LQ > LT ? LQ : LT ;
						
						double aveQProb = 0. ;
						double aveTProb = 0. ;
						double SDQ = 0. ;
						double SDT = 0. ; ;
						double corrSum = 0. ;
						
						for( l = 0 ; l <= L ; ++l )
							{
								if( l <= LQ ) aveQProb += QProb[l] ;
								if( l <= LT ) aveTProb += TProb[l] ;
							}
							
						aveQProb /= (L + 1) ;
						aveTProb /= (L + 1) ;
						
						for( l = 0 ; l <= L ; ++l )
							{
								double delQ, delT ;
								
								if( l <= LQ )
									{
										delQ = QProb[l] - aveQProb ;
									}
								else
									{
										delQ = -aveQProb ;
									}
									
								if( l <= LT )
									{
										delT = TProb[l] - aveTProb ;
									}
								else
									{
										delT = -aveTProb ;
									}
									
								corrSum += delQ * delT ;
								
								SDQ += delQ*delQ ;
								SDT += delT*delT ;
							}
							
						SDQ = sqrt( SDQ / L ) ;
						SDT = sqrt( SDT / L ) ;
						
						Score = 1. - ( corrSum / ( SDQ * SDT * L ) ) ;
					}
												
											
								
			}
			
		return Score ;
	}
			
/*
- (void) addConnectionToHistogram:(histogram *)h 
	{
		if( h == self ) return ;
		
		if( [ connectToHistos member:h ] ) return ;
		
		[ connectToHistos addObject:h ] ;
		
		return ;
	}
	
*/
/*
- (NSString *) keyStringWithIncrement:(double)probInc
	{
		if( [ histogram isTag2D:tag ] == YES ) return nil ;
		
		char *outString = (char *) malloc( (nLengthBins + 1) * sizeof( char ) ) ;
		outString[nLengthBins] = '\0' ;
		
		int k ;
		unsigned char c ;
		
		if( nLengthBins < 2 || nLengthBins > 100 ) return nil ;
		
		// Readjust length in case of trailing zeroes
		
		k = nLengthBins - 1 ;
		
		while( binProbs[k] == 0. && k > 0 )
			{
				--k ;
			}
			
		int nLengthToUse = k + 1 ;
		
		for( k = 0 ; k < nLengthToUse ; ++k )
			{
				c = (unsigned char) floor( binProbs[k]/probInc ) ;
				outString[k] = (char)c ;
			}
			
		for( k = 0 ; k < nLengthToUse ; ++k )
			{
				outString[k] += 33 ;
				if( outString[k] > 126 )
					{
						printf( "ILLEGAL KEY GENERATED !\n" ) ;
						return nil ;
					}
			}
		
			
		outString[nLengthToUse] = '\0' ;
		
		// Find first zero, terminate string
		// NO - zeroes are legitimate data!
		
		NSString *returnString = [ NSString stringWithCString:outString ] ;
		
		free( outString ) ;
			
		return returnString ;
	}
*/
- (NSString *) keyStringWithIncrement:(double)probInc
	{
		// First convert to array of height values
		
		NSArray *heights = [ self discretizeWithIncrement:probInc ] ;
		
		NSMutableString *returnString = [ NSMutableString stringWithCapacity:100 ] ;
		
		NSEnumerator *heightEnumerator = [ heights objectEnumerator ] ;
		
		NSNumber *nextHeight ;
		
		while( ( nextHeight = [ heightEnumerator nextObject ] ) )
			{
				[ returnString appendString:[ nextHeight stringValue ] ] ;
				[ returnString appendString:@":" ] ;
			}
			
		return returnString ;
	}

- (NSString *) cumulativeKeyStringWithIncrement:(double)probInc
	{
		// First convert to array of height values
		
		NSArray *heights = [ self discretizeCumulativeWithIncrement:probInc ] ;
		
		NSMutableString *returnString = [ NSMutableString stringWithCapacity:100 ] ;
		
		NSEnumerator *heightEnumerator = [ heights objectEnumerator ] ;
		
		NSNumber *nextHeight ;
		
		while( ( nextHeight = [ heightEnumerator nextObject ] ) )
			{
				[ returnString appendString:[ nextHeight stringValue ] ] ;
				[ returnString appendString:@":" ] ;
			}
		
		return returnString ;
	}
	
- (NSArray *) discretizeWithIncrement:(double)probInc
	{
		if( [ histogram isTag2D:hostBundle->tag ] == YES ) return nil ;
		
		NSMutableArray *returnArray = [ NSMutableArray arrayWithCapacity:hostBundle->nLengthBins ] ;
		
		
		int k ;
		
		if( hostBundle->nLengthBins < 2 || hostBundle->nLengthBins > 100 ) return nil ;
		
		// Readjust length in case of trailing zeroes
		
		k = hostBundle->nLengthBins - 1 ;
		
		while( binProbs[k] == 0. && k > 0 )
			{
				--k ;
			}
			
		int nLengthToUse = k + 1 ;
		
		for( k = 0 ; k < nLengthToUse ; ++k )
			{
				NSNumber *nextBinHeight = [ NSNumber numberWithInt:floor( binProbs[k]/probInc ) ] ;
				[ returnArray addObject:nextBinHeight ] ;
			}
			
			
		return returnArray ;
	}

- (NSArray *) discretizeCumulativeWithIncrement:(double)probInc
	{
		// Report discretized probability for bins greater than currnt
	
		if( [ histogram isTag2D:hostBundle->tag ] == YES ) return nil ;
		
		NSMutableArray *returnArray = [ NSMutableArray arrayWithCapacity:hostBundle->nLengthBins ] ;
		
		
		int k ;
		
		if( hostBundle->nLengthBins < 2 || hostBundle->nLengthBins > 100 ) return nil ;
		
		// Readjust length in case of trailing zeroes
		
		k = hostBundle->nLengthBins - 1 ;
		
		while( binProbs[k] == 0. && k > 0 )
			{
			--k ;
			}
		
		// Make one less than full length, else we always have a trailing zero
	
		int nLengthToUse = k ;
	
		double cumProb = 1. ;
		
		for( k = 0 ; k < nLengthToUse ; ++k )
			{
				cumProb -= binProbs[k] ;
				NSNumber *nextBinHeight = [ NSNumber numberWithInt:floor( cumProb/probInc ) ] ;
				[ returnArray addObject:nextBinHeight ] ;
			}
		
		
		return returnArray ;
	}


- (NSString *) keyGroupStringWithIncrement:(double)probInc lowBin:(int)lo hiBin:(int)hi 
	{
		// First convert to array of height values
		
		NSArray *heights = [ self discretizeWithIncrement:probInc ] ;
		
		NSMutableString *returnString = [ NSMutableString stringWithCapacity:100 ] ;
		
		NSEnumerator *heightEnumerator = [ heights objectEnumerator ] ;
		
		NSNumber *nextHeight ;
		
		int binCount = 0 ;
		
		while( ( nextHeight = [ heightEnumerator nextObject ] ) )
			{
				if( binCount < lo || binCount > hi ) 
					{
						++binCount ;
						continue ;
					}
				
				[ returnString appendString:[ nextHeight stringValue ] ] ;
				[ returnString appendString:@":" ] ;
				
				++binCount ;
			}
			
		// Check for missing on high side (I assume low side is covered)
		// WAIT - why do I want to pad with zeros - not needed!
		
		/*
		while( binCount <= hi )
			{
				[ returnString appendString:@"0:" ] ;
				++binCount ;
			}
		*/
			
		return returnString ;
	}	
/*
+ (double) lowerBoundOnDistanceBetweenKey:(NSString *)key1 andKey:(NSString *)key2 usingProbabilityIncrement:(double)pInc 
	{
		char *c1 = [ key1 cString ] ;
		char *c2 = [ key2 cString ] ;
		
		int k ;
		
		int L1 = strlen(c1) ; 
		int L2 = strlen(c2) ;
		
		int L = L1 > L2 ? L1 : L2 ;
		
		double bound = 0. ;
		
		for( k = 0 ; k < L ; ++k )
			{
				int h1, h2 ;
				
				if( k >= L1 )
					{
						h1 = 0 ;
					}
				else
					{
						h1 = (int)c1[k] - 33 ;
					}
					
				if( k >= L2 )
					{
						h2 = 0 ;
					}
				else
					{
						h2 = (int)c2[k] - 33 ;
					}
				
				double x = ( abs( h1 - h2 ) - 1 ) * pInc ;
				
				if( x < 0. ) x = 0. ;
				
				bound += x ;
			}
			
		return bound ;
	}
*/

+ (NSArray *) heightArrayForKey:(NSString *) key
	{
		NSArray *strArray = [ key componentsSeparatedByString:@":" ] ;
		
		NSMutableArray *returnArray = [ NSMutableArray arrayWithCapacity:100 ] ;
		
		NSEnumerator *strEnumerator = [ strArray objectEnumerator ] ;
		
		NSString *nextString ;
		
		while( ( nextString = [ strEnumerator nextObject ] ) )
			{
				if( [ nextString length ] == 0 ) continue ;
				
				[ returnArray addObject:[ NSNumber numberWithInt:[ nextString intValue ] ] ] ;
			}
			
		return returnArray ;
	}

+ (double) lowerBoundOnDistanceBetweenKey:(NSString *)key1 andKey:(NSString *)key2 usingProbabilityIncrement:(double)pInc 
	{
		// Make keys back into height arrays
		
		NSArray *heights1 = [ histogram heightArrayForKey:key1 ] ;
		NSArray *heights2 = [ histogram heightArrayForKey:key2 ] ;
		
		int k ;
		
		int L1 = [ heights1 count ]  ; 
		int L2 = [ heights2 count ]  ;
		
		int L = L1 > L2 ? L1 : L2 ;
		
		double bound = 0. ;
		
		for( k = 0 ; k < L ; ++k )
			{
				int h1, h2 ;
				
				if( k >= L1 )
					{
						h1 = 0 ;
					}
				else
					{
						h1 = [ [ heights1 objectAtIndex:k ] intValue ] ;
					}
					
				if( k >= L2 )
					{
						h2 = 0 ;
					}
				else
					{
						h2 = [ [ heights2 objectAtIndex:k ] intValue ] ;
					}
				
				double x = ( abs( h1 - h2 ) - 1 ) * pInc ;
				
				if( x < 0. ) x = 0. ;
				
				bound += x ;
			}
			
		return bound ;
	}
		
		
+ (NSArray *) recognizedTags
	{
		return recognizedTags ;
	}
	
+ (NSArray *) classByRecognizedTag
	{
		return classByRecognizedTag ;
	}
	
+ (NSArray *) tagDescriptions
	{
		return tagDescriptions ;
	}
	
+ (NSString *) descriptionForTag:(NSString *)t 
	{
		int idx = [ recognizedTags indexOfObject:t ] ;
		
		if( idx == NSNotFound ) return nil ;
		
		return [ tagDescriptions objectAtIndex:idx ] ;
	}
	
+ (BOOL) isTag2D:(NSString *)t
	{
		int idx = [ recognizedTags indexOfObject:t ] ;
		
		if( idx == NSNotFound ) return NO ;
		
		if( [ classByRecognizedTag objectAtIndex:idx ] == TWO_DIMENSIONAL )
			{
				return YES ;
			}
		else
			{
				return NO ;
			}
		
	}
			
+ (BOOL) tagAvailable:(NSString *)tag
	{
		if( [ recognizedTags containsObject:tag ] ) 
			{
				return YES ;
			}
		else
			{
				return NO ;
			}
		
		return NO ;
	}
	
	
- (NSDictionary *) propertyListDict
	{
		NSMutableDictionary *returnDictionary = [ NSMutableDictionary dictionaryWithCapacity:10 ] ;
		
		[ returnDictionary setObject:sortedFragmentKey forKey:@"sortedFragmentKey" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&nBins length:sizeof(int) ] forKey:@"nBins" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&nFragments length:sizeof(int) ] forKey:@"nFragments" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:fragments length:3*sizeof(int) ] forKey:@"fragments" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&segmentCount length:sizeof(int) ] forKey:@"segmentCount" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&segmentPairCount length:sizeof(int) ] forKey:@"segmentPairCount" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:binCounts length:nBins*sizeof(int) ] forKey:@"binCounts" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:binProbs length:nBins*sizeof(double) ] forKey:@"binProbs" ]  ;
		
		return returnDictionary ;
	}

- (id) initWithPropertyListDict:(NSDictionary *) pListDict
	{
		self = [ super init ] ;

		sortedFragmentKey = [ [ NSString alloc ] initWithString:[ pListDict objectForKey:@"sortedFragmentKey" ] ] ;
		
		NSData *theData ;
		
		theData = [ pListDict objectForKey:@"nBins" ] ;
		[ theData getBytes:&nBins length:sizeof(int) ] ;

		theData = [ pListDict objectForKey:@"nFragments" ] ;
		[ theData getBytes:&nFragments length:sizeof(int) ] ;
		
		theData = [ pListDict objectForKey:@"fragments" ] ;
		[ theData getBytes:fragments length:(3*sizeof(int)) ] ;
		
		theData = [ pListDict objectForKey:@"segmentCount" ] ;
		[ theData getBytes:&segmentCount length:sizeof(int) ] ;
		
		theData = [ pListDict objectForKey:@"segmentPairCount" ] ;
		[ theData getBytes:&segmentPairCount length:sizeof(int) ] ;
		
		binCounts = (int *) malloc( nBins * sizeof( int ) ) ;
		binProbs = (double *) malloc( nBins * sizeof( double ) ) ;
		
		theData = [ pListDict objectForKey:@"binCounts" ] ;
		[ theData getBytes:binCounts length:(nBins*sizeof(int)) ] ;
		
		theData = [ pListDict objectForKey:@"binProbs" ] ;
		[ theData getBytes:binProbs length:(nBins*sizeof(double)) ] ;
		
		return self ;
	}


		
/*
- (NSSet *) histogramsConnectedTo
	{
		NSMutableSet *returnSet = [ NSMutableSet setWithCapacity:10 ] ;
		
		NSEnumerator *connectionEnumerator = [ connections objectEnumerator ] ;
		
		histogramConnection *nextConnection ;
		
		while( ( nextConnection = [ connectionEnumerator nextObject ] ) )
			{
				[ returnSet unionSet:[ nextConnection linkedHistograms ] ] ;
			}
			
		[ returnSet removeObject:self ] ;
		
		return returnSet ;
	}
	
- (BOOL) isConnectedToHistogram:(histogram *)h 
	{
		NSEnumerator *connectionEnumerator = [ connections objectEnumerator ] ;
		
		histogramConnection *nextConnection ;
		
		while( ( nextConnection = [ connectionEnumerator nextObject ] ) )
			{
				if( [ nextConnection includes:h ] == YES )
					{
						return YES ;
					}
			}
			
		return NO ;
	}
	

- (void) registerConnection:(histogramConnection *)c 
	{
		if( [ connections containsObject:c ] == NO )
			{
				[ connections addObject:c ] ;
			}
			
		return ;
	}
	
- (void) clearConnectionToHistogram:(histogram *)h
	{
		NSEnumerator *connectionEnumerator = [ connections objectEnumerator ] ;
		
		histogramConnection *nextConnection ;
		
		while( ( nextConnection = [ connectionEnumerator nextObject ] ) )
			{
				if( [ nextConnection includes:h ] == YES )
					{
						[ connections removeObject:nextConnection ] ;
						return ;
					}
			}
		
		return ;
		
	}
	
- (void) clearAllConnections
	{
		[ connections removeAllObjects ] ;
		return ;
	}
*/

- (void) encodeWithCoder:(NSCoder *)coder
	{		
		// NOTE that we can't encode the host bundle
		
		[ coder encodeObject:sortedFragmentKey ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&nBins ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&nFragments ] ;
		[ coder encodeArrayOfObjCType:@encode(int) count:3 at:fragments ] ;
		
		
		[ coder encodeValueOfObjCType:@encode(int) at:&segmentCount ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&segmentPairCount ] ;
		
		
		[ coder encodeArrayOfObjCType:@encode(int) count:nBins at:binCounts ] ;
		
		[ coder encodeArrayOfObjCType:@encode(double) count:nBins at:binProbs ] ;
				
		return ;
	}
	
- (id) initWithCoder:(NSCoder *)coder
	{
		self = [ super init ] ;
		
		sortedFragmentKey = [ [ coder decodeObject ] retain ] ;
				
		
		[ coder decodeValueOfObjCType:@encode(int) at:&nBins ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&nFragments ] ;
		[ coder decodeArrayOfObjCType:@encode(int) count:3 at:fragments ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&segmentCount ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&segmentPairCount ] ;
		
	
		binCounts = (int *) malloc( nBins * sizeof( int ) ) ;
		binProbs = (double *) malloc( nBins * sizeof( double ) ) ;
		
		[ coder decodeArrayOfObjCType:@encode(int) count:nBins at:binCounts ] ;
		
		[ coder decodeArrayOfObjCType:@encode(double) count:nBins at:binProbs ] ;
		
		
		return self ;
	}
		
		
@end
