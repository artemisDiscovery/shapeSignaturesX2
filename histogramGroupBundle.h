//
//  histogramGroupBundle.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "histogramGroup.h"

// This is a bundle of groups. Groups link together histograms (in accord with underlying source tree), 
// a group bundle links together groups, again obeying the undelying chemical connectivity

@interface histogramGroupBundle : NSObject 
{
@public
	NSMutableArray *memberGroups ;
	
	histogramBundle *hostBundle ;

}

- (id) initWithGroups:(NSArray *)grps inHistogramBundle:(histogramBundle *)hBundle  ;

+ (NSArray *) allGroupBundlesFromHistogramBundle:(histogramBundle *)hBundle 
		useGroups:(BOOL)useGroups bigFragmentSize:(int)bigFSize maxBigFragmentCount:(int)maxBigFCount ;

+ (BOOL) advance:(NSArray *)conn ;



@end
