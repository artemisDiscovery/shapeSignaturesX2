//
//  histogramGroupBundle.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "histogramGroupBundle.h"
#import "fragmentConnection.h"
#include <math.h>


@implementation histogramGroupBundle

- (id) initWithGroups:(NSArray *)grps inHistogramBundle:(histogramBundle *)hBundle
	{
		// The actions here are to init array of member groups and set up connections between
		// them based on histogram memberships in the groups and connections between associated fragments 
		// in the source connect tree 
		
		memberGroups = [ [ NSMutableArray alloc ] initWithArray:grps ] ;
		
		
		hostBundle = hBundle ;
		
		
		int j, k ;
		
		for( j = 0 ; j < [ memberGroups count ] - 1 ; ++j )
			{
				histogramGroup *jGroup = [ memberGroups objectAtIndex:j ] ;
				
				for( k = j + 1 ; k < [ memberGroups count ] ; ++k )
					{
						histogramGroup *kGroup = [ memberGroups objectAtIndex:k ] ;
						
						// Two groups neighbor each other if the neighborFragmentIndices set
						// of one intersect the groupFragmentIndicesSet of the other. 
						
						if( [ jGroup->groupFragmentIndices 
							intersectsSet:kGroup->neighborFragmentIndices ] == YES )
							{
								// Test other way (sanity)
								
								if( [ kGroup->groupFragmentIndices 
									intersectsSet:jGroup->neighborFragmentIndices ] == NO )
									{
										printf( "BROKEN NEIGHBOR RELATIONSHIP BETWEEN GROUPS!\n" ) ;
										return nil ;
									}
									
								[ jGroup addConnectionTo:kGroup ] ;
								[ kGroup addConnectionTo:jGroup ] ;
							}
					}
			}
			
			
		return self ;
	}
	
- (void) dealloc
	{
		[ memberGroups release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}
			
		
+ (NSArray *) allGroupBundlesFromHistogramBundle:(histogramBundle *)hBundle useGroups:(BOOL)useGroups 
				bigFragmentSize:(int)bigFSize maxBigFragmentCount:(int)maxBigFCount
	{
		// Strategy - for each possible set of fragmentConnection "activations", assemble
		// groups 
		
		NSArray *connections = hBundle->sourceTree->fragmentConnections ;
		
		// Make sure connections are clear
		
		NSEnumerator *connectionEnumerator = [ connections objectEnumerator ] ;
				
		fragmentConnection *nextConnection ;
		
		while( ( nextConnection = [ connectionEnumerator nextObject ] ) )
			{
				nextConnection->active = NO ;
			}
		
		NSMutableArray *groupBundles = [ [ NSMutableArray alloc ] 
			initWithCapacity:pow( [ connections count ], 2 ) ] ; 
			
		NSMutableArray *groupsToBundle = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		NSMutableArray *fragmentSets = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		NSMutableArray *fragmentSetsToRemove = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		NSMutableSet *collectFragmentSet = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
		
		NSMutableArray *activeConnections = [ [ NSMutableArray alloc ] 
			initWithCapacity:[ connections count ] ] ;
			
		NSMutableSet *allFragments = [ [ NSMutableSet alloc ] 
					initWithCapacity:[ hBundle->sourceTree->treeFragments count ] ] ;
		
		NSMutableArray *histogramsToGroup = [ [ NSMutableArray alloc ]
					initWithCapacity:10 ] ;
					
		NSMutableSet *fragmentSetIndices = [ [ NSMutableSet alloc ] initWithCapacity:3 ] ;
		
		do
			{
				// Use current connections to generate group bundle 
				
				[ fragmentSets removeAllObjects ] ;
				[ fragmentSetsToRemove removeAllObjects ] ;
				[ groupsToBundle removeAllObjects ] ;
				[ activeConnections removeAllObjects ] ;
				[ allFragments removeAllObjects ] ;
				
				NSEnumerator *connectionEnumerator = [ connections objectEnumerator ] ;
				
				fragmentConnection *nextConnection ;
				
				while( ( nextConnection = [ connectionEnumerator nextObject ] ) )
					{
						if( nextConnection->active == YES )
							{
								[ activeConnections addObject:nextConnection ] ;
							}
					}
				
				[ allFragments addObjectsFromArray:hBundle->sourceTree->treeFragments ] ;
				
				// Process each active connection. If a connection involves a fragment in a set 
				// already collected, then add its linked members to that set; otherwise, initiate 
				// a new set 
				
				// Set a warning flag if the process of assembly makes a fragment with heavy 
				// atom count > fSizeLim 
				
				
				NSEnumerator *activeConnectionEnumerator = [ activeConnections objectEnumerator ] ;
				
				fragmentConnection *nextActiveConnection ;
				
				while( ( nextActiveConnection = [ activeConnectionEnumerator nextObject ] ) )
					{
						[ collectFragmentSet removeAllObjects ] ;
						[ fragmentSetsToRemove removeAllObjects ] ;
						
						[ collectFragmentSet unionSet:[ nextActiveConnection linkedFragments ] ] ;
						
						NSEnumerator *fragmentSetEnumerator = [ fragmentSets objectEnumerator ] ;
						
						NSMutableSet *nextFragmentSet ;
						
						while( ( nextFragmentSet = [ fragmentSetEnumerator nextObject ] ) )
							{
								if( [ nextFragmentSet intersectsSet:collectFragmentSet ] == YES )
									{	
										
										[ collectFragmentSet unionSet:nextFragmentSet ] ;
										[ fragmentSetsToRemove addObject:nextFragmentSet ] ;
										
									}
							}
							
						[ fragmentSets addObject:[ NSMutableSet setWithSet:collectFragmentSet ] ] ;
							
						[ allFragments minusSet:[ nextActiveConnection linkedFragments ] ] ;
						
						[ fragmentSets removeObjectsInArray:fragmentSetsToRemove ] ;
					}
					
			
					
				// Any fragments left over will be added as singleton sets
						
				NSEnumerator *remainingFragmentsEnumerator = [ allFragments objectEnumerator ] ;
				
				fragment *nextFragment ;
				
				while( ( nextFragment = [ remainingFragmentsEnumerator nextObject ] ) )
					{
						[ fragmentSets addObject:[ NSMutableSet setWithObject:nextFragment ] ] ;
					}
					
				
				// Sanity check - should not have all fragments included together, ever
				
				if( [ fragmentSets count ] == 1 )
					{
						NSMutableSet *testSet = [ NSMutableSet setWithArray:hBundle->sourceTree->treeFragments ] ;
						
						[ testSet minusSet:[ fragmentSets lastObject ] ] ;
						
						if( [ testSet count ] == 0 )
							{
								//printf( "WARNING: SINGLE GROUP WITH ALL FRAGMENTS INCLUDED!\n" ) ;
							}
					}
				
				// Sanity check - should never have a fragment in more than one fragmentSet
				// i.e. the intersection of any two fragment sets should be empty
				
				int j, k ;
				
				for( j = 0 ; j < [ fragmentSets count ] - 1 ; ++j )
					{
						for( k = j + 1 ; k < [ fragmentSets count ] ; ++k )
							{
								if( [ [ fragmentSets objectAtIndex:j ] intersectsSet:[ fragmentSets objectAtIndex:k ] ]
										== YES )
									{
										printf( "WARNING: TWO FRAGMENT SETS INTERSECT!\n" ) ;
									}
							}
					}
					
				// If fragment size limit is in play, skip any mapping if "big" fragment
				// count in any group is > maxCount limit
				
				NSEnumerator *fragmentSetEnumerator ;
				NSSet *nextFragmentSet ;
				NSEnumerator *fragmentEnumerator ;
				
				if( maxBigFCount > 0 )
					{
						BOOL hadViolation = NO ;
						
						fragmentSetEnumerator = [ fragmentSets objectEnumerator ] ;
						
						while( ( nextFragmentSet = [ fragmentSetEnumerator nextObject ] ) )
							{
								if( [ nextFragmentSet count ] == 1 ) continue ;
								
								fragmentEnumerator = [ nextFragmentSet objectEnumerator ] ;
								
								int bigFragmentCount = 0 ;
								
								while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
									{
										if( [ nextFragment heavyAtomCount ] > bigFSize ) ++bigFragmentCount ;
									}
									
								if( bigFragmentCount > maxBigFCount ) 
									{
										hadViolation = YES ;
										break ;
									}
							}
							
						if( hadViolation == YES )
							{
								// Simply move onto the next state
								
								continue ;
							}
					}
								
								

				// Now create histogram groups from each fragment set
				//
				// We need to collect all histograms compatible with the fragment indices implicated 
				// by the fragment set
				
				fragmentSetEnumerator = [ fragmentSets objectEnumerator ] ;
								
				BOOL hadEmptyGroup = NO ;
				
				while( ( nextFragmentSet = [ fragmentSetEnumerator nextObject ] ) )
					{
						[ histogramsToGroup removeAllObjects ] ;
						[ fragmentSetIndices removeAllObjects ] ;
						
						fragmentEnumerator = [ nextFragmentSet objectEnumerator ] ;
						
						while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
							{
								[ fragmentSetIndices 
									addObject:[ NSString stringWithFormat:@"%d",nextFragment->index ] ] ;
							}
							
						// Enumerate all histograms in bundle, retain those whose indices are contained
						// in the current set of fragment indices
						
						NSEnumerator *histogramEnumerator = 
							[ hBundle->sortedFragmentsToHistogram objectEnumerator ] ;
							
						histogram *nextHistogram ;
						
						while( ( nextHistogram = [ histogramEnumerator nextObject ] ) )
							{
								if( [ nextHistogram->sortedFragmentKey isEqualToString:@"GLOBAL" ] == YES ) continue ;
								
								NSSet *nextIndexSet = 
									[ NSSet setWithArray:[ nextHistogram->sortedFragmentKey componentsSeparatedByString:@"_" ] ] ;
								
								if( [ nextIndexSet isSubsetOfSet:fragmentSetIndices ] == YES )
									{
										[ histogramsToGroup addObject:nextHistogram ] ;
									}
							}
							
						// Make the group
						
						if( [ histogramsToGroup count ] == 0 )
							{
								hadEmptyGroup = YES ;
								// continue ;
							}
						
						histogramGroup *nextGroup = [ [ histogramGroup alloc ] initWithHistograms:histogramsToGroup 
							inBundle:hBundle withFragmentIndices:fragmentSetIndices ] ;
							
						[ groupsToBundle addObject:nextGroup ] ;
						// From static analyzer
						[ nextGroup release ] ;
					}
					
				if( hadEmptyGroup == YES )
					{
						// Skip this bundle
						
						// continue ;
					}
					
				// Have all the histogram groups, make the group bundle
				
				histogramGroupBundle *nextBundle = [ [ histogramGroupBundle alloc ]
					initWithGroups:groupsToBundle inHistogramBundle:hBundle ] ;
					
				if( ! nextBundle )
					{
						printf( "ERROR - skipping this grouping\n" ) ;
						continue ;
					}
				
				[ groupBundles addObject:nextBundle ] ;
				[ nextBundle release ] ;
				
				// if we are NOT using groups, exit at this point - first pass through this loop has 
				// all fragment connections turned off, and now we are finished!
				
				if( useGroups == NO ) break ;
					
			} while( [ histogramGroupBundle advance:connections ] == YES ) ;
			
		[ groupsToBundle release ] ;
		[ fragmentSets release ] ;
		[ activeConnections release ] ;
		[ allFragments release ] ;
		[ histogramsToGroup release ] ;
		[ fragmentSetIndices release ] ;
		
		[ fragmentSetsToRemove release ] ;
		[ collectFragmentSet release ] ;
		
		return groupBundles ;
		

			
	}
	
	
+ (BOOL) advance:(NSArray *)conn 
	{
		// This utility method takes an array of connection objects and performs a "binary advance" - 
		// Let the state of each connection (active/inactive) be represented [ s1, s2, ..., sN ] , 
		// where sJ = 0/1 . Then this function converts [ 0, 0, 1, 1 ] to [ 0, 1, 0, 0 ] (returning YES) 
		// and [ 1, 1, 1, 1 ] to [ 0, 0, 0, 0 ] (returning NO for rollover detection ) 
		
		// Since this is only used for fragment-based scoring, we will disallow all fragment connections turned
		// on - if that is detected we will not advance and will return NO . 
		
		int j ;
		
		for( j = [ conn count ] - 1  ; j >= 0 ; --j )
			{
				fragmentConnection *thisConnect = [ conn objectAtIndex:j ] ;
				
				if( thisConnect->active == NO )
					{
						thisConnect->active = YES ;
						break ;
					}
				else
					{
						thisConnect->active = NO ;
						continue ;
					}
			}
			
		if( j < 0 ) return NO ; // Wrap-around - should no longer have this condition
			
		BOOL allActive = YES ;
		
		for( j = 0 ; j < [ conn count ] ; ++j )
			{
				fragmentConnection *thisConnect = [ conn objectAtIndex:j ] ;
				
				if( thisConnect->active == NO )
					{
						allActive = NO ;
						break ;
					}
			}
			
		if( allActive == YES ) 
			{
				return NO ;
			}
		
		return YES ;
	}
		
		
		
		
			
		
				
				
					
				
					
						
						
							
						
						
						
						
						
				
				
				
				
				
				
				
					
				
					
				
				
				
				
				
				
				
				
				
		
		
		

							
						
						
		
		
		
		
@end
