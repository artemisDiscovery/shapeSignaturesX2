//
//  histogram.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#include <math.h>
 

@class histogramBundle ;


@class X2SignatureMapping ;

typedef enum {	ONE_DIMENSIONAL, TWO_DIMENSIONAL } histogramClass ;

typedef struct { double lengthDelta ; double MEPDelta ; } histogramStyle ;


@interface histogram : NSObject 
{
@public
	// This object represents a single histogram. It can accommodate one or two dimensions.
	// It can represent a global histogram, or a fragment histogram, either
	// intra- or inter-fragment
	
	histogramBundle *hostBundle ;
	
	// Descriptive tag
	
	NSString *sortedFragmentKey ;
	
	int nBins ;
	
	int nFragments ;
	int fragments[3] ;
	
	// Counts, segments for 1D, segmentPairs for 2D
	
	int segmentCount ;
	int segmentPairCount ;
	
	int *binCounts ;
	double *binProbs ;
	
	//NSMutableArray *connections ;
	

}

//- (id) initWithRayTrace:(rayTrace *)rt tag:(NSString *)tag 
//				style:(histogramStyle)st fragment:(int)frag  ;
				
//- (id) initClusterHistogramUsingMaxLength:(double)maxL style:(histogramStyle)st ;

- (id) initWithBundle:(histogramBundle *)bndl fragmentIndices:(int []) indices ;

- (void) add2DSegmentPairAtLengthBin:(int)lenBin MEPBin:(int)MEPBin ;
- (void) add1DSegmentAtLengthBin:(int)iBin ;

- (void) normalize ;

- (void) setSortedFragmentKey:(NSString *)key ;
			
//- (double) scoreWithHistogram:(histogram *)target useCorrelation:(BOOL)useCor  ;

+ (NSArray *) recognizedTags ;
+ (NSArray *) classByRecognizedTag ;


//- (void) addConnectionToHistogram:(histogram *)h ;

+ (NSArray *) tagDescriptions ;
+ (BOOL) tagAvailable:(NSString *)tag ;

+ (NSString *) descriptionForTag:(NSString *)t ;
+ (BOOL) isTag2D:(NSString *)t ;

- (NSString *) keyStringWithIncrement:(double)probInc ;
- (NSString *) cumulativeKeyStringWithIncrement:(double)probInc ;
- (NSArray *) discretizeWithIncrement:(double)probInc ;
- (NSArray *) discretizeCumulativeWithIncrement:(double)probInc ;

- (NSString *) keyGroupStringWithIncrement:(double)probInc lowBin:(int)lo hiBin:(int)hi ;

+ (double) lowerBoundOnDistanceBetweenKey:(NSString *)key1 andKey:(NSString *)key2 usingProbabilityIncrement:(double)pInc ;

- (NSDictionary *) propertyListDict ;

- (id) initWithPropertyListDict:(NSDictionary *) pListDict ;

/*
- (BOOL) isConnectedToHistogram:(histogram *)h ;

- (NSSet *) histogramsConnectedTo ;

- (void) registerConnection:(histogramConnection *)c ;
- (void) clearConnectionToHistogram:(histogram *)h ;
- (void) clearAllConnections ;
*/
@end
