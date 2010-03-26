//
//  hitListItem.m
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 10/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "hitListItem.h"


@implementation hitListItem

- (id) initWithMapping:(X2SignatureMapping *)map
	{
		self = [ super init ] ;
		
		mapping = map ;
		
		[ map retain ] ;
		
		weightedScore = 2. ; 
		minimumScore = 2. ;
		maximumScore = 2. ;
		percentQueryUnmatched = 100. ;
		percentTargetUnmatched = 100. ;
		
		return self;
	}
	
- (void) dealloc
	{
		[ mapping release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}
	
- (void) addScoresWithCorrelation:(BOOL)useCor
	{
		// Add score as third list of each histogram pair, then compute aggregate scores
		
		NSEnumerator *histoGroupPairEnumerator =  [ mapping->histoGroupPairs objectEnumerator ] ;
		
		NSMutableArray *nextHistoGroupPair ;
		
		minimumScore = 2. ;
		maximumScore = 0. ;
		

		weightedScore = 0 ;
		
		int cumQuerySegments =  0 ;
		int cumTargetSegments = 0 ;
		
		while( ( nextHistoGroupPair = [ histoGroupPairEnumerator nextObject ] ) )
			{
				histogramGroup *queryHistoGroup = [ nextHistoGroupPair objectAtIndex:0 ] ;
				histogramGroup *targetHistoGroup = [ nextHistoGroupPair objectAtIndex:1 ] ;
				
				double score = [ queryHistoGroup scoreWithHistogramGroup:targetHistoGroup useCorrelation:useCor ] ;
				
				[ nextHistoGroupPair addObject:[ NSNumber numberWithDouble:score ] ] ;
				
				if( score < minimumScore ) minimumScore = score ;
				if( score > maximumScore ) maximumScore = score ;
				
				// Only segmentCount or segmentPairCount will be nonzero
				
				int qCount = queryHistoGroup->segmentCount + queryHistoGroup->segmentPairCount ;
				int tCount = targetHistoGroup->segmentCount + targetHistoGroup->segmentPairCount ;
				
				weightedScore += ( qCount + tCount ) * score ;
				cumQuerySegments += qCount ;
				
				cumTargetSegments += tCount ;
				
			}
			
		weightedScore /= ( cumQuerySegments + cumTargetSegments ) ;
		
		int QTOT, TTOT ;
		
		if( mapping->query->hostBundle->type == ONE_DIMENSIONAL  )
			{
				QTOT = mapping->query->hostBundle->sourceSignature->totalSegments ;
				TTOT = mapping->target->hostBundle->sourceSignature->totalSegments ;
			}
		else
			{
				QTOT = mapping->query->hostBundle->sourceSignature->totalSegmentPairs ;
				TTOT = mapping->target->hostBundle->sourceSignature->totalSegmentPairs ;
			}
		
		// Compute "percentage" of query unmatched, likewise for target
		
		percentQueryUnmatched = 100. * ( 1. - ((double) cumQuerySegments ) / QTOT ) ;
		percentTargetUnmatched = 100. * ( 1. - ((double) cumTargetSegments ) / TTOT ) ;
		
		return ;
	}
		
		
 + (void) merge:(NSArray *)sourceHits intoHitList:(NSMutableArray *)targetHits withMaxScore:(double)maxScore 
									maxPercentQueryUnmatched:(double)maxQueryUnmatched 
									maxPercentTargetUnmatched:(double)maxTargetUnmatched
	{
		
		NSEnumerator *sourceHitEnumerator = [ sourceHits objectEnumerator ] ;
		
		hitListItem *nextSourceItem ;
		
		while( ( nextSourceItem = [ sourceHitEnumerator nextObject ] ) )
			{
				if( nextSourceItem->weightedScore > maxScore ) continue ;
				if( nextSourceItem->percentQueryUnmatched > maxQueryUnmatched ) continue ;
				if( nextSourceItem->percentTargetUnmatched > maxTargetUnmatched ) continue ;
				
				[ targetHits addObject:nextSourceItem ] ;
			}
			
		return ;
			
	}
			
+ (void) sortHits:(NSMutableArray *)hits useWeightedScore:(BOOL)sortByWeightedScore
							retainHits:(int)maxHits	
	{
		// Sort hits in situ
		
		if( sortByWeightedScore == YES )
			{
				[ hits sortUsingSelector:@selector( sortByWeighted: ) ] ;
			}
		else
			{
				[ hits sortUsingSelector:@selector( sortByMinimum: ) ] ;
			}
			
		return ;
	}
		
- (NSComparisonResult) sortByWeighted:(hitListItem *)comp 
	{
		if( weightedScore < comp->weightedScore )
			{
				return NSOrderedAscending ;
			}
		else if( weightedScore > comp->weightedScore )
			{
				return NSOrderedDescending ;
			}
		else
			{
				return NSOrderedSame ;
			}
			
		return NSOrderedSame ;
	}
		
- (NSComparisonResult) sortByMinimum:(hitListItem *)comp 
	{
		if( minimumScore < comp->minimumScore )
			{
				return NSOrderedAscending ;
			}
		else if( minimumScore > comp->minimumScore )
			{
				return NSOrderedDescending ;
			}
		else
			{
				return NSOrderedSame ;
			}
			
		return NSOrderedSame ;
	}
	

@end
