//
//  histogramConnection.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "histogram.h"

// This simple structure connects two histograms. It is intended to be a unique
// object that establishes such a link. 



@interface histogramConnection : NSObject 
{
	BOOL active ;

	histogram *first ;
	histogram *second ;


}

- (id) initWithFirst:(histogram *)f second:(histogram *)s ;

- (NSSet *) linkedHistograms ;

- (BOOL) includes:(histogram *) h ;

@end
