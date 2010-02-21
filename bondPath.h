//
//  bondPath.h
//  MolMon
//
//  Created by Randy Zauhar on 2/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ctTree.h"

@interface bondPath : NSObject 
{
	// As a result of much dicking around, I have decided I need a new-and-improved 
	// path object that will use ctBonds as basic elements rather than nodes. 
	
@public

	NSMutableArray *bonds ;
	NSMutableArray *bondOrientations ;
	NSMutableSet *bondsAsSet ;
	
	ctTree *sourceTree ;
	
	
}

- (id) initWithTree:(ctTree *)t ;

- (id) initWithBondPath:(bondPath *)p ;

- (NSMutableArray *) extendBonds ;

- (void) addBond:(ctBond *)b rootNode:(ctNode *)r ;

- (ctNode *) endNode ;

@end
