//
//  fragment.h
//  MolMon
//
//  Created by Randy Zauhar on 2/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "vector3.h"
#import "ctTree.h"

// NONRING_SUBSTITUENT is a component that is too large to be merged with a ring, but
// is not connected to any other ring. A NONRING_BRIDGE is a non-ring component that 
// joins two or more rings. 

@class fragmentConnection ;

typedef enum { RING, RING_TERMINAL, RING_INTERIOR, NONRING, SUBSTITUENT, BRIDGE } fragmentType ;

@interface fragment : NSObject 
{


@public 

	int index ;
	
	// This represents a fragment in a tree
	
	ctTree *sourceTree ;
	
	fragmentType type ; 
	
	NSMutableSet *fragmentNodes ;
	NSMutableSet *fragmentBonds ;
	
	MMVector3 *normal, *center ;
	
	NSArray *neighborFragments ;
	
	NSMutableSet *neighborFragmentIndices ;
	
	NSMutableArray *connections ;

}

- (id) initWithBonds:(NSSet *)b andType:(fragmentType)typ inTree:(ctTree *)tr ;

//- (void) addCenter ;
//- (void) addNormal ;

- (void) mergeFragment:(fragment *)m ;

- (void) assignFragmentIndex:(int)idx ;

- (void) adjustNodesByNeighbors ;

- (int) heavyAtomCount ;

- (int) neighborRingCount ;
- (int) neighborBridgeCount ;

- (void) assignNonRingFragmentType ;
- (void) assignRingFragmentType ;

- (void) assignNeighborFragmentIndices ;

- (void) registerConnection:(fragmentConnection *)c ;

- (NSDictionary *) propertyListDict ;

- (id) initWithPropertyListDict:(NSDictionary *)pListDict andNodeTranslator:(NSDictionary *)nodeTran
		andBondTranslator:(NSDictionary *)bondTran ;

@end
