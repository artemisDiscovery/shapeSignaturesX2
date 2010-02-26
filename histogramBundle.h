//
//  histogramBundle.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "rayTrace.h"
#import "histogram.h"


@interface histogramBundle : NSObject 
{
	// Maintain a bundle of histograms for a molecule, where each element is a 
	// global histogram or a fragment histo. All histograms have same style and 
	// dimensions.
	
@public

	histogramClass type ;
	histogramStyle style ;
	NSString *tag ;
	
	ctTree *sourceTree ;
	
	rayTrace *theTrace ;
	
	
	int nBins ;
	int nLengthBins ;
	double lengthDelta ;
	
	int nMEPBins ;
	
	// minMEP will be generated automatically and will always be in increments of MEPDelta (to ensure bin 
	// alignment when histograms are being compared) 
	
	double minMEP ;
	double MEPDelta ;

	NSMutableDictionary *sortedFragmentsToHistogram ;

}

- (id) initWithRayTrace:(rayTrace *)rt tag:(NSString *)tg style:(histogramStyle)st ;

@end
