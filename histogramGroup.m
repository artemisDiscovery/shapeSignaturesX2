//
//  histogramGroup.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "histogramGroup.h"
#import "fragment.h"


@implementation histogramGroup

- (id) initWithHistograms:(NSArray *)histos inBundle:(histogramBundle *)bndl withFragmentIndices:(NSSet *)indices
	{
		NSInteger indexCompare( id , id , void * ) ;
		
		self = [ super init ] ;
		
		hostBundle = bndl ;
		
		nLengthBins = hostBundle->nLengthBins ;
		nMEPBins = hostBundle->nMEPBins ;
		nBins = hostBundle->nBins ;
		
		segmentCount = 0 ;
		segmentPairCount = 0 ;
		
		connectToGroups = [ [ NSMutableArray alloc ] initWithCapacity:[ hostBundle->sortedFragmentsToHistogram count ] ] ;
		memberHistograms = [ [ NSArray alloc ] initWithArray:histos  ] ;
		
		binProbs = (double *) malloc( nBins * sizeof( double ) ) ;
		
		int k ; 
		
		for( k = 0 ; k < nBins ; ++k )
			{
				binProbs[k] = 0. ;
			}
			
		NSEnumerator *histoEnumerator = [ histos objectEnumerator ] ;
		
		histogram *nextHisto ;
		
		int segmentSum = 0 ;
		
		while( ( nextHisto = [ histoEnumerator nextObject ] ) )
			{
				int histoSegments ;
				
				if( hostBundle->type == ONE_DIMENSIONAL )
					{
						histoSegments = nextHisto->segmentCount ;
						segmentCount += histoSegments ;
					}
				else
					{
						histoSegments = nextHisto->segmentPairCount ;
						segmentPairCount += histoSegments ;
					}
					
				segmentSum += histoSegments ;
					
				for( k = 0 ; k < nBins ; ++k )
					{
						binProbs[k] += histoSegments * nextHisto->binProbs[k] ;
					}
					
			}
			
		// "Renormalize" the probabilities
		
		// Note that we could potentially have an empty group (fragment with no probability)
		
		if( segmentSum > 0 )
			{
				for( k = 0 ; k < nBins ; ++k )
					{
						binProbs[k] /= segmentSum ;
					}
			}
			
		// Set up set of group fragment indices 
		
		groupFragmentIndices = [ [ NSMutableSet alloc ] initWithSet:indices ] ;
		
		// Make sorted index array
		
		sortedGroupFragmentIndices = [ [ NSMutableArray alloc ] initWithArray:[ groupFragmentIndices allObjects ] ] ;
		
		[ sortedGroupFragmentIndices sortUsingFunction:indexCompare context:nil ] ;
		
		/*histoEnumerator = [ histos objectEnumerator ] ;
		
		
		while( ( nextHisto = [ histoEnumerator nextObject ] ) )
			{
				if( [ nextHisto->sortedFragmentKey isEqualToString:@"GLOBAL" ] == YES ) continue ;
				
				NSArray *fragmentIndices = [ nextHisto->sortedFragmentKey componentsSeparatedByString:@"_" ] ;
				
				[ groupFragmentIndices addObjectsFromArray:fragmentIndices ] ;
			}
		*/
						
		neighborFragmentIndices = [ [ NSMutableSet alloc ] initWithCapacity:[ indices count ] ] ;
		
		NSString *nextGroupFragmentIndex ;
		
		NSEnumerator *indexAsStringEnumerator = [ indices objectEnumerator ] ;
		
		while( ( nextGroupFragmentIndex = [ indexAsStringEnumerator nextObject ] ) )
			{
				int idx = [ nextGroupFragmentIndex intValue ] ;
				fragment *thisFragment = [ hostBundle->sourceTree->treeFragments objectAtIndex:(idx - 1) ] ;
				[ neighborFragmentIndices unionSet:thisFragment->neighborFragmentIndices ] ;
			}
			
		/*
		histoEnumerator = [ histos objectEnumerator ] ;
		
		NSMutableSet *localSet = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
		
		while( ( nextHisto =  [ histoEnumerator nextObject ] ) )
			{
				if( [ nextHisto->sortedFragmentKey isEqualToString:@"GLOBAL" ] == YES ) continue ;
				
				[ localSet removeAllObjects ] ;
				NSArray *fragmentIndices = [ nextHisto->sortedFragmentKey componentsSeparatedByString:@"_" ] ;
				[ localSet addObjectsFromArray:fragmentIndices ] ;
				
				// For sanity ...
				
				if( [ localSet count ] == 1 )
					{
						// Get fragment object from tree
						
						int idx = [ [ localSet anyObject ] intValue ] ;
						
						// Note that fragment array is sorted, but I chose to number fragments starting at 1 :-(
						
						fragment *thisFragment = [ hostBundle->sourceTree->treeFragments objectAtIndex:(idx - 1) ] ;
						
						[ neighborFragmentIndices unionSet:thisFragment->neighborFragmentIndices ] ;
					}
			}
					
		*/
		
		// Subtract the fragments involved in the current group 
		
		[ neighborFragmentIndices minusSet:groupFragmentIndices ] ;
		
		if( [ neighborFragmentIndices count ] == 0 )
			{
				//printf( "WARNING: HAVE GROUP FRAGMENTS WITH NO NEIGHBORS\n" ) ;
			}
		
		// [ localSet release ] ;
		
				
			
		return self ;
	}
	
- (void) dealloc
	{
		[ memberHistograms release ] ;
		
		free( binProbs ) ;
		
		[ groupFragmentIndices release ] ;
		[ neighborFragmentIndices release ] ;
		
		[ connectToGroups release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}

- (double) scoreWithHistogramGroup:(histogramGroup *)target scoringScheme:(scoringScheme *)scheme
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
		
		BOOL useCor ;
		
		if( scheme.scoring == CORRELATION )
		{
			useCor = YES ;
		}
		else
		{
			useCor = NO ;
		}
		
		// Check for empty group
	
		histogramClass type = hostBundle->type ;
		
		if (type == ONE_DIMENSIONAL ) {
			if( segmentCount == 0 && target->segmentCount == 0 ) return 0. ;
			if( segmentCount == 0 || target->segmentCount == 0 ) return 1. ;
		}
		else {
			if( segmentPairCount == 0 && target->segmentPairCount == 0 ) return 0. ;
			if( segmentPairCount == 0 || target->segmentPairCount == 0 ) return 1. ;
		}
		
		
		
		double *TProb = target->binProbs ;
		double *QProb = binProbs ;
		
		// To match my spiel above:
		
		int LQ = hostBundle->nLengthBins - 1 ;
		
		int LT = target->hostBundle->nLengthBins - 1 ;
		
		int L = LQ > LT ? LQ : LT ;
		
		int l ;
		
		// Note that this object is defined as the "query"
		
		
		
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
				
				if( useCor == NO )
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

		
- (void) addConnectionTo:(histogramGroup *)g
	{
		if( [ connectToGroups containsObject:g ] == NO )
			{
				[ connectToGroups addObject:g ] ;
			}
			
		return ;
	}
		
- (NSArray *) sortedFragmentIndices
	{
		return sortedGroupFragmentIndices ;
		
		/*
		NSInteger indexCompare( id , id , void * ) ;
		
		NSMutableArray *returnArray = [ NSMutableArray arrayWithArray:[ groupFragmentIndices allObjects ] ] ;
		
		[ returnArray sortUsingFunction:indexCompare context:nil ] ;
		
		return returnArray ;
		*/
	}
		
- (BOOL) isEqualTo:(histogramGroup *)comp
	{
		if( [ groupFragmentIndices count ] != [ comp->groupFragmentIndices count ] ) return NO ;
		
		NSArray *myIndices = [ self sortedFragmentIndices ] ;
		NSArray *compIndices = [ comp sortedFragmentIndices ] ;
		
		int k ;
		
		for( k = 0 ; k < [ myIndices count ] ; ++k )
			{
				NSString *myIndex = [ myIndices objectAtIndex:k ] ;
				NSString *compIndex = [ compIndices objectAtIndex:k ] ;
				
				if( [ myIndex isEqualToString:compIndex ] == NO ) return NO ;
			}
			
		return YES ;
	}
		
NSInteger indexCompare( id A, id B, void *ctxt )
	{
		NSString *sA = (NSString *) A ;
		NSString *sB = (NSString *) B ;
		
		if( [ sA intValue ] < [ sB intValue ] )
			{
				return NSOrderedAscending ;
			}
		else if( [ sA intValue ] > [ sB intValue ] )
			{
				return NSOrderedDescending ;
			}
			
		return NSOrderedSame ;
	}

@end
