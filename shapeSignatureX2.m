//
//  shapeSignatureX2.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "shapeSignatureX2.h"


@implementation shapeSignatureX2

+ (void) initialize
	{
		version = [ [ NSString stringWithString:@"ShapeSignatures v. X2.0" ] retain ] ;
		
		return ;
	}
	
+ (NSString *) version
	{
		return version ;
	}

- (id) initUsingTree:(ctTree *)tree forTag:(NSString *)tag andRayTrace:(rayTrace *)rt 
			withStyle:(histogramStyle)st
	{
		self = [ super init ] ;
		
		totalSegments = 0 ;	    // For 1D histos
		totalSegmentPairs = 0 ; // For 2D histos
		
		totalInterFragmentSegments = 0 ;	// 1D fragments
		totalInterFragmentSegmentPairs = 0 ;	// 2D fragments
	
		segmentsCounted = NO ;
		
		// Histogram bundle dictionary
		
		histogramBundleForTag = [ [ NSMutableDictionary alloc ] 
			initWithCapacity:[ [ histogram tagDescriptions ] count ] ] ;
		
		sourceTree = tree ;
		
		// Add ID if we like - the source tree has a name. 
		
		identifier = nil ;
		
		[ self addHistogramsWithTag:tag forRayTrace:rt withStyle:st ] ;
		
				 
		
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
			
		// Make the histrograms, add the bundle to our dictionary
		
		
		
		histogramBundle *theHistogramBundle = [ [ histogramBundle alloc ]  initWithRayTrace:(rayTrace *)rt tag:(NSString *)tag style:(histogramStyle)st  ] ;
				
		if( ! theHistogramBundle )
			{
				printf( "HISTOGRAM FAILURE FOR TAG %s , BUNDLE NOT ADDED!\n", [ tag cString ] ) ;
				return ;
			}
			
		[ histogramBundleForTag setObject:theHistogramBundle forKey:tag ] ;
			
		// THE STUFF BELOW NEEDS CHANGED!!!
		
		if ( segmentsCounted == NO )
			{
				totalSegments = globalHisto->segmentCount ;
			}
		
				
		// Add to our dictionary (just one item)
		
		[ globalHistogramsByTagRoot setObject:[ NSArray arrayWithObject:globalHisto ] 
			forKey:root ] ;
			
		[ globalHisto release ] ;
			
		// Make the fragment histograms
		
		NSString *fragmentTag = [ [ root stringByAppendingString:@"FRAGMENT" ] uppercaseString ] ;
		int iFragment ;
		
		// Make sure that the tag is available 
		
		if( [ histogram tagAvailable:fragmentTag ] == NO )
			{
				printf( "TAG %s NOT AVAILABLE, NOT ADDED!\n", [ fragmentTag cString ]  ) ;
				return ;
			}
		
		NSMutableArray *tempArray = [ [ NSMutableArray alloc ] initWithCapacity:5 ] ;
		
		int totalIntraFragmentSegmentsTmp = 0 ;
		
		for( iFragment = 1 ; iFragment <= sourceTree->nFragments ; ++iFragment )
			{
				histogram *fragmentHisto = [ [ histogram alloc ] initWithRayTrace:rt tag:fragmentTag 
					style:st fragment:iFragment ] ;
				
				if( ! fragmentHisto )
					{
						printf( "HISTOGRAM FAILURE FOR FRAGMENT TAG %s , NOT ADDED!\n", [ fragmentTag cString ] ) ;
						return  ;
					}
					
				[ tempArray addObject:fragmentHisto ] ;
				
				[ fragmentHisto release ] ;
				
				totalIntraFragmentSegmentsTmp += fragmentHisto->segmentCount ;
			}
			
		[ fragmentHistogramsByTagRoot setObject:[ NSArray arrayWithArray:tempArray ] 
			forKey:root ] ;
	
		if( segmentsCounted == NO )
			{
				totalIntraFragmentSegments = totalIntraFragmentSegmentsTmp ;
				segmentsCounted = YES ;
			}
		
		// Determine connections between fragments
		
		// Do this simply, by enumerating the bonds and looking for fragment-fragment connections
		
		int iBond ;
		
		for( iBond = 0 ; iBond < sourceTree->nBonds ; ++iBond )
			{
				int fragIndex1 = sourceTree->bonds[iBond]->node1->fragmentIndex ;
				int fragIndex2 = sourceTree->bonds[iBond]->node2->fragmentIndex ;
				
				 // Convert to indices in tempArray
				 
				 histogram *histo1 = [ tempArray objectAtIndex:(fragIndex1 - 1) ] ;
				 histogram *histo2 = [ tempArray objectAtIndex:(fragIndex2 - 1) ] ;
				 
				 [ histo1 addConnectionToHistogram:histo2 ] ;
				 [ histo2 addConnectionToHistogram:histo1 ] ;
			}
			
		[ tempArray release ] ;
		
		return ;
	}

@end
