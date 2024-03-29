//
//  histogramBundle.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "rayTrace.h"
#import "histogram.h"

@class X2Signature ;


@interface histogramBundle : NSObject 
{
	// Maintain a bundle of histograms for a molecule, where each element is a 
	// global histogram or a fragment histo. All histograms have same style and 
	// dimensions.
	
@public

	histogramClass type ;
	NSString *tag ;
	
	ctTree *sourceTree ;
	
	X2Signature *sourceSignature ;
	
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

- (id) initWithRayTrace:(rayTrace *)rt tag:(NSString *)tg style:(histogramStyle)st inSignature:(X2Signature *)sig  ;

- ( NSString *) keyStringsForBundleWithIncrement:(double) inc ;

- (NSDictionary *) propertyListDict ;

- (id) initWithPropertyListDict:(NSDictionary *) pListDict ;


@end
