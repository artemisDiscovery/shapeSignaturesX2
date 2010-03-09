//
//  histogramGroup.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "histogramBundle.h"


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
	
	NSMutableArray *connectToGroups ;
	
}

- (id) initWithHistograms:(NSArray *)histos inBundle:(histogramBundle *)bndl   ;

- (void) addConnectionTo:(histogramGroup *)g ;

- (NSArray *) sortedFragmentIndices ;

- (double) scoreWithHistogramGroup:(histogramGroup *)target useCorrelation:(BOOL)useCorr ;

@end
