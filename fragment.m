//
//  fragment.m
//  MolMon
//
//  Created by Randy Zauhar on 2/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "fragment.h"
#import "fragmentConnection.h"


@implementation fragment

	
- (id) initWithBonds:(NSSet *)b andType:(fragmentType)typ inTree:(ctTree *)tr 
	{
		self = [ super init ] ;
	
		sourceTree = tr ;
		
		fragmentBonds = [ [ NSMutableSet alloc ] initWithSet:b ] ;
		
		fragmentNodes = [ [ NSMutableSet alloc ] initWithCapacity:[ fragmentBonds count ] ] ;
		
		neighborFragmentIndices = nil ;
		connections = nil ;
		
		NSEnumerator *bondEnumerator = [ fragmentBonds objectEnumerator ] ;
		
		ctBond *nextBond ;
		
		while( ( nextBond = [ bondEnumerator nextObject ] ) )
			{
				[ fragmentNodes addObject:nextBond->node1 ] ;
				[ fragmentNodes addObject:nextBond->node2 ] ;
			}
			
		type = typ ;
		
		index = -1 ;
		
			
		return self ;
	}
	
- (void) dealloc
	{
		[ fragmentBonds release ] ;
		[ fragmentNodes release ] ;
		
		if( neighborFragmentIndices ) [ neighborFragmentIndices release ] ;
		if( connections ) [ connections release ] ;
		if( center ) [ center release ] ;
		if( normal ) [ normal release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}
	
- (void) mergeFragment:(fragment *)m 
	{
		[ fragmentNodes unionSet:m->fragmentNodes ] ;
		[ fragmentBonds unionSet:m->fragmentBonds ] ;
		
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
		if( ! sourceTree->fragmentToNeighborData ) return ;
	
		NSArray *neighborData = [ sourceTree->fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:self ] ] ;
		
		// If we are a ring, keep our nodes (only nonring fragments give up nodes)
		
		if( type == RING || type == RING_TERMINAL || type == RING_INTERIOR ) return ;
		
		NSEnumerator *neighborEnumerator = [ neighborData objectEnumerator ] ;
		
		NSArray *nextNeighborBundle ;
		
		while( ( nextNeighborBundle = [ neighborEnumerator nextObject ] ) )
			{
				[ fragmentNodes minusSet:[ nextNeighborBundle objectAtIndex:1 ] ] ;
			}
			
		return ;
	}
		
- (int) heavyAtomCount
	{
		
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
		if( ! sourceTree->fragmentToNeighborData ) return ;
	
		NSArray *neighborData = [ sourceTree->fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:self ] ] ;
		
		NSEnumerator *neighborDataEnumerator = [ neighborData objectEnumerator ] ;
	
		NSArray *nextBundle ;
		
		fragment *nextNeighborFragment ;
		
		int ringCount = 0 ;
		
		while( ( nextBundle = [ neighborDataEnumerator nextObject ] ) )
			{
				nextNeighborFragment = [ nextBundle objectAtIndex:0 ] ;
			
				if( nextNeighborFragment->type == RING || nextNeighborFragment->type == RING_INTERIOR ||
					nextNeighborFragment->type == RING_TERMINAL ) ++ringCount ;
			}
			
		return ringCount ;
	}

- (int) neighborBridgeCount
	{
		if( ! sourceTree->fragmentToNeighborData ) return ;
		
		NSArray *neighborData = [ sourceTree->fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:self ] ] ;
		
		NSEnumerator *neighborDataEnumerator = [ neighborData objectEnumerator ] ;
		
		NSArray *nextBundle ;
		
		fragment *nextNeighborFragment ;
	
		int bridgeCount = 0 ;
		
		while( ( nextBundle = [ neighborDataEnumerator nextObject ] ) )
			{
				nextNeighborFragment = [ nextBundle objectAtIndex:0 ] ;
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
		if( type != RING && type != RING_TERMINAL && type != RING_INTERIOR ) return ;
		
		int neighborBridgeCount = [ self neighborBridgeCount ] ;
		
		int neighborRingCount = [ self neighborRingCount ] ;
		
		 
		if( neighborBridgeCount + neighborRingCount <= 1 )
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
		if( ! sourceTree->fragmentToNeighborData ) return ;
		
		NSArray *neighborData = [ sourceTree->fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:self ] ] ;
		
		NSEnumerator *neighborDataEnumerator = [ neighborData objectEnumerator ] ;
		
		NSArray *nextBundle ;
		
		fragment *nextNeighborFragment ;
	
		neighborFragmentIndices = [ [ NSMutableSet alloc ] initWithCapacity:[ neighborFragments count ] ] ;
 
		while( ( nextBundle = [ neighborDataEnumerator nextObject ] ) )
			{
				fragment *nextNeighborFragment = [ nextBundle objectAtIndex:0 ] ;
				[ neighborFragmentIndices addObject:[ NSString stringWithFormat:@"%d",nextNeighborFragment->index ] ] ;
			}
 
		return ;
	}
 
- (NSString *) description
	{
		NSString *returnString ;
		
		returnString = [ NSString 
		stringWithFormat:@"fragment %x\nNODES:\n%@\nBONDS:\n%@",
			self, fragmentNodes, fragmentBonds ] ;
			
		return returnString ;
	}

- (void) registerConnection:(fragmentConnection *)c
	{
		// If no connections, add this one
 
		if( ! connections )
			{
				connections = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
 
				[ connections addObject:c ] ;
 
				return ;
			}
 
		NSEnumerator *connectionEnumerator = [ connections objectEnumerator ] ;
 
		fragmentConnection *nextConnection ;
 
		while( ( nextConnection = [ connectionEnumerator nextObject ] ) )
			{
				if( [ nextConnection isEqualTo:c ] == YES )
					{
						return ;
					}
			}
 
		[ connections addObject:c ] ;
 
		return ;
	}
 
 
 - (NSDictionary *) propertyListDict 
	{
		NSMutableDictionary *returnDictionary = [ NSMutableDictionary dictionaryWithCapacity:10 ] ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&index length:sizeof(int) ] forKey:@"index" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&type length:sizeof(fragmentType) ] forKey:@"fragmentType" ]  ;
		
		ctNode **originalNodePtrs = (ctNode **) malloc( [ fragmentNodes count ] * sizeof( ctNode * ) ) ;
		
		NSArray *nodeArray = [ fragmentNodes allObjects ] ;
		
		[ returnDictionary setObject:[ NSNumber numberWithInt:[fragmentNodes count] ] forKey:@"fragmentNodeCount" ] ;
		[ returnDictionary setObject:[ NSNumber numberWithInt:[fragmentBonds count] ] forKey:@"fragmentBondCount" ] ;
		
		int j ;
		
		for( j = 0 ; j < [ fragmentNodes count ] ; ++j )
			{
				originalNodePtrs[j] = [ nodeArray objectAtIndex:j ] ;
			}
			
		[ returnDictionary setObject:[ NSData dataWithBytes:originalNodePtrs 
			length:([ fragmentNodes count ]*sizeof(ctNode *)) ]
			forKey:@"originalNodePtrs" ] ;
			
		ctBond **originalBondPtrs = (ctBond **) malloc( [ fragmentBonds count ] * sizeof( ctBond * ) ) ;
		
		NSArray *bondArray = [ fragmentBonds allObjects ] ;
		
		for( j = 0 ; j < [ fragmentBonds count ] ; ++j )
			{
				originalBondPtrs[j] = [ bondArray objectAtIndex:j ] ;
			}
			
		[ returnDictionary setObject:[ NSData dataWithBytes:originalBondPtrs 
			length:([ fragmentBonds count ]*sizeof(ctBond *)) ]
			forKey:@"originalBondPtrs" ] ;
			
		[ returnDictionary setObject:[ neighborFragmentIndices allObjects ] 
			forKey:@"neighborFragmentIndicesAsArray" ] ;
			
			
		free( originalNodePtrs ) ;
		free( originalBondPtrs ) ;
		
		return returnDictionary ;
		//return theData ;
	}
		
- (id)  initWithPropertyListDict:(NSDictionary *)pListDict andNodeTranslator:(NSDictionary *)nodeTran
		andBondTranslator:(NSDictionary *)bondTran
	{
		self = [ super init ] ;
		
	
		normal = center = nil ;
	
		connections = nil ;

		
		NSData *theData ;
		
		theData = [ pListDict objectForKey:@"index" ] ;
		[ theData getBytes:&index length:sizeof(int) ] ;
		theData = [ pListDict objectForKey:@"fragmentType" ] ;
		[ theData getBytes:&type length:sizeof(fragmentType) ] ;
		
		int fragmentNodeCount = [ [ pListDict objectForKey:@"fragmentNodeCount" ] intValue ] ;
		int fragmentBondCount = [ [ pListDict objectForKey:@"fragmentBondCount" ] intValue ] ;

		ctNode **originalNodePtrs = (ctNode **) malloc( fragmentNodeCount * sizeof( ctNode * ) ) ;
		
		theData = [ pListDict objectForKey:@"originalNodePtrs" ] ;
		[ theData getBytes:originalNodePtrs length:( fragmentNodeCount * sizeof( ctNode * ) ) ] ;
		
		ctBond **originalBondPtrs = (ctBond **) malloc( fragmentBondCount * sizeof( ctNode * ) ) ;
		
		theData = [ pListDict objectForKey:@"originalBondPtrs" ] ;
		[ theData getBytes:originalBondPtrs length:( fragmentBondCount * sizeof( ctBond * ) ) ] ;
		
		NSMutableArray *newNodeArray = [ [ NSMutableArray alloc ] initWithCapacity:fragmentNodeCount ] ;
				
		int j ;
		
		for( j = 0 ; j < fragmentNodeCount ; ++j )
			{
				ctNode *newNode = [ nodeTran 
					objectForKey:[ NSData dataWithBytes:&(originalNodePtrs[j]) length:sizeof( ctNode * )  ] ] ;
					
				[ newNodeArray addObject:newNode ] ;
			}
			
		fragmentNodes = [ [ NSMutableSet alloc ] initWithArray:newNodeArray ] ;
		[ newNodeArray release ] ;
		
	
		NSMutableArray *newBondArray = [ [ NSMutableArray alloc ] initWithCapacity:fragmentBondCount ] ;
				
		for( j = 0 ; j < fragmentBondCount ; ++j )
			{
				ctBond *newBond = [ bondTran 
					objectForKey:[ NSData dataWithBytes:&(originalBondPtrs[j]) length:sizeof( ctBond * )  ] ] ;
					
				[ newBondArray addObject:newBond ] ;
			}
			
		fragmentBonds = [ [ NSMutableSet alloc ] initWithArray:newBondArray ] ;
		[ newBondArray release ] ;		
		
		neighborFragmentIndices = [ [ NSMutableSet alloc ] 
			initWithArray:[ pListDict objectForKey:@"neighborFragmentIndicesAsArray" ] ] ;
			
		free( originalNodePtrs ) ;
		free( originalBondPtrs ) ;
			
		return self ;
	}

- (void) encodeWithCoder:(NSCoder *)coder
	{
 
		[ coder encodeValueOfObjCType:@encode(int) at:&index ] ;
		[ coder encodeValueOfObjCType:@encode(fragmentType) at:&type ] ;
 
		[ coder encodeObject:fragmentNodes ] ;
		[ coder encodeObject:fragmentBonds ] ;
  
		[ coder encodeObject:neighborFragmentIndices ] ;
 
 
		return ;
	}
 
- (id) initWithCoder:(NSCoder *)coder
	{
		self = [ super init ] ;
 
		[ coder decodeValueOfObjCType:@encode(int) at:&index ] ;
		[ coder decodeValueOfObjCType:@encode(fragmentType) at:&type ] ;
 
		fragmentNodes = [ [ coder decodeObject ] retain ] ;
		fragmentBonds = [ [ coder decodeObject ] retain ] ;
 
		neighborFragmentIndices = [ [ coder decodeObject ] retain ] ;
 
		connections = nil ;
 
 
		return self ;
	}
 
 
@end
