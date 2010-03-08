//
//  histogramGroup.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "histogramGroup.h"


@implementation histogramGroup

- (id) initWithHistograms:(NSArray *)histos inBundle:(histogramBundle *)bndl 
	{
		self = [ super init ] ;
		
		hostBundle = bndl ;
		
		nLengthBins = hostBundle->nLengthBins ;
		nMEPBins = hostBundle->nMEPBins ;
		nBins = hostBundle->nBins ;
		
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
					}
				else
					{
						histoSegments = nextHisto->segmentPairCount ;
					}
					
				segmentSum += histoSegments ;
					
				for( k = 0 ; k < nBins ; ++k )
					{
						binProbs[k] += histoSegments * nextHisto->binProbs[k] ;
					}
					
			}
			
		// "Renormalize" the probabilities
		
		for( k = 0 ; k < nBins ; ++k )
			{
				binProbs[k] /= segmentSum ;
			}
			
		// Set up set of group fragment indices 
		
		groupFragmentIndices = [ [ NSMutableSet alloc ] initWithCapacity:[ histos count ] ] ;
		
		histoEnumerator = [ histos objectEnumerator ] ;
		
		while( ( nextHisto = [ histoEnumerator nextObject ] ) )
			{
				if( [ nextHisto->sortedFragmentKey isEqualToString:@"GLOBAL" ] == YES ) continue ;
				
				NSArray *fragmentIndices = [ nextHisto->sortedFragmentKey componentsSeparatedByString:@"_" ] ;
				
				[ groupFragmentIndices addObjectsFromArray:fragmentIndices ] ;
			}
			
		neighborFragmentIndices = [ [ NSMutableSet alloc ] initWithCapacity:[ histos count ] ] ;
		
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
					
		// Subtract the fragments involved in the current group 
		
		[ neighborFragmentIndices minusSet:groupFragmentIndices ] ;
		
				
			
		return self ;
	}
		
		
- (void) addConnectionTo:(histogramGroup *)g
	{
		if( [ connectToGroups containsObject:g ] == YES )
			{
				[ connectToGroups addObject:g ] ;
				// Assume symmetry
				[ g->connectToGroups addObject:self ] ;
			}
			
		return ;
	}
		


@end
