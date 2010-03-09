//
//  hitListItem.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 10/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "X2SignatureMapping.h"

// This is one item in the hitlist. It always represents a comparison between hisrogram group bundles



@interface hitListItem : NSObject 
{
@public
	
	// NOTE that the mapping object I will define already holds the pointers to the X2Signatures
	
	
	X2SignatureMapping *mapping ;
	
	double weightedScore, minimumScore, maximumScore ;
	double percentQueryUnmatched, percentTargetUnmatched ;
	
	
}

- (id) initWithMapping:(X2SignatureMapping *)map ;

- (void) addScoresWithCorrelation:(BOOL)useCor ;

+ (void) merge:(NSArray *)sourceHits intoHitList:(NSMutableArray *)targetHits withMaxScore:(double)maxScore 
									maxPercentQueryUnmatched:(double)maxQueryUnmatched 
									maxPercentTargetUnmatched:(double)maxTargetUnmatched ;
									
+ (void) sortHits:(NSMutableArray *)hits useWeightedScore:(BOOL)sortByWeightedScore
							retainHits:(int)maxHits ;
@end
