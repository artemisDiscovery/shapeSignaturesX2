//
//  scoringScheme.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 6/13/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum { RAW, CORRELATION } scoreType ;

@interface scoringScheme : NSObject {
	// This class represents the scoring technique in place
	
	
	scoreType scoring ;
	
	BOOL useLogistic ;
	
	// For logistic scoring, if enabled
	
	double switchThreshold ;
	double gamma ;

}

//@property (assign, nonatomic) scoreType scoring  ;
//@property (assign, nonatomic) BOOL useLogistic  ;
//@property (assign, nonatomic) double switchThreshold ;
//@property (assign, nonatomic) double gamma ;

- (scoreType) scoring ;
- (BOOL) useLogistic ;
- (double) switchThreshold ;
- (double) gamma ;

- (void) setScoring:(scoreType)s ;
- (void) setUseLogistic:(BOOL)u ;
- (void) setSwitchThreshold:(double)t ;
- (void) setGamma:(double)g ;

@end
