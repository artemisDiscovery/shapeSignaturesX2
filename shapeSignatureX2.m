//
//  shapeSignatureX2.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "shapeSignatureX2.h"

static NSString *version ;

@implementation X2Signature

+ (void) initialize
	{
		version = [ [ NSString stringWithString:@"ShapeSignatures v. X2.0" ] retain ] ;
		
		return ;
	}
	
+ (NSString *) version
	{
		return version ;
	}

- (id) initForAllTagsUsingTree:(ctTree *)tree andRayTrace:(rayTrace *)rt withStyle:(histogramStyle)st 
	{
		self = [ super init ] ;
		
		totalSegments = 0 ;	    // For 1D histos
		totalSegmentPairs = 0 ; // For 2D histos
		
		totalInterFragmentSegments = 0 ;	// 1D fragments
		totalInterFragmentSegmentPairs = 0 ;	// 2D fragments
		
		totalIntraFragmentSegments = 0 ;	// 1D fragments
		totalIntraFragmentSegmentPairs = 0 ;	// 2D fragments
	
		segmentsWereCounted = NO ;
		segmentPairsWereCounted = NO ;
		
		fragmentSegmentsWereCounted = NO ;
		fragmentSegmentPairsWereCounted = NO ;
				
		// Histogram bundle dictionary
		
		histogramBundleForTag = [ [ NSMutableDictionary alloc ] 
			initWithCapacity:[ [ histogram tagDescriptions ] count ] ] ;
		
		sourceTree = tree ;
		
		// Add ID if we like - the source tree has a name. 
		
		identifier = nil ;
		
		// For all tags
		
		NSEnumerator *tagEnumerator = [ [ histogram recognizedTags ] objectEnumerator ] ;
		
		NSString *nextTag ;
		
		while( ( nextTag = [ tagEnumerator nextObject ] ) )
			{
				[ self addHistogramsWithTag:nextTag forRayTrace:rt withStyle:st ] ;
			}
		
				 
		
		return self ;
				
		
	}


- (void) addHistogramsWithTag:(NSString *)tag forRayTrace:(rayTrace *)rt withStyle:(histogramStyle)st 
	{
		
		// Make sure that the tag is available 
		
		if( [ histogram tagAvailable:tag ] == NO )
			{
				printf( "TAG %s NOT AVAILABLE, NOT ADDED!\n", [ tag cString ]  ) ;
				return ;
			}
			
		// Make the histograms, add the bundle to our dictionary
		
		
		
		histogramBundle *theHistogramBundle = [ [ histogramBundle alloc ]  initWithRayTrace:(rayTrace *)rt tag:(NSString *)tag style:(histogramStyle)st  ] ;
				
		if( ! theHistogramBundle )
			{
				printf( "HISTOGRAM FAILURE FOR TAG %s , BUNDLE NOT ADDED!\n", [ tag cString ] ) ;
				return ;
			}
			
		[ histogramBundleForTag setObject:theHistogramBundle forKey:tag ] ;
			
		// Check segments/segmentPairs
		
		NSDictionary *histoDict = theHistogramBundle->sortedFragmentsToHistogram ;
		
		histogram *globalHisto = [ histoDict objectForKey:@"GLOBAL" ] ;
		
		if( theHistogramBundle->type == ONE_DIMENSIONAL )
			{
				if( segmentsWereCounted == NO )
					{
						totalSegments = globalHisto->segmentCount ;
						segmentsWereCounted = YES ;
					}
				else if( totalSegments != globalHisto->segmentCount )
					{
						printf( "WARNING: TOTAL SEGMENTS DISAGREE (%d VS %d) FOR TAG %s\n",
							globalHisto->segmentCount, totalSegments, [ tag cString ] ) ;
					}
			}
		else
			{
				if( segmentPairsWereCounted == NO )
					{
						totalSegmentPairs = globalHisto->segmentPairCount ;
						segmentPairsWereCounted = YES ;
					}
				else if( totalSegmentPairs != globalHisto->segmentPairCount )
					{
						printf( "WARNING: TOTAL SEGMENT PAIRS DISAGREE (%d VS %d) FOR TAG %s\n",
							globalHisto->segmentPairCount, totalSegmentPairs, [ tag cString ] ) ;
					}
			}
			
		// Check counts for non-global histos
		
		NSEnumerator *keyEnumerator = [ [ histoDict allKeys ] objectEnumerator ] ;
		NSString *histoKey ;
	
		int tempIntraCount = 0 ;
		int tempInterCount = 0 ;

		
		while( ( histoKey = [ keyEnumerator nextObject ] ) )
			{
				if( [ histoKey isEqualToString:@"GLOBAL" ] == YES ) continue ;
				
				histogram *nextHisto = [ histoDict objectForKey:histoKey ] ;
				
				// Different handling of 1D and 2D
				
				
				if( theHistogramBundle->type == ONE_DIMENSIONAL )
					{
						 if( nextHisto->fragments[0] == nextHisto->fragments[1] )
							{
								// Intra
								
								if( fragmentSegmentsWereCounted == NO )
									{
										totalIntraFragmentSegments += nextHisto->segmentCount ;
									}
								else
									{
										tempIntraCount += nextHisto->segmentCount ;
									}
							}
						else
							{
								// Inter
								
								if( fragmentSegmentsWereCounted == NO )
									{
										totalInterFragmentSegments += nextHisto->segmentCount ;
									}
								else
									{
										tempInterCount += nextHisto->segmentCount ;
									}
							}
					}
				else
					{
						 if( nextHisto->fragments[0] == nextHisto->fragments[1] &&
								nextHisto->fragments[0] == nextHisto->fragments[2] )
							{
								// Intra
								
								if( fragmentSegmentPairsWereCounted == NO )
									{
										totalIntraFragmentSegmentPairs += nextHisto->segmentPairCount ;
									}
								else
									{
										tempIntraCount += nextHisto->segmentPairCount ;
									}
							}
						else
							{
								// Inter
								
								if( fragmentSegmentPairsWereCounted == NO )
									{
										totalInterFragmentSegmentPairs += nextHisto->segmentPairCount ;
									}
								else
									{
										tempInterCount += nextHisto->segmentPairCount ;
									}
							}
					}
			}
			
		if( theHistogramBundle->type == ONE_DIMENSIONAL )
			{
				if( fragmentSegmentsWereCounted == NO )
					{
						fragmentSegmentsWereCounted = YES ;
					}
				else
					{
						if( totalIntraFragmentSegments != tempIntraCount )
							{
								printf( "WARNING: INTRAFRAGMENT SEGMENTS DISAGREE (%d VS %d) FOR TAG %s\n",
									tempIntraCount, totalIntraFragmentSegments, [ tag cString ] ) ;
							}
							
						if( totalInterFragmentSegments != tempInterCount )
							{
								printf( "WARNING: INTERFRAGMENT SEGMENTS DISAGREE (%d VS %d) FOR TAG %s\n",
									tempInterCount, totalInterFragmentSegments, [ tag cString ] ) ;
							}
					}
			}
		else
			{
				if( fragmentSegmentPairsWereCounted == NO )
					{
						fragmentSegmentPairsWereCounted = YES ;
					}
				else
					{
						if( totalIntraFragmentSegmentPairs != tempIntraCount )
							{
								printf( "WARNING: INTRAFRAGMENT SEGMENT PAIRS DISAGREE (%d VS %d) FOR TAG %s\n",
									tempIntraCount, totalIntraFragmentSegmentPairs, [ tag cString ] ) ;
							}
							
						if( totalInterFragmentSegmentPairs != tempInterCount )
							{
								printf( "WARNING: INTERFRAGMENT SEGMENT PAIRS DISAGREE (%d VS %d) FOR TAG %s\n",
									tempInterCount, totalInterFragmentSegmentPairs, [ tag cString ] ) ;
							}
					}
			}
			
		
		return ;
	}


- (void) encodeWithCoder:(NSCoder *)coder
	{		
		if( identifier )
			{
				[ coder encodeObject:identifier ] ;
			}
		else
			{
				[ coder encodeObject:[ NSNull null ] ] ;
			}
			
		[ coder encodeObject:sourceTree ] ;
		
		// The "wereCounted" variables are not encoded as we assume they are YES at time
		// of coding
		
		[ coder encodeValueOfObjCType:@encode(int) at:&totalSegments ] ;
		[ coder encodeValueOfObjCType:@encode(int) at:&totalSegmentPairs ] ;
		[ coder encodeValueOfObjCType:@encode(int) at:&totalInterFragmentSegments ] ;
		[ coder encodeValueOfObjCType:@encode(int) at:&totalInterFragmentSegmentPairs ] ;
		[ coder encodeValueOfObjCType:@encode(int) at:&totalIntraFragmentSegments ] ;
		[ coder encodeValueOfObjCType:@encode(int) at:&totalIntraFragmentSegmentPairs ] ;
		
		
		[ coder encodeObject:histogramBundleForTag ] ;
		
		return ;
	}
	
- (id) initWithCoder:(NSCoder *)coder
	{
		self = [ super init ] ;
		
		identifier = [ coder decodeObject ] ;
		
		if( identifier == [ NSNull null ] )
			{
				identifier = nil ;
			}
		else
			{
				[ identifier retain ] ;
			}
			
		sourceTree = [ [ coder decodeObject ] retain ] ;
			
		segmentsWereCounted = YES ;
		segmentPairsWereCounted = YES ;
		
		fragmentSegmentsWereCounted = YES ;
		fragmentSegmentPairsWereCounted = YES ;
		

		[ coder decodeValueOfObjCType:@encode(int) at:&totalSegments ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&totalSegmentPairs ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&totalInterFragmentSegments ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&totalInterFragmentSegmentPairs ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&totalIntraFragmentSegments ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&totalIntraFragmentSegmentPairs ] ;
		
		histogramBundleForTag = [ [ coder decodeObject ] retain ] ;
		
		return self ;
	}

@end
