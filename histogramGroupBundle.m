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
		
		memberGroups = [ [ NSArray alloc ] initWithArray:grps ] ;
		
		
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
			
		
+ (NSArray *) allGroupBundlesFromHistogramBundle:(histogramBundle *)hBundle 
	{
		// Strategy - for each possible set of fragmentConnection "activations", assemble
		// groups 
		
		NSArray *connections = hBundle->sourceTree->fragmentConnections ;
		
		NSMutableArray *groupBundles = [ [ NSMutableArray alloc ] 
			initWithCapacity:pow( [ connections count ], 2 ) ] ; 
			
		NSMutableArray *groupsToBundle = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		NSMutableArray *fragmentSets = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		
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
				
				NSEnumerator *activeConnectionEnumerator = [ activeConnections objectEnumerator ] ;
				
				fragmentConnection *nextActiveConnection ;
				
				while( ( nextActiveConnection = [ activeConnectionEnumerator nextObject ] ) )
					{
						NSSet *theFragments = [ nextActiveConnection linkedFragments ] ;
						
						NSEnumerator *fragmentSetEnumerator = [ fragmentSets objectEnumerator ] ;
						
						NSMutableSet *nextFragmentSet ;
						
						BOOL didAMerge = NO ;
						
						while( ( nextFragmentSet = [ fragmentSetEnumerator nextObject ] ) )
							{
								if( [ nextFragmentSet intersectsSet:theFragments ] == YES )
									{	
										didAMerge = YES ;
										
										[ nextFragmentSet unionSet:theFragments ] ;
										
										[ allFragments minusSet:theFragments ] ;
									}
							}
							
						if( didAMerge == NO )
							{
								// Make a new set with the linked fragments
								
								[ fragmentSets addObject:[ NSMutableSet setWithSet:theFragments ] ] ;
								[ allFragments minusSet:theFragments ] ;
							}
					}
					
				// Any fragments left over will be added as singleton sets
						
				NSEnumerator *remainingFragmentsEnumerator = [ allFragments objectEnumerator ] ;
				
				fragment *nextFragment ;
				
				while( ( nextFragment = [ remainingFragmentsEnumerator nextObject ] ) )
					{
						[ fragmentSets addObject:[ NSMutableSet setWithObject:nextFragment ] ] ;
					}
					
				// Now create histogram groups from each fragment set
				//
				// We need to collect all histograms compatible with the fragment indices implicated 
				// by the fragment set
				
				NSEnumerator *fragmentSetEnumerator = [ fragmentSets objectEnumerator ] ;
				
				NSSet *nextFragmentSet ;
				
				
				
				while( ( nextFragmentSet = [ fragmentSetEnumerator nextObject ] ) )
					{
						[ histogramsToGroup removeAllObjects ] ;
						[ fragmentSetIndices removeAllObjects ] ;
						
						NSEnumerator *fragmentEnumerator = [ nextFragmentSet objectEnumerator ] ;
						
						fragment *nextFragment ;
						
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
						
						histogramGroup *nextGroup = [ [ histogramGroup alloc ] initWithHistograms:histogramsToGroup 
							inBundle:hBundle ] ;
							
						[ groupsToBundle addObject:nextGroup ] ;
					}
					
				// Have all the histogram groups, make the group bundle
				
				histogramGroupBundle *nextBundle = [ [ histogramGroupBundle alloc ]
					initWithGroups:groupsToBundle inHistogramBundle:hBundle ] ;
				
				[ groupBundles addObject:nextBundle ] ;
				[ nextBundle release ] ;
					
			} while( [ histogramGroupBundle advance:connections ] == YES ) ;
			
		[ groupsToBundle release ] ;
		[ fragmentSets release ] ;
		[ activeConnections release ] ;
		[ allFragments release ] ;
		[ histogramsToGroup release ] ;
		[ fragmentSetIndices release ] ;
		
		return groupBundles ;
		

			
	}
	
	
+ (BOOL) advance:(NSArray *)conn 
	{
		// This utility method takes an array of connection objects and performs a "binary advance" - 
		// Let the state of each connection (active/inactive) be represented [ s1, s2, ..., sN ] , 
		// where sJ = 0/1 . Then this function converts [ 0, 0, 1, 1 ] to [ 0, 1, 0, 0 ] (returning YES) 
		// and [ 1, 1, 1, 1 ] to [ 0, 0, 0, 0 ] (returning NO for rollover detection ) 
		
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
			
		if( j >= 0 ) return YES ;
		
		return NO ;
	}
		
		
		
		
			
		
				
				
					
				
					
						
						
							
						
						
						
						
						
				
				
				
				
				
				
				
					
				
					
				
				
				
				
				
				
				
				
				
		
		
		

							
						
						
		
		
		
		
@end
