//
//  flatSurface.m
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "flatSurface.h"

static int partitionForVote[10] ;
static int votesForPartition[10] ;
static int nPartitionsForVote ;


@implementation flatSurface

- (id) initWithFlatFile: (NSString *)f andTree: (ctTree *) t andSiteFile:(NSString *) s andGridSpacing:(double)del
    {
        FILE *flats ;
		NSString *siteFile ;
		NSScanner *fileScanner ;
        char buffer[1000] ;
        char *word ;
        int i, j, k, count, v1, v2, v3, atomNum, partitionNum ;
        double x, y, z ;
		int *partitionForAtom = nil, fail ;
        
        if( !( self = [ super init ] ) )
            {
                return self ;
            }
            
        if( !( flats = fopen( [ f cString ], "r" ) ) )
            {
                return nil ;
            }
            
			
		theTree = t ;

        fgets( buffer, 1000, flats ) ;
		
		// Make sure it's version 4 (NEW) format
		
		if( ! strstr( buffer, "NEW" ) )
			{
				printf( "MUST USE VERSION 4 (NEW) SURFACE FILE FORMAT!\n" ) ;
				return nil ;
			}
        
        // Get number of vertices
        
        word = strtok( buffer, " \n" ) ;
        
        nVertices = atoi( word ) ;
        
        vertexX = (double *) malloc( nVertices * sizeof( double ) ) ;
		vertexY = (double *) malloc( nVertices * sizeof( double ) ) ;
		vertexZ = (double *) malloc( nVertices * sizeof( double ) ) ;
		
		vertexMEP = ( double * ) malloc( nVertices * sizeof( double ) ) ;
        
        for( i = 0 ; i < nVertices ; ++i )
            {
                fgets( buffer, 1000, flats ) ;
                
                word = strtok( buffer, " \n" ) ;
                vertexX[i] = atof( word ) ;
                
                word = strtok( NULL, " \n" ) ;
                vertexY[i] = atof( word ) ;
                
                word = strtok( NULL, " \n" ) ;
                vertexZ[i] = atof( word ) ;
                
            }
            
        // Get number of elements
        
        fgets( buffer, 1000, flats ) ;
        
        word = strtok( buffer, " \n" ) ;
        
        nElements = atoi( word ) ;
        
        // Number of contact elements
        
        word = strtok( NULL, " \n" ) ;
        
        nContact = atoi( word ) ;
        
		elemVertex0 = (int *) malloc( nElements * sizeof( int ) ) ;
		elemVertex1 = (int *) malloc( nElements * sizeof( int ) ) ;
		elemVertex2 = (int *) malloc( nElements * sizeof( int ) ) ;
		
		normX = ( double * ) malloc( nElements * sizeof( double ) ) ;
		normY = ( double * ) malloc( nElements * sizeof( double ) ) ;
		normZ = ( double * ) malloc( nElements * sizeof( double ) ) ;
		
		axisU = ( double ** ) malloc( nElements * sizeof( double * ) ) ;
		axisV = ( double ** ) malloc( nElements * sizeof( double * ) ) ;
		
		int iElem ;
		
		for( iElem = 0 ; iElem < nElements ; ++iElem )
			{
				axisU[iElem] = (double *) malloc( 3 * sizeof( double ) ) ;
				axisV[iElem] = (double *) malloc( 3 * sizeof( double ) ) ;
			}
				
		
		
		type = ( elemType * ) malloc( nElements * sizeof( elemType ) ) ;
		
		elemSelfIntersecting = (BOOL *) malloc( nElements * sizeof( BOOL ) ) ;
		elemActive = (BOOL *) malloc( nElements * sizeof( BOOL ) ) ;
		
		nAtomsForElement = (int *) malloc( nElements * sizeof( int ) ) ;
		elementAtoms = (int **) malloc( nElements * sizeof( int * ) ) ;
		
		partitionForElement = (int *) malloc( nElements * sizeof( int ) ) ;
		
        count = 0 ;
        
        for( i = 0 ; i < nElements ; ++i )
            {                
                fgets( buffer, 1000, flats ) ;
				               
                word = strtok( buffer, " \n" ) ;
                v1 = atoi( word ) ;
                
                word = strtok( NULL, " \n" ) ;
                v2 = atoi( word ) ;
                
                word = strtok( NULL, " \n" ) ;
                v3 = atoi( word ) ;
				
				elemVertex0[i] = v1 ;
				elemVertex1[i] = v2 ;
				elemVertex2[i] = v3 ;
				
                word = strtok( NULL, " \n" ) ;
                x = atof( word ) ;
                
                word = strtok( NULL, " \n" ) ;
                y = atof( word ) ;
                
                word = strtok( NULL, " \n" ) ;
                z = atof( word ) ;
				
				normX[i] = x ;
				normY[i] = y ;
				normZ[i] = z ;
				
				// Set the axisU and axisV vectors. Axis U is set parallel to the longest of 
				// v2 - v1, v3 - v1 
				
				double dx = vertexX[ elemVertex1[i] ] - vertexX[ elemVertex0[i] ] ;
				double dy = vertexY[ elemVertex1[i] ] - vertexY[ elemVertex0[i] ] ;
				double dz = vertexZ[ elemVertex1[i] ] - vertexZ[ elemVertex0[i] ] ;
				
				axisU[i][0] = dx ;
				axisU[i][1] = dy ;
				axisU[i][2] = dz ;
				
				double length1 = sqrt( dx*dx + dy*dy + dz*dz ) ;
				
				dx = vertexX[ elemVertex2[i] ] - vertexX[ elemVertex0[i] ] ;
				dy = vertexY[ elemVertex2[i] ] - vertexY[ elemVertex0[i] ] ;
				dz = vertexZ[ elemVertex2[i] ] - vertexZ[ elemVertex0[i] ] ;
				
				double length2 = sqrt( dx*dx + dy*dy + dz*dz ) ;
				
				if( length2 > length1 )
					{
						axisU[i][0] = dx ;
						axisU[i][1] = dy ;
						axisU[i][2] = dz ;
						
						length1 = length2 ;
					}
					
				axisU[i][0] /= length1 ;
				axisU[i][1] /= length1 ;
				axisU[i][2] /= length1 ;
				
				// Cross norm X axisU to yield axisV (should be normalized)
				
				axisV[i][0] = normY[i]*axisU[i][2] - axisU[i][1]*normZ[i] ;
				axisV[i][1] = normZ[i]*axisU[i][0] - axisU[i][2]*normX[i] ;
				axisV[i][2] = normX[i]*axisU[i][1] - axisU[i][0]*normY[i] ;
               
                word = strtok( NULL, " \n" ) ;
				
                type[i] = (elemType) atoi( word ) ;
								
				word = strtok( NULL, " \n" ) ;
				
				int atomCount ;
				
				atomCount = atoi( word ) ;
				
				nAtomsForElement[i] = atomCount ;
				
				elementAtoms[i] = (int *) malloc( atomCount * sizeof( int ) ) ;
				
				int jA ;
				
				for( jA = 0 ; jA < atomCount ; ++jA )
					{
						word = strtok( NULL, " \n" ) ;
						elementAtoms[i][jA] = atoi( word ) ;
					}
                
                // Last symbol on line is N or S
				
				word = strtok( NULL, " \n" ) ;
				
				if( word[0] == 'N' )
					{
						elemSelfIntersecting[i] = NO ;
					}
				else if( word[0] == 'S' )
					{
						elemSelfIntersecting[i] = YES ;
					}
				else
					{
						printf( "COULD NOT READ SURFACE FILE!\n" ) ;
						return nil ;
					}
					
				// Sites file?
				
				if( s )
					{
						elemActive[i] = NO ;
					}
				else
					{
						elemActive[i] = YES ;
					}
                
            }
            
        fclose( flats ) ;
		
		// Compute MEP at each vertex
		
		
		for( i = 0 ; i < nVertices ; ++i )	
			{
				vertexMEP[i] = 0. ;
				
				int jN ;
				
				for( jN = 0 ; jN < t->nNodes ; ++jN )
					{
						double dx = vertexX[i] - t->nodes[jN]->coord[0] ;
						double dy = vertexY[i] - t->nodes[jN]->coord[1] ;
						double dz = vertexZ[i] - t->nodes[jN]->coord[2] ;
						
						double d = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						if( d < 1.e-4 )
							{
								printf( "WARNING: CHARGE VERY CLOSE TO VERTEX! - Skipping ...\n" ) ;
								continue ;
							}
						
						vertexMEP[i] += t->nodes[jN]->charge / d ;
					}
			}
        
		
		if( s )
			{
				haveDeadSurface = NO ;
				
				// Need to set up site atom array
				
				// We will assume that atoms are numbered starting at 1 in the file
				
				siteFile = [ NSString stringWithContentsOfFile:s ] ;
				
				if( ! siteFile ) return nil ;
				
				fileScanner = [ NSScanner scannerWithString:siteFile ] ;
				
				[ fileScanner setCharactersToBeSkipped:[ NSCharacterSet whitespaceAndNewlineCharacterSet ] ] ;
				
				// Note that atoms in the file are assumed indexed starting at 1 
				
				partitionForAtom = (int *) malloc( t->nNodes * sizeof( int ) ) ;
				
				// Assign all atoms to default (inactive) site with index -1 
				
				for( i = 0 ; i <= t->nNodes ; ++i )
					{
						partitionForAtom[i] = -1 ;
					}
				
				// Format: <atom index> <partition>
				// Partitions start at 1 (to match my assumption about fragments - why oh why?)
				
				while( [ fileScanner scanInt:&atomNum ] == YES )
					{
						if( [ fileScanner scanInt:&partitionNum ] == NO )
							{
								printf( "ERROR - Site file format messed up!\n" ) ;
								return nil ;
							}
							
						partitionForAtom[ atomNum - 1 ] = partitionNum ;
					}
					
				if( [ fileScanner isAtEnd ] == NO )
					{
						printf( "ERROR - Site file format messed up!\n" ) ;
						return nil ;
					}
					
				// Set each element as being in the site or not.  At least one of the atoms for an element
				// must be assigned to a partition. The partition with the most votes wins
				
				// Instead of vote, find closest distance to elem midpoint
				
				for( i = 0 ; i < nElements ; ++i )
					{
						fail = NO ;
												
						double xc = (vertexX[elemVertex0[i]] + vertexX[elemVertex1[i]] + vertexX[elemVertex2[i]])/3. ;
						double yc = (vertexY[elemVertex0[i]] + vertexY[elemVertex1[i]] + vertexY[elemVertex2[i]])/3. ;
						double zc = (vertexZ[elemVertex0[i]] + vertexZ[elemVertex1[i]] + vertexZ[elemVertex2[i]])/3. ;
						
						double minDist = 1.e12 ;
						int minPartition = -1 ;
						
						//[ flatSurface clearPartitionsForVote ] ;
						
						for( j = 0 ; j < nAtomsForElement[i] ; ++j )
							{
								int jAtom = elementAtoms[i][j] ;
								int p = partitionForAtom[ jAtom ] ;
								
								if( p > 0 ) 
									{
										
										double dx = xc - theTree->nodes[jAtom]->coord[0] ;
										double dy = yc - theTree->nodes[jAtom]->coord[1] ;
										double dz = zc - theTree->nodes[jAtom]->coord[2] ;
										
										double d = dx*dx + dy*dy + dz*dz ;
										
										if( d < minDist )
											{
												minDist = d ;
												minPartition = p ;
											}
										
										//[ flatSurface addVoteForPartition:p ] ;
									}
								else
									{
										fail = YES ;
										break ;
									}
							}
									
						if( fail == NO )
							{
								elemActive[i] = YES ;
								//partitionForElement[i] = [ flatSurface winningPartition ] ;
								partitionForElement[i] = minPartition ;
							}
						else
							{
								elemActive[i] = NO ;
								haveDeadSurface = YES ;
							}
					}
					
				// Done with siteAtom array
				
				free( partitionForAtom ) ;
				
				// Make siteContactElems array
				
				if( haveDeadSurface == YES )	
					{
						siteContactElems = (int *) malloc( nContact * sizeof( int ) ) ;
						
						nSiteContactElems = 0 ;
						
						for( i = 0 ; i < nContact ; ++i )
							{
								if( type[i] != CONTACT ) continue ;
								
								if( elemActive[i] == NO ) continue ;
								
								siteContactElems[nSiteContactElems] = i ;
								
								++nSiteContactElems ;
							}
					}
				else
					{
						haveDeadSurface = NO ;
				
						siteContactElems = nil ;
						
						nSiteContactElems = 0 ;
					}
			}
		else
			{
				haveDeadSurface = NO ;
				
				siteContactElems = nil ;
				
				nSiteContactElems = 0 ;
			}
			
			
		// Also, assign fragment to element - use majority vote
		
		// ONLY do this if sites not in use! Otherwise we assume a "big" molecule not
		// amenable to fragmentation
		
		if( s ) return self ;
		
		//[ t  assignNodesToFragments ] ;
		
		ctNode **theNodes = t->nodes ;
		
		// Assume 1-1 coorespondance between atom indices for elements and nodes in the tree
		
		for( i = 0 ; i < nElements ; ++i )
			{
				//[ flatSurface clearPartitionsForVote ] ;
				
				double xc = (vertexX[elemVertex0[i]] + vertexX[elemVertex1[i]] + vertexX[elemVertex2[i]])/3. ;
				double yc = (vertexY[elemVertex0[i]] + vertexY[elemVertex1[i]] + vertexY[elemVertex2[i]])/3. ;
				double zc = (vertexZ[elemVertex0[i]] + vertexZ[elemVertex1[i]] + vertexZ[elemVertex2[i]])/3. ;
				
				double minDist = 1.e12 ;
				int minPartition = -1 ;
				
				for( j = 0 ; j < nAtomsForElement[i] ; ++j )
					{
						int jAtom = elementAtoms[i][j] ;
						int p = (theNodes[ jAtom ])->fragmentIndex ;
						
						double dx = xc - theTree->nodes[jAtom]->coord[0] ;
						double dy = yc - theTree->nodes[jAtom]->coord[1] ;
						double dz = zc - theTree->nodes[jAtom]->coord[2] ;
						
						double d = dx*dx + dy*dy + dz*dz ;
						
						if( d < minDist )
							{
								minDist = d ;
								minPartition = p ;
							}
							
						//[ flatSurface addVoteForPartition:p ] ;
						
					}
					
				//partitionForElement[i] = [ flatSurface winningPartition ] ;
				partitionForElement[i] = minPartition ;
							
			}
			
		// Set up a grid over the molecule
		
       delta = del ;
        
        // Scan through atoms, get min and max coords
        
        double maxX = -1000000. ;
        double maxY = -1000000. ;
        double maxZ = -1000000. ;
        
        xMin = 1000000. ;
        yMin = 1000000. ;
        zMin = 1000000. ;
        
        for( i = 0 ; i < nElements ; ++i )
            {
               double x = vertexX[ elemVertex0[i] ] ;
               double y = vertexY[ elemVertex0[i] ] ;
               double z = vertexZ[ elemVertex0[i] ] ;
               
               if( x < xMin ) xMin = x ;
               if( y < yMin ) yMin = y ;
               if( z < zMin ) zMin = z ;
               
               if( x > maxX ) maxX = x ;
               if( y > maxY ) maxY = y ;
               if( z > maxZ ) maxZ = z ;
              
               x = vertexX[ elemVertex1[i] ] ;
               y = vertexY[ elemVertex1[i] ] ;
               z = vertexZ[ elemVertex1[i] ] ;
               
               if( x < xMin ) xMin = x ;
               if( y < yMin ) yMin = y ;
               if( z < zMin ) zMin = z ;
               
               if( x > maxX ) maxX = x ;
               if( y > maxY ) maxY = y ;
               if( z > maxZ ) maxZ = z ;
               
               x = vertexX[ elemVertex2[i] ] ;
               y = vertexY[ elemVertex2[i] ] ;
               z = vertexZ[ elemVertex2[i] ] ;
               
               if( x < xMin ) xMin = x ;
               if( y < yMin ) yMin = y ;
               if( z < zMin ) zMin = z ;
               
               if( x > maxX ) maxX = x ;
               if( y > maxY ) maxY = y ;
               if( z > maxZ ) maxZ = z ;
               
            }
              
        // Allocate the grid->element array
        // Note that nX,Y,Z hold the maximum grid coordinate - number of cubes
        // in a given direction is one more than this
        
        nX = (int)floor( (maxX - xMin)/delta  ) ;
        nY = (int)floor( (maxY - yMin)/delta  ) ;
        nZ = (int)floor( (maxZ - zMin)/delta  ) ;
        
        gridToElem = ( elementCollection ****) malloc( (nX + 1)*sizeof( elementCollection *** ) ) ;
        
       
        
         for( i = 0 ; i <= nX ; ++i )
            {
                gridToElem[i] = ( elementCollection ***) malloc( (nY + 1)*sizeof( elementCollection ** ) ) ;
            
                for( j = 0 ; j <=nY ; ++j )
                    {
                        gridToElem[i][j] = ( elementCollection **) malloc( (nZ + 1)*sizeof( elementCollection * ) ) ;
                        
                        for( k = 0 ; k <=nZ ; ++k )
                            {
                                gridToElem[i][j][k] = [ [ elementCollection alloc ] init ] ;
                            }
                    }
            }
                
        // Assign elements to the grid
        
        
        for( i = 0 ; i < nElements ; ++i )
            {
                int iGridMin = 1000000 ;
                int iGridMax = -1000000 ;
                
                int jGridMin = 1000000 ;
                int jGridMax = -1000000 ;
                
                int kGridMin = 1000000 ;
                int kGridMax = -1000000 ;
				
				int iGrid, jGrid, kGrid ;
				
				int *vertexByIndex[3] ;
				
				vertexByIndex[0] = elemVertex0 ;
				vertexByIndex[1] = elemVertex1 ;
				vertexByIndex[2] = elemVertex2 ;
                
                
                for( j = 0 ; j < 3 ; ++j )
                    {
                        iGrid = (int)floor( (vertexX[ vertexByIndex[j][i] ] - xMin)/delta ) ;
                        jGrid = (int)floor( (vertexY[ vertexByIndex[j][i] ] - yMin)/delta ) ;
                        kGrid = (int)floor( (vertexZ[ vertexByIndex[j][i] ] - zMin)/delta ) ;
                        
                        if( iGrid > iGridMax ) iGridMax = iGrid ;
                        if( iGrid < iGridMin ) iGridMin = iGrid ;
                        
                        if( jGrid > jGridMax ) jGridMax = jGrid ;
                        if( jGrid < jGridMin ) jGridMin = jGrid ;
                        
                        if( kGrid > kGridMax ) kGridMax = kGrid ;
                        if( kGrid < kGridMin ) kGridMin = kGrid ;
                    }

				for( iGrid = iGridMin ; iGrid <=iGridMax ; ++iGrid )
					{
						for( jGrid = jGridMin ; jGrid <=jGridMax ; ++jGrid )
							{
								for( kGrid = kGridMin ; kGrid <=kGridMax ; ++kGrid )
									{                                                            
										[ gridToElem[iGrid][jGrid][kGrid]
											addIndex:i ] ;
																						
									}
							}
					}
                    
            }
		

			
        // I think that's it
        
        return self ;
        
    }
	
- (void) dealloc
	{
		free( vertexX ) ;
		free( vertexY ) ;
		free( vertexZ ) ;
		
		free( vertexMEP ) ;
		
		int i, j, k ;
		
		for( j = 0 ; j < nElements ; ++j )
			{
				free( axisU[j] ) ;
				free( axisV[j] ) ;
			}
			
		free( axisU ) ;
		free( axisV ) ;
		
		free( elemVertex0 ) ;
		free( elemVertex1 ) ;
		free( elemVertex2 ) ;
		
		free( normX ) ;
		free( normY ) ;
		free( normZ ) ;
		
		free( type ) ;
		
		free( elemSelfIntersecting ) ;
		free( elemActive ) ;
		
		for( j = 0 ; j < nElements ; ++j )
			{
				free( elementAtoms[j] ) ;
			}
			
		free( elementAtoms ) ;
		
		free( partitionForElement ) ;
		
		if( siteContactElems ) free( siteContactElems ) ;
		
		
		for( i = 0 ; i <= nX ; ++i )
            {
               for( j = 0 ; j <= nY ; ++j )
                    {
                        for( k = 0 ; k <= nZ ; ++k )
                            {
                                [ gridToElem[i][j][k] release ] ; 
                            }
							
						free( gridToElem[i][j] ) ;
                    }
				free( gridToElem[i] ) ;
            }
			
		[ super dealloc ] ;
		
		return ;
	}
			


+ (void) clearPartitionsForVote
	{
		nPartitionsForVote = 0 ;
		
		return ;
	}
	
+ (void) addVoteForPartition:(int)p
	{
		int i ;
		int found = -1 ;
		
		for( i = 0 ; i < nPartitionsForVote ; ++i )
			{
				if( partitionForVote[i] == p )
					{
						found = i ;
						break ;
					}
			}
			
		if( found < 0 )
			{
				// New partition to vote for
				
				if( nPartitionsForVote == 10 )
					{
						printf( "WARNING: TOO MANY PARTITIONS DEFINED FOR ONE ELEMENT! - Ignored ...\n" ) ;
						return ;
					}
				
				partitionForVote[nPartitionsForVote] = p ;
				
				votesForPartition[nPartitionsForVote] = 1 ;
				
				++nPartitionsForVote ;
				
				
			}
		else
			{
				++votesForPartition[found] ;
			}
			
			
		return ;
	}
	
+ (int) winningPartition
	{
		int pMax = -1 ;
		int maxVote = 0 ;
		int i ;
		
		for( i = 0 ; i < nPartitionsForVote ; ++i )
			{
				if( votesForPartition[i] > maxVote )
					{
						maxVote = votesForPartition[i] ;
						pMax = partitionForVote[i] ;
					}
			}
			
		return pMax ;
	}
	
+ (double) determinant:(double *[3][3])mat 
    {
        double det ;
        
        det = (*(mat[0][0]))*( (*(mat[1][1]))*(*(mat[2][2])) - (*(mat[2][1]))*(*(mat[1][2])) )
            - (*(mat[0][1]))*( (*(mat[1][0]))*(*(mat[2][2])) - (*(mat[2][0]))*(*(mat[1][2])) )
            + (*(mat[0][2]))*( (*(mat[1][0]))*(*(mat[2][1])) - (*(mat[2][0]))*(*(mat[1][1])) ) ;
            
        return det ;
    }

				
- (void) position:(double [])p andMEP:(double *)mep inElement:(int)idx forR:(double)r S:(double)s
	{
		// This just returns position vector corresponding to local coordinate in an element
		
		
		int v0 = elemVertex0[idx] ;
		int v1 = elemVertex1[idx] ;
		int v2 = elemVertex2[idx] ;
        
        p[0] = (1. - r - s)*vertexX[v0] + r*vertexX[v1] + s*vertexX[v2] ;
        p[1] = (1. - r - s)*vertexY[v0] + r*vertexY[v1] + s*vertexY[v2] ;
        p[2] = (1. - r - s)*vertexZ[v0] + r*vertexZ[v1] + s*vertexZ[v2] ;
		
		*mep = (1. - r - s)*vertexMEP[v0] + r*vertexMEP[v1] + s*vertexMEP[v2] ;
                
        return ;
	}
	
	
- (BOOL) assignNearestIntersectionToElem:(int *)interElem 
                andPoint:(double [])interPoint andR:(double *)R andS:(double *)S andMEP:(double *)m
                usingStart:(double [])start 
                andDirection:(double [])dir fromElementWithIndex:(int)index
                withRayTraceType:(BOOL)inner
	{
	
		// This algorithm:
		
		// Identify cube by iCube, jCube, kCube; e.g. iCube = floor((x - xMin)/delta)
		// 
		// Identify position with cube by relative cube coordinates: e.g. iRel = (x - Xmin)/delta - iCube 
		//
		// From current cube (defined by cube and relative coordinates), advance to next cube intersected by ray
		
		// Ray direction: u = (ux, uy, uz)
		
		// if( ux > 0 )
		//		delX = ((1 - iRel)*delta)/abs(ux)
		// else
		//		delX = (iRel*delta)/abs(ux)
		//
		// Likewise for delY, delZ
		
		// Choose del = min(delX, delY, delZ)
		//
		//	x = x + del*ux, y = y + del*uy, z = z + del*uz
		// Sanity check: delX is min, and ux > 0, then new iCube = old iCube + 1, else new iCube = old iCube - 1
		
		
        
        int i ; 
        static short *testIntersect = NULL ;
        double TOL ;
        double currentX, currentY, currentZ ;
		double startX, startY, startZ ;
        double tClosest, dot, denom, r, s, tInter ;
        elementCollection *cubeElementCollection ;
        int elemID, elemClosest ;
        double rClosest, sClosest ;

        double x1, y1, z1, x2, y2, z2, x3, y3, z3 ; 
        double dirX, dirY, dirZ ;
		static double mdirX, mdirY, mdirZ ;
        static double x2minusx1, y2minusy1, z2minusz1, x3minusx1, y3minusy1, z3minusz1,
            startXminusx1, startYminusy1, startZminusz1 ;
        
        static double *denomMat[3][3] = {{ &x2minusx1, &x3minusx1, &mdirX },
                                         { &y2minusy1, &y3minusy1, &mdirY },
                                         { &z2minusz1, &z3minusz1, &mdirZ } } ;
                                  
        static double *rNumerator[3][3] = { { &startXminusx1, &x3minusx1, &mdirX },
                                            { &startYminusy1, &y3minusy1, &mdirY },
                                            { &startZminusz1, &z3minusz1, &mdirZ } } ;
                                     
        static double *sNumerator[3][3] = {{ &x2minusx1, &startXminusx1, &mdirX },
                                           { &y2minusy1, &startYminusy1, &mdirY },
                                           { &z2minusz1, &startZminusz1, &mdirZ } } ;
                                    
        static double *tNumerator[3][3] = {{ &x2minusx1, &x3minusx1, &startXminusx1 },
                                           { &y2minusy1, &y3minusy1, &startYminusy1 },
                                           { &z2minusz1, &z3minusz1, &startZminusz1 } } ;
                                    
                                     
        
        // This variable determines when we reject an intersection test owing to numerical
        // problems. 
		
		// This is basically disabled
        
        TOL = 0.0000 ;
        
        // Zero out intersection test
        
        if( ! testIntersect )
            {
                testIntersect = (short *) malloc( nElements * sizeof( short ) ) ;
            }
        
        for( i = 0 ; i < nElements ; ++i )
            {
                testIntersect[i] = FALSE ;
            }
            
        // Don't test for intersection with the source element!!!
        
        testIntersect[index] = TRUE ;
                    
        // Collect all cubes along ray. Test for intersection with all elements in cubes
        
		int iCubeCurrent, jCubeCurrent, kCubeCurrent ;
		double iRelCurrent, jRelCurrent, kRelCurrent ;
        
        currentX = start[0] ;
        currentY = start[1] ;
        currentZ = start[2] ;
		
		startX = currentX ;
		startY = currentY ;
		startZ = currentZ ;
		
		iCubeCurrent = floor(( currentX - xMin )/delta) ;
		jCubeCurrent = floor(( currentY - yMin )/delta) ;
		kCubeCurrent = floor(( currentZ - zMin )/delta) ;
		
		iRelCurrent = ( currentX - xMin )/delta - iCubeCurrent ;
		jRelCurrent = ( currentY - yMin )/delta - jCubeCurrent ;
		kRelCurrent = ( currentZ - zMin )/delta - kCubeCurrent ;
		
        // Direction (assumed normalized!!)
        
        dirX = dir[0] ;
        dirY = dir[1] ;
        dirZ = dir[2] ;
		
        mdirX = -dirX ;
        mdirY = -dirY ;
        mdirZ = -dirZ ;
		
		// Adjust cube index and relative position in cube to take into account ray direction. 
		// Only an issue if we are starting exactly on a cube boundary
		
		if( iRelCurrent == 0. && dirX < 0. )
			{
				iRelCurrent = 1. ;
				--iCubeCurrent ;
			}
			
		if( jRelCurrent == 0. && dirY < 0. )
			{
				jRelCurrent = 1. ;
				--jCubeCurrent ;
			}

		if( kRelCurrent == 0. && dirZ < 0. )
			{
				kRelCurrent = 1. ;
				--kCubeCurrent ;
			}
		
        while( TRUE )
            {
                // For each element in current grid cube, test for intersection
                
                // Mathematics for the intersection test is pretty straightforward. 
                //
                // A point along the ray has position
                //
                // posV = startV + t*dirV
                // 
                // where the V stands for vector. Points within a flat element are located by
                // linear interpolation, using local coordinates r and s (with r,s >= 0 and
                // r + s <= 1 to stay inside the element).
                //
                // elemPosV = (1 - r - s)*vert1V + r*vert2V + s*vert3V
                //     where vert1,2,3V are the positions of the three vertices of the element.
                //
                // To find a potential intersection, find r, s and t such that
                //
                // posV = elemPosV or
                //
                // startV + t*dirV = (1 - r - s)*vert1V + r*vert2V + s*vert3V
                //
                //
                // Rewriting the preceding for separate x, y and z components leads to three
                // equations in three uknowns, which we solve by Cramer's rule. 
                //
                // The "potential" intesection is real if r,s >= 0 and (r + s) <= 1, AND if
                //
                // <dirV,elemNorm> > 0. AND inner=TRUE 
                //    OR
                // <dirV,elemNorm> < 0. AND inner=FALSE
                //
                
                cubeElementCollection = gridToElem[iCubeCurrent][jCubeCurrent][kCubeCurrent] ;
				
				int *cubeElementIndices = [ cubeElementCollection indices ] ;
                
                // Keep track of closest intersection
        
                tClosest = 1000000. ;
                
                elemClosest = -1 ;
				
				int jElem ;
				
                for( jElem = 0 ; jElem < [ cubeElementCollection count ] ; ++jElem  )
                    {
						elemID = cubeElementIndices[ jElem ] ;
                    
                        if( testIntersect[ elemID  ] )
                            {
                                //goto NEXT_ELEM ;
								continue ;
                            }
                        else
                            {
                                testIntersect[ elemID ] = TRUE ;
                            }
                            
                        // Check that this element has correct orientation
						
						dot = dir[0]*normX[elemID] + dir[1]*normY[elemID] + dir[2]*normZ[elemID] ;
                        
                         
                        if( inner )
                            {
                                if( dot <= 0. ) /*goto NEXT_ELEM*/ continue ;
                            }
                        else
                            {
                                if( dot >= 0. ) /*goto NEXT_ELEM*/ continue ;
                            }
                        
						
                        // Compute potential intersection
						
						int v0 = elemVertex0[elemID] ;
						int v1 = elemVertex1[elemID] ;
						int v2 = elemVertex2[elemID] ;
                        
						x1 = vertexX[ v0 ] ;
						y1 = vertexY[ v0 ] ;
						z1 = vertexZ[ v0 ] ;
                        //x1 = [ [ elemID vert1 ] X ] ;
                        //y1 = [ [ elemID vert1 ] Y ] ;
                        //z1 = [ [ elemID vert1 ] Z ] ;
                        
						x2 = vertexX[ v1 ] ;
						y2 = vertexY[ v1 ] ;
						z2 = vertexZ[ v1 ] ;
                        //x2 = [ [ elemID vert2 ] X ] ;
                        //y2 = [ [ elemID vert2 ] Y ] ;
                        //z2 = [ [ elemID vert2 ] Z ] ;
						
                        x3 = vertexX[ v2 ] ;
						y3 = vertexY[ v2 ] ;
						z3 = vertexZ[ v2 ] ;
                        //x3 = [ [ elemID vert3 ] X ] ;
                        //y3 = [ [ elemID vert3 ] Y ] ;
                        //z3 = [ [ elemID vert3 ] Z ] ;
                        
                        x2minusx1 = x2 - x1 ;
                        y2minusy1 = y2 - y1 ;
                        z2minusz1 = z2 - z1 ;
                        
                        x3minusx1 = x3 - x1 ;
                        y3minusy1 = y3 - y1 ;
                        z3minusz1 = z3 - z1 ;
                        
                        startXminusx1 = startX - x1 ;
                        startYminusy1 = startY - y1 ;
                        startZminusz1 = startZ - z1 ;
                        
                        denom = [ flatSurface determinant:denomMat ] ;
                        
                        if( fabs(denom) <= TOL )
                            {
                                /*goto NEXT_ELEM*/ continue ;                            
                            }
                            
                        // Compute intersection r, s and t using Cramer's rule
                        
                        tInter = [ flatSurface determinant:tNumerator ]/denom ;
                        
                        if( tInter < 0. )
                            {
                                /*goto NEXT_ELEM*/ continue ;
                            }

                        r = [ flatSurface determinant:rNumerator ]/denom ;
                        
                        if( ( r < 0. ) || ( r > 1. ) )
                            {
                                /*goto NEXT_ELEM*/ continue ;
                            }
                            
                        s = [ flatSurface determinant:sNumerator ]/denom ;
                        
                        if( ( s < 0. ) || ( (r + s) > 1. ) )
                            {
                                /*goto NEXT_ELEM*/ continue ;
                            }
                        
                        // Looks like we have a valid intersection
                                                
                        if(  tInter < tClosest  )
                            {
                                tClosest = tInter ;
                                elemClosest = elemID ;
                                rClosest = r ;
                                sClosest = s ;
                            }
                        
//NEXT_ELEM:    
                        //elemListID = [ elemListID next ] ;
                        
                        //if( elemListID )
                        //    {
                        //        elemID = [ elemListID entry ] ;
						//   }
                        //else
                        //    {
                        //        break ;
                        //    }
                    }
                    
                // See if we had any intersections from that cube:

                if( elemClosest >= 0 )
                    {
						/*
                        dot = [ vector dotBetween:dir and:[ elemClosest norm ] ] ;
                        
                        
                        
                        if( inner )
                            {
                                if( dot <= 0. ) return 0 ;
                            }
                        else
                            {
                                if( dot >= 0. ) return 0 ;
                            }
						*/
                        // We are all done with this function 
                        
						double mep ;
						
						[ self position:interPoint andMEP:&mep inElement:elemClosest forR:rClosest S:sClosest ] ; 
                        //[ elemClosest assignPoint:interPoint ByR:rClosest S:sClosest ] ;
                        
                        *interElem = elemClosest ;
                        *R = rClosest ;
                        *S = sClosest ;
                        
                        *m = mep ;
                        
                        // All done with this loop
                        
                        return YES ;
                    }
                    
                // Did not find a legal intersection - move to the next cube
		
				double delX, delY, delZ ;
				
				// NOTE that delX,Y,Z are positive quantities
				// delX, e.g., is the displacement required to move to the next X plane of the grid
				
				if( iRelCurrent == 0. )
					{
						// Must have positive X-direction 
						
						if( dirX != 0. )
							{
								delX = delta/fabs(dirX) ;
							}
						else
							{
								delX = 1.e12 ;
							}
					}
				else if( iRelCurrent == 1. )
					{
						// Must have negative X-direction
						
						delX = delta/fabs(dirX) ;
					}
				else  // iRelCurrent between 0. and 1.
					{
						if( dirX >= 0. )
							{
								if( dirX != 0. )
									{
										delX = ((1 - iRelCurrent)*delta)/fabs(dirX) ;
									}
								else
									{
										delX = 1.e12 ;
									}
							}
						else
							{
								delX = (iRelCurrent*delta)/fabs(dirX) ;
							}
					}
				
					
				if( jRelCurrent == 0. )
					{
						// Must have positive Y-direction 
						
						if( dirY != 0. )
							{
								delY = delta/fabs(dirY) ;
							}
						else
							{
								delY = 1.e12 ;
							}
					}
				else if( jRelCurrent == 1. )
					{
						// Must have negative Y-direction
						
						delY = delta/fabs(dirY) ;
					}
				else  // jRelCurrent between 0. and 1.
					{
						if( dirY >= 0. )
							{
								if( dirY != 0. )
									{
										delY = ((1 - jRelCurrent)*delta)/fabs(dirY) ;
									}
								else
									{
										delY = 1.e12 ;
									}
							}
						else
							{
								delY = (jRelCurrent*delta)/fabs(dirY) ;
							}
					}
				
				
				if( kRelCurrent == 0. )
					{
						// Must have positive Z-direction 
						
						if( dirZ != 0. )
							{
								delZ = delta/fabs(dirZ) ;
							}
						else
							{
								delZ = 1.e12 ;
							}
					}
				else if( kRelCurrent == 1. )
					{
						// Must have negative Z-direction
						
						delZ = delta/fabs(dirZ) ;
					}
				else  // kRelCurrent between 0. and 1.
					{
						if( dirZ >= 0. )
							{
								if( dirZ != 0. )
									{
										delZ = ((1 - kRelCurrent)*delta)/fabs(dirZ) ;
									}
								else
									{
										delZ = 1.e12 ;
									}
							}
						else
							{
								delZ = (kRelCurrent*delta)/fabs(dirZ) ;
							}
					}
				
					
				int useDir ; // = 1 for X, 2 for Y, 3 for Z
				double del ;
				
				del = delX ;
				useDir = 1 ;
				
				if( delY < del )
					{
						useDir = 2 ;
						del = delY ;
					}
					
				if( delZ < del )
					{
						useDir = 3 ;
						del = delZ ;
					}
					
				switch( useDir )
					{
						case 1:
						
							currentY = currentY + del*dirY ;
							currentZ = currentZ + del*dirZ ;
							
							jCubeCurrent = floor(( currentY - yMin )/delta) ;
							kCubeCurrent = floor(( currentZ - zMin )/delta) ;
							
							jRelCurrent = ( currentY - yMin )/delta - jCubeCurrent ;
							kRelCurrent = ( currentZ - zMin )/delta - kCubeCurrent ;
							
							// Unlikely scenario, but let's handle it (simultaneous crossing of grid boundary along two different axes)
							
							if( jRelCurrent == 0. && dirY < 0. )
								{
									--jCubeCurrent ;
									jRelCurrent = 1. ;
								}
								
							if( kRelCurrent == 0. && dirZ < 0. )
								{
									--kCubeCurrent ;
									kRelCurrent = 1. ;
								}
								
						
							if( dirX > 0. )
								{
									
									iCubeCurrent = iCubeCurrent + 1 ;	// Avoid any precision problems
									currentX = iCubeCurrent*delta + xMin ;
									iRelCurrent = 0. ;
									
								}
							else
								{
									iCubeCurrent = iCubeCurrent - 1 ;	// Avoid any precision problems
									currentX = iCubeCurrent*delta + xMin + delta ;  // Far side of cube!
									iRelCurrent = 1. ;							
								}
								
							break ;
					
						case 2:
						
							currentX = currentX + del*dirX ;
							currentZ = currentZ + del*dirZ ;
							
							iCubeCurrent = floor(( currentX - xMin )/delta) ;
							kCubeCurrent = floor(( currentZ - zMin )/delta) ;
							
							iRelCurrent = ( currentX - xMin )/delta - iCubeCurrent ;
							kRelCurrent = ( currentZ - zMin )/delta - kCubeCurrent ;
							
							// Unlikely scenario, but let's handle it (simultaneous crossing of grid boundary along two different axes)
							
							if( iRelCurrent == 0. && dirX < 0. )
								{
									--iCubeCurrent ;
									iRelCurrent = 1. ;
								}
								
							if( kRelCurrent == 0. && dirZ < 0. )
								{
									--kCubeCurrent ;
									kRelCurrent = 1. ;
								}
							
						
							if( dirY > 0. )
								{
									
									jCubeCurrent = jCubeCurrent + 1 ;	// Avoid any precision problems
									currentY = jCubeCurrent*delta + yMin ;
									jRelCurrent = 0. ;
									
								}
							else
								{
									jCubeCurrent = jCubeCurrent - 1 ;	// Avoid any precision problems
									currentY = jCubeCurrent*delta + yMin + delta ;
									jRelCurrent = 1. ;							
								}
								
							break ;
						
						case 3:
						
							currentX = currentX + del*dirX ;
							currentY = currentY + del*dirY ;
							
							iCubeCurrent = floor(( currentX - xMin )/delta) ;
							jCubeCurrent = floor(( currentY - yMin )/delta) ;
							
							iRelCurrent = ( currentX - xMin )/delta - iCubeCurrent ;
							jRelCurrent = ( currentY - yMin )/delta - jCubeCurrent ;
						
							// Unlikely scenario, but let's handle it (simultaneous crossing of grid boundary along two different axes)
							
							if( iRelCurrent == 0. && dirX < 0. )
								{
									--iCubeCurrent ;
									iRelCurrent = 1. ;
								}
								
							if( jRelCurrent == 0. && dirY < 0. )
								{
									--jCubeCurrent ;
									jRelCurrent = 1. ;
								}
						
							if( dirZ > 0. )
								{
									
									kCubeCurrent = kCubeCurrent + 1 ;	// Avoid any precision problems
									currentZ = kCubeCurrent*delta + zMin ;
									kRelCurrent = 0. ;
									
								}
							else
								{
									kCubeCurrent = kCubeCurrent - 1 ;	// Avoid any precision problems
									currentZ = kCubeCurrent*delta + zMin + delta ;
									kRelCurrent = 1. ;							
								}
								
							break ;
								
					}
							
							
				if( ( iCubeCurrent > nX ) || ( jCubeCurrent > nY ) || ( kCubeCurrent > nZ ) ||
					( iCubeCurrent < 0 )  || ( jCubeCurrent < 0)   || ( kCubeCurrent < 0 ))
					{
						// Failure!!
						
						*interElem = -1 ;
						
						return NO ;
					}
					
			}
            
        // Should never reach this point!
            
        return NO ;
                        
    }

- (void) assignReflectionDirectionTo:(double [])reflectDirect
					usingDirection:(double [])direction andRandomization:(double)randAngle 
					atIntersectElem:(int)elem 
	{
        unsigned long int divisor = 2147483648 ;
        
        
        double dotn, dotu, dotv, theta, phi, aop ;
        double dotDir, dotW, dotY, x, y, z, length ;
		
		double axisW[3], axisY[3], tempDir[3] ;
        
        
        // Get components of incoming ray along the three element axes
        
		dotn = normX[elem]*direction[0] + normY[elem]*direction[1] + normZ[elem]*direction[2] ;
        //dotn = [ vector dotBetween:norm  and:direction ] ;
		
        //dotu = [ vector dotBetween:axisU and:direction ] ;
		dotu = axisU[elem][0]*direction[0] + axisU[elem][1]*direction[1] + axisU[elem][2]*direction[2] ;
		
        //dotv = [ vector dotBetween:axisV and:direction ] ;
		dotv = axisV[elem][0]*direction[0] + axisV[elem][1]*direction[1] + axisV[elem][2]*direction[2] ;
       
        // Reflected direction
                 
        dotn = -dotn ;
        
        // Angle above plane
        
        aop = ( acos(-1.)/2. ) - acos(-dotn) ;
        
        if( (randAngle == 0.) || (aop <= randAngle) )
            {
				reflectDirect[0] = dotu*axisU[elem][0] + dotv*axisV[elem][0] + dotn*normX[elem] ;
				reflectDirect[1] = dotu*axisU[elem][1] + dotv*axisV[elem][1] + dotn*normY[elem] ;
				reflectDirect[2] = dotu*axisU[elem][2] + dotv*axisV[elem][2] + dotn*normZ[elem] ;
				
                //[ reflectDirect setX:( dotu*[ axisU X ] + dotv*[ axisV X ] + dotn*[ norm X ] )
                //                   Y:( dotu*[ axisU Y ] + dotv*[ axisV Y ] + dotn*[ norm Y ] )
                //                   Z:( dotu*[ axisU Z ] + dotv*[ axisV Z ] + dotn*[ norm Z ] ) ] ;
                           
                return ;
            }
        else
            {
                if( dotn < -0.999 )
                    {
                        dotn = -1.0 ;
                        dotu = 0. ;
                        dotv = 0. ;
                        
                        //[ tempDir setX:dotn*[ norm X ]
						//            Y:dotn*[ norm Y ] 
                        //            Z:dotn*[ norm Z ]  ] ;
									 
						tempDir[0] = -normX[elem] ;
						tempDir[1] = -normY[elem] ;
						tempDir[2] = -normZ[elem] ;
						
						axisW[0] = axisU[elem][0] ;
						axisW[1] = axisU[elem][1] ;
						axisW[2] = axisU[elem][2] ;
                                     
                        //[ axisW setEqual:axisU ] ;
                    }
                else
                    {
						tempDir[0] = dotu*axisU[elem][0] + dotv*axisV[elem][0] + dotn*normX[elem] ;
						tempDir[1] = dotu*axisU[elem][1] + dotv*axisV[elem][1] + dotn*normY[elem] ;
						tempDir[2] = dotu*axisU[elem][2] + dotv*axisV[elem][2] + dotn*normZ[elem] ;
						
                        //[ tempDir setX:( dotu*[ axisU X ] + dotv*[ axisV X ] + dotn*[ norm X ] )
                        //             Y:( dotu*[ axisU Y ] + dotv*[ axisV Y ] + dotn*[ norm Y ] )
                        //             Z:( dotu*[ axisU Z ] + dotv*[ axisV Z ] + dotn*[ norm Z ] ) ] ;
						
						// Cross norm X tempDir to yield axisW 
				
						x = normY[elem]*tempDir[2] - tempDir[1]*normZ[elem] ;
						y = normZ[elem]*tempDir[0] - tempDir[2]*normX[elem] ;
						z = normX[elem]*tempDir[1] - tempDir[0]*normY[elem] ;
						
						length = sqrt( x*x + y*y + z*z ) ;
						
						axisW[0] = x / length ;
						axisW[1] = y / length ;
						axisW[2] = z / length ;
                                     
                        //[ axisW setCross:norm By:tempDir ] ;
                        //[ axisW normalize ] ;
                    }
                
				x = axisW[1]*tempDir[2] - tempDir[1]*axisW[2] ;
				y = axisW[2]*tempDir[0] - tempDir[2]*axisW[0] ;
				z = axisW[0]*tempDir[1] - tempDir[0]*axisW[1] ;
				
				length = sqrt( x*x + y*y + z*z ) ;
				
				axisY[0] = x / length ;
				axisY[1] = y / length ;
				axisY[2] = z / length ;
				
				//[ axisY setCross:axisW By:tempDir ] ;
                
                // Choose theta between 0 and randAngle. 
                                    
                theta = (((double)random()/divisor) * randAngle ) ;
                
                phi = (((double)random()/divisor) * 2. * acos(-1.) ) ;
                
                dotDir = cos( theta ) ;
                dotW = sin( theta ) * cos( phi ) ;
                dotY = sin( theta ) * sin( phi ) ;
                
				reflectDirect[0] = dotDir*tempDir[0] + dotW*axisW[0] + dotY*axisY[0] ;
				reflectDirect[1] = dotDir*tempDir[1] + dotW*axisW[1] + dotY*axisY[1] ;
				reflectDirect[2] = dotDir*tempDir[2] + dotW*axisW[2] + dotY*axisY[2] ;
				
                //[ reflectDirect setX:( dotDir*[tempDir X ] + dotW*[ axisW X ] + dotY*[ axisY X ] )
                //                   Y:( dotDir*[tempDir Y ] + dotW*[ axisW Y ] + dotY*[ axisY Y ] )
                //                   Z:( dotDir*[tempDir Z ] + dotW*[ axisW Z ] + dotY*[ axisY Z ] ) ] ;
                                   
                return ;
                
            }
                        
        return ;
    }
		
@end
