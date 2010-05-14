//
//  ctBond.m
//  fftool
//
//  Created by Randy Zauhar on 5/11/09.
//  Copyright 2009 ArtemisDiscovery LLC. All rights reserved.
//

#import "ctBond.h"
#import "ctNode.h"


@implementation ctBond

- (id) initWithNode1:(ctNode *)n1 andNode2:(ctNode *)n2 andType:(bondType)t 
	{
		// NOTE that I will not retain the nodes - assumption is that everyone is alive for the 
		// lifetime of the tree 
		
		self = [ super init ] ;
		
		node1 = n1 ;
		node2 = n2 ;
		
		type = t ;
		
		closureIndex = -1 ;
		
		return self ;
	}
	
- (void) dealloc
	{
		[ super dealloc ] ;
		
		return ;
	}
	
- (ctNode *) startNode
	{
		return node1 ;
	}
	
- (ctNode *) endNode 
	{
		return node2 ;
	}


- (char) returnBondSymbol
	{
		switch( type )
			{
				case SINGLE:
				case AMIDE:
				case COORDINATION:
					return '-' ;
					
				case DOUBLE:
					return '=' ;
					
				case TRIPLE:
					return '#' ;
				
				case AROMATIC:
					return ':' ;
					
				case ANY:
				case UNDEFINED:
					return '~' ;
					
			}
			
		return '~' ;
	}

		
- (NSSet *) neighborNodes
	{
		NSMutableSet *neighbors = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
		
		int i ;
		ctBond *theBond ;
		
		for( i = 0 ; i < node1->nBonds ; ++i )
			{
				theBond = node1->bonds[i] ;
				
				if( theBond == self ) continue ;
				
				if( [ theBond startNode ] == node1 )
					{
						[ neighbors addObject:[ theBond endNode ] ] ;
					}
				else	
					{
						[ neighbors addObject:[ theBond startNode ] ] ;
					}
				
			}
			
		for( i = 0 ; i < node2->nBonds ; ++i )
			{
				theBond = node2->bonds[i] ;
				
				if( theBond == self ) continue ;
				
				if( [ theBond startNode ] == node2 )
					{
						[ neighbors addObject:[ theBond endNode ] ] ;
					}
				else	
					{
						[ neighbors addObject:[ theBond startNode ] ] ;
					}
				
			}
			
			
		return neighbors ;
	}
		
- (NSSet *) neighborNodesWithBondType:(bondType)t
	{
		NSMutableSet *neighbors = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
		
		int i ;
		ctBond *theBond ;
		
		for( i = 0 ; i < node1->nBonds ; ++i )
			{
				theBond = node1->bonds[i] ;
				
				if( theBond->type != t ) continue ;
				
				if( theBond == self ) continue ;
				
				if( [ theBond startNode ] == node1 )
					{
						[ neighbors addObject:[ theBond endNode ] ] ;
					}
				else	
					{
						[ neighbors addObject:[ theBond startNode ] ] ;
					}
				
			}
			
		for( i = 0 ; i < node2->nBonds ; ++i )
			{
				theBond = node2->bonds[i] ;
				
				if( theBond->type != t ) continue ;
				
				if( theBond == self ) continue ;
				
				if( [ theBond startNode ] == node2 )
					{
						[ neighbors addObject:[ theBond endNode ] ] ;
					}
				else	
					{
						[ neighbors addObject:[ theBond startNode ] ] ;
					}
				
			}
			
			
		return neighbors ;
	}

- (void) encodeWithCoder:(NSCoder *)coder
	{
		[ coder encodeObject:node1 ] ;
		[ coder encodeObject:node2 ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&type ] ;
				
		[ coder encodeValueOfObjCType:@encode(int) at:&closureIndex ] ;
		
		return ;
	}
	
-(id) initWithCoder:(NSCoder *)coder
	{
		self = [ super init ] ;
		
		node1 = [ [ coder decodeObject ] retain ] ;
		node2 = [ [ coder decodeObject ] retain ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&type ] ;
				
		[ coder decodeValueOfObjCType:@encode(int) at:&closureIndex ] ;
		
		return self ;
	}
	
- (NSDictionary *) propertyListDict 
	{
		NSMutableDictionary *returnDictionary = [ NSMutableDictionary dictionaryWithCapacity:10 ] ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&node1 length:sizeof( ctNode * ) ] 
			forKey:@"originalNode1Ptr" ] ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&node2 length:sizeof( ctNode * ) ] 
			forKey:@"originalNode2Ptr" ] ;
			
		[ returnDictionary setObject:[ NSData dataWithBytes:&type length:sizeof( bondType ) ] 
			forKey:@"type" ] ;
			
		
		return returnDictionary ;
		//return theData ;
	}
	
- (id) initWithPropertyListDict:(NSDictionary *) pListDict andNodeTranslator:(NSDictionary *)nodeTran 
	{
		self = [ super init ] ;
		
		NSData *theData ;
		
		theData = [ pListDict objectForKey:@"type" ] ;
		[ theData getBytes:&type length:sizeof(bondType) ] ;
		
		theData = [ pListDict objectForKey:@"originalNode1Ptr" ] ;
		ctNode *originalPtr ;
		[ theData getBytes:&originalPtr length:sizeof(ctNode *) ] ;
		
		node1 = [ nodeTran objectForKey:[ NSData dataWithBytes:&originalPtr length:sizeof( ctNode * )  ] ] ;
		
		theData = [ pListDict objectForKey:@"originalNode2Ptr" ] ;
		[ theData getBytes:&originalPtr length:sizeof(ctNode *) ] ;
		
		node2 = [ nodeTran objectForKey:[ NSData dataWithBytes:&originalPtr length:sizeof( ctNode * )  ] ] ;
		
		return self ;
	}
		
		
		
	
		
- (NSString *) description
	{
		NSString *returnString = [ NSString 
			stringWithFormat:@"ctBond: %x \nnode1: %@ node2: %@",
			self, node1, node2 ] ;
			
		return returnString ;
	}
	
@end
