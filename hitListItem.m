//
//  hitListItem.m
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 10/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "hitListItem.h"
#import "scoringScheme.h"


@implementation hitListItem

- (id) initWithMapping:(X2SignatureMapping *)map
	{
		self = [ super init ] ;
		
		mapping = map ;
		
		[ map retain ] ;
	
		fragmentGroupPairs = [ [ NSMutableArray alloc ] initWithCapacity:[ mapping->histoGroupPairs count ] ] ;
	
		queryName = [ [ NSString alloc ] initWithString:mapping->query->hostBundle->sourceTree->treeName ] ;
		targetName = [ [ NSString alloc ] initWithString:mapping->target->hostBundle->sourceTree->treeName ] ;
		
		weightedScore = 2. ; 
		minimumScore = 2. ;
		maximumScore = 2. ;
		percentQueryUnmatched = 100. ;
		percentTargetUnmatched = 100. ;
		
		return self;
	}
	
- (void) dealloc
	{
		if( mapping ) [ mapping release ] ;
		
		[ fragmentGroupPairs release ] ;
	
		[ queryName release ] ;
		[ targetName release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}

double logistic( double thresh, double gamma, int segCount, int cumSeg )
{
	double f = (double)segCount / cumSeg ;
	double term = exp( -gamma * ( thresh - f ) ) ;
	
	return term / ( 1. + term ) ;
}
	
- (void) addScoresWithScoringScheme:(scoringScheme *)scheme
	{
		// Add score as third list of each histogram pair, then compute aggregate scores
		
 		NSEnumerator *histoGroupPairEnumerator =  [ mapping->histoGroupPairs objectEnumerator ] ;
		
		NSMutableArray *nextHistoGroupPair ;
		
		minimumScore = 2. ;
		maximumScore = 0. ;
		

		weightedScore = 0 ;
		
		cumQuerySegments =  0 ;
		cumTargetSegments = 0 ;
		
		
		while( ( nextHistoGroupPair = [ histoGroupPairEnumerator nextObject ] ) )
			{
				histogramGroup *queryHistoGroup = [ nextHistoGroupPair objectAtIndex:0 ] ;
				histogramGroup *targetHistoGroup = [ nextHistoGroupPair objectAtIndex:1 ] ;
				
				double score = [ queryHistoGroup scoreWithHistogramGroup:targetHistoGroup scoringScheme:scheme ] ;
				
				
			
				//[ nextHistoGroupPair addObject:[ NSNumber numberWithDouble:score ] ] ;
				
				if( score < minimumScore ) minimumScore = score ;
				if( score > maximumScore ) maximumScore = score ;
				
				// Only segmentCount or segmentPairCount will be nonzero
				
				int qCount = queryHistoGroup->segmentCount + queryHistoGroup->segmentPairCount ;
				int tCount = targetHistoGroup->segmentCount + targetHistoGroup->segmentPairCount ;
			
				[ fragmentGroupPairs addObject:[ NSArray arrayWithObjects:
											[ NSArray arrayWithArray:[ queryHistoGroup sortedFragmentIndices ] ],
											[ NSArray arrayWithArray:[ targetHistoGroup sortedFragmentIndices ] ],
											[ NSNumber numberWithDouble:score ],
											[ NSNumber numberWithInt:qCount ],
											[ NSNumber numberWithInt:tCount ],nil ] ] ;
				
				weightedScore += ( qCount + tCount ) * score ;
				cumQuerySegments += qCount ;
				
				cumTargetSegments += tCount ;
				
			}
			
		if( scheme.useLogistic == YES )
		{
			// We need to recompute score using the logistic function approach
			
			weightedScore = 0. ;
			double denom = 0. ;
			double num = 0. ;
			
			int cumSegments = cumQuerySegments + cumTargetSegments ;
			
			for ( NSArray *pair in fragmentGroupPairs )
			{
				int segCount = [ (NSNumber *)[ pair objectAtIndex:3 ] intValue ] +
				[ (NSNumber *)[ pair objectAtIndex:4 ] intValue ] ;
				
				double pairScore = [ (NSNumber *)[ pair objectAtIndex:2 ] doubleValue ] ;
				
				double lg = logistic( scheme.switchThreshold, scheme.gamma, segCount, cumSegments) ;
				
				num +=  lg * segCount *  pairScore ;
				denom += lg * segCount ;
			}
			
			weightedScore = num / denom ;
		}
		else 
		{
			weightedScore /= ( cumQuerySegments + cumTargetSegments ) ;
		}
		
		// Compute "percentage" of query unmatched, likewise for target
		
		// There is an issue here - the totalQuerySegements counts all segments, both inter- and intra-fragment,
		// but only intra- are used currently in scoring - thus percent used can never reach 100. Modify
		// to use totalIntraFragmentSegments or segmentPairs as appropriate
				
		if( mapping->query->hostBundle->type == ONE_DIMENSIONAL  )
			{
				totalQuerySegments = mapping->query->hostBundle->sourceSignature->totalIntraFragmentSegments ;
				totalTargetSegments = mapping->target->hostBundle->sourceSignature->totalIntraFragmentSegments ;
			}
		else
			{
				totalQuerySegments = mapping->query->hostBundle->sourceSignature->totalIntraFragmentSegmentPairs ;
				totalTargetSegments = mapping->target->hostBundle->sourceSignature->totalIntraFragmentSegmentPairs ;
			}
		
		
		
		percentQueryUnmatched = 100. * ( 1. - ((double) cumQuerySegments ) / totalQuerySegments ) ;
		percentTargetUnmatched = 100. * ( 1. - ((double) cumTargetSegments ) / totalTargetSegments ) ;
		
		
		// No longer need the mapping 
	
		[ mapping release ] ;
	
		mapping = nil ;
		
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
	
		
		if( [ hits count ] > maxHits )
			{
				NSRange removeRange = NSMakeRange(maxHits, [ hits count ] - maxHits ) ;
				[ hits removeObjectsInRange:removeRange ] ;
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
