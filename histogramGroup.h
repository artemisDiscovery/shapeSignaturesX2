//
//  histogramGroup.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "histogramBundle.h"
#include <math.h>

#import "scoringScheme.h"

// This represents a group of histograms. All must have the same dimension so that they can be 
// easily merged into a single 1D array of probabilities. 

@interface histogramGroup : NSObject 
{
@public
	NSArray *memberHistograms ;
	
	histogramBundle *hostBundle ;
	
	int nLengthBins ;
	int nMEPBins ;
	int nBins ;
	
	int segmentCount ;
	int segmentPairCount ;
	
	double *binProbs ;
	
	NSMutableSet *groupFragmentIndices ;
	NSMutableSet *neighborFragmentIndices ;
	
	NSArray *sortedGroupFragmentIndices ;
	
	NSMutableArray *connectToGroups ;
	
}

- (id) initWithHistograms:(NSArray *)histos inBundle:(histogramBundle *)bndl withFragmentIndices:(NSSet *)indices   ;

- (void) addConnectionTo:(histogramGroup *)g ;

- (NSArray *) sortedFragmentIndices ;

- (double) scoreWithHistogramGroup:(histogramGroup *)target scoringScheme:(scoringScheme *)scheme ;

@end
