//
//  XSignatureMapping.m
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 10/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "X2SignatureMapping.h"


@implementation X2SignatureMapping

- (id) initWithQuery:(histogramGroupBundle *)q andTarget:(histogramGroupBundle *)t
	{
		self = [ super init ] ;
		
		query = q ;
		target = t ;
		
		isMaximal = NO ;
		
		unpairedQueryHistoGroups = [ [ NSMutableSet alloc ] 
					initWithArray:query->memberGroups ] ;
		unpairedTargetHistoGroups = [ [ NSMutableSet alloc ] 
					initWithArray:target->memberGroups ] ;
		
				
				
		histoGroupPairs = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		
		return self ;
	}
	
- (id) initWithMapping:(X2SignatureMapping *)map
	{
		self = [ super init ] ;
		
		query = map->query ;
		target = map->target ;
		
		histoGroupPairs = [ [ NSMutableArray alloc ] initWithArray:map->histoGroupPairs ] ;
		
		unpairedQueryHistoGroups = [ [ NSMutableSet alloc ] initWithSet:map->unpairedQueryHistoGroups ] ;
		unpairedTargetHistoGroups = [ [ NSMutableSet alloc ] initWithSet:map->unpairedTargetHistoGroups ] ;
		
		isMaximal = map->isMaximal ;
		
		return self ;
	}
	
- (void) dealloc
	{
		[ histoGroupPairs release ] ;
		
		[ unpairedQueryHistoGroups release ] ;
		[ unpairedTargetHistoGroups release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}
	
- (BOOL) addMatchBetweenQueryHistoGroup:(histogramGroup *)q andTargetHistoGroup:(histogramGroup *)t 
	{
		// The histogram groups must be initially unpaired
		
		if( [ unpairedQueryHistoGroups member:q ] && [ unpairedTargetHistoGroups member:t ] )
			{
				NSMutableArray *addArray = [ NSMutableArray arrayWithCapacity:5 ] ;
				[ addArray addObject:q ] ;
				[ addArray addObject:t ] ;
				[ histoGroupPairs addObject:addArray ] ;
 				
				[ unpairedQueryHistoGroups removeObject:q ] ;
				[ unpairedTargetHistoGroups removeObject:t ] ;
			
				return YES ;
			}
			
		return NO ;
	}
		
+ (NSMutableArray *) expandMappings:(NSMutableArray *)mappings 
	{
		// Strategy: 
		//
		// initialize empty expandedMappings array
		//
		//	while( TRUE)
		//
		// change = FALSE 
		//
		// foreach mapping m in mappings:
		//
		//		if m is maximal (could not be expanded) continue 
		//
		//		set m as maximal
		//
		//		foreach histo pair (hQa,hTb) in m
		//			find childrenQ = hQa(children) intersect mQueryUnmatched
		//			find childrenT = hTb(children) intersect mTargetUnmatched
		//		
		//			if( no childrenQ || no children T ) continue
		//
		//			foreach qcH in childrenQ
		//				foreach tcH in childrenT
		//
		//					newMapping = copy of m
		//					newMapping add connection qcH to tcH
		//					set m submaximal
		//					add newMapping to newMappings 
		//
		//					change = TRUE
		//
		//				end
		//			end
		//		end
		//
		//		if( m maximal) add m to newMappings
		//
		//		release mappings
		//
		//		if( change == FALSE ) return newMappings
		//
		//		mappings = newMappings
		//
		//	end
		//
		// end
		//
		//
		//		
		
		NSEnumerator *argumentMappingEnumerator = [ mappings objectEnumerator ] ;
		NSMutableArray *seedMappings = [ [ NSMutableArray alloc ] initWithCapacity:[ mappings count ] ] ;
		
		X2SignatureMapping *nextArgMap ;

		while( ( nextArgMap = [ argumentMappingEnumerator nextObject ] ) )
		//for( X2SignatureMapping *nextArgMap in argumentMappingEnumerator )
		{
			X2SignatureMapping *copyMap = [ [ X2SignatureMapping alloc ] initWithMapping:nextArgMap ] ;
			[ seedMappings addObject:copyMap ] ;
			[ copyMap release ] ;
		}
		
		//NSArray *seedMappings = [ [ NSArray alloc ] initWithArray:mappings ] ;
		
		while( TRUE )
			{
				BOOL change = NO ;
				
				NSMutableArray *newMappings = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
				
				NSEnumerator *mappingEnumerator = [ seedMappings objectEnumerator ] ;
		
				X2SignatureMapping *nextSeedMapping ;
				
				
				while( ( nextSeedMapping = [ mappingEnumerator nextObject ] ) )
					{
						if( nextSeedMapping->isMaximal == YES )
							{
								[ newMappings addObject:nextSeedMapping ] ;
								continue ;
							}
							
						nextSeedMapping->isMaximal = YES ;
						
						NSEnumerator *histoGroupPairEnumerator = [ nextSeedMapping->histoGroupPairs objectEnumerator ] ;
						NSArray *nextHistoGroupPair ;

						while( ( nextHistoGroupPair = [ histoGroupPairEnumerator nextObject ] ) )
							{
								histogramGroup *queryParent = [ nextHistoGroupPair objectAtIndex:0 ] ;
								histogramGroup *targetParent = [ nextHistoGroupPair objectAtIndex:1 ] ;
								
								// Want query and target children that are not already used 
						
								NSMutableSet *queryChildren = [ NSMutableSet setWithArray:queryParent->connectToGroups ] ;
								
								// Any unused?
								
								[ queryChildren intersectSet:nextSeedMapping->unpairedQueryHistoGroups ] ;
								
								if( [ queryChildren count ] == 0 ) continue ;
								
								NSMutableSet *targetChildren = [ NSMutableSet setWithArray:targetParent->connectToGroups ] ;
								
								// Any unused?
								
								[ targetChildren intersectSet:nextSeedMapping->unpairedTargetHistoGroups ] ;
								
								if( [ targetChildren count ] == 0 ) continue ;
								
								NSEnumerator *queryChildrenEnumerator = [ queryChildren objectEnumerator ] ;
								
								histogramGroup *nextQueryChild ;
								
								while( ( nextQueryChild = [ queryChildrenEnumerator nextObject ] ) )
									{
										NSEnumerator *targetChildrenEnumerator = [ targetChildren objectEnumerator ] ;
										
										histogramGroup *nextTargetChild ;
										
										while( ( nextTargetChild = [ targetChildrenEnumerator nextObject ] ) )
											{
												nextSeedMapping->isMaximal = NO ;
												
												X2SignatureMapping *newMapping = [ [ X2SignatureMapping alloc ]
																					initWithMapping:nextSeedMapping ] ;
												[ newMapping addMatchBetweenQueryHistoGroup:nextQueryChild 
														andTargetHistoGroup:nextTargetChild ] ;
														
												[ newMappings addObject:newMapping ] ;
												[ newMapping release ] ;
												
												change = YES ;
											}
									}
								// Next histo pair
							}
							
						// Is our current mapping maximal?
						
						if( nextSeedMapping->isMaximal == YES )
							{
								[ newMappings addObject:nextSeedMapping ] ;
 							}
					}
				
				if( change == NO ) {
					[ seedMappings release ] ;
					return newMappings ;
				}
						
				[ seedMappings release ] ;
				
				seedMappings = newMappings ;
				
				// Try to expand again
			}
			
		// Should never reach here!
		
		return nil ;
	}
	
- (BOOL) isEqualToMapping:(X2SignatureMapping *)targetMap
	{
		// Equality if all histopairs are equal (they should already be sorted at this point)
							
		if( [ histoGroupPairs count ] != [ targetMap->histoGroupPairs count ] ) return NO ;
		
		int j ;
		
		for( j = 0 ; j < [ histoGroupPairs count ] ; ++j )
			{
				NSArray *myHistoGroupPair = [ histoGroupPairs objectAtIndex:j ] ;
				NSArray *targetHistoGroupPair = [ targetMap->histoGroupPairs objectAtIndex:j ] ;
				
				int k ;
				
				for( k = 0 ; k < 2 ; ++k )
					{
						histogramGroup *myGroup = [ myHistoGroupPair objectAtIndex:k ] ;
						histogramGroup *targetGroup = [ targetHistoGroupPair objectAtIndex:k ] ;
						
						if( [ myGroup isEqualTo:targetGroup ] == NO )
							{
								return NO ;
							}
						
						//if(  [ myHistoGroupPair objectAtIndex:k ] != [ targetHistoGroupPair objectAtIndex:k ] ) return NO ;
					}
			}
			
		return YES ;
	}
						
						
- (NSString *) description
	{
		NSInteger stringIndexCompare(id, id, void *) ;
		
		NSEnumerator *histoGroupPairEnumerator = [ histoGroupPairs objectEnumerator ] ;
		
		NSArray *nextGroupPair ;
		
		NSMutableString *returnString = [ NSMutableString stringWithCapacity:100 ] ;
		
		[ returnString appendString:@"[" ] ;
						
		while( ( nextGroupPair = [ histoGroupPairEnumerator nextObject ] ) )
			{

				
				histogramGroup *Q = [ nextGroupPair objectAtIndex:0 ] ;
				histogramGroup *T = [ nextGroupPair objectAtIndex:1 ] ;
								
				NSMutableArray *qIndices = [ NSMutableArray arrayWithArray:[ Q->groupFragmentIndices allObjects ] ] ;
				[ qIndices sortUsingFunction:stringIndexCompare context:nil ] ;
				
				NSMutableArray *tIndices = [ NSMutableArray arrayWithArray:[ T->groupFragmentIndices allObjects ] ] ;
				[ tIndices sortUsingFunction:stringIndexCompare context:nil ] ;
				
				[ returnString appendString:@" (" ] ;
				
				NSEnumerator *indexEnumerator = [ qIndices objectEnumerator ] ;
				NSString *nextIndex ;
				
				while( ( nextIndex = [ indexEnumerator nextObject ] ) )
					{
						[ returnString appendString:nextIndex ] ;
						[ returnString appendString:@" " ] ;
					}
					
				[ returnString appendString:@")-( " ] ;
				
				indexEnumerator = [ tIndices objectEnumerator ] ;
				
				while( ( nextIndex = [ indexEnumerator nextObject ] ) )
					{
						[ returnString appendString:nextIndex ] ;
						[ returnString appendString:@" " ] ;
					}
				
				[ returnString appendString:@") " ] ;
			}
			
		[ returnString appendString:@"]" ] ;
		
		return returnString ;
	}
				

NSInteger stringIndexCompare( id A, id B, void *ctxt )
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

@end
