//
//  vector.h
//  MolMon
//
//  Created by zauhar on Mon Feb 25 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#include <math.h>

// This class implements simple defs of a 3D vector and operations on vector. 
// Will be expanded as needed


@interface MMVector3 : NSObject 
{

    double X ;
    double Y ;
    double Z ;

}

+ (MMVector3 *) xAxis ;
+ (MMVector3 *) yAxis ;
+ (MMVector3 *) zAxis ;


- (double) X ;
- (double) Y ;
- (double) Z ;

- (double *) XLoc ;
- (double *) YLoc ;
- (double *) ZLoc ;

- (double) length ;

- (double) dotWith: (MMVector3 *)d ;

- (void) setX : (double) x ;
- (void) setY : (double) y ;
- (void) setZ : (double) z ;

- (id) initX : (double)x Y: (double)y Z: (double)z ;
- (id) initAlong: (MMVector3 *) a perpTo: (MMVector3 *) p ;
- (id) initPerpTo: (MMVector3 *) p byCrossWith: (MMVector3 *) c ;

- (id) initByCrossing:(MMVector3 *)u and:(MMVector3 *)v ;

- (void) scaleBy: (double)s ;

- (void) add:(MMVector3 *)u ;
- (void) subtract:(MMVector3 *)u ;

- (void) normalize ;
- (BOOL) normalizeWithZero: (double) z ;

- (void) coordPointersX: (double *)xp Y:(double *)yp Z:(double *) zp ;

@end
