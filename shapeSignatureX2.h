//
//  shapeSignatureX2.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "histogramBundle.h"


@interface X2Signature : NSObject 
{
	// This is the second incarnation of the new shape sig X object. 
	// I am starting from scratch as I will now reatain both inter- and intra-
	// fragment information.
	
@public
	
		NSString *identifier ;
	
		ctTree *sourceTree ;
		
		BOOL segmentsWereCounted ;
		BOOL segmentPairsWereCounted ;
		
		BOOL fragmentSegmentsWereCounted ;
		BOOL fragmentSegmentPairsWereCounted ;
		
		
		int totalSegments ;	    // For 1D histos
		int totalSegmentPairs ; // For 2D histos
		
		int totalInterFragmentSegments ;	// 1D fragments
		int totalInterFragmentSegmentPairs ;	// 2D fragments
		
		int totalIntraFragmentSegments ;	// 1D fragments
		int totalIntraFragmentSegmentPairs ;	// 2D fragments
		
		// Signature bundles are represented by a tag - for example
		// 1DHISTO, 2DMEPHISTO, 2DMEPREDUCEDHISTO, etc. 
		// A 1D class maps to histogram dictionary with key GLOBAL (all reflection segments),
		// intrafragment keys like "1", "2", etc, and interfragment (as found) with 
		// keys like "1_3", etc. 
		// A 2D class maps to histogram dictionary with key GLOBAL (all pairs of segments bordering
		// a single reflection) and also to all intrafragment and inter-fragment keys 
		// (with values like "1", "2", "1_3", "3_5_6", etc). 
		
		// This dictionary points at other dictionaries
		
		NSMutableDictionary *histogramBundleForTag ;
		

}

- (id) initForAllTagsUsingTree:(ctTree *)tree andRayTrace:(rayTrace *)rt withStyle:(histogramStyle)st ;
			
- (void) addHistogramsWithTag:(NSString *)tag forRayTrace:(rayTrace *)rt withStyle:(histogramStyle)st ;

+ (NSArray *) scoreQuerySignature:(X2Signature *)query againstTarget:(X2Signature *)target usingTag:(NSString *)tag
				withCorrelation:(BOOL)useCor useFragments:(BOOL)useFrag ;

+ (NSString *) version ;


@end
