//
//  bondPath.m
//  MolMon
//
//  Created by Randy Zauhar on 2/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "bondPath.h"


@implementation bondPath

- (id) initWithTree:(ctTree *)t 
	{
		self = [ super init ] ;
		
		sourceTree = t ;
		
		bonds = [ [ NSMutableArray alloc ] initWithCapacity:t->nBonds ] ;
		bondOrientations = [ [ NSMutableArray alloc ] initWithCapacity:t->nBonds ] ;
		
		bondsAsSet = [ [ NSMutableSet alloc ] initWithCapacity:t->nBonds ] ;
		
		return self ;
	}
	
- (id) initWithBondPath:(bondPath *)p 
	{
		self = [ super init ] ;
		
		sourceTree = p->sourceTree ;
		
		bonds = [ [ NSMutableArray alloc ] initWithArray:p->bonds ] ;
		bondOrientations = [ [ NSMutableArray alloc ] initWithArray:p->bondOrientations ] ;
		
		bondsAsSet = [ [ NSMutableSet alloc ] initWithSet:p->bondsAsSet ] ;
		
		return self ;
	}
		
- (void) dealloc
	{
		[ bonds release ] ;
		[ bondOrientations release ] ;
		[ bondsAsSet release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}

- (NSMutableArray *) extendBonds 
	{
		NSMutableArray *returnArray = [ NSMutableArray arrayWithCapacity:5 ] ;
		
		ctBond *lastBond = [ bonds lastObject ] ;
		
		BOOL forward = [ [ bondOrientations lastObject ] boolValue ] ;
		
		ctNode *endNode ;
		
		if( forward == YES )
			{
				endNode = lastBond->node2 ;
			}
		else
			{
				endNode = lastBond->node1 ;
			}
			
		// Examine all candidate bonds
		
		int k ;
		
		for( k = 0 ; k < endNode->nBonds ; ++k )
			{
				ctBond *theBond = endNode->bonds[k] ;
				BOOL isForward = endNode->atBondStart[k] ;
				
				if( ! [ bondsAsSet member:theBond ] )
					{
						if( isForward == YES )
							{
								if( ! strcasecmp(theBond->node2->element, "H" ) )
									{
										// No hydrogens in path
										
										continue ;
									}
									
								[ returnArray addObject:theBond ] ;
							}
						else
							{
								if( ! strcasecmp(theBond->node1->element, "H" ) )
									{
										// No hydrogens in path
										
										continue ;
									}
									
								[ returnArray addObject:theBond ] ;
							}
					}
			}
		
		return returnArray ;
	}
		
- (void) addBond:(ctBond *)b rootNode:(ctNode *)r
	{
		[ bonds addObject:b ] ;
		[ bondsAsSet addObject:b ] ;
		
		// Check orientation
		
		ctNode *checkNode ;
		
		if( b->node1 == r )
			{
				[ bondOrientations addObject:[ NSNumber numberWithBool:YES ] ] ;
			}
		else if( b->node2 == r )
			{
				[ bondOrientations addObject:[ NSNumber numberWithBool:NO ] ] ;
			}
		else
			{
				[ bondOrientations addObject:[ NSNumber numberWithBool:NO ] ] ;
				printf( "ILLEGAL BOND ADDITION TO BONDPATH!\n" ) ;
			}
			
		return ;
	}
		
- (ctNode *) endNode
	{
		ctBond *lastBond = [ bonds lastObject ] ;
		
		if( [ [ bondOrientations lastObject ] boolValue ] == YES )
			{
				return lastBond->node2 ;
			}
			
		return lastBond->node1 ;
	}
	
- (NSString *) description
	{
		NSMutableString *returnString = [ NSMutableString stringWithFormat:@"PATH: " ] ;
		
		int k ;
		
		for( k = 0 ; k < [ bonds count ] ; ++k )
			{
				ctBond *nextBond = [ bonds objectAtIndex:k ] ;
				
				if( [ [ bondOrientations objectAtIndex:k ] boolValue ] == YES )
					{
						[ returnString appendString:[ NSString stringWithFormat:@"%s ",
							[ [ nextBond->node1 returnPropertyForKey:@"atomName" ] cString ] ] ] ;
					}
				else
					{
						[ returnString appendString:[ NSString stringWithFormat:@"%s ",
							[ [ nextBond->node2 returnPropertyForKey:@"atomName" ] cString ] ] ] ;
					}
					
			}
			
		[ returnString appendString:[ NSString stringWithFormat:@"%s", 
			[ [ [ self endNode ] returnPropertyForKey:@"atomName" ] cString ] ] ] ;
			
		return returnString ;
	}
					
@end
