//
//  fragmentConnection.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/8/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "fragment.h"

// This class represents a connection between fragments. Serves as the foundation to build 
// histogram groups/bundles

@interface fragmentConnection : NSObject 
{
	BOOL active ;

	fragment *first ;
	fragment *second ;


}

- (id) initWithFirst:(fragment *)f second:(fragment *)s ;

- (NSSet *) linkedFragments ;

- (BOOL) includes:(fragment *) f ;

- (BOOL) isEqualTo:(fragmentConnection * )c ;


@end
