module Matrix4x4;
import std.math: abs, sin, cos, tan, PI, isNaN;
import std.string;
import Vec3;

void Multiply( Matrix4x4 a, Matrix4x4 b, out Matrix4x4 result )
{
    Matrix4x4 tmp;

    for (int i = 0; i < 4; ++i)
    {
        for (int j = 0; j < 4; ++j)
        {
            tmp.m[ i * 4 + j ] = a.m[ i * 4 + 0 ] * b.m[ 0 * 4 + j ] +
                a.m[ i * 4 + 1 ] * b.m[ 1 * 4 + j ] +
                a.m[ i * 4 + 2 ] * b.m[ 2 * 4 + j ] +
                a.m[ i * 4 + 3 ] * b.m[ 3 * 4 + j ];
        }
    }

    result = tmp;

    result.CheckForNaN();
}

void TransformPoint( Vec3 vec, Matrix4x4 mat, out Vec3 vOut )
{
    vOut.x = mat.m[0] * vec.x + mat.m[ 4 ] * vec.y + mat.m[ 8] * vec.z + mat.m[12];
    vOut.y = mat.m[1] * vec.x + mat.m[ 5 ] * vec.y + mat.m[ 9] * vec.z + mat.m[13];
    vOut.z = mat.m[2] * vec.x + mat.m[ 6 ] * vec.y + mat.m[10] * vec.z + mat.m[14];
}

struct Matrix4x4
{
    string toString() const
    {
        return format( "%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n",
            m[ 0 ], m[ 1 ], m[ 2 ], m[ 3 ], m[ 4 ], m[ 5 ], m[ 6 ], m[ 7 ],
            m[ 8 ], m[ 9 ], m[ 10 ], m[ 11 ], m[ 12 ], m[ 13 ], m[ 14 ], m[ 15 ] );
            
    }

    void CheckForNaN() const
    {
        for (int i = 0; i < 16; ++i)
        {
            assert( !isNaN( m[ i ]), "Matrix contains a NaN" );
        }
    }

    void MakeIdentity()
    {
        m[] = 0;
        m[  0 ] = 1;
        m[  5 ] = 1;
        m[ 10 ] = 1;
        m[ 15 ] = 1;

        CheckForNaN();
    }

    void MakeRotationXYZ( float xDeg, float yDeg, float zDeg )
    {
        const float deg2rad = PI / 180.0f;
        const float sx = sin( xDeg * deg2rad );
        const float sy = sin( yDeg * deg2rad );
        const float sz = sin( zDeg * deg2rad );
        const float cx = cos( xDeg * deg2rad );
        const float cy = cos( yDeg * deg2rad );
        const float cz = cos( zDeg * deg2rad );
        
        m[ 0 ] = cy * cz;
        m[ 1 ] = cz * sx * sy - cx * sz;
        m[ 2 ] = cx * cz * sy + sx * sz;
        m[ 3 ] = 0;
        m[ 4 ] = cy * sz;
        m[ 5 ] = cx * cz + sx * sy * sz;
        m[ 6 ] = -cz * sx + cx * sy * sz;
        m[ 7 ] = 0;
        m[ 8 ] = -sy;
        m[ 9 ] = cy * sx;
        m[10 ] = cx * cy;
        m[11 ] = 0;
        m[12 ] = 0;
        m[13 ] = 0;
        m[14 ] = 0;
        m[15 ] = 1;

        CheckForNaN();   
    }

    void MakeProjection( float left, float right, float bottom, float top, float nearDepth, float farDepth )
    {
        const float tx = -((right + left) / (right - left));
        const float ty = -((top + bottom) / (top - bottom));
        const float tz = -((farDepth + nearDepth) / (farDepth - nearDepth));
		
        m =
        [
            2.0f / (right - left), 0.0f, 0.0f, 0.0f,
            0.0f, 2.0f / (top - bottom), 0.0f, 0.0f,
            0.0f, 0.0f, -2.0f / (farDepth - nearDepth), 0.0f,
            tx, ty, tz, 1.0f
        ];

        CheckForNaN();
    }
	
    void MakeProjection( float fovDegrees, float aspect, float nearDepth, float farDepth )
    {
        const float top = tan( fovDegrees * PI / 360.0f ) * nearDepth;
        const float bottom = -top;
        const float left = aspect * bottom;
        const float right = aspect * top;

        const float x = (2 * nearDepth) / (right - left);
        const float y = (2 * nearDepth) / (top - bottom);
        const float a = (right + left)  / (right - left);
        const float b = (top + bottom)  / (top - bottom);

        const float c = -(farDepth + nearDepth) / (farDepth - nearDepth);
        const float d = -(2 * farDepth * nearDepth) / (farDepth - nearDepth);

        m =
        [
            x, 0, 0,  0,
            0, y, 0,  0,
            a, b, c, -1,
            0, 0, d,  0
        ];

        CheckForNaN();
    }

    void MakeLookAt( Vec3 eye, Vec3 center, Vec3 up )
    {
        Vec3.Vec3 zAxis = Vec3.Vec3( center.x - eye.x, center.y - eye.y, center.z - eye.z );
        Normalize( zAxis );

        Vec3 xAxis = Cross( up, zAxis );
        Normalize( xAxis );

        Vec3 yAxis = Cross( zAxis, xAxis );

        m[  0 ] = xAxis.x; m[  1 ] = xAxis.y; m[  2 ] = xAxis.z; m[  3 ] = -Vec3.Dot( xAxis, eye );
        m[  4 ] = yAxis.x; m[  5 ] = yAxis.y; m[  6 ] = yAxis.z; m[  7 ] = -Vec3.Dot( yAxis, eye );
        m[  8 ] = zAxis.x; m[  9 ] = zAxis.y; m[ 10 ] = zAxis.z; m[ 11 ] = -Vec3.Dot( zAxis, eye );
        m[ 12 ] =       0; m[ 13 ] =       0; m[ 14 ] =       0; m[ 15 ] = 1;

        CheckForNaN();
    }

    void Scale( float x, float y, float z )
    {
        Matrix4x4 scale;
        scale.MakeIdentity();
        
        scale.m[  0 ] = x;
        scale.m[  5 ] = y;
        scale.m[ 10 ] = z;

        Multiply( this, scale, this );
    }
    
    void Translate( Vec3 v )
    {
        Matrix4x4 translateMatrix;
        translateMatrix.MakeIdentity();

        translateMatrix.m[ 12 ] = v.x;
        translateMatrix.m[ 13 ] = v.y;
        translateMatrix.m[ 14 ] = v.z;

        Matrix4x4 th;
        th.m = m;
        Matrix4x4 res;
        Multiply( th, translateMatrix, res );
        m = res.m;

        CheckForNaN();
    }

    void Transpose()
    {
        float[ 16 ] tmp;
        
        tmp[  0 ] = m[  0 ];
        tmp[  1 ] = m[  4 ];
        tmp[  2 ] = m[  8 ];
        tmp[  3 ] = m[ 12 ];
        tmp[  4 ] = m[  1 ];
        tmp[  5 ] = m[  5 ];
        tmp[  6 ] = m[  9 ];
        tmp[  7 ] = m[ 13 ];
        tmp[  8 ] = m[  2 ];
        tmp[  9 ] = m[  6 ];
        tmp[ 10 ] = m[ 10 ];
        tmp[ 11 ] = m[ 14 ];
        tmp[ 12 ] = m[  3 ];
        tmp[ 13 ] = m[  7 ];
        tmp[ 14 ] = m[ 11 ];
        tmp[ 15 ] = m[ 15 ];

        m = tmp;

        CheckForNaN();
    }

    float[ 16 ] m;
}

unittest
{
	auto proj = new Matrix4x4();
	proj.MakeProjection( 0, 640, 0, 480, -1, 1 );
	assert( proj.m[ 15 ] == 1 );
}

unittest
{
    Matrix4x4 matrix1;
    matrix1.m = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 ];
    
    Matrix4x4 matrix2;
    matrix2.m = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 ];
    
    Matrix4x4 result;
    Multiply( matrix1, matrix2, result );
    
    Matrix4x4 expectedResult;
    expectedResult.m = 
    [ 
        90, 100, 110, 120,
            202, 228, 254, 280,
            314, 356, 398, 440,
            426, 484, 542, 600
    ];
    
    for (int i = 0; i < 16; ++i)
    {
        assert( abs( result.m[ i ] - expectedResult.m[ i ] ) < 0.0001f, "Matrix4x4 Multiply failed" );
    }
}

unittest
{
    Matrix4x4 matrix;
    matrix.MakeIdentity();
    const float exceptedResult = 42;
    matrix.m[ 3 ] = exceptedResult;
    matrix.Transpose();
    
    assert( matrix.m[ 3 * 4 ] == exceptedResult, "Matrix4x4 Transpose failed!" );
}

