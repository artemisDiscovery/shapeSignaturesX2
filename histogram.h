//
//  histogram.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class rayTrace ;

typedef enum {	ONE_DIMENSIONAL_GLOBAL, TWO_DIMENSIONAL_GLOBAL, 
				ONE_DIMENSIONAL_INTRAFRAGMENT, TWO_DIMENSIONAL_INTRAFRAGMENT,
				ONE_DIMENSIONAL_INTERFRAGMENT, TWO_DIMENSIONAL_INTERFRAGMENT } histogramClass ;

typedef struct { double lengthDelta ; double MEPDelta ; } histogramStyle ;

@class X2SignatureMapping ;

@interface histogram : NSObject 
{
@public
	// This object represents a single histogram. It can accommodate one or two dimensions.
	// It can represent a global histogram, or a fragment histogram, either
	// intra- or inter-fragment
	
	histogramClass type ;
	
	// Descriptive tag
	
	NSString *tag ;
	NSString *fragmentKey ;
	
	// For partition histograms
	 
	int nParticipatingFragments ;
	int nParticipatingFragmentAlloc ;
	int *fragments ;
	
	int nBins ;
	int nLengthBins ;
	double lengthDelta ;
	
	int nMEPBins ;
	
	// minMEP will be generated automatically and will always be in increments of MEPDelta (to ensure bin 
	// alignment when histograms are being compared) 
	
	double minMEP ;
	double MEPDelta ;
	
	// For a 2-D histogram, number of bins = nLengthBins * nMEPBins ; for 1-D, number of bins = nLengthBins 
	
	// Counts, segments for 1D, segmentPairs for 2D
	
	int segmentCount ;
	int segmentPairCount ;
	
	int *binCounts ;
	double *binProbs ;
	

}

- (id) initWithRayTrace:(rayTrace *)rt tag:(NSString *)tag 
				style:(histogramStyle)st fragment:(int)frag  ;
				
//- (id) initClusterHistogramUsingMaxLength:(double)maxL style:(histogramStyle)st ;
			
- (double) scoreWithHistogram:(histogram *)target useCorrelation:(BOOL)useCor  ;

+ (NSArray *) recognizedTags ;
+ (NSArray *) classByRecognizedTag ;


- (void) addConnectionToHistogram:(histogram *)h ;

+ (BOOL) tagAvailable:(NSString *)tag ;

+ (NSString *) descriptionForTag:(NSString *)t ;
+ (BOOL) isTag2D:(NSString *)t ;

- (void) useChildrenToExtendMatch:(XSignatureMapping *)map ;

- (NSString *) keyStringWithIncrement:(double)probInc ;
- (NSArray *) discretizeWithIncrement:(double)probInc ;

- (NSString *) keyGroupStringWithIncrement:(double)probInc lowBin:(int)lo hiBin:(int)hi ;

+ (double) lowerBoundOnDistanceBetweenKey:(NSString *)key1 andKey:(NSString *)key2 usingProbabilityIncrement:(double)pInc ;

@end
