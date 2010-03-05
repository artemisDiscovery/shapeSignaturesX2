//
//  histogramGroupBundle.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "histogramGroupBundle.h"


@implementation histogramGroupBundle

- (id) initWithGroups:(NSArray *)grps inHistogramBundle:(histogramBundle *)hBundle
	{
		// The actions here are to init array of member groups and set up connections between
		// them based on histogram memberships in the groups and connections between associated fragments 
		// in the source connect tree 
		
		memberGroups = [ [ NSArray alloc ] initWithArray:grps ] ;
		
		ctTree *sourceTree = hBundle->sourceTree ;
		
		int j, k ;
		
		for( j = 0 ; j < [ memberGroups count ] - 1 ; ++j )
			{
				histogramGroup *jGroup = [ memberGroups objectAtIndex:j ] ;
				
				for( k = j + 1 ; k < [ memberGroups count ] ; ++k )
					{
						histogramGroup *kGroup = [ memberGroups objectAtIndex:j ] ;
						
						// Two groups neighbor each other if the neighborFragmentIndices set
						// of one intersect the groupFragmentIndicesSet of the other. 
						
						if( [ jGroup->neighborFragmentIndices 
							intersectsSet:kGroup->neighborFragmentIndices ] == YES )
							{
								// Test other way (sanity)
								
								if( [ kGroup->neighborFragmentIndices 
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
			
		
+ (NSArray *) allGroupBundlesFromHistogramBundle:(histogramBundle *)hBundle 
	{
		// Strategy - isolate 

							
						
						
		
		
		
		
@end
