//
//  fragment.h
//  MolMon
//
//  Created by Randy Zauhar on 2/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "vector3.h"
#import "ctTree.h"

typedef enum { RING, NONRING } fragmentType ;

@interface fragment : NSObject 
{


@public 

	int index ;
	
	// This represents a fragment in a tree
	
	fragmentType type ; 
	
	NSMutableSet *fragmentNodes ;
	NSMutableSet *fragmentBonds ;
	
	MMVector3 *normal, *center ;
	
	NSArray *neighborFragments ;

}

- (id) initWithBonds:(NSSet *)b andType:(fragmentType)typ checkForNeighbors:(BOOL)chk inTree:(ctTree *)tr ;

- (void) addCenter ;
- (void) addNormal ;

- (void) mergeFragment:(fragment *)m ;

- (void) assignFragmentIndex:(int)idx ;

- (void) adjustNodesByNeighbors ;

@end
