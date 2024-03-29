//
//  elementCollection.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif



@interface elementCollection : NSObject 
{
	// Really simple object to encapsulate an expandable list of 
	// integers (but w/o NSMutableArray overhead)
	
	int nAlloc ;
	
	int nEle ;
	
	int *indices ;
	
}

- (id) init ;

- (void) addIndex:(int) i ;

- (int) count ;

- (int *) indices ;

@end
