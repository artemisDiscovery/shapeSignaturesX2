//
//  hitListItem.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 10/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "X2SignatureMapping.h"

// This is one item in the hitlist. It always represents a comparison between histogram group bundles

// 4 September 2010 - Major revision of this class. I will no longer maintain references to 
// X2Signature objects via mappings, since those objects may be dealloced (for better memory 
// performance, I want to release target signatures after we have compared against them). 



@interface hitListItem : NSObject 
{
@public
	
	// NOTE that the mapping object I will define already holds the pointers to the X2Signatures
	
	NSString *queryName ;
	NSString *targetName ;
	
	NSMutableArray *fragmentGroupPairs ;
	
	// Note that the mapping is not guaranteed to be alive forever - might be worthwhile to
	// invalidate this component. 
	
	X2SignatureMapping *mapping ;
	
	int cumQuerySegments, cumTargetSegments ;
	int totalQuerySegments, totalTargetSegments ;
	
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
