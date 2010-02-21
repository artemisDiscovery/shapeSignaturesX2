//
//  fragment.m
//  MolMon
//
//  Created by Randy Zauhar on 2/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "fragment.h"


@implementation fragment

	
- (id) initWithBonds:(NSSet *)b andType:(fragmentType)typ checkForNeighbors:(BOOL)chk inTree:(ctTree *)tr 
	{
		self = [ super init ] ;
		
		fragmentBonds = [ [ NSMutableSet alloc ] initWithSet:b ] ;
		
		fragmentNodes = [ [ NSMutableSet alloc ] initWithCapacity:[ fragmentBonds count ] ] ;
		
		neighborFragments = nil ; ;
		
		NSEnumerator *bondEnumerator = [ fragmentBonds objectEnumerator ] ;
		
		ctBond *nextBond ;
		
		while( ( nextBond = [ bondEnumerator nextObject ] ) )
			{
				[ fragmentNodes addObject:nextBond->node1 ] ;
				[ fragmentNodes addObject:nextBond->node2 ] ;
			}
			
		type = typ ;
		
		index = -1 ;
		
		if( chk == YES )
			{
				// Check for any neighbors
				
				// Added array has a retain count of one and points at 
				// autoreleased objects 
				
				neighborFragments = [ tr neighborFragmentsTo:self ] ;
				
				// Subtract any common nodes
				/*
				NSEnumerator *neighborEnumerator = [ neighborFragments objectEnumerator ] ;
				
				NSArray *nextNeighbor ;
				
				while( ( nextNeighbor = [ neighborEnumerator nextObject ] ) )
					{
						[ fragmentNodes minusSet:[ nextNeighbor lastObject ] ] ;
					}
				*/
			}
			
		return self ;
	}
	
- (void) dealloc
	{
		[ fragmentBonds release ] ;
		[ fragmentNodes release ] ;
		
		if( neighborFragments ) [ neighborFragments release ] ;
		if( center ) [ center release ] ;
		if( normal ) [ normal release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}
	
- (void) mergeFragment:(fragment *)m 
	{
		[ fragmentNodes unionSet:m->fragmentNodes ] ;
		[ fragmentBonds unionSet:m->fragmentBonds ] ;
		
		[ m release ] ;
		
		return ;
	}
	
- (void) assignFragmentIndex:(int)idx
	{
		NSEnumerator *nodeEnumerator = [ fragmentNodes objectEnumerator ] ;
		
		ctNode *nextNode ;
		
		index = idx ;
		
		while( ( nextNode = [ nodeEnumerator nextObject ] ) )
			{
				nextNode->fragmentIndex = idx ;
				char label[100] ;

				switch( type )
					{
						case RING:
							sprintf( label, "%s%d", "R", idx ) ;
							[ nextNode addPropertyValue:label forKey:"fragmentID" ] ;
							break ;
							
						case NONRING:
							sprintf( label, "%s%d", "NR", idx ) ;
							[ nextNode addPropertyValue:label forKey:"fragmentID" ] ;
							break ;
					}
			}
			
		return ;
	}
		
- (void) adjustNodesByNeighbors
	{
		if( ! neighborFragments ) return ;
		
		// If we are a ring, keep our nodes (only nonring fragments give up nodes)
		
		if( type == RING ) return ;
		
		NSEnumerator *neighborEnumerator = [ neighborFragments objectEnumerator ] ;
		
		NSArray *nextNeighborBundle ;
		
		while( ( nextNeighborBundle = [ neighborEnumerator nextObject ] ) )
			{
				[ fragmentNodes minusSet:[ nextNeighborBundle objectAtIndex:1 ] ] ;
			}
			
		return ;
	}
		

@end
