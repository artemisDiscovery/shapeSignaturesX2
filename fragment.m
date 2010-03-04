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
		
		neighborFragments = nil ; 
		neighborFragmentIndices = nil ;
		
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
				
				// Neighbor check will override type passed in!
				
				
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
		if( neighborFragmentIndices ) [ neighborFragmentIndices release ] ;
		//if( center ) [ center release ] ;
		//if( normal ) [ normal release ] ;
		
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
						case RING_TERMINAL:
							sprintf( label, "%s%d", "RT", idx ) ;
							[ nextNode addPropertyValue:label forKey:"fragmentID" ] ;
							break ;
							
						case RING_INTERIOR:
							sprintf( label, "%s%d", "RI", idx ) ;
							[ nextNode addPropertyValue:label forKey:"fragmentID" ] ;
							break ;
							
						case BRIDGE:
							sprintf( label, "%s%d", "B", idx ) ;
							[ nextNode addPropertyValue:label forKey:"fragmentID" ] ;
							break ;
							
						case SUBSTITUENT:
							sprintf( label, "%s%d", "S", idx ) ;
							[ nextNode addPropertyValue:label forKey:"fragmentID" ] ;
							break ;
						
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
		
		if( type == RING || type == RING_TERMINAL || type == RING_INTERIOR ) return ;
		
		NSEnumerator *neighborEnumerator = [ neighborFragments objectEnumerator ] ;
		
		NSArray *nextNeighborBundle ;
		
		while( ( nextNeighborBundle = [ neighborEnumerator nextObject ] ) )
			{
				[ fragmentNodes minusSet:[ nextNeighborBundle objectAtIndex:1 ] ] ;
			}
			
		return ;
	}
		
- (int) heavyAtomCount
	{
		int j ;
		
		int hCount = 0 ;
		
		NSEnumerator *nodeEnumerator = [ fragmentNodes objectEnumerator ] ;
		ctNode *theNode ;
		
		while( ( theNode = [ nodeEnumerator nextObject ] ) )
			{
				if( theNode->atomicNumber > 1 ) ++hCount ;
			}
			
		return hCount ;
	}
	
- (int) neighborRingCount 
	{
		if( ! neighborFragments ) return 0 ;
		
		NSEnumerator *neighborFragmentEnumerator = [ neighborFragments objectEnumerator ] ;
		
		fragment *nextNeighborFragment ;
		
		int ringCount = 0 ;
		
		while( ( nextNeighborFragment = [ neighborFragmentEnumerator nextObject ] ) )
			{
				if( nextNeighborFragment->type == RING || nextNeighborFragment->type == RING_INTERIOR ||
					nextNeighborFragment->type == RING_TERMINAL ) ++ringCount ;
			}
			
		return ringCount ;
	}

- (int) neighborBridgeCount
	{
		if( ! neighborFragments ) return 0 ;
		
		NSEnumerator *neighborFragmentEnumerator = [ neighborFragments objectEnumerator ] ;
		
		fragment *nextNeighborFragment ;
		
		int bridgeCount = 0 ;
		
		while( ( nextNeighborFragment = [ neighborFragmentEnumerator nextObject ] ) )
			{
				if( nextNeighborFragment->type == BRIDGE ) ++bridgeCount ;
			}
			
		return bridgeCount ;
	}


- (void) assignNonRingFragmentType
	{
		// Skip if not a NONRING type
		
		if( type != NONRING ) return ;
		
		int neighborRingCount = [ self neighborRingCount ] ;
		
		if( neighborRingCount == 0 ) 
			{
				return ; // How did that happen?
			}
		 
		if( neighborRingCount > 1 )
			{
				type = BRIDGE ;
			}
		else
			{
				type = SUBSTITUENT ;
			}
		
		return ;
	}
	
- (void) assignRingFragmentType
	{
		if( type != RING ) return ;
		
		int neighborBridgeCount = [ self neighborBridgeCount ] ;
		
		 
		if( neighborBridgeCount <= 1 )
			{
				type = RING_TERMINAL ;
			}
		else
			{
				type = RING_INTERIOR ;
			}
		
		return ;
	}
	
- (void) assignNeighborFragmentIndices
	{
		if( ! neighborFragments ) return ;
		
		neighborFragmentIndices = [ [ NSMutableSet alloc ] initWithCapacity:[ neighborFragments count ] ] ;
		
		NSEnumerator *neighborFragmentEnumerator = [ neighborFragments objectEnumerator ] ;
		
		fragment *nextNeighborFragment ;
		
		while( ( nextNeighborFragment = [ neighborFragmentEnumerator nextObject ] ) )
			{
				fragment *neighbor = [ nextNeighborFragment objectAtIndex:0 ] ;
				[ neighborFragmentIndices addObject:[ [ NSString stringWithFormat:@"%d",neighbor->index ] ] ] ;
			}
			
		return ;
	}
				
				
	
- (void) encodeWithCoder:(NSCoder *)coder
	{

		[ coder encodeValueOfObjCType:@encode(int) at:&index ] ;
		[ coder encodeValueOfObjCType:@encode(fragmentType) at:&type ] ;
		
		[ coder encodeObject:fragmentNodes ] ;
		[ coder encodeObject:fragmentBonds ] ;
		
		[ coder encodeObject:neighborFragments ] ;
		
		
		return ;
	}
		
- (id) initWithCoder:(NSCoder *)coder
	{
		self = [ super init ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&index ] ;
		[ coder decodeValueOfObjCType:@encode(fragmentType) at:&type ] ;
		
		fragmentNodes = [ [ coder decodeObject ] retain ] ;
		fragmentBonds = [ [ coder decodeObject ] retain ] ;
		
		neighborFragments = [ [ coder decodeObject ] retain ] ;
		
		
		return self ;
	}



@end
