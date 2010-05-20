//
//  shapeSignatureX2.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "shapeSignatureX2.h"
#import "histogramGroup.h"
#import "histogramGroupBundle.h"
#import "hitListItem.h"
#import "fragment.h"

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
		
		
		
		histogramBundle *theHistogramBundle = [ [ histogramBundle alloc ]  initWithRayTrace:(rayTrace *)rt tag:(NSString *)tag 
			style:(histogramStyle)st  inSignature:self ] ;
				
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
		
		NSEnumerator *histogramBundleEnumerator = [ histogramBundleForTag objectEnumerator ] ;
		
		histogramBundle *nextBundle ;
		
		while( ( nextBundle = [ histogramBundleEnumerator nextObject ] ) )
			{
				nextBundle->sourceTree = sourceTree ;
				nextBundle->sourceSignature = self ;
			}
		
		return self ;
	}

+ (NSArray *) scoreQuerySignature:(X2Signature *)query againstTarget:(X2Signature *)target usingTag:(NSString *)tag 
					withCorrelation:(BOOL)useCor useFragments:(BOOL)useFrag fragmentGrouping:(BOOL)useGroups
					bigFragmentSize:(int)bigFSize maxBigFragmentCount:(int)maxBigFCount
	{
		// Critical method - compare two signatures and return an array of hit-list items
		
		// We return an array because in the case of fragment-based scoring we expect multiple mappings
		
		// We consider all possible intial mappings using a fragment of query and fragment of target as root
		
		NSLog( @"***SCORE %@ AGAINST %@ \n", query->sourceTree->treeName, target->sourceTree->treeName ) ;
		
		NSInteger compareHistoGroupPair( id hA, id hB, void *ctxt ) ;
		NSInteger compareMappingPair( id mA, id mB, void *ctxt ) ;
		
		X2SignatureMapping *theMapping ;
		hitListItem *theItem ;
		
		histogram *nextQueryHisto, *nextTargetHisto ;
		
		histogramBundle *queryBundle = [ query->histogramBundleForTag objectForKey:tag ] ;
		histogramBundle *targetBundle = [ target->histogramBundleForTag objectForKey:tag ] ;
		
		if( useFrag == NO )
			{
				// Need a set with all fragment indices
				
				NSMutableSet *allQueryFragmentIndices = [ NSMutableSet setWithCapacity:10 ] ;
				
				NSEnumerator *fragmentEnumerator = [ query->sourceTree->treeFragments objectEnumerator ] ;
				fragment *nextFragment ;
				
				while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
					{
						[ allQueryFragmentIndices addObject:[ NSString stringWithFormat:@"%d",nextFragment->index ] ] ;
					}
					
				NSMutableSet *allTargetFragmentIndices = [ NSMutableSet setWithCapacity:10 ] ;
				
				fragmentEnumerator = [ target->sourceTree->treeFragments objectEnumerator ] ;
				
				while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
					{
						[ allTargetFragmentIndices addObject:[ NSString stringWithFormat:@"%d",nextFragment->index ] ] ;
					}
				
				nextQueryHisto = [ queryBundle->sortedFragmentsToHistogram objectForKey:@"GLOBAL" ] ; 
				
				nextTargetHisto = [ targetBundle->sortedFragmentsToHistogram objectForKey:@"GLOBAL" ] ;
				
				// This is going to be a little slow, but I am sticking to the logic laid down. :-(
				
				histogramGroup *queryGroup = [ [ histogramGroup alloc ] 
					initWithHistograms:[ NSArray arrayWithObject:nextQueryHisto ] inBundle:queryBundle
						withFragmentIndices:allQueryFragmentIndices ] ;
					
				histogramGroupBundle *queryGroupBundle = [ [ histogramGroupBundle alloc ]
					initWithGroups:[ NSArray arrayWithObject:queryGroup ] inHistogramBundle:queryBundle ] ;
					
				histogramGroup *targetGroup = [ [ histogramGroup alloc ] 
					initWithHistograms:[ NSArray arrayWithObject:nextTargetHisto ] inBundle:targetBundle
						withFragmentIndices:allTargetFragmentIndices ] ;
					
				histogramGroupBundle *targetGroupBundle = [ [ histogramGroupBundle alloc ]
					initWithGroups:[ NSArray arrayWithObject:targetGroup ] inHistogramBundle:targetBundle ] ;
					
				theMapping = [ [ X2SignatureMapping alloc ] 
					initWithQuery:queryGroupBundle andTarget:targetGroupBundle ] ;
					
				[ theMapping  addMatchBetweenQueryHistoGroup:queryGroup andTargetHistoGroup:targetGroup ] ;
				
				theItem = [ [ hitListItem alloc ] initWithMapping:theMapping ] ;
				[ theMapping release ] ;
				
				[ theItem addScoresWithCorrelation:useCor ] ;
				
				NSArray *returnArray = [ [ NSArray alloc ] initWithObjects:theItem,nil ] ;
				[ theItem release ] ;
				
				return returnArray ;
			}
		else
			{
				NSArray *queryGroupBundles = [ histogramGroupBundle 
					allGroupBundlesFromHistogramBundle:queryBundle useGroups:useGroups
					bigFragmentSize:bigFSize maxBigFragmentCount:maxBigFCount ] ;
					
				NSArray *targetGroupBundles = [ histogramGroupBundle 
					allGroupBundlesFromHistogramBundle:targetBundle useGroups:useGroups
					bigFragmentSize:bigFSize maxBigFragmentCount:maxBigFCount ] ;
					
				NSEnumerator *queryGroupBundleEnumerator = 
					[ queryGroupBundles objectEnumerator ] ;
				
				NSEnumerator *targetGroupBundleEnumerator ;
				
				NSMutableArray *returnArray = [ [ NSMutableArray alloc ] initWithCapacity:50 ] ;
				
				NSMutableArray *accumMappings = [ [ NSMutableArray alloc ] initWithCapacity:50 ] ;
				
				histogramGroupBundle *nextQueryGroupBundle, *nextTargetGroupBundle ;
				
				while( ( nextQueryGroupBundle = [ queryGroupBundleEnumerator nextObject ] ) )
					{
						targetGroupBundleEnumerator = 
							[ targetGroupBundles objectEnumerator ] ;
						
						while( ( nextTargetGroupBundle = [ targetGroupBundleEnumerator nextObject ] ) )
							{
							
								// Need to make all possible initial mappings where the a histo group of the 
								// query is mapped to any histo group of the target. Necessary to do this as some
								// optimal mappings may NOT include a particular group
								
								NSEnumerator *queryHistoGroupEnumerator = 
									[ nextQueryGroupBundle->memberGroups objectEnumerator ] ;
									
								NSEnumerator *targetHistoGroupEnumerator ;
								
								histogramGroup *nextQueryHistoGroup, *nextTargetHistoGroup ;
								
								while( ( nextQueryHistoGroup = [ queryHistoGroupEnumerator nextObject ] ) )
									{
										targetHistoGroupEnumerator = [ nextTargetGroupBundle->memberGroups objectEnumerator ] ;
										
										while( ( nextTargetHistoGroup = [ targetHistoGroupEnumerator nextObject ] ) )
											{
												theMapping = [ [ X2SignatureMapping alloc ] 
													initWithQuery:nextQueryGroupBundle andTarget:nextTargetGroupBundle  ] ;
													
												[ theMapping  addMatchBetweenQueryHistoGroup:nextQueryHistoGroup
													andTargetHistoGroup:nextTargetHistoGroup ] ;
								
												NSMutableArray *mappings = [ [ NSMutableArray alloc ] initWithObjects:theMapping,nil ] ;
												[ theMapping release ] ;
								
												mappings = [ X2SignatureMapping expandMappings:mappings ] ;
								
												[ accumMappings addObjectsFromArray:mappings ] ;
								
												[ mappings release ] ;
											}
									}
									
							}
					}
								
				// Sort the histoGroup pairs in each mapping
				
				NSEnumerator *mappingEnumerator = [ accumMappings objectEnumerator ] ;
				X2SignatureMapping *nextMapping ;
				

				while( ( nextMapping = [ mappingEnumerator nextObject ] ) )
					{
						//NSLog( @"Next Mapping before sort:" ) ;
						//NSLog( @"%@", [ nextMapping description ] ) ;
						[ nextMapping->histoGroupPairs sortUsingFunction:compareHistoGroupPair context:nil ] ;
						//NSLog( @"After Mapping of group pairs:" ) ;
						//NSLog( @"%@", [ nextMapping description ] ) ;
					}
					

				// Now that histo pairs are sorted WITHIN mappings, sort the mappings
				
				[ accumMappings sortUsingFunction:compareMappingPair context:nil ] ;
				
				//NSLog( @"**MAPPINGS AFTER MAPPING SORT:" ) ;
				
				//NSLog( @"%@", [ accumMappings description ] ) ;
				
				// Remove duplicates - 
				
				int j = 0 ;
				
				while( j < [ accumMappings count ] )
					{
						X2SignatureMapping *jMapping =  [ accumMappings objectAtIndex:j ] ;
						
						int k = j + 1 ; 
						
						
						while( k < [ accumMappings count ] )
							{
								if( [ jMapping isEqualToMapping:[ accumMappings objectAtIndex:k ] ] )
									{
										[ accumMappings removeObjectAtIndex:k ] ;
										continue ;
									}
								//else
								//	{
								//		break ;
								//	}
									
								++k ;
							}
							
						++j ;
					}
				  
				
				// Convert mappings into scored hitListItems
				
				mappingEnumerator = [ accumMappings objectEnumerator ] ;
				
				while( ( nextMapping = [ mappingEnumerator nextObject ] ) )
					{
						theItem = [ [ hitListItem alloc ] initWithMapping:nextMapping ] ;
						[ theItem addScoresWithCorrelation:useCor ] ;
						
						[ returnArray addObject:theItem ] ;
						[ theItem release ] ;
					}
					
				return returnArray ;
			}
					
				
			
		return nil ;
	}
	
NSInteger compareHistoGroupPair( id pairA, id pairB, void *ctxt )
	{
		NSInteger indexCompare2( id , id , void * ) ;
		
		NSArray *arrayA = pairA ;
		NSArray *arrayB = pairB ;
		
		histogramGroup *hA = [ arrayA objectAtIndex:0 ] ;
		histogramGroup *hB = [ arrayB objectAtIndex:0 ] ;
		
		// First check number of fragment indices in each group
		
		if( [ hA->groupFragmentIndices count ] <  [ hB->groupFragmentIndices count ] )
			{
				return NSOrderedAscending ;
			}
		else if( [ hA->groupFragmentIndices count ] > [ hB->groupFragmentIndices count ] )
			{
				return NSOrderedDescending ;
			}
			
		// Check sorted fragment indices
		
		NSMutableArray *sortedAIndices = [ NSMutableArray arrayWithArray:[ hA->groupFragmentIndices allObjects ] ] ;
		
		[ sortedAIndices sortUsingFunction:indexCompare2 context:nil ] ;
		
		NSMutableArray *sortedBIndices = [ NSMutableArray arrayWithArray:[ hB->groupFragmentIndices allObjects ] ] ;
		
		[ sortedBIndices sortUsingFunction:indexCompare2 context:nil ] ;
		
		int k ;
		
		for( k = 0 ; k < [ sortedAIndices count ] ; ++k )
			{
				if( [ [ sortedAIndices objectAtIndex:k ] intValue ] < 
					[ [ sortedBIndices objectAtIndex:k ] intValue ] )
					{
						return NSOrderedAscending ;
					}
				else if( [ [ sortedAIndices objectAtIndex:k ] intValue ] > 
					[ [ sortedBIndices objectAtIndex:k ] intValue ] )
					{
						return NSOrderedDescending ;
					}
			}
			
		// Everything same for A, B, now check C, D 
		
		histogramGroup *hC = [ arrayA objectAtIndex:1 ] ;
		histogramGroup *hD = [ arrayB objectAtIndex:1 ] ;
		
		if( [ hC->groupFragmentIndices count ] <  [ hD->groupFragmentIndices count ] )
			{
				return NSOrderedAscending ;
			}
		else if( [ hC->groupFragmentIndices count ] > [ hD->groupFragmentIndices count ] )
			{
				return NSOrderedDescending ;
			}
			
		// Check sorted fragment indices
		
		NSMutableArray *sortedCIndices = [ NSMutableArray arrayWithArray:[ hC->groupFragmentIndices allObjects ] ] ;
		
		[ sortedCIndices sortUsingFunction:indexCompare2 context:nil ] ;
		
		NSMutableArray *sortedDIndices = [ NSMutableArray arrayWithArray:[ hD->groupFragmentIndices allObjects ] ] ;
		
		[ sortedDIndices sortUsingFunction:indexCompare2 context:nil ] ;
		
		for( k = 0 ; k < [ sortedCIndices count ] ; ++k )
			{
				if( [ [ sortedCIndices objectAtIndex:k ] intValue ] < 
					[ [ sortedDIndices objectAtIndex:k ] intValue ] )
					{
						return NSOrderedAscending ;
					}
				else if( [ [ sortedCIndices objectAtIndex:k ] intValue ] > 
					[ [ sortedDIndices objectAtIndex:k ] intValue ] )
					{
						return NSOrderedDescending ;
					}
			}

		// All checks match - these must be identical
			
		return NSOrderedSame ;
	}
	
NSInteger indexCompare2( id A, id B, void *ctxt )
	{
		NSString *sA = (NSString *) A ;
		NSString *sB = (NSString *) B ;
		
		if( [ sA intValue ] < [ sB intValue ] )
			{
				return NSOrderedAscending ;
			}
		else if( [ sA intValue ] > [ sB intValue ] )
			{
				return NSOrderedDescending ;
			}
			
		return NSOrderedSame ;
	}

- (NSString *) propertyListDict
	{
		// This method expresses an XSignature in text format as a property list. This is 
		// a portable alternative to archiving using NSCoder, and which we can also use 
		// in web service implementation
		
		NSMutableDictionary *returnDictionary = [ NSMutableDictionary dictionaryWithCapacity:10 ] ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&totalSegments length:sizeof(int) ] forKey:@"totalSegments" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&totalSegmentPairs length:sizeof(int) ] forKey:@"totalSegmentPairs" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&totalInterFragmentSegments length:sizeof(int) ] forKey:@"totalInterFragmentSegments" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&totalInterFragmentSegmentPairs length:sizeof(int) ] forKey:@"totalInterFragmentSegmentPairs" ] ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&totalIntraFragmentSegments length:sizeof(int) ] forKey:@"totalIntraFragmentSegments" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&totalIntraFragmentSegmentPairs length:sizeof(int) ] forKey:@"totalIntraFragmentSegmentPairs" ]  ;
		
		[ returnDictionary  setObject:[ sourceTree propertyListDict ]  forKey:@"sourceTreePList" ] ;
		
		NSMutableDictionary *histogramBundlePropListForTag = [ NSMutableDictionary 
			dictionaryWithCapacity:[ histogramBundleForTag count ] ] ;
			
		NSEnumerator *tagEnumerator = [ [ histogramBundleForTag allKeys ] objectEnumerator ] ;
		
		NSString *nextTag ;
		
		while( ( nextTag = [ tagEnumerator nextObject ] ) )
			{
				[ histogramBundlePropListForTag setObject:[ [ histogramBundleForTag objectForKey:nextTag ] propertyListDict ]
					forKey:nextTag ] ;
			}
			
		[ returnDictionary  setObject:histogramBundlePropListForTag forKey:@"histogramBundlePropListForTag" ] ;
		
		return returnDictionary ;
		
		NSString *error ;
		
		NSData *theData = [ NSPropertyListSerialization dataFromPropertyList:returnDictionary
                            format:NSPropertyListXMLFormat_v1_0
                            errorDescription:&error] ;
							
		if( ! theData )
			{
				printf( "WARNING: COULD NOT PRODUCE PROPERTY LIST REPRESENTATION OF X2Signature - %s\n",
					[ error cString ] ) ;
				return nil ;
			}
		
		return [ [ NSString alloc ] initWithData:theData encoding:NSASCIIStringEncoding ] ;
		//return theData ;
	}
	
- (id) initWithPropertyListDict:(NSDictionary *)sourceDictionary
	{
		self = [ super init ] ;
		
		//NSData *pListAsData = [ pList dataUsingEncoding:NSASCIIStringEncoding  ] ;
		
		//NSString *errorString ;
		//NSPropertyListFormat theFormat ;
		
		//NSDictionary *sourceDictionary = [ NSPropertyListSerialization propertyListFromData:pListAsData mutabilityOption:0 format:&theFormat 
		//	errorDescription:&errorString ] ;

			
		NSData *theData ;
			
		theData = [ sourceDictionary objectForKey:@"totalSegments" ] ;
		[ theData getBytes:&totalSegments length:sizeof(int) ] ;
		theData = [ sourceDictionary objectForKey:@"totalSegmentPairs" ] ;
		[ theData getBytes:&totalSegmentPairs length:sizeof(int) ] ;
		theData = [ sourceDictionary objectForKey:@"totalInterFragmentSegments" ] ;
		[ theData getBytes:&totalInterFragmentSegments length:sizeof(int) ] ;
		theData = [ sourceDictionary objectForKey:@"totalInterFragmentSegmentPairs" ] ;
		[ theData getBytes:&totalInterFragmentSegmentPairs length:sizeof(int) ] ;
		theData = [ sourceDictionary objectForKey:@"totalIntraFragmentSegments" ] ;
		[ theData getBytes:&totalIntraFragmentSegments length:sizeof(int) ] ;
		theData = [ sourceDictionary objectForKey:@"totalIntraFragmentSegmentPairs" ] ;
		[ theData getBytes:&totalIntraFragmentSegmentPairs length:sizeof(int) ] ;
			
			
			
		NSDictionary *pListDict = [ sourceDictionary objectForKey:@"sourceTreePList" ] ;
		
		sourceTree = [ [ ctTree alloc ] initWithPropertyListDict:pListDict ] ;
		
		// Histogram bundles
		
		
		
		NSDictionary *histogramBundlePropListForTag = [ sourceDictionary objectForKey:@"histogramBundlePropListForTag" ] ;
		
		histogramBundleForTag = [ [ NSMutableDictionary alloc ] initWithCapacity:[ histogramBundlePropListForTag count ] ] ;
		
		NSEnumerator *tagEnumerator = [ [ histogramBundlePropListForTag allKeys ] objectEnumerator ] ;
		
		NSString *nextTag ;
		
		while( ( nextTag = [ tagEnumerator nextObject ] ) )
			{
				NSDictionary *nextPropListDict = [ histogramBundlePropListForTag objectForKey:nextTag ] ;
				
				histogramBundle *nextHistoBundle = [ [ histogramBundle alloc ] 
					initWithPropertyListDict:nextPropListDict ] ;
					
				nextHistoBundle->sourceTree = sourceTree ;
				nextHistoBundle->sourceSignature = self ;
				
				[ histogramBundleForTag setObject:nextHistoBundle forKey:nextTag ] ;
			}
				
				
		
		return self ;
	
		
				
	}

								
NSInteger compareMappingPair( id A, id B, void *ctxt )
	{
		// Really simple - more histopairs take precendence over fewer, 
		// if identical that use histo pair comparison already in place
		
		X2SignatureMapping *mapA = (X2SignatureMapping *) A ;
		X2SignatureMapping *mapB = (X2SignatureMapping *) B ;
		
		if( [ mapA->histoGroupPairs count ] < [ mapB->histoGroupPairs count ] )
			{
				return NSOrderedAscending ;
			}
		else if( [ mapA->histoGroupPairs count ] > [ mapB->histoGroupPairs count ] )
			{
				return NSOrderedDescending ;
			}
		else
			{
				// Move to histogroup group pair comparison
				
				int j ;
				
				for( j = 0 ; j < [ mapA->histoGroupPairs count ] ; ++j )
					{
						NSArray *pairA = [ mapA->histoGroupPairs objectAtIndex:j ] ;
						NSArray *pairB = [ mapB->histoGroupPairs objectAtIndex:j ] ;
						
						NSComparisonResult order = compareHistoGroupPair(pairA, pairB, nil ) ;
						
						if( order != NSOrderedSame ) return order ;
					}
				
			}
			
		return NSOrderedSame ;
	}
		


@end
