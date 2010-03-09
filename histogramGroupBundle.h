//
//  histogramGroupBundle.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
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

+ (NSArray *) allGroupBundlesFromHistogramBundle:(histogramBundle *)hBundle ;

+ (BOOL) advance:(NSArray *)conn ;



@end
