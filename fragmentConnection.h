//
//  fragmentConnection.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/8/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "fragment.h"

// This class represents a connection between fragments. Serves as the foundation to build 
// histogram groups/bundles

@interface fragmentConnection : NSObject 
{
@public

	BOOL active ;

	fragment *first ;
	fragment *second ;
	
	int firstIndex ;
	int secondIndex ;


}

- (id) initWithFirst:(fragment *)f second:(fragment *)s ;

- (NSSet *) linkedFragments ;

- (BOOL) includes:(fragment *) f ;

- (BOOL) isEqualTo:(fragmentConnection * )c ;


@end
