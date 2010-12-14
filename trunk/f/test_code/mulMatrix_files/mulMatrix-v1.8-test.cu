#include <stdio.h>
//#include <cuda.h>
//#include "cuda_runtime_api.h"
//#include <stdint.h>
//#include <stdlib.h>

//This is the working matrix multiplication code - very basic
/*
Done:
- printing of matrix in a more pleasant manner using printMatrix function
- command line arguments
- opens matrix files and reads the matrix successfully
- working array passing from main to auxiliary (loadMatrixFile) function :)
- fixed printing of matrix
- fixed erroneous matrix values by moving loading into host matrix multiplication function!
- basic move towards SN P simulation: multiplication of s0 and Msnp

Problems:
- (fixed)  MatA and MatB values are overlapping and erroneous
*/


// START of Auxiliary functions

//START vector addition kernel function
__global__ void MatrixAddKernel ( int  *Md, int *Nd, int *Pd, int Width ){
        int tx = threadIdx.x;
	int ty = threadIdx.y;
	int Pvalue = 0;
	for ( int k = 0; k < Width; ++k ){
		int Mdelement = Md[ ty * Width + k ];
		int Ndelement = Nd[ k * Width + tx ];
		Pvalue += Mdelement + Ndelement;
	}
        Pd[ ty * Width + tx  ] = Pvalue;
}							
//END of kernel addition


//Start of kernel multiplication
__global__ void MatrixMulKernel ( int  *Md, int *Nd, int *Pd, int Width ){
	int tx = threadIdx.x;
	int ty = threadIdx.y;

	int Pvalue = 0;
	for ( int k = 0; k < Width; ++k ){
		int Mdelement = Md[ ty * Width + k ];
		int Ndelement = Nd[ k * Width + tx ];
		Pvalue += Mdelement * Ndelement;
	}

	Pd[ ty * Width + tx  ] = Pvalue;
}
//End of kernel multiplication


//function to print matrix
void printMatrix ( int *M, int rows, int columns ){
	//assumes matrix is in row-major format
	int index;
	printf ( "\n \n " );
	for ( int v = 0; v < rows; v++  ){
	//assumes a square matrix
		for ( int w = 0; w < columns; w++   ) {
			index = v * columns + w;
			printf ( " %02d", M[ index ]  );
		}
		printf ( " \n\n " );
	}
}//End of printMatrix function

//Start of getMatWidth => Get width i.e. # of columns
int getMatWidth( char *filename ){
	int width;
	//assumes space separate integer values e.g. -1 23 4 -56 6 77
	//assumes first integer in file is row, 2nd integer is column
	FILE *ptr = fopen( filename, "r" );
	if ( ptr == 0 ){
		printf( "\n could not open file %s \n", filename );
		width = 0;
	}
	else{
		fscanf( ptr, "%d", &width  );
	}
	fclose( ptr );
	return width;
}//end of getMatWidth function


//Start of getMatHeight => Get height i.e. # of rows
int getMatHeight( char *filename ){
	int height, dummy;
	//assumes space separate integer values e.g. -1 23 4 -56 6 77
	//assumes first integer in file is row, 2nd integer is column
	FILE *ptr = fopen( filename, "r" );
	if ( ptr == 0 ){
		printf( "\n could not open file %s \n", filename );
		height = 0;
	}
	else{
		for ( int count = 1; count < 3; count++ ){
			if ( count != 2 )
				fscanf( ptr, "%d", &dummy );
		else
			fscanf( ptr, "%d", &dummy  );
			height = dummy;
		}
	}
	fclose( ptr );
	return height;
}//end of getMatHeight function


//START of loadMatrixFile
void loadMatrixFile( char *filename, int *z, int matWidth, int matHeight ){
	int y = 0;
	int w = 0;
	int x;
	int offset = 0;
	FILE *ptr1 = fopen( filename, "r" );
//	int *z = ( int * )malloc( sizeof( ( matWidth * matHeight ) ) );
	//int z[ ( matWidth * matHeight ) + offset ] ;
	fscanf( ptr1, " %d", &x  );
	while( !feof( ptr1 ) && y < ( matWidth * matHeight ) + 1 ){
		if ( y > offset ){
			fscanf( ptr1, " %d", &z[ w - offset ]  );
			//printf( " B: z[ %d ]: %d \n", w, z[ w - offset ] );
			w++;
		}
		else{
			fscanf( ptr1, " %d", &x );
		}
		y++;
	}
	fclose( ptr1 );
//	x = y = w = 0;
//	array = &z[ 0 ];
//	free( z );
}
//END of loadMatrixFile


//Start of matrix multiplication host function MatrixMul
void MatrixMul( char *filename1, char *filename2, int Width /*, int *M, int *N, int  *P, int Width*/ ){
	int size = Width * Width * sizeof( int );
	int *Md, *Nd, *Pd;

	dim3 dimBlock( Width, Width );
	dim3 dimGrid( 1, 1 );

			//load matrices from files
			//get heigh/rows and width/columns of matrices
/*			int matWidthA = getMatWidth ( filename1  );
			int matHeightA = getMatHeight ( filename1  );
			
			int matWidthB = getMatWidth ( filename2  );
			int matHeightB = getMatHeight ( filename2  ); */
			
			int *matA = ( int * )malloc( size );
			//printf( "Width and height of Matrix A: %d %d and init values are\n", Width, Width );
			//printMatrix( matA, Width, Width );
			loadMatrixFile( filename1, matA, Width, Width );

			printf( " \nMatrix A after loading from file: \n" );
			printMatrix( matA, Width, Width );
			
			int *matB = ( int * )malloc( size );
			//printf( "Width and height of Matrix B: %d %d and init values are\n", Width, Width );
			//printMatrix( matB, Width, Width );
			loadMatrixFile( filename2, matB, Width, Width );
		
			printf( " \nMatrix B after loading from file: \n" );
			printMatrix( matB, Width, Width );
			
			//assumes a square matrix
			int *matC = ( int * )malloc( size );
			
/*			printf( "A: \n" );
			for ( int w = 0; w < Width * Width + 10; w++ ){
			        printf( "%d: %d \n",w,  matA[ w ] );
			}
			printf( "\n" );
*/
			//printf( " \nMatrix C initially: \n" );
			//printMatrix( matC, Width, Width );


	cudaMalloc( (void**) &Md, size );
	cudaMemcpy( Md, matA, size, cudaMemcpyHostToDevice );
	cudaMalloc( (void**) &Nd, size );
        cudaMemcpy( Nd, matB, size, cudaMemcpyHostToDevice );
	cudaMalloc( (void**) &Pd, size );	
	
	MatrixMulKernel<<< dimGrid, dimBlock >>>( Md, Nd, Pd, Width );

	cudaMemcpy( matC, Pd, size, cudaMemcpyDeviceToHost );

			printf( " \nMatrix C finally: \n" );
			printMatrix( matC, Width, Width );

	free( matA ); free( matB ); free( matC );
	cudaFree( Md ); cudaFree( Nd ); cudaFree ( Pd );
}
//End of Matrix multiplication function MatrixMul


//END of Auxiliary functions


//START of Main function
int main ( int argc, char *argv[ ] ) {
	int offset = 2;

	if ( argc != 5 ) {
		printf( "\nusage: %s configurationVector spikingVector spikingTransitionMatrix squarematrixwidth\n\n", argv [ 0 ] );
	}
	else {
		char *confVec = argv[ 1 ];
		char *spikVec = argv[ 2 ];
		char *spikTransMat = argv[ 3 ];
		int width = atoi( argv[ 4 ] );
		
		printf( "\nYou have entered files %s, %s, and %s and square matrix width %d \n", spikVec, confVec, spikTransMat, width );

		//load matrices from files
		FILE *ptr1 = fopen( confVec, "r" );
		FILE *ptr2 = fopen( spikVec, "r" );
		FILE *ptr3 = fopen( spikTransMat, "r" );

		if ( ptr1 == 0 && ptr2 == 0 && ptr3 == 0 )
			printf( "\n could not open one of the following files: %s %s \n", argv[ 1 ], argv[ 2 ] );
		else {
			MatrixMul( spikVec, spikTransMat, width );
		}
		fclose( ptr1 ); fclose( ptr2 ); fclose( ptr3 );
	}
}
//END of Main function
